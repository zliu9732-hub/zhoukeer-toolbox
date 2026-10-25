#!/bin/bash
# Fully mocked install/migration regression. No real Linux binary is executed.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home" ZHOUKEER_APP_DIR="$TMP/apps" ZHOUKEER_LOG_DIR="$TMP/logs"
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_AUTO_CONFIRM=1
mkdir -p "$HOME" "$ZHOUKEER_APP_DIR"
source "$ROOT/modules/steam_accelerator.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
uname() { case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) return 99 ;; esac; }
calculate_steam302_sha256() { echo "$STEAM302_ARCHIVE_SHA256"; }
steam302_service_is_active() { return 1; }
steam302_service_is_enabled() { return 1; }
steam302_service_exists() { return 1; }
steam302_service_is_toolbox_managed() { return 1; }
steam302_stop_legacy() { echo stop-legacy >> "$TMP/calls"; }
steam302_v15_helper() { echo "helper-$1" >> "$TMP/calls"; [ "${HELPER_FAIL:-0}" -eq 0 ]; }
steam302_v15_control() { echo "control-$1" >> "$TMP/calls"; [ "$1" != certificates ] || [ "${CERT_FAIL:-0}" -eq 0 ]; }
download_steam302_archive() {
    cat > "$1" <<'MOCK'
#!/bin/bash
set -eu
[ "$1" = --appimage-extract ]
mkdir -p squashfs-root/usr/bin
printf '#!/bin/bash\nexit 0\n' > squashfs-root/AppRun
cp squashfs-root/AppRun squashfs-root/usr/bin/s302-service-installer
chmod 755 squashfs-root/AppRun squashfs-root/usr/bin/s302-service-installer
printf '{}\n' > squashfs-root/usr/bin/s302-service-manifest.json
MOCK
}
old_fixture() {
    rm -rf -- "$STEAM302_INSTALL_DIR" "$APP_DIR"/.steamcommunity302-backup.*
    mkdir -p "$STEAM302_INSTALL_DIR"
    echo 14.0.02 > "$STEAM302_INSTALL_DIR/.zhoukeer-version"
    echo customer-settings > "$STEAM302_INSTALL_DIR/S302.ini"
}
old_fixture
HELPER_FAIL=1
if install_steam302 > "$TMP/output" 2>&1; then fail "helper failure was accepted"; fi
[ "$(steam302_installed_version)" = 14.0.02 ] || fail "old version not restored"
[ "$(cat "$STEAM302_INSTALL_DIR/S302.ini")" = customer-settings ] || fail "old config lost"
HELPER_FAIL=0 CERT_FAIL=1
if install_steam302 > "$TMP/output" 2>&1; then fail "partial certificate failure was accepted"; fi
grep -q '安装尚未完成' "$TMP/output" || { cat "$TMP/output"; fail "missing incomplete warning"; }
if grep -q '安装成功' "$TMP/output"; then fail "false success"; fi
compgen -G "$APP_DIR/.steamcommunity302-backup.*/steamcommunity302/S302.ini" >/dev/null || fail "old backup lost"
old_fixture
CERT_FAIL=0
install_steam302 > "$TMP/output" 2>&1 || { cat "$TMP/output"; fail "successful fixture failed"; }
[ "$(steam302_installed_version)" = 15.0.9 ] || fail "version not updated"
grep -q '安装成功' "$TMP/output" || fail "missing final success"
if compgen -G "$APP_DIR/.steamcommunity302-stage.*" >/dev/null; then fail "staging leaked"; fi
if compgen -G "$APP_DIR/.steamcommunity302-backup.*" >/dev/null; then fail "backup leaked after success"; fi
steam302_v15_service_exists() { return 0; }
rm "$STEAM302_INSTALL_DIR/AppRun"
if uninstall_steam302 > "$TMP/uninstall" 2>&1; then fail "incomplete V15 orphaned its live service"; fi
[ -d "$STEAM302_INSTALL_DIR" ] || fail "removed incomplete V15 while vendor service exists"
grep -q '先更新加速工具' "$TMP/uninstall" || fail "missing incomplete uninstall warning"
echo "PASS: Steamcommunity 302 V15 migration, rollback and certificate failure"
