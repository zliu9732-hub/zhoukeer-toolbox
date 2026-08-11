#!/bin/bash

if [ -n "${ZHOUKEER_ENV_LOADED:-}" ]; then
    return 0
fi

ZHOUKEER_ENV_LOADED=1

SCRIPT_PATH="${BASH_SOURCE[0]}"
CORE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROJECT_ROOT="$(cd "$CORE_DIR/.." && pwd)"

TOOLBOX_VERSION="1.3.5"
TOOLBOX_NAME="Renkit"

CONFIG_FILE="$PROJECT_ROOT/config/settings.conf"
CONFIG_EXAMPLE_FILE="$PROJECT_ROOT/config/settings.example.conf"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
APP_DIR="${ZHOUKEER_APP_DIR:-$PROJECT_ROOT/apps}"
ASSET_DIR="$PROJECT_ROOT/assets"

ensure_runtime_dirs() {
    mkdir -p "$LOG_DIR" "$APP_DIR"
}

config_key_is_allowed() {
    case "$1" in
        TOOLBOX_NAME|DUAL_BOOT_TIMEOUT|GITHUB_RELEASE_PROXY|GITHUB_MIRRORS|GITHUB_PROBE_CONNECT_TIMEOUT|GITHUB_PROBE_MAX_TIME|GITHUB_CONNECT_TIMEOUT|GITHUB_MAX_TIME|GITHUB_RETRIES|GITHUB_MIN_SPEED_BYTES|GITHUB_MIN_SPEED_TIME|GITHUB_DOWNLOAD_PROXY|DECKY_LOADER_URL|DECKY_LOADER_SHA256|DECKY_SERVICE_URL|DECKY_SERVICE_SHA256|DECKY_LSFG_URL|DECKY_LSFG_SHA256|DECKY_FSR4_URL|DECKY_FSR4_SHA256|DECKY_CHEATDECK_URL|DECKY_CHEATDECK_SHA256|DECKY_TOMOON_URL|DECKY_TOMOON_SHA256|DECKY_DECKRECALL_URL|DECKY_DECKRECALL_SHA256|DECKY_SIMPLE_TDP_URL|DECKY_SIMPLE_TDP_VERSION|DECKY_SIMPLE_TDP_SHA256|DECKY_UNIFIDECK_URL|DECKY_UNIFIDECK_VERSION|DECKY_UNIFIDECK_SHA256|GE_PROTON_URL|GE_PROTON_VERSION|GE_PROTON_SHA256|DECKY_FREEDECK_URL|DECKY_FREEDECK_SHA256|DECKY_FREEDECK_VERSION|DECKY_LSFG_ZH_URL|DECKY_LSFG_ZH_SHA256|DECKY_FSR4_ZH_URL|DECKY_FSR4_ZH_SHA256|DECKY_GITEE_ARCHIVE_URL|DECKY_GITEE_ARCHIVE_SHA256|DECKY_GITEE_ARCHIVE_PREFIX|DECKY_DOWNLOAD_PROXY) return 0 ;;
        *) return 1 ;;
    esac
}

config_value_is_safe() {
    case "$1" in
        *'$('*|*'`'*|*';'*|*'&&'*|*'||'*|*'|'*|*'<'*|*'>'*) return 1 ;;
        *) return 0 ;;
    esac
}

load_config_file() {
    local file="$1" line key value
    [ -f "$file" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if ! config_key_is_allowed "$key"; then
                printf '忽略未支持的配置项：%s\n' "$key" >&2
                continue
            fi
            if ! config_value_is_safe "$value"; then
                printf '拒绝不安全的配置项：%s\n' "$key" >&2
                continue
            fi
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            printf -v "$key" '%s' "$value"
        else
            printf '忽略格式错误的配置行。\n' >&2
        fi
    done < "$file"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        load_config_file "$CONFIG_FILE"
    elif [ -f "$CONFIG_EXAMPLE_FILE" ]; then
        load_config_file "$CONFIG_EXAMPLE_FILE"
    fi

    # 仅 GitHub Release 使用此受控代理；其他 GitHub 内容走官方源。
    : "${GITHUB_RELEASE_PROXY:=https://gh.llkk.cc/}"
    # 额外镜像与 Release 代理一起参与实际文件测速，按吞吐排序后回退官方源。
    : "${GITHUB_MIRRORS:=https://ghproxy.net/ https://gh.api.99988866.xyz/ https://github.moeyy.xyz/ https://gh.llkk.cc/ https://mirror.ghproxy.com/ https://gh.ddlc.com/ https://gh-proxy.lanqier.me/}"
}

# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/download_policy.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/utils/github_download.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/utils/gitee_download.sh"
