#!/bin/bash
# The test uses local files and simulates a root-owned staging directory.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_ROOT="$(cd -P "$TEST_ROOT" && pwd)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1 DECKY_PLUGIN_DIR="$TEST_ROOT/homebrew/plugins"
source "$ROOT/modules/plugin_store.sh"
IS_STEAMOS=1 IS_CHIMERAOS=0
mkdir -p "$DECKY_PLUGIN_DIR/Mako" "$TEST_ROOT/source"
fail() { echo "FAIL: $*" >&2; exit 1; }
log() { :; }
python3() {
    if [[ "${3:-}" == "$TEST_ROOT/homebrew"/.renkit-plugin-install.*/new ]] &&
       [ "${MOCK_STAGE_AUTHORIZED:-0}" != 1 ]; then
        echo 'Mocked denial of unprivileged reads from a private staging directory' >&2
        return 77
    fi
    command python3 "$@"
}
toolbox_sudo() {
    case "$1" in
        mktemp|cp|rm|mv) "$@" ;;
        python3)
            [[ "$2:$3" = '-I:-' && "$4" == "$TEST_ROOT/homebrew"/.renkit-plugin-install.*/new ]] ||
                fail 'Privileged verification escaped the staged plugin'
            echo read >> "$TEST_ROOT/admin-reads"
            shift
            MOCK_STAGE_AUTHORIZED=1 python3 "$@" ;;
        *) fail "Unexpected privileged command $1" ;;
    esac
}
if [ "$#" -gt 0 ]; then
    [ "$(calculate_decky_sha256 "$1")" = "$DECKY_LSFG_MAKO_SHA256" ] ||
        fail 'Supplied MAKO ZIP does not match the official hash'
    unzip -q "$1" -d "$TEST_ROOT/source"
else
    mkdir -p "$TEST_ROOT/source/Mako/"{bin,dist}
    printf '{"name":"MAKO - Frame Generation"}\n' > "$TEST_ROOT/source/Mako/plugin.json"
    printf '{"version":"%s"}\n' "$LSFG_MAKO_VERSION" > "$TEST_ROOT/source/Mako/package.json"
    printf 'GPL fixture\n' > "$TEST_ROOT/source/Mako/LICENSE.md"
    printf 'frontend fixture\n' > "$TEST_ROOT/source/Mako/dist/index.js"
    printf 'renderer fixture\n' > "$TEST_ROOT/source/Mako/bin/MAKO-Renderer-v5.0.0-linux.tar.xz"
    LSFG_MAKO_INDEX_SHA256="$(calculate_decky_sha256 "$TEST_ROOT/source/Mako/dist/index.js")"
fi
echo old > "$DECKY_PLUGIN_DIR/Mako/old-marker"
PLUGIN_NEEDS_SUDO=1 install_tree_atomically "$TEST_ROOT/source/Mako" "$DECKY_PLUGIN_DIR" Mako verify_mako_directory ||
    fail 'Valid package was rejected in private staging'
[ -s "$TEST_ROOT/admin-reads" ] || fail 'MAKO verification did not use the existing authorization'
mako_official_is_current "$DECKY_PLUGIN_DIR" || fail 'Installed package failed verification'
[ ! -e "$DECKY_PLUGIN_DIR/Mako/old-marker" ] || fail 'Old files remained in the installed plugin'
printf 'bad frontend\n' > "$TEST_ROOT/source/Mako/dist/index.js"
if PLUGIN_NEEDS_SUDO=1 install_tree_atomically "$TEST_ROOT/source/Mako" "$DECKY_PLUGIN_DIR" Mako verify_mako_directory >"$TEST_ROOT/failure" 2>&1; then
    fail 'Modified frontend was accepted'
fi
grep -Fq '插件界面文件校验不一致' "$TEST_ROOT/failure" || fail 'No specific failure reason'
mako_official_is_current "$DECKY_PLUGIN_DIR" || fail 'Rejected package changed the installed plugin'
echo 'PASS: MAKO staging uses existing authorization, validates the original ZIP, and preserves the installed tree on failure'
