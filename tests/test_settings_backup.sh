#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
HOME_DIR="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
FLATPAK_STATE="$TMP_ROOT/flatpak-remotes"
mkdir -p "$HOME_DIR/Desktop" "$HOME_DIR/.local/share/applications" "$TMP_ROOT/etc" "$TMP_ROOT/backups" "$BIN_DIR" "$TMP_ROOT/steam302"

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$BIN_DIR/flatpak" <<'EOF'
#!/bin/sh
case "$1" in
    remote-list) [ ! -f "$FLATPAK_STATE" ] || cat "$FLATPAK_STATE" ;;
    remote-delete)
        remote="${4:-}"
        grep -Fvx "$remote" "$FLATPAK_STATE" > "$FLATPAK_STATE.tmp" 2>/dev/null || true
        mv "$FLATPAK_STATE.tmp" "$FLATPAK_STATE"
        ;;
    remote-add) printf '%s\n' "${5:-}" >> "$FLATPAK_STATE" ;;
esac
EOF
chmod +x "$BIN_DIR/flatpak"
: > "$FLATPAK_STATE"

CONFIG="$TMP_ROOT/settings.conf"
ZRAM="$TMP_ROOT/etc/zram.conf"
SYSCTL="$TMP_ROOT/etc/memory.conf"
STEAM302="$TMP_ROOT/steam302/S302.ini"
printf 'TOOLBOX_NAME="Renkit"\nGITHUB_DOWNLOAD_PROXY="https://user:secret@proxy.example"\n' > "$CONFIG"
printf '# Managed by Zhoukeer Toolbox\nzram-size = ram / 2\n' > "$ZRAM"
printf '# Managed by Zhoukeer Toolbox\nvm.swappiness = 1\n' > "$SYSCTL"
printf '[Rules]\nenabled = Steam_store,github\n' > "$STEAM302"
cat > "$HOME_DIR/Desktop/Test.desktop" <<'EOF'
[Desktop Entry]
Name=Test
Exec=/tmp/test
X-Zhoukeer-Managed=true
EOF

result="$(HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" FLATPAK_STATE="$FLATPAK_STATE" ZHOUKEER_TEST_MODE=1 ZHOUKEER_AUTO_CONFIRM=1 \
    MODULE="$PROJECT_ROOT/modules/settings_backup.sh" CONFIG="$CONFIG" ZRAM="$ZRAM" SYSCTL="$SYSCTL" \
    STEAM302="$STEAM302" BACKUPS="$TMP_ROOT/backups" TMP_ROOT="$TMP_ROOT" bash -c '
        source "$MODULE"
        CONFIG_FILE="$CONFIG"
        SETTINGS_MEMORY_ZRAM="$ZRAM"
        SETTINGS_MEMORY_SYSCTL="$SYSCTL"
        SETTINGS_MEMORY_SYSTEMD_DIR="$TMP_ROOT/no-units"
        SETTINGS_PACMAN_CONF="$TMP_ROOT/no-pacman"
        SETTINGS_STEAM302_CONFIG="$STEAM302"
        SETTINGS_BACKUP_OUTPUT_DIR="$BACKUPS"
        create_settings_backup
    ')"
archive="$(printf '%s\n' "$result" | tail -n 1)"
[ -f "$archive" ] && [ -f "$archive.sha256" ] || fail "备份文件或 SHA256 缺失"
if tar -xOf "$archive" zhoukeer-settings/config/settings.conf | grep -Fq 'secret'; then fail "备份泄露代理认证"; fi

printf 'TOOLBOX_NAME="已修改"\n' > "$CONFIG"
printf '# Managed by Zhoukeer Toolbox\nzram-size = ram\n' > "$ZRAM"
printf 'changed\n' > "$HOME_DIR/Desktop/Test.desktop"
printf '[Rules]\nenabled = Steam_API\n' > "$STEAM302"
printf 'flathub-cn\n' > "$FLATPAK_STATE"

HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" FLATPAK_STATE="$FLATPAK_STATE" ZHOUKEER_TEST_MODE=1 ZHOUKEER_AUTO_CONFIRM=1 \
    MODULE="$PROJECT_ROOT/modules/settings_backup.sh" CONFIG="$CONFIG" ZRAM="$ZRAM" SYSCTL="$SYSCTL" \
    STEAM302="$STEAM302" BACKUPS="$TMP_ROOT/backups" ARCHIVE="$archive" TMP_ROOT="$TMP_ROOT" bash -c '
        source "$MODULE"
        CONFIG_FILE="$CONFIG"
        SETTINGS_MEMORY_ZRAM="$ZRAM"
        SETTINGS_MEMORY_SYSCTL="$SYSCTL"
        SETTINGS_MEMORY_SYSTEMD_DIR="$TMP_ROOT/no-units"
        SETTINGS_PACMAN_CONF="$TMP_ROOT/no-pacman"
        SETTINGS_STEAM302_CONFIG="$STEAM302"
        SETTINGS_BACKUP_OUTPUT_DIR="$BACKUPS"
        toolbox_sudo() { "$@"; }
        restore_settings_backup "$ARCHIVE"
    ' > "$TMP_ROOT/restore.output"
grep -Fq 'TOOLBOX_NAME="Renkit"' "$CONFIG" || fail "Renkit配置未恢复"
grep -Fq 'zram-size = ram / 2' "$ZRAM" || fail "内存参数未恢复"
grep -Fq 'X-Zhoukeer-Managed=true' "$HOME_DIR/Desktop/Test.desktop" || fail "Renkit快捷方式未恢复"
grep -Fq 'enabled = Steam_store,github' "$STEAM302" || fail "Steam302 规则未恢复"
if grep -Fxq 'flathub-cn' "$FLATPAK_STATE"; then fail "国内缓存缺席状态未恢复"; fi
grep -Fq '恢复前备份' "$TMP_ROOT/restore.output" || fail "恢复前没有自动备份当前状态"

printf 'tamper' >> "$archive"
if HOME="$HOME_DIR" ZHOUKEER_TEST_MODE=1 ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/settings_backup.sh" restore "$archive" >/dev/null 2>&1; then
    fail "被篡改的备份仍被恢复"
fi

echo "PASS: 设置备份范围、权限、恢复前备份、内存/快捷方式恢复和篡改拦截测试通过"
