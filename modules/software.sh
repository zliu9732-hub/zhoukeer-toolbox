#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

load_config

FLATHUB_CN_REMOTE="flathub-cn"
FLATHUB_CN_FALLBACK_REMOTE="flathub-ustc"
FLATHUB_CN_URL="${ZHOUKEER_FLATHUB_CN_URL:-https://mirror.sjtu.edu.cn/flathub}"
FLATHUB_CN_FALLBACK_URL="${ZHOUKEER_FLATHUB_CN_FALLBACK_URL:-https://mirrors.ustc.edu.cn/flathub}"
FLATHUB_OFFICIAL_REMOTE="flathub"
FLATHUB_OFFICIAL_REPO_FILE="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_INSTALL_TIMEOUT="${ZHOUKEER_FLATPAK_INSTALL_TIMEOUT:-300}"
FLATPAK_INSTALL_RETRIES="${ZHOUKEER_FLATPAK_INSTALL_RETRIES:-1}"
FLATPAK_SOURCE_PROBE_TIMEOUT="${ZHOUKEER_FLATPAK_SOURCE_PROBE_TIMEOUT:-8}"
INSTALL_PRIMARY_REMOTE="$FLATHUB_CN_REMOTE"
INSTALL_FALLBACK_REMOTE="$FLATHUB_CN_FALLBACK_REMOTE"
case "${ZHOUKEER_FLATPAK_SOURCE_MODE:-domestic}" in
    official|domestic) FLATPAK_SOURCE_MODE="${ZHOUKEER_FLATPAK_SOURCE_MODE:-domestic}" ;;
    *) FLATPAK_SOURCE_MODE="domestic" ;;
esac

QQ_CONFIG_PRIMARY="https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json"
QQ_CONFIG_FALLBACK="https://im.qq.com/proxy/domain/qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json"
QQ_APPIMAGE_PATH="${ZHOUKEER_QQ_APPIMAGE_PATH:-$APP_DIR/QQ.AppImage}"
QQ_DOWNLOAD_TIMEOUT="${ZHOUKEER_QQ_DOWNLOAD_TIMEOUT:-600}"
QQ_MIN_BYTES="${ZHOUKEER_QQ_MIN_BYTES:-52428800}"

WECHAT_APPIMAGE_URL="${ZHOUKEER_WECHAT_APPIMAGE_URL:-https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage}"
WECHAT_APPIMAGE_PATH="${ZHOUKEER_WECHAT_APPIMAGE_PATH:-$APP_DIR/WeChat.AppImage}"
WECHAT_ICON_PATH="${ZHOUKEER_WECHAT_ICON_PATH:-$PROJECT_ROOT/assets/software/wechat.png}"
WECHAT_DOWNLOAD_TIMEOUT="${ZHOUKEER_WECHAT_DOWNLOAD_TIMEOUT:-900}"
WECHAT_MIN_BYTES="${ZHOUKEER_WECHAT_MIN_BYTES:-104857600}"

RUSTDESK_DOWNLOAD_URL="${ZHOUKEER_RUSTDESK_DOWNLOAD_URL:-https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.AppImage}"
RUSTDESK_APPIMAGE_PATH="${ZHOUKEER_RUSTDESK_APPIMAGE_PATH:-$APP_DIR/RustDesk.AppImage}"
RUSTDESK_SHA256="${ZHOUKEER_RUSTDESK_SHA256:-7902cd60a4f29817eebe2668a15c9a1952ac690e8f7b07bfe7620fedd4e28217}"
RUSTDESK_DOWNLOAD_TIMEOUT="${ZHOUKEER_RUSTDESK_DOWNLOAD_TIMEOUT:-600}"
RUSTDESK_MIN_BYTES="${ZHOUKEER_RUSTDESK_MIN_BYTES:-10485760}"

software_details() {
    SOFTWARE_INSTALL_MODE="flatpak"
    SOFTWARE_EXTRA_APP_IDS=""
    SOFTWARE_STEAM_ENTRY=0
    case "$1" in
        wechat)
            SOFTWARE_NAME="微信"
            SOFTWARE_DESKTOP_NAME="微信"
            SOFTWARE_APP_ID=""
            SOFTWARE_INSTALL_MODE="wechat_appimage"
            SOFTWARE_CATEGORIES="Network;InstantMessaging;"
            ;;
        qq)
            SOFTWARE_NAME="QQ"
            SOFTWARE_DESKTOP_NAME="QQ"
            SOFTWARE_APP_ID="com.qq.QQ"
            SOFTWARE_CATEGORIES="Network;InstantMessaging;"
            ;;
        browser)
            SOFTWARE_NAME="Firefox浏览器"
            SOFTWARE_DESKTOP_NAME="Firefox浏览器"
            SOFTWARE_APP_ID="org.mozilla.firefox"
            SOFTWARE_INSTALL_MODE="flatpak"
            SOFTWARE_CATEGORIES="Network;WebBrowser;"
            ;;
        rustdesk)
            SOFTWARE_NAME="RustDesk"
            SOFTWARE_DESKTOP_NAME="RustDesk"
            SOFTWARE_APP_ID=""
            SOFTWARE_INSTALL_MODE="rustdesk_appimage"
            SOFTWARE_CATEGORIES="Network;RemoteAccess;"
            ;;
        anydesk)
            SOFTWARE_NAME="AnyDesk"
            SOFTWARE_DESKTOP_NAME="AnyDesk"
            SOFTWARE_APP_ID="com.anydesk.Anydesk"
            SOFTWARE_CATEGORIES="Network;RemoteAccess;"
            ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        libreoffice)
            SOFTWARE_NAME="LibreOffice 办公套件"
            SOFTWARE_DESKTOP_NAME="LibreOffice"
            SOFTWARE_APP_ID="org.libreoffice.LibreOffice"
            SOFTWARE_CATEGORIES="Office;"
            ;;
        vlc)
            SOFTWARE_NAME="VLC 播放器"
            SOFTWARE_DESKTOP_NAME="VLC"
            SOFTWARE_APP_ID="org.videolan.VLC"
            SOFTWARE_CATEGORIES="AudioVideo;Player;"
            ;;
        obs)
            SOFTWARE_NAME="OBS Studio"
            SOFTWARE_DESKTOP_NAME="OBS Studio"
            SOFTWARE_APP_ID="com.obsproject.Studio"
            SOFTWARE_CATEGORIES="AudioVideo;Recorder;"
            ;;
        localsend)
            SOFTWARE_NAME="LocalSend"
            SOFTWARE_DESKTOP_NAME="LocalSend"
            SOFTWARE_APP_ID="org.localsend.localsend_app"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        peazip)
            SOFTWARE_NAME="PeaZip 压缩工具"
            SOFTWARE_DESKTOP_NAME="PeaZip"
            SOFTWARE_APP_ID="io.github.peazip.PeaZip"
            SOFTWARE_CATEGORIES="Utility;Archiving;"
            ;;
        willwill)
            SOFTWARE_NAME="WiliWili"
            SOFTWARE_DESKTOP_NAME="WiliWili"
            SOFTWARE_APP_ID="cn.xfangfang.wiliwili"
            SOFTWARE_CATEGORIES="AudioVideo;Player;"
            SOFTWARE_STEAM_ENTRY=1
            ;;
        fcitx5)
            SOFTWARE_NAME="Fcitx5 中文输入法"
            SOFTWARE_DESKTOP_NAME="Fcitx5"
            SOFTWARE_APP_ID="org.fcitx.Fcitx5"
            SOFTWARE_EXTRA_APP_IDS="org.fcitx.Fcitx5.Addon.ChineseAddons"
            SOFTWARE_CATEGORIES="Utility;InputMethods;"
            ;;
        xbox-cloud)
            SOFTWARE_NAME="Xbox 云游戏"
            SOFTWARE_DESKTOP_NAME="Xbox 云游戏"
            SOFTWARE_APP_ID="io.github.unknownskl.greenlight"
            SOFTWARE_CATEGORIES="Game;"
            SOFTWARE_STEAM_ENTRY=1
            ;;
        qqmusic)
            SOFTWARE_NAME="QQ音乐"
            SOFTWARE_DESKTOP_NAME="QQ音乐"
            SOFTWARE_APP_ID="com.qq.QQmusic"
            SOFTWARE_CATEGORIES="AudioVideo;Player;"
            ;;
        netease-music)
            SOFTWARE_NAME="网易云音乐"
            SOFTWARE_DESKTOP_NAME="网易云音乐"
            SOFTWARE_APP_ID="com.github.gmg137.netease-cloud-music-gtk"
            SOFTWARE_CATEGORIES="AudioVideo;Player;"
            ;;
        yesplaymusic)
            SOFTWARE_NAME="YesPlayMusic"
            SOFTWARE_DESKTOP_NAME="YesPlayMusic"
            SOFTWARE_APP_ID="io.github.qier222.YesPlayMusic"
            SOFTWARE_CATEGORIES="AudioVideo;Player;"
            ;;
        qbittorrent)
            SOFTWARE_NAME="qBittorrent"
            SOFTWARE_DESKTOP_NAME="qBittorrent"
            SOFTWARE_APP_ID="org.qbittorrent.qBittorrent"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        motrix)
            SOFTWARE_NAME="Motrix 下载器"
            SOFTWARE_DESKTOP_NAME="Motrix"
            SOFTWARE_APP_ID="net.agalwood.Motrix"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        freedownloadmanager)
            SOFTWARE_NAME="Free Download Manager"
            SOFTWARE_DESKTOP_NAME="Free Download Manager"
            SOFTWARE_APP_ID="org.freedownloadmanager.Manager"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        media-downloader)
            SOFTWARE_NAME="Media Downloader"
            SOFTWARE_DESKTOP_NAME="Media Downloader"
            SOFTWARE_APP_ID="io.github.mhogomchungu.media-downloader"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        flameshot)
            SOFTWARE_NAME="Flameshot 截图"
            SOFTWARE_DESKTOP_NAME="Flameshot"
            SOFTWARE_APP_ID="org.flameshot.Flameshot"
            SOFTWARE_CATEGORIES="Graphics;"
            ;;
        onlyoffice)
            SOFTWARE_NAME="OnlyOffice 办公套件"
            SOFTWARE_DESKTOP_NAME="OnlyOffice"
            SOFTWARE_APP_ID="org.onlyoffice.desktopeditors"
            SOFTWARE_CATEGORIES="Office;"
            ;;
        joplin)
            SOFTWARE_NAME="Joplin 笔记"
            SOFTWARE_DESKTOP_NAME="Joplin"
            SOFTWARE_APP_ID="net.cozic.joplin_desktop"
            SOFTWARE_CATEGORIES="Utility;"
            ;;
        heroic)
            SOFTWARE_NAME="Heroic 游戏启动器"
            SOFTWARE_DESKTOP_NAME="Heroic"
            SOFTWARE_APP_ID="com.heroicgameslauncher.hgl"
            SOFTWARE_CATEGORIES="Game;"
            SOFTWARE_STEAM_ENTRY=1
            ;;
        lutris)
            SOFTWARE_NAME="Lutris"
            SOFTWARE_DESKTOP_NAME="Lutris"
            SOFTWARE_APP_ID="net.lutris.Lutris"
            SOFTWARE_CATEGORIES="Game;"
            SOFTWARE_STEAM_ENTRY=1
            ;;
        chiaki4deck)
            SOFTWARE_NAME="Chiaki4Deck（PS5串流）"
            SOFTWARE_DESKTOP_NAME="Chiaki4Deck"
            SOFTWARE_APP_ID="io.github.streetpea.Chiaki4deck"
            SOFTWARE_CATEGORIES="Game;"
            SOFTWARE_STEAM_ENTRY=1
            ;;
        parsec)
            SOFTWARE_NAME="Parsec"
            SOFTWARE_DESKTOP_NAME="Parsec"
            SOFTWARE_APP_ID="com.parsecgaming.parsec"
            SOFTWARE_CATEGORIES="Game;"
            SOFTWARE_STEAM_ENTRY=1
            ;;
        sunshine)
            SOFTWARE_NAME="Sunshine 串流服务端"
            SOFTWARE_DESKTOP_NAME="Sunshine"
            SOFTWARE_APP_ID="dev.lizardbyte.app.Sunshine"
            SOFTWARE_INSTALL_MODE="sunshine_flatpak"
            SOFTWARE_CATEGORIES="Game;Network;RemoteAccess;"
            ;;
        *)
            echo "未知软件: $1"
            return 1
            ;;
    esac
}

SOFTWARE_TARGETS=(
    wechat qq browser rustdesk anydesk baidunetdisk libreoffice vlc obs
    localsend peazip willwill fcitx5 xbox-cloud
    qqmusic netease-music yesplaymusic qbittorrent motrix freedownloadmanager
    media-downloader flameshot onlyoffice joplin heroic lutris chiaki4deck parsec
    sunshine
)

software_print_domestic_source_hint() {
    if [ "$FLATPAK_SOURCE_MODE" = "official" ]; then
        echo "提示：当前使用官方 Flathub；如国内网络下载较慢，可在 Bazzite 使用准备中手动选择国内 Flatpak 源。"
    else
        echo "提示：请先在Renkit【初始化国内源并检测系统组件】中初始化国内源后重试。"
    fi
}

confirm_software_install() {
    local answer

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    case "$SOFTWARE_INSTALL_MODE" in
        appimage)
            echo "将从腾讯QQ官网国内CDN下载官方AppImage：$SOFTWARE_NAME"
            ;;
        wechat_appimage)
            echo "将从微信Linux版官网下载官方x86_64 AppImage。"
            ;;
        flatpak_official)
            echo "将从官方 Flathub 安装 Firefox（org.mozilla.firefox）。"
            ;;
        rustdesk_appimage)
            echo "将从 RustDesk 作者 GitHub Release 下载 x86_64 AppImage。"
            ;;
        sunshine_flatpak)
            echo "将通过 Flatpak 安装 Sunshine 串流服务端。"
            echo "安装后会读取 Sunshine 官方包内的服务和输入规则，并使用桌面管理员密码记录自动配置，不重复弹出验证窗口。"
            ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            echo "将通过 Flatpak 国内源安装：$SOFTWARE_NAME"
            ;;
        *)
            if [ "$FLATPAK_SOURCE_MODE" = "official" ]; then
                echo "将通过官方 Flathub 安装：$SOFTWARE_NAME"
            else
                echo "将通过 Flatpak 国内源安装：$SOFTWARE_NAME"
            fi
            ;;
    esac

    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

download_official_flathub_repo_file() {
    local destination="$1"

    echo "正在获取 Flathub 官方签名配置..."
    download_policy_url_allowed "$FLATHUB_OFFICIAL_REPO_FILE" || return 1
    if curl \
        --fail \
        --location \
        --silent \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 10 \
        --max-time 30 \
        --retry 2 \
        --max-filesize "$(download_policy_max_bytes "$FLATHUB_OFFICIAL_REPO_FILE")" \
        --output "$destination" \
        "$FLATHUB_OFFICIAL_REPO_FILE" && download_policy_response_is_safe "$FLATHUB_OFFICIAL_REPO_FILE" "$destination" && \
        grep -q '^\[Flatpak Repo\]$' "$destination" && \
        grep -q '^GPGKey=' "$destination"; then
        return 0
    fi
    rm -f -- "$destination"
    echo "无法获取 Flathub 官方签名配置。"
    return 1
}

flatpak_remote_exists() {
    flatpak remotes --user --columns=name 2>/dev/null | grep -Fxq "$1"
}

flatpak_system_remote_exists() {
    flatpak remotes --system --columns=name 2>/dev/null | grep -Fxq "$1"
}

flatpak_remote_scope() {
    if flatpak_remote_exists "$1"; then
        printf '%s\n' user
    elif flatpak_system_remote_exists "$1"; then
        printf '%s\n' system
    else
        printf '%s\n' missing
    fi
}

flatpak_any_remote_exists() {
    flatpak remotes --user --columns=name 2>/dev/null | grep -q . && return 0
    flatpak remotes --system --columns=name 2>/dev/null | grep -q .
}

confirm_domestic_flatpak_risk() {
    local answer

    echo "警告：以下国内 Flatpak 远程源将关闭软件包签名验证："
    echo "- $FLATHUB_CN_REMOTE: $FLATHUB_CN_URL"
    echo "- $FLATHUB_CN_FALLBACK_REMOTE: $FLATHUB_CN_FALLBACK_URL"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit界面确认，正在继续配置。"
        return 0
    fi
    read -r -p "确认信任以上镜像并关闭签名验证，请输入 DOMESTIC：" answer
    [ "$answer" = "DOMESTIC" ]
}

confirm_official_flatpak_restore() {
    local answer

    echo "将恢复官方 Flathub：https://dl.flathub.org/repo/"
    echo "将重新启用 GPG 验证，并移除 $FLATHUB_CN_REMOTE 和 $FLATHUB_CN_FALLBACK_REMOTE。"
    detect_platform
    if [ "$IS_STEAMOS" -eq 1 ]; then
        echo "同时会移除由Renkit写入的 archlinuxcn 配置；用户原有配置不会被删除。"
    else
        echo "不会修改 Bazzite 系统更新源。"
    fi
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit界面确认，正在恢复官方源。"
        return 0
    fi
    read -r -p "确认恢复官方源请输入 RESTORE：" answer
    [ "$answer" = "RESTORE" ]
}

configure_domestic_flatpak_remote() {
    local remote="$1"
    local url="$2"
    local display_name="$3"
    local scope

    detect_platform
    if [ "$IS_BAZZITE" -eq 1 ]; then
        if flatpak_remote_exists "$remote"; then
            scope=user
        else
            scope=missing
        fi
    else
        scope="$(flatpak_remote_scope "$remote")"
    fi
    if [ "$scope" = "missing" ]; then
        if ! timeout --foreground 30 flatpak remote-add --user --if-not-exists \
            --no-gpg-verify "$remote" "$url"; then
            log "未能添加${display_name}Flathub缓存源: $remote"
            return 1
        fi
        scope=user
    fi

    if [ "$scope" = "system" ]; then
        log "沿用旧版系统级 Flatpak 远程: $remote"
        if ! toolbox_sudo timeout --foreground 30 flatpak remote-modify --system \
            "$remote" --url="$url" || \
           ! toolbox_sudo timeout --foreground 30 flatpak remote-modify --system \
            --no-gpg-verify "$remote"; then
            log "未能更新系统级${display_name}Flathub缓存源: $remote"
            return 1
        fi
    else
        if ! timeout --foreground 30 flatpak remote-modify --user \
            "$remote" --url="$url" || \
           ! timeout --foreground 30 flatpak remote-modify --user \
            --no-gpg-verify "$remote"; then
            log "未能更新${display_name}Flathub缓存源: $remote"
            return 1
        fi
    fi
}

ensure_flatpak_remotes() {
    detect_platform
    if [ "${ZHOUKEER_FORCE_FLATPAK_RECONFIGURE:-0}" != "1" ]; then
        if [ "$IS_BAZZITE" -eq 1 ]; then
            if flatpak_remote_exists "$FLATHUB_CN_REMOTE" && \
               flatpak_remote_exists "$FLATHUB_CN_FALLBACK_REMOTE"; then
                return 0
            fi
        elif [ "$(flatpak_remote_scope "$FLATHUB_CN_REMOTE")" != "missing" ] && \
             [ "$(flatpak_remote_scope "$FLATHUB_CN_FALLBACK_REMOTE")" != "missing" ]; then
            return 0
        fi
    fi
    confirm_domestic_flatpak_risk || {
        echo "已取消国内 Flatpak 源配置，未修改任何远程源。"
        return 1
    }

    configure_domestic_flatpak_remote "$FLATHUB_CN_REMOTE" \
        "$FLATHUB_CN_URL" "上海交大" || return 1
    configure_domestic_flatpak_remote "$FLATHUB_CN_FALLBACK_REMOTE" \
        "$FLATHUB_CN_FALLBACK_URL" "中科大" || return 1
}

run_flatpak_install() {
    local remote="$1"
    local locale_name="C"
    local utf8_locale
    local attempt=1

    utf8_locale="$(locale -a 2>/dev/null | awk 'tolower($0) ~ /^c\.(utf-8|utf8)$/ { print; exit }')"
    if [ -n "$utf8_locale" ]; then
        locale_name="$utf8_locale"
    fi

    while [ "$attempt" -le "$FLATPAK_INSTALL_RETRIES" ]; do
        if LC_ALL="$locale_name" LANG="$locale_name" \
            timeout --foreground "$FLATPAK_INSTALL_TIMEOUT" \
            flatpak install --user --noninteractive -y "$remote" "$SOFTWARE_APP_ID" \
            ${SOFTWARE_EXTRA_APP_IDS:-}; then
            return 0
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

ensure_official_flathub_remote() {
    if flatpak_remote_exists "$FLATHUB_OFFICIAL_REMOTE"; then
        return 0
    fi

    echo "正在添加官方 Flathub 源..."
    timeout --foreground 30 flatpak remote-add --user --if-not-exists \
        "$FLATHUB_OFFICIAL_REMOTE" "$FLATHUB_OFFICIAL_REPO_FILE"
}

install_official_firefox_flatpak() {
    echo "正在从官方 Flathub 安装 Firefox..."
    if ! ensure_official_flathub_remote; then
        echo "官方 Flathub 源配置失败，已停止。"
        return 1
    fi
    if ! run_flatpak_install "$FLATHUB_OFFICIAL_REMOTE"; then
        echo "Firefox 官方 Flathub 安装失败或超时，已停止。"
        return 1
    fi
}

measure_source_seconds() {
    local url="$1"
    local elapsed

    download_policy_url_allowed "$url" || return 1
    elapsed="$(curl --fail --location --silent --output /dev/null \
        --proto '=https' --proto-redir '=https' \
        --connect-timeout "$FLATPAK_SOURCE_PROBE_TIMEOUT" \
        --max-time "$FLATPAK_SOURCE_PROBE_TIMEOUT" \
        --write-out '%{time_total}' "$url" 2>/dev/null || true)"
    case "$elapsed" in
        ''|*[!0-9.]*|.*) return 1 ;;
        *) printf '%s\n' "$elapsed" ;;
    esac
}

choose_install_remotes() {
    local primary_seconds fallback_seconds

    INSTALL_PRIMARY_REMOTE="$FLATHUB_CN_REMOTE"
    INSTALL_FALLBACK_REMOTE="$FLATHUB_CN_FALLBACK_REMOTE"
    primary_seconds="$(measure_source_seconds "$FLATHUB_CN_URL/summary.idx" || true)"
    fallback_seconds="$(measure_source_seconds "$FLATHUB_CN_FALLBACK_URL/summary.idx" || true)"

    if [ -n "$primary_seconds" ] && [ -n "$fallback_seconds" ] && \
        awk "BEGIN { exit !($fallback_seconds < $primary_seconds) }"; then
        INSTALL_PRIMARY_REMOTE="$FLATHUB_CN_FALLBACK_REMOTE"
        INSTALL_FALLBACK_REMOTE="$FLATHUB_CN_REMOTE"
    fi
    log "$SOFTWARE_NAME 下载源顺序: $INSTALL_PRIMARY_REMOTE -> $INSTALL_FALLBACK_REMOTE"
}

file_size_bytes() {
    stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1" 2>/dev/null
}

appimage_is_valid() {
    local image_file="$1"
    local minimum_bytes="$2"
    local image_size magic

    [ -f "$image_file" ] || return 1
    image_size="$(file_size_bytes "$image_file" || true)"
    case "$image_size" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$image_size" -ge "$minimum_bytes" ] || return 1

    magic="$(od -An -tx1 -N4 "$image_file" 2>/dev/null | tr -d '[:space:]')"
    [ "$magic" = "7f454c46" ]
}

qq_appimage_is_valid() {
    appimage_is_valid "$1" "$QQ_MIN_BYTES"
}

wechat_appimage_is_valid() {
    appimage_is_valid "$1" "$WECHAT_MIN_BYTES"
}

rustdesk_appimage_is_valid() {
    appimage_is_valid "$1" "$RUSTDESK_MIN_BYTES"
}

calculate_sha256() {
    local file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

resolve_qq_appimage_url() {
    local config_file config_url appimage_url

    config_file="$(mktemp)" || return 1
    for config_url in "$QQ_CONFIG_PRIMARY" "$QQ_CONFIG_FALLBACK"; do
        download_policy_url_allowed "$config_url" || continue
        if curl \
            --fail \
            --location \
            --silent \
            --proto '=https' \
            --proto-redir '=https' \
            --connect-timeout 10 \
            --max-time 30 \
            --retry 2 \
            --max-filesize "$(download_policy_max_bytes "$config_url")" \
            --output "$config_file" \
            "$config_url" && download_policy_response_is_safe "$config_url" "$config_file"; then
            appimage_url="$(grep -o '"appimage"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" | \
                head -n 1 | sed 's/^"appimage"[[:space:]]*:[[:space:]]*"//; s/"$//' || true)"
            case "$appimage_url" in
                https://qqdl.gtimg.cn/qqfile/*.AppImage)
                    rm -f -- "$config_file"
                    printf '%s\n' "$appimage_url"
                    return 0
                    ;;
            esac
        fi
    done

    rm -f -- "$config_file"
    return 1
}

install_official_qq_appimage() (
    local architecture appimage_url parent_dir temp_file backup_file

    architecture="$(uname -m)"
    case "$architecture" in
        x86_64|amd64) ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        *)
            echo "腾讯官网当前未提供适用于 $architecture 的QQ AppImage安装入口。"
            return 1
            ;;
    esac

    echo "正在向腾讯官网查询最新版QQ下载地址..."
    appimage_url="$(resolve_qq_appimage_url)" || {
        echo "未能从腾讯官网获取QQ下载地址，请稍后重试。"
        return 1
    }

    parent_dir="$(dirname "$QQ_APPIMAGE_PATH")"
    mkdir -p "$parent_dir" || return 1
    temp_file="$QQ_APPIMAGE_PATH.new.$$"
    backup_file="$QQ_APPIMAGE_PATH.backup.$$"

    cleanup_qq_download() {
        rm -f -- "$temp_file"
        if [ -f "$backup_file" ] && [ ! -e "$QQ_APPIMAGE_PATH" ]; then
            mv -- "$backup_file" "$QQ_APPIMAGE_PATH" 2>/dev/null || true
        else
            rm -f -- "$backup_file"
        fi
    }
    trap cleanup_qq_download EXIT INT TERM

    echo "正在从腾讯国内CDN下载QQ，最长等待 $QQ_DOWNLOAD_TIMEOUT 秒..."
    download_policy_url_allowed "$appimage_url" || { echo "QQ 下载地址不在受控来源清单中。"; return 1; }
    if ! curl \
        --fail \
        --location \
        --progress-meter \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time "$QQ_DOWNLOAD_TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --max-filesize "$(download_policy_max_bytes "$appimage_url")" \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --referer "https://im.qq.com/" \
        --output "$temp_file" \
        "$appimage_url" \
        2> >(download_progress_filter "QQ" >&2); then
        echo "QQ下载失败或超时，已停止；原有版本未受影响。"
        return 1
    fi
    download_policy_response_is_safe "$appimage_url" "$temp_file" || {
        echo "QQ 下载响应格式或大小异常，已丢弃。"
        return 1
    }

    if ! qq_appimage_is_valid "$temp_file"; then
        echo "QQ下载文件不完整或格式不正确，已丢弃；原有版本未受影响。"
        return 1
    fi
    chmod 0755 "$temp_file" || return 1

    if [ -e "$QQ_APPIMAGE_PATH" ]; then
        mv -- "$QQ_APPIMAGE_PATH" "$backup_file" || return 1
    fi
    if ! mv -- "$temp_file" "$QQ_APPIMAGE_PATH"; then
        echo "QQ文件替换失败，正在恢复原有版本。"
        return 1
    fi
    rm -f -- "$backup_file"
    trap - EXIT INT TERM

    echo "QQ安装完成：$QQ_APPIMAGE_PATH"
    log "QQ官方AppImage安装完成: $QQ_APPIMAGE_PATH"
)

install_official_wechat_appimage() (
    local architecture parent_dir temp_file backup_file

    architecture="$(uname -m)"
    case "$architecture" in
        x86_64|amd64) ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        *)
            echo "当前微信官方AppImage不适用于 $architecture 架构。"
            return 1
            ;;
    esac

    parent_dir="$(dirname "$WECHAT_APPIMAGE_PATH")"
    mkdir -p "$parent_dir" || return 1
    temp_file="$WECHAT_APPIMAGE_PATH.new.$$"
    backup_file="$WECHAT_APPIMAGE_PATH.backup.$$"

    cleanup_wechat_download() {
        rm -f -- "$temp_file"
        if [ -f "$backup_file" ] && [ ! -e "$WECHAT_APPIMAGE_PATH" ]; then
            mv -- "$backup_file" "$WECHAT_APPIMAGE_PATH" 2>/dev/null || true
        else
            rm -f -- "$backup_file"
        fi
    }
    trap cleanup_wechat_download EXIT
    trap 'exit 130' INT TERM

    echo "正在从腾讯国内CDN下载微信，最长等待 $WECHAT_DOWNLOAD_TIMEOUT 秒..."
    download_policy_url_allowed "$WECHAT_APPIMAGE_URL" || { echo "微信下载地址不在受控来源清单中。"; return 1; }
    if ! curl \
        --fail \
        --location \
        --progress-meter \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time "$WECHAT_DOWNLOAD_TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --max-filesize "$(download_policy_max_bytes "$WECHAT_APPIMAGE_URL")" \
        --output "$temp_file" \
        "$WECHAT_APPIMAGE_URL" \
        2> >(download_progress_filter "微信" >&2); then
        echo "微信下载失败或超时，已停止；原有版本未受影响。"
        return 1
    fi
    download_policy_response_is_safe "$WECHAT_APPIMAGE_URL" "$temp_file" || {
        echo "微信下载响应格式或大小异常，已丢弃。"
        return 1
    }

    if ! wechat_appimage_is_valid "$temp_file"; then
        echo "微信下载文件不完整或格式不正确，已丢弃；原有版本未受影响。"
        return 1
    fi
    chmod 0755 "$temp_file" || return 1

    if [ -e "$WECHAT_APPIMAGE_PATH" ]; then
        mv -- "$WECHAT_APPIMAGE_PATH" "$backup_file" || return 1
    fi
    if ! mv -- "$temp_file" "$WECHAT_APPIMAGE_PATH"; then
        echo "微信文件替换失败，正在恢复原有版本。"
        return 1
    fi
    rm -f -- "$backup_file"
    trap - EXIT INT TERM

    echo "微信安装完成：$WECHAT_APPIMAGE_PATH"
    log "微信官方AppImage安装完成: $WECHAT_APPIMAGE_PATH"
)

install_rustdesk_appimage() (
    local architecture parent_dir temp_file backup_file actual_sha256

    architecture="$(uname -m)"
    case "$architecture" in
        x86_64|amd64) ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        *)
            echo "当前RustDesk安装包不适用于 $architecture 架构。"
            return 1
            ;;
    esac

    parent_dir="$(dirname "$RUSTDESK_APPIMAGE_PATH")"
    mkdir -p "$parent_dir" || return 1
    temp_file="$RUSTDESK_APPIMAGE_PATH.new.$$"
    backup_file="$RUSTDESK_APPIMAGE_PATH.backup.$$"

    cleanup_rustdesk_download() {
        rm -f -- "$temp_file"
        if [ -f "$backup_file" ] && [ ! -e "$RUSTDESK_APPIMAGE_PATH" ]; then
            mv -- "$backup_file" "$RUSTDESK_APPIMAGE_PATH" 2>/dev/null || true
        else
            rm -f -- "$backup_file"
        fi
    }
    trap cleanup_rustdesk_download EXIT
    trap 'exit 130' INT TERM

    echo "正在从 RustDesk 作者 GitHub Release 下载，最长等待 $RUSTDESK_DOWNLOAD_TIMEOUT 秒..."
    if ! GITHUB_MAX_TIME="$RUSTDESK_DOWNLOAD_TIMEOUT" download_github_file \
        "$RUSTDESK_DOWNLOAD_URL" "$temp_file" "$RUSTDESK_SHA256" "RustDesk AppImage"; then
        echo "RustDesk下载失败或超时，已停止；原有版本未受影响。"
        return 1
    fi

    if ! rustdesk_appimage_is_valid "$temp_file"; then
        echo "RustDesk下载文件不完整或格式不正确，已丢弃。"
        return 1
    fi
    actual_sha256="$(calculate_sha256 "$temp_file" || true)"
    if [ -z "$actual_sha256" ] || \
        [ "$actual_sha256" != "$(printf '%s' "$RUSTDESK_SHA256" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "RustDesk安装包校验失败，已丢弃；原有版本未受影响。"
        return 1
    fi
    chmod 0755 "$temp_file" || return 1

    if [ -e "$RUSTDESK_APPIMAGE_PATH" ]; then
        mv -- "$RUSTDESK_APPIMAGE_PATH" "$backup_file" || return 1
    fi
    if ! mv -- "$temp_file" "$RUSTDESK_APPIMAGE_PATH"; then
        echo "RustDesk文件替换失败，正在恢复原有版本。"
        return 1
    fi
    rm -f -- "$backup_file"
    trap - EXIT INT TERM

    echo "RustDesk安装完成：$RUSTDESK_APPIMAGE_PATH"
    log "RustDesk 官方GitHub Release AppImage安装完成: $RUSTDESK_APPIMAGE_PATH"
)

firefox_install_is_valid() {
    [ -x "$FIREFOX_INSTALL_DIR/firefox" ] && \
        [ -f "$FIREFOX_INSTALL_DIR/application.ini" ]
}

install_firefox_archive() (
    local architecture temp_dir archive_file listing_file extracted_dir
    local parent_dir staging_dir backup_dir archive_size

    architecture="$(uname -m)"
    case "$architecture" in
        x86_64|amd64) ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        *)
            echo "当前Firefox完整包不适用于 $architecture 架构。"
            return 1
            ;;
    esac

    temp_dir="$(mktemp -d)" || return 1
    archive_file="$temp_dir/firefox.tar.xz"
    listing_file="$temp_dir/archive.list"
    parent_dir="$(dirname "$FIREFOX_INSTALL_DIR")"
    staging_dir="$parent_dir/.firefox.new.$$"
    backup_dir="$parent_dir/.firefox.backup.$$"

    cleanup_firefox_install() {
        rm -rf -- "$temp_dir" "$staging_dir"
        if [ -d "$backup_dir" ] && [ ! -e "$FIREFOX_INSTALL_DIR" ]; then
            mv -- "$backup_dir" "$FIREFOX_INSTALL_DIR" 2>/dev/null || true
        else
            rm -rf -- "$backup_dir"
        fi
    }
    trap cleanup_firefox_install EXIT
    trap 'exit 130' INT TERM

    echo "正在下载Firefox完整安装包，最长等待 $FIREFOX_DOWNLOAD_TIMEOUT 秒..."
    if ! curl \
        --fail \
        --location \
        --progress-meter \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time "$FIREFOX_DOWNLOAD_TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$archive_file" \
        "$FIREFOX_DOWNLOAD_URL" \
        2> >(download_progress_filter "Firefox" >&2); then
        echo "Firefox下载失败或超时，已停止；原有版本未受影响。"
        return 1
    fi

    archive_size="$(file_size_bytes "$archive_file" || true)"
    case "$archive_size" in
        ''|*[!0-9]*) archive_size=0 ;;
    esac
    if [ "$archive_size" -lt "$FIREFOX_MIN_BYTES" ] || \
        ! tar -tf "$archive_file" > "$listing_file" 2>/dev/null; then
        echo "Firefox安装包不完整或无法读取，已丢弃。"
        return 1
    fi
    if grep -Eq '(^/|(^|/)\.\.(/|$))' "$listing_file" || \
        grep -Ev '^firefox(/|$)' "$listing_file" | grep -q . || \
        ! grep -Fxq 'firefox/firefox' "$listing_file"; then
        echo "Firefox安装包目录结构异常，已拒绝解压。"
        return 1
    fi

    mkdir -p "$parent_dir" "$staging_dir" || return 1
    if ! tar -xJf "$archive_file" -C "$temp_dir"; then
        echo "Firefox安装包解压失败。"
        return 1
    fi
    extracted_dir="$temp_dir/firefox"
    if [ ! -x "$extracted_dir/firefox" ] || \
        [ ! -f "$extracted_dir/application.ini" ]; then
        echo "Firefox主程序缺失，已停止安装。"
        return 1
    fi
    rm -rf -- "$staging_dir"
    mv -- "$extracted_dir" "$staging_dir" || return 1

    if [ -e "$FIREFOX_INSTALL_DIR" ]; then
        mv -- "$FIREFOX_INSTALL_DIR" "$backup_dir" || return 1
    fi
    if ! mv -- "$staging_dir" "$FIREFOX_INSTALL_DIR"; then
        echo "Firefox文件替换失败，正在恢复原有版本。"
        return 1
    fi
    rm -rf -- "$backup_dir" "$temp_dir"
    trap - EXIT INT TERM

    echo "Firefox安装完成：$FIREFOX_INSTALL_DIR"
    log "Firefox完整包安装完成: $FIREFOX_INSTALL_DIR"
)

software_is_installed() {
    case "$SOFTWARE_INSTALL_MODE" in
        appimage) qq_appimage_is_valid "$QQ_APPIMAGE_PATH" ;;
        wechat_appimage) wechat_appimage_is_valid "$WECHAT_APPIMAGE_PATH" ;;
        rustdesk_appimage) rustdesk_appimage_is_valid "$RUSTDESK_APPIMAGE_PATH" ;;
        baidunetdisk)
            command -v flatpak >/dev/null 2>&1 && \
                flatpak info "$SOFTWARE_APP_ID" >/dev/null 2>&1
            ;;
        *)
            command -v flatpak >/dev/null 2>&1 && \
                flatpak info "$SOFTWARE_APP_ID" >/dev/null 2>&1
            ;;
    esac
}

sunshine_package_file_is_safe() {
    local file="$1"
    local minimum_bytes="$2"
    local maximum_bytes="$3"
    local file_bytes

    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    file_bytes="$(file_size_bytes "$file" 2>/dev/null || true)"
    case "$file_bytes" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$file_bytes" -ge "$minimum_bytes" ] && \
        [ "$file_bytes" -le "$maximum_bytes" ]
}

sunshine_export_package_file() {
    local source_path="$1"
    local destination="$2"

    timeout --foreground 30 flatpak run --command=cat \
        "$SOFTWARE_APP_ID" "$source_path" > "$destination"
}

complete_sunshine_install() (
    local temp_dir service_file module_file udev_file service_target

    for command_name in sudo install modprobe; do
        require_command "$command_name" || return 1
    done
    toolbox_sudo true || {
        echo "Sunshine 输入权限配置需要可用的桌面管理员密码记录，已停止。"
        return 1
    }

    temp_dir="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$temp_dir"' EXIT INT TERM
    service_file="$temp_dir/app-dev.lizardbyte.app.Sunshine.service"
    module_file="$temp_dir/60-sunshine.conf"
    udev_file="$temp_dir/60-sunshine.rules"
    service_target="$HOME/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service"

    echo "正在从已安装的 Sunshine 官方 Flatpak 读取必要配置..."
    sunshine_export_package_file \
        /app/share/sunshine/systemd/user/app-dev.lizardbyte.app.Sunshine.service \
        "$service_file" || return 1
    sunshine_export_package_file \
        /app/share/sunshine/modules-load.d/60-sunshine.conf \
        "$module_file" || return 1
    sunshine_export_package_file \
        /app/share/sunshine/udev/rules.d/60-sunshine.rules \
        "$udev_file" || return 1

    sunshine_package_file_is_safe "$service_file" 100 32768 && \
        grep -Fxq '[Unit]' "$service_file" && \
        grep -Fxq '[Service]' "$service_file" && \
        grep -Fxq '[Install]' "$service_file" && \
        grep -Fq 'dev.lizardbyte.app.Sunshine' "$service_file" || {
        echo "Sunshine 用户服务文件格式异常，已停止配置。"
        return 1
    }
    sunshine_package_file_is_safe "$module_file" 1 128 && \
        [ "$(tr -d '[:space:]' < "$module_file")" = "uhid" ] || {
        echo "Sunshine 内核模块配置异常，已停止配置。"
        return 1
    }
    sunshine_package_file_is_safe "$udev_file" 100 32768 && \
        grep -Fq 'KERNEL=="uinput"' "$udev_file" && \
        grep -Fq 'KERNEL=="uhid"' "$udev_file" && \
        grep -Fq 'TAG+="uaccess"' "$udev_file" || {
        echo "Sunshine 输入设备规则格式异常，已停止配置。"
        return 1
    }

    mkdir -p "$(dirname "$service_target")" || return 1
    install -m 0644 "$service_file" "$service_target" || return 1
    toolbox_sudo install -m 0644 "$module_file" \
        /etc/modules-load.d/60-sunshine.conf || return 1
    toolbox_sudo modprobe uhid || return 1
    toolbox_sudo install -m 0644 "$udev_file" \
        /etc/udev/rules.d/60-sunshine.rules || return 1

    echo "Sunshine 附加安装完成；没有调用 pkexec。若输入设备暂不可用，请重启 Steam Deck。"
    log "Sunshine Flatpak附加安装完成：使用桌面密码记录配置，无pkexec弹窗"
)

remove_sunshine_additional_install() {
    local service_target="$HOME/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service"

    require_command sudo || return 1
    toolbox_sudo true || {
        echo "Sunshine 输入规则清理需要可用的桌面管理员密码记录，已停止。"
        return 1
    }
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user stop app-dev.lizardbyte.app.Sunshine >/dev/null 2>&1 || true
    fi
    rm -f -- "$service_target" || return 1
    toolbox_sudo rm -f -- \
        /etc/modules-load.d/60-sunshine.conf \
        /etc/udev/rules.d/60-sunshine.rules || return 1
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
}

create_software_shortcut() {
    local desktop_dir="$HOME/Desktop"
    local desktop_file="$desktop_dir/$SOFTWARE_DESKTOP_NAME.desktop"
    local application_dir="$HOME/.local/share/applications"
    local application_file=""
    local exec_line icon_name

    case "$SOFTWARE_INSTALL_MODE" in
        appimage)
            exec_line="\"$QQ_APPIMAGE_PATH\""
            icon_name="qq"
            ;;
        wechat_appimage)
            exec_line="\"$WECHAT_APPIMAGE_PATH\""
            if [ ! -f "$WECHAT_ICON_PATH" ] || [ -L "$WECHAT_ICON_PATH" ]; then
                echo "缺少微信官方图标，未创建无图标的桌面入口。"
                return 1
            fi
            icon_name="$WECHAT_ICON_PATH"
            ;;
        rustdesk_appimage)
            exec_line="\"$RUSTDESK_APPIMAGE_PATH\""
            icon_name="rustdesk"
            ;;
        baidunetdisk)
            SOFTWARE_NAME="百度网盘"
            SOFTWARE_DESKTOP_NAME="百度网盘"
            SOFTWARE_APP_ID="com.baidu.NetDisk"
            SOFTWARE_CATEGORIES="Network;FileTransfer;"
            ;;
        *)
            exec_line="flatpak run $SOFTWARE_APP_ID"
            icon_name="$SOFTWARE_APP_ID"
            ;;
    esac

    mkdir -p "$desktop_dir" || return 1
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=$SOFTWARE_NAME
Comment=由Renkit安装
Exec=$exec_line
Icon=$icon_name
Terminal=false
Categories=$SOFTWARE_CATEGORIES
EOF
    chmod +x "$desktop_file" || return 1

    log "$SOFTWARE_NAME 桌面快捷方式已创建: $desktop_file"
}

find_software_steam_root() {
    local candidate

    for candidate in "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
        if [ -d "$candidate/steamapps" ] && [ -d "$candidate/userdata" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

find_software_steam_shortcut_file() {
    local steam_root="$1"
    local candidate newest="" newest_time=0 modified

    while IFS= read -r -d '' candidate; do
        modified="$(stat -c '%Y' "$candidate" 2>/dev/null || printf '0')"
        if [ "$modified" -ge "$newest_time" ]; then
            newest="$candidate"
            newest_time="$modified"
        fi
    done < <(find "$steam_root/userdata" -mindepth 3 -maxdepth 3 \
        -type f -name shortcuts.vdf -print0 2>/dev/null)
    if [ -n "$newest" ]; then
        printf '%s\n' "$newest"
        return 0
    fi
    return 1
}

software_stop_steam_for_vdf() {
    local steam_bin attempt

    command -v pgrep >/dev/null 2>&1 || return 0
    pgrep -x steam >/dev/null 2>&1 || return 0
    steam_bin="$(command -v steam 2>/dev/null || true)"
    if [ -z "$steam_bin" ] && [ -x "$HOME/.steam/steam/steam.sh" ]; then
        steam_bin="$HOME/.steam/steam/steam.sh"
    fi
    [ -n "$steam_bin" ] || return 0
    "$steam_bin" -shutdown >/dev/null 2>&1 || true
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x steam >/dev/null 2>&1 || return 0
        sleep 1
    done
    return 1
}

software_start_steam() {
    local steam_bin

    [ "${ZHOUKEER_SKIP_STEAM_RESTART:-0}" = "1" ] && return 0
    steam_bin="$(command -v steam 2>/dev/null || true)"
    if [ -z "$steam_bin" ] && [ -x "$HOME/.steam/steam/steam.sh" ]; then
        steam_bin="$HOME/.steam/steam/steam.sh"
    fi
    [ -n "$steam_bin" ] || return 0
    "$steam_bin" >/dev/null 2>&1 &
}

find_software_flatpak_icon() {
    local stem

    stem="${SOFTWARE_APP_ID##*.}"
    find "$HOME/.local/share/flatpak/exports/share/icons" \
        /var/lib/flatpak/exports/share/icons \
        -type f \( \
            -name "$SOFTWARE_APP_ID.png" -o -name "$SOFTWARE_APP_ID.svg" \
            -o -name "*${stem}.png" -o -name "*${stem}.svg" \
        \) -print 2>/dev/null | head -n 1
}

install_software_steam_entry() {
    local target="$1" steam_root shortcut_file wrapper icon

    steam_root="$(find_software_steam_root)" || {
        echo "未找到 Steam 库，请先登录 Steam 后再添加 $SOFTWARE_NAME。"
        return 0
    }
    shortcut_file="$(find_software_steam_shortcut_file "$steam_root")" || {
        echo "未找到 Steam 快捷方式文件，请先登录 Steam 后再添加 $SOFTWARE_NAME。"
        return 0
    }
    wrapper="$APP_DIR/game-launchers/$target/launch-$target.sh"
    mkdir -p "$(dirname "$wrapper")" || return 1
    cat > "$wrapper" <<EOF
#!/bin/bash
exec flatpak run $SOFTWARE_APP_ID
EOF
    chmod +x "$wrapper" || return 1
    software_stop_steam_for_vdf || {
        echo "Steam 未能在 10 秒内退出，已停止写入 Steam 库。"
        return 1
    }
    python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" \
        --shortcut-file "$shortcut_file" add \
        --name "$SOFTWARE_NAME" --exe "$wrapper" \
        --start-dir "$(dirname "$wrapper")" >/dev/null || return 1
    icon="$(find_software_flatpak_icon)"
    if [ -n "$icon" ]; then
        python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" \
            --shortcut-file "$shortcut_file" set-icon \
            --name "$SOFTWARE_NAME" --exe "$wrapper" --icon "$icon" >/dev/null || true
    fi
    echo "$SOFTWARE_NAME 已添加到 Steam 库。"
    log "$SOFTWARE_NAME 已添加到 Steam 库"
    software_start_steam
}

uninstall_software_steam_entry() {
    local target="$1" steam_root shortcut_file wrapper

    wrapper="$APP_DIR/game-launchers/$target/launch-$target.sh"
    steam_root="$(find_software_steam_root 2>/dev/null || true)"
    if [ -n "$steam_root" ]; then
        shortcut_file="$(find_software_steam_shortcut_file "$steam_root" 2>/dev/null || true)"
        if [ -n "$shortcut_file" ]; then
            python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" \
                --shortcut-file "$shortcut_file" remove \
                --exe-basename "launch-$target.sh" >/dev/null || true
        fi
    fi
    rm -f -- "$wrapper"
    rmdir "$APP_DIR/game-launchers/$target" 2>/dev/null || true
}

uninstall_steam_entry_flatpak_software() {
    local target="$1"

    software_details "$target" || return 1
    if [ "$SOFTWARE_STEAM_ENTRY" = "1" ]; then
        uninstall_software_steam_entry "$target"
    fi
    uninstall_flatpak_software "$SOFTWARE_APP_ID" "$SOFTWARE_NAME" \
        "$SOFTWARE_DESKTOP_NAME.desktop" "$SOFTWARE_APP_ID.desktop"
}

install_software() {
    local target="$1"

    software_details "$target" || return 1
    is_linux || {
        echo "$SOFTWARE_NAME 安装仅支持Linux/SteamOS。"
        return 1
    }
    if [ "$target" = "sunshine" ]; then
        require_supported_gaming_os || return 1
    fi

    if software_is_installed; then
        echo "[已安装] $SOFTWARE_NAME"
        if [ "$target" = "sunshine" ]; then
            require_command timeout || return 1
            confirm_software_install || {
                echo "已取消修复 $SOFTWARE_NAME。"
                return 0
            }
            complete_sunshine_install || return 1
        fi
        create_software_shortcut
        if [ "$SOFTWARE_STEAM_ENTRY" = "1" ]; then
            install_software_steam_entry "$target"
        fi
        return $?
    fi

    require_command curl || return 1
    require_command od || return 1

    confirm_software_install || {
        echo "已取消安装 $SOFTWARE_NAME。"
        return 0
    }

    if [ "$SOFTWARE_INSTALL_MODE" = "appimage" ]; then
        install_official_qq_appimage || return 1
        create_software_shortcut
        return $?
    fi
    if [ "$SOFTWARE_INSTALL_MODE" = "wechat_appimage" ]; then
        install_official_wechat_appimage || return 1
        create_software_shortcut
        return $?
    fi
    if [ "$SOFTWARE_INSTALL_MODE" = "rustdesk_appimage" ]; then
        install_rustdesk_appimage || return 1
        create_software_shortcut
        return $?
    fi

    require_command flatpak || {
        software_print_domestic_source_hint
        return 1
    }
    require_command timeout || {
        echo "系统缺少限时运行组件，为避免安装无限卡住，已停止。"
        software_print_domestic_source_hint
        return 1
    }
    if [ "$SOFTWARE_INSTALL_MODE" = "flatpak_official" ]; then
        install_official_firefox_flatpak || return 1
        if ! software_is_installed; then
            echo "$SOFTWARE_NAME 安装命令结束，但未检测到已安装应用。"
            software_print_domestic_source_hint
            return 1
        fi
        echo "$SOFTWARE_NAME 安装完成。"
        log "$SOFTWARE_NAME 官方 Flathub 安装完成"
        create_software_shortcut
        return $?
    fi
    if [ "$FLATPAK_SOURCE_MODE" = "official" ]; then
        if ! ensure_official_flathub_remote; then
            echo "官方 Flathub 源配置失败，已停止。"
            return 1
        fi
        echo "正在从官方 Flathub 安装 $SOFTWARE_NAME..."
        if ! run_flatpak_install "$FLATHUB_OFFICIAL_REMOTE"; then
            echo "官方 Flathub 安装失败或超时，已停止。"
            software_print_domestic_source_hint
            log "$SOFTWARE_NAME 官方Flatpak安装失败"
            return 1
        fi
    else
        if ! ensure_flatpak_remotes; then
            echo "国内Flathub缓存源配置失败，已停止，不会转连官方源。"
            echo "提示：请先在Renkit【初始化国内源并检测系统组件】中初始化国内源后重试。"
            return 1
        fi

        choose_install_remotes
        local _fr_retry=0
        while [ "$_fr_retry" -le 1 ]; do
            echo "正在安装 $SOFTWARE_NAME..."
            if run_flatpak_install "$INSTALL_PRIMARY_REMOTE"; then
                break
            fi
            if run_flatpak_install "$INSTALL_FALLBACK_REMOTE"; then
                break
            fi
            if [ "$_fr_retry" -eq 0 ]; then
                echo "检测到下载源不可用，正在切换至国内源，请耐心等待..."
                if ! ZHOUKEER_FORCE_FLATPAK_RECONFIGURE=1 \
                    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable >/dev/null 2>&1; then
                    ZHOUKEER_FORCE_FLATPAK_RECONFIGURE=1 \
                        ensure_flatpak_remotes >/dev/null 2>&1 || true
                fi
                choose_install_remotes 2>/dev/null || true
                _fr_retry=1
            else
                echo "两个国内缓存均失败或超时，已停止。"
                echo "提示：请先在Renkit【初始化国内源并检测系统组件】中初始化国内源后重试。"
                log "$SOFTWARE_NAME Flatpak安装失败"
                return 1
            fi
        done
    fi

    if ! software_is_installed; then
        echo "$SOFTWARE_NAME 安装命令结束，但未检测到已安装应用。"
        software_print_domestic_source_hint
        log "$SOFTWARE_NAME Flatpak安装结果验证失败"
        return 1
    fi

    echo "$SOFTWARE_NAME 安装完成。"
    log "$SOFTWARE_NAME Flatpak安装完成"
    if [ "$target" = "sunshine" ]; then
        complete_sunshine_install || return 1
    fi
    create_software_shortcut
    if [ "$SOFTWARE_STEAM_ENTRY" = "1" ]; then
        install_software_steam_entry "$target"
    fi
}

show_software_status() {
    local target
    local installed_count=0
    local target_count=0

    detect_platform
    echo "常用软件与远程协助安装状态："
    for target in "${SOFTWARE_TARGETS[@]}"; do
        if [ "$IS_BAZZITE" -eq 1 ] && [ "$target" = "anydesk" ]; then
            continue
        fi
        target_count=$((target_count + 1))
        software_details "$target" || return 1
        if software_is_installed; then
            echo "✓ $SOFTWARE_NAME：已安装"
            installed_count=$((installed_count + 1))
        else
            echo "- $SOFTWARE_NAME：未安装"
        fi
    done
    echo "已安装：$installed_count / $target_count"
}

repair_software_shortcuts() {
    local target
    local repaired=0

    detect_platform
    for target in "${SOFTWARE_TARGETS[@]}"; do
        if [ "$IS_BAZZITE" -eq 1 ] && [ "$target" = "anydesk" ]; then
            continue
        fi
        software_details "$target" || return 1
        if software_is_installed; then
            create_software_shortcut || return 1
            repaired=$((repaired + 1))
        fi
    done
    echo "已修复 $repaired 个已安装应用的桌面图标。"
    log "已修复 $repaired 个应用桌面图标"
}



# Deprecated: legacy pacman path; normal CLI routing is blocked below.
install_firefox_pacman() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "此方式仅支持 SteamOS 环境。"
        return 1
    fi
    for cmd in steamos-readonly pacman pacman-key; do
        require_command "$cmd" || return 1
    done

    echo "将通过 pacman 安装 Firefox 到系统分区。"
    echo "将临时关闭 SteamOS 只读保护，安装完成后恢复。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        local answer
        read -r -p "确认安装请输入 INSTALL：" answer
        [ "$answer" = "INSTALL" ] || { echo "已取消。"; return 0; }
    fi

    toolbox_sudo true || { echo "管理员权限验证失败。"; return 1; }

    echo "第 1 步：关闭 SteamOS 只读保护..."
    toolbox_sudo steamos-readonly disable || { echo "关闭只读保护失败。"; return 1; }

    echo "第 2 步：初始化 pacman 密钥..."
    toolbox_sudo pacman-key --init || { echo "pacman-key 初始化失败。"; toolbox_sudo steamos-readonly enable 2>/dev/null; return 1; }
    toolbox_sudo pacman-key --populate || { echo "pacman-key 填充失败。"; toolbox_sudo steamos-readonly enable 2>/dev/null; return 1; }

    echo "第 3 步：安装 Firefox..."
    toolbox_sudo pacman -S firefox --noconfirm || {
        echo "Firefox 安装失败。"
        toolbox_sudo steamos-readonly enable 2>/dev/null
        return 1
    }

    echo "第 4 步：恢复 SteamOS 只读保护..."
    toolbox_sudo steamos-readonly enable || {
        echo "警告：未恢复只读保护，请手动执行: sudo steamos-readonly enable"
    }

    echo "Firefox 安装完成（系统级 pacman 安装）。"
    log "Firefox 通过 pacman 安装完成"
}



# Deprecated: legacy direct mirror path; normal CLI routing is blocked below.
install_firefox_sjtu() {
    is_linux || { echo "仅支持 Linux/SteamOS。"; return 1; }
    require_command flatpak || return 1

    echo "将从上海交大镜像源安装 Firefox（Flatpak 版）。"
    echo "需要先配置交大镜像源（系统设置 → 交大 Flatpak 镜像）。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        local answer
        read -r -p "确认安装请输入 INSTALL：" answer
        [ "$answer" = "INSTALL" ] || { echo "已取消。"; return 0; }
    fi

    if ! flatpak remote-ls --user Sjtu 2>/dev/null | grep -q .; then
        echo "交大镜像源未配置或不可用，请先在系统设置中添加。"
        echo "命令：bash modules/domestic_source.sh sjtu"
        return 1
    fi

    echo "正在从 Sjtu 源安装 Firefox..."
    flatpak install Sjtu org.mozilla.firefox -y || {
        echo "Firefox 安装失败。"
        return 1
    }

    echo "Firefox（Flatpak）安装完成。"
    log "Firefox Flatpak 通过交大镜像安装完成"
}


# Deprecated: legacy system setup; normal CLI routing is blocked below.
system_setup() {
    echo "系统初始化"

    if ! sudo -n true 2>/dev/null; then
        echo "  - 尝试通过桌面密码记录提权..."
        toolbox_sudo true || {
            echo "管理员权限验证失败，请在桌面创建管理员密码.txt后重试。"
            return 1
        }
        SUDO_CMD="toolbox_sudo"
    else
        echo "  - sudo 会话有效"
        SUDO_CMD="sudo"
    fi

    echo "  - 关闭 SteamOS 只读保护"
    $SUDO_CMD steamos-readonly disable || { echo "关闭只读保护失败。"; return 1; }

    echo "  - 初始化 pacman 密钥"
    $SUDO_CMD pacman-key --init || true
    $SUDO_CMD pacman-key --populate archlinux || true

    if pacman -Q firefox 2>/dev/null; then
        echo "  - Firefox 已安装，跳过"
    else
        echo "  - 安装 Firefox"
        $SUDO_CMD pacman -S firefox --noconfirm || {
            $SUDO_CMD steamos-readonly enable 2>/dev/null
            echo "Firefox 安装失败。"; return 1
        }
    fi

    echo "  - 配置国内 Flatpak 镜像"
    $SUDO_CMD flatpak remote-add --if-not-exists Sjtu \
        https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo || true
    flatpak remote-modify Sjtu --url=https://mirror.sjtu.edu.cn/flathub || true

    $SUDO_CMD steamos-readonly enable || true
    echo "系统初始化完成"
}



install_flatpak_app() {
    local app_id="$1"
    local app_name="$2"
    local _fp_src _fp_desk

    if command -v flatpak >/dev/null 2>&1 && \
       flatpak info "$app_id" >/dev/null 2>&1; then
        echo "[已安装] $app_name 已存在，无需重复安装。"
        _fp_desk="$(find "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications -name "${app_id}.desktop" 2>/dev/null | head -1)"
        if [ -n "$_fp_desk" ]; then
            mkdir -p "$HOME/Desktop" || return 1
            cp "$_fp_desk" "$HOME/Desktop/" 2>/dev/null || return 1
            chmod +x "$HOME/Desktop/${app_id}.desktop" 2>/dev/null || return 1
            echo "桌面快捷方式已确认。"
        fi
        return 0
    fi

    if [ "$FLATPAK_SOURCE_MODE" = "official" ]; then
        require_command flatpak || return 1
        require_command timeout || return 1
        ensure_official_flathub_remote || {
            echo "官方 Flathub 源配置失败，已停止。"
            return 1
        }
        echo "正在从官方 Flathub 安装 $app_name..."
        SOFTWARE_APP_ID="$app_id"
        if run_flatpak_install "$FLATHUB_OFFICIAL_REMOTE"; then
            echo "$app_name 安装完成。"
            _fp_desk="$(find "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications -name "${app_id}.desktop" 2>/dev/null | head -1)"
            [ -n "$_fp_desk" ] && cp "$_fp_desk" "$HOME/Desktop/" 2>/dev/null && chmod +x "$HOME/Desktop/${app_id}.desktop" 2>/dev/null && echo "  桌面快捷方式已创建。"
            log "$app_name 官方 Flatpak 安装完成"
            return 0
        fi
        echo "$app_name 官方 Flathub 安装失败。"
        return 1
    fi

    echo "提示：如遇下载缓慢，请在Renkit【系统设置 → 国内源】中初始化国内 Flathub 源。"
    echo "正在安装 $app_name..."
    for _fp_src in Sjtu Ustc flathub; do
        if flatpak remote-list --user 2>/dev/null | grep -q "$_fp_src"; then
            echo "  从 $_fp_src 安装..."
            if flatpak install -y "$_fp_src" "$app_id"; then
                echo "$app_name 安装完成。"
                _fp_desk="$(find "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications -name "${app_id}.desktop" 2>/dev/null | head -1)"
                [ -n "$_fp_desk" ] && cp "$_fp_desk" "$HOME/Desktop/" 2>/dev/null && chmod +x "$HOME/Desktop/${app_id}.desktop" 2>/dev/null && echo "  桌面快捷方式已创建。"
                log "$app_name Flatpak 安装完成"
                return 0
            fi
        fi
        if flatpak remote-list --system 2>/dev/null | grep -q "$_fp_src"; then
            echo "  从 $_fp_src 安装(system)..."
            if toolbox_sudo flatpak install -y "$_fp_src" "$app_id"; then
                echo "$app_name 安装完成。"
                _fp_desk="$(find "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications -name "${app_id}.desktop" 2>/dev/null | head -1)"
                [ -n "$_fp_desk" ] && cp "$_fp_desk" "$HOME/Desktop/" 2>/dev/null && chmod +x "$HOME/Desktop/${app_id}.desktop" 2>/dev/null && echo "  桌面快捷方式已创建。"
                log "$app_name Flatpak 安装完成"
                return 0
            fi
        fi
        echo "  $_fp_src 不可用，尝试下一个..."
    done

    # 兜底
    if command -v flatpak >/dev/null 2>&1; then
        echo "  尝试从 flathub 官方源安装..."
        if toolbox_sudo flatpak install --system -y flathub "$app_id" || \
           flatpak install --user -y flathub "$app_id"; then
            echo "$app_name 安装完成。"
            _fp_desk="$(find "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications -name "${app_id}.desktop" 2>/dev/null | head -1)"
            [ -n "$_fp_desk" ] && cp "$_fp_desk" "$HOME/Desktop/" 2>/dev/null && chmod +x "$HOME/Desktop/${app_id}.desktop" 2>/dev/null && echo "  桌面快捷方式已创建。"
            log "$app_name Flatpak 安装完成"
            return 0
        fi
    fi

    echo "$app_name 安装失败。"
    return 1
}

confirm_software_uninstall() {
    local name="$1"
    local answer

    echo "将卸载：$name"
    echo "只删除该软件和Renkit创建的桌面快捷方式，不删除其他应用。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认卸载请输入 UNINSTALL：" answer
    [ "$answer" = "UNINSTALL" ]
}

remove_software_shortcuts() {
    local shortcut

    for shortcut in "$@"; do
        [ -n "$shortcut" ] || continue
        rm -f -- "$HOME/Desktop/$shortcut" || return 1
    done
}

uninstall_flatpak_software() {
    local app_id="$1"
    local app_name="$2"
    shift 2

    command -v flatpak >/dev/null 2>&1 || {
        echo "$app_name 未安装。"
        return 0
    }
    if flatpak info --user "$app_id" >/dev/null 2>&1; then
        confirm_software_uninstall "$app_name" || { echo "已取消卸载。"; return 0; }
        flatpak uninstall --user --noninteractive -y "$app_id" || return 1
    elif flatpak info --system "$app_id" >/dev/null 2>&1; then
        detect_platform
        if [ "$IS_BAZZITE" -eq 1 ]; then
            echo "$app_name 是系统级 Flatpak，Renkit Bazzite版不会提权卸载。"
            echo "请使用 Bazzite 自带的软件管理界面维护该系统级应用。"
            return 0
        fi
        confirm_software_uninstall "$app_name" || { echo "已取消卸载。"; return 0; }
        toolbox_sudo flatpak uninstall --system --noninteractive -y "$app_id" || return 1
    else
        echo "$app_name 未安装。"
        return 0
    fi
    remove_software_shortcuts "$@" || return 1
    echo "$app_name 已卸载。"
    log "$app_name 已卸载"
}

uninstall_appimage_software() {
    local path="$1"
    local app_name="$2"
    shift 2

    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        echo "$app_name 未安装。"
        return 0
    fi
    [ -f "$path" ] && [ ! -L "$path" ] || {
        echo "$app_name 安装路径异常，拒绝自动删除：$path"
        return 1
    }
    confirm_software_uninstall "$app_name" || { echo "已取消卸载。"; return 0; }
    rm -f -- "$path" || return 1
    remove_software_shortcuts "$@" || return 1
    echo "$app_name 已卸载。"
    log "$app_name 已卸载"
}

uninstall_software() {
    is_linux || {
        echo "软件卸载仅支持 Linux / SteamOS。"
        return 1
    }
    case "$1" in
        wechat) uninstall_appimage_software "$WECHAT_APPIMAGE_PATH" "微信" "微信.desktop" ;;
        qq) uninstall_flatpak_software "com.qq.QQ" "QQ" "QQ.desktop" "com.qq.QQ.desktop" ;;
        browser) uninstall_flatpak_software "org.mozilla.firefox" "Firefox 浏览器" "Firefox浏览器.desktop" "org.mozilla.firefox.desktop" ;;
        chrome) uninstall_flatpak_software "com.google.Chrome" "Google Chrome" "com.google.Chrome.desktop" ;;
        edge) uninstall_flatpak_software "com.microsoft.Edge" "Microsoft Edge" "com.microsoft.Edge.desktop" ;;
        rustdesk) uninstall_appimage_software "$RUSTDESK_APPIMAGE_PATH" "RustDesk" "RustDesk.desktop" ;;
        anydesk) uninstall_flatpak_software "com.anydesk.Anydesk" "AnyDesk" "AnyDesk.desktop" "com.anydesk.Anydesk.desktop" ;;
        protontricks) uninstall_flatpak_software "com.github.Matoking.protontricks" "Protontricks" "com.github.Matoking.protontricks.desktop" ;;
        bottles) uninstall_flatpak_software "com.usebottles.bottles" "Bottles" "com.usebottles.bottles.desktop" ;;
        baidunetdisk) uninstall_flatpak_software "com.baidu.NetDisk" "百度网盘" "com.baidu.NetDisk.desktop" ;;
        libreoffice) uninstall_flatpak_software "org.libreoffice.LibreOffice" "LibreOffice 办公套件" "org.libreoffice.LibreOffice.desktop" ;;
        vlc) uninstall_flatpak_software "org.videolan.VLC" "VLC 播放器" "org.videolan.VLC.desktop" ;;
        obs) uninstall_flatpak_software "com.obsproject.Studio" "OBS Studio" "com.obsproject.Studio.desktop" ;;
        localsend) uninstall_flatpak_software "org.localsend.localsend_app" "LocalSend" "org.localsend.localsend_app.desktop" ;;
        peazip) uninstall_flatpak_software "io.github.peazip.PeaZip" "PeaZip 压缩工具" "PeaZip.desktop" "io.github.peazip.PeaZip.desktop" ;;
        willwill) uninstall_steam_entry_flatpak_software "willwill" ;;
        fcitx5) uninstall_flatpak_software "org.fcitx.Fcitx5" "Fcitx5 中文输入法" "Fcitx5.desktop" "org.fcitx.Fcitx5.desktop" ;;
        xbox-cloud|qqmusic|netease-music|yesplaymusic|qbittorrent|motrix|freedownloadmanager|media-downloader|flameshot|onlyoffice|joplin|heroic|lutris|chiaki4deck|parsec) uninstall_steam_entry_flatpak_software "$1" ;;
        sunshine)
            require_supported_gaming_os || return 1
            software_details sunshine || return 1
            if ! software_is_installed; then
                echo "$SOFTWARE_NAME 未安装。"
                return 0
            fi
            if ! flatpak info --user "$SOFTWARE_APP_ID" >/dev/null 2>&1; then
                echo "Sunshine 是系统级 Flatpak，Renkit 不会自动提权或改动它的附加组件。"
                echo "请按 Sunshine 官方说明维护该系统级安装。"
                return 1
            fi
            confirm_software_uninstall "$SOFTWARE_NAME" || { echo "已取消卸载。"; return 0; }
            require_command timeout || return 1
            echo "正在使用桌面密码记录移除 Sunshine 虚拟输入设备规则..."
            if ! remove_sunshine_additional_install; then
                echo "Sunshine 附加组件清理失败，已停止卸载 Flatpak，避免遗留系统规则。"
                log "Sunshine Flatpak附加组件清理失败"
                return 1
            fi
            flatpak uninstall --user --noninteractive -y "$SOFTWARE_APP_ID" || return 1
            remove_software_shortcuts "Sunshine.desktop" \
                "dev.lizardbyte.app.Sunshine.desktop" || return 1
            echo "$SOFTWARE_NAME 已卸载。"
            log "$SOFTWARE_NAME 已卸载"
            ;;
        *) echo "未知卸载目标：$1"; return 1 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        wechat|qq|browser|rustdesk|anydesk|baidunetdisk|libreoffice|vlc|obs|localsend|peazip|willwill|fcitx5|xbox-cloud|qqmusic|netease-music|yesplaymusic|qbittorrent|motrix|freedownloadmanager|media-downloader|flameshot|onlyoffice|joplin|heroic|lutris|chiaki4deck|parsec|sunshine) install_software "$1" ;;
        firefox-pacman|firefox-sjtu|system-setup)
            echo "该旧版系统级功能已停用，请使用当前 Flatpak 菜单功能。"
            exit 1
            ;;
        chrome) install_flatpak_app "com.google.Chrome" "Google Chrome" ;;
        edge) install_flatpak_app "com.microsoft.Edge" "Microsoft Edge" ;;
        protontricks) install_flatpak_app "com.github.Matoking.protontricks" "Protontricks" ;;
        bottles) install_flatpak_app "com.usebottles.bottles" "Bottles" ;;
        uninstall)
            [ -n "${2:-}" ] || { echo "用法: $0 uninstall 软件名"; exit 1; }
            uninstall_software "$2"
            ;;
        status) require_command od && show_software_status ;;
        repair-shortcuts) require_command od && repair_software_shortcuts ;;
        *) echo "用法: $0 {wechat|qq|browser|rustdesk|anydesk|baidunetdisk|libreoffice|vlc|obs|localsend|peazip|willwill|fcitx5|xbox-cloud|qqmusic|netease-music|yesplaymusic|qbittorrent|motrix|freedownloadmanager|media-downloader|flameshot|onlyoffice|joplin|heroic|lutris|chiaki4deck|parsec|sunshine|chrome|edge|protontricks|bottles|status|repair-shortcuts}"; exit 1 ;;
    esac
fi
