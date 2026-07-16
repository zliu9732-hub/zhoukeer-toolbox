#!/bin/bash

set -u

DRY_RUN=0
STARTUP_MODE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        --startup)
            STARTUP_MODE=1
            ;;
        *)
            echo "未知参数: $arg"
            exit 1
            ;;
    esac
done

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITEE_OWNER="${ZHOUKEER_GITEE_OWNER:-zliu9732-hub}"
GITHUB_OWNER="${ZHOUKEER_GITHUB_OWNER:-zliu9732-hub}"
REPO_NAME="${ZHOUKEER_REPO_NAME:-zhoukeer-toolbox}"
BRANCH="${ZHOUKEER_BRANCH:-main}"

# Gitee 首次跳转到国内 CDN 偶尔较慢，不能因一次短暂网络波动立刻改走 GitHub。
CONNECT_TIMEOUT="${ZHOUKEER_CONNECT_TIMEOUT:-20}"
MAX_TIME="${ZHOUKEER_MAX_TIME:-600}"
VERSION_CONNECT_TIMEOUT="${ZHOUKEER_VERSION_CONNECT_TIMEOUT:-8}"
VERSION_MAX_TIME="${ZHOUKEER_VERSION_MAX_TIME:-30}"

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
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$output" \
        "$url"
}

download_version_one() {
    local url="$1"
    local output="$2"
    local label="$3"

    echo "检查版本($label)..."
    rm -f -- "$output"
    curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$VERSION_CONNECT_TIMEOUT" \
        --max-time "$VERSION_MAX_TIME" \
        --retry 3 \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$output" \
        "$url"
}

valid_release_version() {
    local value="$1"

    [ -n "$value" ] && [ "${#value}" -le 64 ] || return 1
    case "$value" in
        *[!A-Za-z0-9._+-]*) return 1 ;;
    esac
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

    if [ "${VERSION_SOURCE:-}" = "GitHub" ]; then
        if download_verified_package_from \
            "GitHub" "$GITHUB_PACKAGE_URL" "$GITHUB_CHECKSUM_URL" \
            "$package_file" "$checksum_file"; then
            DOWNLOAD_SOURCE="GitHub"
            return 0
        fi

        echo "GitHub包或校验文件不可用，切换Gitee备用源。"
    if download_verified_package_from \
        "域名" "$DOMAIN_PACKAGE_URL" "$DOMAIN_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="域名"
        return 0
    fi
        if download_verified_package_from \
            "Gitee" "$GITEE_PACKAGE_URL" "$GITEE_CHECKSUM_URL" \
            "$package_file" "$checksum_file"; then
            DOWNLOAD_SOURCE="Gitee"
            return 0
        fi

        echo "更新包验证失败：GitHub和Gitee均不可用。旧版本不会被覆盖。"
        return 1
    fi

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

    echo "更新包验证失败：Gitee和GitHub均不可用。旧版本不会被覆盖。"
    return 1
}

download_version_with_fallback() {
    local output="$1"

    if download_version_one "$DOMAIN_VERSION_URL" "$output" "域名"; then
        VERSION_SOURCE="域名"
        return 0
    fi
    if download_version_one "$GITEE_VERSION_URL" "$output" "Gitee"; then
        VERSION_SOURCE="Gitee"
        return 0
    fi

    echo "Gitee版本检测失败，切换GitHub备用源。"
    if download_version_one "$GITHUB_VERSION_URL" "$output" "GitHub"; then
        VERSION_SOURCE="GitHub"
        return 0
    fi

    echo "版本检测失败：Gitee和GitHub均不可用。旧版本不会被覆盖。"
    return 1
}

SYSTEM="$(uname -s 2>/dev/null || echo unknown)"

echo "================================"
echo " 周克儿工具箱 V4 自更新"
echo "================================"
echo "当前目录: $PROJECT_ROOT"
echo "分支: $BRANCH"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "模式: dry-run"
elif [ "$STARTUP_MODE" -eq 1 ]; then
    echo "模式: startup-auto-update"
else
    echo "模式: update"
fi
echo ""

if [ "$SYSTEM" = "Darwin" ]; then
    echo "检测到 macOS。仅允许语法测试，不执行 SteamOS 自更新。"
    exit 0
fi

if [ "$SYSTEM" != "Linux" ]; then
    echo "不支持的系统: $SYSTEM"
    exit 1
fi

need_command curl
need_command tar

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] 将先比较本地 VERSION 与远程 VERSION"
    echo "[dry-run] 将优先下载域名: $DOMAIN_PACKAGE_URL"
    echo "[dry-run] GitHub备用: $GITHUB_PACKAGE_URL"
    echo "[dry-run] 将更新目录: $PROJECT_ROOT"
    echo "[dry-run] 不会下载、解压或覆盖任何文件。"
    exit 0
fi

LOCK_DIR=""
if [ "$STARTUP_MODE" -eq 1 ]; then
    STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    LOCK_DIR="$STATE_HOME/zhoukeer-toolbox/auto-update.lock"
    mkdir -p "$(dirname "$LOCK_DIR")" || exit 1
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        LOCK_PID="$(sed -n '1p' "$LOCK_DIR/pid" 2>/dev/null || true)"
        case "$LOCK_PID" in
            ''|*[!0-9]*)
                LOCK_MTIME="$(stat -c '%Y' "$LOCK_DIR" 2>/dev/null || true)"
                NOW="$(date '+%s')"
                case "$LOCK_MTIME" in
                    ''|*[!0-9]*) LOCK_MTIME="$NOW" ;;
                esac
                if [ $((NOW - LOCK_MTIME)) -lt 300 ]; then
                    echo "已有自动更新任务正在准备，本次继续启动当前版本。"
                    exit 0
                fi
                LOCK_PID=""
                ;;
        esac
        if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
            echo "已有自动更新任务正在运行，本次继续启动当前版本。"
            exit 0
        fi
        rm -rf -- "$LOCK_DIR"
        if ! mkdir "$LOCK_DIR" 2>/dev/null; then
            echo "无法取得自动更新锁，本次继续启动当前版本。"
            exit 0
        fi
    fi
    printf '%s\n' "$$" > "$LOCK_DIR/pid"
fi

TMP_DIR="$(mktemp -d)"
PACKAGE_FILE="$TMP_DIR/zhoukeer-toolbox.tar.gz"
VERSION_FILE="$TMP_DIR/VERSION"
CHECKSUM_FILE="$TMP_DIR/SHA256SUMS"
EXTRACT_DIR="$TMP_DIR/extracted"

cleanup() {
    rm -rf "$TMP_DIR"
    if [ -n "$LOCK_DIR" ] && \
        [ "$(sed -n '1p' "$LOCK_DIR/pid" 2>/dev/null || true)" = "$$" ]; then
        rm -rf -- "$LOCK_DIR"
    fi
}
trap cleanup EXIT

echo "[1/4] 获取版本信息..."
if download_version_with_fallback "$VERSION_FILE"; then
    REMOTE_VERSION="$(tr -d '\r\n' < "$VERSION_FILE")"
    if ! valid_release_version "$REMOTE_VERSION"; then
        echo "远程版本格式无效，旧版本不会被覆盖。"
        exit 1
    fi
else
    if [ "$STARTUP_MODE" -eq 1 ]; then
        echo "自动更新检测暂时不可用。"
        exit 1
    fi
    REMOTE_VERSION="unknown"
fi
LOCAL_VERSION="unknown"
if [ -r "$PROJECT_ROOT/VERSION" ]; then
    LOCAL_VERSION="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
fi
echo "本地版本: $LOCAL_VERSION"
echo "远程版本: $REMOTE_VERSION"

if [ "$REMOTE_VERSION" != "unknown" ] && [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo "当前已是最新版本，无需更新。"
    exit 0
fi

echo "[2/4] 下载并校验更新包..."
download_verified_package "$PACKAGE_FILE" "$CHECKSUM_FILE" || exit 1
echo "下载源: $DOWNLOAD_SOURCE"

echo "[3/4] 解压更新包..."
mkdir -p "$EXTRACT_DIR"
tar -xzf "$PACKAGE_FILE" -C "$EXTRACT_DIR"
INSTALLER_PATH="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 2 -type f -name install.sh -print | head -n 1)"

if [ -z "$INSTALLER_PATH" ] || [ ! -f "$INSTALLER_PATH" ]; then
    echo "更新包不完整：未找到 install.sh。旧版本不会被覆盖。"
    exit 1
fi
PACKAGE_DIR="$(dirname "$INSTALLER_PATH")"

if [ "$REMOTE_VERSION" != "unknown" ]; then
    if [ ! -r "$PACKAGE_DIR/VERSION" ]; then
        echo "更新包不完整：缺少VERSION。旧版本不会被覆盖。"
        exit 1
    fi
    PACKAGE_VERSION="$(tr -d '\r\n' < "$PACKAGE_DIR/VERSION")"
    if [ "$PACKAGE_VERSION" != "$REMOTE_VERSION" ]; then
        echo "更新包版本与检测结果不一致。旧版本不会被覆盖。"
        echo "检测版本: $REMOTE_VERSION"
        echo "包内版本: $PACKAGE_VERSION"
        exit 1
    fi
fi

if ! find "$PACKAGE_DIR" -type f -name '*.sh' -exec bash -n {} \;; then
    echo "更新包包含Shell语法错误，旧版本不会被覆盖。"
    exit 1
fi

echo "[4/4] 调用安装器..."
# 安装器会原子替换 PROJECT_ROOT；从安装目录内启动更新时必须先离开旧目录。
cd "$HOME" 2>/dev/null || cd "$(dirname "$PROJECT_ROOT")" 2>/dev/null || cd / || exit 1
ZHOUKEER_INSTALL_DIR="$PROJECT_ROOT" bash "$INSTALLER_PATH"

# 安装目录采用原子替换；恢复当前工作目录，避免调用方继续引用已删除的旧目录。
cd "$PROJECT_ROOT" 2>/dev/null || cd "$HOME" || exit 1

echo "自更新完成"
