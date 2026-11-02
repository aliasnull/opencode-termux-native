#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

readonly REPO="aliasnull/opencode-termux-native"
readonly API_URL="https://api.github.com/repos/${REPO}/releases?per_page=100"
readonly RELEASE_BASE="https://github.com/${REPO}/releases/download"
readonly ASSET="opencode-aarch64"
readonly CHECKSUMS="SHA256SUMS.txt"
readonly TARGET_NAME="opencode"
readonly STATE_DIR_NAME="opencode-termux-native"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
usage() {
    cat <<'USAGE'
OpenCode Native for Termux updater

Usage:
  bash termux-update.sh
  bash termux-update.sh --adopt-existing

Use --adopt-existing only after personally confirming that the existing
$PREFIX/bin/opencode executable belongs to this project. Adoption records
ownership only; run the updater again afterward to install/check updates.
USAGE
}

adopt_existing=false
while (($#)); do
    case "$1" in
        --adopt-existing) adopt_existing=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1 (use --help for usage)" ;;
    esac
done

for cmd in curl sha256sum install mktemp uname jq awk mv mkdir cat rm chmod cp; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command '$cmd' is missing. Install dependencies with: pkg install curl coreutils jq"
done

[[ "${OSTYPE:-}" == linux-android && -n "${PREFIX:-}" && -d "$PREFIX" ]] ||
    die 'This script must run inside Termux on Android.'
[[ -n "${ANDROID_ROOT:-}" && -n "${ANDROID_DATA:-}" ]] ||
    die 'Android environment variables are missing; refusing to update.'
[[ "$(uname -s)" == Linux ]] || die 'Unsupported operating system.'
[[ "$(uname -m)" == aarch64 || "$(uname -m)" == arm64 ]] ||
    die "Unsupported architecture: $(uname -m). This release supports ARM64 only."

target="$PREFIX/bin/$TARGET_NAME"
state_dir="$PREFIX/var/lib/$STATE_DIR_NAME"
marker="$state_dir/managed-install"
[[ -f "$target" && ! -L "$target" ]] ||
    die "Expected a regular file at $target; refusing to follow a symlink or update a missing file."
[[ -x "$target" ]] || die "The installed file is not executable: $target"

if [[ ! -e "$marker" && ! -L "$marker" ]]; then
    [[ "$adopt_existing" == true ]] ||
        die "This installation is not marked as managed by this project. If you have confirmed it belongs to this project, rerun with --adopt-existing."
    current_output="$("$target" --version 2>/dev/null)" || die 'Existing executable failed its version check; it will not be adopted.'
    [[ -n "$current_output" ]] || die 'Could not read the existing executable version.'
    mkdir -p -- "$state_dir" || die "Could not create metadata directory: $state_dir"
    adoption_tmp="$state_dir/.managed-install-adopt.$$"
    [[ ! -e "$adoption_tmp" && ! -L "$adoption_tmp" ]] || die "Temporary metadata path already exists: $adoption_tmp"
    printf 'adopted-existing: %s\n' "${current_output%%$'\n'*}" > "$adoption_tmp"
    chmod 600 "$adoption_tmp"
    if ! mv -n -- "$adoption_tmp" "$marker"; then
        rm -f -- "$adoption_tmp"
        die 'Could not record ownership; existing executable was not changed.'
    fi
    if [[ -e "$adoption_tmp" || -L "$adoption_tmp" ]]; then
        rm -f -- "$adoption_tmp"
        die 'Could not record ownership because the metadata destination already exists; existing executable was not changed.'
    fi
    info 'Existing executable recorded as project-managed. No binary was changed.'
    info 'Run the updater again to check for and install a release update.'
    exit 0
fi
[[ -f "$marker" && ! -L "$marker" ]] || die "Ownership metadata is not a regular file: $marker"

tmpdir="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/opencode-termux-update.XXXXXX")" || die 'Could not create a temporary directory.'
staged=""
rollback=""
marker_rollback=""
marker_staged=""
transaction_started=false
cleanup() {
    local status=$?
    trap - EXIT HUP INT TERM
    if [[ "$transaction_started" == true ]]; then
        if [[ -n "$rollback" && ( -e "$rollback" || -L "$rollback" ) ]]; then
            if [[ -e "$target" && "$rollback" -ef "$target" ]]; then
                rm -f -- "$rollback"
                info 'Previous executable is already in place; executable rollback was not needed.'
            elif mv -f -- "$rollback" "$target"; then
                info 'Restored the previous executable after an interrupted update.'
            else
                info "ERROR: Automatic rollback failed. Previous executable backup: $rollback" >&2
            fi
        fi
        if [[ -n "$marker_rollback" && ( -e "$marker_rollback" || -L "$marker_rollback" ) ]]; then
            if [[ -e "$marker" && "$marker_rollback" -ef "$marker" ]]; then
                rm -f -- "$marker_rollback"
                info 'Previous ownership metadata is already in place; metadata rollback was not needed.'
            elif mv -f -- "$marker_rollback" "$marker"; then
                info 'Restored previous ownership metadata.'
            else
                info "ERROR: Could not restore previous metadata backup: $marker_rollback" >&2
            fi
        fi
    fi
    for path in "$staged" "$marker_staged"; do
        if [[ -n "$path" && ( -e "$path" || -L "$path" ) ]]; then rm -f -- "$path"; fi
    done
    rm -rf -- "$tmpdir"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$API_URL" --output "$tmpdir/releases.json" || die 'Could not retrieve release metadata from GitHub.'
version="$(jq -er --arg asset "$ASSET" --arg sums "$CHECKSUMS" '
  [.[] |
    select(.draft == false) |
    select(.tag_name | type == "string") |
    select(.tag_name | test("^v[0-9][A-Za-z0-9._-]*-termux\\.[0-9]+$")) |
    select([.assets[].name] | index($asset)) |
    select([.assets[].name] | index($sums))
  ] | sort_by(.published_at // .created_at) | reverse | .[0].tag_name // empty
' "$tmpdir/releases.json")" || die 'Could not identify a published Termux release with both required assets.'
[[ "$version" =~ ^v[0-9][A-Za-z0-9._-]*-termux\.[0-9]+$ ]] || die 'The selected release tag is invalid.'

release_url="$RELEASE_BASE/$version"
binary_path="$tmpdir/$ASSET"
checksums_path="$tmpdir/$CHECKSUMS"
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 "$release_url/$CHECKSUMS" --output "$checksums_path" || die 'Checksum file download failed.'
expected_sha="$(awk -v asset="$ASSET" '$2 == asset {print $1; exit}' "$checksums_path")"
[[ "$expected_sha" =~ ^[a-fA-F0-9]{64}$ ]] || die 'Checksum file does not contain a valid SHA-256 entry for the binary.'

current_output="$("$target" --version 2>/dev/null)" || die 'The currently installed executable failed its version check.'
current_marker="$(cat "$marker")"
current_sha="$(sha256sum "$target")"; current_sha="${current_sha%% *}"
if [[ "$current_marker" == "$version" && "${current_sha,,}" == "${expected_sha,,}" ]]; then
    info "Already up to date: $version"
    exit 0
fi

info "Current installation: $current_output"
info "Downloading update $version..."
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 "$release_url/$ASSET" --output "$binary_path" || die 'Binary download failed.'
actual_sha="$(sha256sum "$binary_path")"; actual_sha="${actual_sha%% *}"
[[ "${actual_sha,,}" == "${expected_sha,,}" ]] || die 'SHA-256 verification failed. The existing executable remains unchanged.'
info 'SHA-256 verification passed.'

staged="$PREFIX/bin/.opencode-update.$$"
[[ ! -e "$staged" && ! -L "$staged" ]] || die "Temporary update path already exists: $staged"
install -m 755 -- "$binary_path" "$staged"
"$staged" --version >/dev/null || die 'Downloaded executable failed its version check; existing installation is unchanged.'

rollback="$PREFIX/bin/.opencode-rollback.$$"
[[ ! -e "$rollback" && ! -L "$rollback" ]] || die "Rollback path already exists: $rollback"
cp -p -- "$target" "$rollback" || die 'Could not create a rollback backup; existing installation is unchanged.'
marker_rollback="$state_dir/.managed-install-rollback.$$"
[[ ! -e "$marker_rollback" && ! -L "$marker_rollback" ]] || die "Metadata rollback path already exists: $marker_rollback"
cp -p -- "$marker" "$marker_rollback" || { rm -f -- "$rollback" "$marker_rollback"; die 'Could not create a metadata rollback backup; existing installation is unchanged.'; }

transaction_started=true
if ! mv -f -- "$staged" "$target"; then die 'Could not replace the executable; rollback will restore the previous state.'; fi
staged=""

marker_staged="$state_dir/.managed-install-new.$$"
[[ ! -e "$marker_staged" && ! -L "$marker_staged" ]] || die "Temporary metadata path already exists: $marker_staged"
printf '%s\n' "$version" > "$tmpdir/managed-install" || die 'Could not prepare updated ownership metadata; rollback will restore the previous state.'
install -m 600 -- "$tmpdir/managed-install" "$marker_staged" || die 'Could not stage updated ownership metadata; rollback will restore the previous state.'
if ! mv -f -- "$marker_staged" "$marker"; then die 'Could not publish updated ownership metadata; rollback will restore the previous state.'; fi
marker_staged=""
"$target" --version >/dev/null 2>&1 || die 'Updated executable failed its version check; rollback will restore the previous state.'

transaction_started=false
rm -f -- "$rollback" "$marker_rollback"
rollback=""
marker_rollback=""
info "Update successful: $version"
info "Updated executable: $target"
info 'Configuration, sessions, and cache were not changed.'
