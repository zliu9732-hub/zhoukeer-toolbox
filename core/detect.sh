#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform.sh"

REPORT_MODE=0
case "${1:-}" in
    "") ;;
    --report) REPORT_MODE=1 ;;
    *) echo "用法: $0 [--report]"; exit 1 ;;
esac

if [ "$REPORT_MODE" -eq 1 ]; then
    REPORT_FILE="$HOME/Desktop/周克儿工具箱诊断报告.txt"
    mkdir -p "$HOME/Desktop" || exit 1
    exec > >(tee "$REPORT_FILE") 2>&1
fi

echo "======设备检测======"

SYSTEM=$(uname)
detect_platform

echo "系统：$SYSTEM"
echo "发行版：$PLATFORM_NAME"

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "系统版本：${PRETTY_NAME:-${NAME:-未知}}"
fi

if [ -f /etc/os-release ]; then
    echo "Linux系统"
fi

if [[ "$SYSTEM" == "Darwin" ]]; then
    echo "Mac系统"
fi

if [ "$IS_STEAMOS" -eq 1 ]; then
    echo "SteamOS环境：是"
else
echo "SteamOS环境：否"
fi

echo "设备架构：$(uname -m)"
if [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
    echo "用户目录剩余空间：$(df -h "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 " 可用（" $5 " 已用）" }')"
fi
if command -v ip >/dev/null 2>&1 && ip route show default 2>/dev/null | grep -q '^default'; then
    echo "网络状态：已检测到默认网络路由"
else
    echo "网络状态：未检测到默认网络路由"
fi

echo "应用安装状态："
if [ -x "$APP_DIR/QQ.AppImage" ]; then
    echo "- QQ：已安装（腾讯官方AppImage）"
else
    echo "- QQ：未安装"
fi
if [ -x "$APP_DIR/WeChat.AppImage" ]; then
    echo "- 微信：已安装（腾讯官方AppImage）"
else
    echo "- 微信：未安装"
fi
if [ -x "$APP_DIR/firefox/firefox" ]; then
    echo "- Firefox：已安装（完整包）"
else
    echo "- Firefox：未安装"
fi
if command -v flatpak >/dev/null 2>&1; then
    for app_entry in \
        'RustDesk:com.rustdesk.RustDesk' \
        'AnyDesk:com.anydesk.Anydesk'; do
        app_name="${app_entry%%:*}"
        app_id="${app_entry#*:}"
        if flatpak info "$app_id" >/dev/null 2>&1; then
            echo "- $app_name：已安装"
        else
            echo "- $app_name：未安装"
        fi
    done
fi

if [ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logger.sh" ]; then
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logger.sh"
    log "已查看系统信息: $PLATFORM_NAME"
fi

echo "=================="
if [ "$REPORT_MODE" -eq 1 ]; then
    echo "诊断报告已保存到：$REPORT_FILE"
fi
