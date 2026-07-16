#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform.sh"

REPORT_MODE=0
HEALTH_MODE=0
case "${1:-}" in
    "") ;;
    --report) REPORT_MODE=1 ;;
    --health) REPORT_MODE=1; HEALTH_MODE=1 ;;
    *) echo "用法: $0 [--report|--health]"; exit 1 ;;
esac

if [ "$REPORT_MODE" -eq 1 ]; then
    REPORT_FILE="$HOME/Desktop/周克儿工具箱诊断报告.txt"
    mkdir -p "$HOME/Desktop" || exit 1
    exec > >(tee "$REPORT_FILE") 2>&1
fi

echo "======设备检测======"

PASS_COUNT=0
WARN_COUNT=0
health_pass() {
    echo "✓ $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

health_warn() {
    echo "! $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

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
    health_pass "已识别 SteamOS 环境"
else
    echo "SteamOS环境：否"
    health_warn "未识别到 SteamOS；部分 Deck 专用功能可能不可用"
fi

echo "设备架构：$(uname -m)"
if [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
    AVAILABLE_KB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    echo "用户目录剩余空间：$(df -h "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 " 可用（" $5 " 已用）" }')"
    if [ "${AVAILABLE_KB:-0}" -ge 10485760 ]; then
        health_pass "存储空间充足"
    else
        health_warn "可用空间不足 10GB，建议清理下载或着色器缓存"
    fi
fi
if command -v ip >/dev/null 2>&1 && ip route show default 2>/dev/null | grep -q '^default'; then
    echo "网络状态：已检测到默认网络路由"
    health_pass "已检测到网络连接"
else
    echo "网络状态：未检测到默认网络路由"
    health_warn "未检测到网络连接，请先确认 Wi-Fi 或网线"
fi

if command -v getent >/dev/null 2>&1 && getent hosts store.steampowered.com >/dev/null 2>&1; then
    health_pass "Steam 商店域名解析正常"
else
    health_warn "无法解析 Steam 商店域名，下载或商店可能异常"
fi

if [ -d "$HOME/homebrew/plugins" ] || [ -d "$HOME/.local/share/decky-loader" ]; then
    health_pass "已检测到 Decky Loader"
else
    health_warn "未检测到 Decky Loader；如需插件商城可在工具箱内安装"
fi

if command -v flatpak >/dev/null 2>&1; then
    if flatpak remotes --user 2>/dev/null | grep -Eq 'sjtu|ustc|flathub'; then
        health_pass "已检测到用户级 Flatpak 软件源"
    else
        health_warn "未检测到用户级 Flatpak 软件源，部分软件安装可能较慢"
    fi
else
    health_warn "未检测到 Flatpak，部分桌面软件无法安装"
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
if [ -x "$APP_DIR/RustDesk.AppImage" ]; then
    echo "- RustDesk：已安装（官方 GitHub AppImage）"
else
    echo "- RustDesk：未安装"
fi

if [ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logger.sh" ]; then
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logger.sh"
    log "已查看系统信息: $PLATFORM_NAME"
fi

echo "=================="
if [ "$REPORT_MODE" -eq 1 ]; then
    if [ "$HEALTH_MODE" -eq 1 ]; then
        echo "体检结果：$PASS_COUNT 项正常，$WARN_COUNT 项需要留意"
        if [ "$WARN_COUNT" -eq 0 ]; then
            echo "建议：当前基础环境正常，可以继续使用。"
        else
            echo "建议：按上方带 ! 的提示逐项处理；体检本身没有修改任何系统设置。"
        fi
    fi
    echo "诊断报告已保存到：$REPORT_FILE"
fi
