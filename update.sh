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
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/download_policy.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/source_status.sh"
GITEE_OWNER="${ZHOUKEER_GITEE_OWNER:-zliu9732-hub}"
GITHUB_OWNER="${ZHOUKEER_GITHUB_OWNER:-}"
REPO_NAME="${ZHOUKEER_REPO_NAME:-zhoukeer-toolbox-v2}"
BRANCH="${ZHOUKEER_BRANCH:-main}"

# Gitee 首次跳转到国内 CDN 偶尔较慢，不能因一次短暂网络波动立刻改走 GitHub。
CONNECT_TIMEOUT="${ZHOUKEER_CONNECT_TIMEOUT:-20}"
MAX_TIME="${ZHOUKEER_MAX_TIME:-600}"
if [ "$STARTUP_MODE" -eq 1 ]; then
    # 启动时版本检测只做快速确认，避免已是最新版本时长时间卡在加载界面。
    VERSION_CONNECT_TIMEOUT="${ZHOUKEER_STARTUP_VERSION_CONNECT_TIMEOUT:-4}"
    VERSION_MAX_TIME="${ZHOUKEER_STARTUP_VERSION_MAX_TIME:-10}"
    VERSION_RETRIES="${ZHOUKEER_STARTUP_VERSION_RETRIES:-1}"
else
    VERSION_CONNECT_TIMEOUT="${ZHOUKEER_VERSION_CONNECT_TIMEOUT:-8}"
    VERSION_MAX_TIME="${ZHOUKEER_VERSION_MAX_TIME:-30}"
    VERSION_RETRIES="${ZHOUKEER_VERSION_RETRIES:-3}"
fi
CACHE_BUSTER="${ZHOUKEER_CACHE_BUSTER:-$(date '+%s')-$$}"

GITEE_RAW_BASE="${ZHOUKEER_GITEE_RAW_BASE:-https://gitee.com/$GITEE_OWNER/$REPO_NAME/raw/$BRANCH}"
GITHUB_RAW_BASE="${ZHOUKEER_GITHUB_RAW_BASE:-}"
if [ -z "$GITHUB_RAW_BASE" ] && [ -n "$GITHUB_OWNER" ]; then
    GITHUB_RAW_BASE="https://raw.githubusercontent.com/$GITHUB_OWNER/$REPO_NAME/$BRANCH"
fi
DOMAIN_RAW_BASE="${ZHOUKEER_DOMAIN_RAW_BASE:-}"
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

cache_busted_url() {
    case "$1" in
        *\?*) printf '%s&zhoukeer_cb=%s\n' "$1" "$CACHE_BUSTER" ;;
        *) printf '%s?zhoukeer_cb=%s\n' "$1" "$CACHE_BUSTER" ;;
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
    local request_url

    rm -f -- "$output"
    request_url="$(cache_busted_url "$url")"
    local max_bytes
    download_policy_url_allowed "$url" || {
        echo "$label 下载地址不在受控来源清单中。"
        return 1
    }
    max_bytes="$(download_policy_max_bytes "$url")"
    curl \
        --fail \
        --location \
        --progress-meter \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$CONNECT_TIMEOUT" \
        --max-time "$MAX_TIME" \
        --retry 2 \
        --retry-delay 2 \
        --retry-all-errors \
        --max-filesize "$max_bytes" \
        --output "$output" \
        "$request_url" \
        2> >(download_progress_filter "$label" >&2) && \
        download_policy_response_is_safe "$url" "$output"
}

download_version_one() {
    local url="$1"
    local output="$2"
    local label="$3"
    local request_url

    rm -f -- "$output"
    request_url="$(cache_busted_url "$url")"
    download_policy_url_allowed "$url" || {
        echo "$label 版本地址不在受控来源清单中。"
        return 1
    }
    curl \
        --fail \
        --location \
        --silent \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$VERSION_CONNECT_TIMEOUT" \
        --max-time "$VERSION_MAX_TIME" \
        --retry "$VERSION_RETRIES" \
        --retry-delay 2 \
        --retry-all-errors \
        --max-filesize 2097152 \
        --output "$output" \
        "$request_url" && download_policy_response_is_safe "$url" "$output"
}

valid_release_version() {
    local value="$1"

    [ -n "$value" ] && [ "${#value}" -le 64 ] || return 1
    case "$value" in
        *[!A-Za-z0-9._+-]*) return 1 ;;
    esac
}

version_greater() {
    # 返回 0 表示 $1 高于 $2；数字段按数值比较，字母段按字典序。
    local left="$1" right="$2"
    local left_part right_part left_tail right_tail left_is_number right_is_number

    while :; do
        case "$left" in
            *.*) left_part="${left%%.*}"; left_tail="${left#*.}" ;;
            *) left_part="$left"; left_tail="" ;;
        esac
        case "$right" in
            *.*) right_part="${right%%.*}"; right_tail="${right#*.}" ;;
            *) right_part="$right"; right_tail="" ;;
        esac

        # 去掉前导零，避免 08/09 被当作八进制；字母段保持原样。
        case "$left_part" in
            ''|*[!0-9]*) ;;
            *) left_part="${left_part#"${left_part%%[!0]*}"}"; left_part="${left_part:-0}" ;;
        esac
        case "$right_part" in
            ''|*[!0-9]*) ;;
            *) right_part="${right_part#"${right_part%%[!0]*}"}"; right_part="${right_part:-0}" ;;
        esac

        if [ "$left_part" != "$right_part" ]; then
            case "$left_part" in
                *[!0-9]*|'') left_is_number=0 ;;
                *) left_is_number=1 ;;
            esac
            case "$right_part" in
                *[!0-9]*|'') right_is_number=0 ;;
                *) right_is_number=1 ;;
            esac
            if [ "$left_is_number" -eq 1 ] && [ "$right_is_number" -eq 1 ]; then
                if [ "$left_part" -gt "$right_part" ] 2>/dev/null; then
                    return 0
                fi
                return 1
            fi
            [[ "$left_part" > "$right_part" ]]
            return $?
        fi

        if [ -z "$left_tail" ] && [ -z "$right_tail" ]; then
            return 1
        fi
        if [ -z "$left_tail" ]; then
            return 1
        fi
        if [ -z "$right_tail" ]; then
            return 0
        fi
        left="$left_tail"
        right="$right_tail"
    done
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
        echo "更新包不是有效的 tar.gz 文件。"
        return 1
    }
    while IFS= read -r entry; do
        entry_count=$((entry_count + 1))
        case "$entry" in
            /*|../*|*/../*|*/..)
                echo "更新包包含不安全路径：$entry"
                return 1
                ;;
        esac
    done < "$listing"
    if [ "$entry_count" -eq 0 ] || [ "$entry_count" -gt 5000 ]; then
        echo "更新包文件数量异常：$entry_count"
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
        echo "更新包包含不安全的链接。"
        return 1
    fi
}

download_verified_package_from() {
    local label="$1"
    local package_url="$2"
    local checksum_url="$3"
    local package_file="$4"
    local checksum_file="$5"
    local expected
    local attempt

    # Gitee 国内 CDN 偶尔先刷新小文件、后刷新大文件，首次 SHA256 可能短暂不匹配。
    # 重新下载一次校验文件和更新包，避免把 CDN 缓存波动误判为源不可用。
    for attempt in 1 2; do
        expected="${ZHOUKEER_SHA256:-}"
        rm -f -- "$package_file" "$checksum_file"
        if download_one "$package_url" "$package_file" "${label}更新包" && \
            { [ -n "$expected" ] || download_one "$checksum_url" "$checksum_file" "${label}校验文件"; } && \
            { [ -n "$expected" ] || expected="$(checksum_from_manifest "$checksum_file" "$PACKAGE_NAME")"; } && \
            verify_package "$package_file" "$expected"; then
            return 0
        fi
        [ "$attempt" -eq 1 ] || return 1
        sleep 3
    done
    return 1
}

download_verified_package() {
    local package_file="$1"
    local checksum_file="$2"

    if [ "${VERSION_SOURCE:-}" = "GitHub" ]; then
        if download_verified_package_from \
            "GitHub" "$GITHUB_PACKAGE_URL" "$GITHUB_CHECKSUM_URL" \
            "$package_file" "$checksum_file"; then
            DOWNLOAD_SOURCE="GitHub"
            source_status_record update-github ok "更新包与校验文件可用" >/dev/null 2>&1 || true
            return 0
        fi
        source_status_record update-github fail "更新包或校验文件不可用" >/dev/null 2>&1 || true

        echo "GitHub包或校验文件不可用，切换域名源。"
        if download_verified_package_from \
            "域名" "$DOMAIN_PACKAGE_URL" "$DOMAIN_CHECKSUM_URL" \
            "$package_file" "$checksum_file"; then
            DOWNLOAD_SOURCE="域名"
            source_status_record update-domain ok "更新包与校验文件可用" >/dev/null 2>&1 || true
            return 0
        fi
        source_status_record update-domain fail "更新包或校验文件不可用" >/dev/null 2>&1 || true
        echo "域名源不可用，切换国内镜像备用源。"
        if download_verified_package_from \
            "国内镜像" "$GITEE_PACKAGE_URL" "$GITEE_CHECKSUM_URL" \
            "$package_file" "$checksum_file"; then
            DOWNLOAD_SOURCE="Gitee"
            source_status_record update-gitee ok "更新包与校验文件可用" >/dev/null 2>&1 || true
            return 0
        fi
        source_status_record update-gitee fail "更新包或校验文件不可用" >/dev/null 2>&1 || true

        echo "更新包验证失败：GitHub、域名源和国内镜像均不可用。旧版本不会被覆盖。"
        return 1
    fi

    if download_verified_package_from \
        "国内镜像" "$GITEE_PACKAGE_URL" "$GITEE_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="Gitee"
        source_status_record update-gitee ok "更新包与校验文件可用" >/dev/null 2>&1 || true
        return 0
    fi
    source_status_record update-gitee fail "更新包或校验文件不可用" >/dev/null 2>&1 || true

    echo "国内镜像包或校验文件不可用，切换域名源。"
    if download_verified_package_from \
        "域名" "$DOMAIN_PACKAGE_URL" "$DOMAIN_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="域名"
        source_status_record update-domain ok "更新包与校验文件可用" >/dev/null 2>&1 || true
        return 0
    fi
    source_status_record update-domain fail "更新包或校验文件不可用" >/dev/null 2>&1 || true

    echo "域名源不可用，切换GitHub备用源。"
    if download_verified_package_from \
        "GitHub" "$GITHUB_PACKAGE_URL" "$GITHUB_CHECKSUM_URL" \
        "$package_file" "$checksum_file"; then
        DOWNLOAD_SOURCE="GitHub"
        source_status_record update-github ok "更新包与校验文件可用" >/dev/null 2>&1 || true
        return 0
    fi
    source_status_record update-github fail "更新包或校验文件不可用" >/dev/null 2>&1 || true

    echo "更新包验证失败：国内镜像、域名源和GitHub均不可用。旧版本不会被覆盖。"
    return 1
}

download_version_with_fallback() {
    local output="$1"
    local candidate_file="${output}.candidate"
    local candidate best="" source_url source_label source_name status_key
    local code_source_reachable=0 local_version="" source deadline=0

    if [ "$STARTUP_MODE" -eq 1 ]; then
        deadline=$((SECONDS + ${ZHOUKEER_STARTUP_VERSION_DEADLINE:-15}))
    fi

    for source in gitee github domain; do
        if [ "$deadline" -gt 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
            echo "版本检测超过启动限时，继续使用当前版本。"
            break
        fi
        case "$source" in
            gitee) source_url="$GITEE_VERSION_URL"; source_label="国内镜像"; source_name="Gitee"; status_key="update-gitee" ;;
            github) source_url="$GITHUB_VERSION_URL"; source_label="GitHub"; source_name="GitHub"; status_key="update-github" ;;
            domain) source_url="$DOMAIN_VERSION_URL"; source_label="域名"; source_name="域名"; status_key="update-domain" ;;
        esac
        rm -f -- "$candidate_file"
        if ! download_version_one "$source_url" "$candidate_file" "$source_label"; then
            source_status_record "$status_key" fail "版本检查失败" >/dev/null 2>&1 || true
            continue
        fi
        candidate="$(tr -d '\r\n' < "$candidate_file")"
        if ! valid_release_version "$candidate"; then
            source_status_record "$status_key" fail "版本格式无效" >/dev/null 2>&1 || true
            continue
        fi
        source_status_record "$status_key" ok "版本检查成功" >/dev/null 2>&1 || true
        [ "$source" = "domain" ] || code_source_reachable=1
        if [ -z "$best" ] || version_greater "$candidate" "$best"; then
            best="$candidate"
            VERSION_SOURCE="$source_name"
        fi
    done

    if [ -z "$best" ]; then
        echo "版本检测失败：国内镜像、GitHub 和域名源均不可用。旧版本不会被覆盖。"
        return 1
    fi

    # 域名源作为唯一可达源时不能单独裁决“已是最新”；版本高于本地时才允许更新。
    if [ "$code_source_reachable" -eq 0 ]; then
        if [ -r "$PROJECT_ROOT/VERSION" ]; then
            local_version="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
        fi
        if [ -n "$local_version" ] && valid_release_version "$local_version" && \
            ! version_greater "$best" "$local_version"; then
            echo "版本检测失败：域名源版本($best)未高于本地版本($local_version)，且国内镜像和GitHub均不可用。"
            return 1
        fi
    fi

    printf '%s\n' "$best" > "$output"
    return 0
}

SYSTEM="$(uname -s 2>/dev/null || echo unknown)"

echo "正在检查工具箱更新..."

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
if [ "$REMOTE_VERSION" != "unknown" ] && [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo "✓ 工具箱已是最新版本"
    exit 0
fi

echo "正在更新工具箱..."
if [ "$REMOTE_VERSION" != "unknown" ]; then
    echo "当前版本 V${LOCAL_VERSION}，正在更新到 V${REMOTE_VERSION}..."
fi
download_verified_package "$PACKAGE_FILE" "$CHECKSUM_FILE" || exit 1

mkdir -p "$EXTRACT_DIR"
validate_tar_archive "$PACKAGE_FILE" "$TMP_DIR/archive.list" "$TMP_DIR/archive.verbose" || exit 1
tar --no-xattrs --no-same-owner --no-same-permissions -xzf "$PACKAGE_FILE" -C "$EXTRACT_DIR" || exit 1
remove_appledouble_files "$EXTRACT_DIR" || {
    echo "无法清理更新包中的 macOS 元数据文件，旧版本不会被覆盖。"
    exit 1
}
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

if ! find "$PACKAGE_DIR" -type f -name '*.sh' ! -name '._*' -exec bash -n {} \;; then
    echo "更新包包含Shell语法错误，旧版本不会被覆盖。"
    exit 1
fi

# 安装器会原子替换 PROJECT_ROOT；从安装目录内启动更新时必须先离开旧目录。
cd "$HOME" 2>/dev/null || cd "$(dirname "$PROJECT_ROOT")" 2>/dev/null || cd / || exit 1
if ! ZHOUKEER_INSTALL_DIR="$PROJECT_ROOT" bash "$INSTALLER_PATH" >"$TMP_DIR/install.log" 2>&1; then
    echo "更新安装未完成，以下是最后的错误提示："
    tail -n 20 "$TMP_DIR/install.log"
    exit 1
fi

# 安装目录采用原子替换；恢复当前工作目录，避免调用方继续引用已删除的旧目录。
cd "$PROJECT_ROOT" 2>/dev/null || cd "$HOME" || exit 1

if [ "$REMOTE_VERSION" != "unknown" ]; then
    echo "✓ 工具箱更新完成，当前版本 V${PACKAGE_VERSION:-$REMOTE_VERSION}"
else
    echo "✓ 工具箱更新完成"
fi
