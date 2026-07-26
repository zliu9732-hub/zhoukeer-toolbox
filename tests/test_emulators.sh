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

for action in yuzu cemu duckstation pcsx2 rpcs3 shadps4; do
    assert_contains "$module_text" ") EMULATOR_NAME=" "模拟器详情缺失"
    assert_contains "$module_text" "$action" "模拟器动作缺失：$action"
done

for forbidden in EmuDeck Azahar Pegasus 'ES-DE'; do
    assert_not_contains "$module_text" "$forbidden" "不应纳入的模拟器或前端：$forbidden"
done

echo "PASS: 模拟器下载、桌面入口与 Steam 入库逻辑完整"
