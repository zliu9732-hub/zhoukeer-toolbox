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

download_verified_package() {
    local name="$1"
    local url="$2"
    local expected_sha256="$3"
    local output="$4"
    local actual_sha256

    if [ -z "$url" ] || [ -z "$expected_sha256" ]; then
        echo "$name 的下载配置不完整，请先更新工具箱。"
        return 1
    fi

    echo "正在从123云盘下载 $name ..."
    if ! curl \
        --fail \
        --location \
        --show-error \
        --progress-bar \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time 1200 \
        --retry 3 \
        --retry-delay 2 \
        --output "$output" \
        "$url"; then
        rm -f -- "$output"
        echo "$name 下载失败，未改动现有文件。"
        return 1
    fi

    actual_sha256="$(calculate_decky_sha256 "$output")" || {
        rm -f -- "$output"
        echo "无法校验 $name，已停止安装。"
        return 1
    }
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        rm -f -- "$output"
        echo "$name 下载不完整，校验失败，已删除临时文件。"
        return 1
    fi
    echo "$name 下载完成并通过完整性校验。"
}

archive_paths_are_safe() {
    local archive="$1"
    local archive_type="$2"
    local paths

    case "$archive_type" in
        zip) paths="$(unzip -Z1 "$archive")" || return 1 ;;
        *) return 1 ;;
    esac

    if printf '%s\n' "$paths" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        echo "压缩包包含不安全路径，已停止安装。"
        return 1
    fi
}

run_plugin_file_operation() {
    if [ "${PLUGIN_NEEDS_SUDO:-0}" -eq 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

prepare_plugin_root() {
    local plugin_root="$1"

    if [ ! -d "$plugin_root" ]; then
        echo "未找到 Decky 插件目录：$plugin_root"
        echo "请先点击“安装或更新 Decky Loader”，完成后再安装插件。"
        return 1
    fi
    if [ -w "$plugin_root" ]; then
        PLUGIN_NEEDS_SUDO=0
    else
        require_command sudo || return 1
        PLUGIN_NEEDS_SUDO=1
    fi
}

install_tree_atomically() {
    local source_dir="$1"
    local target_parent="$2"
    local target_name="$3"
    local target_dir="$target_parent/$target_name"
    local staging_dir="$target_parent/.${target_name}.new.$$"
    local backup_dir="$target_parent/.${target_name}.backup.$$"

    run_plugin_file_operation rm -rf -- "$staging_dir" "$backup_dir" || return 1
    run_plugin_file_operation cp -a -- "$source_dir" "$staging_dir" || return 1

    if [ -e "$target_dir" ]; then
        run_plugin_file_operation mv -- "$target_dir" "$backup_dir" || {
            run_plugin_file_operation rm -rf -- "$staging_dir"
            return 1
        }
    fi

    if ! run_plugin_file_operation mv -- "$staging_dir" "$target_dir"; then
        if [ -e "$backup_dir" ] && [ ! -e "$target_dir" ]; then
            run_plugin_file_operation mv -- "$backup_dir" "$target_dir" || true
        fi
        return 1
    fi
    run_plugin_file_operation rm -rf -- "$backup_dir"
}

find_plugin_source() {
    local extract_dir="$1"
    local plugin_json

    plugin_json="$(find "$extract_dir" -mindepth 2 -maxdepth 3 -type f -name plugin.json -print -quit)"
    [ -n "$plugin_json" ] || return 1
    dirname "$plugin_json"
}

install_decky_zip() {
    local display_name="$1"
    local url="$2"
    local sha256="$3"
    local expected_dir="$4"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local tmp_dir
    local archive
    local extract_dir
    local plugin_source

    for command_name in curl unzip; do
        require_command "$command_name" || return 1
    done
    prepare_plugin_root "$plugin_root" || return 1

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    archive="$tmp_dir/plugin.zip"
    extract_dir="$tmp_dir/extracted"
    mkdir -p "$extract_dir"
    trap cleanup_decky_tmp EXIT INT TERM

    download_verified_package "$display_name" "$url" "$sha256" "$archive" || return 1
    archive_paths_are_safe "$archive" zip || return 1
    unzip -q "$archive" -d "$extract_dir" || {
        echo "$display_name 解压失败，未改动现有插件。"
        return 1
    }
    plugin_source="$(find_plugin_source "$extract_dir")" || {
        echo "$display_name 压缩包中没有找到 plugin.json。"
        return 1
    }
    if [ "$(basename "$plugin_source")" != "$expected_dir" ]; then
        echo "$display_name 的目录结构不符合预期，已停止安装。"
        return 1
    fi

    install_tree_atomically "$plugin_source" "$plugin_root" "$expected_dir" || {
        echo "$display_name 安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "$display_name 已安装到：$plugin_root/$expected_dir"
    log "$display_name 安装完成"
    cleanup_decky_tmp
    trap - EXIT INT TERM
}

install_lsfg_bundle() {
    if install_decky_zip \
        "小黄鸭（LSFG-VK）" \
        "${DECKY_LSFG_URL:-}" \
        "${DECKY_LSFG_SHA256:-}" \
        "Decky LSFG-VK"; then
        echo "请确认已经通过 Steam 正版购买并安装 Lossless Scaling。"
        return 0
    fi
    return 1
}

install_configured_plugin() {
    local action="$1"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "Decky 插件安装仅支持真实 SteamOS 环境。"
        return 1
    fi

    case "$action" in
        lsfg) install_lsfg_bundle ;;
        fsr4)
            install_decky_zip \
                "FSR4（Decky Framegen）" \
                "${DECKY_FSR4_URL:-}" \
                "${DECKY_FSR4_SHA256:-}" \
                "Decky-Framegen"
            ;;
        cheatdeck)
            install_decky_zip \
                "CheatDeck" \
                "${DECKY_CHEATDECK_URL:-}" \
                "${DECKY_CHEATDECK_SHA256:-}" \
                "CheatDeck"
            ;;
        *) return 1 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-store}" in
        store) install_plugin_store ;;
        lsfg) install_configured_plugin lsfg ;;
        fsr4) install_configured_plugin fsr4 ;;
        cheatdeck) install_configured_plugin cheatdeck ;;
        *) echo "未知插件操作: $1"; exit 1 ;;
    esac
fi
