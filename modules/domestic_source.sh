#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"
# 复用常用软件模块中经过验证的 Flathub 国内缓存配置。
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/software.sh"

configure_domestic_flatpak() {
    require_command flatpak || return 1
    require_command timeout || return 1
    require_command curl || return 1

    echo "[2/2] 配置上海交大和中科大 Flatpak 国内缓存..."
    if ! ensure_flatpak_remotes; then
        echo "Flatpak 国内缓存配置失败，现有软件和其他来源保持不变。"
        return 1
    fi

    echo "国内下载源配置完成：${FLATHUB_CN_REMOTE}、${FLATHUB_CN_FALLBACK_REMOTE}。"
}

prepare_system_packages() {
    local readonly_disabled=0

    for command_name in steamos-readonly pacman pacman-key; do
        require_command "$command_name" || return 1
    done

    echo "[1/2] 初始化 pacman 密钥环并更新系统软件组件..."
    toolbox_sudo steamos-readonly disable || return 1
    readonly_disabled=1

    if ! toolbox_sudo pacman-key --init || \
        ! toolbox_sudo pacman-key --populate || \
        ! toolbox_sudo pacman -Syu --needed --noconfirm git flatpak; then
        [ "$readonly_disabled" -eq 0 ] || \
            toolbox_sudo steamos-readonly enable >/dev/null 2>&1 || true
        echo "系统软件组件初始化失败，已尝试恢复 SteamOS 只读保护。"
        return 1
    fi

    if ! toolbox_sudo steamos-readonly enable; then
        echo "系统组件已更新，但恢复 SteamOS 只读保护失败。"
        return 1
    fi
}

initialize_software_sources() {
    is_linux || {
        echo "初始化软件源仅支持 Linux/SteamOS。"
        return 1
    }

    echo "================================================"
    echo " 初始化软件源"
    echo "================================================"
    echo "将自动准备系统包管理、更新系统软件组件并配置 Flatpak 国内缓存。"
    echo "管理员权限会读取桌面管理员密码.txt，不会重复询问密码。"

    prepare_system_packages || return 1
    configure_domestic_flatpak || return 1

    echo ""
    echo "初始化软件源完成。现在可以正常使用工具箱安装软件。"
    echo "上海交大：$FLATHUB_CN_URL"
    echo "中科大：$FLATHUB_CN_FALLBACK_URL"
    log "软件源初始化完成：pacman系统组件和Flatpak国内双缓存已配置"
}

show_software_source_status() {
    require_command flatpak || return 1
    echo "当前用户的 Flatpak 下载源："
    flatpak remotes --user --show-details 2>/dev/null || \
        flatpak remotes --user 2>/dev/null || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-init}" in
        init|init-domestic) initialize_software_sources ;;
        enable) configure_domestic_flatpak ;;
        status) show_software_source_status ;;
        *) echo "用法: $0 {init|enable|status}"; exit 1 ;;
    esac
fi
