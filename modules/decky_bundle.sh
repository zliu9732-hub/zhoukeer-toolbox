#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/steam_accelerator.sh"

load_config

DECKY_API_BASE="${ZHOUKEER_DECKY_API_BASE:-http://127.0.0.1:1337}"
DECKY_STORE_URL="${DECKY_STORE_URL:-https://plugins.deckbrew.xyz/plugins}"
DECKY_ARTIFACT_BASE="${DECKY_ARTIFACT_BASE:-https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions}"
DECKY_BUNDLE_MARKER="zhoukeer-decky-bundle-queued"
DECKY_BUNDLE_TMP_DIR=""

# 这两款不在官方数据库中的插件固定使用作者 Release，避免旧安装保留的
# 配置继续把客户导向已退役的第三方下载地址。
DECKY_SIMPLE_TDP_URL="${ZHOUKEER_DECKY_SIMPLE_TDP_URL:-https://github.com/aarron-lee/SimpleDeckyTDP/releases/download/v1.0.5/SimpleDeckyTDP.zip}"
DECKY_SIMPLE_TDP_VERSION="${ZHOUKEER_DECKY_SIMPLE_TDP_VERSION:-v1.0.5}"
DECKY_SIMPLE_TDP_SHA256="${ZHOUKEER_DECKY_SIMPLE_TDP_SHA256:-ebf1c68147b6300ee17c2d7ea00a9cfe9ac1c78af78d364d9d306ac64a2cc057}"
DECKY_UNIFIDECK_URL="${ZHOUKEER_DECKY_UNIFIDECK_URL:-https://github.com/mubaraknumann/unifideck/releases/download/Release-0.7/unifideck.prod.v0.7.0.zip}"
DECKY_UNIFIDECK_VERSION="${ZHOUKEER_DECKY_UNIFIDECK_VERSION:-0.7.0}"
DECKY_UNIFIDECK_SHA256="${ZHOUKEER_DECKY_UNIFIDECK_SHA256:-4715b74d0033b8c1587040e90c1d19b925c7110c7723926605aa62128c4c03e0}"
DECKY_FREEDECK_URL="${ZHOUKEER_DECKY_FREEDECK_URL:-https://github.com/panyiwei-home/Freedeck/archive/refs/tags/0.6.zip}"
DECKY_FREEDECK_SHA256="${ZHOUKEER_DECKY_FREEDECK_SHA256:-1b42bc7ab15f5a0fee69f2c261340247359e55d83c48ee45f95851704217a7b6}"
DECKY_FREEDECK_VERSION="${ZHOUKEER_DECKY_FREEDECK_VERSION:-0.6}"

# Names must exactly match the official Decky store database.
DECKY_OFFICIAL_PLUGIN_NAMES='["CSS Loader","vibrantDeck","Animation Changer","Audio Loader","SteamGridDB","PowerTools","Storage Cleaner","AutoFlatpaks","Bluetooth","ProtonDB Badges","Deck Settings","HLTB for Deck","PlayCount","TabMaster","Wine Cellar","Pause Games","Controller Tools","Volume Mixer","Battery Tracker","PlayTime","Free Loader","DeckMTP","MangoPeel"]'

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
        echo "$name 的 GitHub Release 地址或SHA256配置无效，已停止。"
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

build_decky_bundle_javascript_legacy() {
    local custom_plugins="$1"
    local official_names="${2:-$DECKY_OFFICIAL_PLUGIN_NAMES}"

    printf '%s' "(function(){const m=$(json_quote "$DECKY_BUNDLE_MARKER");const on=$official_names;const c=[$custom_plugins];const su=$(json_quote "$DECKY_STORE_URL");const ab=$(json_quote "$DECKY_ARTIFACT_BASE");if(typeof DeckyBackend==="undefined"){console.error("no back");return m;}DeckyPluginLoader.updateVersion().then(function(v){return fetch(su,{headers:{"X-Decky-Version":v.current}});}).then(function(r){if(!r.ok)throw Error("http"+r.status);return r.json();}).then(function(s){var b=new Map(s.map(function(p){return[p.name,p];}));DeckyBackend.call("loader/get_plugins").then(function(i){var iv=new Map(i.map(function(p){return[p.name,String(p.version||"")];}));var rq=[];var p;for(var n of on){p=b.get(n);var l=p.versions&&p.versions[0];if(!l||!l.hash)continue;if(iv.get(n)===String(l.name))continue;rq.push({name:n,artifact:l.artifact||ab+"/"+l.hash+".zip",version:String(l.name),hash:l.hash,install_type:iv.has(n)?2:0});}for(var pg of c){if(iv.get(pg.name)===String(pg.version))continue;rq.push({name:pg.name,artifact:pg.artifact,version:String(pg.version),hash:pg.hash,install_type:iv.has(pg.name)?2:0});}if(rq.length)DeckyBackend.call("utilities/install_plugins",rq);});}).catch(function(e){console.error("zkeer:",e);});return m;})()"
}

build_decky_bundle_javascript() {
    local custom_plugins="$1"
    local official_names="${2:-$DECKY_OFFICIAL_PLUGIN_NAMES}"

    # Wait for Decky to compare versions and accept the request before returning
    # a marker. This prevents the terminal from reporting an unconfirmed install.
    printf '%s\n' \
        "(async function(){" \
        "const m=$(json_quote "$DECKY_BUNDLE_MARKER");const on=$official_names;const c=[$custom_plugins];" \
        "const su=$(json_quote "$DECKY_STORE_URL");const ab=$(json_quote "$DECKY_ARTIFACT_BASE");" \
        "try{if(typeof DeckyBackend===\"undefined\")throw Error(\"DeckyBackend unavailable\");" \
        "const v=await DeckyPluginLoader.updateVersion();const r=await fetch(su,{headers:{\"X-Decky-Version\":v.current}});" \
        "if(!r.ok)throw Error(\"http\"+r.status);const s=await r.json();" \
        "const b=new Map(s.map(function(p){return[p.name,p];}));const i=await DeckyBackend.call(\"loader/get_plugins\");" \
        "const iv=new Map(i.map(function(p){return[p.name,String(p.version||\"\")];}));const rq=[];let p;" \
        "for(const n of on){p=b.get(n);const l=p.versions&&p.versions[0];if(!l||!l.hash)continue;if(iv.get(n)===String(l.name))continue;" \
        "rq.push({name:n,artifact:l.artifact||ab+\"/\"+l.hash+\".zip\",version:String(l.name),hash:l.hash,install_type:iv.has(n)?2:0});}" \
        "for(const pg of c){if(iv.get(pg.name)===String(pg.version))continue;rq.push({name:pg.name,artifact:pg.artifact,version:String(pg.version),hash:pg.hash,install_type:iv.has(pg.name)?2:0});}" \
        "if(!rq.length)return m+\":current\";await DeckyBackend.call(\"utilities/install_plugins\",rq);return m+\":queued:\"+rq.length;" \
        "}catch(e){console.error(\"zkeer:\",e);return m+\":failed\";}})()"
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
            --max-time 90 \
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
    local plugin_count="${1:-23}"
    local include_custom="${2:-1}"

    echo "将从Decky官方商店读取 $plugin_count 个插件的最新版本，并交给Decky内置安装器。"
    if [ "$include_custom" = "1" ]; then
        echo "SimpleDeckyTDP和Unifideck使用作者 GitHub Release 加入安装队列。"
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
    local plugin_count="${DECKY_BUNDLE_PLUGIN_COUNT:-23}"
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
    # Steam/GitHub 加速非必需，下载慢时可去系统设置启用 Steamcommunity 302

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

    case "$response" in
        *"$DECKY_BUNDLE_MARKER:current"*)
            echo "所选插件已经全部是当前最新版，无需重复安装。"
            log "Decky推荐插件检查完成: 已是最新版"
            ;;
        *"$DECKY_BUNDLE_MARKER:queued:"*)
            echo "安装清单已交给Decky Loader。"
            echo "请在Steam界面的Decky确认窗口中核对清单并点击安装，后续下载和权限处理均由Decky完成。"
            log "Decky推荐插件安装请求已提交"
            ;;
        *)
            echo "Decky未能确认插件安装请求，未将其显示为成功。"
            echo "请确认游戏模式或大屏幕模式正在运行，并打开一次 Decky 菜单后重试。"
            return 1
            ;;
    esac

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
