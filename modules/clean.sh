#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/safety.sh"

clean_action() {
    case "$1" in
        download-cache)
            safe_remove_contents "$HOME/.steam/steam/steamapps/downloading" "Steam下载残留"
            ;;
        shader-cache)
            safe_remove_contents "$HOME/.steam/steam/steamapps/shadercache" "Steam着色器缓存"
            ;;
        user-cache)
            safe_remove_contents "$HOME/.cache" "Linux用户缓存"
            ;;
        *)
            echo "未知清理项目: $1"
            return 1
            ;;
    esac
}

clean_menu() {
    local choice

    echo "安全清理模式"
    echo "1. 清理Steam下载残留"
    echo "2. 清理Steam着色器缓存"
    echo "3. 清理Linux用户缓存"
    echo "0. 返回"
    echo ""
    read -r -p "选择: " choice

    case "$choice" in
        1) clean_action download-cache ;;
        2) clean_action shader-cache ;;
        3) clean_action user-cache ;;
        0) return 0 ;;
        *) echo "输入错误" ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        download-cache|shader-cache|user-cache) clean_action "$1" ;;
        "") clean_menu ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
fi
