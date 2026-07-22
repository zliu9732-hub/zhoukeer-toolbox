#!/bin/bash

# GitHub 统一下载模块：并行探测可配置镜像，逐源下载并在校验后原子替换。

if [ -n "${GITHUB_DOWNLOAD_LOADED:-}" ]; then
    return 0
fi
GITHUB_DOWNLOAD_LOADED=1

_GITHUB_SOURCES_RANKED=""
_GITHUB_RANKED_FOR_URL=""

_github_positive_integer() {
    case "$1" in
        ''|*[!0-9]*|0) return 1 ;;
        *) return 0 ;;
    esac
}

_github_setting() {
    local value="$1"
    local fallback="$2"
    if _github_positive_integer "$value"; then
        printf '%s' "$value"
    else
        printf '%s' "$fallback"
    fi
}

_github_mirror_list() {
    local configured="${GITHUB_MIRRORS:-}"
    local source

    for source in $configured; do
        case "$source" in
            https://*) printf '%s\n' "$source" ;;
            *) printf '忽略非 HTTPS GitHub 下载源：%s\n' "$source" >&2 ;;
        esac
    done
    printf '%s\n' "https://github.com"
}

# 下载源可以是完整 URL 前缀，也可以用 {url} 表示原始 GitHub URL。
_resolve_github_url() {
    local url="$1"
    local source="$2"

    case "$source" in
        https://github.com|https://github.com/)
            printf '%s' "$url"
            ;;
        *'{url}'*)
            printf '%s' "${source//\{url\}/$url}"
            ;;
        */)
            printf '%s%s' "$source" "$url"
            ;;
        *)
            printf '%s/%s' "$source" "$url"
            ;;
    esac
}

_github_source_speed() {
    local source="$1"
    local url="$2"
    local probe_connect_timeout probe_max_time resolved_url

    probe_connect_timeout="$(_github_setting "${GITHUB_PROBE_CONNECT_TIMEOUT:-}" 2)"
    probe_max_time="$(_github_setting "${GITHUB_PROBE_MAX_TIME:-}" 4)"
    resolved_url="$(_resolve_github_url "$url" "$source")"
    curl --fail --location --silent --output /dev/null --write-out '%{time_total}' \
        --proto '=https' --proto-redir '=https' \
        --connect-timeout "$probe_connect_timeout" --max-time "$probe_max_time" \
        "$resolved_url" 2>/dev/null
}

get_ranked_github_sources() {
    local url="${1:-https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/VERSION}"
    local probe_url="https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/VERSION"
    local work_dir source index=0 result_file

    if [ "$url" = "$_GITHUB_RANKED_FOR_URL" ] && [ -n "$_GITHUB_SOURCES_RANKED" ]; then
        printf '%s' "$_GITHUB_SOURCES_RANKED"
        return 0
    fi

    work_dir="$(mktemp -d 2>/dev/null)" || return 1
    while IFS= read -r source; do
        [ -n "$source" ] || continue
        index=$((index + 1))
        result_file="$work_dir/$index"
        (
            speed="$(_github_source_speed "$source" "$probe_url")" || exit 0
            case "$speed" in
                ''|*[!0-9.]*) exit 0 ;;
            esac
            printf '%s|%s|%s\n' "$speed" "$index" "$source" > "$result_file"
        ) &
    done < <(_github_mirror_list)
    wait

    _GITHUB_SOURCES_RANKED="$(cat "$work_dir"/* 2>/dev/null | \
        sort -t'|' -k1,1n -k2,2n | cut -d'|' -f3- | awk '!seen[$0]++')"
    rm -rf -- "$work_dir"
    if ! printf '%s\n' "$_GITHUB_SOURCES_RANKED" | grep -Fxq 'https://github.com'; then
        if [ -n "$_GITHUB_SOURCES_RANKED" ]; then
            _GITHUB_SOURCES_RANKED="$_GITHUB_SOURCES_RANKED
https://github.com"
        else
            _GITHUB_SOURCES_RANKED="https://github.com"
        fi
    fi
    _GITHUB_RANKED_FOR_URL="$url"
    printf '%s' "$_GITHUB_SOURCES_RANKED"
}

_github_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$1" | awk '{print $1}'
    else
        return 1
    fi
}

_github_download_is_plausible() {
    local file="$1"
    [ -s "$file" ] || return 1
    if LC_ALL=C head -c 512 "$file" 2>/dev/null | grep -Eiq '<(!doctype[[:space:]]+html|html[[:space:]>])'; then
        return 1
    fi
}

download_github_file() {
    local url="$1"
    local output="$2"
    local expected_sha256="${3:-}"
    local name="${4:-GitHub文件}"
    local connect_timeout max_time retries min_speed min_speed_time
    local proxy="${GITHUB_DOWNLOAD_PROXY:-${DECKY_DOWNLOAD_PROXY:-}}"
    local ranked_sources source resolved_url temp_file actual_sha256
    local curl_options=()

    connect_timeout="$(_github_setting "${GITHUB_CONNECT_TIMEOUT:-}" 10)"
    max_time="$(_github_setting "${GITHUB_MAX_TIME:-}" 1200)"
    retries="$(_github_setting "${GITHUB_RETRIES:-}" 2)"
    min_speed="$(_github_setting "${GITHUB_MIN_SPEED_BYTES:-}" 65536)"
    min_speed_time="$(_github_setting "${GITHUB_MIN_SPEED_TIME:-}" 60)"

    case "$url" in
        https://github.com/*|https://raw.githubusercontent.com/*)
            ranked_sources="$(get_ranked_github_sources "$url")" || ranked_sources=""
            ;;
        https://*) ranked_sources="DIRECT" ;;
        *)
            echo "$name 下载地址不是 HTTPS，已拒绝下载。"
            return 1
            ;;
    esac

    temp_file="$(mktemp "${output}.part.XXXXXX" 2>/dev/null)" || {
        echo "$name 无法创建临时下载文件。"
        return 1
    }
    curl_options=(
        --fail --location --show-error --progress-bar
        --proto '=https' --proto-redir '=https'
        --connect-timeout "$connect_timeout" --max-time "$max_time"
        --retry "$retries" --retry-delay 1 --retry-connrefused
        --speed-limit "$min_speed" --speed-time "$min_speed_time"
    )
    [ -z "$proxy" ] || curl_options+=(--proxy "$proxy")

    echo "正在下载 $name..."
    while IFS= read -r source; do
        [ -n "$source" ] || continue
        if [ "$source" = "DIRECT" ]; then
            resolved_url="$url"
        else
            resolved_url="$(_resolve_github_url "$url" "$source")"
        fi

        rm -f -- "$temp_file"
        temp_file="$(mktemp "${output}.part.XXXXXX" 2>/dev/null)" || return 1
        if ! curl "${curl_options[@]}" --output "$temp_file" "$resolved_url"; then
            continue
        fi
        if ! _github_download_is_plausible "$temp_file"; then
            echo "$name 下载内容为空或疑似网页，正在尝试下一源。"
            continue
        fi
        if [ -n "$expected_sha256" ]; then
            actual_sha256="$(_github_sha256 "$temp_file")" || {
                rm -f -- "$temp_file"
                echo "$name 缺少 SHA256 校验工具，已停止下载。"
                return 1
            }
            if [ "$actual_sha256" != "$expected_sha256" ]; then
                echo "$name SHA256校验失败，正在尝试下一源。"
                continue
            fi
        fi
        if mv -f -- "$temp_file" "$output"; then
            [ -z "$expected_sha256" ] || echo "$name 下载完成并通过完整性校验。"
            [ -n "$expected_sha256" ] || echo "$name 下载完成。"
            declare -F log >/dev/null 2>&1 && log "GitHub 下载成功: $name"
            return 0
        fi
        break
    done <<EOF
$ranked_sources
EOF

    rm -f -- "$temp_file"
    echo "$name 下载失败，所有可用源均未成功；现有文件未改动。"
    declare -F log >/dev/null 2>&1 && log "GitHub 下载失败: $name"
    return 1
}

download_github_release() {
    local repo="$1" tag="$2" asset="$3" output="$4"
    local expected_sha256="${5:-}" name="${6:-$asset}"
    download_github_file "https://github.com/$repo/releases/download/$tag/$asset" \
        "$output" "$expected_sha256" "Release $name"
}

download_github_raw() {
    local repo="$1" branch="$2" path="$3" output="$4"
    local name="${5:-${path##*/}}"
    download_github_file "https://raw.githubusercontent.com/$repo/$branch/$path" \
        "$output" "" "Raw $name"
}
