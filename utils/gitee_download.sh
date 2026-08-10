#!/bin/bash

# Gitee 分块镜像下载：从仓库 mirrors 目录读取 latest.txt 清单，逐块下载
# 并重组文件，完整下载必须通过清单中的 SHA256 校验。

if [ -n "${ZHOUKEER_GITEE_DOWNLOAD_LOADED:-}" ]; then
    return 0
fi
ZHOUKEER_GITEE_DOWNLOAD_LOADED=1

GITEE_MIRROR_OWNER="${ZHOUKEER_GITEE_MIRROR_OWNER:-zliu9732-hub}"
GITEE_MIRROR_REPO="${ZHOUKEER_GITEE_MIRROR_REPO:-zhoukeer-toolbox-mirror}"
GITEE_MIRROR_BRANCH="${ZHOUKEER_GITEE_MIRROR_BRANCH:-main}"
GITEE_MIRROR_CHUNK_BYTES="${ZHOUKEER_GITEE_MIRROR_CHUNK_BYTES:-8388608}"
GITEE_MIRROR_DIRECT_MAX_BYTES="${ZHOUKEER_GITEE_MIRROR_DIRECT_MAX_BYTES:-9437184}"
GITEE_MIRROR_ENABLED="${ZHOUKEER_GITEE_MIRROR_ENABLED:-1}"

_GITEE_MIRROR_ID=""
_GITEE_MIRROR_NAME=""
_GITEE_MIRROR_VERSION=""
_GITEE_MIRROR_FILE=""
_GITEE_MIRROR_SOURCE_URL=""
_GITEE_MIRROR_SHA256=""
_GITEE_MIRROR_SIZE=""
_GITEE_MIRROR_CHUNKS=""
_GITEE_MIRROR_CHUNK_SIZE=""
_GITEE_MIRROR_REPO1=""
_GITEE_MIRROR_REPO2=""
_GITEE_MIRROR_PARTS_REPO1=""
_GITEE_MIRROR_LATEST_VERSION=""
_GITEE_MIRROR_LATEST_FILE=""
_GITEE_MIRROR_LATEST_SHA256=""
_GITEE_MIRROR_LATEST_URL=""

_gitee_mirror_positive_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

gitee_mirror_id_is_valid() {
    case "$1" in
        ''|*[!a-z0-9-]*|--*) return 1 ;;
        *) return 0 ;;
    esac
}

gitee_mirror_raw_base() {
    printf 'https://gitee.com/%s/%s/raw/%s' \
        "$GITEE_MIRROR_OWNER" "$GITEE_MIRROR_REPO" "$GITEE_MIRROR_BRANCH"
}

gitee_mirror_direct_url() {
    local id="$1" version="$2" file="$3"

    gitee_mirror_id_is_valid "$id" || return 1
    case "$version" in ''|*'/'*|*'..'*) return 1 ;; esac
    case "$file" in ''|*'/'*|*'..'*) return 1 ;; esac
    printf '%s/%s/%s/%s' "$(gitee_mirror_raw_base)" "$id" "$version" "$file"
}

_gitee_mirror_parse_manifest() {
    local manifest="$1" line key value

    _GITEE_MIRROR_ID=""
    _GITEE_MIRROR_NAME=""
    _GITEE_MIRROR_VERSION=""
    _GITEE_MIRROR_FILE=""
    _GITEE_MIRROR_SOURCE_URL=""
    _GITEE_MIRROR_SHA256=""
    _GITEE_MIRROR_SIZE=""
    _GITEE_MIRROR_CHUNKS=""
    _GITEE_MIRROR_CHUNK_SIZE=""
    _GITEE_MIRROR_REPO1=""
    _GITEE_MIRROR_REPO2=""
    _GITEE_MIRROR_PARTS_REPO1=""

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        if [[ "$line" =~ ^([A-Za-z0-9_.-]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            case "$key" in
                id) _GITEE_MIRROR_ID="$value" ;;
                name) _GITEE_MIRROR_NAME="$value" ;;
                version) _GITEE_MIRROR_VERSION="$value" ;;
                file) _GITEE_MIRROR_FILE="$value" ;;
                source_url) _GITEE_MIRROR_SOURCE_URL="$value" ;;
                sha256) _GITEE_MIRROR_SHA256="$value" ;;
                size) _GITEE_MIRROR_SIZE="$value" ;;
                chunks) _GITEE_MIRROR_CHUNKS="$value" ;;
                chunk_size) _GITEE_MIRROR_CHUNK_SIZE="$value" ;;
                repo1) _GITEE_MIRROR_REPO1="$value" ;;
                repo2) _GITEE_MIRROR_REPO2="$value" ;;
                parts_repo1) _GITEE_MIRROR_PARTS_REPO1="$value" ;;
                *) continue ;;
            esac
        fi
    done < "$manifest"

    [ -n "$_GITEE_MIRROR_ID" ] && [ -n "$_GITEE_MIRROR_VERSION" ] && \
        [ -n "$_GITEE_MIRROR_FILE" ] && [ -n "$_GITEE_MIRROR_SHA256" ] && \
        [ -n "$_GITEE_MIRROR_SIZE" ] && [ -n "$_GITEE_MIRROR_CHUNKS" ] || return 1
    case "$_GITEE_MIRROR_SHA256" in
        ''|*[!0-9A-Fa-f]*) return 1 ;;
    esac
    [ "${#_GITEE_MIRROR_SHA256}" -eq 64 ] || return 1
    _gitee_mirror_positive_integer "$_GITEE_MIRROR_SIZE" || return 1
    _gitee_mirror_positive_integer "$_GITEE_MIRROR_CHUNKS" || return 1
    if [ "$_GITEE_MIRROR_CHUNKS" -gt 0 ]; then
        _gitee_mirror_positive_integer "${_GITEE_MIRROR_CHUNK_SIZE:-}" || return 1
        if [ -n "$_GITEE_MIRROR_REPO1" ] || [ -n "$_GITEE_MIRROR_REPO2" ] || \
            [ -n "$_GITEE_MIRROR_PARTS_REPO1" ]; then
            [ -n "$_GITEE_MIRROR_REPO1" ] && [ -n "$_GITEE_MIRROR_REPO2" ] && \
                _gitee_mirror_positive_integer "$_GITEE_MIRROR_PARTS_REPO1" || return 1
            case "$_GITEE_MIRROR_REPO1$_GITEE_MIRROR_REPO2" in
                *'/'*) return 1 ;;
            esac
        fi
    fi
}

_gitee_mirror_setting() {
    local value="$1" fallback="$2"
    if _gitee_mirror_positive_integer "$value"; then
        printf '%s' "$value"
    else
        printf '%s' "$fallback"
    fi
}

download_gitee_mirror_manifest() {
    local id="$1" output="$2"
    local manifest_url temp_file
    local connect_timeout max_time retries

    gitee_mirror_id_is_valid "$id" || return 1
    [ "$GITEE_MIRROR_ENABLED" = "1" ] || return 1
    manifest_url="$(gitee_mirror_raw_base)/$id/latest.txt"
    if declare -F download_policy_url_allowed >/dev/null 2>&1 && \
        ! download_policy_url_allowed "$manifest_url"; then
        return 1
    fi

    connect_timeout="$(_gitee_mirror_setting "${GITEE_MIRROR_CONNECT_TIMEOUT:-}" 10)"
    max_time="$(_gitee_mirror_setting "${GITEE_MIRROR_MAX_TIME:-}" 60)"
    retries="$(_gitee_mirror_setting "${GITEE_MIRROR_RETRIES:-}" 2)"
    temp_file="$(mktemp 2>/dev/null)" || return 1
    if ! curl --fail --location --silent --proto '=https' --proto-redir '=https' \
        --connect-timeout "$connect_timeout" --max-time "$max_time" \
        --retry "$retries" --retry-delay 1 --retry-all-errors \
        --max-filesize 2097152 \
        --output "$temp_file" "$manifest_url"; then
        rm -f -- "$temp_file"
        return 1
    fi
    if declare -F download_policy_response_is_safe >/dev/null 2>&1 && \
        ! download_policy_response_is_safe "$manifest_url" "$temp_file"; then
        rm -f -- "$temp_file"
        return 1
    fi
    if ! _gitee_mirror_parse_manifest "$temp_file"; then
        rm -f -- "$temp_file"
        return 1
    fi
    [ "$_GITEE_MIRROR_ID" = "$id" ] || {
        rm -f -- "$temp_file"
        return 1
    }
    mv -f -- "$temp_file" "$output" || {
        rm -f -- "$temp_file"
        return 1
    }
}

_gitee_mirror_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

_gitee_mirror_download_one() {
    local url="$1" output="$2" max_bytes="$3"
    local connect_timeout max_time retries
    local quiet="${GITEE_MIRROR_QUIET:-0}"
    local curl_options=()

    if declare -F download_policy_url_allowed >/dev/null 2>&1 && \
        ! download_policy_url_allowed "$url"; then
        return 1
    fi
    connect_timeout="$(_gitee_mirror_setting "${GITEE_MIRROR_CONNECT_TIMEOUT:-}" 10)"
    max_time="$(_gitee_mirror_setting "${GITEE_MIRROR_MAX_TIME:-}" 1200)"
    retries="$(_gitee_mirror_setting "${GITEE_MIRROR_RETRIES:-}" 2)"
    curl_options=(
        --fail --location
        --proto '=https' --proto-redir '=https'
        --connect-timeout "$connect_timeout" --max-time "$max_time"
        --retry "$retries" --retry-delay 1 --retry-connrefused
        --speed-limit 65536 --speed-time 60
        --max-filesize "$max_bytes"
    )
    if [ "$quiet" = "1" ]; then
        curl_options+=(--silent)
        if ! curl "${curl_options[@]}" --output "$output" "$url" 2>/dev/null; then
            return 1
        fi
    else
        curl_options+=(--progress-meter)
        if ! curl "${curl_options[@]}" --output "$output" "$url" \
            2> >(download_progress_filter "${GITEE_MIRROR_LABEL:-下载}" >&2); then
            return 1
        fi
    fi
    if declare -F download_policy_response_is_safe >/dev/null 2>&1 && \
        ! download_policy_response_is_safe "$url" "$output"; then
        return 1
    fi
}

download_gitee_mirror_file() {
    local id="$1" output="$2" expected_sha256="${3:-}" name="${4:-镜像文件}"
    local manifest manifest_file base_url file_url temp_file temp_dir part_name part_file
    local actual_sha256 index actual_size
    local GITEE_MIRROR_LABEL="$name"

    gitee_mirror_id_is_valid "$id" || {
        echo "$name 镜像标识无效。"
        return 1
    }
    manifest_file="$(mktemp 2>/dev/null)" || {
        echo "$name 无法创建临时清单。"
        return 1
    }
    if ! download_gitee_mirror_manifest "$id" "$manifest_file"; then
        rm -f -- "$manifest_file"
        echo "$name 镜像清单不可用，切换备用源。"
        return 1
    fi
    rm -f -- "$manifest_file"

    if [ -n "$expected_sha256" ]; then
        expected_sha256="$(printf '%s' "$expected_sha256" | tr '[:upper:]' '[:lower:]')"
        actual_sha256="$(printf '%s' "$_GITEE_MIRROR_SHA256" | tr '[:upper:]' '[:lower:]')"
        if [ "$actual_sha256" != "$expected_sha256" ]; then
            echo "$name 镜像清单校验值与当前固定版本不一致，切换备用源。"
            return 1
        fi
    fi
    case "$_GITEE_MIRROR_VERSION" in
        ''|*'/'*|*'..'*) echo "$name 镜像版本路径不安全。"; return 1 ;;
    esac
    case "$_GITEE_MIRROR_FILE" in
        ''|*'/'*|*'..'*) echo "$name 镜像文件名不安全。"; return 1 ;;
    esac

    base_url="$(gitee_mirror_raw_base)/$id/$_GITEE_MIRROR_VERSION"
    temp_file="$(mktemp "${output}.part.XXXXXX" 2>/dev/null)" || {
        echo "$name 无法创建临时下载文件。"
        return 1
    }
    rm -f -- "$temp_file"

    if [ "$_GITEE_MIRROR_CHUNKS" = "0" ]; then
        if [ "$_GITEE_MIRROR_SIZE" -gt "$GITEE_MIRROR_DIRECT_MAX_BYTES" ]; then
            echo "$name 镜像清单把小文件标记为直接文件，但体积超限。"
            return 1
        fi
        file_url="$base_url/$_GITEE_MIRROR_FILE"
        if ! _gitee_mirror_download_one "$file_url" "$temp_file" \
            "$_GITEE_MIRROR_SIZE"; then
            rm -f -- "$temp_file"
            echo "$name 镜像下载失败，切换备用源。"
            return 1
        fi
    else
        temp_dir="$(mktemp -d 2>/dev/null)" || {
            echo "$name 无法创建临时目录。"
            return 1
        }
        GITEE_MIRROR_QUIET=1
        echo "正在下载 $name..."
        index=1
        while [ "$index" -le "$_GITEE_MIRROR_CHUNKS" ]; do
            part_name="$(printf 'part.%04d' "$index")"
            part_file="$temp_dir/$part_name"
            part_repo="$GITEE_MIRROR_REPO"
            if [ -n "$_GITEE_MIRROR_REPO1" ] && [ -n "$_GITEE_MIRROR_REPO2" ] && \
                _gitee_mirror_positive_integer "$_GITEE_MIRROR_PARTS_REPO1"; then
                if [ "$index" -le "$_GITEE_MIRROR_PARTS_REPO1" ]; then
                    part_repo="$_GITEE_MIRROR_REPO1"
                else
                    part_repo="$_GITEE_MIRROR_REPO2"
                fi
            fi
            file_url="https://gitee.com/zliu9732-hub/$part_repo/raw/main/$id/$_GITEE_MIRROR_VERSION/$part_name"
            if ! _gitee_mirror_download_one "$file_url" "$part_file" \
                "$_GITEE_MIRROR_CHUNK_SIZE"; then
                rm -rf -- "$temp_dir"
                rm -f -- "$temp_file"
                echo "$name 镜像下载失败，切换备用源。"
                return 1
            fi
            index=$((index + 1))
        done
        index=1
        while [ "$index" -le "$_GITEE_MIRROR_CHUNKS" ]; do
            part_name="$(printf 'part.%04d' "$index")"
            cat "$temp_dir/$part_name" >> "$temp_file" || {
                rm -rf -- "$temp_dir"
                rm -f -- "$temp_file"
                return 1
            }
            index=$((index + 1))
        done
        rm -rf -- "$temp_dir"
    fi

    actual_size="$(wc -c < "$temp_file" | tr -d ' ')"
    if [ "$actual_size" != "$_GITEE_MIRROR_SIZE" ]; then
        rm -f -- "$temp_file"
        echo "$name 镜像大小校验失败，切换备用源。"
        return 1
    fi
    actual_sha256="$(_gitee_mirror_sha256 "$temp_file")" || {
        rm -f -- "$temp_file"
        echo "$name 缺少 SHA256 校验工具。"
        return 1
    }
    if [ "$actual_sha256" != "$(printf '%s' "$_GITEE_MIRROR_SHA256" | tr '[:upper:]' '[:lower:]')" ]; then
        rm -f -- "$temp_file"
        echo "$name 镜像 SHA256 校验失败，切换备用源。"
        return 1
    fi
    if ! mv -f -- "$temp_file" "$output"; then
        rm -f -- "$temp_file"
        return 1
    fi
    echo "$name 下载完成。"
    if declare -F log >/dev/null 2>&1; then
        log "Gitee 镜像下载成功: $name"
    fi
    return 0
}

resolve_latest_gitee_mirror() {
    local id="$1" asset_pattern="$2" name="${3:-镜像}"
    local manifest_file base_url

    gitee_mirror_id_is_valid "$id" || return 1
    manifest_file="$(mktemp 2>/dev/null)" || return 1
    if ! download_gitee_mirror_manifest "$id" "$manifest_file"; then
        rm -f -- "$manifest_file"
        echo "$name 镜像清单不可用，改用 GitHub 检测最新版本。"
        return 1
    fi
    rm -f -- "$manifest_file"
    case "$_GITEE_MIRROR_VERSION" in
        ''|*'/'*|*'..'*) return 1 ;;
    esac
    case "$_GITEE_MIRROR_FILE" in
        ''|*'/'*|*'..'*) return 1 ;;
    esac
    if [[ ! "$_GITEE_MIRROR_FILE" =~ $asset_pattern ]]; then
        echo "$name 镜像清单中的文件不匹配版本规则。"
        return 1
    fi
    _GITEE_MIRROR_LATEST_VERSION="$_GITEE_MIRROR_VERSION"
    _GITEE_MIRROR_LATEST_FILE="$_GITEE_MIRROR_FILE"
    _GITEE_MIRROR_LATEST_SHA256="$_GITEE_MIRROR_SHA256"
    if [ -n "$_GITEE_MIRROR_SOURCE_URL" ]; then
        _GITEE_MIRROR_LATEST_URL="$_GITEE_MIRROR_SOURCE_URL"
    else
        base_url="$(gitee_mirror_raw_base)/$id/$_GITEE_MIRROR_VERSION"
        _GITEE_MIRROR_LATEST_URL="$base_url/$_GITEE_MIRROR_FILE"
    fi
    echo "$name 镜像最新版本: $_GITEE_MIRROR_LATEST_VERSION"
}

download_with_gitee_mirror_fallback() {
    local id="$1" github_url="$2" sha256="$3" output="$4" name="${5:-文件}"

    if download_gitee_mirror_file "$id" "$output" "$sha256" "$name"; then
        return 0
    fi
    download_github_file "$github_url" "$output" "$sha256" "$name"
}

gitee_mirror_id_for_url() {
    case "$1" in
        *'/xXJSONDeruloXx/decky-lsfg-vk/releases/download/'*) printf '%s\n' lsfg ;;
        *'/xXJSONDeruloXx/Decky-Framegen/releases/download/'*) printf '%s\n' fsr4 ;;
        *'/SheffeyG/CheatDeck/releases/download/'*) printf '%s\n' cheatdeck ;;
        *'/YukiCoco/ToMoon/releases/download/'*) printf '%s\n' tomoon ;;
        *'/Ren-Amamiya-pixle/DeckRecall/releases/download/'*) printf '%s\n' deckrecall ;;
        *'/mubaraknumann/unifideck/releases/download/'*) printf '%s\n' unifideck ;;
        *'/panyiwei-home/Freedeck/releases/download/'*) printf '%s\n' freedeck ;;
        *'/PixelAddictUnlocked/allycenter/releases/download/'*) printf '%s\n' allycenter ;;
        *'/honjow/HueSync/releases/download/'*) printf '%s\n' huesync ;;
        *'/aarron-lee/LegionGoRemapper/releases/download/'*) printf '%s\n' legiongo-remapper ;;
        *'/aarron-lee/GpdControl/releases/download/'*) printf '%s\n' gpd-control ;;
        *'/Rayekkk/LeGo-Vibe-Control/releases/download/'*) printf '%s\n' lego-vibe ;;
        *'/Rodpad/LeGo2-Fan-Control/releases/download/'*) printf '%s\n' lego2-fan ;;
        *'/srsholmes/onexplayer-apex-bazzite-fixes/releases/download/'*) printf '%s\n' onexplayer-apex ;;
        *'/aarron-lee/SimpleDeckyTDP/releases/download/'*) printf '%s\n' simpledeckytdp ;;
        *'/SteamDeckHomebrew/decky-loader/releases/download/v3.2.6/'*) printf '%s\n' decky-loader-stable ;;
        *'/SteamDeckHomebrew/decky-loader/releases/download/v3.2.8-pre1/'*) printf '%s\n' decky-loader-prerelease ;;
        *'/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton'*) printf '%s\n' ge-proton ;;
        *) return 1 ;;
    esac
}
