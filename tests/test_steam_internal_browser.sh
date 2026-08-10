#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1

FAIL() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/env.sh"
# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/decky_bundle.sh"

code="$(build_steam_browser_javascript "test-browser-marker" "https://account.battle.net/login")"
printf '%s\n' "$code" | grep -Fq 'SteamClient.Browser.OpenUrl' || \
    FAIL "Steam 内置浏览器 JS 缺少 OpenUrl"
printf '%s\n' "$code" | grep -Fq 'https://account.battle.net/login' || \
    FAIL "Steam 内置浏览器 JS 缺少目标地址"

FAKE_STEAM="$TMP_ROOT/fake-steam"
FAKE_STEAM_LOG="$TMP_ROOT/steam-url.log"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$FAKE_STEAM_LOG"\n' > "$FAKE_STEAM"
chmod +x "$FAKE_STEAM"
export ZHOUKEER_STEAM_BIN="$FAKE_STEAM"
export FAKE_STEAM_LOG="$FAKE_STEAM_LOG"
output="$(bash "$PROJECT_ROOT/scripts/open_steam_internal_browser.sh" \
    "https://account.battle.net/login")"
grep -Fq 'steam://openurl/https://account.battle.net/login' "$FAKE_STEAM_LOG" || \
    FAIL "未使用 Steam 自带 openurl 协议打开内置浏览器"
printf '%s\n' "$output" | grep -Fq '已用 Steam 内置浏览器打开' || \
    FAIL "Steam 内置浏览器打开未确认成功"

if bash "$PROJECT_ROOT/scripts/open_steam_internal_browser.sh" 2>/dev/null; then
    FAIL "open_steam_internal_browser.sh 缺少地址时仍返回成功"
fi

echo "PASS: Steam 内置浏览器打开测试通过"
