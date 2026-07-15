#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

load_config

DECKY_API_BASE="${ZHOUKEER_DECKY_API_BASE:-http://127.0.0.1:1337}"
DECKY_STORE_URL="${DECKY_STORE_URL:-https://plugins.deckbrew.xyz/plugins}"
DECKY_ARTIFACT_BASE="${DECKY_ARTIFACT_BASE:-https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions}"
DECKY_BUNDLE_MARKER="zhoukeer-decky-bundle-queued"
DECKY_BUNDLE_TMP_DIR=""

# Names must exactly match the official Decky store database.
DECKY_OFFICIAL_PLUGIN_NAMES='["CSS Loader","vibrantDeck","Animation Changer","Audio Loader","SteamGridDB","PowerTools","Storage Cleaner","AutoFlatpaks","Bluetooth","ProtonDB Badges","Deck Settings","HLTB for Deck","PlayCount","TabMaster","Game Theme Music","Wine Cellar","Pause Games","Controller Tools","Volume Mixer","Battery Tracker","PlayTime","Free Loader","DeckMTP","MangoPeel"]'

json_quote() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '"%s"' "$value"
}

valid_https_url() {
    case "$1" in
        https://* ) return 0 ;;
        * ) return 1 ;;
    esac
}

valid_sha256() {
    [[ "$1" =~ ^[0-9A-Fa-f]{64}$ ]]
}

append_custom_plugin_json() {
    local output="$1"
    local name="$2"
    local version="$3"
    local url="$4"
    local sha256="$5"
    local separator=""

    [ -n "$url" ] || return 0
    if ! valid_https_url "$url" || ! valid_sha256 "$sha256"; then
        echo "$name 的123云盘地址或SHA256配置无效，已停止。"
        return 1
    fi
    [ ! -s "$output" ] || separator=","
    printf '%s{"name":%s,"version":%s,"artifact":%s,"hash":%s}' \
        "$separator" \
        "$(json_quote "$name")" \
        "$(json_quote "$version")" \
        "$(json_quote "$url")" \
        "$(json_quote "$sha256")" >> "$output"
}

cleanup_decky_bundle_tmp() {
    if [ -n "$DECKY_BUNDLE_TMP_DIR" ] && [ -d "$DECKY_BUNDLE_TMP_DIR" ]; then
        rm -rf -- "$DECKY_BUNDLE_TMP_DIR"
    fi
    DECKY_BUNDLE_TMP_DIR=""
}

build_custom_plugins_json() {
    local output="$1"

    : > "$output"
    append_custom_plugin_json "$output" \
        "SimpleDeckyTDP" \
        "${DECKY_SIMPLE_TDP_VERSION:-v1.0.4}" \
        "${DECKY_SIMPLE_TDP_URL:-}" \
        "${DECKY_SIMPLE_TDP_SHA256:-}" || return 1
    append_custom_plugin_json "$output" \
        "Unifideck" \
        "${DECKY_UNIFIDECK_VERSION:-0.7.0}" \
        "${DECKY_UNIFIDECK_URL:-}" \
        "${DECKY_UNIFIDECK_SHA256:-}" || return 1
}

build_decky_bundle_javascript() {
    local custom_plugins="$1"
    local official_names="${2:-$DECKY_OFFICIAL_PLUGIN_NAMES}"

    printf '%s' "(async()=>{const marker=$(json_quote "$DECKY_BUNDLE_MARKER");const officialNames=$official_names;const custom=[$custom_plugins];const storeUrl=$(json_quote "$DECKY_STORE_URL");const artifactBase=$(json_quote "$DECKY_ARTIFACT_BASE");if(typeof DeckyBackend==='undefined')throw new Error('Decky frontend is not ready');const response=await fetch(storeUrl,{headers:{'X-Decky-Version':(await DeckyPluginLoader.updateVersion()).current}});if(!response.ok)throw new Error('Decky store HTTP '+response.status);const store=await response.json();const byName=new Map(store.map((plugin)=>[plugin.name,plugin]));const missing=officialNames.filter((name)=>!byName.has(name));if(missing.length)throw new Error('Missing official plugins: '+missing.join(', '));const installed=await DeckyBackend.call('loader/get_plugins');const installedVersions=new Map(installed.map((plugin)=>[plugin.name,String(plugin.version||'')]));const requests=[];for(const name of officialNames){const plugin=byName.get(name);const latest=plugin.versions&&plugin.versions[0];if(!latest||!latest.hash)throw new Error('No release for '+name);if(installedVersions.get(name)===String(latest.name))continue;requests.push({name,artifact:latest.artifact||artifactBase+'/'+latest.hash+'.zip',version:String(latest.name),hash:latest.hash,install_type:installedVersions.has(name)?2:0});}for(const plugin of custom){if(installedVersions.get(plugin.name)===String(plugin.version))continue;requests.push({name:plugin.name,artifact:plugin.artifact,version:String(plugin.version),hash:plugin.hash,install_type:installedVersions.has(plugin.name)?2:0});}if(!requests.length)return marker+':current';await DeckyBackend.call('utilities/install_plugins',requests);return marker+':'+requests.length;})()"
}

call_decky_frontend() {
    local code="$1"
    local token="$2"
    local tab
    local payload
    local response

    for tab in "SharedJSContext" "Steam Shared Context presented by Valve™" "Steam" "SP"; do
        payload="{\"tab\":$(json_quote "$tab"),\"run_async\":true,\"code\":$(json_quote "$code")}"
        response="$(curl \
            --fail \
            --silent \
            --show-error \
            --connect-timeout 5 \
            --max-time 45 \
            --header "X-Decky-Auth: $token" \
            --header "Content-Type: application/json" \
            --data "$payload" \
            "$DECKY_API_BASE/methods/execute_in_tab" 2>/dev/null || true)"
        if [[ "$response" == *"$DECKY_BUNDLE_MARKER"* ]]; then
            printf '%s\n' "$response"
            return 0
        fi
    done
    return 1
}

confirm_bundle_install() {
    local plugin_count="${1:-24}"
    local include_custom="${2:-1}"

    echo "将从Decky官方商店读取 $plugin_count 个插件的最新版本，并交给Decky内置安装器。"
    if [ "$include_custom" = "1" ]; then
        echo "SimpleDeckyTDP和Unifideck仅在已配置123云盘成品ZIP时加入。"
    fi
    echo "PowerTools与SimpleDeckyTDP功能有重叠，请安装后只保留一套性能参数控制。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    local answer
    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

install_recommended_decky_plugins() {
    local tmp_dir
    local custom_file
    local custom_plugins
    local token
    local code
    local response
    local official_names="${DECKY_BUNDLE_OFFICIAL_NAMES_JSON:-$DECKY_OFFICIAL_PLUGIN_NAMES}"
    local plugin_count="${DECKY_BUNDLE_PLUGIN_COUNT:-24}"
    local include_custom="${DECKY_BUNDLE_INCLUDE_CUSTOM:-1}"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "${ZHOUKEER_ALLOW_NON_STEAMOS:-0}" != "1" ]; then
        echo "推荐插件整组安装仅支持真实SteamOS环境。"
        return 1
    fi
    require_command curl || return 1
    confirm_bundle_install "$plugin_count" "$include_custom" || {
        echo "已取消推荐插件安装。"
        return 0
    }

    token="$(curl \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 3 \
        --max-time 10 \
        "$DECKY_API_BASE/auth/token" 2>/dev/null || true)"
    if [ -z "$token" ]; then
        echo "未检测到正在运行的Decky Loader。"
        echo "请先安装或更新Decky Loader，并确认Steam处于游戏模式或大屏幕模式。"
        return 1
    fi

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_BUNDLE_TMP_DIR="$tmp_dir"
    custom_file="$tmp_dir/custom.json"
    trap cleanup_decky_bundle_tmp EXIT INT TERM
    if [ "$include_custom" = "1" ]; then
        build_custom_plugins_json "$custom_file" || return 1
        custom_plugins="$(cat "$custom_file")"
    else
        custom_plugins=""
    fi
    code="$(build_decky_bundle_javascript "$custom_plugins" "$official_names")"

    response="$(call_decky_frontend "$code" "$token")" || {
        echo "Decky服务已运行，但没有找到可接收安装请求的Steam界面。"
        echo "请先进入游戏模式或Steam大屏幕模式，打开一次Decky菜单后再重试。"
        return 1
    }

    if [[ "$response" == *"$DECKY_BUNDLE_MARKER:current"* ]]; then
        echo "所选插件已经全部是当前最新版，无需重复安装。"
        log "Decky推荐插件检查完成: 已是最新版"
    else
        echo "安装清单已交给Decky Loader。"
        echo "请在Steam界面的Decky确认窗口中核对清单并点击安装，后续下载和权限处理均由Decky完成。"
        log "Decky推荐插件安装请求已提交"
    fi

    cleanup_decky_bundle_tmp
    trap - EXIT INT TERM
}

install_single_official_plugin() {
    local plugin_name="${1:-}"

    if [ -z "$plugin_name" ] || ! printf '%s\n' "$DECKY_OFFICIAL_PLUGIN_NAMES" | grep -Fq "\"$plugin_name\""; then
        echo "未找到该官方插件：$plugin_name"
        return 1
    fi

    DECKY_BUNDLE_OFFICIAL_NAMES_JSON="[$(json_quote "$plugin_name")]"
    DECKY_BUNDLE_PLUGIN_COUNT=1
    DECKY_BUNDLE_INCLUDE_CUSTOM=0
    install_recommended_decky_plugins
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-install}" in
        install) install_recommended_decky_plugins ;;
        plugin)
            [ -n "${2:-}" ] || {
                echo "用法: $0 plugin 插件名称"
                exit 1
            }
            install_single_official_plugin "$2"
            ;;
        print-js)
            tmp_file="$(mktemp)" || exit 1
            trap 'rm -f -- "$tmp_file"' EXIT
            build_custom_plugins_json "$tmp_file" || exit 1
            build_decky_bundle_javascript "$(cat "$tmp_file")"
            ;;
        *) echo "未知Decky推荐插件操作: $1"; exit 1 ;;
    esac
fi
