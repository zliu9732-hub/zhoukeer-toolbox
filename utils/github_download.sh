#!/bin/bash

# GitHub 统一下载模块：并行测量实际文件吞吐，逐源下载并在校验后原子替换。

if [ -n "${GITHUB_DOWNLOAD_LOADED:-}" ]; then
    return 0
fi
GITHUB_DOWNLOAD_LOADED=1

_GITHUB_SOURCES_RANKED=""
_GITHUB_RANKED_FOR_URL=""
_LATEST_RELEASE_TAG=""
_LATEST_RELEASE_ASSET=""
_LATEST_RELEASE_SHA256=""
_LATEST_RELEASE_URL=""

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
    local url="$1"
    local configured="${GITHUB_MIRRORS:-}"
    local source release_proxy

    # GitHub Release 优先使用 ghfast.top 代理前缀；其他镜像和官方源仍参与
    # 实际文件测速与逐源回退，完整下载必须通过调用方 SHA256 校验。
    case "$url" in
        https://github.com/*/releases/download/*)
            release_proxy="${GITHUB_RELEASE_PROXY:-https://ghfast.top/}"
            if ! declare -F download_policy_github_mirror_allowed >/dev/null 2>&1 || \
                download_policy_github_mirror_allowed "$release_proxy"; then
                printf '%s\n' "$release_proxy"
            else
                declare -F log >/dev/null 2>&1 && \
                    log "GitHub Release 代理未列入白名单，改用官方源：$release_proxy"
            fi
            ;;
    esac

    for source in $configured; do
        if declare -F download_policy_github_mirror_allowed >/dev/null 2>&1 && \
            ! download_policy_github_mirror_allowed "$source"; then
            declare -F log >/dev/null 2>&1 && log "忽略未列入白名单的 GitHub 下载源：$source"
            continue
        fi
        case "$source" in https://*) printf '%s\n' "$source" ;; *) declare -F log >/dev/null 2>&1 && log "忽略非 HTTPS GitHub 下载源：$source" ;; esac
    done
    printf '%s\n' "https://github.com"
}

# Steamcommunity 302 的 GitHub 规则接管官方域名；测速时仍让官方源与
# 第三方镜像公平比较，避免仅凭规则开启状态选到吞吐较慢的节点。
_github_steam302_is_ready() {
    declare -F steam302_download_acceleration_is_ready >/dev/null 2>&1 || return 1
    steam302_download_acceleration_is_ready >/dev/null 2>&1
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
    local probe_bytes=524288

    probe_connect_timeout="$(_github_setting "${GITHUB_PROBE_CONNECT_TIMEOUT:-}" 2)"
    probe_max_time="$(_github_setting "${GITHUB_PROBE_MAX_TIME:-}" 4)"
    resolved_url="$(_resolve_github_url "$url" "$source")"
    # 仅取实际目标文件的前 512KiB，反映大包 CDN 吞吐；最大响应限制会拒绝
    # 忽略 Range 的镜像，避免测速时意外下载完整发布包。
    curl --fail --location --silent --output /dev/null --write-out '%{speed_download}' \
        --proto '=https' --proto-redir '=https' \
        --connect-timeout "$probe_connect_timeout" --max-time "$probe_max_time" \
        --range "0-$((probe_bytes - 1))" --max-filesize "$probe_bytes" \
        "$resolved_url" 2>/dev/null
}

get_ranked_github_sources() {
    local url="${1:-https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/VERSION}"
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
            speed="$(_github_source_speed "$source" "$url")" || exit 0
            case "$speed" in
                ''|*[!0-9.]*) exit 0 ;;
            esac
            printf '%s|%s|%s\n' "$speed" "$index" "$source" > "$result_file"
        ) &
    done < <(_github_mirror_list "$url")
    wait

    _GITHUB_SOURCES_RANKED="$(cat "$work_dir"/* 2>/dev/null | \
        sort -t'|' -k1,1nr -k2,2n | cut -d'|' -f3- | awk '!seen[$0]++')"
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

_github_filter_curl_progress() {
    # 只处理 GitHub 安装包下载的显示：保留进度条内容，去掉 curl 自动重试
    # 与错误码英文；下载策略、重试次数和返回状态完全由原 curl 命令决定。
    awk '
        {
            visible = $0
            lowered = tolower(visible)
            technical_at = index(lowered, "warning:")
            if (technical_at && substr(lowered, technical_at) !~ /(retry|timeout|problem)/) {
                technical_at = 0
            }
            if (!technical_at) technical_at = index(lowered, "curl: (")
            if (technical_at) visible = substr(visible, 1, technical_at - 1)
            if (visible != "") print visible
        }
    '
}

download_github_file() {
    local url="$1"
    local output="$2"
    local expected_sha256="${3:-}"
    local name="${4:-GitHub文件}"
    local connect_timeout max_time retries min_speed min_speed_time
    local proxy="${GITHUB_DOWNLOAD_PROXY:-${DECKY_DOWNLOAD_PROXY:-}}"
    local ranked_sources source resolved_url temp_file actual_sha256 max_bytes
    local curl_options=()

    connect_timeout="$(_github_setting "${GITHUB_CONNECT_TIMEOUT:-}" 10)"
    max_time="$(_github_setting "${GITHUB_MAX_TIME:-}" 1200)"
    retries="$(_github_setting "${GITHUB_RETRIES:-}" 2)"
    min_speed="$(_github_setting "${GITHUB_MIN_SPEED_BYTES:-}" 65536)"
    min_speed_time="$(_github_setting "${GITHUB_MIN_SPEED_TIME:-}" 60)"

    if declare -F download_policy_url_allowed >/dev/null 2>&1 && \
        ! download_policy_url_allowed "$url"; then
        echo "$name 下载地址不在受控来源清单中，已拒绝下载。"
        return 1
    fi
    case "${url%%\?*}" in
        *.zip|*.tar.gz|*.AppImage|*.exe|*.msi)
            if [ -z "$expected_sha256" ]; then
                echo "$name 缺少固定 SHA256，已拒绝下载。"
                return 1
            fi
            ;;
    esac
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
        --fail --location --progress-bar
        --proto '=https' --proto-redir '=https'
        --connect-timeout "$connect_timeout" --max-time "$max_time"
        --retry "$retries" --retry-delay 1 --retry-connrefused
        --speed-limit "$min_speed" --speed-time "$min_speed_time"
    )
    if declare -F download_policy_max_bytes >/dev/null 2>&1; then
        max_bytes="$(download_policy_max_bytes "$url")"
        curl_options+=(--max-filesize "$max_bytes")
    fi
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
        if ! curl "${curl_options[@]}" --output "$temp_file" "$resolved_url" \
            2> >(_github_filter_curl_progress >&2); then
            continue
        fi
        if ! _github_download_is_plausible "$temp_file" || \
            { declare -F download_policy_response_is_safe >/dev/null 2>&1 && \
              ! download_policy_response_is_safe "$url" "$temp_file"; }; then
            continue
        fi
        if [ -n "$expected_sha256" ]; then
            actual_sha256="$(_github_sha256 "$temp_file")" || {
                rm -f -- "$temp_file"
                echo "$name 缺少 SHA256 校验工具，已停止下载。"
                return 1
            }
            if [ "$actual_sha256" != "$expected_sha256" ]; then
                continue
            fi
        fi
        if mv -f -- "$temp_file" "$output"; then
            echo "$name 下载完成。"
            declare -F log >/dev/null 2>&1 && log "GitHub 下载成功: $name"
            return 0
        fi
        break
    done <<EOF
$ranked_sources
EOF

    rm -f -- "$temp_file"
    echo "$name 下载失败。"
    declare -F log >/dev/null 2>&1 && log "GitHub 下载失败: $name"
    return 1
}

# 解析 GitHub 最新正式 Release 元数据，只接受匹配资产名并带 SHA256 digest 的资产。
_parse_latest_github_release() {
    local json_file="$1"
    local asset_pattern="$2"
    local metadata

    metadata="$(awk -v pattern="$asset_pattern" '
        function field_value(line, re, result) {
            if (match(line, re)) {
                result = substr(line, RSTART, RLENGTH)
                sub(/^"[^"]*"[[:space:]]*:[[:space:]]*"/, "", result)
                sub(/"$/, "", result)
                return result
            }
            return ""
        }
        {
            line = $0
            value = field_value(line, "\"tag_name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")
            if (value != "") tag = value
            value = field_value(line, "\"name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")
            if (value != "") {
                if (asset != "" && digest != "" && url != "" && asset ~ pattern) {
                    print tag "\t" asset "\t" digest "\t" url
                    exit
                }
                asset = value
                digest = ""
                url = ""
            }
            value = field_value(line, "\"digest\"[[:space:]]*:[[:space:]]*\"sha256:[0-9a-fA-F]{64}\"")
            if (value != "" && asset != "") {
                digest = value
                sub(/^sha256:/, "", digest)
            }
            value = field_value(line, "\"browser_download_url\"[[:space:]]*:[[:space:]]*\"[^\"]*\"")
            if (value != "" && asset != "") url = value
        }
        END {
            if (asset != "" && digest != "" && url != "" && asset ~ pattern) {
                print tag "\t" asset "\t" digest "\t" url
            }
        }
    ' "$json_file")" || return 1
    [ -n "$metadata" ] || return 1

    IFS=$'\t' read -r _LATEST_RELEASE_TAG _LATEST_RELEASE_ASSET \
        _LATEST_RELEASE_SHA256 _LATEST_RELEASE_URL <<< "$metadata"
    case "$_LATEST_RELEASE_SHA256" in
        ''|*[!0-9A-Fa-f]*) return 1 ;;
    esac
    [ "${#_LATEST_RELEASE_SHA256}" -eq 64 ] || return 1
}

resolve_latest_github_release() {
    local repo="$1"
    local asset_pattern="$2"
    local name="${3:-Release文件}"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local temp_file

    _LATEST_RELEASE_TAG=""
    _LATEST_RELEASE_ASSET=""
    _LATEST_RELEASE_SHA256=""
    _LATEST_RELEASE_URL=""

    if declare -F download_policy_github_repo_allowed >/dev/null 2>&1 && \
        ! download_policy_github_repo_allowed "$repo"; then
        echo "$name 最新 Release 仓库不在受控来源清单中。"
        return 1
    fi
    if declare -F download_policy_url_allowed >/dev/null 2>&1 && \
        ! download_policy_url_allowed "$api_url"; then
        echo "$name 最新 Release 元数据地址不在受控来源清单中。"
        return 1
    fi

    temp_file="$(mktemp 2>/dev/null)" || return 1
    if ! curl --fail --location --silent --proto '=https' --proto-redir '=https' \
        --connect-timeout "$(_github_setting "${GITHUB_API_CONNECT_TIMEOUT:-}" 10)" \
        --max-time "$(_github_setting "${GITHUB_API_MAX_TIME:-}" 30)" \
        --retry 2 --retry-delay 2 --retry-all-errors \
        --max-filesize "$(download_policy_max_bytes "$api_url")" \
        --output "$temp_file" "$api_url" || \
        { declare -F download_policy_response_is_safe >/dev/null 2>&1 && \
          ! download_policy_response_is_safe "$api_url" "$temp_file"; }; then
        rm -f -- "$temp_file"
        echo "$name 最新 Release 元数据获取失败。"
        return 1
    fi

    if ! _parse_latest_github_release "$temp_file" "$asset_pattern"; then
        rm -f -- "$temp_file"
        echo "$name 最新 Release 中未找到匹配资产或缺少 SHA256。"
        return 1
    fi
    rm -f -- "$temp_file"
    echo "$name 最新 Release: $_LATEST_RELEASE_TAG / $_LATEST_RELEASE_ASSET"
    return 0
}

download_latest_github_release() {
    local repo="$1"
    local asset_pattern="$2"
    local output="$3"
    local name="${4:-Release文件}"

    resolve_latest_github_release "$repo" "$asset_pattern" "$name" || return 1
    download_github_release "$repo" "$_LATEST_RELEASE_TAG" "$_LATEST_RELEASE_ASSET" \
        "$output" "$_LATEST_RELEASE_SHA256" "$name"
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
