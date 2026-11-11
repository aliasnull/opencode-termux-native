#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

readonly REPO="aliasnull/opencode-termux-native"
readonly API_URL="https://api.github.com/repos/${REPO}/releases?per_page=100"
readonly RELEASE_BASE="https://github.com/${REPO}/releases/download"
readonly ASSET="opencode-aarch64"
readonly ICU_ASSET="opencode-icu-aarch64.tar.xz"
readonly CHECKSUMS="SHA256SUMS.txt"
readonly TARGET_NAME="opencode"
readonly STATE_DIR_NAME="opencode-termux-native"
readonly INSTALL_DIR_NAME="opencode-termux-native"

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

for cmd in curl sha256sum install mktemp uname jq awk mv mkdir cat rm chmod cp stat tar readlink grep; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command '$cmd' is missing. Install dependencies with: pkg install curl coreutils jq tar"
done

[[ "${OSTYPE:-}" == linux-android && -n "${PREFIX:-}" && -d "$PREFIX" ]] ||
    die 'This script must run inside Termux on Android.'
[[ -n "${ANDROID_ROOT:-}" && -n "${ANDROID_DATA:-}" ]] ||
    die 'Android environment variables are missing; refusing to update.'
[[ "$(uname -s)" == Linux ]] || die 'Unsupported operating system.'
[[ "$(uname -m)" == aarch64 || "$(uname -m)" == arm64 ]] ||
    die "Unsupported architecture: $(uname -m). This release supports ARM64 only."
[[ -d "$PREFIX/bin" && -w "$PREFIX/bin" && -d "$PREFIX/lib" && -w "$PREFIX/lib" ]] ||
    die 'Termux bin/lib directories are missing or not writable.'

target="$PREFIX/bin/$TARGET_NAME"
install_root="$PREFIX/lib/$INSTALL_DIR_NAME"
state_dir="$PREFIX/var/lib/$STATE_DIR_NAME"
marker="$state_dir/managed-install"

[[ -f "$target" && ! -L "$target" ]] ||
    die "Expected a regular file at $target; refusing to follow a symlink or update a missing file."
[[ -x "$target" ]] || die "The installed launcher/executable is not executable: $target"

if [[ ! -e "$marker" && ! -L "$marker" ]]; then
    [[ "$adopt_existing" == true ]] ||
        die "This installation is not marked as managed by this project. If you have confirmed it belongs to this project, rerun with --adopt-existing."
    [[ ! -L "$state_dir" ]] ||
        die "Metadata directory must not be a symlink: $state_dir"
    mkdir -p -- "$state_dir" || die "Could not create metadata directory: $state_dir"
    [[ -d "$state_dir" && ! -L "$state_dir" ]] ||
        die "Metadata directory is not a real directory: $state_dir"

    # Adoption must use the same lock as install/update. Otherwise --adopt-existing
    # could create a marker while a fresh installer is publishing its files.
    lock_dir="$state_dir/update.lock"
    if ! mkdir -- "$lock_dir" 2>/dev/null; then
        die "Another installer/updater may be running, or a stale lock exists: $lock_dir. Confirm no operation is active, then remove that lock directory manually."
    fi
    adoption_tmp=""
    # shellcheck disable=SC2329
    cleanup_adoption() {
        local status=$?
        local lock_owner=""
        trap - EXIT HUP INT TERM
        if [[ -n "$adoption_tmp" && ( -e "$adoption_tmp" || -L "$adoption_tmp" ) ]]; then
            rm -f -- "$adoption_tmp" || printf 'Error: could not remove adoption temporary file: %s\n' "$adoption_tmp" >&2
        fi
        if [[ -d "$lock_dir" && ! -L "$lock_dir" ]]; then
            [[ ! -f "$lock_dir/pid" ]] || lock_owner="$(cat "$lock_dir/pid" 2>/dev/null || true)"
            if [[ "$lock_owner" == "$$" || -z "$lock_owner" ]]; then
                rm -f -- "$lock_dir/pid" 2>/dev/null || true
                rmdir -- "$lock_dir" 2>/dev/null || true
            fi
        fi
        exit "$status"
    }
    trap cleanup_adoption EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf '%s\n' "$$" > "$lock_dir/pid" ||
        die "Could not write adoption lock owner: $lock_dir/pid"

    adoption_tmp="$state_dir/.managed-install-adopt.$$"
    [[ ! -e "$adoption_tmp" && ! -L "$adoption_tmp" ]] ||
        die "Temporary metadata path already exists: $adoption_tmp"
    printf 'adopted-existing: pending-update\n' > "$adoption_tmp" ||
        die 'Could not prepare adoption metadata.'
    chmod 600 "$adoption_tmp" || die 'Could not secure adoption metadata.'
    if ! mv -n -- "$adoption_tmp" "$marker"; then
        die 'Could not record ownership; existing executable was not changed.'
    fi
    if [[ -e "$adoption_tmp" || -L "$adoption_tmp" ]]; then
        die 'Could not record ownership because metadata destination already exists.'
    fi
    info 'Existing executable recorded as project-managed. No binary was changed.'
    info 'Run the updater again to install the current release and its private ICU runtime.'
    exit 0
fi
[[ -d "$state_dir" && ! -L "$state_dir" ]] ||
    die "Metadata directory is missing or is a symlink: $state_dir"
[[ -f "$marker" && ! -L "$marker" ]] || die "Ownership metadata is not a regular file: $marker"

tmpdir="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/opencode-termux-update.XXXXXX")" ||
    die 'Could not create a temporary directory.'

staged_root="$PREFIX/lib/.opencode-termux-native-update.$$"
staged_wrapper="$PREFIX/bin/.opencode-update.$$"
rollback_root="$PREFIX/lib/.opencode-termux-native-rollback.$$"
rollback_target="$PREFIX/bin/.opencode-rollback.$$"
rollback_marker="$state_dir/.managed-install-rollback.$$"
staged_marker="$state_dir/.managed-install-new.$$"

transaction_started=0
success=0
lock_dir="$state_dir/update.lock"
lock_owned=0
staged_root_id=""
staged_wrapper_id=""
staged_marker_id=""
old_target_id=""
old_marker_id=""

path_id() {
    stat -c '%d:%i' -- "$1" 2>/dev/null || true
}

cleanup() {
    local status=$?
    local current_id=""

    trap - EXIT HUP INT TERM

    if (( success == 0 && transaction_started == 1 )); then
        # Restore metadata only if it is still the file published by this run,
        # or if the destination is missing. Never overwrite an unrelated change.
        if [[ -e "$rollback_marker" || -L "$rollback_marker" ]]; then
            if [[ -e "$marker" || -L "$marker" ]]; then
                current_id="$(path_id "$marker")"
                if [[ -n "$staged_marker_id" && "$current_id" == "$staged_marker_id" ]]; then
                    rm -f -- "$marker" ||
                        info "ERROR: Could not remove failed metadata: $marker"
                elif [[ -n "$old_marker_id" && "$current_id" == "$old_marker_id" ]]; then
                    rm -f -- "$rollback_marker" ||
                        info "ERROR: Could not remove unused metadata backup: $rollback_marker"
                else
                    info "ERROR: Metadata changed during rollback; backup preserved at $rollback_marker"
                fi
            fi
            if [[ ! -e "$marker" && ! -L "$marker" && ( -e "$rollback_marker" || -L "$rollback_marker" ) ]]; then
                mv -- "$rollback_marker" "$marker" ||
                    info "ERROR: Could not restore metadata backup: $rollback_marker"
            fi
        fi

        if [[ -e "$rollback_target" || -L "$rollback_target" ]]; then
            if [[ -e "$target" || -L "$target" ]]; then
                current_id="$(path_id "$target")"
                if [[ -n "$staged_wrapper_id" && "$current_id" == "$staged_wrapper_id" ]]; then
                    rm -f -- "$target" ||
                        info "ERROR: Could not remove failed launcher: $target"
                elif [[ -n "$old_target_id" && "$current_id" == "$old_target_id" ]]; then
                    rm -f -- "$rollback_target" ||
                        info "ERROR: Could not remove unused launcher backup: $rollback_target"
                else
                    info "ERROR: Launcher changed during rollback; backup preserved at $rollback_target"
                fi
            fi
            if [[ ! -e "$target" && ! -L "$target" && ( -e "$rollback_target" || -L "$rollback_target" ) ]]; then
                mv -- "$rollback_target" "$target" ||
                    info "ERROR: Could not restore launcher backup: $rollback_target"
            fi
        fi

        if [[ -e "$rollback_root" || -L "$rollback_root" ]]; then
            if [[ -e "$install_root" || -L "$install_root" ]]; then
                current_id="$(path_id "$install_root")"
                if [[ -n "$staged_root_id" && "$current_id" == "$staged_root_id" ]]; then
                    rm -rf -- "$install_root" ||
                        info "ERROR: Could not remove failed runtime: $install_root"
                else
                    info "ERROR: Runtime destination changed during rollback; backup preserved at $rollback_root"
                fi
            fi
            if [[ ! -e "$install_root" && ! -L "$install_root" && ( -e "$rollback_root" || -L "$rollback_root" ) ]]; then
                mv -- "$rollback_root" "$install_root" ||
                    info "ERROR: Could not restore runtime backup: $rollback_root"
            fi
        elif [[ -n "$staged_root_id" && ( -e "$install_root" || -L "$install_root" ) ]]; then
            current_id="$(path_id "$install_root")"
            if [[ "$current_id" == "$staged_root_id" ]]; then
                rm -rf -- "$install_root" ||
                    info "ERROR: Could not remove failed new runtime: $install_root"
            fi
        fi
    fi

    for path in "$staged_wrapper" "$staged_marker"; do
        [[ ! -e "$path" && ! -L "$path" ]] || rm -f -- "$path"
    done
    [[ ! -e "$staged_root" && ! -L "$staged_root" ]] || rm -rf -- "$staged_root"

    if (( success == 1 || transaction_started == 0 )); then
        rm -f -- "$rollback_target" "$rollback_marker"
        rm -rf -- "$rollback_root"
    fi

    rm -rf -- "$tmpdir"

    if (( lock_owned == 1 )) && [[ -d "$lock_dir" && ! -L "$lock_dir" ]]; then
        local lock_owner=""
        [[ ! -f "$lock_dir/pid" ]] || lock_owner="$(cat "$lock_dir/pid" 2>/dev/null || true)"
        if [[ "$lock_owner" == "$$" || -z "$lock_owner" ]]; then
            rm -f -- "$lock_dir/pid" 2>/dev/null || true
            rmdir -- "$lock_dir" 2>/dev/null || true
        fi
    fi

    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Atomic mkdir prevents two updater instances from modifying the installation.
if ! mkdir -- "$lock_dir" 2>/dev/null; then
    die "Another updater may be running, or a stale lock exists: $lock_dir. Confirm no updater is active, then remove that lock directory manually."
fi
lock_owned=1
printf '%s\n' "$$" > "$lock_dir/pid" ||
    die "Could not write updater lock owner: $lock_dir/pid"

for path in "$staged_root" "$staged_wrapper" "$rollback_root" "$rollback_target" "$rollback_marker" "$staged_marker"; do
    [[ ! -e "$path" && ! -L "$path" ]] || die "Temporary or rollback path already exists: $path"
done

[[ ! -e "$install_root" || ( -d "$install_root" && ! -L "$install_root" ) ]] ||
    die "Managed runtime path exists but is not a real directory: $install_root"

curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$API_URL" --output "$tmpdir/releases.json" ||
    die 'Could not retrieve release metadata from GitHub.'

version="$(jq -er --arg asset "$ASSET" --arg icu "$ICU_ASSET" --arg sums "$CHECKSUMS" '
  [.[] |
    select(.draft == false) |
    select(.tag_name | type == "string") |
    select(.tag_name | test("^v[0-9][A-Za-z0-9._-]*-termux\\.[0-9]+$")) |
    select([.assets[].name] | index($asset)) |
    select([.assets[].name] | index($icu)) |
    select([.assets[].name] | index($sums))
  ] | sort_by(.published_at // .created_at) | reverse | .[0].tag_name // empty
' "$tmpdir/releases.json")" ||
    die 'Could not identify a published Termux release containing the binary, ICU bundle, and checksums.'
[[ "$version" =~ ^v[0-9][A-Za-z0-9._-]*-termux\.[0-9]+$ ]] ||
    die 'The selected release tag is invalid.'

release_url="$RELEASE_BASE/$version"
binary_path="$tmpdir/$ASSET"
icu_path="$tmpdir/$ICU_ASSET"
checksums_path="$tmpdir/$CHECKSUMS"

curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$CHECKSUMS" --output "$checksums_path" ||
    die 'Checksum file download failed.'
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$ASSET" --output "$binary_path" ||
    die 'Binary download failed.'
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$ICU_ASSET" --output "$icu_path" ||
    die 'ICU runtime bundle download failed.'

verify_checksum() {
    local asset="$1" file="$2" expected actual
    expected="$(awk -v asset="$asset" '$2 == asset {print $1; exit}' "$checksums_path")"
    [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] ||
        die "Checksum file does not contain a valid SHA-256 entry for $asset."
    actual="$(sha256sum "$file")"
    actual="${actual%% *}"
    [[ "${actual,,}" == "${expected,,}" ]] || die "SHA-256 verification failed for $asset."
    info "SHA-256 verification passed: $asset"
}

verify_checksum "$ASSET" "$binary_path"
verify_checksum "$ICU_ASSET" "$icu_path"

# Validate every archive member's type, exact path, and symlink target before extraction.
tar -tvJf "$icu_path" > "$tmpdir/icu-verbose.txt" ||
    die 'The ICU archive is invalid or cannot be listed.'
awk '
function fail(message) {
    printf "Error: invalid ICU archive: %s\n", message > "/dev/stderr"
    bad = 1
}
{
    type = substr($1, 1, 1)
    if (type == "l") {
        if ($(NF - 1) != "->") {
            fail("malformed symlink entry")
            next
        }
        path = $(NF - 2)
        target = $NF
    } else {
        path = $NF
        target = ""
    }

    if (seen[path]++) {
        fail("duplicate archive path: " path)
        next
    }

    if (path == "./" || path == "./lib/") {
        if (type != "d") fail("expected directory: " path)
    } else if (path == "./LICENSE") {
        if (type != "-") fail("LICENSE must be a regular file")
        license_seen = 1
    } else if (path == "./lib/libicudata.so.78.3" ||
               path == "./lib/libicuuc.so.78.3" ||
               path == "./lib/libicui18n.so.78.3") {
        if (type != "-") fail("ICU versioned library must be a regular file: " path)
        files[path] = 1
    } else if (path == "./lib/libicudata.so.78") {
        if (type != "l" || target != "libicudata.so.78.3") fail("invalid libicudata SONAME symlink")
        links[path] = 1
    } else if (path == "./lib/libicuuc.so.78") {
        if (type != "l" || target != "libicuuc.so.78.3") fail("invalid libicuuc SONAME symlink")
        links[path] = 1
    } else if (path == "./lib/libicui18n.so.78") {
        if (type != "l" || target != "libicui18n.so.78.3") fail("invalid libicui18n SONAME symlink")
        links[path] = 1
    } else {
        fail("unexpected path or unsupported file type: " path)
    }
}
END {
    required[1] = "./LICENSE"
    required[2] = "./lib/libicudata.so.78"
    required[3] = "./lib/libicuuc.so.78"
    required[4] = "./lib/libicui18n.so.78"
    required[5] = "./lib/libicudata.so.78.3"
    required[6] = "./lib/libicuuc.so.78.3"
    required[7] = "./lib/libicui18n.so.78.3"
    for (i = 1; i <= 7; i++) {
        if (!seen[required[i]]) fail("required entry missing: " required[i])
    }
    if (bad) exit 1
}
' "$tmpdir/icu-verbose.txt" || die 'ICU archive contents failed validation.'

mkdir -p -- "$staged_root/icu"
tar -xJf "$icu_path" --no-same-owner --no-same-permissions -C "$staged_root/icu" ||
    die 'Could not extract the ICU runtime bundle.'

for soname in libicudata.so.78 libicuuc.so.78 libicui18n.so.78; do
    link="$staged_root/icu/lib/$soname"
    [[ -L "$link" ]] || die "Expected ICU SONAME symlink is missing: $soname"
    link_target="$(readlink "$link")"
    [[ "$link_target" == "$(basename "$link_target")" && "$link_target" == "$soname".* ]] ||
        die "Unsafe or unexpected ICU symlink target for $soname: $link_target"
    [[ -f "$staged_root/icu/lib/$link_target" ]] ||
        die "ICU symlink target is missing for $soname: $link_target"
done
[[ -s "$staged_root/icu/LICENSE" ]] || die 'ICU license file is missing or empty.'
chmod 755 "$staged_root/icu/lib/"*.so.78.* ||
    die 'Could not set permissions on ICU libraries.'
chmod 644 "$staged_root/icu/LICENSE"

install -m 755 -- "$binary_path" "$staged_root/opencode"

# Test the new binary without executing the currently installed binary.
info 'Testing downloaded OpenCode with its bundled ICU runtime...'
LD_LIBRARY_PATH="$staged_root/icu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$staged_root/opencode" --version > "$tmpdir/new-version.txt" ||
    die 'Downloaded executable failed its version check with the bundled ICU runtime.'
new_output="$(cat "$tmpdir/new-version.txt")"
[[ -n "$new_output" ]] || die 'Downloaded executable returned an empty version string.'

cat > "$staged_wrapper" <<'WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail

case "$0" in
    */*) script_dir="${0%/*}" ;;
    *) script_dir="." ;;
esac
script_dir="$(CDPATH= cd -- "$script_dir" && pwd)" || {
    printf 'Error: cannot resolve OpenCode launcher directory.\n' >&2
    exit 1
}

runtime_dir="$script_dir/../lib/opencode-termux-native"
[[ -x "$runtime_dir/opencode" ]] || {
    printf 'Error: managed OpenCode binary is missing: %s\n' "$runtime_dir/opencode" >&2
    exit 1
}
[[ -d "$runtime_dir/icu/lib" ]] || {
    printf 'Error: managed ICU runtime is missing: %s\n' "$runtime_dir/icu/lib" >&2
    exit 1
}

export LD_LIBRARY_PATH="$runtime_dir/icu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$runtime_dir/opencode" "$@"
WRAPPER
chmod 755 "$staged_wrapper"

current_marker="$(awk 'NR == 1 {print; exit}' "$marker")"
current_binary=""
if [[ -x "$install_root/opencode" && -f "$install_root/opencode" && ! -L "$install_root/opencode" ]]; then
    current_binary="$install_root/opencode"
elif [[ -f "$target" && ! -L "$target" ]]; then
    current_binary="$target"
fi

binary_sha="$(sha256sum "$binary_path")"
binary_sha="${binary_sha%% *}"
icu_sha="$(sha256sum "$icu_path")"
icu_sha="${icu_sha%% *}"
current_binary_sha=""
if [[ -n "$current_binary" ]]; then
    current_binary_sha="$(sha256sum "$current_binary")"
    current_binary_sha="${current_binary_sha%% *}"
fi
current_icu_sha=""
if [[ -f "$marker" ]]; then
    current_icu_sha="$(awk -F= '$1 == "ICU-SHA256" {print $2; exit}' "$marker")"
fi

if [[ "$current_marker" == "$version" &&
      "${current_binary_sha,,}" == "${binary_sha,,}" &&
      "${current_icu_sha,,}" == "${icu_sha,,}" &&
      -x "$install_root/opencode" &&
      -d "$install_root/icu" ]]; then
    info "Already up to date: $version"
    exit 0
fi

info "Installing update $version..."
mkdir -p -- "$state_dir" ||
    die "Could not access metadata directory: $state_dir"

# Prepare the complete replacement before touching the current installation.
printf '%s\nICU-SHA256=%s\n' "$version" "$icu_sha" > "$tmpdir/managed-install" ||
    die 'Could not prepare updated ownership metadata.'
install -m 600 -- "$tmpdir/managed-install" "$staged_marker" ||
    die 'Could not stage updated ownership metadata.'

# Capture identities before publication. Cleanup uses these identities rather
# than flags that could be missed if the process is interrupted between mv and
# a flag assignment.
staged_root_id="$(path_id "$staged_root")"
staged_wrapper_id="$(path_id "$staged_wrapper")"
staged_marker_id="$(path_id "$staged_marker")"
old_target_id="$(path_id "$target")"
old_marker_id="$(path_id "$marker")"

[[ -n "$staged_root_id" && -n "$staged_wrapper_id" && -n "$staged_marker_id" ]] ||
    die 'Could not record staged component identities.'

# Build backup copies in the private temporary directory, then publish each
# backup with an atomic rename. An interrupted cp cannot leave a partial backup.
cp -p -- "$target" "$tmpdir/old-launcher" ||
    die 'Could not prepare launcher backup.'
mv -- "$tmpdir/old-launcher" "$rollback_target" ||
    die 'Could not publish launcher backup.'
cp -p -- "$marker" "$tmpdir/old-marker" ||
    die 'Could not prepare metadata backup.'
mv -- "$tmpdir/old-marker" "$rollback_marker" ||
    die 'Could not publish metadata backup.'

transaction_started=1
if [[ -e "$install_root" || -L "$install_root" ]]; then
    mv -- "$install_root" "$rollback_root" ||
        die 'Could not back up the current private runtime.'
fi

mv -- "$staged_root" "$install_root" ||
    die 'Could not publish the new private runtime.'
mv -f -- "$staged_wrapper" "$target" ||
    die 'Could not publish the new launcher.'
mv -f -- "$staged_marker" "$marker" ||
    die 'Could not publish updated ownership metadata.'

"$target" --version > "$tmpdir/installed-version.txt" ||
    die 'Updated launcher failed its version check; rollback will restore the previous installation.'
installed_output="$(cat "$tmpdir/installed-version.txt")"
[[ "$installed_output" == "$new_output" ]] ||
    die 'Installed launcher returned a different version than the staged binary; rollback will restore the previous installation.'

# Mark the verified installation committed before disabling rollback. If a
# signal arrives between these assignments, cleanup must not discard backups
# while treating the transaction as uncommitted.
success=1
transaction_started=0
rm -f -- "$rollback_target" "$rollback_marker"
rm -rf -- "$rollback_root"
info "Update successful: $version"
info "Updated launcher: $target"
info "Private ICU runtime: $install_root/icu"
info 'Configuration, sessions, and cache were not changed.'
