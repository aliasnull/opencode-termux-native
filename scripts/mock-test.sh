#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
INSTALLER="$SCRIPT_DIR/termux-install.sh"
UPDATER="$SCRIPT_DIR/termux-update.sh"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
note() { printf '\n== %s ==\n' "$*"; }

[[ -f "$INSTALLER" && -f "$UPDATER" ]] || die "Place this script in the repository's scripts/ directory."
[[ "${OSTYPE:-}" == linux-android ]] || die "Run this harness in native Termux, not Ubuntu/proot or another Linux environment."
[[ "$(uname -s)" == Linux && ( "$(uname -m)" == aarch64 || "$(uname -m)" == arm64 ) ]] ||
    die "This harness expects native Termux ARM64."

for cmd in bash jq tar xz sha256sum stat mktemp curl awk mv mkdir rm chmod cp install readlink basename find; do
    command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
done

REAL_MV="$(command -v mv)"
REAL_MKDIR="$(command -v mkdir)"
BASH_PATH="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/opencode-mock-tests.XXXXXX")"
MOCKBIN="$WORK/mock-bin"
mkdir -p "$MOCKBIN"
FAILURES=0
TESTS=0

cleanup_harness() {
    local status=$?
    trap - EXIT HUP INT TERM
    if (( FAILURES > 0 )); then
        printf 'Test workspace preserved for diagnosis: %s\\n' "$WORK" >&2
    else
        rm -rf -- "$WORK"
    fi
    exit "$status"
}
trap cleanup_harness EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cat > "$MOCKBIN/curl" <<'MOCK_CURL'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
out=""
url=""
while (($#)); do
    case "$1" in
        --output)
            (($# >= 2)) || exit 2
            out="$2"
            shift 2
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done
[[ -n "$out" && -n "$url" && -n "${MOCK_RELEASE_DIR:-}" ]] || exit 2
case "$url" in
    *api.github.com*)
        src="$MOCK_RELEASE_DIR/releases.json"
        ;;
    */opencode-aarch64)
        src="$MOCK_RELEASE_DIR/opencode-aarch64"
        ;;
    */opencode-icu-aarch64.tar.xz)
        src="$MOCK_RELEASE_DIR/opencode-icu-aarch64.tar.xz"
        ;;
    */SHA256SUMS.txt)
        src="$MOCK_RELEASE_DIR/SHA256SUMS.txt"
        ;;
    *)
        printf 'Mock curl rejected unexpected URL: %s\n' "$url" >&2
        exit 22
        ;;
esac
[[ -f "$src" ]] || exit 22
cp -- "$src" "$out"
MOCK_CURL
chmod 755 "$MOCKBIN/curl"

cat > "$MOCKBIN/mv" <<'MOCK_MV'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
dest="${@: -1}"

if [[ -n "${MOCK_FAIL_MV_DEST:-}" &&
      "$dest" == "$MOCK_FAIL_MV_DEST" &&
      -n "${MOCK_FAIL_MV_ONCE_FILE:-}" &&
      ! -e "$MOCK_FAIL_MV_ONCE_FILE" ]]; then
    : > "$MOCK_FAIL_MV_ONCE_FILE"
    exit 1
fi

"${REAL_MV:?}" "$@"
if [[ -n "${MOCK_SIGNAL_AFTER_MV_DEST:-}" &&
      "$dest" == "$MOCK_SIGNAL_AFTER_MV_DEST" &&
      -n "${MOCK_SIGNAL_ONCE_FILE:-}" &&
      ! -e "$MOCK_SIGNAL_ONCE_FILE" ]]; then
    : > "$MOCK_SIGNAL_ONCE_FILE"
    kill -TERM "$PPID"
fi
MOCK_MV
chmod 755 "$MOCKBIN/mv"

cat > "$MOCKBIN/mkdir" <<'MOCK_MKDIR'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
dest="${@: -1}"
if [[ "${MOCK_COLLIDE_INSTALL_STAGE:-0}" == 1 &&
      "$dest" == */.opencode-termux-native-install.* &&
      "$dest" != */icu &&
      -n "${MOCK_COLLISION_ONCE_FILE:-}" &&
      ! -e "$MOCK_COLLISION_ONCE_FILE" ]]; then
    "${REAL_MKDIR:?}" -p -- "$dest"
    printf 'pre-existing sentinel\n' > "$dest/preexisting-sentinel"
    : > "$MOCK_COLLISION_ONCE_FILE"
fi
exec "${REAL_MKDIR:?}" "$@"
MOCK_MKDIR
chmod 755 "$MOCKBIN/mkdir"

export PATH="$MOCKBIN:$PATH"
export REAL_MV REAL_MKDIR
export MOCK_FAIL_MV_DEST="" MOCK_FAIL_MV_ONCE_FILE=""
export MOCK_SIGNAL_AFTER_MV_DEST="" MOCK_SIGNAL_ONCE_FILE=""
export MOCK_COLLIDE_INSTALL_STAGE=0 MOCK_COLLISION_ONCE_FILE=""

new_prefix() {
    TEST_PREFIX="$WORK/prefix-$1"
    mkdir -p "$TEST_PREFIX/bin" "$TEST_PREFIX/lib" "$TEST_PREFIX/tmp"
}

make_binary() {
    local destination="$1" version="$2" fail_installed="${3:-0}"
    cat > "$destination" <<EOF
#!$BASH_PATH
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
    if [[ "$fail_installed" == 1 && "\${LD_LIBRARY_PATH:-}" == *"/opencode-termux-native/icu"* ]]; then
        printf 'injected installed-runtime failure\\n' >&2
        exit 42
    fi
    printf '%s\\n' 'opencode $version'
    exit 0
fi
printf 'mock OpenCode: %s\\n' '$version'
EOF
    chmod 755 "$destination"
}

make_release() {
    local directory="$1" version="$2" bad_checksum="${3:-0}" bad_archive="${4:-0}" fail_installed="${5:-0}"
    local package="$directory/package"
    mkdir -p "$package/lib"

    make_binary "$directory/opencode-aarch64" "$version" "$fail_installed"
    printf 'mock ICU data\n' > "$package/lib/libicudata.so.78.3"
    printf 'mock ICU uc\n' > "$package/lib/libicuuc.so.78.3"
    printf 'mock ICU i18n\n' > "$package/lib/libicui18n.so.78.3"
    ln -s libicudata.so.78.3 "$package/lib/libicudata.so.78"
    ln -s libicuuc.so.78.3 "$package/lib/libicuuc.so.78"
    ln -s libicui18n.so.78.3 "$package/lib/libicui18n.so.78"
    printf 'Mock Unicode license\n' > "$package/LICENSE"
    if [[ "$bad_archive" == 1 ]]; then
        printf 'unexpected member\n' > "$package/UNEXPECTED"
    fi
    tar -cJf "$directory/opencode-icu-aarch64.tar.xz" -C "$package" .

    jq -n --arg tag "$version" '
      [{
        draft: false,
        tag_name: $tag,
        published_at: "2026-11-11T00:00:00Z",
        assets: [
          {name:"opencode-aarch64"},
          {name:"opencode-icu-aarch64.tar.xz"},
          {name:"SHA256SUMS.txt"}
        ]
      }]
    ' > "$directory/releases.json"

    (
        cd "$directory"
        sha256sum opencode-aarch64 opencode-icu-aarch64.tar.xz > SHA256SUMS.txt
    )
    if [[ "$bad_checksum" == 1 ]]; then
        printf '%064d  opencode-aarch64\n' 0 > "$directory/SHA256SUMS.txt"
        sha256sum "$directory/opencode-icu-aarch64.tar.xz" |
            awk '{print $1 "  opencode-icu-aarch64.tar.xz"}' >> "$directory/SHA256SUMS.txt"
    fi
}

run_installer() {
    local prefix="$1" release="$2"
    shift 2
    env PREFIX="$prefix" ANDROID_ROOT=/system ANDROID_DATA=/data \
        TMPDIR="$prefix/tmp" MOCK_RELEASE_DIR="$release" \
        PATH="$MOCKBIN:$PATH" REAL_MV="$REAL_MV" REAL_MKDIR="$REAL_MKDIR" \
        bash "$INSTALLER" "$@"
}

run_updater() {
    local prefix="$1" release="$2"
    shift 2
    env PREFIX="$prefix" ANDROID_ROOT=/system ANDROID_DATA=/data \
        TMPDIR="$prefix/tmp" MOCK_RELEASE_DIR="$release" \
        PATH="$MOCKBIN:$PATH" REAL_MV="$REAL_MV" REAL_MKDIR="$REAL_MKDIR" \
        bash "$UPDATER" "$@"
}

assert_file() { [[ -f "$1" ]] || return 1; }
assert_absent() { [[ ! -e "$1" && ! -L "$1" ]] || return 1; }
assert_version() {
    local target="$1" expected="$2" output
    output="$("$target" --version 2>/dev/null)" || return 1
    [[ "$output" == "$expected" ]]
}
assert_no_lock() { assert_absent "$1/var/lib/opencode-termux-native/update.lock"; }
assert_icu_wrapper_path() {
    local wrapper="$1"
    grep -Fqx "export LD_LIBRARY_PATH=\"\$runtime_dir/icu/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\"" "$wrapper" &&
    ! grep -Fqx "export LD_LIBRARY_PATH=\"\$runtime_dir/icu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\"" "$wrapper"
}

assert_no_transaction_artifacts() {
    local prefix="$1"
    shopt -s nullglob
    local artifacts=(
        "$prefix"/lib/.opencode-termux-native-rollback.*
        "$prefix"/bin/.opencode-rollback.*
        "$prefix"/var/lib/opencode-termux-native/.managed-install-rollback.*
        "$prefix"/var/lib/opencode-termux-native/.managed-install-new.*
    )
    shopt -u nullglob
    ((${#artifacts[@]} == 0))
}

run_test() {
    local description="$1"
    shift
    TESTS=$((TESTS + 1))
    if "$@"; then
        pass "$description"
    else
        fail "$description"
    fi
}

test_installer_success() {
    local release="$WORK/release-install-success"
    new_prefix installer-success
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1"
    run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-success.log" 2>&1 || {
        cat "$WORK/installer-success.log"
        return 1
    }
    assert_file "$TEST_PREFIX/bin/opencode" &&
    assert_file "$TEST_PREFIX/lib/opencode-termux-native/opencode" &&
    grep -qx 'v9.1.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.1.0-termux.1" &&
    assert_icu_wrapper_path "$TEST_PREFIX/bin/opencode" &&
    assert_no_lock "$TEST_PREFIX"
}

test_installer_lock_refusal() {
    local release="$WORK/release-lock"
    new_prefix installer-lock
    mkdir -p "$TEST_PREFIX/var/lib/opencode-termux-native/update.lock" "$release"
    printf '99999999\n' > "$TEST_PREFIX/var/lib/opencode-termux-native/update.lock/pid"
    make_release "$release" "v9.1.0-termux.1"
    if run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-lock.log" 2>&1; then return 1; fi
    [[ -d "$TEST_PREFIX/var/lib/opencode-termux-native/update.lock" ]] &&
    assert_absent "$TEST_PREFIX/bin/opencode"
}

test_installer_bad_checksum() {
    local release="$WORK/release-installer-bad-checksum"
    new_prefix installer-bad-checksum
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1" 1
    if run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-bad-checksum.log" 2>&1; then return 1; fi
    assert_absent "$TEST_PREFIX/bin/opencode" &&
    assert_absent "$TEST_PREFIX/lib/opencode-termux-native" &&
    assert_no_lock "$TEST_PREFIX"
}

test_installer_bad_archive() {
    local release="$WORK/release-installer-bad-archive"
    new_prefix installer-bad-archive
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1" 0 1
    if run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-bad-archive.log" 2>&1; then return 1; fi
    assert_absent "$TEST_PREFIX/bin/opencode" &&
    assert_absent "$TEST_PREFIX/lib/opencode-termux-native" &&
    assert_no_lock "$TEST_PREFIX"
}

test_installer_stage_collision() {
    local release="$WORK/release-installer-collision"
    local staged_collision=""
    new_prefix installer-collision
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1"
    export MOCK_COLLIDE_INSTALL_STAGE=1
    export MOCK_COLLISION_ONCE_FILE="$WORK/collision-injected"
    local result=0
    run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-collision.log" 2>&1 || result=$?
    export MOCK_COLLIDE_INSTALL_STAGE=0
    staged_collision="$(find "$TEST_PREFIX/lib" -maxdepth 1 -type d -name '.opencode-termux-native-install.*' -print -quit)"
    [[ "$result" -ne 0 ]] &&
    [[ -f "$WORK/collision-injected" ]] &&
    [[ -n "$staged_collision" ]] &&
    assert_file "$staged_collision/preexisting-sentinel" &&
    [[ "$(cat "$staged_collision/preexisting-sentinel")" == "pre-existing sentinel" ]] &&
    assert_absent "$TEST_PREFIX/bin/opencode" &&
    assert_absent "$TEST_PREFIX/lib/opencode-termux-native" &&
    assert_no_lock "$TEST_PREFIX"
}

test_installer_publish_failure() {
    local release="$WORK/release-installer-publish-fail"
    new_prefix installer-publish-fail
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1"
    export MOCK_FAIL_MV_DEST="$TEST_PREFIX/lib/opencode-termux-native"
    export MOCK_FAIL_MV_ONCE_FILE="$WORK/installer-mv-fail-once"
    local result=0
    run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-publish-fail.log" 2>&1 || result=$?
    export MOCK_FAIL_MV_DEST="" MOCK_FAIL_MV_ONCE_FILE=""
    [[ "$result" -ne 0 ]] &&
    assert_absent "$TEST_PREFIX/bin/opencode" &&
    assert_absent "$TEST_PREFIX/lib/opencode-termux-native" &&
    assert_no_lock "$TEST_PREFIX"
}

test_installer_signal_after_publish() {
    local release="$WORK/release-installer-signal"
    new_prefix installer-signal
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1"
    export MOCK_SIGNAL_AFTER_MV_DEST="$TEST_PREFIX/lib/opencode-termux-native"
    export MOCK_SIGNAL_ONCE_FILE="$WORK/installer-signal-once"
    local result=0
    run_installer "$TEST_PREFIX" "$release" > "$WORK/installer-signal.log" 2>&1 || result=$?
    export MOCK_SIGNAL_AFTER_MV_DEST="" MOCK_SIGNAL_ONCE_FILE=""
    [[ "$result" -ne 0 ]] &&
    assert_absent "$TEST_PREFIX/bin/opencode" &&
    assert_absent "$TEST_PREFIX/lib/opencode-termux-native" &&
    assert_no_lock "$TEST_PREFIX"
}

prepare_managed_v1() {
    local prefix_name="$1"
    local release="$WORK/release-$prefix_name-v1"
    new_prefix "$prefix_name"
    mkdir -p "$release"
    make_release "$release" "v9.1.0-termux.1"
    run_installer "$TEST_PREFIX" "$release" > "$WORK/$prefix_name-install.log" 2>&1
}

test_updater_success() {
    local release="$WORK/release-updater-success"
    prepare_managed_v1 updater-success || return 1
    mkdir -p "$release"
    make_release "$release" "v9.2.0-termux.1"
    run_updater "$TEST_PREFIX" "$release" > "$WORK/updater-success.log" 2>&1 || {
        cat "$WORK/updater-success.log"
        return 1
    }
    grep -qx 'v9.2.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.2.0-termux.1" &&
    assert_icu_wrapper_path "$TEST_PREFIX/bin/opencode" &&
    assert_no_lock "$TEST_PREFIX" &&
    assert_no_transaction_artifacts "$TEST_PREFIX"
}

test_updater_bad_checksum() {
    local release="$WORK/release-updater-bad-checksum"
    prepare_managed_v1 updater-bad-checksum || return 1
    mkdir -p "$release"
    make_release "$release" "v9.2.0-termux.1" 1
    if run_updater "$TEST_PREFIX" "$release" > "$WORK/updater-bad-checksum.log" 2>&1; then return 1; fi
    grep -qx 'v9.1.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.1.0-termux.1" &&
    assert_no_lock "$TEST_PREFIX"
}

test_updater_lock_refusal() {
    local release="$WORK/release-updater-lock"
    prepare_managed_v1 updater-lock || return 1
    mkdir -p "$release" "$TEST_PREFIX/var/lib/opencode-termux-native/update.lock"
    printf '99999999\n' > "$TEST_PREFIX/var/lib/opencode-termux-native/update.lock/pid"
    make_release "$release" "v9.2.0-termux.1"
    if run_updater "$TEST_PREFIX" "$release" > "$WORK/updater-lock.log" 2>&1; then return 1; fi
    [[ -d "$TEST_PREFIX/var/lib/opencode-termux-native/update.lock" ]] &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.1.0-termux.1"
}

test_updater_publish_failure() {
    local release="$WORK/release-updater-publish-fail"
    prepare_managed_v1 updater-publish-fail || return 1
    mkdir -p "$release"
    make_release "$release" "v9.2.0-termux.1"
    export MOCK_FAIL_MV_DEST="$TEST_PREFIX/bin/opencode"
    export MOCK_FAIL_MV_ONCE_FILE="$WORK/updater-mv-fail-once"
    local result=0
    run_updater "$TEST_PREFIX" "$release" > "$WORK/updater-publish-fail.log" 2>&1 || result=$?
    export MOCK_FAIL_MV_DEST="" MOCK_FAIL_MV_ONCE_FILE=""
    [[ "$result" -ne 0 ]] &&
    grep -qx 'v9.1.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.1.0-termux.1" &&
    assert_file "$TEST_PREFIX/lib/opencode-termux-native/opencode" &&
    assert_no_lock "$TEST_PREFIX"
}

test_updater_signal_after_publish() {
    local release="$WORK/release-updater-signal"
    prepare_managed_v1 updater-signal || return 1
    mkdir -p "$release"
    make_release "$release" "v9.2.0-termux.1"
    export MOCK_SIGNAL_AFTER_MV_DEST="$TEST_PREFIX/lib/opencode-termux-native"
    export MOCK_SIGNAL_ONCE_FILE="$WORK/updater-signal-once"
    local result=0
    run_updater "$TEST_PREFIX" "$release" > "$WORK/updater-signal.log" 2>&1 || result=$?
    export MOCK_SIGNAL_AFTER_MV_DEST="" MOCK_SIGNAL_ONCE_FILE=""
    [[ "$result" -ne 0 ]] &&
    grep -qx 'v9.1.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.1.0-termux.1" &&
    assert_file "$TEST_PREFIX/lib/opencode-termux-native/opencode" &&
    assert_no_lock "$TEST_PREFIX"
}

test_updater_installed_check_failure() {
    local release="$WORK/release-updater-installed-fail"
    prepare_managed_v1 updater-installed-fail || return 1
    mkdir -p "$release"
    make_release "$release" "v9.2.0-termux.1" 0 0 1
    if run_updater "$TEST_PREFIX" "$release" > "$WORK/updater-installed-fail.log" 2>&1; then return 1; fi
    grep -qx 'v9.1.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.1.0-termux.1" &&
    assert_file "$TEST_PREFIX/lib/opencode-termux-native/opencode" &&
    assert_no_lock "$TEST_PREFIX"
}

test_adoption_then_update() {
    local release="$WORK/release-adoption"
    new_prefix adoption
    mkdir -p "$release"
    make_binary "$TEST_PREFIX/bin/opencode" "v0.0.0-unmanaged"
    make_release "$release" "v9.2.0-termux.1"
    run_updater "$TEST_PREFIX" "$release" --adopt-existing > "$WORK/adoption.log" 2>&1 || {
        cat "$WORK/adoption.log"
        return 1
    }
    grep -qx 'adopted-existing: pending-update' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_no_lock "$TEST_PREFIX" || return 1
    run_updater "$TEST_PREFIX" "$release" > "$WORK/adoption-update.log" 2>&1 || {
        cat "$WORK/adoption-update.log"
        return 1
    }
    grep -qx 'v9.2.0-termux.1' "$TEST_PREFIX/var/lib/opencode-termux-native/managed-install" &&
    assert_version "$TEST_PREFIX/bin/opencode" "opencode v9.2.0-termux.1" &&
    assert_no_lock "$TEST_PREFIX"
}

note "Installer tests"
run_test "fresh install publishes wrapper, runtime, marker, and releases lock" test_installer_success
run_test "installer refuses an already-held shared lock" test_installer_lock_refusal
run_test "installer rejects a bad binary checksum without changing prefix" test_installer_bad_checksum
run_test "installer rejects an archive with an unexpected member" test_installer_bad_archive
run_test "installer refuses a pre-existing staging directory" test_installer_stage_collision
run_test "installer rolls back when runtime publication fails" test_installer_publish_failure
run_test "installer rolls back when TERM arrives just after runtime publication" test_installer_signal_after_publish

note "Updater tests"
run_test "updater replaces v1 with v2 and cleans transaction files" test_updater_success
run_test "updater rejects a bad checksum and preserves v1" test_updater_bad_checksum
run_test "updater refuses an already-held shared lock" test_updater_lock_refusal
run_test "updater restores v1 when launcher publication fails" test_updater_publish_failure
run_test "updater restores v1 when TERM arrives just after runtime publication" test_updater_signal_after_publish
run_test "updater restores v1 when installed version check fails" test_updater_installed_check_failure
run_test "adoption records ownership, releases lock, then updates successfully" test_adoption_then_update

printf '\nMock test summary: %d tests, %d failures\n' "$TESTS" "$FAILURES"
if (( FAILURES > 0 )); then
    printf 'Some tests failed. Harness workspace preserved at %s for diagnosis.\n' "$WORK" >&2
    exit 1
fi
printf 'All mock tests passed. No real Termux OpenCode files were modified.\n'
