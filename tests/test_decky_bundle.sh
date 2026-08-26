#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ZHOUKEER_TEST_MODE=1
MODULE="$PROJECT_ROOT/modules/decky_bundle.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local label="$3"

    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

# shellcheck disable=SC1090
source "$MODULE"

# 本测试只模拟旧版 HTTP 通道，避免 WebSocket 优先调用碰到真实 Decky。
DECKY_API_BASE="http://127.0.0.1:9"


for plugin in \
    "CSS Loader" \
    "vibrantDeck" \
    "Animation Changer" \
    "Audio Loader" \
    "SteamGridDB" \
    "PowerTools" \
    "Storage Cleaner" \
    "AutoFlatpaks" \
    "Bluetooth" \
    "Deck Settings" \
    "HLTB for Deck" \
    "PlayCount" \
    "TabMaster" \
    "Wine Cellar" \
    "Pause Games" \
    "Controller Tools" \
    "Volume Mixer" \
    "Battery Tracker" \
    "PlayTime" \
    "Free Loader" \
    "DeckMTP" \
    "MangoPeel"; do
    assert_contains "$DECKY_OFFICIAL_PLUGIN_NAMES" "\"$plugin\"" "官方推荐清单缺少 $plugin"
done

if printf '%s\n' "$DECKY_OFFICIAL_PLUGIN_NAMES" | grep -Fq 'Game Theme Music'; then
    fail "报错的 Game Theme Music 仍在官方推荐清单"
fi
if printf '%s\n' "$DECKY_OFFICIAL_PLUGIN_NAMES" | grep -Fq 'ProtonDB Badges'; then
    fail "已停用的 ProtonDB Badges 仍在官方推荐清单"
fi

javascript="$(build_decky_bundle_javascript "")"
assert_contains "$javascript" "https://plugins.deckbrew.xyz/plugins" "未使用Decky官方商店"
assert_contains "$javascript" "loader/get_plugins" "未读取Decky已安装插件"
assert_contains "$javascript" "utilities/install_plugins" "未调用Decky内置批量安装"
assert_contains "$javascript" "if(iv.get(n)===String(l.name))continue" "未跳过已是最新版的插件"
assert_contains "$javascript" "l.hash+\".zip\"" "未按Decky官方哈希构造发布包地址"
assert_contains "$javascript" "m+\":current\"" "未返回已是最新版状态"
assert_contains "$javascript" "m+\":installed:\"+rq.length" "未返回真实安装完成状态"
assert_contains "$javascript" "m+\":missing:\"+missing.length" "未返回安装后缺失状态"
assert_contains "$javascript" "attempt<30" "未在提交后轮询已安装插件"
assert_contains "$javascript" "fv.get(pg.name)!==String(pg.version)" "未核对插件最终版本"

single_javascript="$(build_decky_bundle_javascript "" '["SteamGridDB"]')"
assert_contains "$single_javascript" 'const on=["SteamGridDB"]' "单插件安装未限制为选中的官方插件"
grep -Fq 'install_single_official_plugin()' "$MODULE" || fail "缺少单插件安装入口"
grep -Fq 'install_single_official_plugin "$2"' "$MODULE" || fail "单插件安装命令未注册"

DECKY_SIMPLE_TDP_URL="https://example.invalid/SimpleDeckyTDP.zip"
DECKY_SIMPLE_TDP_VERSION="v1.0.4"
DECKY_SIMPLE_TDP_SHA256="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
DECKY_UNIFIDECK_URL="https://example.invalid/unifideck.zip"
DECKY_UNIFIDECK_VERSION="0.7.0"
DECKY_UNIFIDECK_SHA256="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
custom_file="$TMP_ROOT/custom.json"
build_custom_plugins_json "$custom_file"
custom_json="$(cat "$custom_file")"
assert_contains "$custom_json" '"name":"SimpleDeckyTDP"' "未生成SimpleDeckyTDP安装请求"
assert_contains "$custom_json" '"name":"Unifideck"' "未生成Unifideck安装请求"
assert_contains "$custom_json" "$DECKY_UNIFIDECK_SHA256" "非官方插件未携带SHA256"
assert_contains "$custom_json" '"name":"Freedeck"' "未生成Freedeck安装请求"
assert_contains "$custom_json" "$DECKY_FREEDECK_SHA256" "Freedeck 未固定 0.6 校验值"
assert_contains "$custom_json" 'gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror/raw/main/simpledeckytdp' "SimpleDeckyTDP 未使用 Gitee 镜像地址"
if printf '%s\n' "$custom_json" | grep -Fq 'Fantastic'; then
    fail "Fantastic 不应再进入会弹出 Steam 安装窗口的精选插件请求"
fi

DECKY_SIMPLE_TDP_URL="http://unsafe.invalid/plugin.zip"
DECKY_SIMPLE_TDP_MIRROR_URL="http://unsafe.invalid/plugin.zip"
if build_custom_plugins_json "$TMP_ROOT/unsafe.json" >/dev/null 2>&1; then
    fail "非HTTPS插件地址不应被接受"
fi

DECKY_SIMPLE_TDP_URL=""
DECKY_SIMPLE_TDP_SHA256=""
DECKY_SIMPLE_TDP_MIRROR_URL=""
DECKY_UNIFIDECK_URL=""
DECKY_UNIFIDECK_SHA256=""
DECKY_UNIFIDECK_MIRROR_URL=""
DECKY_FREEDECK_MIRROR_URL=""
CAPTURE_FILE="$TMP_ROOT/decky-request.json"

curl() {
    local data=""
    local target=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --data|--data-binary)
                shift
                case "${1:-}" in
                    @*) data="$(< "${1#@}")" ;;
                    *) data="${1:-}" ;;
                esac
                ;;
            http://*|https://*) target="$1" ;;
        esac
        shift || true
    done

    case "$target" in
        */auth/token)
            printf '%s' "test-token"
            ;;
        */methods/execute_in_tab)
            printf '%s' "$data" > "$CAPTURE_FILE"
            printf '%s' '{"result":{"success":true,"result":"zhoukeer-decky-bundle:installed:24"},"success":true}'
            ;;
        *) return 1 ;;
    esac
}

output="$(
    ZHOUKEER_ALLOW_NON_STEAMOS=1
    ZHOUKEER_AUTO_CONFIRM=1
    install_recommended_decky_plugins
)"
assert_contains "$output" "Decky 已确认所选插件全部安装完成" "整组安装未核对真实安装结果"
assert_contains "$(cat "$CAPTURE_FILE")" "utilities/install_plugins" "发送给Steam界面的代码未调用Decky安装器"
assert_contains "$(cat "$CAPTURE_FILE")" "X-Decky-Version" "发送代码未按Decky版本读取官方商店"

if grep -Eq 'unzip|extractall|homebrew/plugins' "$MODULE"; then
    fail "推荐整组安装不应绕过Decky自行解压插件"
fi

curl() {
    local target=""
    while [ "$#" -gt 0 ]; do
        case "$1" in http://*|https://*) target="$1" ;; esac
        shift || true
    done
    case "$target" in
        */auth/token) printf '%s' "test-token" ;;
        */methods/execute_in_tab)
            printf '%s' '{"result":{"success":true,"result":"zhoukeer-decky-bundle:missing:1"},"success":true}'
            ;;
        *) return 1 ;;
    esac
}
if missing_output="$(ZHOUKEER_ALLOW_NON_STEAMOS=1 ZHOUKEER_AUTO_CONFIRM=1 install_recommended_decky_plugins 2>&1)"; then
    fail "仍有插件未落盘时不应报告成功"
fi
assert_contains "$missing_output" "仍有插件未出现在已安装列表" "缺失插件没有给出真实失败提示"

echo "PASS: Decky官方商店推荐插件安装测试通过，Fantastic 已与精选安装器隔离"
