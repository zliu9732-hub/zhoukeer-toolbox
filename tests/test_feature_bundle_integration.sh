#!/bin/bash
# Actual combo dispatch, unzip, atomic copy and final status. OS/network actions
# are mocked; an optional verified upstream ZIP is inspected as bytes only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_ROOT="$(cd -P -- "$TEST_ROOT" && pwd)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" ZHOUKEER_APP_DIR="$TEST_ROOT/apps" ZHOUKEER_TEST_MODE=1
export DECKY_PLUGIN_DIR="$HOME/homebrew/plugins"
mkdir -p "$DECKY_PLUGIN_DIR" "$TEST_ROOT/runtime/scripts" "$TEST_ROOT/runtime/data"
cp "$ROOT/scripts/deckygcm_package.py" "$TEST_ROOT/runtime/scripts/"
python3 - "$ROOT" "$TEST_ROOT" "${1:-}" <<'PY'
from pathlib import Path
import hashlib, json, shutil, sys, zipfile
repo, base = map(Path, sys.argv[1:3])
output = base / 'gcm.zip'
if sys.argv[3]:
    archive = Path(sys.argv[3])
    inventory = json.loads((repo / 'data/deckygcm_files.json').read_text())
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == inventory['sha256']
    shutil.copyfile(archive, output)
else:
    files = {'plugin.json': b'{"name":"DeckyGCM"}', 'package.json': b'{"version":"1.0.1"}',
             'main.py': b'# fixture, never executed', 'dist/index.js': b'fixture', 'README.md': b'original readme',
             'LICENSE': b'license fixture', 'py_modules/_gcm_core/auth.pyc': b'fixture bytecode, never executed'}
    with zipfile.ZipFile(output, 'w') as archive:
        for name, value in files.items(): archive.writestr('DeckyGCM/' + name, value)
    inventory = {'version': '1.0.1', 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                 'files': {name: hashlib.sha256(value).hexdigest() for name, value in files.items()}}
(base / 'runtime/data/deckygcm_files.json').write_text(json.dumps(inventory))
PY
source "$ROOT/modules/plugin_store.sh"
PROJECT_ROOT="$TEST_ROOT/runtime"
LOG_FILE="$TEST_ROOT/install.log"
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; IS_DESKTOP_LINUX=0; }
detect_platform
resolve_plugin_latest() { :; }
refresh_framegen_catalog() { :; }
load_framegen_cached_versions() { :; }
lsfg_v2_is_current() { return 1; }
ensure_plugin_store_ready() { :; }
select_lsfg_variant() { LSFG_INSTALL_VARIANT=legacy; }
select_feature_plugin_cleanup() { FEATURE_PLUGIN_CLEANUP=keep; }
OPTIONAL_TOOLS=skip
select_feature_trainer_tools() { FEATURE_TRAINER_TOOLS="$OPTIONAL_TOOLS"; }
refresh_feature_usage_guides() { :; }
write_flingtrainer_desktop_note() { :; }
check_lossless_scaling_installation() { :; }
reload_decky_plugins() { echo reload >> "$TEST_ROOT/reloads"; }
systemctl() { fail 'Unexpected real service operation'; }
curl() { fail 'Unexpected network'; }
download_github_file() { fail 'Unexpected network'; }
download_gitee_mirror_file() { fail 'Unexpected network'; }
make_plugin() {
    mkdir -p "$DECKY_PLUGIN_DIR/$1/dist"
    printf '{"name":"%s"}\n' "$2" > "$DECKY_PLUGIN_DIR/$1/plugin.json"
    printf '{"version":"%s"}\n' "$3" > "$DECKY_PLUGIN_DIR/$1/package.json"
    printf 'fixture\n' > "$DECKY_PLUGIN_DIR/$1/dist/index.js"
}
make_plugin 'Decky LSFG-VK' 小黄鸭 "$LSFG_OFFICIAL_VERSION"
make_plugin Decky-Framegen 'Decky-Framegen（FSR4）' "$FSR4_OFFICIAL_VERSION"
make_plugin CheatDeck CheatDeck "$DECKY_CHEATDECK_VERSION"
make_plugin "$LSFG_MAKO_DIRECTORY" 'MAKO - Frame Generation' "$LSFG_MAKO_VERSION"
mkdir -p "$DECKY_PLUGIN_DIR/$LSFG_MAKO_DIRECTORY/bin"
echo license > "$DECKY_PLUGIN_DIR/$LSFG_MAKO_DIRECTORY/LICENSE.md"
echo renderer > "$DECKY_PLUGIN_DIR/$LSFG_MAKO_DIRECTORY/bin/MAKO-Renderer-v2.2.0-linux.tar.xz"
make_plugin "$STEAMGRIDDB_OFFICIAL_DIRECTORY" SteamGridDB "$STEAMGRIDDB_OFFICIAL_VERSION"
make_plugin "$CSSLOADER_OFFICIAL_DIRECTORY" 主题美化 "$CSSLOADER_OFFICIAL_VERSION"
make_plugin Friendeck-plugin Friendeck "$DECKY_FRIENDECK_PACKAGE_VERSION"
make_plugin 'Decky Music' 'Decky Music' "$DECKY_DECKYMUSIC_VERSION"
mkdir -p "$DECKY_PLUGIN_DIR/Decky Music/bin"
for binary in player qq-provider ncm-provider; do echo fixture > "$DECKY_PLUGIN_DIR/Decky Music/bin/$binary"; done
make_plugin "$DECKY_FANTASTIC_DIRECTORY" Fantastic "$DECKY_FANTASTIC_VERSION"
LSFG_MAKO_INDEX_SHA256="$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$LSFG_MAKO_DIRECTORY/dist/index.js")"
CSSLOADER_ZH_INDEX_SHA256="$LSFG_MAKO_INDEX_SHA256"
DECKY_FANTASTIC_INDEX_SHA256="$LSFG_MAKO_INDEX_SHA256"
DECKYGCM_SHA256="$(calculate_decky_sha256 "$TEST_ROOT/gcm.zip")"
DOWNLOADS=0 DENY_CLEANUP=0 DENY_ADMIN=0 CORRUPT_COPY=0
download_verified_package() {
    [ "$1:$2:$3" = "DeckyGCM:$DECKYGCM_URL:$DECKYGCM_SHA256" ] || fail 'Unexpected download or metadata'
    [ "$(calculate_decky_sha256 "$TEST_ROOT/gcm.zip")" = "$3" ] || fail 'ZIP digest incorrect'
    echo download >> "$TEST_ROOT/downloads"
    cp "$TEST_ROOT/gcm.zip" "$4"
}
run_plugin_file_operation() {
    local destination="${!#}"
    if [ "$1" = rm ] && [ "$DENY_CLEANUP" = 1 ] && [ -d "$destination/previous" ]; then
        echo 'Permission denied: previous root-owned plugin' >&2
        return 1
    fi
    "$@" || return $?
    if [ "$1" = cp ] && [ "$CORRUPT_COPY" = 1 ]; then
        echo corrupt > "$destination/py_modules/_gcm_core/auth.pyc"
    fi
}
toolbox_sudo() {
    [ "$1:$2:$3" = 'rm:-rf:--' ] || fail 'Unexpected privileged command'
    case "$4" in "$HOME/homebrew"/.renkit-plugin-install.*) ;; *) fail 'Cleanup escaped scope';; esac
    [ "$DENY_ADMIN" = 0 ] || return 1
    "$@"
}
install_feature_plugins > "$TEST_ROOT/fresh" 2> "$TEST_ROOT/hidden-errors" || fail 'Full combo failed'
grep -Fq '十款常用功能插件已全部安装完成' "$TEST_ROOT/fresh" || fail 'Combo not verified'
grep -Fq '✓ DeckyGCM' "$TEST_ROOT/fresh" || fail 'Real companion check skipped'
for DENY_ADMIN in 0 1; do
    echo changed > "$DECKY_PLUGIN_DIR/DeckyGCM/README.md"
    DENY_CLEANUP=1
    install_feature_plugins > "$TEST_ROOT/cleanup-result" 2> "$TEST_ROOT/hidden-errors" || fail 'Finished combo falsely failed on old-copy cleanup'
    deckygcm_is_current || fail 'Real copied tree incomplete'
    if [ "$DENY_ADMIN" = 1 ]; then
        grep -Fq '新文件已安装' "$TEST_ROOT/cleanup-result" || fail 'Cleanup warning hidden'
    fi
    ! grep -q '部分功能插件未完成' "$TEST_ROOT/cleanup-result" || fail 'Cleanup warning became installation failure'
done
DENY_CLEANUP=0 DENY_ADMIN=0
install_feature_plugins > "$TEST_ROOT/repeat" || fail 'Idempotent combo failed'
[ "$(wc -l < "$TEST_ROOT/downloads")" -eq 3 ] || fail 'Complete combo downloaded again'
cp -a "$DECKY_PLUGIN_DIR/DeckyGCM" "$DECKY_PLUGIN_DIR/.DeckyGCM.backup.99999999"
install_feature_plugins > "$TEST_ROOT/legacy-copy" || fail 'Complete combo could not isolate old duplicate'
[ ! -d "$DECKY_PLUGIN_DIR/.DeckyGCM.backup.99999999" ] || fail 'Legacy duplicate still scanned by loader'
grep -Fq '已隔离 1 个上次安装残留' "$TEST_ROOT/legacy-copy" || fail 'Legacy recovery hidden'
[ "$(wc -l < "$TEST_ROOT/downloads")" -eq 3 ] || fail 'Legacy isolation unnecessarily reinstalled plugin'
echo old-readme > "$DECKY_PLUGIN_DIR/DeckyGCM/README.md"
CORRUPT_COPY=1
if install_feature_plugins > "$TEST_ROOT/corrupt" 2> "$TEST_ROOT/hidden-errors"; then fail 'Corrupt staged backend accepted'; fi
[ "$(cat "$DECKY_PLUGIN_DIR/DeckyGCM/README.md")" = old-readme ] || fail 'Rejected package replaced old tree'
grep -Fq 'auth.pyc' "$TEST_ROOT/corrupt" || fail 'Underlying check reason hidden from stdout'
grep -Fq '未完成项目：CheatDeck 与 DeckyGCM' "$TEST_ROOT/corrupt" || fail 'Failed plugin absent from final summary'
grep -Fq 'DeckyGCM 文件检查失败' "$LOG_FILE" || fail 'Integrity reason missing from log'
CORRUPT_COPY=0
install_feature_plugins >/dev/null || fail 'Repair after failure failed'
OPTIONAL_TOOLS=install
bash() { [ "$2:$3" = 'install-trainer-one:10-29' ] || fail 'Unexpected child installer'; echo '模拟：运行工具下载失败' >&2; return 37; }
if install_feature_plugins > "$TEST_ROOT/tools-fail" 2> "$TEST_ROOT/hidden-errors"; then fail 'Trainer failure masked'; fi
grep -Fq '模拟：运行工具下载失败' "$TEST_ROOT/tools-fail" || fail 'Child stderr filtered away'
grep -Fq '常用插件已安装完成；未完成的是另外选择的修改器运行工具' "$TEST_ROOT/tools-fail" || fail 'Optional tool failure mislabeled as plugin failure'
unset -f bash
echo 'PASS: actual ten-plugin combo, real GCM unzip/copy/full status, existing root-owned backup failures, successful warnings, repeat install, staging corruption, rollback, visible reasons and separate trainer failure'
