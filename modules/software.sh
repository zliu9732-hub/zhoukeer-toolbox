#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

FLATHUB_CN_REMOTE="flathub-cn"
FLATHUB_OFFICIAL_REMOTE="flathub"
FLATHUB_CN_URL="${ZHOUKEER_FLATHUB_CN_URL:-https://mirrors.ustc.edu.cn/flathub}"
FLATHUB_REPO_FILE_PRIMARY="https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo"
FLATHUB_REPO_FILE_FALLBACK="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATHUB_APPREF_BASE="https://flathub.org/repo/appstream"
FLATPAK_INSTALL_TIMEOUT="${ZHOUKEER_FLATPAK_INSTALL_TIMEOUT:-1800}"
FLATPAK_APPREF_TIMEOUT="${ZHOUKEER_FLATPAK_APPREF_TIMEOUT:-300}"

software_details() {
    case "$1" in
        wechat)
            SOFTWARE_NAME="微信"
            SOFTWARE_DESKTOP_NAME="微信"
            SOFTWARE_APP_ID="com.tencent.WeChat"
            SOFTWARE_CATEGORIES="Network;InstantMessaging;"
            ;;
        qq)
            SOFTWARE_NAME="QQ"
            SOFTWARE_DESKTOP_NAME="QQ"
            SOFTWARE_APP_ID="com.qq.QQ"
            SOFTWARE_CATEGORIES="Network;InstantMessaging;"
            ;;
        browser)
            SOFTWARE_NAME="Google Chrome浏览器"
            SOFTWARE_DESKTOP_NAME="Chrome浏览器"
            SOFTWARE_APP_ID="com.google.Chrome"
            SOFTWARE_CATEGORIES="Network;WebBrowser;"
            ;;
        rustdesk)
            SOFTWARE_NAME="RustDesk"
            SOFTWARE_DESKTOP_NAME="RustDesk"
            SOFTWARE_APP_ID="com.rustdesk.RustDesk"
            SOFTWARE_CATEGORIES="Network;RemoteAccess;"
            ;;
        anydesk)
            SOFTWARE_NAME="AnyDesk"
            SOFTWARE_DESKTOP_NAME="AnyDesk"
            SOFTWARE_APP_ID="com.anydesk.Anydesk"
            SOFTWARE_CATEGORIES="Network;RemoteAccess;"
            ;;
        *)
            echo "未知软件: $1"
            return 1
            ;;
    esac
}

confirm_software_install() {
    local answer

    echo "将通过Flatpak以当前用户身份安装：$SOFTWARE_NAME"
    echo "应用ID：$SOFTWARE_APP_ID"
    echo "下载顺序：中科大Flathub缓存 → Flathub官方源"
    case "$SOFTWARE_APP_ID" in
        com.tencent.WeChat|com.qq.QQ)
            echo "注意：Flathub页面将该应用标记为非腾讯官方验证的社区封装。"
            ;;
        com.anydesk.Anydesk)
            echo "注意：AnyDesk 的 Flathub 包由社区维护；首次启动请按软件提示授权。"
            ;;
    esac

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

download_flathub_repo_file() {
    local destination="$1"
    local url

    for url in "$FLATHUB_REPO_FILE_PRIMARY" "$FLATHUB_REPO_FILE_FALLBACK"; do
        echo "正在获取Flathub签名配置：$url"
        if curl \
            --fail \
            --location \
            --silent \
            --show-error \
            --proto '=https' \
            --proto-redir '=https' \
            --connect-timeout 10 \
            --max-time 30 \
            --retry 2 \
            --output "$destination" \
            "$url" && \
            grep -q '^\[Flatpak Repo\]$' "$destination" && \
            grep -q '^GPGKey=' "$destination"; then
            return 0
        fi
    done

    rm -f -- "$destination"
    echo "无法获取Flathub签名配置。"
    return 1
}

flatpak_remote_exists() {
    flatpak remotes --user --columns=name 2>/dev/null | grep -Fxq "$1"
}

ensure_flatpak_remotes() {
    local repo_file

    repo_file="$(mktemp)" || return 1
    if ! download_flathub_repo_file "$repo_file"; then
        rm -f -- "$repo_file"
        return 1
    fi

    if ! flatpak_remote_exists "$FLATHUB_CN_REMOTE"; then
        echo "正在添加Flathub国内缓存源..."
        if ! flatpak remote-add --user --if-not-exists \
            "$FLATHUB_CN_REMOTE" "$repo_file"; then
            rm -f -- "$repo_file"
            return 1
        fi
    fi

    if ! flatpak remote-modify --user "$FLATHUB_CN_REMOTE" \
        --url="$FLATHUB_CN_URL"; then
        echo "无法配置Flathub国内缓存源。"
        rm -f -- "$repo_file"
        return 1
    fi

    # 官方源只作为国内缓存失败后的备用，不修改用户已有的官方源配置。
    if ! flatpak_remote_exists "$FLATHUB_OFFICIAL_REMOTE"; then
        echo "正在添加Flathub官方备用源..."
        if ! flatpak remote-add --user --if-not-exists \
            "$FLATHUB_OFFICIAL_REMOTE" "$repo_file"; then
            rm -f -- "$repo_file"
            return 1
        fi
    fi

    rm -f -- "$repo_file"
}

run_flatpak_install() {
    local remote="$1"
    local locale_name="C"
    local utf8_locale

    utf8_locale="$(locale -a 2>/dev/null | awk 'tolower($0) ~ /^c\.(utf-8|utf8)$/ { print; exit }')"
    if [ -n "$utf8_locale" ]; then
        locale_name="$utf8_locale"
    fi

    if command -v timeout >/dev/null 2>&1; then
        LC_ALL="$locale_name" LANG="$locale_name" \
            timeout --foreground "$FLATPAK_INSTALL_TIMEOUT" \
            flatpak install --user --noninteractive -y \
            "$remote" "$SOFTWARE_APP_ID"
    else
        LC_ALL="$locale_name" LANG="$locale_name" \
            flatpak install --user --noninteractive -y \
            "$remote" "$SOFTWARE_APP_ID"
    fi
}

run_flatpak_appref_install() {
    local appref_url="$FLATHUB_APPREF_BASE/$SOFTWARE_APP_ID.flatpakref"
    echo "正在使用Flathub官方安装描述直装 $SOFTWARE_NAME..."
    if command -v timeout >/dev/null 2>&1; then
        timeout --foreground "$FLATPAK_APPREF_TIMEOUT" \
            flatpak install --user --noninteractive -y "$appref_url"
    else
        flatpak install --user --noninteractive -y "$appref_url"
    fi
}

create_software_shortcut() {
    local desktop_dir="$HOME/Desktop"
    local desktop_file="$desktop_dir/$SOFTWARE_DESKTOP_NAME.desktop"

    mkdir -p "$desktop_dir" || return 1
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=$SOFTWARE_NAME
Comment=由周克儿工具箱安装
Exec=flatpak run $SOFTWARE_APP_ID
Icon=$SOFTWARE_APP_ID
Terminal=false
Categories=$SOFTWARE_CATEGORIES
EOF
    chmod +x "$desktop_file" || return 1

    echo "已创建桌面快捷方式：$desktop_file"
    log "$SOFTWARE_NAME 桌面快捷方式已创建: $desktop_file"
}

install_software() {
    local target="$1"

    software_details "$target" || return 1
    is_linux || {
        echo "$SOFTWARE_NAME 安装仅支持Linux/SteamOS。"
        return 1
    }
    require_command flatpak || return 1
    require_command curl || return 1

    if flatpak info "$SOFTWARE_APP_ID" >/dev/null 2>&1; then
        echo "$SOFTWARE_NAME 已安装，正在检查桌面快捷方式。"
        create_software_shortcut
        return $?
    fi

    confirm_software_install || {
        echo "已取消安装 $SOFTWARE_NAME。"
        return 0
    }
    if ! ensure_flatpak_remotes; then
        echo "Flathub远程源配置失败，将尝试官方安装描述直装。"
    fi

    echo "正在通过国内缓存安装 $SOFTWARE_NAME..."
    if ! run_flatpak_install "$FLATHUB_CN_REMOTE"; then
        echo "国内缓存安装失败或超时，切换Flathub官方备用源。"
        if ! run_flatpak_install "$FLATHUB_OFFICIAL_REMOTE" && \
            ! run_flatpak_appref_install; then
            echo "$SOFTWARE_NAME 安装失败，不会继续无限等待。"
            log "$SOFTWARE_NAME Flatpak安装失败"
            return 1
        fi
    fi

    if ! flatpak info "$SOFTWARE_APP_ID" >/dev/null 2>&1; then
        echo "$SOFTWARE_NAME 安装命令结束，但未检测到已安装应用。"
        log "$SOFTWARE_NAME Flatpak安装结果验证失败"
        return 1
    fi

    echo "$SOFTWARE_NAME 安装完成。"
    log "$SOFTWARE_NAME Flatpak安装完成"
    create_software_shortcut
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        wechat|qq|browser|rustdesk|anydesk) install_software "$1" ;;
        *) echo "用法: $0 {wechat|qq|browser|rustdesk|anydesk}"; exit 1 ;;
    esac
fi
