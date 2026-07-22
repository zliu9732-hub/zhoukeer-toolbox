#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

load_config

# 固定使用作者 GitHub Release，防止旧安装保留的配置重新启用退役下载地址。
# 测试或紧急诊断可以通过 ZHOUKEER_GE_PROTON_* 环境变量明确覆盖。
GE_PROTON_URL="${ZHOUKEER_GE_PROTON_URL:-https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-1/GE-Proton11-1.tar.gz}"
GE_PROTON_VERSION="${ZHOUKEER_GE_PROTON_VERSION:-GE-Proton11-1}"
GE_PROTON_SHA256="${ZHOUKEER_GE_PROTON_SHA256:-ce6dd663ea01725a31805ed5c165723a253cdf0945a6642907330742ae2de5e4}"
GE_PROTON_TMP_DIR=""
GE_PROTON_STAGE_DIR=""
GE_PROTON_BACKUP_DIR=""
GE_PROTON_TARGET_DIR=""
GE_PROTON_SWAP_STARTED=0
GE_PROTON_SWAP_FINISHED=0

calculate_ge_proton_sha256() {
    local file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

resolve_compatibilitytools_dir() {
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

    echo "未找到Steam用户目录，请先启动一次Steam后再安装GE-Proton。" >&2
    return 1
}

validate_ge_proton_config() {
    if [ -z "$GE_PROTON_URL" ] || [ -z "$GE_PROTON_VERSION" ] || \
        [ -z "$GE_PROTON_SHA256" ]; then
        echo "GE-Proton下载配置尚未补齐，请先更新工具箱。"
        return 1
    fi

    case "$GE_PROTON_URL" in
        https://*) ;;
        *) echo "GE-Proton下载地址必须使用HTTPS。"; return 1 ;;
    esac

    case "$GE_PROTON_VERSION" in
        GE-Proton*) ;;
        *) echo "GE-Proton版本目录名称无效。"; return 1 ;;
    esac
    case "$GE_PROTON_VERSION" in
        *[!0-9A-Za-z._-]*) echo "GE-Proton版本目录名称无效。"; return 1 ;;
    esac

    if [ "${#GE_PROTON_SHA256}" -ne 64 ]; then
        echo "GE-Proton SHA256必须是64位十六进制字符串。"
        return 1
    fi
    case "$GE_PROTON_SHA256" in
        *[!0-9A-Fa-f]*) echo "GE-Proton SHA256包含无效字符。"; return 1 ;;
    esac
}

validate_archive_members() {
    local archive="$1"
    local member
    local members

    members="$(LC_ALL=C tar -tzf "$archive" 2>/dev/null)" || {
        echo "GE-Proton压缩包无法读取或不是tar.gz格式。"
        return 1
    }
    [ -n "$members" ] || {
        echo "GE-Proton压缩包为空。"
        return 1
    }

    while IFS= read -r member; do
        member="${member#./}"
        case "$member" in
            ""|"$GE_PROTON_VERSION"|"$GE_PROTON_VERSION/"*) ;;
            *)
                echo "压缩包包含预期目录之外的文件：$member"
                return 1
                ;;
        esac
        case "/$member/" in
            */../*|*/./*)
                echo "压缩包包含不安全路径，已拒绝解压。"
                return 1
                ;;
        esac
    done <<< "$members"
}

validate_extracted_tool() {
    local source_dir="$1"
    local source_real
    local link
    local resolved
    local required_file

    for required_file in compatibilitytool.vdf proton toolmanifest.vdf; do
        if [ ! -f "$source_dir/$required_file" ]; then
            echo "GE-Proton压缩包缺少必要文件：$required_file"
            return 1
        fi
    done

    source_real="$(readlink -f "$source_dir" 2>/dev/null || true)"
    [ -n "$source_real" ] || {
        echo "无法解析GE-Proton解压目录。"
        return 1
    }

    while IFS= read -r link; do
        resolved="$(readlink -f "$link" 2>/dev/null || true)"
        case "$resolved" in
            "$source_real"|"$source_real"/*) ;;
            *)
                echo "GE-Proton压缩包包含指向目录外部的符号链接。"
                return 1
                ;;
        esac
    done < <(find "$source_dir" -type l -print)
}

cleanup_ge_proton() {
    if [ "$GE_PROTON_SWAP_STARTED" -eq 1 ] && \
        [ "$GE_PROTON_SWAP_FINISHED" -eq 0 ] && \
        [ -d "$GE_PROTON_BACKUP_DIR" ] && \
        [ ! -e "$GE_PROTON_TARGET_DIR" ]; then
        mv -- "$GE_PROTON_BACKUP_DIR" "$GE_PROTON_TARGET_DIR" 2>/dev/null || true
    fi

    [ -z "$GE_PROTON_STAGE_DIR" ] || rm -rf -- "$GE_PROTON_STAGE_DIR"
    [ -z "$GE_PROTON_BACKUP_DIR" ] || rm -rf -- "$GE_PROTON_BACKUP_DIR"
    [ -z "$GE_PROTON_TMP_DIR" ] || rm -rf -- "$GE_PROTON_TMP_DIR"
}

install_ge_proton() {
    local compatibility_dir
    local archive
    local extract_dir
    local source_dir
    local actual_sha256
    local command_name

    validate_ge_proton_config || return 1
    for command_name in curl tar find; do
        command -v "$command_name" >/dev/null 2>&1 || {
            echo "缺少安装GE-Proton所需命令：$command_name"
            return 1
        }
    done
    command -v sha256sum >/dev/null 2>&1 || \
        command -v shasum >/dev/null 2>&1 || {
            echo "缺少SHA256校验工具。"
            return 1
        }

    compatibility_dir="$(resolve_compatibilitytools_dir)" || return 1
    mkdir -p "$compatibility_dir" || {
        echo "无法创建Steam兼容层目录：$compatibility_dir"
        return 1
    }

    GE_PROTON_TMP_DIR="$(mktemp -d)" || return 1
    archive="$GE_PROTON_TMP_DIR/ge-proton.tar.gz"
    extract_dir="$GE_PROTON_TMP_DIR/extracted"
    mkdir -p "$extract_dir" || return 1

    if ! GITHUB_MAX_TIME=1800 GITHUB_RETRIES=3 download_github_file \
        "$GE_PROTON_URL" "$archive" "$GE_PROTON_SHA256" "$GE_PROTON_VERSION"; then
        echo "GE-Proton下载失败。"
        return 1
    fi

    actual_sha256="$(calculate_ge_proton_sha256 "$archive")" || return 1
    if [ "$actual_sha256" != "$(printf '%s' "$GE_PROTON_SHA256" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "GE-Proton SHA256校验失败，已有兼容层保持不变。"
        return 1
    fi
    echo "GE-Proton SHA256校验通过。"

    validate_archive_members "$archive" || return 1
    if ! tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$extract_dir"; then
        echo "GE-Proton解压失败。"
        return 1
    fi

    source_dir="$extract_dir/$GE_PROTON_VERSION"
    validate_extracted_tool "$source_dir" || return 1

    GE_PROTON_TARGET_DIR="$compatibility_dir/$GE_PROTON_VERSION"
    GE_PROTON_STAGE_DIR="$compatibility_dir/.${GE_PROTON_VERSION}.new.$$"
    GE_PROTON_BACKUP_DIR="$compatibility_dir/.${GE_PROTON_VERSION}.backup.$$"
    rm -rf -- "$GE_PROTON_STAGE_DIR" "$GE_PROTON_BACKUP_DIR"
    cp -a -- "$source_dir" "$GE_PROTON_STAGE_DIR" || return 1

    if [ -e "$GE_PROTON_TARGET_DIR" ]; then
        GE_PROTON_SWAP_STARTED=1
        mv -- "$GE_PROTON_TARGET_DIR" "$GE_PROTON_BACKUP_DIR" || return 1
    fi
    if ! mv -- "$GE_PROTON_STAGE_DIR" "$GE_PROTON_TARGET_DIR"; then
        echo "无法启用GE-Proton，正在恢复原版本。"
        return 1
    fi
    GE_PROTON_STAGE_DIR=""
    GE_PROTON_SWAP_FINISHED=1
    rm -rf -- "$GE_PROTON_BACKUP_DIR"
    GE_PROTON_BACKUP_DIR=""

    log "$GE_PROTON_VERSION 已安装到 $GE_PROTON_TARGET_DIR"
    echo ""
    echo "$GE_PROTON_VERSION 安装完成。"
    echo "安装位置：$GE_PROTON_TARGET_DIR"
    echo "请完全退出并重新启动Steam，然后在游戏属性的兼容性页面选择该版本。"
}

trap cleanup_ge_proton EXIT
trap 'exit 130' INT TERM

case "${1:-}" in
    install) install_ge_proton ;;
    *) echo "用法：bash ge_proton.sh install"; exit 1 ;;
esac
