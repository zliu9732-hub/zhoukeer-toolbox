#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
    "ProtonDB Badges" \
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

javascript="$(build_decky_bundle_javascript "")"
assert_contains "$javascript" "https://plugins.deckbrew.xyz/plugins" "未使用Decky官方商店"
assert_contains "$javascript" "loader/get_plugins" "未读取Decky已安装插件"
assert_contains "$javascript" "utilities/install_plugins" "未调用Decky内置批量安装"
assert_contains "$javascript" "if(iv.get(n)===String(l.name))continue" "未跳过已是最新版的插件"
assert_contains "$javascript" "l.hash+\".zip\"" "未按Decky官方哈希构造发布包地址"
assert_contains "$javascript" "m+\":current\"" "未返回已是最新版状态"
assert_contains "$javascript" "m+\":queued:\"+rq.length" "未返回安装请求状态"

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

DECKY_SIMPLE_TDP_URL="http://unsafe.invalid/plugin.zip"
if build_custom_plugins_json "$TMP_ROOT/unsafe.json" >/dev/null 2>&1; then
    fail "非HTTPS插件地址不应被接受"
fi

DECKY_SIMPLE_TDP_URL=""
DECKY_SIMPLE_TDP_SHA256=""
DECKY_UNIFIDECK_URL=""
DECKY_UNIFIDECK_SHA256=""
CAPTURE_FILE="$TMP_ROOT/decky-request.json"

curl() {
    local data=""
    local target=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --data)
                shift
                data="${1:-}"
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
            printf '%s' '{"result":{"success":true,"result":"zhoukeer-decky-bundle-queued:queued:24"},"success":true}'
            ;;
        *) return 1 ;;
    esac
}

output="$(
    ZHOUKEER_ALLOW_NON_STEAMOS=1
    ZHOUKEER_AUTO_CONFIRM=1
    install_recommended_decky_plugins
)"
assert_contains "$output" "安装清单已交给Decky Loader" "整组安装未报告成功提交"
assert_contains "$(cat "$CAPTURE_FILE")" "utilities/install_plugins" "发送给Steam界面的代码未调用Decky安装器"
assert_contains "$(cat "$CAPTURE_FILE")" "X-Decky-Version" "发送代码未按Decky版本读取官方商店"

if grep -Eq 'unzip|extractall|homebrew/plugins' "$MODULE"; then
    fail "推荐整组安装不应绕过Decky自行解压插件"
fi

echo "PASS: Decky官方商店推荐插件整组安装测试通过"
