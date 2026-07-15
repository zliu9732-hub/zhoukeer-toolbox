#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# 复用常用软件模块中已经过测试的 Flathub 国内缓存配置。
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/software.sh"

configure_domestic_source() {
    is_linux || {
        echo "国内下载源配置仅支持 Linux/SteamOS。"
        return 1
    }
    require_command flatpak || return 1
    require_command curl || return 1

    echo "正在添加上海交大和中科大两个用户级 Flathub 缓存源..."
    echo "不会修改 SteamOS 只读系统分区，也不会删除用户已有的其他来源。"
    if ! ensure_flatpak_remotes; then
        echo "国内下载源配置失败，现有软件和其他下载源保持不变。"
        return 1
    fi

    echo "国内下载源配置完成：${FLATHUB_CN_REMOTE}、${FLATHUB_CN_FALLBACK_REMOTE}"
    echo "上海交大：$FLATHUB_CN_URL"
    echo "中科大：$FLATHUB_CN_FALLBACK_URL"
    log "Flathub国内双缓存源配置完成"
}

show_domestic_source_status() {
    require_command flatpak || return 1
    echo "当前用户的 Flatpak 下载源："
    flatpak remotes --user --show-details 2>/dev/null || \
        flatpak remotes --user 2>/dev/null || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-enable}" in
        enable) configure_domestic_source ;;
        status) show_domestic_source_status ;;
        *) echo "用法: $0 {enable|status}"; exit 1 ;;
    esac
fi
