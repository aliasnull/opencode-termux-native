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

for cmd in curl sha256sum install mktemp uname jq awk mv mkdir rm chmod stat tar readlink grep basename; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command '$cmd' is missing. Install dependencies with: pkg install curl coreutils jq tar"
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
[[ -d "$PREFIX/lib" && -w "$PREFIX/lib" ]] ||
    die "Termux library directory is missing or not writable: $PREFIX/lib"

target="$PREFIX/bin/$TARGET_NAME"
install_root="$PREFIX/lib/$INSTALL_DIR_NAME"
state_dir="$PREFIX/var/lib/$STATE_DIR_NAME"
marker="$state_dir/managed-install"

if [[ -e "$target" || -L "$target" ]]; then
    die "An 'opencode' path already exists at $target. Nothing was changed. Inspect it first."
fi
if [[ -e "$install_root" || -L "$install_root" ]]; then
    die "The managed runtime directory already exists at $install_root. Inspect it before installing."
fi
if [[ -e "$marker" || -L "$marker" ]]; then
    die "Ownership metadata already exists at $marker while the executable is missing. Inspect it before installing."
fi

staged_root="$PREFIX/lib/.opencode-termux-native-install.$$"
staged_wrapper="$PREFIX/bin/.opencode-install.$$"
marker_tmp=""
tmpdir=""
lock_dir="$state_dir/update.lock"
lock_owned=0
staged_root_owned=0
staged_wrapper_owned=0
marker_tmp_owned=0
root_id=""
wrapper_id=""
marker_id=""
success=0

cleanup() {
    local status=$?
    local current_id
    trap - EXIT HUP INT TERM

    if (( success == 0 )); then
        if [[ -n "$marker_id" && -f "$marker" && ! -L "$marker" ]]; then
            current_id="$(stat -c '%d:%i' -- "$marker" 2>/dev/null || true)"
            if [[ "$current_id" == "$marker_id" ]]; then
                rm -f -- "$marker" || info "ERROR: Could not remove partially published metadata: $marker"
            fi
        fi
        if [[ -n "$wrapper_id" && -f "$target" && ! -L "$target" ]]; then
            current_id="$(stat -c '%d:%i' -- "$target" 2>/dev/null || true)"
            if [[ "$current_id" == "$wrapper_id" ]]; then
                rm -f -- "$target" || info "ERROR: Could not remove partially published launcher: $target"
            fi
        fi
        if [[ -n "$root_id" && -d "$install_root" && ! -L "$install_root" ]]; then
            current_id="$(stat -c '%d:%i' -- "$install_root" 2>/dev/null || true)"
            if [[ "$current_id" == "$root_id" ]]; then
                rm -rf -- "$install_root" || info "ERROR: Could not remove partially published runtime: $install_root"
            fi
        fi
    fi

    if (( marker_tmp_owned == 1 )) && [[ -n "$marker_tmp" && ( -e "$marker_tmp" || -L "$marker_tmp" ) ]]; then
        rm -f -- "$marker_tmp" || info "ERROR: Could not remove staged metadata: $marker_tmp"
    fi
    if (( staged_wrapper_owned == 1 )) && [[ -e "$staged_wrapper" || -L "$staged_wrapper" ]]; then
        rm -f -- "$staged_wrapper" || info "ERROR: Could not remove staged launcher: $staged_wrapper"
    fi
    if (( staged_root_owned == 1 )) && [[ -e "$staged_root" || -L "$staged_root" ]]; then
        rm -rf -- "$staged_root" || info "ERROR: Could not remove staged runtime: $staged_root"
    fi
    if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
        rm -rf -- "$tmpdir" || info "ERROR: Could not remove temporary directory: $tmpdir"
    fi

    if (( lock_owned == 1 )) && [[ -d "$lock_dir" && ! -L "$lock_dir" ]]; then
        local lock_owner=""
        [[ ! -f "$lock_dir/pid" ]] || lock_owner="$(cat "$lock_dir/pid" 2>/dev/null || true)"
        if [[ -z "$lock_owner" || "$lock_owner" == "$$" ]]; then
            rm -rf -- "$lock_dir" || info "ERROR: Could not remove installer lock: $lock_dir"
        fi
    fi

    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Use the updater lock so install and update cannot overlap.
mkdir -p -- "$state_dir" || die "Could not create metadata directory: $state_dir"
[[ -d "$state_dir" && ! -L "$state_dir" ]] ||
    die "Metadata path must be a real directory, not a symlink: $state_dir"
if ! mkdir -- "$lock_dir" 2>/dev/null; then
    die "Another installer/updater may be running, or a stale lock exists: $lock_dir. Confirm no operation is active, then remove that lock directory manually."
fi
lock_owned=1
printf '%s\n' "$$" > "$lock_dir/pid" ||
    die "Could not write operation lock owner: $lock_dir/pid"

# Recheck destinations after acquiring the lock.
if [[ -e "$target" || -L "$target" ]]; then
    die "An 'opencode' path appeared at $target while acquiring the lock. Nothing was changed."
fi
if [[ -e "$install_root" || -L "$install_root" ]]; then
    die "The managed runtime directory appeared at $install_root while acquiring the lock."
fi
if [[ -e "$marker" || -L "$marker" ]]; then
    die "Ownership metadata appeared at $marker while acquiring the lock."
fi

tmpdir="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/opencode-termux-install.XXXXXX")" ||
    die 'Could not create a temporary directory.'

[[ ! -e "$staged_root" && ! -L "$staged_root" ]] ||
    die "Temporary runtime path already exists: $staged_root"
[[ ! -e "$staged_wrapper" && ! -L "$staged_wrapper" ]] ||
    die "Temporary launcher path already exists: $staged_wrapper"

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

info "Downloading OpenCode ${version} for Android ARM64..."
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$ASSET" --output "$binary_path" ||
    die 'Binary download failed.'
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$ICU_ASSET" --output "$icu_path" ||
    die 'ICU runtime bundle download failed.'
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    "$release_url/$CHECKSUMS" --output "$checksums_path" ||
    die 'Checksum file download failed.'

verify_checksum() {
    local asset="$1"
    local file="$2"
    local expected actual

    expected="$(awk -v asset="$asset" '$2 == asset {print $1; exit}' "$checksums_path")"
    [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] ||
        die "Checksum file does not contain a valid SHA-256 entry for $asset."
    actual="$(sha256sum "$file")"
    actual="${actual%% *}"
    [[ "${actual,,}" == "${expected,,}" ]] ||
        die "SHA-256 verification failed for $asset."
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

mkdir -- "$staged_root" || die "Could not exclusively create staging directory: $staged_root"
staged_root_owned=1
mkdir -- "$staged_root/icu" || die "Could not create ICU staging directory: $staged_root/icu"
tar -xJf "$icu_path" --no-same-owner --no-same-permissions -C "$staged_root/icu" ||
    die 'Could not extract the ICU runtime bundle.'

for soname in libicudata.so.78 libicuuc.so.78 libicui18n.so.78; do
    link="$staged_root/icu/lib/$soname"
    [[ -L "$link" ]] || die "Expected ICU SONAME symlink is missing: $soname"
    link_target="$(readlink "$link")"
    [[ "$link_target" == "$(basename "$link_target")" ]] ||
        die "Unsafe ICU symlink target for $soname: $link_target"
    [[ "$link_target" == "$soname".* ]] ||
        die "Unexpected ICU symlink target for $soname: $link_target"
    [[ -f "$staged_root/icu/lib/$link_target" ]] ||
        die "ICU symlink target is missing for $soname: $link_target"
done
[[ -s "$staged_root/icu/LICENSE" ]] || die 'ICU license file is missing or empty.'

install -m 755 -- "$binary_path" "$staged_root/opencode"
chmod 755 "$staged_root/icu/lib/"*.so.78.* ||
    die 'Could not set executable permissions on ICU libraries.'
chmod 644 "$staged_root/icu/LICENSE"

info 'Testing the staged OpenCode binary with the bundled ICU runtime...'
LD_LIBRARY_PATH="$staged_root/icu/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$staged_root/opencode" --version >/dev/null ||
    die 'Downloaded executable failed its version check with the bundled ICU runtime.'

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
staged_wrapper_owned=1
chmod 755 "$staged_wrapper"

mkdir -p -- "$state_dir" ||
    die "Could not create metadata directory: $state_dir"
marker_tmp="$state_dir/.managed-install.$$"
[[ ! -e "$marker_tmp" && ! -L "$marker_tmp" ]] ||
    die "Temporary metadata path already exists: $marker_tmp"
icu_sha="$(sha256sum "$icu_path")"
icu_sha="${icu_sha%% *}"
printf '%s\nICU-SHA256=%s\n' "$version" "$icu_sha" > "$marker_tmp" ||
    die 'Could not prepare installation metadata.'
marker_tmp_owned=1
chmod 600 "$marker_tmp" || die 'Could not secure installation metadata.'

root_id="$(stat -c '%d:%i' -- "$staged_root")" ||
    die 'Could not identify the staged runtime directory.'
if ! mv -n -- "$staged_root" "$install_root"; then
    die "Could not publish runtime directory: $install_root"
fi
[[ ! -e "$staged_root" && ! -L "$staged_root" ]] ||
    die 'Runtime directory publication failed; destination may already exist.'
[[ "$(stat -c '%d:%i' -- "$install_root")" == "$root_id" ]] ||
    die 'Published runtime directory identity check failed.'

wrapper_id="$(stat -c '%d:%i' -- "$staged_wrapper")" ||
    die 'Could not identify the staged launcher.'
if ! mv -n -- "$staged_wrapper" "$target"; then
    die "Could not publish launcher: $target"
fi
[[ ! -e "$staged_wrapper" && ! -L "$staged_wrapper" ]] ||
    die 'Launcher publication failed; destination may already exist.'
[[ "$(stat -c '%d:%i' -- "$target")" == "$wrapper_id" ]] ||
    die 'Published launcher identity check failed.'

info 'Testing the installed launcher...'
"$target" --version >/dev/null ||
    die 'Installed launcher failed its version check; installation will be rolled back.'

marker_id="$(stat -c '%d:%i' -- "$marker_tmp")" ||
    die 'Could not identify installation metadata.'
if ! mv -n -- "$marker_tmp" "$marker"; then
    die "Could not publish ownership metadata at $marker."
fi
[[ ! -e "$marker_tmp" && ! -L "$marker_tmp" ]] ||
    die 'Metadata publication failed; destination may already exist.'
marker_tmp=""
marker_tmp_owned=0
[[ "$(stat -c '%d:%i' -- "$marker")" == "$marker_id" ]] ||
    die 'Published metadata identity check failed.'

success=1
info "Installation successful: $target"
info "Managed release: $version"
info "Private ICU runtime: $install_root/icu"
info 'Shell configuration, user data, sessions, and cache were not changed.'
