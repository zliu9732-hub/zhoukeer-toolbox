#!/bin/bash

set -euo pipefail

# Only the installation decision flow runs. Network, platform detection,
# administrator access, services, downloads, and plugin writes are mocked.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# An unexpected external command must fail safely, even if a tested branch
# swallows its exit status. The final assertion also checks this call log.
GUARD_CALLS="$TEST_ROOT/guard.calls"
export GUARD_CALLS
mkdir -p "$TEST_ROOT/guards"
for blocked in curl wget sudo doas systemctl pacman flatpak steamos-readonly \
    udevadm ssh git inputplumber; do
    printf '%s\n' '#!/bin/bash' \
        'printf "%s\n" "$0 $*" >> "$GUARD_CALLS"' \
        'exit 125' > "$TEST_ROOT/guards/$blocked"
    chmod 700 "$TEST_ROOT/guards/$blocked"
done
PATH="$TEST_ROOT/guards:$PATH"
export PATH

# Keep the normal config parser, but never read this machine's saved settings.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
CONFIG_FILE="$TEST_ROOT/settings.conf"
CONFIG_EXAMPLE_FILE="$TEST_ROOT/settings.example.conf"
LOG_DIR="$TEST_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
APP_DIR="$TEST_ROOT/apps"
: > "$CONFIG_FILE"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/plugin_store.sh"

EXPECTED_URL='https://github.com/aarron-lee/SimpleDeckyTDP/releases/download/v1.0.7/SimpleDeckyTDP.zip'
EXPECTED_SHA='dae7cf43ec8936c07a94a08ac418be8d9e129744a54f3aa63d2b31222bc0ad38'
[ "$SIMPLEDECKYTDP_OFFICIAL_VERSION" = 1.0.7 ] || fail 'Test fixture version must be updated with the Chinese bundle'
[ "${SIMPLEDECKYTDP_OFFICIAL_URL:-}" = "$EXPECTED_URL" ] || fail 'Chinese bundle has no matching official URL'
[ "${SIMPLEDECKYTDP_OFFICIAL_SHA256:-}" = "$EXPECTED_SHA" ] || fail 'Chinese bundle has no matching official checksum'

run_case() (
    CASE_NAME="$1"
    MIRROR_RESULT="$2"
    OFFICIAL_RESULT="$3"
    CURRENT_RESULT="$4"
    CHINESE_RESULT="$5"
    EXPECT_SUCCESS="$6"
    RELOAD_AFTER="${7:-0}"
    LOCAL_IO_FAILURE="${8:-0}"
    DOWNLOAD_LOCAL_IO_FAILED=0
    CASE_ROOT="$TEST_ROOT/$CASE_NAME"
    CALLS="$CASE_ROOT/calls"
    OUTPUT="$CASE_ROOT/output"
    mkdir -p "$CASE_ROOT/plugins"
    : > "$CALLS"
    DECKY_PLUGIN_DIR="$CASE_ROOT/plugins"

    # Old saved package values caused the first attempt to reject a valid
    # v1.0.7 mirror. A future upstream version must not replace this bundle.
    DECKY_SIMPLE_TDP_URL='https://example.invalid/old-v1.0.4.zip'
    DECKY_SIMPLE_TDP_VERSION='v1.0.4'
    DECKY_SIMPLE_TDP_SHA256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    DECKY_SIMPLE_TDP_MIRROR_URL='https://example.invalid/stale-mirror.zip'
    detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
    require_existing_chimera_plugin_environment() { return 0; }
    simpledeckytdp_chinese_is_current() { return "$CURRENT_RESULT"; }
    feature_plugin_is_present() { return 1; }
    log() { printf 'log:%s\n' "$*" >> "$CASE_ROOT/log"; }
    cleanup_decky_tmp() { printf 'cleanup\n' >> "$CALLS"; }
    reload_decky_plugins() { printf 'reload\n' >> "$CALLS"; }
    install_decky_zip_from_mirror() {
        [ "$#" = 4 ] || fail "$CASE_NAME: unexpected mirror argument count"
        [ "$1" = SimpleDeckyTDP ] && [ "$2" = simpledeckytdp ] && \
            [ "$3" = "$EXPECTED_SHA" ] && [ "$4" = SimpleDeckyTDP ] || \
            fail "$CASE_NAME: stale config changed the first download"
        printf 'mirror\n' >> "$CALLS"
        DOWNLOAD_LOCAL_IO_FAILED="$LOCAL_IO_FAILURE"
        return "$MIRROR_RESULT"
    }
    install_decky_zip() {
        [ "$#" = 5 ] || fail "$CASE_NAME: unexpected official argument count"
        [ "$1" = SimpleDeckyTDP ] && [ "$2" = "$EXPECTED_URL" ] && \
            [ "$3" = "$EXPECTED_SHA" ] && [ "$4" = SimpleDeckyTDP ] && \
            [ "$5" = 0 ] || fail "$CASE_NAME: fallback changed the Chinese bundle version or reload mode"
        printf 'official\n' >> "$CALLS"
        return "$OFFICIAL_RESULT"
    }
    install_simpledeckytdp_chinese() {
        [ "$#" = 1 ] && [ "$1" = "$RELOAD_AFTER" ] || \
            fail "$CASE_NAME: Chinese overlay lost the requested reload mode"
        printf 'chinese\n' >> "$CALLS"
        return "$CHINESE_RESULT"
    }
    resolve_latest_github_release() {
        printf 'latest\n' >> "$CALLS"
        _LATEST_RELEASE_TAG=v99.0.0
        _LATEST_RELEASE_URL='https://example.invalid/future.zip'
        _LATEST_RELEASE_SHA256='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        return 0
    }
    install_configured_plugin() {
        printf 'configured\n' >> "$CALLS"
        resolve_latest_github_release
    }
    toolbox_sudo() {
        printf 'toolbox_sudo %s\n' "$*" >> "$GUARD_CALLS"
        return 125
    }

    if install_simpledeckytdp_zh_from_gitee "$RELOAD_AFTER" > "$OUTPUT" 2>&1; then
        [ "$EXPECT_SUCCESS" = 1 ] || fail "$CASE_NAME: failed installation reported success"
    else
        [ "$EXPECT_SUCCESS" = 0 ] || {
            cat "$OUTPUT" >&2
            fail "$CASE_NAME: installation unexpectedly failed"
        }
    fi
    if grep -Eq '^(latest|configured)$' "$CALLS"; then
        fail "$CASE_NAME: fixed Chinese bundle queried a newer upstream version"
    fi
    if [ "$CURRENT_RESULT" = 0 ]; then
        [ ! -s "$CALLS" ] || fail "$CASE_NAME: complete Chinese plugin was reinstalled"
        grep -Fq '无需重复安装' "$OUTPUT" || fail "$CASE_NAME: current plugin was not acknowledged"
        exit 0
    fi
    [ "$(grep -c '^mirror$' "$CALLS")" = 1 ] || fail "$CASE_NAME: mirror must be attempted once"
    if [ "$LOCAL_IO_FAILURE" = 1 ]; then
        ! grep -Eq '^(official|chinese|reload)$' "$CALLS" || \
            fail "$CASE_NAME: local write failure triggered another installation attempt"
        ! grep -Fq '安装成功' "$OUTPUT" || fail "$CASE_NAME: local write failure displayed success"
        exit 0
    fi
    if [ "$MIRROR_RESULT" = 0 ]; then
        ! grep -Fq 'official' "$CALLS" || fail "$CASE_NAME: successful mirror triggered fallback"
    else
        [ "$(grep -c '^official$' "$CALLS")" = 1 ] || fail "$CASE_NAME: matching official fallback missing"
        [ "$(sed -n '1p' "$CALLS")" = mirror ] || fail "$CASE_NAME: mirror was not preferred"
    fi
    if [ "$MIRROR_RESULT" != 0 ] && [ "$OFFICIAL_RESULT" != 0 ]; then
        ! grep -Fq 'chinese' "$CALLS" || fail "$CASE_NAME: overlay ran without an official runtime"
    else
        [ "$(grep -c '^chinese$' "$CALLS")" = 1 ] || fail "$CASE_NAME: Chinese overlay was not applied once"
    fi
    if [ "$EXPECT_SUCCESS" = 0 ]; then
        ! grep -Fq '安装成功' "$OUTPUT" || fail "$CASE_NAME: failure displayed a success message"
        ! grep -Fq 'reload' "$CALLS" || fail "$CASE_NAME: failed installation reloaded plugins"
    fi
)

run_case stale-config-mirror 0 1 1 0 1
run_case matching-fallback 1 0 1 0 1
run_case current-chinese 1 1 0 1 1
run_case both-downloads-fail 1 1 1 0 0
run_case mirror-overlay-fails 0 0 1 1 0
run_case fallback-overlay-fails 1 0 1 1 0
run_case mirror-reload 0 1 1 0 1 1
run_case fallback-reload 1 0 1 0 1 1
run_case local-write-fails 1 0 1 0 0 0 1
[ ! -s "$GUARD_CALLS" ] || {
    cat "$GUARD_CALLS" >&2
    fail 'A real network, administrator, or system command was attempted'
}
printf '%s\n' 'PASS: SimpleDeckyTDP 中文安装固定版本与校验值、国内优先、备用失败处理和已安装跳过均通过模拟测试'
