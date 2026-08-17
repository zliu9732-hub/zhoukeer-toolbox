#!/bin/bash

# Handheld Pink 粉色主题：只把 Renkit 内置文件放入 CSS Loader 的 themes 目录。
# 启用与关闭由 CSS Loader 界面控制，本模块不直接改写主题开关。

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

HANDHELD_PINK_NAME="Handheld Pink"
HANDHELD_PINK_VERSION="v1.0.1"
HANDHELD_PINK_SOURCE_DIR="$PROJECT_ROOT/assets/cssloader/handheld-pink"
HANDHELD_PINK_THEME_JSON_SHA256="7c78ba0669378bd20274d17724d14a387407fd69fdb9dca99350852d7b65f7ba"
HANDHELD_PINK_SHARED_CSS_SHA256="e5fd5a598e07421508ae8376c6784cd56f38976d07a655b82cf6d8f805318ac4"

handheld_pink_decky_home() {
    printf '%s' "${DECKY_HOME:-${ZHOUKEER_DECKY_HOMEBREW_DIR:-$HOME/homebrew}}"
}

handheld_pink_themes_dir() {
    printf '%s' "$(handheld_pink_decky_home)/themes"
}

handheld_pink_theme_dir() {
    printf '%s' "$(handheld_pink_themes_dir)/$HANDHELD_PINK_NAME"
}

handheld_pink_plugin_root() {
    printf '%s' "${DECKY_PLUGIN_DIR:-$(handheld_pink_decky_home)/plugins}"
}

handheld_pink_config_name() {
    local user="${USER:-$(id -un 2>/dev/null || echo user)}"
    if [ "$user" = "root" ]; then
        printf '%s\n' "config_ROOT.json"
    else
        printf '%s\n' "config_USER.json"
    fi
}

handheld_pink_file_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

handheld_pink_source_ok() {
    local json_sha css_sha

    [ -f "$HANDHELD_PINK_SOURCE_DIR/theme.json" ] || {
        echo "Renkit 缺少 Handheld Pink 主题清单，请更新后重试。" >&2
        return 1
    }
    [ -f "$HANDHELD_PINK_SOURCE_DIR/shared.css" ] || {
        echo "Renkit 缺少 Handheld Pink 样式文件，请更新后重试。" >&2
        return 1
    }

    json_sha="$(handheld_pink_file_sha256 "$HANDHELD_PINK_SOURCE_DIR/theme.json")" || return 1
    css_sha="$(handheld_pink_file_sha256 "$HANDHELD_PINK_SOURCE_DIR/shared.css")" || return 1

    [ "$json_sha" = "$HANDHELD_PINK_THEME_JSON_SHA256" ] || {
        echo "Handheld Pink 主题清单校验失败，已停止。" >&2
        return 1
    }
    [ "$css_sha" = "$HANDHELD_PINK_SHARED_CSS_SHA256" ] || {
        echo "Handheld Pink 样式文件校验失败，已停止。" >&2
        return 1
    }
    return 0
}

handheld_pink_css_loader_installed() {
    local plugin_root
    plugin_root="$(handheld_pink_plugin_root)"
    [ -f "$plugin_root/SDH-CssLoader/plugin.json" ] ||
        [ -f "$plugin_root/CSS Loader/plugin.json" ]
}

handheld_pink_theme_current() {
    local theme_dir json_sha css_sha
    theme_dir="$(handheld_pink_theme_dir)"

    [ -f "$theme_dir/theme.json" ] || return 1
    [ -f "$theme_dir/shared.css" ] || return 1

    json_sha="$(handheld_pink_file_sha256 "$theme_dir/theme.json" 2>/dev/null)" || return 1
    css_sha="$(handheld_pink_file_sha256 "$theme_dir/shared.css" 2>/dev/null)" || return 1

    [ "$json_sha" = "$HANDHELD_PINK_THEME_JSON_SHA256" ] &&
        [ "$css_sha" = "$HANDHELD_PINK_SHARED_CSS_SHA256" ]
}

handheld_pink_theme_enabled() {
    local theme_dir config
    theme_dir="$(handheld_pink_theme_dir)"
    config="$theme_dir/$(handheld_pink_config_name)"
    [ -f "$config" ] && grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$config"
}

handheld_pink_print_status() {
    local theme_state loader_state enabled_state theme_dir
    theme_dir="$(handheld_pink_theme_dir)"

    if handheld_pink_theme_current; then
        theme_state="已安装 $HANDHELD_PINK_VERSION"
    elif [ -d "$theme_dir" ]; then
        theme_state="已安装但版本不一致"
    else
        theme_state="未安装"
    fi

    if handheld_pink_css_loader_installed; then
        loader_state="已安装"
    else
        loader_state="未安装"
    fi

    if handheld_pink_theme_enabled; then
        enabled_state="已启用"
    else
        enabled_state="未启用（请在 CSS Loader 中打开 Handheld Pink）"
    fi

    echo "Handheld Pink 粉色主题 $HANDHELD_PINK_VERSION"
    echo "状态：$theme_state"
    echo "CSS Loader：$loader_state"
    echo "启用状态：$enabled_state"
    if [ "$loader_state" = "未安装" ]; then
        echo "提示：请先安装“主题美化（CSS Loader）”，再安装本主题。"
    fi
}

handheld_pink_install() {
    local themes_dir theme_dir tmp_dir backup_dir decky_home

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ] && \
        [ "${ZHOUKEER_ALLOW_NON_STEAMOS:-0}" != "1" ]; then
        echo "Handheld Pink 粉色主题仅支持 SteamOS 或 Bazzite，已停止执行。"
        return 1
    fi

    if ! handheld_pink_source_ok; then
        echo "Handheld Pink 内置文件缺失或校验失败，请更新 Renkit 后重试。"
        return 1
    fi

    if ! handheld_pink_css_loader_installed; then
        echo "未检测到 CSS Loader。请先安装“主题美化（CSS Loader）”，再安装 Handheld Pink 粉色主题。"
        return 1
    fi

    if handheld_pink_theme_current; then
        echo "Handheld Pink $HANDHELD_PINK_VERSION 已存在，无需重复安装。"
        handheld_pink_print_status
        return 0
    fi

    decky_home="$(handheld_pink_decky_home)"
    themes_dir="$(handheld_pink_themes_dir)"
    theme_dir="$(handheld_pink_theme_dir)"
    tmp_dir=""
    backup_dir=""

    if ! mkdir -p "$themes_dir"; then
        echo "无法创建 CSS Loader 主题目录：$themes_dir" >&2
        return 1
    fi

    tmp_dir="$(mktemp -d "$decky_home/.rog-white.XXXXXX")" || {
        echo "无法创建 Handheld Pink 临时目录。" >&2
        return 1
    }
    if ! mkdir -p "$tmp_dir/$HANDHELD_PINK_NAME" || \
        ! cp -- "$HANDHELD_PINK_SOURCE_DIR/theme.json" "$tmp_dir/$HANDHELD_PINK_NAME/theme.json" || \
        ! cp -- "$HANDHELD_PINK_SOURCE_DIR/shared.css" "$tmp_dir/$HANDHELD_PINK_NAME/shared.css"; then
        echo "无法暂存 Handheld Pink 主题文件。" >&2
        rm -rf -- "$tmp_dir"
        return 1
    fi

    if [ -d "$theme_dir" ]; then
        backup_dir="$(mktemp -d "$decky_home/.rog-white-backup.XXXXXX")" || {
            rm -rf -- "$tmp_dir"
            echo "无法创建 Handheld Pink 备份目录。" >&2
            return 1
        }
        if ! mv -- "$theme_dir" "$backup_dir"; then
            echo "无法备份旧版 Handheld Pink 主题。" >&2
            rm -rf -- "$tmp_dir" "$backup_dir"
            return 1
        fi
    fi

    if ! mv -- "$tmp_dir/$HANDHELD_PINK_NAME" "$theme_dir"; then
        if [ -d "$backup_dir" ]; then
            mv -- "$backup_dir" "$theme_dir" 2>/dev/null || true
        fi
        echo "无法写入 Handheld Pink 主题目录。" >&2
        rm -rf -- "$tmp_dir" "$backup_dir"
        return 1
    fi

    rm -rf -- "$tmp_dir" "$backup_dir" 2>/dev/null || true
    log "Handheld Pink 粉色主题已安装到 $theme_dir"
    echo "Handheld Pink $HANDHELD_PINK_VERSION 已放入 CSS Loader 主题目录。"
    echo "请进入 CSS Loader 开启 Handheld Pink；若主题未出现，请完全退出并重新进入 Steam。"
    echo "若启用后 Decky 插头或插件商城消失，请完全退出并重新进入 Steam；这是 Decky Loader 已知的 QAM 标签丢失问题。"
    return 0
}

handheld_pink_uninstall() {
    local theme_dir backup_dir decky_home
    theme_dir="$(handheld_pink_theme_dir)"

    if [ ! -d "$theme_dir" ]; then
        echo "Handheld Pink 未安装，无需卸载。"
        return 0
    fi

    decky_home="$(handheld_pink_decky_home)"
    backup_dir="$(mktemp -d "$decky_home/.rog-white-uninstall.XXXXXX")" || {
        echo "无法创建 Handheld Pink 卸载临时目录。" >&2
        return 1
    }

    if ! mv -- "$theme_dir" "$backup_dir"; then
        echo "无法移除 Handheld Pink 主题目录。" >&2
        rm -rf -- "$backup_dir"
        return 1
    fi

    rm -rf -- "$backup_dir"
    log "Handheld Pink 粉色主题已卸载"
    echo "Handheld Pink 已从 CSS Loader 主题目录移除。"
    echo "若界面仍在使用该主题，请在 CSS Loader 中关闭，或完全退出并重新进入 Steam。"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) handheld_pink_install ;;
        status) handheld_pink_print_status ;;
        uninstall) handheld_pink_uninstall ;;
        *)
            echo "用法：$0 install|status|uninstall" >&2
            exit 1
            ;;
    esac
fi
