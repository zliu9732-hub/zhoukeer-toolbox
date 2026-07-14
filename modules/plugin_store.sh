#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

DECKY_INSTALLER_URL="https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh"
DECKY_INSTALLER_SHA256="e926a9215efdb6a1449f7fe9e703a8b2495d5be53ab5c7abc4c3968ead472b0b"

calculate_decky_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

confirm_decky_install() {
    local answer

    echo "将安装官方Decky Loader插件商城。"
    echo "安装器会请求管理员权限并从GitHub下载最新版PluginLoader。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

install_plugin_store() {
    local tmp_dir
    local installer
    local actual_sha256

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "插件商城安装仅支持真实SteamOS环境。"
        return 1
    fi
    for command_name in curl jq sudo; do
        require_command "$command_name" || return 1
    done
    confirm_decky_install || {
        echo "已取消插件商城安装。"
        return 0
    }

    tmp_dir="$(mktemp -d)" || return 1
    installer="$tmp_dir/install_release.sh"
    trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM

    if ! curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time 120 \
        --retry 3 \
        --output "$installer" \
        "$DECKY_INSTALLER_URL"; then
        echo "Decky官方安装器下载失败。"
        return 1
    fi

    actual_sha256="$(calculate_decky_sha256 "$installer")" || {
        echo "无法校验Decky安装器。"
        return 1
    }
    if [ "$actual_sha256" != "$DECKY_INSTALLER_SHA256" ]; then
        echo "Decky安装器已发生变化，为避免执行未经审查的新脚本，已停止。"
        echo "请更新周克儿工具箱后再试。"
        log "Decky安装停止: 安装器SHA256变化"
        return 1
    fi
    bash -n "$installer" || {
        echo "Decky安装器语法检查失败。"
        return 1
    }

    echo "正在启动Decky官方安装器..."
    if sh "$installer"; then
        echo "Decky Loader安装完成，请返回游戏模式检查插件菜单。"
        log "Decky Loader安装完成"
    else
        echo "Decky Loader安装失败。"
        log "Decky Loader安装失败"
        return 1
    fi

    rm -rf -- "$tmp_dir"
    trap - EXIT INT TERM
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_plugin_store
fi
