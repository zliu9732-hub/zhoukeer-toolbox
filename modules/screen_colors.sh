#!/bin/bash

SCREEN_COLORS_VERSION="1.0.0"
SCREEN_COLORS_DIRECTORY="Screen Colors"
SCREEN_COLORS_MIRROR_ID="screen-colors"
SCREEN_COLORS_MIRROR_REPO="zhoukeer-toolbox-mirror-4"
SCREEN_COLORS_PACKAGE_SHA256="4535b6f378cbb6cca4274067a36604b0fd5a2e94c14913855b177bdae009abb5"

screen_colors_chinese_is_current() {
    python3 "$PROJECT_ROOT/scripts/localize_screen_colors.py" check \
        "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/$SCREEN_COLORS_DIRECTORY" >/dev/null 2>&1
}

ensure_screen_colors_chinese_current() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    PLUGIN_INSTALL_CHANGED=0
    [ "$IS_STEAMOS" -eq 1 ] || { echo "屏幕色彩插件仅在 SteamOS 主线提供。"; return 1; }
    require_command python3 || return 1
    if screen_colors_chinese_is_current; then
        echo "[已安装] 屏幕色彩 v$SCREEN_COLORS_VERSION 中文版已完整安装。"
        return 0
    fi
    ensure_plugin_store_ready || return 1
    prepare_plugin_root "$plugin_root" || return 1
    echo "正在安装屏幕色彩 v$SCREEN_COLORS_VERSION..."
    if (
        local temporary
        temporary="$(mktemp -d)" || return 1
        trap 'rm -rf -- "$temporary"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        GITEE_MIRROR_REPO="$SCREEN_COLORS_MIRROR_REPO" download_gitee_mirror_file \
            "$SCREEN_COLORS_MIRROR_ID" "$temporary/plugin.zip" "$SCREEN_COLORS_PACKAGE_SHA256" \
            "屏幕色彩" || return 1
        python3 "$PROJECT_ROOT/scripts/localize_screen_colors.py" prepare \
            "$temporary/plugin" --archive "$temporary/plugin.zip" > "$temporary/check.log" 2>&1 || {
                log "Screen Colors 中文组件准备失败：$(cat "$temporary/check.log")"
                return 1
            }
        install_tree_atomically "$temporary/plugin" "$plugin_root" "$SCREEN_COLORS_DIRECTORY"
    ); then
        PLUGIN_INSTALL_CHANGED=1
        echo "屏幕色彩 v$SCREEN_COLORS_VERSION 中文版安装成功。"
        echo "请在游戏模式使用；可调整颜色并一键恢复，类 OLED 效果不会改变屏幕本身。"
        echo "汉化：RenAmamiya；原作者：PacificSilent；色彩引擎：Hooandee；许可证：GPL-3.0-or-later。"
        return 0
    fi
    echo "屏幕色彩安装失败，原来的插件已保留。"
    return 1
}
