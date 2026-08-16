#!/bin/bash

# ROG White 白色主题：只把 Renkit 内置文件放入 CSS Loader 的 themes 目录。
# 启用与关闭由 CSS Loader 界面控制，本模块不直接改写主题开关。

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

ROG_WHITE_NAME="ROG White"
ROG_WHITE_VERSION="v1.4.0"
ROG_WHITE_SOURCE_DIR="$PROJECT_ROOT/assets/cssloader/rog-white"
ROG_WHITE_THEME_JSON_SHA256="2fb087b1dc83b0955025d9e286391e7aab3cc149ef5f59224519d4e7c33c809e"
ROG_WHITE_SHARED_CSS_SHA256="53252f8c2cde275426a0cc76335b7d00318df2e945f9bde05be38d787e52b1e3"

rog_white_decky_home() {
    printf '%s' "${DECKY_HOME:-${ZHOUKEER_DECKY_HOMEBREW_DIR:-$HOME/homebrew}}"
}

rog_white_themes_dir() {
    printf '%s' "$(rog_white_decky_home)/themes"
}

rog_white_theme_dir() {
    printf '%s' "$(rog_white_themes_dir)/$ROG_WHITE_NAME"
}

rog_white_plugin_root() {
    printf '%s' "${DECKY_PLUGIN_DIR:-$(rog_white_decky_home)/plugins}"
}

rog_white_config_name() {
    local user="${USER:-$(id -un 2>/dev/null || echo user)}"
    if [ "$user" = "root" ]; then
        printf '%s\n' "config_ROOT.json"
    else
        printf '%s\n' "config_USER.json"
    fi
}

rog_white_file_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

rog_white_source_ok() {
    local json_sha css_sha

    [ -f "$ROG_WHITE_SOURCE_DIR/theme.json" ] || {
        echo "Renkit 缺少 ROG White 主题清单，请更新后重试。" >&2
        return 1
    }
    [ -f "$ROG_WHITE_SOURCE_DIR/shared.css" ] || {
        echo "Renkit 缺少 ROG White 样式文件，请更新后重试。" >&2
        return 1
    }

    json_sha="$(rog_white_file_sha256 "$ROG_WHITE_SOURCE_DIR/theme.json")" || return 1
    css_sha="$(rog_white_file_sha256 "$ROG_WHITE_SOURCE_DIR/shared.css")" || return 1

    [ "$json_sha" = "$ROG_WHITE_THEME_JSON_SHA256" ] || {
        echo "ROG White 主题清单校验失败，已停止。" >&2
        return 1
    }
    [ "$css_sha" = "$ROG_WHITE_SHARED_CSS_SHA256" ] || {
        echo "ROG White 样式文件校验失败，已停止。" >&2
        return 1
    }
    return 0
}

rog_white_css_loader_installed() {
    local plugin_root
    plugin_root="$(rog_white_plugin_root)"
    [ -f "$plugin_root/SDH-CssLoader/plugin.json" ] ||
        [ -f "$plugin_root/CSS Loader/plugin.json" ]
}

rog_white_theme_current() {
    local theme_dir json_sha css_sha
    theme_dir="$(rog_white_theme_dir)"

    [ -f "$theme_dir/theme.json" ] || return 1
    [ -f "$theme_dir/shared.css" ] || return 1

    json_sha="$(rog_white_file_sha256 "$theme_dir/theme.json" 2>/dev/null)" || return 1
    css_sha="$(rog_white_file_sha256 "$theme_dir/shared.css" 2>/dev/null)" || return 1

    [ "$json_sha" = "$ROG_WHITE_THEME_JSON_SHA256" ] &&
        [ "$css_sha" = "$ROG_WHITE_SHARED_CSS_SHA256" ]
}

rog_white_theme_enabled() {
    local theme_dir config
    theme_dir="$(rog_white_theme_dir)"
    config="$theme_dir/$(rog_white_config_name)"
    [ -f "$config" ] && grep -Eq '"active"[[:space:]]*:[[:space:]]*true' "$config"
}

rog_white_print_status() {
    local theme_state loader_state enabled_state theme_dir
    theme_dir="$(rog_white_theme_dir)"

    if rog_white_theme_current; then
        theme_state="已安装 $ROG_WHITE_VERSION"
    elif [ -d "$theme_dir" ]; then
        theme_state="已安装但版本不一致"
    else
        theme_state="未安装"
    fi

    if rog_white_css_loader_installed; then
        loader_state="已安装"
    else
        loader_state="未安装"
    fi

    if rog_white_theme_enabled; then
        enabled_state="已启用"
    else
        enabled_state="未启用（请在 CSS Loader 中打开 ROG White）"
    fi

    echo "ROG White 白色主题 $ROG_WHITE_VERSION"
    echo "状态：$theme_state"
    echo "CSS Loader：$loader_state"
    echo "启用状态：$enabled_state"
    if [ "$loader_state" = "未安装" ]; then
        echo "提示：请先安装“主题美化（CSS Loader）”，再安装本主题。"
    fi
}

rog_white_install() {
    local themes_dir theme_dir tmp_dir backup_dir decky_home

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ] && \
        [ "${ZHOUKEER_ALLOW_NON_STEAMOS:-0}" != "1" ]; then
        echo "ROG White 白色主题仅支持 SteamOS 或 Bazzite，已停止执行。"
        return 1
    fi

    if ! rog_white_source_ok; then
        echo "ROG White 内置文件缺失或校验失败，请更新 Renkit 后重试。"
        return 1
    fi

    if ! rog_white_css_loader_installed; then
        echo "未检测到 CSS Loader。请先安装“主题美化（CSS Loader）”，再安装 ROG White 白色主题。"
        return 1
    fi

    if rog_white_theme_current; then
        echo "ROG White $ROG_WHITE_VERSION 已存在，无需重复安装。"
        rog_white_print_status
        return 0
    fi

    decky_home="$(rog_white_decky_home)"
    themes_dir="$(rog_white_themes_dir)"
    theme_dir="$(rog_white_theme_dir)"
    tmp_dir=""
    backup_dir=""

    if ! mkdir -p "$themes_dir"; then
        echo "无法创建 CSS Loader 主题目录：$themes_dir" >&2
        return 1
    fi

    tmp_dir="$(mktemp -d "$decky_home/.rog-white.XXXXXX")" || {
        echo "无法创建 ROG White 临时目录。" >&2
        return 1
    }
    if ! mkdir -p "$tmp_dir/$ROG_WHITE_NAME" || \
        ! cp -- "$ROG_WHITE_SOURCE_DIR/theme.json" "$tmp_dir/$ROG_WHITE_NAME/theme.json" || \
        ! cp -- "$ROG_WHITE_SOURCE_DIR/shared.css" "$tmp_dir/$ROG_WHITE_NAME/shared.css"; then
        echo "无法暂存 ROG White 主题文件。" >&2
        rm -rf -- "$tmp_dir"
        return 1
    fi

    if [ -d "$theme_dir" ]; then
        backup_dir="$(mktemp -d "$decky_home/.rog-white-backup.XXXXXX")" || {
            rm -rf -- "$tmp_dir"
            echo "无法创建 ROG White 备份目录。" >&2
            return 1
        }
        if ! mv -- "$theme_dir" "$backup_dir"; then
            echo "无法备份旧版 ROG White 主题。" >&2
            rm -rf -- "$tmp_dir" "$backup_dir"
            return 1
        fi
    fi

    if ! mv -- "$tmp_dir/$ROG_WHITE_NAME" "$theme_dir"; then
        if [ -d "$backup_dir" ]; then
            mv -- "$backup_dir" "$theme_dir" 2>/dev/null || true
        fi
        echo "无法写入 ROG White 主题目录。" >&2
        rm -rf -- "$tmp_dir" "$backup_dir"
        return 1
    fi

    rm -rf -- "$tmp_dir" "$backup_dir" 2>/dev/null || true
    log "ROG White 白色主题已安装到 $theme_dir"
    echo "ROG White $ROG_WHITE_VERSION 已放入 CSS Loader 主题目录。"
    echo "请进入 CSS Loader 开启 ROG White；若主题未出现，请完全退出并重新进入 Steam。"
    return 0
}

rog_white_uninstall() {
    local theme_dir backup_dir decky_home
    theme_dir="$(rog_white_theme_dir)"

    if [ ! -d "$theme_dir" ]; then
        echo "ROG White 未安装，无需卸载。"
        return 0
    fi

    decky_home="$(rog_white_decky_home)"
    backup_dir="$(mktemp -d "$decky_home/.rog-white-uninstall.XXXXXX")" || {
        echo "无法创建 ROG White 卸载临时目录。" >&2
        return 1
    }

    if ! mv -- "$theme_dir" "$backup_dir"; then
        echo "无法移除 ROG White 主题目录。" >&2
        rm -rf -- "$backup_dir"
        return 1
    fi

    rm -rf -- "$backup_dir"
    log "ROG White 白色主题已卸载"
    echo "ROG White 已从 CSS Loader 主题目录移除。"
    echo "若界面仍在使用该主题，请在 CSS Loader 中关闭，或完全退出并重新进入 Steam。"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) rog_white_install ;;
        status) rog_white_print_status ;;
        uninstall) rog_white_uninstall ;;
        *)
            echo "用法：$0 install|status|uninstall" >&2
            exit 1
            ;;
    esac
fi
