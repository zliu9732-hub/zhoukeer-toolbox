#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/emulators.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local text="$1" expected="$2" label="$3"
    grep -Fq -- "$expected" <<< "$text" || fail "$label"
}

assert_not_contains() {
    local text="$1" unexpected="$2" label="$3"
    if grep -Fq -- "$unexpected" <<< "$text"; then
        fail "$label"
    fi
}

bash -n "$MODULE"
module_text="$(cat "$MODULE")"

assert_contains "$module_text" 'download_github_release' "模拟器下载未复用安全下载器"
assert_contains "$module_text" 'emulator_file_is_valid' "模拟器文件缺少格式校验"
assert_contains "$module_text" '_github_sha256' "已下载的模拟器未复检 SHA256"
assert_contains "$module_text" 'create_emulator_desktop_shortcut' "模拟器未创建桌面入口"
assert_contains "$module_text" 'add_emulator_to_steam' "模拟器未添加 Steam 库"
assert_contains "$module_text" 'stop_steam_for_vdf' "写入 Steam 前未安全退出 Steam"
assert_contains "$module_text" 'set-icon' "Steam 条目未设置图标"
assert_contains "$module_text" 'verify' "Steam 条目未校验"
assert_contains "$module_text" 'install_flatpak_emulator' "缺少 Flatpak 模拟器安装"
assert_contains "$module_text" 'org.ppsspp.PPSSPP' "缺少 PPSSPP Flatpak 应用 ID"
assert_contains "$module_text" 'io.mgba.mGBA' "缺少 mGBA Flatpak 应用 ID"
assert_contains "$module_text" '--launch-options' "Flatpak 模拟器 Steam 条目未使用启动参数"
assert_contains "$module_text" 'install_azahar_emulator' "缺少 Azahar 3DS 模拟器安装"
assert_contains "$module_text" 'azahar_key_file_is_valid' "Azahar 3DS 密钥未校验"
assert_contains "$module_text" 'import_azahar_keys' "缺少 Azahar 3DS 密钥导入"
assert_contains "$module_text" 'aes_keys.txt' "Azahar 未使用 aes_keys.txt"
assert_contains "$module_text" 'Applications/3ds' "Azahar 未使用用户本地安装路径"
assert_contains "$module_text" '[ -e "$YUZU_KEY_IMPORT_DIR/prod.keys" ]' "Yuzu 密钥仅在本人备份存在时自动导入"
assert_contains "$module_text" 'import_yuzu_keys || true' "Yuzu 安装后未自动导入密钥"
assert_contains "$module_text" '[ -e "$AZAHAR_KEYS_IMPORT_DIR/aes_keys.txt" ]' "Azahar 密钥仅在本人备份存在时自动导入"
assert_contains "$module_text" 'import_yuzu_keys' "缺少 Yuzu 用户自备密钥导入"
assert_contains "$module_text" 'yuzu_key_file_is_valid' "Yuzu 密钥文件未校验"
assert_contains "$module_text" 'YUZU_KEY_MAX_BYTES=1048576' "Yuzu 密钥缺少大小限制"
assert_contains "$module_text" 'chmod 600' "Yuzu 密钥未限制为仅本人可读"
assert_contains "$module_text" '不会下载、生成、分享或显示密钥内容' "Yuzu 密钥导入缺少安全说明"

for icon in yuzu cemu duckstation pcsx2 rpcs3 shadps4; do
    [ -s "$PROJECT_ROOT/assets/emulators/$icon.png" ] || fail "缺少模拟器专用图标：$icon"
    assert_contains "$module_text" "assets/emulators/$icon.png" "模拟器未使用专用图标：$icon"
done
assert_not_contains "$module_text" 'assets/icon-round.png' "模拟器桌面入口仍使用Renkit图标"

KEY_TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$KEY_TEST_ROOT"' EXIT
(
    source "$MODULE"
    require_steamos() { return 0; }
    log() { :; }
    YUZU_KEY_IMPORT_DIR="$KEY_TEST_ROOT/import"
    YUZU_KEYS_DIR="$KEY_TEST_ROOT/keys"
    mkdir -p "$YUZU_KEY_IMPORT_DIR"
    printf '%s\n' 'master_key_00 = 0123456789abcdef0123456789abcdef' > "$YUZU_KEY_IMPORT_DIR/prod.keys"
    printf '%s\n' 'titlekek_00 = 0123456789abcdef0123456789abcdef' > "$YUZU_KEY_IMPORT_DIR/title.keys"
    ZHOUKEER_AUTO_CONFIRM=1 import_yuzu_keys >/dev/null
    [ -f "$YUZU_KEYS_DIR/prod.keys" ] || exit 1
    [ -f "$YUZU_KEYS_DIR/title.keys" ] || exit 1
    [ ! -L "$YUZU_KEYS_DIR/prod.keys" ] || exit 1
    [ "$(stat -f '%Lp' "$YUZU_KEYS_DIR/prod.keys")" = "600" ] || exit 1
)

for action in yuzu cemu duckstation pcsx2 rpcs3 shadps4; do
    assert_contains "$module_text" ") EMULATOR_NAME=" "模拟器详情缺失"
    assert_contains "$module_text" "$action" "模拟器动作缺失：$action"
done

for forbidden in EmuDeck Pegasus 'ES-DE'; do
    assert_not_contains "$module_text" "$forbidden" "不应纳入的模拟器或前端：$forbidden"
done

# 模拟器卸载会移除 Steam 条目、桌面入口和程序本体，保留存档与配置。
UNINSTALL_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$KEY_TEST_ROOT" "$UNINSTALL_ROOT"' EXIT
UNINSTALL_HOME="$UNINSTALL_ROOT/home"
UNINSTALL_EMULATORS="$UNINSTALL_ROOT/emulators"
UNINSTALL_BIN="$UNINSTALL_ROOT/bin"
mkdir -p "$UNINSTALL_HOME/Desktop" "$UNINSTALL_HOME/.local/share/applications" \
    "$UNINSTALL_EMULATORS" "$UNINSTALL_ROOT/steam/steamapps" "$UNINSTALL_BIN"

cat > "$UNINSTALL_BIN/flatpak" <<'EOF'
#!/bin/sh
state="${FLATPAK_TEST_STATE:?}"
command="$1"
shift
case "$command" in
    info)
        case "${1:-}" in --user|--system) shift ;; esac
        [ -f "$state/installed.$1" ]
        ;;
    uninstall)
        printf 'uninstall %s\n' "$*" >> "$state/commands"
        app_id=""
        for arg in "$@"; do
            case "$arg" in --*) ;; *) app_id="$arg" ;; esac
        done
        rm -f "$state/installed.$app_id"
        ;;
    *)
        echo "unexpected flatpak command: $command" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$UNINSTALL_BIN/flatpak"
: > "$UNINSTALL_ROOT/installed.org.ppsspp.PPSSPP"
: > "$UNINSTALL_ROOT/commands"

printf '\177ELFtest-yuzu\n' > "$UNINSTALL_EMULATORS/Yuzu.AppImage"
chmod +x "$UNINSTALL_EMULATORS/Yuzu.AppImage"
cat > "$UNINSTALL_HOME/Desktop/Yuzu（Switch 模拟器）.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Yuzu（Switch 模拟器）
Exec=/fake/Yuzu.AppImage
Icon=/fake/yuzu.png
Categories=Game;Emulator;
X-Zhoukeer-Managed=true
EOF

UNINSTALL_SHORTCUTS="$UNINSTALL_ROOT/shortcuts.vdf"
python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" --shortcut-file "$UNINSTALL_SHORTCUTS" add \
    --name "Yuzu（Switch 模拟器）" --exe "$UNINSTALL_EMULATORS/Yuzu.AppImage" \
    --start-dir "$UNINSTALL_EMULATORS" >/dev/null
python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" --shortcut-file "$UNINSTALL_SHORTCUTS" add \
    --name "PPSSPP（PSP 模拟器）" --exe "/usr/bin/flatpak" --start-dir "$UNINSTALL_HOME" \
    --launch-options "run org.ppsspp.PPSSPP" >/dev/null
python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" --shortcut-file "$UNINSTALL_SHORTCUTS" add \
    --name "mGBA（GBA 模拟器）" --exe "/usr/bin/flatpak" --start-dir "$UNINSTALL_HOME" \
    --launch-options "run io.mgba.mGBA" >/dev/null

(
    export ZHOUKEER_EMULATOR_DIR="$UNINSTALL_EMULATORS"
    source "$MODULE"
    require_steamos() { return 0; }
    HOME="$UNINSTALL_HOME" \
    ZHOUKEER_STEAM_ROOT="$UNINSTALL_ROOT/steam" \
    ZHOUKEER_SHORTCUT_FILE="$UNINSTALL_SHORTCUTS" \
    ZHOUKEER_SKIP_STEAM_RESTART=1 \
    ZHOUKEER_AUTO_CONFIRM=1 \
    uninstall_emulator yuzu >/dev/null
)
(
    export ZHOUKEER_EMULATOR_DIR="$UNINSTALL_EMULATORS"
    source "$MODULE"
    require_steamos() { return 0; }
    HOME="$UNINSTALL_HOME" \
    ZHOUKEER_STEAM_ROOT="$UNINSTALL_ROOT/steam" \
    ZHOUKEER_SHORTCUT_FILE="$UNINSTALL_SHORTCUTS" \
    ZHOUKEER_SKIP_STEAM_RESTART=1 \
    ZHOUKEER_AUTO_CONFIRM=1 \
    FLATPAK_TEST_STATE="$UNINSTALL_ROOT" \
    PATH="$UNINSTALL_BIN:$PATH" \
    uninstall_emulator ppsspp >/dev/null
)

[ ! -e "$UNINSTALL_EMULATORS/Yuzu.AppImage" ] || fail "Yuzu 程序本体未移除"
[ ! -e "$UNINSTALL_HOME/Desktop/Yuzu（Switch 模拟器）.desktop" ] || fail "Yuzu 桌面入口未移除"
[ ! -e "$UNINSTALL_ROOT/installed.org.ppsspp.PPSSPP" ] || fail "PPSSPP Flatpak 未卸载"
assert_contains "$(cat "$UNINSTALL_ROOT/commands")" \
    'uninstall --user --noninteractive -y org.ppsspp.PPSSPP' "PPSSPP 卸载命令缺失"
python3 - "$UNINSTALL_SHORTCUTS" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert "Yuzu（Switch 模拟器）".encode() not in data
assert "PPSSPP（PSP 模拟器）".encode() not in data
assert "mGBA（GBA 模拟器）".encode() in data
PY

echo "PASS: 模拟器下载、桌面入口与 Steam 入库逻辑完整"
