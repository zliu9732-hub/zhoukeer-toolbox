#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
WS_PID=""
trap 'rm -rf -- "$TMP_ROOT"; [ -n "${WS_PID:-}" ] && kill "$WS_PID" 2>/dev/null || true' EXIT
export ZHOUKEER_TEST_MODE=1

FAIL() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/env.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/decky_bundle.sh"

WS_PORT_FILE="$TMP_ROOT/ws-port"
python3 "$PROJECT_ROOT/tests/mock_decky_ws_server.py" "$WS_PORT_FILE" &
WS_PID=$!
for _ in $(seq 1 50); do
    [ -s "$WS_PORT_FILE" ] && break
    sleep 0.1
done
[ -s "$WS_PORT_FILE" ] || FAIL "mock Decky WebSocket 服务未启动"
DECKY_API_BASE="http://127.0.0.1:$(tr -d '\r\n' < "$WS_PORT_FILE")"

code="$(build_steam_artwork_javascript "test-artwork-marker" "[2503252332]" "1" "YWJj")"
printf '%s\n' "$code" | grep -Fq 'SteamClient.Apps.ClearCustomArtworkForApp' || \
    FAIL "Decky 封面 JS 缺少 ClearCustomArtworkForApp"
printf '%s\n' "$code" | grep -Fq 'SteamClient.Apps.SetCustomArtworkForApp' || \
    FAIL "Decky 封面 JS 缺少 SetCustomArtworkForApp"
printf '%s\n' "$code" | grep -Fq '2503252332' || \
    FAIL "Decky 封面 JS 未携带快捷方式 appid"
printf '%s\n' "$code" | grep -Fq 'SaveCustomLogoPosition' || \
    FAIL "Decky 封面 JS 缺少 logo 位置写入"

curl() {
    local arg

    for arg in "$@"; do
        case "$arg" in
            *auth/token)
                printf '%s' "test-token"
                return 0
                ;;
            *execute_in_tab)
                printf '%s' \
                    'zhoukeer-artwork-epic-header:ok zhoukeer-artwork-epic-capsule:ok ' \
                    'zhoukeer-artwork-epic-hero:ok zhoukeer-artwork-epic-logo:ok'
                return 0
                ;;
        esac
    done
    return 1
}

output="$(apply_steam_launcher_artwork_via_decky epic 2503252332)"
printf '%s\n' "$output" | grep -Fq '已通过 Decky 即时应用' || \
    FAIL "Decky 封面即时应用未确认成功"

# v2 旧 HTTP 接口仍保留回退：WebSocket 不可达时必须走 curl 通道。
DECKY_API_BASE="http://127.0.0.1:9"
output="$(apply_steam_launcher_artwork_via_decky epic 2503252332)"
printf '%s\n' "$output" | grep -Fq '已通过 Decky 即时应用' || \
    FAIL "Decky 旧版 HTTP 回退未确认成功"

# 兼容层走 Steam 官方接口，并在可识别该 appid 的 tab 中执行。
DECKY_API_BASE="http://127.0.0.1:$(tr -d '\r\n' < "$WS_PORT_FILE")"
compat_output="$(apply_steam_compat_via_decky 2503252332)"
printf '%s\n' "$compat_output" | grep -Fq '已通过 Steam 界面启用' || \
    FAIL "Decky 兼容层设置未确认成功"

SHORTCUTS="$TMP_ROOT/shortcuts.vdf"
python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" --shortcut-file "$SHORTCUTS" add \
    --name "Epic Games 启动器" --exe "$TMP_ROOT/launch-epic.sh" \
    --start-dir "$TMP_ROOT" >/dev/null
expected_appid="$(python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" \
    --shortcut-file "$SHORTCUTS" appid \
    --name "Epic Games 启动器" --exe "$TMP_ROOT/launch-epic.sh")"
found_appid="$(python3 "$PROJECT_ROOT/scripts/steam_shortcut.py" \
    --shortcut-file "$SHORTCUTS" find-appid --name "Epic Games 启动器")"
[ "$found_appid" = "$expected_appid" ] || {
    FAIL "find-appid 未返回 shortcuts.vdf 中的真实 appid"
}

export ZHOUKEER_SHORTCUT_FILE="$SHORTCUTS"
expected_signed_app_id="$expected_appid"
if [ "$expected_appid" -gt 2147483647 ]; then
    expected_signed_app_id=$((expected_appid - 4294967296))
fi
expected_game_id="$(python3 -c 'import sys; print((int(sys.argv[1]) << 32) | 0x02000000)' "$expected_appid")"
mkdir -p "$(dirname "$SHORTCUTS")/grid"
for check_id in "$expected_appid" "$expected_signed_app_id" "$expected_game_id"; do
    for artwork in "$check_id.jpg" "${check_id}p.jpg" "${check_id}_hero.jpg" \
        "${check_id}_logo.png" "${check_id}_icon.png" "${check_id}_background.jpg"; do
        : > "$(dirname "$SHORTCUTS")/grid/$artwork"
    done
done
verify_output="$(bash "$PROJECT_ROOT/scripts/apply_steam_artwork.sh" verify epic)"
printf '%s\n' "$verify_output" | grep -Fq "appid: $expected_appid" || \
    FAIL "verify 未输出 shortcuts.vdf 中的 appid"
printf '%s\n' "$verify_output" | grep -Fq "$expected_appid.jpg 存在" || \
    FAIL "verify 未确认封面文件已写入"
unset ZHOUKEER_SHORTCUT_FILE

if bash "$PROJECT_ROOT/scripts/apply_steam_artwork.sh" 2>/dev/null; then
    FAIL "apply_steam_artwork.sh 缺少目标时仍返回成功"
fi

echo "PASS: Steam 库封面 Decky API 即时应用测试通过"
