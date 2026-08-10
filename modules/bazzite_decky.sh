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
    require_bazzite || return 1
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
    require_bazzite || return 1
    require_command ujust || {
        echo "当前 Bazzite 缺少 ujust，无法使用官方 Decky 安装方式。"
        return 1
    }
    if bazzite_decky_is_installed; then
        echo "[已安装] Decky Loader 已存在，无需重复安装。"
        return 0
    fi

    echo "正在调用 Bazzite 官方安装入口：ujust setup-decky"
    echo "如出现系统确认窗口，请按 Bazzite 提示完成。"
    ujust setup-decky || {
        echo "Bazzite 官方 Decky 安装未完成，请查看上方提示。"
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
