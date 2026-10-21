#!/bin/bash
# Network/platform/service calls are mocked; file writes stay in a temporary tree.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_APP_DIR="$TEST_ROOT/apps"
source "$ROOT/modules/plugin_store.sh"
export DECKY_PLUGIN_DIR="$TEST_ROOT/plugins"
mkdir -p "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist" "$TEST_ROOT/settings" "$TEST_ROOT/runtime"
printf 'previous frontend' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js"
printf '{"version":"1.10.7"}' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/package.json"
printf 'old file' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/obsolete.py"
printf 'customer settings' > "$TEST_ROOT/settings/settings.json"
printf 'customer theme' > "$TEST_ROOT/runtime/theme.bin"
python3 - "$ROOT/scripts" "$TEST_ROOT" <<'PY'
import hashlib,json,sys,zipfile
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from themehub_package import entry
root=Path(sys.argv[2]);files={'plugin.json':b'{"name":"ThemeHub"}',
'package.json':b'{"version":"1.10.10"}','main.py':b'# unchanged backend',
'dist/index.js':'完整中文 RenAmamiya汉化'.encode(),'LICENSE':b'original license',
'RENKIT_UI_COVERAGE.json':b'{}'}
archive=root/'plugin.zip'
with zipfile.ZipFile(archive,'w') as z:
    for name,data in files.items():z.writestr('DeckHomeThemes/'+name,data)
sha=lambda b:hashlib.sha256(b).hexdigest()
e={'plugin_name':'ThemeHub','archive_root':'DeckHomeThemes','mirror_id':'themehub-zh-auto',
'upstream_version':'1.10.10','translation_revision':2,'attribution':'RenAmamiya',
'upstream_sha256':'a'*64,'package_sha256':sha(archive.read_bytes()),'frontend_sha256':sha(files['dist/index.js']),
'files':{n:sha(b) for n,b in files.items()},'modes':{n:0o644 for n in files}}
c={'schema':1,'package':e};entry(c);(root/'catalog.json').write_text(json.dumps(c))
PY
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
detect_platform
log() { printf '%s\n' "$*" >> "$TEST_ROOT/log"; }
reload_decky_plugins() { fail 'unexpected service action'; }
META=good DOWNLOAD=good FILE_MODE=good
download_github_file() {
    case "$META" in
        offline) return 1 ;;
        invalid) printf 'not JSON' > "$2" ;;
        *) cp "$TEST_ROOT/catalog.json" "$2" ;;
    esac
}
download_gitee_mirror_file() {
    [ "$1" = themehub-zh-auto ] || fail 'wrong download route'
    printf 'download\n' >> "$TEST_ROOT/downloads"
    [ "$DOWNLOAD" != fail ] || return 1
    cp "$TEST_ROOT/plugin.zip" "$2"
    [ "$DOWNLOAD" != corrupt ] || printf 'corruption' >> "$2"
}
run_plugin_file_operation() {
    if [ "$FILE_MODE" = copy-fail ] && [ "$1" = cp ]; then return 1; fi
    if [ "$FILE_MODE" = final-corrupt ] && [ "$1" = mv ] && [[ "$3" = *'/.DeckHomeThemes.new.'* ]]; then
        command "$@" || return
        printf 'damaged' > "$4/dist/index.js"
        return
    fi
    command "$@"
}
ensure_deckhomethemes_chinese_current > "$TEST_ROOT/install.out"
[ "$PLUGIN_INSTALL_CHANGED" = 1 ] || fail 'entry did not install new package'
[ ! -e "$DECKY_PLUGIN_DIR/DeckHomeThemes/obsolete.py" ] || fail 'old files not removed'
python3 "$ROOT/scripts/themehub_package.py" check --catalog "$TEST_ROOT/catalog.json" --root "$DECKY_PLUGIN_DIR/DeckHomeThemes"
ensure_deckhomethemes_chinese_current > "$TEST_ROOT/repeat.out"
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail 'complete install was downloaded again'
[ "$(wc -l < "$TEST_ROOT/downloads" | tr -d ' ')" = 1 ] || fail 'repeat download'
[ "$(find "$DECKY_PLUGIN_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ] || fail 'duplicate or backup left after success'

# Each failure must leave the previous tree byte-for-byte intact.
printf 'previous frontend' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js"
printf 'old file' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/obsolete.py"
for scenario in download corrupt copy final; do
    DOWNLOAD=good FILE_MODE=good
    case "$scenario" in download) DOWNLOAD=fail ;; corrupt) DOWNLOAD=corrupt ;; copy) FILE_MODE=copy-fail ;; final) FILE_MODE=final-corrupt ;; esac
    if ensure_deckhomethemes_chinese_current > "$TEST_ROOT/$scenario.out" 2>&1; then fail "$scenario returned success"; fi
    [ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail "$scenario marked changed"
    [ "$(cat "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js")" = 'previous frontend' ] || fail "$scenario damaged previous install"
    [ -f "$DECKY_PLUGIN_DIR/DeckHomeThemes/obsolete.py" ] || fail "$scenario deleted previous files"
    [ "$(find "$DECKY_PLUGIN_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ] || fail "$scenario left duplicate files"
done
DOWNLOAD=good FILE_MODE=good META=offline
ensure_deckhomethemes_chinese_current > "$TEST_ROOT/offline.out"
META=invalid
refresh_themehub_catalog
python3 - "$THEMEHUB_CATALOG_CACHE" "$TEST_ROOT/catalog.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))==json.load(open(sys.argv[2])), 'bad metadata replaced cached release'
PY
printf '{"version":"1.11.0"}' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/package.json"
printf 'newer frontend' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js"
ensure_deckhomethemes_chinese_current > "$TEST_ROOT/newer.out"
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] && [ "$(cat "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js")" = 'newer frontend' ] || fail 'downgraded newer version'
(
    install_themehub_auto() { return 2; }
    download_deckhomethemes_package() { fail 'fallback attempted to downgrade a newer install'; }
    if ensure_deckhomethemes_chinese_current > "$TEST_ROOT/fallback.out"; then fail 'unavailable catalog permitted old fallback'; fi
    [ "$(cat "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js")" = 'newer frontend' ] || fail 'fallback damaged newer version'
)
[ "$(cat "$TEST_ROOT/settings/settings.json")" = 'customer settings' ] || fail 'settings changed'
[ "$(cat "$TEST_ROOT/runtime/theme.bin")" = 'customer theme' ] || fail 'themes changed'
if rg -i 'gitee|https://|分块|镜像' "$TEST_ROOT"/*.out; then fail 'internal download terms in UI'; fi
printf '%s\n' 'PASS: ThemeHub latest install, cleanup, verified rollback, offline cache, no downgrade and preserved themes/settings'
