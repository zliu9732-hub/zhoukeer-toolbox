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

if bash "$PROJECT_ROOT/scripts/apply_steam_artwork.sh" 2>/dev/null; then
    FAIL "apply_steam_artwork.sh 缺少目标时仍返回成功"
fi

echo "PASS: Steam 库封面 Decky API 即时应用测试通过"
