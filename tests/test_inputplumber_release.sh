#!/bin/bash
set -euo pipefail
# Actual resolver and parser, mocked HTTP only. No Linux install commands run.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/modules/inputplumber_manual.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TMPDIR="$TEST_ROOT"
LOG_FILE="$TEST_ROOT/log" CALLS="$TEST_ROOT/calls"
MODE=limited
SHA="$(printf '%064d' 1)"
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
load_config() { :; }
ipu_message() { echo "$*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
curl() {
    local output='' effective=0 url='' max=0 secure=0 redir=0 timeout=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            --write-out) effective=1; shift 2 ;;
            --max-filesize) max="$2"; shift 2 ;;
            --proto) [ "$2" = '=https' ] && secure=1; shift 2 ;;
            --proto-redir) [ "$2" = '=https' ] && redir=1; shift 2 ;;
            --max-time) timeout="$2"; shift 2 ;;
            --connect-timeout|--retry|--retry-delay) shift 2 ;;
            https://*) url="$1"; shift ;;
            --*) shift ;;
            *) fail "Unexpected curl argument: $1" ;;
        esac
    done
    [ -n "$output" ] && [ "$secure:$redir" = 1:1 ] && [ "$max" -gt 0 ] && [ "$timeout" -gt 0 ] || fail 'Unbounded/insecure query'
    echo "$url" >> "$CALLS"
    case "$url" in
        https://api.github.com/repos/ShadowBlip/InputPlumber/releases/latest)
            [ "$MODE" = api ] || return 22
            printf '{"tag_name":"v0.90.0","draft":false,"prerelease":false,"assets":[{"name":"inputplumber-x86_64.tar.gz","digest":"sha256:%s","browser_download_url":"https://github.com/ShadowBlip/InputPlumber/releases/download/v0.90.0/inputplumber-x86_64.tar.gz"}]}' "$SHA" > "$output" ;;
        https://github.com/ShadowBlip/InputPlumber/releases/latest)
            [ "$max" = 2097152 ] && [ "$effective" = 1 ] || fail 'Page constraints missing'
            echo '<html>release</html>' > "$output"
            case "$MODE" in
                offline) return 22 ;;
                prerelease) printf '%s' https://github.com/ShadowBlip/InputPlumber/releases/tag/v0.90.0-rc1 ;;
                foreign) printf '%s' https://example.com/ShadowBlip/InputPlumber/releases/tag/v0.90.0 ;;
                *) printf '%s' https://github.com/ShadowBlip/InputPlumber/releases/tag/v0.90.0 ;;
            esac ;;
        https://github.com/ShadowBlip/InputPlumber/releases/expanded_assets/v0.90.0)
            [ "$max" = 2097152 ] && [ "$effective" = 1 ] || fail 'Asset page constraints missing'
            printf '<li><a href="/ShadowBlip/InputPlumber/releases/download/v0.90.0/inputplumber-x86_64.tar.gz">file</a>' > "$output"
            if [ "$MODE" != missing ]; then printf '<span>sha256:%s</span>' "$SHA" >> "$output"; fi
            if [ "$MODE" = ambiguous ]; then printf '<span>sha256:%064d</span>' 2 >> "$output"; fi
            echo '</li>' >> "$output"
            if [ "$MODE" = asset-foreign ]; then printf '%s' https://example.com/assets
            else printf '%s' "$url"; fi ;;
        *) fail "Unexpected query: $url" ;;
    esac
}
for MODE in limited api; do
    : > "$CALLS"
    ipu_latest_release > "$TEST_ROOT/output" || fail "Lookup failed: $MODE"
    [ "$IPU_LATEST_VERSION" = 0.90.0 ] && [ "$IPU_OFFICIAL_SHA256" = "$SHA" ] || fail 'Latest version/hash lost'
    [ "$IPU_OFFICIAL_URL" = https://github.com/ShadowBlip/InputPlumber/releases/download/v0.90.0/inputplumber-x86_64.tar.gz ] || fail 'Unexpected asset'
    if [ "$MODE" = api ]; then
        [ "$(wc -l < "$CALLS")" -eq 1 ] || fail 'Successful API unnecessarily retried'
    else
        [ "$(wc -l < "$CALLS")" -eq 3 ] || fail 'Website fallback missing'
        ! grep -Fq '获取失败' "$TEST_ROOT/output" || fail 'Recovered API error shown to user'
    fi
done
for MODE in offline prerelease foreign asset-foreign missing ambiguous; do
    if ipu_latest_release > "$TEST_ROOT/output"; then fail "Invalid metadata accepted: $MODE"; fi
    grep -Fq '当前手柄设置未修改' "$TEST_ROOT/output" || fail 'Safe failure message missing'
done
for path in "$TEST_ROOT"/tmp.*; do [ ! -e "$path" ] || fail 'Query workspace leaked'; done
python3 "$PROJECT_ROOT/tests/test_inputplumber_release.py"
echo 'PASS: API failure fallback, official stable page and SHA256, API preference, bounded HTTP and failure cleanup'
