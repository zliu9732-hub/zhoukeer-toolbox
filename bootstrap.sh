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

CONNECT_TIMEOUT="${ZHOUKEER_CONNECT_TIMEOUT:-10}"
MAX_TIME="${ZHOUKEER_MAX_TIME:-120}"

GITEE_RAW_BASE="${ZHOUKEER_GITEE_RAW_BASE:-https://gitee.com/$GITEE_OWNER/$REPO_NAME/raw/$BRANCH}"
GITHUB_RAW_BASE="${ZHOUKEER_GITHUB_RAW_BASE:-https://raw.githubusercontent.com/$GITHUB_OWNER/$REPO_NAME/$BRANCH}"
PACKAGE_NAME="${ZHOUKEER_PACKAGE_NAME:-zhoukeer-toolbox.tar.gz}"
GITEE_PACKAGE_URL="${ZHOUKEER_GITEE_PACKAGE_URL:-$GITEE_RAW_BASE/dist/$PACKAGE_NAME}"
GITHUB_PACKAGE_URL="${ZHOUKEER_GITHUB_PACKAGE_URL:-$GITHUB_RAW_BASE/dist/$PACKAGE_NAME}"
GITEE_VERSION_URL="${ZHOUKEER_GITEE_VERSION_URL:-$GITEE_RAW_BASE/VERSION}"
GITHUB_VERSION_URL="${ZHOUKEER_GITHUB_VERSION_URL:-$GITHUB_RAW_BASE/VERSION}"
GITEE_CHECKSUM_URL="${ZHOUKEER_GITEE_CHECKSUM_URL:-$GITEE_RAW_BASE/dist/SHA256SUMS}"
GITHUB_CHECKSUM_URL="${ZHOUKEER_GITHUB_CHECKSUM_URL:-$GITHUB_RAW_BASE/dist/SHA256SUMS}"

need_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "缺少命令: $1"
        exit 1
    fi
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

    echo "尝试下载($label): $url"
    rm -f -- "$output"
    curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$CONNECT_TIMEOUT" \
        --max-time "$MAX_TIME" \
        --output "$output" \
        "$url"
}

valid_sha256() {
    local value="$1"

    [ "${#value}" -eq 64 ] || return 1
    case "$value" in
        *[!0-9A-Fa-f]*) return 1 ;;
    esac
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

    echo "SHA256校验通过"
}

download_verified_package_from() {
    local label="$1"
    local package_url="$2"
    local checksum_url="$3"
    local package_file="$4"
    local checksum_file="$5"
    local expected="${ZHOUKEER_SHA256:-}"

    echo "尝试获取并校验($label)"
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

    echo "Gitee包或校验文件不可用，切换GitHub备用源。"
    if download_verified_package_from \
        "GitHub" "$GITHUB_PACKAGE_URL" "$GITHUB_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="GitHub"
        return 0
    fi

    echo "安装包验证失败：Gitee和GitHub均不可用。"
    return 1
}

download_with_fallback() {
    local output="$1"
    local label="$2"
    local gitee_url="$3"
    local github_url="$4"

    if download_one "$gitee_url" "$output" "Gitee"; then
        DOWNLOAD_SOURCE="Gitee"
        return 0
    fi

    echo "Gitee下载失败，切换GitHub备用源。"
    if download_one "$github_url" "$output" "GitHub"; then
        DOWNLOAD_SOURCE="GitHub"
        return 0
    fi

    echo "$label 下载失败：Gitee和GitHub均不可用。"
    return 1
}

SYSTEM="$(uname -s 2>/dev/null || echo unknown)"

echo "================================"
echo " 周克儿工具箱 Bootstrap"
echo "================================"
echo "分支: $BRANCH"
echo "安装目录: $INSTALL_DIR"
echo "模式: $([ "$DRY_RUN" -eq 1 ] && echo dry-run || echo install)"
echo ""

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
    echo "[dry-run] 将优先从Gitee获取版本: $GITEE_VERSION_URL"
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

echo "[1/4] 获取版本信息..."
if download_with_fallback "$VERSION_FILE" "版本信息" "$GITEE_VERSION_URL" "$GITHUB_VERSION_URL"; then
    VERSION="$(tr -d '\r\n' < "$VERSION_FILE")"
else
    VERSION="unknown"
fi
echo "版本: $VERSION"

echo "[2/4] 下载并校验项目包..."
download_verified_package "$PACKAGE_FILE" "$CHECKSUM_FILE" || exit 1
echo "下载源: $DOWNLOAD_SOURCE"

echo "[3/4] 解压并检查安装器..."
tar -xzf "$PACKAGE_FILE" -C "$TMP_DIR"
INSTALLER_PATH="$(find "$TMP_DIR" -mindepth 1 -maxdepth 2 -type f -name install.sh -print | head -n 1)"

if [ -z "$INSTALLER_PATH" ] || [ ! -f "$INSTALLER_PATH" ]; then
    echo "项目包不完整：未找到 install.sh"
    exit 1
fi
PACKAGE_DIR="$(dirname "$INSTALLER_PATH")"

if [ ! -f "$PACKAGE_DIR/main.sh" ] || [ ! -d "$PACKAGE_DIR/modules" ] || [ ! -d "$PACKAGE_DIR/core" ]; then
    echo "项目包不完整：缺少 main.sh、modules 或 core"
    exit 1
fi

if ! find "$PACKAGE_DIR" -type f -name '*.sh' -exec bash -n {} \;; then
    echo "项目包包含Shell语法错误，已停止安装。"
    exit 1
fi

echo "[4/4] 调用安装器..."
ZHOUKEER_INSTALL_DIR="$INSTALL_DIR" bash "$INSTALLER_PATH"
