#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

load_config

FLATHUB_CN_REMOTE="flathub-cn"
FLATHUB_CN_FALLBACK_REMOTE="flathub-ustc"
FLATHUB_CN_URL="${ZHOUKEER_FLATHUB_CN_URL:-https://mirror.sjtu.edu.cn/flathub}"
FLATHUB_CN_FALLBACK_URL="${ZHOUKEER_FLATHUB_CN_FALLBACK_URL:-https://mirrors.ustc.edu.cn/flathub}"
FLATHUB_REPO_FILE_PRIMARY="https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo"
FLATHUB_REPO_FILE_FALLBACK="https://mirrors.ustc.edu.cn/flathub/flathub.flatpakrepo"
FLATHUB_OFFICIAL_REMOTE="flathub"
FLATHUB_OFFICIAL_REPO_FILE="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_INSTALL_TIMEOUT="${ZHOUKEER_FLATPAK_INSTALL_TIMEOUT:-300}"
FLATPAK_INSTALL_RETRIES="${ZHOUKEER_FLATPAK_INSTALL_RETRIES:-1}"
FLATPAK_SOURCE_PROBE_TIMEOUT="${ZHOUKEER_FLATPAK_SOURCE_PROBE_TIMEOUT:-8}"
INSTALL_PRIMARY_REMOTE="$FLATHUB_CN_REMOTE"
INSTALL_FALLBACK_REMOTE="$FLATHUB_CN_FALLBACK_REMOTE"

QQ_CONFIG_PRIMARY="https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json"
QQ_CONFIG_FALLBACK="https://im.qq.com/proxy/domain/qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json"
QQ_APPIMAGE_PATH="${ZHOUKEER_QQ_APPIMAGE_PATH:-$APP_DIR/QQ.AppImage}"
QQ_DOWNLOAD_TIMEOUT="${ZHOUKEER_QQ_DOWNLOAD_TIMEOUT:-600}"
QQ_MIN_BYTES="${ZHOUKEER_QQ_MIN_BYTES:-52428800}"

WECHAT_APPIMAGE_URL="${ZHOUKEER_WECHAT_APPIMAGE_URL:-https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage}"
WECHAT_APPIMAGE_PATH="${ZHOUKEER_WECHAT_APPIMAGE_PATH:-$APP_DIR/WeChat.AppImage}"
WECHAT_DOWNLOAD_TIMEOUT="${ZHOUKEER_WECHAT_DOWNLOAD_TIMEOUT:-900}"
WECHAT_MIN_BYTES="${ZHOUKEER_WECHAT_MIN_BYTES:-104857600}"

RUSTDESK_DOWNLOAD_URL="${ZHOUKEER_RUSTDESK_DOWNLOAD_URL:-https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.AppImage}"
RUSTDESK_APPIMAGE_PATH="${ZHOUKEER_RUSTDESK_APPIMAGE_PATH:-$APP_DIR/RustDesk.AppImage}"
RUSTDESK_SHA256="${ZHOUKEER_RUSTDESK_SHA256:-7902cd60a4f29817eebe2668a15c9a1952ac690e8f7b07bfe7620fedd4e28217}"
RUSTDESK_DOWNLOAD_TIMEOUT="${ZHOUKEER_RUSTDESK_DOWNLOAD_TIMEOUT:-600}"
RUSTDESK_MIN_BYTES="${ZHOUKEER_RUSTDESK_MIN_BYTES:-10485760}"

software_details() {
    SOFTWARE_INSTALL_MODE="flatpak"
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
        *)
            echo "未知软件: $1"
            return 1
            ;;
    esac
}

confirm_software_install() {
    local answer

    case "$SOFTWARE_INSTALL_MODE" in
        appimage)
            echo "将从腾讯QQ官网国内CDN下载官方AppImage：$SOFTWARE_NAME"
            echo "安装位置：$QQ_APPIMAGE_PATH"
            echo "下载最长等待 $QQ_DOWNLOAD_TIMEOUT 秒，失败后会保留旧版本。"
            ;;
        wechat_appimage)
            echo "将从微信Linux版官网下载官方x86_64 AppImage。"
            echo "安装位置：$WECHAT_APPIMAGE_PATH"
            echo "下载最长等待 $WECHAT_DOWNLOAD_TIMEOUT 秒，失败后会保留旧版本。"
            ;;
        flatpak_official)
            echo "将从官方 Flathub 安装 Firefox（org.mozilla.firefox）。"
            echo "使用官方 Flathub，Firefox 后续可在系统内自动更新。"
            ;;
        rustdesk_appimage)
            echo "将从 RustDesk 作者 GitHub Release 下载 x86_64 AppImage。"
            echo "安装位置：$RUSTDESK_APPIMAGE_PATH"
            echo "下载最长等待 $RUSTDESK_DOWNLOAD_TIMEOUT 秒，失败后会保留旧版本。"
            ;;
        *)
            echo "将通过Flatpak以当前用户身份安装：$SOFTWARE_NAME"
            echo "应用ID：$SOFTWARE_APP_ID"
            echo "下载顺序：上海交大Flathub缓存 → 中科大Flathub缓存"
            echo "每个来源最长等待 $FLATPAK_INSTALL_TIMEOUT 秒，不再额外寻找Flathub官方源。"
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
    local source

    for source in \
        "$FLATHUB_REPO_FILE_PRIMARY" \
        "$FLATHUB_REPO_FILE_FALLBACK" \
        "$FLATHUB_OFFICIAL_REPO_FILE"; do
        echo "正在获取 Flathub 签名配置..."
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
            "$source" && \
            grep -q '^\[Flatpak Repo\]$' "$destination" && \
            grep -q '^GPGKey=' "$destination"; then
            return 0
        fi
        rm -f -- "$destination"
    done

    echo "无法获取Flathub签名配置。"
    return 1
}

flatpak_remote_exists() {
    flatpak remotes --user --columns=name 2>/dev/null | grep -Fxq "$1"
}

ensure_flatpak_remotes() {
    local repo_file=""

    if ! flatpak_remote_exists "$FLATHUB_CN_REMOTE" || \
        ! flatpak_remote_exists "$FLATHUB_CN_FALLBACK_REMOTE"; then
        repo_file="$(mktemp)" || return 1
        if ! download_flathub_repo_file "$repo_file"; then
            rm -f -- "$repo_file"
            return 1
        fi
    fi

    if ! flatpak_remote_exists "$FLATHUB_CN_REMOTE"; then
        echo "正在添加Flathub国内缓存源..."
        if ! timeout --foreground 30 flatpak remote-add --user --if-not-exists \
            "$FLATHUB_CN_REMOTE" "$repo_file"; then
            rm -f -- "$repo_file"
            return 1
        fi
    fi

    if ! timeout --foreground 30 flatpak remote-modify --user "$FLATHUB_CN_REMOTE" \
        --url="$FLATHUB_CN_URL"; then
        echo "无法配置上海交大Flathub缓存源。"
        rm -f -- "$repo_file"
        return 1
    fi

    if ! flatpak_remote_exists "$FLATHUB_CN_FALLBACK_REMOTE"; then
        echo "正在添加中科大Flathub缓存源..."
        if ! timeout --foreground 30 flatpak remote-add --user --if-not-exists \
            "$FLATHUB_CN_FALLBACK_REMOTE" "$repo_file"; then
            rm -f -- "$repo_file"
            return 1
        fi
    fi
    if ! timeout --foreground 30 flatpak remote-modify --user "$FLATHUB_CN_FALLBACK_REMOTE" \
        --url="$FLATHUB_CN_FALLBACK_URL"; then
        echo "无法配置中科大Flathub缓存源。"
        rm -f -- "$repo_file"
        return 1
    fi

    rm -f -- "$repo_file"
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
        echo "正在从 $remote 安装（第 $attempt/$FLATPAK_INSTALL_RETRIES 次尝试）..."
        if LC_ALL="$locale_name" LANG="$locale_name" \
            timeout --foreground "$FLATPAK_INSTALL_TIMEOUT" \
            flatpak install --user --noninteractive -y "$remote" "$SOFTWARE_APP_ID"; then
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
        echo "测速结果：优先使用中科大缓存（科大 ${fallback_seconds}s，交大 ${primary_seconds}s）。"
    elif [ -n "$primary_seconds" ]; then
        echo "测速结果：优先使用上海交大缓存（${primary_seconds}s）。"
    else
        echo "测速未完成，默认先尝试上海交大缓存。"
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
            --output "$config_file" \
            "$config_url"; then
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
    if ! curl \
        --fail \
        --location \
        --show-error \
        --progress-bar \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time "$QQ_DOWNLOAD_TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --referer "https://im.qq.com/" \
        --output "$temp_file" \
        "$appimage_url"; then
        echo "QQ下载失败或超时，已停止；原有版本未受影响。"
        return 1
    fi

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
    if ! curl \
        --fail \
        --location \
        --show-error \
        --progress-bar \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time "$WECHAT_DOWNLOAD_TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$temp_file" \
        "$WECHAT_APPIMAGE_URL"; then
        echo "微信下载失败或超时，已停止；原有版本未受影响。"
        return 1
    fi

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
    local _dl_ok=0 _dl_url _mirror
    for _mirror in $GITHUB_MIRRORS ""; do
        if [ -n "$_mirror" ]; then
            _dl_url="${_mirror}${RUSTDESK_DOWNLOAD_URL}"
        else
            _dl_url="$RUSTDESK_DOWNLOAD_URL"
        fi
        if curl \
            --fail \
            --location \
            --show-error \
            --progress-bar \
            --proto '=https' \
            --proto-redir '=https' \
            --connect-timeout 15 \
            --max-time "$RUSTDESK_DOWNLOAD_TIMEOUT" \
            --retry 2 \
            --retry-delay 2 \
            --retry-all-errors \
            --output "$temp_file" \
            "$_dl_url"; then
            _dl_ok=1
            break
        fi
        rm -f "$temp_file"
    done
    if [ "$_dl_ok" -ne 1 ]; then
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
        --show-error \
        --progress-bar \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time "$FIREFOX_DOWNLOAD_TIMEOUT" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$archive_file" \
        "$FIREFOX_DOWNLOAD_URL"; then
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
        *)
            command -v flatpak >/dev/null 2>&1 && \
                flatpak info "$SOFTWARE_APP_ID" >/dev/null 2>&1
            ;;
    esac
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
            icon_name="wechat"
            ;;
        rustdesk_appimage)
            exec_line="\"$RUSTDESK_APPIMAGE_PATH\""
            icon_name="rustdesk"
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
Comment=由周克儿工具箱安装
Exec=$exec_line
Icon=$icon_name
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
    require_command curl || return 1
    require_command od || return 1

    if software_is_installed; then
        echo "$SOFTWARE_NAME 已安装，正在检查桌面快捷方式。"
        create_software_shortcut
        return $?
    fi

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

    require_command flatpak || return 1
    require_command timeout || {
        echo "系统缺少限时运行组件，为避免安装无限卡住，已停止。"
        return 1
    }
    if [ "$SOFTWARE_INSTALL_MODE" = "flatpak_official" ]; then
        install_official_firefox_flatpak || return 1
        if ! software_is_installed; then
            echo "$SOFTWARE_NAME 安装命令结束，但未检测到已安装应用。"
            return 1
        fi
        echo "$SOFTWARE_NAME 安装完成。"
        log "$SOFTWARE_NAME 官方 Flathub 安装完成"
        create_software_shortcut
        return $?
    fi
    if ! ensure_flatpak_remotes; then
        echo "国内Flathub缓存源配置失败，已停止，不会转连官方源。"
        return 1
    fi

    choose_install_remotes
    echo "正在安装 $SOFTWARE_NAME..."
    if ! run_flatpak_install "$INSTALL_PRIMARY_REMOTE"; then
        echo "$INSTALL_PRIMARY_REMOTE 安装失败或超时，切换备用源 $INSTALL_FALLBACK_REMOTE。"
        if ! run_flatpak_install "$INSTALL_FALLBACK_REMOTE"; then
            echo "两个国内缓存均失败或超时，已停止，不再连接Flathub官方源。"
            log "$SOFTWARE_NAME Flatpak安装失败"
            return 1
        fi
    fi

    if ! software_is_installed; then
        echo "$SOFTWARE_NAME 安装命令结束，但未检测到已安装应用。"
        log "$SOFTWARE_NAME Flatpak安装结果验证失败"
        return 1
    fi

    echo "$SOFTWARE_NAME 安装完成。"
    log "$SOFTWARE_NAME Flatpak安装完成"
    create_software_shortcut
}

show_software_status() {
    local target
    local installed_count=0

    echo "常用软件与远程协助安装状态："
    for target in wechat qq browser rustdesk; do
        software_details "$target" || return 1
        if software_is_installed; then
            echo "✓ $SOFTWARE_NAME：已安装"
            installed_count=$((installed_count + 1))
        else
            echo "- $SOFTWARE_NAME：未安装"
        fi
    done
    echo "已安装：$installed_count / 4"
}

repair_software_shortcuts() {
    local target
    local repaired=0

    for target in wechat qq browser rustdesk; do
        software_details "$target" || return 1
        if software_is_installed; then
            create_software_shortcut || return 1
            repaired=$((repaired + 1))
        fi
    done
    echo "已修复 $repaired 个已安装应用的桌面图标。"
    log "已修复 $repaired 个应用桌面图标"
}



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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        wechat|qq|browser|rustdesk) install_software "$1" ;;
        firefox-pacman) install_firefox_pacman ;;
        firefox-sjtu) install_firefox_sjtu ;;
        status) require_command od && show_software_status ;;
        repair-shortcuts) require_command od && repair_software_shortcuts ;;
        *) echo "用法: $0 {wechat|qq|browser|rustdesk|firefox-pacman|firefox-sjtu|status|repair-shortcuts}"; exit 1 ;;
    esac
fi
