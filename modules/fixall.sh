#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/safety.sh"

echo "一键修复模式"

detect_platform

echo "1. 网络状态检测"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "网络正常"
    log "一键修复: 网络检测正常"
else
    echo "网络异常，请检查 Wi-Fi、DNS 或路由器设置"
    log "一键修复: 网络检测异常"
fi

echo "2. Steam缓存清理"
safe_remove_contents "$HOME/.steam/steam/steamapps/downloading" "Steam下载缓存"

echo "3. DNS刷新"
if is_macos; then
    echo "当前是macOS开发环境，未执行需要管理员权限的DNS刷新。"
elif is_linux; then
    echo "SteamOS/Linux下DNS刷新通常需要重启网络服务，已跳过管理员操作。"
    echo "如需处理，请在Steam Deck系统设置中断开并重新连接网络。"
else
    echo "未知系统，跳过DNS刷新。"
fi

echo "完成"
