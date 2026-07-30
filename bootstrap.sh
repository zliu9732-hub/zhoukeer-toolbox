#!/bin/bash

set -u

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        *)
            echo "未知参数: $arg"
            exit 1
            ;;
    esac
done

GITEE_OWNER="${ZHOUKEER_GITEE_OWNER:-zliu9732-hub}"
GITHUB_OWNER="${ZHOUKEER_GITHUB_OWNER:-zliu9732-hub}"
REPO_NAME="${ZHOUKEER_REPO_NAME:-zhoukeer-toolbox}"
BRANCH="${ZHOUKEER_BRANCH:-main}"
INSTALL_DIR="${ZHOUKEER_INSTALL_DIR:-$HOME/.local/share/zhoukeer-toolbox}"

# 国内 CDN 初次连接可能较慢；保留足够时间和重试后才使用 GitHub 备用源。
CONNECT_TIMEOUT="${ZHOUKEER_CONNECT_TIMEOUT:-20}"
MAX_TIME="${ZHOUKEER_MAX_TIME:-600}"

GITEE_RAW_BASE="${ZHOUKEER_GITEE_RAW_BASE:-https://gitee.com/$GITEE_OWNER/$REPO_NAME/raw/$BRANCH}"
GITHUB_RAW_BASE="${ZHOUKEER_GITHUB_RAW_BASE:-https://raw.githubusercontent.com/$GITHUB_OWNER/$REPO_NAME/$BRANCH}"
DOMAIN_RAW_BASE="${ZHOUKEER_DOMAIN_RAW_BASE:-https://jktool.icu}"
PACKAGE_NAME="${ZHOUKEER_PACKAGE_NAME:-zhoukeer-toolbox.tar.gz}"
GITEE_PACKAGE_URL="${ZHOUKEER_GITEE_PACKAGE_URL:-$GITEE_RAW_BASE/dist/$PACKAGE_NAME}"
GITHUB_PACKAGE_URL="${ZHOUKEER_GITHUB_PACKAGE_URL:-$GITHUB_RAW_BASE/dist/$PACKAGE_NAME}"
GITEE_VERSION_URL="${ZHOUKEER_GITEE_VERSION_URL:-$GITEE_RAW_BASE/VERSION}"
GITHUB_VERSION_URL="${ZHOUKEER_GITHUB_VERSION_URL:-$GITHUB_RAW_BASE/VERSION}"
GITEE_CHECKSUM_URL="${ZHOUKEER_GITEE_CHECKSUM_URL:-$GITEE_RAW_BASE/dist/SHA256SUMS}"
GITHUB_CHECKSUM_URL="${ZHOUKEER_GITHUB_CHECKSUM_URL:-$GITHUB_RAW_BASE/dist/SHA256SUMS}"
DOMAIN_VERSION_URL="${ZHOUKEER_DOMAIN_VERSION_URL:-$DOMAIN_RAW_BASE/VERSION}"
DOMAIN_PACKAGE_URL="${ZHOUKEER_DOMAIN_PACKAGE_URL:-$DOMAIN_RAW_BASE/dist/$PACKAGE_NAME}"
DOMAIN_CHECKSUM_URL="${ZHOUKEER_DOMAIN_CHECKSUM_URL:-$DOMAIN_RAW_BASE/dist/SHA256SUMS}"

need_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "缺少命令: $1"
        exit 1
    fi
}

# bootstrap.sh 必须能在工具箱尚未安装时独立运行，因此这里保留受控清单的
# 最小自包含副本；安装完成后的全部下载统一使用 core/download_policy.sh。
bootstrap_url_allowed() {
    case "$1" in
        https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/VERSION|https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/dist/SHA256SUMS|https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/dist/zhoukeer-toolbox.tar.gz|https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/VERSION|https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/dist/SHA256SUMS|https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/dist/zhoukeer-toolbox.tar.gz|https://jktool.icu/VERSION|https://jktool.icu/dist/SHA256SUMS|https://jktool.icu/dist/zhoukeer-toolbox.tar.gz) return 0 ;;
        https://*) [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ] ;;
        *) return 1 ;;
    esac
}

bootstrap_response_safe() {
    local url="$1" file="$2" size magic
    [ -f "$file" ] && [ ! -L "$file" ] && [ -s "$file" ] || return 1
    size="$(wc -c < "$file" | tr -d ' ')"
    case "$size" in ''|*[!0-9]*) return 1 ;; esac
    [ "$size" -le 9437184 ] || return 1
    if LC_ALL=C head -c 512 "$file" | grep -Eiq '<(!doctype[[:space:]]+html|html[[:space:]>])|access[[:space:]]+denied|error[[:space:]]+403'; then
        return 1
    fi
    case "${url%%\?*}" in
        *.tar.gz)
            magic="$(LC_ALL=C od -An -tx1 -N2 "$file" 2>/dev/null | tr -d ' \n')"
            [ "$magic" = "1f8b" ] || return 1
            ;;
    esac
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
        exit 1
    fi
}

download_one() {
    local url="$1"
    local output="$2"
    local label="$3"

    rm -f -- "$output"
    bootstrap_url_allowed "$url" || {
        echo "$label 地址不在受控来源清单中。"
        return 1
    }
    curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$CONNECT_TIMEOUT" \
        --max-time "$MAX_TIME" \
        --retry 3 \
        --retry-delay 2 \
        --retry-all-errors \
        --max-filesize 9437184 \
        --output "$output" \
        "$url" && bootstrap_response_safe "$url" "$output"
}

valid_sha256() {
    local value="$1"

    [ "${#value}" -eq 64 ] || return 1
    case "$value" in
        *[!0-9A-Fa-f]*) return 1 ;;
    esac
}

valid_release_version() {
    [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

checksum_from_manifest() {
    local manifest="$1"
    local package_name="$2"

    awk -v name="$package_name" '
        NF >= 2 {
            file = $2
            sub(/^\*/, "", file)
            if (file == name) {
                print $1
                exit
            }
        }
    ' "$manifest"
}

verify_package() {
    local package_file="$1"
    local expected="$2"
    local actual

    if ! valid_sha256 "$expected"; then
        echo "SHA256格式无效或校验文件中缺少 $PACKAGE_NAME"
        return 1
    fi

    actual="$(sha256_file "$package_file")"
    expected="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
    if [ "$actual" != "$expected" ]; then
        echo "SHA256校验失败"
        echo "期望: $expected"
        echo "实际: $actual"
        return 1
    fi

}

remove_appledouble_files() {
    local root="$1"

    # macOS 可能生成 ._* AppleDouble 元数据。其文件名会带 .sh 后缀，
    # 在 SteamOS 上被 bash -n 误当脚本；只清理下载包内的这类元数据文件。
    find "$root" -type f -name '._*' -exec rm -f -- {} +
}

validate_tar_archive() {
    local archive="$1"
    local listing="$2"
    local verbose_listing="$3"
    local entry
    local entry_count=0

    tar -tzf "$archive" > "$listing" || {
        echo "项目包不是有效的 tar.gz 文件。"
        return 1
    }
    while IFS= read -r entry; do
        entry_count=$((entry_count + 1))
        case "$entry" in
            /*|../*|*/../*|*/..)
                echo "项目包包含不安全路径：$entry"
                return 1
                ;;
        esac
    done < "$listing"
    if [ "$entry_count" -eq 0 ] || [ "$entry_count" -gt 5000 ]; then
        echo "项目包文件数量异常：$entry_count"
        return 1
    fi

    tar -tvzf "$archive" > "$verbose_listing" || return 1
    if ! awk '
        function unsafe(target, parts, count, i) {
            if (target ~ /^\//) return 1
            count = split(target, parts, "/")
            for (i = 1; i <= count; i++) if (parts[i] == "..") return 1
            return 0
        }
        /^[lh]/ {
            target = ""
            if (index($0, " -> ")) target = substr($0, index($0, " -> ") + 4)
            else if (index($0, " link to ")) target = substr($0, index($0, " link to ") + 9)
            if (target == "" || unsafe(target)) exit 1
        }
    ' "$verbose_listing"; then
        echo "项目包包含不安全的链接。"
        return 1
    fi
}

download_verified_package_from() {
    local label="$1"
    local package_url="$2"
    local checksum_url="$3"
    local package_file="$4"
    local checksum_file="$5"
    local expected="${ZHOUKEER_SHA256:-}"

    download_one "$package_url" "$package_file" "${label}更新包" || return 1

    if [ -z "$expected" ]; then
        download_one "$checksum_url" "$checksum_file" "${label}校验文件" || return 1
        expected="$(checksum_from_manifest "$checksum_file" "$PACKAGE_NAME")"
    fi

    verify_package "$package_file" "$expected"
}

download_verified_package() {
    local package_file="$1"
    local checksum_file="$2"

    if download_verified_package_from \
        "Gitee" "$GITEE_PACKAGE_URL" "$GITEE_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="Gitee"
        return 0
    fi

    echo "Gitee不可用，切换GitHub备用源。"
    if download_verified_package_from \
        "GitHub" "$GITHUB_PACKAGE_URL" "$GITHUB_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="GitHub"
        return 0
    fi

    echo "GitHub不可用，切换域名源。"
    if download_verified_package_from \
        "域名" "$DOMAIN_PACKAGE_URL" "$DOMAIN_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="域名"
        return 0
    fi

    echo "安装包验证失败。"
    return 1
}

download_with_fallback() {
    local output="$1"
    local label="$2"
    local domain_url="$3"
    local gitee_url="$4"
    local github_url="$5"

    if download_one "$gitee_url" "$output" "Gitee"; then
        DOWNLOAD_SOURCE="Gitee"
        return 0
    fi

    echo "Gitee不可用，切换GitHub备用源。"
    if download_one "$github_url" "$output" "GitHub"; then
        DOWNLOAD_SOURCE="GitHub"
        return 0
    fi

    echo "GitHub不可用，切换域名源。"
    if download_one "$domain_url" "$output" "域名"; then
        DOWNLOAD_SOURCE="域名"
        return 0
    fi

    echo "$label 下载失败。"
    return 1
}

SYSTEM="$(uname -s 2>/dev/null || echo unknown)"

if [ "$SYSTEM" = "Darwin" ]; then
    echo "检测到 macOS。仅允许语法测试，不执行 SteamOS 安装。"
    exit 0
fi

if [ "$SYSTEM" != "Linux" ]; then
    echo "不支持的系统: $SYSTEM"
    exit 1
fi

need_command curl
need_command tar

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] 将优先从域名获取版本: $DOMAIN_VERSION_URL"
    echo "[dry-run] Gitee发布包: $GITEE_PACKAGE_URL"
    echo "[dry-run] GitHub备用包: $GITHUB_PACKAGE_URL"
    echo "[dry-run] 将安装到: $INSTALL_DIR"
    echo "[dry-run] 不会创建目录、下载文件或调用安装器。"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
PACKAGE_FILE="$TMP_DIR/zhoukeer-toolbox.tar.gz"
VERSION_FILE="$TMP_DIR/VERSION"
CHECKSUM_FILE="$TMP_DIR/SHA256SUMS"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if download_with_fallback "$VERSION_FILE" "版本信息" "$DOMAIN_VERSION_URL" "$GITEE_VERSION_URL" "$GITHUB_VERSION_URL"; then
    VERSION="$(tr -d '\r\n' < "$VERSION_FILE")"
else
    echo "无法确认工具箱版本，已停止安装。"
    exit 1
fi
valid_release_version "$VERSION" || { echo "版本信息格式无效，已停止安装。"; exit 1; }
echo "正在安装工具箱..."
download_verified_package "$PACKAGE_FILE" "$CHECKSUM_FILE" || exit 1

validate_tar_archive "$PACKAGE_FILE" "$TMP_DIR/archive.list" "$TMP_DIR/archive.verbose" || exit 1
tar --no-xattrs --no-same-owner --no-same-permissions -xzf "$PACKAGE_FILE" -C "$TMP_DIR" || exit 1
remove_appledouble_files "$TMP_DIR" || {
    echo "无法清理项目包中的 macOS 元数据文件。"
    exit 1
}
INSTALLER_PATH="$(find "$TMP_DIR" -mindepth 1 -maxdepth 2 -type f -name install.sh -print | head -n 1)"

if [ -z "$INSTALLER_PATH" ] || [ ! -f "$INSTALLER_PATH" ]; then
    echo "项目包不完整：未找到 install.sh"
    exit 1
fi
PACKAGE_DIR="$(dirname "$INSTALLER_PATH")"

[ -r "$PACKAGE_DIR/VERSION" ] || { echo "项目包不完整：缺少 VERSION"; exit 1; }
PACKAGE_VERSION="$(tr -d '\r\n' < "$PACKAGE_DIR/VERSION")"
valid_release_version "$PACKAGE_VERSION" || { echo "包内版本格式无效，已停止安装。"; exit 1; }
[ "$PACKAGE_VERSION" = "$VERSION" ] || {
    echo "下载版本与包内版本不一致，已停止安装。"
    exit 1
}

if [ ! -f "$PACKAGE_DIR/main.sh" ] || [ ! -d "$PACKAGE_DIR/modules" ] || [ ! -d "$PACKAGE_DIR/core" ]; then
    echo "项目包不完整：缺少 main.sh、modules 或 core"
    exit 1
fi

if ! find "$PACKAGE_DIR" -type f -name '*.sh' ! -name '._*' -exec bash -n {} \;; then
    echo "项目包包含Shell语法错误，已停止安装。"
    exit 1
fi

if ! ZHOUKEER_INSTALL_DIR="$INSTALL_DIR" bash "$INSTALLER_PATH" >"$TMP_DIR/install.log" 2>&1; then
    echo "工具箱安装未完成，以下是最后的错误提示："
    tail -n 20 "$TMP_DIR/install.log"
    exit 1
fi
echo "✓ 工具箱安装完成"
