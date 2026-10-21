#!/bin/bash
# Only temporary files and local fake Proton; no network, Steam or system actions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$TEST_ROOT/home with spaces" ZHOUKEER_APP_DIR="$TEST_ROOT/apps with spaces"
export ZHOUKEER_LAUNCHER_BASE="$TEST_ROOT/storage with spaces"
export ZHOUKEER_TEST_MODE=1
mkdir -p "$HOME/.config" "$HOME/桌面" "$TEST_ROOT/steam/steamapps"
printf 'XDG_DESKTOP_DIR="$HOME/桌面"\n' > "$HOME/.config/user-dirs.dirs"
source "$ROOT/modules/quark.sh"
(
    unset ZHOUKEER_TEST_MODE
    launcher_details quark
    download_policy_url_allowed "$LAUNCHER_URL" || fail 'official fixed URL denied'
    if download_policy_url_allowed 'https://umcdn.quark.cn.example.org/setup.exe'; then fail 'lookalike download allowed'; fi
    if download_policy_url_allowed 'https://umcdn.quark.cn/download/other.exe'; then fail 'unreviewed package allowed'; fi
)
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
log() { :; }
find_steam_root() { printf '%s\n' "$TEST_ROOT/steam"; }
select_launcher_storage_base() { printf '%s\n' "$ZHOUKEER_LAUNCHER_BASE"; }
ensure_launcher_proton_runner() { printf '%s\n' "$TEST_ROOT/proton"; }
printf 'MZfixture installer' > "$TEST_ROOT/fixture.exe"
EXPECTED_SHA="$(launcher_file_sha256 "$TEST_ROOT/fixture.exe")"
ORIGINAL_DETAILS="$(declare -f launcher_details)"
# Fixture metadata reuses the real target settings, while all payloads are tiny local files.
source <(printf '%s\n' "$ORIGINAL_DETAILS" | sed '1s/launcher_details/real_launcher_details/')
launcher_details() { real_launcher_details "$@"; LAUNCHER_FIXED_SHA256="$EXPECTED_SHA"; LAUNCHER_GITEE_MIRROR_SHA256="$EXPECTED_SHA"; LAUNCHER_MIN_BYTES=2; }
MODE=good MIRROR=good
download_gitee_mirror_file() {
    [ "$1" = quark ] && [ "$(gitee_mirror_manifest_repo "$1")" = zhoukeer-toolbox-mirror-6 ] || fail 'wrong mirror route'
    printf 'mirror\n' >> "$TEST_ROOT/downloads"
    [ "$MIRROR" = good ] || return 1
    cp "$TEST_ROOT/fixture.exe" "$2"
}
run_curl_with_progress() {
    printf 'fallback\n' >> "$TEST_ROOT/downloads"
    local previous='' arg output=''
    for arg in "$@"; do [ "$previous" != --output ] || output="$arg"; previous="$arg"; done
    [ "$MODE" != fail ] || return 1
    if [ "$MODE" = bad ]; then printf 'MZdamaged fixture' > "$output"; else cp "$TEST_ROOT/fixture.exe" "$output"; fi
}
cat > "$TEST_ROOT/proton" <<'SH'
#!/bin/bash
printf '%s\n' "$@" >> "$QUARK_TEST_LOG"
case "$2" in
    *QuarkCloudDrive-7.4.2.exe)
        [ "${QUARK_TEST_INSTALL_FAIL:-0}" != 1 ] || exit 1
        mkdir -p "$STEAM_COMPAT_DATA_PATH/pfx/drive_c/Program Files/QuarkCloudDrive"
        printf 'MZinstalled fixture' > "$STEAM_COMPAT_DATA_PATH/pfx/drive_c/Program Files/QuarkCloudDrive/QuarkCloudDrive.exe"
        ;;
esac
SH
chmod +x "$TEST_ROOT/proton"
export QUARK_TEST_LOG="$TEST_ROOT/proton.log"
POST_INSTALL_TIMEOUT=0 POST_INSTALL_INTERVAL=1
sleep() { :; }
(
    # Versioned/user-local paths must also work through the managed drive link.
    launcher_details quark
    mkdir -p "$TEST_ROOT/versioned-drive/users/steamuser/AppData/Local/QuarkCloudDrive/app-7.4.2" "$TEST_ROOT/versioned-prefix/pfx"
    printf 'MZversioned' > "$TEST_ROOT/versioned-drive/users/steamuser/AppData/Local/QuarkCloudDrive/app-7.4.2/QuarkCloudDrive.exe"
    ln -s "$TEST_ROOT/versioned-drive" "$TEST_ROOT/versioned-prefix/pfx/drive_c"
    found="$(find_launcher_in_prefix "$TEST_ROOT/versioned-prefix")"
    quark_exe_valid "$found" || fail 'versioned installed executable not found'
)
(
    APP_DIR="$TEST_ROOT/failure-apps"; QUARK_APP_DIR="$APP_DIR/game-launchers/quark"
    ZHOUKEER_LAUNCHER_BASE="$TEST_ROOT/failure-storage"
    export QUARK_TEST_INSTALL_FAIL=1
    if install_quark > "$TEST_ROOT/installer-fail.out" 2>&1; then fail 'installer failure reported success'; fi
    [ ! -e "$HOME/桌面/夸克网盘.desktop" ] || fail 'failed install created entry'
)
rm -f -- "$TEST_ROOT/downloads"
install_quark > "$TEST_ROOT/install.out" 2>&1
DESKTOP="$HOME/桌面/夸克网盘.desktop"
APPLICATION="$HOME/.local/share/applications/renkit-quark.desktop"
[ -f "$DESKTOP" ] && [ -f "$APPLICATION" ] || fail 'missing desktop/application entries'
grep -Fq 'Categories=Network;FileTransfer;' "$DESKTOP" || fail 'wrong application category'
grep -Fq 'Icon='"$ROOT/assets/software/quark.png" "$DESKTOP" || fail 'missing vendor icon'
grep -Fqx '/DIR=C:\Program Files\QuarkCloudDrive' "$QUARK_TEST_LOG" || fail 'missing verified Inno installation path'
if grep -Fqx /S "$QUARK_TEST_LOG"; then fail 'used incompatible installer switches'; fi
printf 'customer data' > "$ZHOUKEER_LAUNCHER_BASE/quark/drive_c/customer.data"
install_quark > "$TEST_ROOT/repeat.out" 2>&1
[ "$(wc -l < "$TEST_ROOT/downloads" | tr -d ' ')" = 1 ] || fail 'repeated download for existing installation'
bash "$QUARK_APP_DIR/launch-quark.sh"
grep -Fqx "$ZHOUKEER_LAUNCHER_BASE/quark/drive_c/Program Files/QuarkCloudDrive/QuarkCloudDrive.exe" "$QUARK_TEST_LOG" || \
    grep -Fqx "$QUARK_APP_DIR/compatdata/pfx/drive_c/Program Files/QuarkCloudDrive/QuarkCloudDrive.exe" "$QUARK_TEST_LOG" || fail 'wrapper changed executable path'

# Test real download dispatch and its integrity gates with mocked transports.
launcher_details quark
MIRROR=fail
download_launcher_installer "$TEST_ROOT/fallback.exe" > "$TEST_ROOT/fallback.out" 2>&1
cmp "$TEST_ROOT/fallback.exe" "$TEST_ROOT/fixture.exe" || fail 'fallback payload mismatch'
for MODE in bad fail; do
    if download_launcher_installer "$TEST_ROOT/fallback.exe" > "$TEST_ROOT/$MODE.out" 2>&1; then fail "$MODE download accepted"; fi
    cmp "$TEST_ROOT/fallback.exe" "$TEST_ROOT/fixture.exe" || fail 'failed download replaced previous installer'
    [ ! -e "$TEST_ROOT/fallback.exe.new.$$" ] || fail 'temporary download leaked'
done
MODE=good
remove_quark_shortcuts > "$TEST_ROOT/remove.out"
[ ! -e "$DESKTOP" ] && [ ! -e "$APPLICATION" ] || fail 'managed entries not removed'
[ "$(cat "$ZHOUKEER_LAUNCHER_BASE/quark/drive_c/customer.data")" = 'customer data' ] || fail 'customer data removed'
printf '[Desktop Entry]\nName=customer entry\n' > "$DESKTOP"
if install_quark > "$TEST_ROOT/conflict.out" 2>&1; then fail 'overwrote unmanaged shortcut'; fi
grep -Fq 'Name=customer entry' "$DESKTOP" || fail 'customer shortcut changed'
rm -- "$DESKTOP"
ln -s "$TEST_ROOT/outside" "$QUARK_APP_DIR/launch-quark.sh.link"
mv -- "$QUARK_APP_DIR/launch-quark.sh.link" "$QUARK_APP_DIR/launch-quark.sh"
if install_quark > "$TEST_ROOT/symlink.out" 2>&1; then fail 'unsafe wrapper accepted'; fi
[ ! -e "$TEST_ROOT/outside" ] || fail 'followed wrapper symlink'
if grep -Ei 'gitee|分块|镜像|https://' "$TEST_ROOT"/*.out; then fail 'internal details in download UI'; fi
printf '%s\n' 'PASS: Quark verified mirror/fallback, install, wrapper, repeat, data preservation and unsafe path checks'
