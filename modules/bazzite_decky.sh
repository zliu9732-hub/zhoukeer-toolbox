#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

bazzite_decky_is_installed() {
    [ -x "$HOME/homebrew/services/PluginLoader" ] || \
        [ -x "$HOME/.local/share/decky-loader/services/PluginLoader" ]
}

bazzite_decky_status() {
    require_desktop_linux || return 1
    if bazzite_decky_is_installed; then
        echo "Decky Loader：已安装"
        if command -v systemctl >/dev/null 2>&1 && \
            systemctl is-active --quiet plugin_loader.service 2>/dev/null; then
            echo "Decky 服务：正在运行"
        else
            echo "Decky 服务：未确认运行状态，可进入游戏模式检查"
        fi
        return 0
    fi
    echo "Decky Loader：未安装"
    return 0
}

install_bazzite_decky() {
    local recipes
    require_desktop_linux || return 1
    if bazzite_decky_is_installed; then
        echo "[已安装] Decky Loader 已存在，无需重复安装。"
        return 0
    fi

    if ! command -v ujust >/dev/null 2>&1; then
        echo "未检测到插件商城；请先通过当前系统支持的方式安装 Decky Loader，再返回安装插件。"
        return 1
    fi
    if [ "$IS_BAZZITE" -ne 1 ]; then
        recipes="$(ujust --list 2>/dev/null)" || {
            echo "无法读取当前系统的插件商城安装入口，请先安装 Decky Loader 后重试。"
            return 1
        }
        if ! grep -Eq '^[[:space:]]*setup-decky([[:space:]]|$)' <<< "$recipes"; then
            echo "当前系统未提供插件商城安装入口，请先安装 Decky Loader 后重试。"
            return 1
        fi
    fi
    echo "正在调用系统提供的插件商城安装入口…"
    echo "如出现系统确认窗口，请按系统提示完成。"
    ujust setup-decky || {
        echo "插件商城安装未完成，请查看上方提示。"
        return 1
    }
    if ! bazzite_decky_is_installed; then
        echo "官方安装命令已结束，但尚未检测到 Decky 文件；请重启或进入游戏模式后检查。"
        return 1
    fi
    log "Bazzite Decky Loader 安装完成"
    echo "Decky Loader 安装完成。"
}

case "${1:-status}" in
    install) install_bazzite_decky ;;
    status) bazzite_decky_status ;;
    *) echo "用法: $0 {install|status}"; exit 1 ;;
esac
