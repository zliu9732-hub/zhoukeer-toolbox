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
assert_contains "$module_text" 'import_yuzu_keys' "缺少 Yuzu 用户自备密钥导入"
assert_contains "$module_text" 'yuzu_key_file_is_valid' "Yuzu 密钥文件未校验"
assert_contains "$module_text" 'YUZU_KEY_MAX_BYTES=1048576' "Yuzu 密钥缺少大小限制"
assert_contains "$module_text" 'chmod 600' "Yuzu 密钥未限制为仅本人可读"
assert_contains "$module_text" '不会下载、生成、分享或显示密钥内容' "Yuzu 密钥导入缺少安全说明"

for icon in yuzu cemu duckstation pcsx2 rpcs3 shadps4; do
    [ -s "$PROJECT_ROOT/assets/emulators/$icon.png" ] || fail "缺少模拟器专用图标：$icon"
    assert_contains "$module_text" "assets/emulators/$icon.png" "模拟器未使用专用图标：$icon"
done
assert_not_contains "$module_text" 'assets/icon-round.png' "模拟器桌面入口仍使用工具箱图标"

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

for forbidden in EmuDeck Azahar Pegasus 'ES-DE'; do
    assert_not_contains "$module_text" "$forbidden" "不应纳入的模拟器或前端：$forbidden"
done

echo "PASS: 模拟器下载、桌面入口与 Steam 入库逻辑完整"
