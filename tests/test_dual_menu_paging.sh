#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
CHOICES="$TMP_ROOT/choices"
DIALOG_LOG="$TMP_ROOT/dialog.log"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/gui.sh"

printf '%s\n' next previous home > "$CHOICES"
gui_dialog() {
    local choice remaining="$TMP_ROOT/choices.next"

    printf '%s\n' "$*" >> "$DIALOG_LOG"
    choice="$(sed -n '1p' "$CHOICES")"
    sed '1d' "$CHOICES" > "$remaining"
    mv -- "$remaining" "$CHOICES"
    printf '%s\n' "$choice"
}

GUI_NAV_HOME=0
dual_system_menu || fail "双系统 GUI 分页模拟执行失败"

[ "$(grep -Fc '双系统用户专用｜磁盘与互通盘｜第 1/2 页' "$DIALOG_LOG")" -eq 2 ] || \
    fail "第一页没有在进入和返回时正确显示"
[ "$(grep -Fc '更多双系统工具｜只读检查、恢复与引导清理｜第 2/2 页' "$DIALOG_LOG")" -eq 1 ] || \
    fail "点击更多双系统工具后没有显示第二页"
[ "$GUI_NAV_HOME" -eq 1 ] || fail "分页后返回首页状态错误"

echo "PASS: 双系统 GUI 可进入第二页、返回第一页并安全返回首页"
