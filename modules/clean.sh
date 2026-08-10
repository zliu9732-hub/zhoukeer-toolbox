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
            echo "正在清理 Steam 着色器缓存..."
            local _cc_cleaned=0 _cc_dir _cc_vdf _cc_path
            for _cc_dir in \
                "$HOME/.steam/steam/steamapps/shadercache" \
                "$HOME/.local/share/Steam/steamapps/shadercache"; do
                if [ -d "$_cc_dir" ]; then
                    toolbox_sudo find "$_cc_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
                    _cc_cleaned=$((_cc_cleaned + 1))
                fi
            done
            for _cc_vdf in \
                "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
                "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
                [ -r "$_cc_vdf" ] || continue
                while IFS= read -r _cc_path; do
                    case "$_cc_path" in
                        /*)
                            _cc_dir="$_cc_path/steamapps/shadercache"
                            if [ -d "$_cc_dir" ]; then
                                toolbox_sudo find "$_cc_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
                                _cc_cleaned=$((_cc_cleaned + 1))
                            fi
                            ;;
                    esac
                done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$_cc_vdf" 2>/dev/null)
            done
            if [ "$_cc_cleaned" -gt 0 ]; then
                echo "已清理 $_cc_cleaned 个 Steam 库的着色器缓存。"
                log "已清理 $_cc_cleaned 个 Steam 库的着色器缓存"
            else
                echo "未找到 Steam 着色器缓存目录。"
            fi
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
