#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

software_details() {
    case "$1" in
        wechat)
            SOFTWARE_NAME="微信"
            SOFTWARE_APP_ID="com.tencent.WeChat"
            ;;
        qq)
            SOFTWARE_NAME="QQ"
            SOFTWARE_APP_ID="com.qq.QQ"
            ;;
        protonup)
            SOFTWARE_NAME="ProtonUp-Qt兼容层管理器"
            SOFTWARE_APP_ID="net.davidotek.pupgui2"
            ;;
        *)
            echo "未知软件: $1"
            return 1
            ;;
    esac
}

confirm_software_install() {
    local answer

    echo "将通过Flathub以当前用户身份安装：$SOFTWARE_NAME"
    echo "应用ID：$SOFTWARE_APP_ID"
    case "$SOFTWARE_APP_ID" in
        com.tencent.WeChat|com.qq.QQ)
            echo "注意：Flathub页面将该应用标记为非腾讯官方验证的社区封装。"
            ;;
    esac

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

ensure_flathub() {
    if flatpak remotes --user --columns=name 2>/dev/null | grep -Fxq flathub; then
        return 0
    fi

    echo "正在添加Flathub用户源..."
    flatpak remote-add \
        --user \
        --if-not-exists \
        flathub \
        https://flathub.org/repo/flathub.flatpakrepo
}

install_software() {
    local target="$1"

    software_details "$target" || return 1
    is_linux || {
        echo "$SOFTWARE_NAME 安装仅支持Linux/SteamOS。"
        return 1
    }
    require_command flatpak || return 1

    if flatpak info "$SOFTWARE_APP_ID" >/dev/null 2>&1; then
        echo "$SOFTWARE_NAME 已安装。"
        return 0
    fi

    confirm_software_install || {
        echo "已取消安装 $SOFTWARE_NAME。"
        return 0
    }
    ensure_flathub || {
        echo "Flathub配置失败。"
        return 1
    }

    echo "正在安装 $SOFTWARE_NAME..."
    if flatpak install --user --noninteractive -y flathub "$SOFTWARE_APP_ID"; then
        echo "$SOFTWARE_NAME 安装完成。"
        log "$SOFTWARE_NAME Flatpak安装完成"
    else
        echo "$SOFTWARE_NAME 安装失败。"
        log "$SOFTWARE_NAME Flatpak安装失败"
        return 1
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        wechat|qq|protonup) install_software "$1" ;;
        *) echo "用法: $0 {wechat|qq|protonup}"; exit 1 ;;
    esac
fi
