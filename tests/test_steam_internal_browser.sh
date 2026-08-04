#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

curl() {
    local arg

    for arg in "$@"; do
        case "$arg" in
            *auth/token)
                printf '%s' "test-token"
                return 0
                ;;
            *execute_in_tab)
                printf '%s' "zhoukeer-steam-browser:ok"
                return 0
                ;;
        esac
    done
    return 1
}

output="$(open_steam_internal_browser_via_decky "https://account.battle.net/login")"
printf '%s\n' "$output" | grep -Fq '已用 Steam 内置浏览器打开' || \
    FAIL "Steam 内置浏览器打开未确认成功"

if bash "$PROJECT_ROOT/scripts/open_steam_internal_browser.sh" 2>/dev/null; then
    FAIL "open_steam_internal_browser.sh 缺少地址时仍返回成功"
fi

echo "PASS: Steam 内置浏览器打开测试通过"
