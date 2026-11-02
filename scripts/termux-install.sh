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

for cmd in curl sha256sum install mktemp uname jq awk mv mkdir rm chmod stat; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command '$cmd' is missing. Install dependencies with: pkg install curl coreutils jq"
done

[[ "${OSTYPE:-}" == linux-android && -n "${PREFIX:-}" && -d "$PREFIX" ]] ||
    die 'This script must run inside Termux on Android.'
[[ -n "${ANDROID_ROOT:-}" && -n "${ANDROID_DATA:-}" ]] ||
    die 'Android environment variables are missing; refusing to install.'
[[ "$(uname -s)" == Linux ]] || die 'Unsupported operating system.'
[[ "$(uname -m)" == aarch64 || "$(uname -m)" == arm64 ]] ||
    die "Unsupported architecture: $(uname -m). This release supports ARM64 only."
[[ -d "$PREFIX/bin" && -w "$PREFIX/bin" ]] ||
    die "Termux bin directory is missing or not writable: $PREFIX/bin"

target="$PREFIX/bin/$TARGET_NAME"
state_dir="$PREFIX/var/lib/$STATE_DIR_NAME"
marker="$state_dir/managed-install"

if [[ -e "$target" || -L "$target" ]]; then
    die "An 'opencode' path already exists at $target. Nothing was changed. Inspect it first."
fi
if [[ -e "$marker" || -L "$marker" ]]; then
    die "Ownership metadata already exists at $marker while the executable is missing. Inspect it before installing."
fi

tmpdir="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/opencode-termux-install.XXXXXX")" ||
    die 'Could not create a temporary directory.'
staged=""
marker_tmp=""
cleanup() {
    if [[ -n "$staged" && ( -e "$staged" || -L "$staged" ) ]]; then rm -f -- "$staged"; fi
    if [[ -n "$marker_tmp" && ( -e "$marker_tmp" || -L "$marker_tmp" ) ]]; then rm -f -- "$marker_tmp"; fi
    rm -rf -- "$tmpdir"
}
trap cleanup EXIT

curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$API_URL" --output "$tmpdir/releases.json" ||
    die 'Could not retrieve release metadata from GitHub.'

version="$(jq -er --arg asset "$ASSET" --arg sums "$CHECKSUMS" '
  [.[] |
    select(.draft == false) |
    select(.tag_name | type == "string") |
    select(.tag_name | test("^v[0-9][A-Za-z0-9._-]*-termux\\.[0-9]+$")) |
    select([.assets[].name] | index($asset)) |
    select([.assets[].name] | index($sums))
  ] | sort_by(.published_at // .created_at) | reverse | .[0].tag_name // empty
' "$tmpdir/releases.json")" ||
    die 'Could not identify a published Termux release with both required assets.'
[[ "$version" =~ ^v[0-9][A-Za-z0-9._-]*-termux\.[0-9]+$ ]] ||
    die 'The selected release tag is invalid.'

release_url="$RELEASE_BASE/$version"
binary_path="$tmpdir/$ASSET"
checksums_path="$tmpdir/$CHECKSUMS"
info "Downloading OpenCode ${version} for Android ARM64..."
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$ASSET" --output "$binary_path" || die 'Binary download failed.'
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$CHECKSUMS" --output "$checksums_path" || die 'Checksum file download failed.'

expected_sha="$(awk -v asset="$ASSET" '$2 == asset {print $1; exit}' "$checksums_path")"
[[ "$expected_sha" =~ ^[a-fA-F0-9]{64}$ ]] ||
    die 'Checksum file does not contain a valid SHA-256 entry for the binary.'
actual_sha="$(sha256sum "$binary_path")"
actual_sha="${actual_sha%% *}"
[[ "${actual_sha,,}" == "${expected_sha,,}" ]] ||
    die 'SHA-256 verification failed. The binary will not be installed.'
info 'SHA-256 verification passed.'

staged="$PREFIX/bin/.opencode-install.$$"
[[ ! -e "$staged" && ! -L "$staged" ]] || die "Temporary install path already exists: $staged"
install -m 755 -- "$binary_path" "$staged"
"$staged" --version >/dev/null || die 'Downloaded executable failed its version check; nothing was installed.'

# Prepare metadata before publishing the executable.
mkdir -p -- "$state_dir" || die "Could not create metadata directory: $state_dir"
marker_tmp="$state_dir/.managed-install.$$"
[[ ! -e "$marker_tmp" && ! -L "$marker_tmp" ]] || die "Temporary metadata path already exists: $marker_tmp"
printf '%s\n' "$version" > "$marker_tmp" || die 'Could not prepare installation metadata.'
chmod 600 "$marker_tmp" || die 'Could not secure installation metadata.'

# Record the staged file identity, then publish without clobbering an existing target.
staged_id="$(stat -c '%d:%i' -- "$staged")" || die 'Could not identify the staged executable.'
if ! mv -n -- "$staged" "$target"; then
    die "Could not publish $target; no existing path was intentionally overwritten."
fi
if [[ -e "$staged" || -L "$staged" ]]; then
    die "Could not publish $target because the destination already exists; no existing path was overwritten."
fi
[[ "$(stat -c '%d:%i' -- "$target")" == "$staged_id" ]] ||
    die 'Published executable identity check failed; refusing to continue.'

# Publish ownership metadata without replacing an existing marker.
if ! mv -n -- "$marker_tmp" "$marker"; then
    if [[ -f "$target" && ! -L "$target" ]] &&
       [[ "$(stat -c '%d:%i' -- "$target")" == "$staged_id" ]]; then
        rm -f -- "$target"
    fi
    die "Could not publish ownership metadata at $marker; installation was rolled back where safe."
fi
if [[ -e "$marker_tmp" || -L "$marker_tmp" ]]; then
    if [[ -f "$target" && ! -L "$target" ]] &&
       [[ "$(stat -c '%d:%i' -- "$target")" == "$staged_id" ]]; then
        rm -f -- "$target"
    fi
    die "Could not publish ownership metadata at $marker; the destination may already exist."
fi
marker_tmp=""
staged=""

info "Installation successful: $target"
info "Managed release: $version"
info 'Shell configuration, user data, sessions, and cache were not changed.'
