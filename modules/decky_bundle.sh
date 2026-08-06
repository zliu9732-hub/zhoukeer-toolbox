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

# Decky 的认证令牌只能发送给本机服务，禁止通过环境变量改写目标地址。
DECKY_API_BASE="http://127.0.0.1:1337"
DECKY_STORE_URL="${DECKY_STORE_URL:-https://plugins.deckbrew.xyz/plugins}"
DECKY_ARTIFACT_BASE="${DECKY_ARTIFACT_BASE:-https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions}"
DECKY_BUNDLE_MARKER="zhoukeer-decky-bundle-queued"
DECKY_BUNDLE_TMP_DIR=""

# 这两款不在官方数据库中的插件固定使用作者 Release，避免旧安装保留的
# 配置继续把客户导向已退役的第三方下载地址。
DECKY_SIMPLE_TDP_URL="${ZHOUKEER_DECKY_SIMPLE_TDP_URL:-https://github.com/aarron-lee/SimpleDeckyTDP/releases/download/v1.0.5/SimpleDeckyTDP.zip}"
DECKY_SIMPLE_TDP_VERSION="${ZHOUKEER_DECKY_SIMPLE_TDP_VERSION:-v1.0.5}"
DECKY_SIMPLE_TDP_SHA256="${ZHOUKEER_DECKY_SIMPLE_TDP_SHA256:-ebf1c68147b6300ee17c2d7ea00a9cfe9ac1c78af78d364d9d306ac64a2cc057}"
DECKY_SIMPLE_TDP_MIRROR_URL="$(gitee_mirror_direct_url simpledeckytdp v1.0.5 SimpleDeckyTDP.zip)"
DECKY_UNIFIDECK_URL="${ZHOUKEER_DECKY_UNIFIDECK_URL:-https://github.com/mubaraknumann/unifideck/releases/download/Release-0.7.2/unifideck.prod.v0.7.2.zip}"
DECKY_UNIFIDECK_VERSION="${ZHOUKEER_DECKY_UNIFIDECK_VERSION:-0.7.2}"
DECKY_UNIFIDECK_SHA256="${ZHOUKEER_DECKY_UNIFIDECK_SHA256:-a313be924cabe15255d222742a402cd98cb510a35dfe4b2d06cf1e59366936de}"
DECKY_UNIFIDECK_MIRROR_URL="$(gitee_mirror_direct_url unifideck Release-0.7.2 unifideck.prod.v0.7.2.zip)"
DECKY_FREEDECK_URL="${ZHOUKEER_DECKY_FREEDECK_URL:-https://github.com/panyiwei-home/Freedeck/releases/download/0.6/freedeck.v.0.6.zip}"
DECKY_FREEDECK_SHA256="${ZHOUKEER_DECKY_FREEDECK_SHA256:-04329d07761c42cc481e97ddd4fc180fa51eb1d0388761424a8c90a18a822c62}"
DECKY_FREEDECK_VERSION="${ZHOUKEER_DECKY_FREEDECK_VERSION:-0.6}"
DECKY_FREEDECK_MIRROR_URL="$(gitee_mirror_direct_url freedeck 0.6 freedeck.v.0.6.zip)"

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
    download_policy_url_allowed "$1"
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
        "${DECKY_SIMPLE_TDP_MIRROR_URL:-$DECKY_SIMPLE_TDP_URL}" \
        "${DECKY_SIMPLE_TDP_SHA256:-}" || return 1
    append_custom_plugin_json "$output" \
        "Unifideck" \
        "${DECKY_UNIFIDECK_VERSION:-0.7.2}" \
        "${DECKY_UNIFIDECK_MIRROR_URL:-$DECKY_UNIFIDECK_URL}" \
        "${DECKY_UNIFIDECK_SHA256:-}" || return 1
    append_custom_plugin_json "$output" \
        "Freedeck" \
        "${DECKY_FREEDECK_VERSION:-0.6}" \
        "${DECKY_FREEDECK_MIRROR_URL:-$DECKY_FREEDECK_URL}" \
        "${DECKY_FREEDECK_SHA256:-}" || return 1
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
    local marker="${3:-$DECKY_BUNDLE_MARKER}"
    local max_time="${DECKY_EXECUTE_TIMEOUT:-90}"
    local tab
    local payload_file
    local response

    for tab in "SharedJSContext" "Steam Shared Context presented by Valve™" "Steam" "SP"; do
        payload_file="$(mktemp 2>/dev/null)" || return 1
        printf '{"tab":%s,"run_async":true,"code":%s}\n' \
            "$(json_quote "$tab")" "$(json_quote "$code")" > "$payload_file"
        if response="$(call_decky_execute_in_tab "$token" "$payload_file" \
            "$DECKY_API_BASE" "$marker" "$max_time")"; then
            rm -f -- "$payload_file"
            printf '%s\n' "$response"
            return 0
        fi
        rm -f -- "$payload_file"
    done
    return 1
}

call_decky_execute_in_tab() {
    local token="$1"
    local payload_file="$2"
    local base_url="$3"
    local marker="$4"
    local max_time="$5"
    local response

    # Decky v3 只通过 WebSocket 提供 execute_in_tab；v2 仍保留旧 HTTP 接口，继续作为回退。
    response="$(python3 "$PROJECT_ROOT/scripts/decky_ws_call.py" \
        --token "$token" \
        --payload-file "$payload_file" \
        --base-url "$base_url" \
        --timeout "$max_time" 2>/dev/null || true)"
    if [[ "$response" == *"$marker"* ]]; then
        printf '%s\n' "$response"
        return 0
    fi
    response="$(curl \
        --fail \
        --silent \
        --connect-timeout 5 \
        --max-time "$max_time" \
        --header "X-Decky-Auth: $token" \
        --header "Content-Type: application/json" \
        --data-binary "@$payload_file" \
        "$base_url/methods/execute_in_tab" 2>/dev/null || true)"
    if [[ "$response" == *"$marker"* ]]; then
        printf '%s\n' "$response"
        return 0
    fi
    return 1
}

find_decky_app_tab() {
    local token="$1" appids="$2" base_url="$3" max_time="$4"
    local tab status

    while IFS=$'\t' read -r tab status _ _; do
        [ "$status" = "true" ] || continue
        printf '%s\n' "$tab"
        return 0
    done < <(python3 "$PROJECT_ROOT/scripts/decky_probe.py" \
        --token "$token" \
        --appids "$appids" \
        --base-url "$base_url" \
        --timeout "$max_time" 2>/dev/null || true)
    return 1
}

decky_recognized_appids() {
    local token="$1" appids="$2" base_url="$3" max_time="$4"
    local tab status id

    while IFS=$'\t' read -r tab status id _; do
        [ "$status" = "true" ] || continue
        [ -n "$id" ] || continue
        printf '%s\n' "$id"
    done < <(python3 "$PROJECT_ROOT/scripts/decky_probe.py" \
        --token "$token" \
        --appids "$appids" \
        --base-url "$base_url" \
        --timeout "$max_time" 2>/dev/null || true)
}

build_steam_artwork_javascript() {
    local marker="$1" appids_json="$2" asset_type="$3" base64_data="$4"

    printf '%s\n' \
        "(async function(){" \
        "const m=$(json_quote "$marker");const ids=$appids_json;const b64=$(json_quote "$base64_data");" \
        "try{if(typeof SteamClient===\"undefined\"||!SteamClient.Apps)throw Error(\"SteamClient unavailable\");" \
        "let ok=0;for(const appId of ids){" \
        "if(SteamClient.Apps.ClearCustomArtworkForApp){try{await SteamClient.Apps.ClearCustomArtworkForApp(appId,$asset_type);}catch(e){}await new Promise(x=>setTimeout(x,300));}" \
        "await SteamClient.Apps.SetCustomArtworkForApp(appId,b64,\"png\",$asset_type);" \
        "if(SteamClient.Apps.ReportLibraryAssetCacheMiss){try{SteamClient.Apps.ReportLibraryAssetCacheMiss(appId,$asset_type);}catch(e){}}" \
        "if($asset_type===2){try{const ov=window.appStore&&window.appStore.GetAppOverviewByAppID?.(appId);if(ov&&window.appDetailsStore)await window.appDetailsStore.SaveCustomLogoPosition(ov,{pinnedPosition:\"BottomLeft\",nWidthPct:50,nHeightPct:50});}catch(e){}}" \
        "ok++;}return m+\":ok:\"+ok;" \
        "}catch(e){console.error(\"zkeer-artwork:\",e);return m+\":failed:\"+String(e&&e.message||e);}})()"
}

build_steam_compat_javascript() {
    local app_id="$1"

    printf '%s\n' \
        "(async function(){try{SteamClient.Apps.SpecifyCompatTool($app_id,\"proton_10\");return \"zhoukeer-compat-ok\";}catch(e){return \"zhoukeer-compat-fail:\"+String(e&&e.message||e);}})()"
}

apply_steam_compat_via_decky() {
    local app_ids="$*"
    local app_id token decky_tab code payload_file response
    local appids_csv recognized_ids
    local DECKY_EXECUTE_TIMEOUT="${DECKY_ARTWORK_TIMEOUT:-12}"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        echo "Decky 兼容层设置仅支持真实 SteamOS 环境。"
        return 1
    fi
    [ -n "$app_ids" ] || {
        echo "缺少 Steam 快捷方式 appid。"
        return 1
    }
    require_command curl || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    token="$(curl \
        --fail \
        --silent \
        --connect-timeout 3 \
        --max-time 10 \
        "$DECKY_API_BASE/auth/token" 2>/dev/null || true)"
    if [ -z "$token" ]; then
        echo "未检测到运行中的 Decky Loader。"
        return 1
    fi
    appids_csv="$(printf '%s' "$app_ids" | tr ' ' ',')"
    recognized_ids="$(decky_recognized_appids "$token" "$appids_csv" \
        "$DECKY_API_BASE" "$DECKY_EXECUTE_TIMEOUT" | sort -u | paste -sd' ' -)"
    if [ -n "$recognized_ids" ]; then
        echo "检测到 Steam 实际使用的 AppID：$recognized_ids"
        app_ids="$recognized_ids"
    fi
    decky_tab="$(find_decky_app_tab "$token" "$(printf '%s' "$app_ids" | tr ' ' ',')" \
        "$DECKY_API_BASE" "$DECKY_EXECUTE_TIMEOUT")" || {
        echo "未找到能识别该快捷方式的 Steam 界面上下文，请切换游戏模式后重试。"
        return 1
    }
    for app_id in $app_ids; do
        code="$(build_steam_compat_javascript "$app_id")"
        payload_file="$(mktemp 2>/dev/null)" || return 1
        printf '{"tab":%s,"run_async":true,"code":%s}\n' \
            "$(json_quote "$decky_tab")" "$(json_quote "$code")" > "$payload_file"
        if response="$(call_decky_execute_in_tab "$token" "$payload_file" \
            "$DECKY_API_BASE" "zhoukeer-compat" "$DECKY_EXECUTE_TIMEOUT")"; then
            rm -f -- "$payload_file"
            if [[ "$response" == *"zhoukeer-compat-ok"* ]]; then
                echo "已通过 Steam 界面启用 Proton 10.0-4 兼容层 (AppID $app_id)。"
                return 0
            fi
        else
            rm -f -- "$payload_file"
        fi
    done
    return 1
}

apply_steam_launcher_artwork_via_decky() {
    local target="$1"
    shift
    local asset_name appids_json appids_csv decky_tab token marker recognized_ids
    local entry type file_suffix asset_type file
    local DECKY_EXECUTE_TIMEOUT="${DECKY_ARTWORK_TIMEOUT:-12}"
    local payload_file tab payload_response artwork_ok failure_detail

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        echo "Decky 封面即时应用仅支持真实 SteamOS 环境。"
        return 1
    fi
    [ "$#" -gt 0 ] || {
        echo "缺少 Steam 快捷方式 appid。"
        return 1
    }
    require_command curl || return 1
    command -v python3 >/dev/null 2>&1 || {
        echo "缺少 python3 命令。"
        return 1
    }
    case "$target" in
        epic) asset_name="epic" ;;
        battlenet) asset_name="battlenet" ;;
        ubisoft|uplay) asset_name="ubisoft" ;;
        heihe) asset_name="heihe" ;;
        *) echo "未知启动器: $target"; return 1 ;;
    esac
    appids_json="[$(IFS=,; printf '%s' "$*")]"
    appids_csv="$(IFS=,; printf '%s' "$*")"

    token="$(curl \
        --fail \
        --silent \
        --connect-timeout 3 \
        --max-time 10 \
        "$DECKY_API_BASE/auth/token" 2>/dev/null || true)"
    if [ -z "$token" ]; then
        echo "未检测到运行中的 Decky Loader，无法即时应用 Steam 库封面。"
        return 1
    fi
    recognized_ids="$(decky_recognized_appids "$token" "$appids_csv" \
        "$DECKY_API_BASE" "$DECKY_EXECUTE_TIMEOUT" | sort -u | paste -sd, -)"
    if [ -n "$recognized_ids" ]; then
        appids_csv="$recognized_ids"
        appids_json="$(printf '%s' "$recognized_ids" | \
            awk -F, '{printf "["; for (i=1;i<=NF;i++) { if (i>1) printf ","; printf "%s", $i } print "]"}')"
        echo "检测到 Steam 实际使用的 AppID：$recognized_ids"
    fi
    decky_tab="$(find_decky_app_tab "$token" "$appids_csv" "$DECKY_API_BASE" "$DECKY_EXECUTE_TIMEOUT")" || true

    for entry in "header:-grid.png:3" "capsule:-portrait.png:0" "hero:-hero.png:1" "logo:.png:2"; do
        type="${entry%%:*}"
        rest="${entry#*:}"
        file_suffix="${rest%%:*}"
        asset_type="${rest##*:}"
        file="$PROJECT_ROOT/assets/game-launchers/${asset_name}${file_suffix}"
        [ -s "$file" ] || continue
        marker="zhoukeer-artwork-$target-$type"
        payload_file="$(mktemp 2>/dev/null)" || {
            echo "无法创建 Decky 封面请求文件。"
            return 1
        }
        artwork_ok=0
        for tab in ${decky_tab:+"$decky_tab"} "SharedJSContext" "Steam Shared Context presented by Valve™" "Steam" "SP"; do
            if ! python3 "$PROJECT_ROOT/scripts/build_steam_artwork_payload.py" \
                "$marker" "$appids_json" "$asset_type" "$file" "$tab" > "$payload_file"; then
                continue
            fi
            if payload_response="$(call_decky_execute_in_tab "$token" "$payload_file" \
                "$DECKY_API_BASE" "$marker" "$DECKY_EXECUTE_TIMEOUT")"; then
                if [[ "$payload_response" == *"$marker:ok"* ]]; then
                    artwork_ok=1
                    break
                fi
            fi
        done
        rm -f -- "$payload_file"
        if [ "$artwork_ok" -ne 1 ] || [[ "$payload_response" != *"$marker:ok"* ]]; then
            if [ "${ZHOUKEER_ARTWORK_DEBUG:-0}" = "1" ] && \
                [[ "$payload_response" == *"$marker:failed:"* ]]; then
                failure_detail="${payload_response##*"$marker:failed:"}"
                failure_detail="${failure_detail%%\"*}"
                echo "Decky $target $type 封面接口错误：$failure_detail" >&2
            fi
            echo "Decky 应用 $target $type 封面失败。"
            return 1
        fi
    done
    echo "$target Steam 库封面已通过 Decky 即时应用。"
}

build_steam_browser_javascript() {
    local marker="$1" url="$2"

    printf '%s' \
        "(function(){const m=$(json_quote "$marker");" \
        "try{if(typeof SteamClient===\"undefined\"||!SteamClient.Browser||!SteamClient.Browser.OpenUrl)throw Error(\"Browser API unavailable\");" \
        "SteamClient.Browser.OpenUrl($(json_quote "$url"));return m+\":ok\";" \
        "}catch(e){return m+\":failed\";}})()"
}

open_steam_internal_browser_via_decky() {
    local url="$1"
    local marker="zhoukeer-steam-browser"
    local code token response
    local DECKY_EXECUTE_TIMEOUT="${DECKY_BROWSER_TIMEOUT:-10}"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        echo "Steam 内置浏览器仅支持真实 SteamOS 环境。"
        return 1
    fi
    case "$url" in
        https://*) ;;
        *) echo "仅支持 https 地址。"; return 1 ;;
    esac
    require_command curl || return 1

    token="$(curl \
        --fail \
        --silent \
        --connect-timeout 3 \
        --max-time 10 \
        "$DECKY_API_BASE/auth/token" 2>/dev/null || true)"
    if [ -z "$token" ]; then
        echo "未检测到运行中的 Decky Loader，无法打开 Steam 内置浏览器。"
        return 1
    fi

    code="$(build_steam_browser_javascript "$marker" "$url")" || return 1
    response="$(call_decky_frontend "$code" "$token" "$marker")" || {
        echo "Decky 未确认浏览器窗口已打开。"
        return 1
    }
    [[ "$response" == *"$marker:ok"* ]] || {
        echo "Steam 内置浏览器打开失败。"
        return 1
    }
    echo "已用 Steam 内置浏览器打开：$url"
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
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" decky; then
        echo "插件组合安装已停止：准备检查未通过。"
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
        artwork)
            [ -n "${2:-}" ] || {
                echo "用法: $0 artwork <epic|battlenet|ubisoft> <appid>"
                exit 1
            }
            shift
            apply_steam_launcher_artwork_via_decky "$@"
            ;;
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
