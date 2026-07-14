#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

RUSTDESK="$APP_DIR/rustdesk.AppImage"
RUSTDESK_CONNECT_TIMEOUT=15
RUSTDESK_MAX_TIME=600
RUSTDESK_RETRIES=3

load_config

calculate_sha256() {
    local file="$1"
    local output

    if command -v sha256sum >/dev/null 2>&1; then
        output="$(sha256sum -- "$file")" || return 1
    elif command -v shasum >/dev/null 2>&1; then
        output="$(shasum -a 256 -- "$file")" || return 1
    else
        return 1
    fi

    printf '%s\n' "${output%% *}"
}

validate_rustdesk_settings() {
    if [ -z "${RUSTDESK_DOWNLOAD:-}" ]; then
        echo "未配置 RustDesk 下载地址。"
        echo "请在 config/settings.conf 中设置 RUSTDESK_DOWNLOAD。"
        log "RustDesk安装失败: RUSTDESK_DOWNLOAD为空"
        return 1
    fi

    if [ "${#RUSTDESK_SHA256}" -ne 64 ]; then
        echo "RustDesk SHA256 配置无效：必须是64位十六进制字符串。"
        log "RustDesk安装失败: RUSTDESK_SHA256格式无效"
        return 1
    fi

    case "$RUSTDESK_SHA256" in
        *[!0-9A-Fa-f]*)
            echo "RustDesk SHA256 配置无效：只能包含十六进制字符。"
            log "RustDesk安装失败: RUSTDESK_SHA256格式无效"
            return 1
            ;;
    esac

    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
        log "RustDesk安装失败: 缺少SHA256校验命令"
        return 1
    fi
}

show_manual_config() {
    echo ""
    echo "请打开 RustDesk → 设置 → 网络 → 解锁网络设置，手动填写："
    echo "ID服务器：${RUSTDESK_ID_SERVER:-未配置}"
    echo "中继服务器：${RUSTDESK_RELAY_SERVER:-未配置}"
    echo "API：${RUSTDESK_API:-未配置}"
    echo "Key：${RUSTDESK_KEY:-未配置}"
    echo ""
    echo "本工具不会猜测或直接修改 RustDesk2.toml。"
    echo "请勿在工具配置或日志中保存远程密码、API账号或登录Token。"
}

# 返回值：0=检测到普通用户可用的--config，1=未检测到，2=无法检查，3=需要安装和管理员权限。
rustdesk_supports_config_import() {
    local inspect_dir
    local status=2

    if [ ! -x "$RUSTDESK" ]; then
        return 2
    fi

    inspect_dir="$(mktemp -d "$APP_DIR/.rustdesk-inspect.XXXXXX")" || return 2

    # --appimage-extract 是AppImage运行时参数，只解包到用户目录，不安装也不提权。
    if (cd "$inspect_dir" && "$RUSTDESK" --appimage-extract >/dev/null 2>&1); then
        if LC_ALL=C grep -aR -F -q -- "--config" "$inspect_dir/squashfs-root" 2>/dev/null; then
            if LC_ALL=C grep -aR -F -q -- \
                "Installation and administrative privileges required!" \
                "$inspect_dir/squashfs-root" 2>/dev/null; then
                status=3
            else
                status=0
            fi
        else
            status=1
        fi
    fi

    rm -rf -- "$inspect_dir"
    return "$status"
}

configure_installed_rustdesk() {
    local support_status
    local config_string="${RUSTDESK_CONFIG_STRING:-${RUSTDESK_CONFIG:-}}"

    rustdesk_supports_config_import
    support_status=$?

    case "$support_status" in
        0)
            echo "已检查当前 AppImage：检测到普通用户可用的 --config 导入入口。"
            ;;
        1)
            echo "已检查当前 AppImage：未检测到 --config 导入入口。"
            show_manual_config
            return 0
            ;;
        3)
            echo "已检查当前 AppImage：包含 --config，但要求已安装并使用管理员权限。"
            echo "本工具以便携 AppImage 方式运行且不会使用 sudo，因此跳过自动导入。"
            if [ -z "$config_string" ]; then
                echo "同时未配置 RustDesk 导出的服务器配置字符串。"
            fi
            show_manual_config
            return 0
            ;;
        *)
            echo "无法解包当前 AppImage，不能确认 --config 支持情况。"
            show_manual_config
            return 0
            ;;
    esac

    if [ -z "$config_string" ]; then
        echo "未配置 RustDesk 导出的服务器配置字符串，跳过自动导入。"
        show_manual_config
        return 0
    fi

    echo "正在以当前用户导入 RustDesk 服务器配置（不会使用 sudo）..."
    if "$RUSTDESK" --config "$config_string" >/dev/null 2>&1; then
        echo "已调用 --config，请在 RustDesk 网络设置中确认服务器配置。"
        log "RustDesk服务器配置导入命令执行完成"
    else
        echo "RustDesk --config 导入失败，未进行提权操作。"
        log "RustDesk服务器配置导入失败"
        show_manual_config
    fi
}

install_rustdesk() {
    local download_tmp
    local actual_sha256
    local expected_sha256

    if ! require_command curl; then
        log "RustDesk安装失败: 缺少curl"
        return 1
    fi

    if ! validate_rustdesk_settings; then
        return 1
    fi

    if ! mkdir -p "$APP_DIR"; then
        echo "无法创建应用目录: $APP_DIR"
        log "RustDesk安装失败: 无法创建应用目录"
        return 1
    fi

    download_tmp="$(mktemp "$APP_DIR/.rustdesk.AppImage.download.XXXXXX")" || {
        echo "无法创建临时下载文件。"
        log "RustDesk安装失败: 无法创建临时文件"
        return 1
    }

    echo "[1/4] 下载 RustDesk..."
    if ! curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$RUSTDESK_CONNECT_TIMEOUT" \
        --max-time "$RUSTDESK_MAX_TIME" \
        --retry "$RUSTDESK_RETRIES" \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$download_tmp" \
        "$RUSTDESK_DOWNLOAD"; then
        echo "下载失败，已保留现有 RustDesk。"
        rm -f -- "$download_tmp"
        log "RustDesk下载失败，已保留旧版本"
        return 1
    fi

    echo "[2/4] 校验 SHA256..."
    actual_sha256="$(calculate_sha256 "$download_tmp")" || {
        echo "SHA256 计算失败，已保留现有 RustDesk。"
        rm -f -- "$download_tmp"
        log "RustDesk校验失败: 无法计算SHA256，已保留旧版本"
        return 1
    }
    expected_sha256="$(printf '%s' "$RUSTDESK_SHA256" | tr '[:upper:]' '[:lower:]')"

    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "SHA256 校验失败，已保留现有 RustDesk。"
        echo "期望: $expected_sha256"
        echo "实际: $actual_sha256"
        rm -f -- "$download_tmp"
        log "RustDesk校验失败: SHA256不匹配，已保留旧版本"
        return 1
    fi

    echo "[3/4] 安装已校验的 AppImage..."
    if ! chmod +x "$download_tmp"; then
        echo "添加执行权限失败，已保留现有 RustDesk。"
        rm -f -- "$download_tmp"
        log "RustDesk添加执行权限失败，已保留旧版本"
        return 1
    fi

    # 临时文件与目标在同一目录；仅在下载和校验全部成功后原子替换旧版本。
    if ! mv -f -- "$download_tmp" "$RUSTDESK"; then
        echo "替换 RustDesk 失败，现有版本未被主动删除。"
        rm -f -- "$download_tmp"
        log "RustDesk替换失败"
        return 1
    fi

    echo "[4/4] 安装完成"
    echo "位置: $RUSTDESK"
    log "RustDesk安装完成: $RUSTDESK"

    configure_installed_rustdesk
}

config_rustdesk() {
    echo ""
    echo "RustDesk服务器配置"
    echo ""
    echo "ID服务器：${RUSTDESK_ID_SERVER:-未配置}"
    echo "中继服务器：${RUSTDESK_RELAY_SERVER:-未配置}"
    echo "API：${RUSTDESK_API:-未配置}"
    echo "Key：${RUSTDESK_KEY:-未配置}"

    case "${RUSTDESK_API:-}" in
        http://*)
            echo "警告：API当前使用HTTP，请勿通过它提交账号、密码或Token。"
            ;;
    esac

    if [ -f "$RUSTDESK" ]; then
        echo ""
        configure_installed_rustdesk
    else
        echo ""
        echo "尚未安装 RustDesk AppImage，无法检查 --config 支持情况。"
        show_manual_config
    fi
}

rustdesk_menu() {
    local c

    echo "================================"
    echo " 周克儿工具箱 - RustDesk安装"
    echo "================================"
    echo "1. 安装或更新 RustDesk"
    echo "2. 查看或导入服务器配置"
    echo "0. 返回"

    read -r -p "选择:" c

    case "$c" in
        1)
            install_rustdesk
            ;;
        2)
            config_rustdesk
            ;;
        0)
            return 0
            ;;
        *)
            echo "错误"
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    rustdesk_menu
fi
