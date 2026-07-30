#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export HOME="$TMP_ROOT/home"
export XDG_STATE_HOME="$TMP_ROOT/state"
export ZHOUKEER_TEST_MODE=1
mkdir -p "$HOME"

fail() { echo "FAIL: $*" >&2; exit 1; }

# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/plugin_store.sh"
log() { return 0; }

PAYLOAD='decky-official-test-payload'
CALLS="$TMP_ROOT/calls"
MOCK_OFFICIAL_FAIL=0
MOCK_GHFAST_FAIL=0
DOMESTIC_MODE=fail

curl() {
    local output="" url=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) shift; output="${1:-}" ;;
            https://*) url="$1" ;;
        esac
        shift || true
    done
    printf '%s\n' "$url" >> "$CALLS"
    case "$url" in
        https://www.mhhf.com/*)
            if [ "$DOMESTIC_MODE" = "html" ]; then
                printf '<!doctype html><html>403</html>\n' > "$output"
                return 0
            fi
            return 22
            ;;
        https://ghfast.top/https://github.com/SteamDeckHomebrew/*)
            [ "$MOCK_GHFAST_FAIL" -eq 0 ] || return 28
            printf '%s' "$PAYLOAD" > "$output"
            ;;
        https://github.com/SteamDeckHomebrew/*|https://raw.githubusercontent.com/SteamDeckHomebrew/*)
            [ "$MOCK_OFFICIAL_FAIL" -eq 0 ] || return 28
            printf '%s' "$PAYLOAD" > "$output"
            ;;
        *) return 1 ;;
    esac
}

# 本测试只验证插件商城是否把官方 GitHub 文件交给统一下载器。固定排名
# 避免 curl 测速细节干扰调用顺序；统一排名本身由 test_github_download 覆盖。
get_ranked_github_sources() {
    local url="$1"
    case "$url" in
        https://github.com/*/releases/download/*)
            _GITHUB_SOURCES_RANKED="https://ghfast.top/
https://github.com"
            ;;
        *) _GITHUB_SOURCES_RANKED="https://github.com" ;;
    esac
    _GITHUB_RANKED_FOR_URL="$url"
    printf '%s' "$_GITHUB_SOURCES_RANKED"
}

printf '%s' "$PAYLOAD" > "$TMP_ROOT/expected"
EXPECTED_SHA256="$(calculate_decky_sha256 "$TMP_ROOT/expected")"

output="$(download_decky_component_with_fallback \
    'Decky PluginLoader' \
    "$DECKY_LOADER_URL" \
    "$DECKY_LOADER_OFFICIAL_URL" \
    "$EXPECTED_SHA256" \
    "$TMP_ROOT/PluginLoader")"
printf '%s\n' "$output" | grep -Fq '国内线路不可用，正在自动切换 Decky 官方国外线路' || \
    fail "国内源失败后没有提示自动切换官方源"
printf '%s\n' "$output" | grep -Fq '已通过 Decky 官方线路获取' || \
    fail "官方源成功后没有给出明确结果"
[ "$(sed -n '1p' "$CALLS")" = "$DECKY_LOADER_URL" ] || fail "未优先尝试国内 Loader"
[ "$(sed -n '2p' "$CALLS")" = "https://ghfast.top/$DECKY_LOADER_OFFICIAL_URL" ] || \
    fail "Loader 官方回退未先使用 ghfast"
cmp -s "$TMP_ROOT/expected" "$TMP_ROOT/PluginLoader" || fail "官方 Loader 下载结果不一致"

: > "$CALLS"
DOMESTIC_MODE=html
download_decky_component_with_fallback \
    'Decky PluginLoader' \
    "$DECKY_LOADER_URL" \
    "$DECKY_LOADER_OFFICIAL_URL" \
    "$EXPECTED_SHA256" \
    "$TMP_ROOT/PluginLoader-from-html" >/dev/null
[ "$(sed -n '2p' "$CALLS")" = "https://ghfast.top/$DECKY_LOADER_OFFICIAL_URL" ] || \
    fail "国内 HTML 错误页未触发 ghfast 官方回退"
cmp -s "$TMP_ROOT/expected" "$TMP_ROOT/PluginLoader-from-html" || fail "HTML 回退后的官方文件不一致"

: > "$CALLS"
DOMESTIC_MODE=fail
download_decky_component_with_fallback \
    'Decky systemd服务模板' \
    "$DECKY_SERVICE_URL" \
    "$DECKY_SERVICE_OFFICIAL_URL" \
    "$EXPECTED_SHA256" \
    "$TMP_ROOT/plugin_loader-release.service" >/dev/null
[ "$(sed -n '1p' "$CALLS")" = "$DECKY_SERVICE_URL" ] || fail "未优先尝试国内服务模板"
[ "$(sed -n '2p' "$CALLS")" = "$DECKY_SERVICE_OFFICIAL_URL" ] || fail "服务模板未回退 Decky 官方源"

: > "$CALLS"
MOCK_OFFICIAL_FAIL=1
MOCK_GHFAST_FAIL=1
if download_decky_component_with_fallback \
    'Decky PluginLoader' \
    "$DECKY_LOADER_URL" \
    "$DECKY_LOADER_OFFICIAL_URL" \
    "$EXPECTED_SHA256" \
    "$TMP_ROOT/failed.download" >/dev/null 2>&1; then
    fail "国内与官方源均失败时仍返回成功"
fi
[ ! -e "$TMP_ROOT/failed.download" ] || fail "双源失败后保留了未校验下载"

echo "PASS: 插件商城国内源失败自动切换 Decky 官方源，双源失败安全退出"
