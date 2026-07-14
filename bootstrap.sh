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
GITEE_PACKAGE_URL="${ZHOUKEER_GITEE_PACKAGE_URL:-https://gitee.com/$GITEE_OWNER/$REPO_NAME/repository/archive/$BRANCH.tar.gz}"
GITHUB_PACKAGE_URL="${ZHOUKEER_GITHUB_PACKAGE_URL:-https://github.com/$GITHUB_OWNER/$REPO_NAME/archive/refs/heads/$BRANCH.tar.gz}"
GITEE_VERSION_URL="${ZHOUKEER_GITEE_VERSION_URL:-$GITEE_RAW_BASE/VERSION}"
GITHUB_VERSION_URL="${ZHOUKEER_GITHUB_VERSION_URL:-$GITHUB_RAW_BASE/VERSION}"
GITEE_CHECKSUM_URL="${ZHOUKEER_GITEE_CHECKSUM_URL:-$GITEE_RAW_BASE/SHA256SUMS}"
GITHUB_CHECKSUM_URL="${ZHOUKEER_GITHUB_CHECKSUM_URL:-$GITHUB_RAW_BASE/SHA256SUMS}"

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
    curl -fL --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o "$output" "$url"
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

echo "[1/5] 获取版本信息..."
if download_with_fallback "$VERSION_FILE" "版本信息" "$GITEE_VERSION_URL" "$GITHUB_VERSION_URL"; then
    VERSION="$(tr -d '\r\n' < "$VERSION_FILE")"
else
    VERSION="unknown"
fi
echo "版本: $VERSION"

echo "[2/5] 下载项目包..."
download_with_fallback "$PACKAGE_FILE" "项目包" "$GITEE_PACKAGE_URL" "$GITHUB_PACKAGE_URL" || exit 1
PACKAGE_SOURCE="$DOWNLOAD_SOURCE"

echo "[3/5] SHA256完整性校验..."
EXPECTED_SHA256="${ZHOUKEER_SHA256:-}"
if [ -z "$EXPECTED_SHA256" ]; then
    if [ "$PACKAGE_SOURCE" = "Gitee" ]; then
        curl -fL --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o "$CHECKSUM_FILE" "$GITEE_CHECKSUM_URL" 2>/dev/null || true
    else
        curl -fL --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" -o "$CHECKSUM_FILE" "$GITHUB_CHECKSUM_URL" 2>/dev/null || true
    fi

    if [ -s "$CHECKSUM_FILE" ]; then
        EXPECTED_SHA256="$(awk '/\.tar\.gz/ {print $1; exit} NF >= 1 {candidate=$1} END {if (candidate) print candidate}' "$CHECKSUM_FILE" | head -n 1)"
    fi
fi

ACTUAL_SHA256="$(sha256_file "$PACKAGE_FILE")"
if [ -n "$EXPECTED_SHA256" ]; then
    if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "SHA256校验失败，已停止安装。"
        echo "期望: $EXPECTED_SHA256"
        echo "实际: $ACTUAL_SHA256"
        exit 1
    fi
    echo "SHA256校验通过"
else
    echo "未获取到 SHA256SUMS，开发阶段继续安装。"
    echo "当前包 SHA256: $ACTUAL_SHA256"
fi

echo "[4/5] 解压并检查安装器..."
tar -xzf "$PACKAGE_FILE" -C "$TMP_DIR"
PACKAGE_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 2 -type f -name install.sh -print | head -n 1)"
PACKAGE_DIR="$(dirname "$PACKAGE_DIR")"

if [ -z "$PACKAGE_DIR" ] || [ ! -f "$PACKAGE_DIR/install.sh" ]; then
    echo "项目包不完整：未找到 install.sh"
    exit 1
fi

if [ ! -f "$PACKAGE_DIR/main.sh" ] || [ ! -d "$PACKAGE_DIR/modules" ] || [ ! -d "$PACKAGE_DIR/core" ]; then
    echo "项目包不完整：缺少 main.sh、modules 或 core"
    exit 1
fi

echo "[5/5] 调用安装器..."
ZHOUKEER_INSTALL_DIR="$INSTALL_DIR" bash "$PACKAGE_DIR/install.sh"
