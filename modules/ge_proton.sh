#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

load_config

# 默认自动检测作者最新正式 Release；API 失败或测试/紧急诊断时可回退固定版本。
GE_PROTON_URL="${ZHOUKEER_GE_PROTON_URL:-https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-3/GE-Proton11-3.tar.gz}"
GE_PROTON_VERSION="${ZHOUKEER_GE_PROTON_VERSION:-GE-Proton11-3}"
GE_PROTON_SHA256="${ZHOUKEER_GE_PROTON_SHA256:-861c2edc8d40d051fb1e7a692deb953be52bd339c46d90f2b7dde50ddad91266}"
GE_PROTON_AUTO_UPDATE="${ZHOUKEER_GE_PROTON_AUTO_UPDATE:-1}"
GE_PROTON_TMP_DIR=""
GE_PROTON_STAGE_DIR=""
GE_PROTON_BACKUP_DIR=""
GE_PROTON_TARGET_DIR=""
GE_PROTON_SWAP_STARTED=0
GE_PROTON_SWAP_FINISHED=0

# 修改器常用兼容层：固定四个 GE-Proton 版本，从自有 Gitee 镜像下载。
GE_PROTON_TRAINER_ITEMS=(
    "ge-proton-trainer-7-55|zhoukeer-toolbox-mirror-4|GE-Proton7-55|ffbd03b40a5c8dafba53e45bd6551c132512ad6fcba9120e25f0d510d0cd0485"
    "ge-proton-trainer-8-25|zhoukeer-toolbox-mirror-5|GE-Proton8-25|b37160b27ab36e0068f73ab09ac0c936323cf934c6f36edb171cd642bd7ce18a"
    "ge-proton-trainer-9-27|zhoukeer-toolbox-mirror-6|GE-Proton9-27|bbd3108ba8dcf173dd2a60ef4eb1b8d07e0fb3c9a1061b5b9310c5355c151937"
    "ge-proton-trainer-10-29|zhoukeer-toolbox-mirror-7|GE-Proton10-29|29a42ff004e9e5c79e22fa9a0595490284167d4a2e7cabbe570b1f9c2f3295c0"
)

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

resolve_ge_proton_latest() {
    if [ "${GE_PROTON_AUTO_UPDATE:-1}" != "1" ] || \
        [ -n "${ZHOUKEER_GE_PROTON_URL:-}" ] || \
        [ -n "${ZHOUKEER_GE_PROTON_VERSION:-}" ] || \
        [ -n "${ZHOUKEER_GE_PROTON_SHA256:-}" ]; then
        return 0
    fi

    if resolve_latest_gitee_mirror "ge-proton" \
        '^GE-Proton[0-9]+-[0-9]+[.]tar[.]gz$' "GE-Proton"; then
        GE_PROTON_URL="$_GITEE_MIRROR_LATEST_URL"
        GE_PROTON_VERSION="$_GITEE_MIRROR_LATEST_VERSION"
        GE_PROTON_SHA256="$_GITEE_MIRROR_LATEST_SHA256"
        log "GE-Proton Gitee 镜像最新版本: $GE_PROTON_VERSION"
    elif resolve_latest_github_release "GloriousEggroll/proton-ge-custom" \
        '^GE-Proton[0-9]+-[0-9]+[.]tar[.]gz$' "GE-Proton"; then
        GE_PROTON_URL="$_LATEST_RELEASE_URL"
        GE_PROTON_VERSION="$_LATEST_RELEASE_TAG"
        GE_PROTON_SHA256="$_LATEST_RELEASE_SHA256"
        log "GE-Proton 自动检测最新版本: $GE_PROTON_VERSION"
    else
        echo "自动检测最新 GE-Proton 失败，继续使用固定版本 $GE_PROTON_VERSION。"
    fi
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

ge_proton_is_installed() {
    local compatibility_dir="$1"
    local target_dir="$compatibility_dir/$GE_PROTON_VERSION"

    [ -d "$target_dir" ] && \
        validate_extracted_tool "$target_dir" >/dev/null 2>&1
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

install_ge_proton_package() {
    local mirror_id="$1"
    local mirror_repo="$2"
    local download_mode="$3"
    local compatibility_dir="$4"
    local archive
    local extract_dir
    local source_dir
    local actual_sha256
    local command_name

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

    mkdir -p "$compatibility_dir" || {
        echo "无法创建Steam兼容层目录：$compatibility_dir"
        return 1
    }

    GE_PROTON_TMP_DIR="$(mktemp -d)" || return 1
    archive="$GE_PROTON_TMP_DIR/ge-proton.tar.gz"
    extract_dir="$GE_PROTON_TMP_DIR/extracted"
    mkdir -p "$extract_dir" || return 1

    if [ "$download_mode" = "mirror" ]; then
        if ! GITEE_MIRROR_REPO="$mirror_repo" \
            download_gitee_mirror_file \
            "$mirror_id" "$archive" "$GE_PROTON_SHA256" \
            "$GE_PROTON_VERSION"; then
            echo "$GE_PROTON_VERSION 下载失败。"
            return 1
        fi
    else
        if ! GITHUB_MAX_TIME=1800 GITHUB_RETRIES=3 \
            download_with_gitee_mirror_fallback \
            "$mirror_id" "$GE_PROTON_URL" "$GE_PROTON_SHA256" \
            "$archive" "$GE_PROTON_VERSION"; then
            echo "$GE_PROTON_VERSION 下载失败。"
            return 1
        fi
    fi

    actual_sha256="$(calculate_ge_proton_sha256 "$archive")" || return 1
    if [ "$actual_sha256" != "$(printf '%s' "$GE_PROTON_SHA256" | tr '[:upper:]' '[:lower:]')" ]; then
        echo "$GE_PROTON_VERSION SHA256校验失败，已有兼容层保持不变。"
        return 1
    fi
    validate_archive_members "$archive" || return 1
    if ! tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$extract_dir"; then
        echo "$GE_PROTON_VERSION 解压失败。"
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
        echo "无法启用$GE_PROTON_VERSION，正在恢复原版本。"
        return 1
    fi
    GE_PROTON_STAGE_DIR=""
    GE_PROTON_SWAP_FINISHED=1
    rm -rf -- "$GE_PROTON_BACKUP_DIR"
    GE_PROTON_BACKUP_DIR=""

    log "$GE_PROTON_VERSION 已安装到 $GE_PROTON_TARGET_DIR"
    echo "$GE_PROTON_VERSION 安装完成。"
    echo "请完全退出并重新启动Steam，然后在游戏属性的兼容性页面选择该版本。"
}

install_ge_proton() {
    local compatibility_dir

    resolve_ge_proton_latest
    validate_ge_proton_config || return 1
    compatibility_dir="$(resolve_compatibilitytools_dir)" || return 1
    if ge_proton_is_installed "$compatibility_dir"; then
        echo "[已安装] $GE_PROTON_VERSION 已存在且文件完整，无需重复安装。"
        return 0
    fi
    install_ge_proton_package "ge-proton" "zhoukeer-toolbox-mirror" \
        "fallback" "$compatibility_dir"
}

install_trainer_ge_proton() {
    local compatibility_dir
    local item
    local mirror_id
    local mirror_repo
    local version
    local sha256

    echo "正在安装修改器所需常用兼容层。"
    echo "包含 GE-Proton 7-55、8-25、9-27、10-29，合计约 1.72GB；下载较慢为正常现象，请耐心等待。"
    compatibility_dir="$(resolve_compatibilitytools_dir)" || return 1
    mkdir -p "$compatibility_dir" || return 1

    for item in "${GE_PROTON_TRAINER_ITEMS[@]}"; do
        IFS='|' read -r mirror_id mirror_repo version sha256 <<< "$item"
        GE_PROTON_VERSION="$version"
        GE_PROTON_SHA256="$sha256"
        if ge_proton_is_installed "$compatibility_dir"; then
            echo "[已安装] $version 已存在且文件完整，跳过。"
            continue
        fi
        echo "正在安装 $version..."
        install_ge_proton_package "$mirror_id" "$mirror_repo" \
            "mirror" "$compatibility_dir" || return 1
    done

    echo "修改器所需常用兼容层安装完成。"
}

uninstall_ge_proton() {
    local compatibility_dir target_dir answer

    resolve_ge_proton_latest
    validate_ge_proton_config || return 1
    compatibility_dir="$(resolve_compatibilitytools_dir)" || return 1
    target_dir="$compatibility_dir/$GE_PROTON_VERSION"
    if [ ! -e "$target_dir" ] && [ ! -L "$target_dir" ]; then
        echo "$GE_PROTON_VERSION 未安装。"
        return 0
    fi
    [ -d "$target_dir" ] && [ ! -L "$target_dir" ] && \
        validate_extracted_tool "$target_dir" >/dev/null 2>&1 || {
        echo "GE-Proton 目录不完整或类型异常，拒绝自动删除：$target_dir"
        return 1
    }
    echo "只会删除当前工具箱版本：$target_dir"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        read -r -p "确认卸载请输入 UNINSTALL：" answer
        [ "$answer" = "UNINSTALL" ] || { echo "已取消卸载。"; return 0; }
    fi
    rm -rf -- "$target_dir" || return 1
    echo "$GE_PROTON_VERSION 已卸载，其他 Proton 版本未改动。"
    log "$GE_PROTON_VERSION 已卸载"
}

trap cleanup_ge_proton EXIT
trap 'exit 130' INT TERM

case "${1:-}" in
    install) install_ge_proton ;;
    install-trainer) install_trainer_ge_proton ;;
    uninstall) uninstall_ge_proton ;;
    *) echo "用法：bash ge_proton.sh {install|install-trainer|uninstall}"; exit 1 ;;
esac
