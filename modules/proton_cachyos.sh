#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"

load_config

PROTON_CACHYOS_MIRROR_ID="proton-cachyos"
PROTON_CACHYOS_MIRROR_REPO="zhoukeer-toolbox-mirror-9"
PROTON_CACHYOS_FILE="${ZHOUKEER_PROTON_CACHYOS_FILE:-proton-cachyos-11.0-20260703-slr-x86_64.tar.xz}"
PROTON_CACHYOS_URL="${ZHOUKEER_PROTON_CACHYOS_URL:-https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-11.0-20260703-slr/proton-cachyos-11.0-20260703-slr-x86_64.tar.xz}"
PROTON_CACHYOS_SHA256="${ZHOUKEER_PROTON_CACHYOS_SHA256:-b06d509ffddee2ffe592d34948ce2578ef2cff4102582e75e77b504ae1a44c1b}"
PROTON_CACHYOS_VERSION="${PROTON_CACHYOS_FILE%.tar.xz}"
PROTON_CACHYOS_TMP_DIR=""
PROTON_CACHYOS_STAGE_DIR=""
PROTON_CACHYOS_BACKUP_DIR=""
PROTON_CACHYOS_TARGET_DIR=""
PROTON_CACHYOS_SWAP_STARTED=0
PROTON_CACHYOS_SWAP_FINISHED=0

proton_cachyos_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

proton_cachyos_resolve_compatibility_dir() {
    local steam_root

    if [ -n "${ZHOUKEER_COMPATIBILITYTOOLS_DIR:-}" ]; then
        printf '%s\n' "$ZHOUKEER_COMPATIBILITYTOOLS_DIR"
        return 0
    fi
    for steam_root in \
        "$HOME/.steam/root" \
        "$HOME/.steam/steam" \
        "$HOME/.local/share/Steam"; do
        if [ -d "$steam_root" ]; then
            printf '%s/compatibilitytools.d\n' "${steam_root%/}"
            return 0
        fi
    done
    echo "未找到 Steam 用户目录，请先启动一次 Steam。" >&2
    return 1
}

proton_cachyos_config_is_valid() {
    case "$PROTON_CACHYOS_URL" in
        https://*) ;;
        *) echo "Proton-CachyOS 下载地址必须使用 HTTPS。"; return 1 ;;
    esac
    case "$PROTON_CACHYOS_FILE" in
        proton-cachyos-*-slr-x86_64.tar.xz) ;;
        *) echo "Proton-CachyOS 文件名不符合普通 x86_64 SLR 包规则。"; return 1 ;;
    esac
    case "$PROTON_CACHYOS_FILE" in
        *'/'*|*'..'*|*[!0-9A-Za-z._-]*)
            echo "Proton-CachyOS 文件名不安全。"
            return 1
            ;;
    esac
    case "$PROTON_CACHYOS_SHA256" in
        ''|*[!0-9A-Fa-f]*) echo "Proton-CachyOS SHA256 无效。"; return 1 ;;
    esac
    [ "${#PROTON_CACHYOS_SHA256}" -eq 64 ] || {
        echo "Proton-CachyOS SHA256 长度无效。"
        return 1
    }
}

resolve_proton_cachyos_latest() {
    if [ -n "${ZHOUKEER_PROTON_CACHYOS_URL:-}" ] || \
        [ -n "${ZHOUKEER_PROTON_CACHYOS_FILE:-}" ] || \
        [ -n "${ZHOUKEER_PROTON_CACHYOS_SHA256:-}" ]; then
        PROTON_CACHYOS_VERSION="${PROTON_CACHYOS_FILE%.tar.xz}"
        return 0
    fi

    if resolve_latest_gitee_mirror "$PROTON_CACHYOS_MIRROR_ID" \
        '^proton-cachyos-[0-9.]+-[0-9]+-slr-x86_64[.]tar[.]xz$' \
        "Proton-CachyOS"; then
        PROTON_CACHYOS_FILE="$_GITEE_MIRROR_LATEST_FILE"
        PROTON_CACHYOS_URL="$_GITEE_MIRROR_LATEST_URL"
        PROTON_CACHYOS_SHA256="$_GITEE_MIRROR_LATEST_SHA256"
        PROTON_CACHYOS_VERSION="${PROTON_CACHYOS_FILE%.tar.xz}"
        log "Proton-CachyOS mirror-9 最新版本: $PROTON_CACHYOS_VERSION"
    elif resolve_latest_github_release "CachyOS/proton-cachyos" \
        '^proton-cachyos-[0-9.]+-[0-9]+-slr-x86_64[.]tar[.]xz$' \
        "Proton-CachyOS"; then
        PROTON_CACHYOS_FILE="$_LATEST_RELEASE_ASSET"
        PROTON_CACHYOS_URL="$_LATEST_RELEASE_URL"
        PROTON_CACHYOS_SHA256="$_LATEST_RELEASE_SHA256"
        PROTON_CACHYOS_VERSION="${PROTON_CACHYOS_FILE%.tar.xz}"
        log "Proton-CachyOS GitHub 最新版本: $PROTON_CACHYOS_VERSION"
    else
        echo "最新版检测失败，继续使用固定版本 $PROTON_CACHYOS_VERSION。"
    fi
}

validate_proton_cachyos_archive() {
    local archive="$1" member root="" candidate members

    members="$(LC_ALL=C tar -tJf "$archive" 2>/dev/null)" || {
        echo "Proton-CachyOS 压缩包无法读取或不是 tar.xz 格式。"
        return 1
    }
    [ -n "$members" ] || { echo "Proton-CachyOS 压缩包为空。"; return 1; }
    while IFS= read -r member; do
        member="${member#./}"
        [ -n "$member" ] || continue
        case "$member" in
            /*|../*|*/../*|*/./*)
                echo "Proton-CachyOS 压缩包包含不安全路径。"
                return 1
                ;;
        esac
        candidate="${member%%/*}"
        case "$candidate" in
            proton-cachyos-*-slr-x86_64|Proton-cachyos-*-slr-x86_64) ;;
            *)
                echo "Proton-CachyOS 压缩包包含意外顶层目录：$candidate"
                return 1
                ;;
        esac
        if [ -n "$root" ] && [ "$root" != "$candidate" ]; then
            echo "Proton-CachyOS 压缩包包含多个顶层目录。"
            return 1
        fi
        root="$candidate"
    done <<< "$members"
    [ -n "$root" ] || return 1
    PROTON_CACHYOS_ARCHIVE_DIR="$root"
}

validate_proton_cachyos_tool() {
    local source_dir="$1" source_real required link resolved

    for required in compatibilitytool.vdf proton toolmanifest.vdf; do
        [ -f "$source_dir/$required" ] || {
            echo "Proton-CachyOS 缺少必要文件：$required"
            return 1
        }
    done
    [ -x "$source_dir/proton" ] || {
        echo "Proton-CachyOS 启动文件不可执行。"
        return 1
    }
    source_real="$(readlink -f "$source_dir" 2>/dev/null || true)"
    [ -n "$source_real" ] || return 1
    while IFS= read -r link; do
        resolved="$(readlink -f "$link" 2>/dev/null || true)"
        case "$resolved" in
            "$source_real"|"$source_real"/*) ;;
            *) echo "Proton-CachyOS 包含指向目录外部的符号链接。"; return 1 ;;
        esac
    done < <(find "$source_dir" -type l -print)
}

cleanup_proton_cachyos() {
    if [ "$PROTON_CACHYOS_SWAP_STARTED" -eq 1 ] && \
        [ "$PROTON_CACHYOS_SWAP_FINISHED" -eq 0 ] && \
        [ -d "$PROTON_CACHYOS_BACKUP_DIR" ] && \
        [ ! -e "$PROTON_CACHYOS_TARGET_DIR" ]; then
        mv -- "$PROTON_CACHYOS_BACKUP_DIR" "$PROTON_CACHYOS_TARGET_DIR" 2>/dev/null || true
    fi
    [ -z "$PROTON_CACHYOS_STAGE_DIR" ] || rm -rf -- "$PROTON_CACHYOS_STAGE_DIR"
    [ -z "$PROTON_CACHYOS_BACKUP_DIR" ] || rm -rf -- "$PROTON_CACHYOS_BACKUP_DIR"
    [ -z "$PROTON_CACHYOS_TMP_DIR" ] || rm -rf -- "$PROTON_CACHYOS_TMP_DIR"
}

proton_cachyos_is_installed() {
    local compatibility_dir="$1"
    validate_proton_cachyos_tool "$compatibility_dir/$PROTON_CACHYOS_VERSION" \
        >/dev/null 2>&1
}

restart_steam_after_proton_cachyos() {
    local steam_bin attempt
    if command -v steam >/dev/null 2>&1; then
        steam_bin="$(command -v steam)"
    elif [ -x "$HOME/.steam/steam/steam.sh" ]; then
        steam_bin="$HOME/.steam/steam/steam.sh"
    else
        echo "未找到 Steam 启动命令，请手动重启 Steam 后生效。"
        return 0
    fi
    if pgrep -x steam >/dev/null 2>&1; then
        "$steam_bin" -shutdown >/dev/null 2>&1 || true
        for attempt in 1 2 3 4 5 6 7 8 9 10; do
            pgrep -x steam >/dev/null 2>&1 || break
            sleep 1
        done
    fi
    nohup "$steam_bin" >/dev/null 2>&1 &
    echo "Steam 已重新启动，Proton-CachyOS 已生效。"
}

install_proton_cachyos() {
    local compatibility_dir archive extract_dir source_dir actual_sha command_name

    require_supported_gaming_os || return 1
    for command_name in curl tar find; do
        require_command "$command_name" || return 1
    done
    command -v sha256sum >/dev/null 2>&1 || \
        command -v shasum >/dev/null 2>&1 || {
            echo "缺少 SHA256 校验工具。"
            return 1
        }
    resolve_proton_cachyos_latest
    proton_cachyos_config_is_valid || return 1
    compatibility_dir="$(proton_cachyos_resolve_compatibility_dir)" || return 1
    mkdir -p "$compatibility_dir" || return 1
    if proton_cachyos_is_installed "$compatibility_dir"; then
        echo "[已安装] $PROTON_CACHYOS_VERSION 文件完整，无需重复安装。"
        return 0
    fi

    echo "将安装 CachyOS 上游发布的普通 x86_64 SLR 兼容层，不会删除其他 Proton。"
    PROTON_CACHYOS_TMP_DIR="$(mktemp -d "${compatibility_dir}/.proton-cachyos-tmp.XXXXXX")" || return 1
    archive="$PROTON_CACHYOS_TMP_DIR/$PROTON_CACHYOS_FILE"
    extract_dir="$PROTON_CACHYOS_TMP_DIR/extracted"
    mkdir -p "$extract_dir" || return 1
    if ! GITEE_MIRROR_REPO="$PROTON_CACHYOS_MIRROR_REPO" \
        download_with_gitee_mirror_fallback "$PROTON_CACHYOS_MIRROR_ID" \
        "$PROTON_CACHYOS_URL" "$PROTON_CACHYOS_SHA256" "$archive" \
        "Proton-CachyOS"; then
        echo "Proton-CachyOS 下载失败，已有兼容层保持不变。"
        return 1
    fi
    actual_sha="$(proton_cachyos_sha256 "$archive")" || return 1
    [ "$actual_sha" = "$(printf '%s' "$PROTON_CACHYOS_SHA256" | tr '[:upper:]' '[:lower:]')" ] || {
        echo "Proton-CachyOS SHA256 校验失败，已有兼容层保持不变。"
        return 1
    }
    validate_proton_cachyos_archive "$archive" || return 1
    tar --no-same-owner --no-same-permissions -xJf "$archive" -C "$extract_dir" || {
        echo "Proton-CachyOS 解压失败。"
        return 1
    }
    source_dir="$extract_dir/$PROTON_CACHYOS_ARCHIVE_DIR"
    validate_proton_cachyos_tool "$source_dir" || return 1

    PROTON_CACHYOS_TARGET_DIR="$compatibility_dir/$PROTON_CACHYOS_VERSION"
    PROTON_CACHYOS_STAGE_DIR="$compatibility_dir/.${PROTON_CACHYOS_VERSION}.new.$$"
    PROTON_CACHYOS_BACKUP_DIR="$compatibility_dir/.${PROTON_CACHYOS_VERSION}.backup.$$"
    cp -a -- "$source_dir" "$PROTON_CACHYOS_STAGE_DIR" || return 1
    if [ -e "$PROTON_CACHYOS_TARGET_DIR" ]; then
        PROTON_CACHYOS_SWAP_STARTED=1
        mv -- "$PROTON_CACHYOS_TARGET_DIR" "$PROTON_CACHYOS_BACKUP_DIR" || return 1
    fi
    mv -- "$PROTON_CACHYOS_STAGE_DIR" "$PROTON_CACHYOS_TARGET_DIR" || return 1
    PROTON_CACHYOS_STAGE_DIR=""
    PROTON_CACHYOS_SWAP_FINISHED=1
    rm -rf -- "$PROTON_CACHYOS_BACKUP_DIR"
    PROTON_CACHYOS_BACKUP_DIR=""
    log "$PROTON_CACHYOS_VERSION 已安装到 $PROTON_CACHYOS_TARGET_DIR"
    echo "$PROTON_CACHYOS_VERSION 安装完成。"
    restart_steam_after_proton_cachyos
}

status_proton_cachyos() {
    local compatibility_dir
    require_supported_gaming_os || return 1
    resolve_proton_cachyos_latest
    compatibility_dir="$(proton_cachyos_resolve_compatibility_dir)" || return 1
    if proton_cachyos_is_installed "$compatibility_dir"; then
        echo "[已安装] $PROTON_CACHYOS_VERSION"
    else
        echo "[未安装] $PROTON_CACHYOS_VERSION"
    fi
}

uninstall_proton_cachyos() {
    local compatibility_dir target answer
    require_supported_gaming_os || return 1
    resolve_proton_cachyos_latest
    compatibility_dir="$(proton_cachyos_resolve_compatibility_dir)" || return 1
    target="$compatibility_dir/$PROTON_CACHYOS_VERSION"
    if [ ! -e "$target" ]; then
        echo "$PROTON_CACHYOS_VERSION 未安装。"
        return 0
    fi
    [ -d "$target" ] && [ ! -L "$target" ] && \
        validate_proton_cachyos_tool "$target" >/dev/null 2>&1 || {
        echo "目录不完整或类型异常，拒绝自动删除：$target"
        return 1
    }
    echo "只会删除 Proton-CachyOS：$target"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        read -r -p "确认卸载请输入 UNINSTALL：" answer
        [ "$answer" = "UNINSTALL" ] || { echo "已取消卸载。"; return 0; }
    fi
    rm -rf -- "$target" || return 1
    log "$PROTON_CACHYOS_VERSION 已卸载"
    echo "$PROTON_CACHYOS_VERSION 已卸载，其他 Proton 未改动。"
}

trap cleanup_proton_cachyos EXIT
trap 'exit 130' INT TERM

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) install_proton_cachyos ;;
        status) status_proton_cachyos ;;
        uninstall) uninstall_proton_cachyos ;;
        *) echo "用法：bash proton_cachyos.sh {install|status|uninstall}"; exit 1 ;;
    esac
fi
