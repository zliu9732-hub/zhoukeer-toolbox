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
    printf '################################# 42.0%%\n'
    echo 'Warning: Problem : timeout. Will retry in 1 seconds. 2 retries left.'
    echo 'curl: (28) Operation timed out after 1000 milliseconds'
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
if grep -Eiq 'timeout|retry|curl:' "$DIALOG_LOG"; then
    echo "FAIL: 图形失败提示仍显示 curl 英文超时或重试信息" >&2
    exit 1
fi
grep -Fq '42.0%' "$DIALOG_LOG" || {
    echo "FAIL: 过滤英文网络提示时误删了百分比进度" >&2
    exit 1
}
grep -R -Fq 'Warning: Problem : timeout' "$LOG_DIR" || {
    echo "FAIL: 被隐藏的英文技术信息没有保留在动作日志" >&2
    exit 1
}
grep -Fq '完整日志：' "$DIALOG_LOG" || {
    echo "FAIL: 图形失败提示没有提供日志位置" >&2
    exit 1
}

echo "PASS: 图形动作保留百分比、隐藏英文网络提示并在失败时返回非零"
