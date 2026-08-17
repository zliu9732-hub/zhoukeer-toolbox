#!/bin/bash

# Pink White Gradient 粉色主题：只把 Renkit 内置文件放入 CSS Loader 的 themes 目录。
# 启用与关闭由 CSS Loader 界面控制，本模块不直接改写主题开关。

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

PINK_WHITE_GRADIENT_NAME="Pink White Gradient"
PINK_WHITE_GRADIENT_VERSION="v1.0.0"
PINK_WHITE_GRADIENT_SOURCE_DIR="$PROJECT_ROOT/assets/cssloader/pink-white-gradient"
PINK_WHITE_GRADIENT_THEME_JSON_SHA256="cf9385f034e2527056e3c465b65b4753ff4c9d49ac4d676a32f38ccf90ea0ec3"
PINK_WHITE_GRADIENT_SHARED_CSS_SHA256="72272970970dcab19c090887999cb67bcfe54b597bff248803a307a6aaf58a46"

pink_white_gradient_decky_home() {
    printf '%s' "${DECKY_HOME:-${ZHOUKEER_DECKY_HOMEBREW_DIR:-$HOME/homebrew}}"
}

pink_white_gradient_themes_dir() {
    printf '%s' "$(pink_white_gradient_decky_home)/themes"
}

pink_white_gradient_theme_dir() {
    printf '%s' "$(pink_white_gradient_themes_dir)/$PINK_WHITE_GRADIENT_NAME"
}

pink_white_gradient_plugin_root() {
    printf '%s' "${DECKY_PLUGIN_DIR:-$(pink_white_gradient_decky_home)/plugins}"
}

pink_white_gradient_config_name() {
    local user="${USER:-$(id -un 2>/dev/null || echo user)}"
    if [ "$user" = "root" ]; then
        printf '%s\n' "config_ROOT.json"
    else
        printf '%s\n' "config_USER.json"
    fi
}

pink_white_gradient_file_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

pink_white_gradient_source_ok() {
    local json_sha css_sha

    [ -f "$PINK_WHITE_GRADIENT_SOURCE_DIR/theme.json" ] || {
        echo "Renkit 缺少 Pink White Gradient 主题清单，请更新后重试。" >&2
        return 1
    }
    [ -f "$PINK_WHITE_GRADIENT_SOURCE_DIR/shared.css" ] || {
        echo "Renkit 缺少 Pink White Gradient 样式文件，请更新后重试。" >&2
        return 1
    }

    json_sha="$(pink_white_gradient_file_sha256 "$PINK_WHITE_GRADIENT_SOURCE_DIR/theme.json")" || return 1
    css_sha="$(pink_white_gradient_file_sha256 "$PINK_WHITE_GRADIENT_SOURCE_DIR/shared.css")" || return 1

    [ "$json_sha" = "$PINK_WHITE_GRADIENT_THEME_JSON_SHA256" ] || {
        echo "Pink White Gradient 主题清单校验失败，已停止。" >&2
        return 1
    }
    [ "$css_sha" = "$PINK_WHITE_GRADIENT_SHARED_CSS_SHA256" ] || {
        echo "Pink White Gradient 样式文件校验失败，已停止。" >&2
        return 1
    }
    return 0
}

pink_white_gradient_css_loader_installed() {
    local plugin_root
    plugin_root="$(pink_white_gradient_plugin_root)"
    [ -f "$plugin_root/SDH-CssLoader/plugin.json" ] ||
        [ -f "$plugin_root/CSS Loader/plugin.json" ]
}

pink_white_gradient_theme_current() {
    local theme_dir json_sha css_sha
    theme_dir="$(pink_white_gradient_theme_dir)"

    [ -f "$theme_dir/theme.json" ] || return 1
    [ -f "$theme_dir/shared.css" ] || return 1

    json_sha="$(pink_white_gradient_file_sha256 "$theme_dir/theme.json" 2>/dev/null)" || return 1
    css_sha="$(pink_white_gradient_file_sha256 "$theme_dir/shared.css" 2>/dev/null)" || return 1

    [ "$json_sha" = "$PINK_WHITE_GRADIENT_THEME_JSON_SHA256" ] &&
        [ "$css_sha" = "$PINK_WHITE_GRADIENT_SHARED_CSS_SHA256" ]
}

pink_white_gradient_theme_enabled() {
    local theme_dir config
    theme_dir="$(pink_white_gradient_theme_dir)"
    config="$theme_dir/$(pink_white_gradient_config_name)"
    [ -f "$config" ] && grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$config"
}

pink_white_gradient_print_status() {
    local theme_state loader_state enabled_state theme_dir
    theme_dir="$(pink_white_gradient_theme_dir)"

    if pink_white_gradient_theme_current; then
        theme_state="已安装 $PINK_WHITE_GRADIENT_VERSION"
    elif [ -d "$theme_dir" ]; then
        theme_state="已安装但版本不一致"
    else
        theme_state="未安装"
    fi

    if pink_white_gradient_css_loader_installed; then
        loader_state="已安装"
    else
        loader_state="未安装"
    fi

    if pink_white_gradient_theme_enabled; then
        enabled_state="已启用"
    else
        enabled_state="未启用（请在 CSS Loader 中打开 Pink White Gradient）"
    fi

    echo "Pink White Gradient 粉色主题 $PINK_WHITE_GRADIENT_VERSION"
    echo "状态：$theme_state"
    echo "CSS Loader：$loader_state"
    echo "启用状态：$enabled_state"
    if [ "$loader_state" = "未安装" ]; then
        echo "提示：请先安装“主题美化（CSS Loader）”，再安装本主题。"
    fi
}

pink_white_gradient_install() {
    local themes_dir theme_dir tmp_dir backup_dir decky_home

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ] && \
        [ "${ZHOUKEER_ALLOW_NON_STEAMOS:-0}" != "1" ]; then
        echo "Pink White Gradient 粉色主题仅支持 SteamOS 或 Bazzite，已停止执行。"
        return 1
    fi

    if ! pink_white_gradient_source_ok; then
        echo "Pink White Gradient 内置文件缺失或校验失败，请更新 Renkit 后重试。"
        return 1
    fi

    if ! pink_white_gradient_css_loader_installed; then
        echo "未检测到 CSS Loader。请先安装“主题美化（CSS Loader）”，再安装 Pink White Gradient 粉色主题。"
        return 1
    fi

    if pink_white_gradient_theme_current; then
        echo "Pink White Gradient $PINK_WHITE_GRADIENT_VERSION 已存在，无需重复安装。"
        pink_white_gradient_print_status
        return 0
    fi

    decky_home="$(pink_white_gradient_decky_home)"
    themes_dir="$(pink_white_gradient_themes_dir)"
    theme_dir="$(pink_white_gradient_theme_dir)"
    tmp_dir=""
    backup_dir=""

    if ! mkdir -p "$themes_dir"; then
        echo "无法创建 CSS Loader 主题目录：$themes_dir" >&2
        return 1
    fi

    tmp_dir="$(mktemp -d "$decky_home/.rog-white.XXXXXX")" || {
        echo "无法创建 Pink White Gradient 临时目录。" >&2
        return 1
    }
    if ! mkdir -p "$tmp_dir/$PINK_WHITE_GRADIENT_NAME" || \
        ! cp -- "$PINK_WHITE_GRADIENT_SOURCE_DIR/theme.json" "$tmp_dir/$PINK_WHITE_GRADIENT_NAME/theme.json" || \
        ! cp -- "$PINK_WHITE_GRADIENT_SOURCE_DIR/shared.css" "$tmp_dir/$PINK_WHITE_GRADIENT_NAME/shared.css"; then
        echo "无法暂存 Pink White Gradient 主题文件。" >&2
        rm -rf -- "$tmp_dir"
        return 1
    fi

    if [ -d "$theme_dir" ]; then
        backup_dir="$(mktemp -d "$decky_home/.rog-white-backup.XXXXXX")" || {
            rm -rf -- "$tmp_dir"
            echo "无法创建 Pink White Gradient 备份目录。" >&2
            return 1
        }
        if ! mv -- "$theme_dir" "$backup_dir"; then
            echo "无法备份旧版 Pink White Gradient 主题。" >&2
            rm -rf -- "$tmp_dir" "$backup_dir"
            return 1
        fi
    fi

    if ! mv -- "$tmp_dir/$PINK_WHITE_GRADIENT_NAME" "$theme_dir"; then
        if [ -d "$backup_dir" ]; then
            mv -- "$backup_dir" "$theme_dir" 2>/dev/null || true
        fi
        echo "无法写入 Pink White Gradient 主题目录。" >&2
        rm -rf -- "$tmp_dir" "$backup_dir"
        return 1
    fi

    rm -rf -- "$tmp_dir" "$backup_dir" 2>/dev/null || true
    log "Pink White Gradient 粉色主题已安装到 $theme_dir"
    echo "Pink White Gradient $PINK_WHITE_GRADIENT_VERSION 已放入 CSS Loader 主题目录。"
    echo "请进入 CSS Loader 开启 Pink White Gradient；若主题未出现，请完全退出并重新进入 Steam。"
    echo "若启用后 Decky 插头或插件商城消失，请完全退出并重新进入 Steam；这是 Decky Loader 已知的 QAM 标签丢失问题。"
    return 0
}

pink_white_gradient_uninstall() {
    local theme_dir backup_dir decky_home
    theme_dir="$(pink_white_gradient_theme_dir)"

    if [ ! -d "$theme_dir" ]; then
        echo "Pink White Gradient 未安装，无需卸载。"
        return 0
    fi

    decky_home="$(pink_white_gradient_decky_home)"
    backup_dir="$(mktemp -d "$decky_home/.rog-white-uninstall.XXXXXX")" || {
        echo "无法创建 Pink White Gradient 卸载临时目录。" >&2
        return 1
    }

    if ! mv -- "$theme_dir" "$backup_dir"; then
        echo "无法移除 Pink White Gradient 主题目录。" >&2
        rm -rf -- "$backup_dir"
        return 1
    fi

    rm -rf -- "$backup_dir"
    log "Pink White Gradient 粉色主题已卸载"
    echo "Pink White Gradient 已从 CSS Loader 主题目录移除。"
    echo "若界面仍在使用该主题，请在 CSS Loader 中关闭，或完全退出并重新进入 Steam。"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) pink_white_gradient_install ;;
        status) pink_white_gradient_print_status ;;
        uninstall) pink_white_gradient_uninstall ;;
        *)
            echo "用法：$0 install|status|uninstall" >&2
            exit 1
            ;;
    esac
fi
