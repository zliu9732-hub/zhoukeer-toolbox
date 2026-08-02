#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/gui.sh"

LOG_DIR="$TMP_ROOT/logs"
DIALOG_LOG="$TMP_ROOT/dialog.log"
print_header() { :; }
print_section_title() { :; }
gui_dialog() { printf '%s\n' "$*" > "$DIALOG_LOG"; }

failing_clover_action() {
    echo "无法确认 EFI 系统分区对应的块设备。"
    return 1
}

if run_gui_action "安装 Clover 开机菜单" failing_clover_action; then
    echo "FAIL: 图形动作失败后仍返回成功" >&2
    exit 1
fi

grep -Fq '无法确认 EFI 系统分区对应的块设备。' "$DIALOG_LOG" || {
    echo "FAIL: 图形失败提示没有显示模块具体错误" >&2
    exit 1
}
grep -Fq '完整日志：' "$DIALOG_LOG" || {
    echo "FAIL: 图形失败提示没有提供日志位置" >&2
    exit 1
}

echo "PASS: 图形动作失败会返回非零并显示最近错误与日志位置"
