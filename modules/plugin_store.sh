#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

load_config

DECKY_INSTALLER_URL="${DECKY_INSTALLER_URL:-https://www.mhhf.com/Deck/install.sh}"
DECKY_INSTALLER_SHA256="${DECKY_INSTALLER_SHA256:-e7c504485bccbc223d8aaab5b45e7214362ece97fdb279bde336bd872aa3e4b0}"
DECKY_TMP_DIR=""

cleanup_decky_tmp() {
    if [ -n "$DECKY_TMP_DIR" ] && [ -d "$DECKY_TMP_DIR" ]; then
        rm -rf -- "$DECKY_TMP_DIR"
    fi
    DECKY_TMP_DIR=""
}

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

    echo "将通过国内镜像安装Decky Loader插件商城。"
    echo "安装脚本已固定SHA256；执行时会请求Steam Deck管理员权限。"
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
    for command_name in bash curl sudo; do
        require_command "$command_name" || return 1
    done
    confirm_decky_install || {
        echo "已取消插件商城安装。"
        return 0
    }

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    installer="$tmp_dir/install.sh"
    trap cleanup_decky_tmp EXIT INT TERM

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
        echo "Decky国内安装器下载失败。"
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

    echo "正在启动Decky国内安装器..."
    if bash "$installer"; then
        echo "Decky Loader安装完成，请返回游戏模式检查插件菜单。"
        log "Decky Loader安装完成"
    else
        echo "Decky Loader安装失败。"
        log "Decky Loader安装失败"
        return 1
    fi

    cleanup_decky_tmp
    trap - EXIT INT TERM
}

show_pending_plugin_source() {
    local plugin_name="$1"
    local url="$2"
    local sha256="$3"

    if [ -n "$url" ] && [ -n "$sha256" ]; then
        echo "$plugin_name 的国内分流已经填入配置，但安装格式仍需完成真机校验。"
        echo "为避免破坏Decky插件目录，本版暂不执行该安装包。"
        return 1
    fi

    echo "$plugin_name 的123云盘国内分流正在整理，暂未开放安装。"
    echo "请稍后通过左侧“工具箱更新”获取完整的一键安装功能。"
    return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-store}" in
        store) install_plugin_store ;;
        lsfg) show_pending_plugin_source "小黄鸭（LSFG-VK）" "${DECKY_LSFG_URL:-}" "${DECKY_LSFG_SHA256:-}" ;;
        fsr4) show_pending_plugin_source "FSR4（Decky Framegen）" "${DECKY_FSR4_URL:-}" "${DECKY_FSR4_SHA256:-}" ;;
        cheatdeck) show_pending_plugin_source "CheatDeck" "${DECKY_CHEATDECK_URL:-}" "${DECKY_CHEATDECK_SHA256:-}" ;;
        *) echo "未知插件操作: $1"; exit 1 ;;
    esac
fi
