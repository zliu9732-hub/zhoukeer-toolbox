#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

TODESK_CONNECT_TIMEOUT=15
TODESK_MAX_TIME=1200
TODESK_RETRIES=3
TODESK_READONLY_CHANGED=0
TODESK_TMP_DIR=""
TODESK_DOWNLOADED_PACKAGE=""

load_config

cleanup_todesk() {
    if [ -n "$TODESK_TMP_DIR" ] && [ -d "$TODESK_TMP_DIR" ]; then
        rm -rf -- "$TODESK_TMP_DIR"
    fi

    if [ "$TODESK_READONLY_CHANGED" -eq 1 ]; then
        echo "正在恢复 SteamOS 只读保护..."
        if ! toolbox_sudo steamos-readonly enable; then
            echo "警告：未能恢复只读保护，请执行: sudo steamos-readonly enable"
            log "ToDesk安装警告: 未能恢复SteamOS只读保护"
        fi
    fi
}

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

validate_todesk_settings() {
    local value

    for value in TODESK_ARCHIVE_URL TODESK_PACKAGE_NAME TODESK_PACKAGE_SHA256; do
        eval "[ -n \"\${$value:-}\" ]" || {
            echo "ToDesk配置缺失: $value"
            return 1
        }
    done

    [ "${#TODESK_PACKAGE_SHA256}" -eq 64 ] || {
        echo "ToDesk SHA256必须是64位十六进制字符串。"
        return 1
    }
    case "$TODESK_PACKAGE_SHA256" in
        *[!0-9A-Fa-f]*)
            echo "ToDesk SHA256包含无效字符。"
            return 1
            ;;
    esac

    case "$TODESK_ARCHIVE_URL" in
        https://*) ;;
        *)
            echo "ToDesk下载地址必须使用HTTPS。"
            return 1
            ;;
    esac
}

show_todesk_warning() {
    echo "================================"
    echo " ToDesk SteamOS 安装说明"
    echo "================================"
    echo "来源：mclanbai/archtodesk 第三方适配包"
    echo "版本：4.7.2.0"
    echo ""
    echo "使用前必须先在游戏模式完成："
    echo "1. Steam键 → 设置 → 系统 → 开启“启用开发者模式”"
    echo "2. 返回设置侧栏 → 进入“开发者”"
    echo "3. 在开发者页面的“杂项”中开启“使用旧版X11桌面模式”"
    echo "4. 重新进入桌面模式后再安装并启动ToDesk"
    echo ""
    echo "该操作将："
    echo "- 下载约80MB的第三方ToDesk软件包并校验SHA256"
    echo "- 优先读取桌面密码.txt自动验证，记录不可用时由系统询问"
    echo "- 临时关闭SteamOS只读保护"
    echo "- 使用pacman安装系统软件并启用todeskd服务"
    echo "- 完成后恢复SteamOS只读保护"
    echo ""
    echo "SteamOS系统更新可能移除通过pacman安装的软件。"
    echo "本工具不会删除已有ToDesk配置，也不会使用 chmod 777。"
}

confirm_todesk_install() {
    local answer

    show_todesk_warning
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "新机初始化已确认，继续ToDesk安装。"
        return 0
    fi

    echo ""
    read -r -p "确认安装请输入 INSTALL：" answer
    [ "$answer" = "INSTALL" ]
}

download_todesk_package() {
    local archive_file
    local package_member
    local extracted_package
    local package_tmp
    local actual_sha256
    local expected_sha256

    mkdir -p "$APP_DIR" || return 1
    TODESK_TMP_DIR="$(mktemp -d "$APP_DIR/.todesk-download.XXXXXX")" || return 1
    archive_file="$TODESK_TMP_DIR/archtodesk.tar.gz"

    echo "正在下载ToDesk适配包..."
    if ! curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$TODESK_CONNECT_TIMEOUT" \
        --max-time "$TODESK_MAX_TIME" \
        --retry "$TODESK_RETRIES" \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$archive_file" \
        "$TODESK_ARCHIVE_URL"; then
        echo "ToDesk下载失败。"
        return 1
    fi

    package_member="$(
        tar -tzf "$archive_file" 2>/dev/null |
            awk -v name="$TODESK_PACKAGE_NAME" '
                $0 == name || index($0, "/" name) == length($0) - length(name) {
                    print
                    exit
                }
            '
    )"
    case "$package_member" in
        ""|/*|../*|*/../*|*/..)
            echo "ToDesk下载包结构异常，已停止。"
            return 1
            ;;
    esac

    if ! tar -xzf "$archive_file" -C "$TODESK_TMP_DIR" "$package_member"; then
        echo "无法从下载包提取ToDesk软件包。"
        return 1
    fi
    extracted_package="$TODESK_TMP_DIR/$package_member"

    actual_sha256="$(calculate_sha256 "$extracted_package")" || {
        echo "无法计算ToDesk SHA256。"
        return 1
    }
    expected_sha256="$(printf '%s' "$TODESK_PACKAGE_SHA256" | tr '[:upper:]' '[:lower:]')"
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "ToDesk SHA256校验失败，已停止安装。"
        echo "期望: $expected_sha256"
        echo "实际: $actual_sha256"
        return 1
    fi
    echo "ToDesk SHA256校验通过"

    package_tmp="$APP_DIR/.${TODESK_PACKAGE_NAME}.verified.$$"
    if ! mv -- "$extracted_package" "$package_tmp"; then
        echo "无法保存已校验的ToDesk软件包。"
        return 1
    fi
    if ! mv -f -- "$package_tmp" "$APP_DIR/$TODESK_PACKAGE_NAME"; then
        rm -f -- "$package_tmp"
        echo "无法更新本地ToDesk软件包。"
        return 1
    fi

    rm -rf -- "$TODESK_TMP_DIR"
    TODESK_TMP_DIR=""
    TODESK_DOWNLOADED_PACKAGE="$APP_DIR/$TODESK_PACKAGE_NAME"
}

install_todesk() {
    local package_path
    local readonly_status

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "ToDesk安装仅支持真实SteamOS环境。"
        return 1
    fi

    for command_name in curl tar sudo pacman pacman-key systemctl steamos-readonly; do
        require_command "$command_name" || return 1
    done
    validate_todesk_settings || return 1
    confirm_todesk_install || {
        echo "已取消ToDesk安装。"
        return 0
    }

    download_todesk_package || return 1
    package_path="$TODESK_DOWNLOADED_PACKAGE"

    echo "安装需要Steam Deck管理员密码。"
    if ! toolbox_sudo true; then
        echo "管理员验证失败，未修改系统。"
        return 1
    fi

    readonly_status="$(steamos-readonly status 2>/dev/null || true)"
    if printf '%s' "$readonly_status" | grep -qi 'enabled'; then
        # 先登记需要恢复并注册处理，再修改只读状态，避免异常中断留下关闭状态。
        TODESK_READONLY_CHANGED=1
        trap cleanup_todesk EXIT INT TERM
        if ! toolbox_sudo steamos-readonly disable; then
            echo "无法关闭SteamOS只读保护。"
            cleanup_todesk
            TODESK_READONLY_CHANGED=0
            trap - EXIT INT TERM
            return 1
        fi
    else
        trap cleanup_todesk EXIT INT TERM
    fi

    echo "正在准备pacman密钥..."
    toolbox_sudo pacman-key --init || return 1
    toolbox_sudo pacman-key --populate || return 1

    echo "正在安装ToDesk..."
    if ! toolbox_sudo pacman -U --noconfirm "$package_path"; then
        echo "ToDesk安装失败；未删除原有配置。"
        log "ToDesk安装失败: pacman返回错误"
        return 1
    fi

    if ! toolbox_sudo systemctl enable --now todeskd.service; then
        echo "ToDesk已安装，但后台服务启动失败。"
        log "ToDesk安装警告: todeskd服务启动失败"
    fi

    if [ -f /usr/share/applications/todesk.desktop ]; then
        mkdir -p "$HOME/Desktop"
        cp /usr/share/applications/todesk.desktop "$HOME/Desktop/ToDesk.desktop"
        chmod +x "$HOME/Desktop/ToDesk.desktop"
    fi

    cleanup_todesk
    TODESK_READONLY_CHANGED=0
    trap - EXIT INT TERM
    echo "ToDesk安装完成。"
    log "ToDesk安装完成"
}

todesk_menu() {
    local choice

    echo "1. 安装或更新ToDesk"
    echo "2. 查看安装风险说明"
    echo "0. 返回"
    read -r -p "选择：" choice

    case "$choice" in
        1) install_todesk ;;
        2) show_todesk_warning ;;
        0) return 0 ;;
        *) echo "输入错误" ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        --install) install_todesk ;;
        "") todesk_menu ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
fi
