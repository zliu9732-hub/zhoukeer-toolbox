#!/bin/bash

GFG_EXTREME_VERSION="3.0.10"
GFG_EXTREME_DIRECTORY="GFG-Extreme"
GFG_EXTREME_MIRROR_ID="gfg-extreme-zh"
GFG_EXTREME_MIRROR_REPO="zhoukeer-toolbox-mirror-4"
GFG_EXTREME_PACKAGE_SHA256="efd2f4c92fa287c1ad85b3e753f92c86d9b0947d84e6342b28b746dc2808e50d"
GFG_EXTREME_DMI=/sys/class/dmi/id

gfg_extreme_is_steam_deck() {
    local vendor product board
    vendor="$(cat "$GFG_EXTREME_DMI/sys_vendor" 2>/dev/null)" || return 1
    product="$(cat "$GFG_EXTREME_DMI/product_name" 2>/dev/null)" || return 1
    board="$(cat "$GFG_EXTREME_DMI/board_name" 2>/dev/null)" || return 1
    [ "$vendor" = Valve ] && { [ "$product:$board" = Jupiter:Jupiter ] || [ "$product:$board" = Galileo:Galileo ]; }
}

gfg_extreme_chinese_is_current() {
    python3 "$PROJECT_ROOT/scripts/localize_gfg_extreme.py" check \
        "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/$GFG_EXTREME_DIRECTORY" >/dev/null 2>&1
}

ensure_gfg_extreme_chinese_current() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    PLUGIN_INSTALL_CHANGED=0
    [ "$IS_STEAMOS" -eq 1 ] && gfg_extreme_is_steam_deck || {
        echo 'GFG Extreme 目前仅在 Steam Deck / SteamOS 提供，其他设备已停止安装。'
        return 1
    }
    require_command python3 || return 1
    if gfg_extreme_chinese_is_current; then
        echo "[已安装] GFG Extreme v$GFG_EXTREME_VERSION 中文版已完整安装。"
        return 0
    fi
    ensure_plugin_store_ready || return 1
    prepare_plugin_root "$plugin_root" || return 1
    echo "正在安装 GFG Extreme v$GFG_EXTREME_VERSION 中文版…"
    if (
        local temporary
        temporary="$(mktemp -d)" || return 1
        trap 'rm -rf -- "$temporary"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        GITEE_MIRROR_REPO="$GFG_EXTREME_MIRROR_REPO" download_gitee_mirror_file \
            "$GFG_EXTREME_MIRROR_ID" "$temporary/plugin.zip" "$GFG_EXTREME_PACKAGE_SHA256" \
            'GFG Extreme' || return 1
        python3 "$PROJECT_ROOT/scripts/localize_gfg_extreme.py" prepare \
            "$temporary/plugin" --archive "$temporary/plugin.zip" > "$temporary/check.log" 2>&1 || {
                log "GFG Extreme 中文组件准备失败：$(cat "$temporary/check.log")"
                return 1
            }
        install_tree_atomically "$temporary/plugin" "$plugin_root" "$GFG_EXTREME_DIRECTORY"
    ); then
        PLUGIN_INSTALL_CHANGED=1
        echo "GFG Extreme v$GFG_EXTREME_VERSION 中文版安装成功。"
        echo '请在游戏模式的插件“设置”页面安装引擎，再保存工作并手动重启。'
        echo '首次启动会迁移旧设置并清理旧 GFG/MAKO 组件；勿同时启用其他功耗控制插件。'
        echo '需要恢复时，在插件中移除引擎后重启；仅卸载插件不会移除引擎。'
        echo '汉化：RenAmamiya；原作者：Eugenio Segala 和原项目贡献者；许可证：GPL-3.0-or-later。'
        return 0
    fi
    echo 'GFG Extreme 安装未完成，原来的插件已保留。'
    return 1
}
