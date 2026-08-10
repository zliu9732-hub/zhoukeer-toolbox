#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/safety.sh"

steam_action() {
    case "$1" in
        download-cache)
            safe_remove_contents "$HOME/.steam/steam/steamapps/downloading" "Steam下载缓存"
            ;;
        performance)
            echo "建议：性能模式 = 15W / 关闭后台"
            echo "提示：实际性能档位请在 Steam Deck 快捷菜单中手动调整。"
            log "显示Steam Deck性能模式建议"
            ;;
        shader-cache)
            echo "正在清理 Steam 着色器缓存..."
            local _ss_cleaned=0 _ss_dir _ss_vdf _ss_path
            for _ss_dir in \
                "$HOME/.steam/steam/steamapps/shadercache" \
                "$HOME/.local/share/Steam/steamapps/shadercache"; do
                if [ -d "$_ss_dir" ]; then
                    toolbox_sudo find "$_ss_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
                    _ss_cleaned=$((_ss_cleaned + 1))
                fi
            done
            for _ss_vdf in \
                "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
                "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
                [ -r "$_ss_vdf" ] || continue
                while IFS= read -r _ss_path; do
                    case "$_ss_path" in
                        /*)
                            _ss_dir="$_ss_path/steamapps/shadercache"
                            if [ -d "$_ss_dir" ]; then
                                toolbox_sudo find "$_ss_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
                                _ss_cleaned=$((_ss_cleaned + 1))
                            fi
                            ;;
                    esac
                done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$_ss_vdf" 2>/dev/null)
            done
            if [ "$_ss_cleaned" -gt 0 ]; then
                echo "已清理 $_ss_cleaned 个 Steam 库的着色器缓存。"
                log "已清理 $_ss_cleaned 个 Steam 库的着色器缓存"
            else
                echo "未找到 Steam 着色器缓存目录。"
            fi
            ;;
        *)
            echo "未知优化项目: $1"
            return 1
            ;;
    esac
}

steam_menu() {
    local choice

    echo "Steam Deck / 游戏优化"
    echo "1. 清理下载缓存"
    echo "2. 性能模式提示"
    echo "3. 清理着色器缓存"
    echo "0. 返回"
    read -r -p "选择: " choice

    case "$choice" in
        1) steam_action download-cache ;;
        2) steam_action performance ;;
        3) steam_action shader-cache ;;
        0) return 0 ;;
        *) echo "输入错误" ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        download-cache|performance|shader-cache) steam_action "$1" ;;
        "") steam_menu ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
fi
