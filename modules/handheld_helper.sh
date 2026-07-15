#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

show_shortcuts() {
    echo "======掌机常用快捷键======"
    echo "Steam + X：呼出屏幕键盘"
    echo "长按 Steam：查看全部快捷键"
    echo "桌面模式右触控板：移动鼠标"
    echo "桌面模式 R2：左键点击；L2：右键点击"
    echo "回游戏模式：点击桌面上的“Return to Gaming Mode”图标"
    echo "提示：这些是说明页面，不会修改按键设置。"
    log "已查看掌机常用快捷键"
}

check_peripherals() {
    echo "======外接设备检查======"
    echo "说明：本检查只读取状态，不会改显示或蓝牙设置。"

    if command -v kscreen-doctor >/dev/null 2>&1; then
        output_count="$(kscreen-doctor -o 2>/dev/null | grep -c '^Output:' || true)"
        echo "显示输出：检测到 $output_count 个"
        if [ "$output_count" -gt 1 ]; then
            echo "✓ 已检测到外接显示器或扩展坞输出"
        else
            echo "! 未检测到额外显示输出；请检查扩展坞供电、线材和显示器输入源"
        fi
    else
        echo "! 当前系统没有显示输出检测工具；请在桌面模式的显示设置中确认。"
    fi

    if command -v bluetoothctl >/dev/null 2>&1; then
        paired_count="$(bluetoothctl devices Paired 2>/dev/null | wc -l)"
        connected_count="$(bluetoothctl devices Connected 2>/dev/null | wc -l)"
        echo "蓝牙设备：已配对 $paired_count 个，已连接 $connected_count 个"
    else
        echo "! 当前未找到蓝牙检测工具。"
    fi

    echo "提示：电视建议打开游戏模式并关闭动态插帧，能减少延迟。"
    log "已执行外接设备检查"
}

case "${1:-}" in
    shortcuts) show_shortcuts ;;
    peripherals) check_peripherals ;;
    *) echo "用法: $0 [shortcuts|peripherals]"; exit 1 ;;
esac
