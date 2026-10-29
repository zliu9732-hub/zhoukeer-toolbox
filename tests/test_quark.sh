#!/bin/bash
# Only temporary files and fake Proton. Optional argument: reviewed portable archive.
set -euo pipefail
ROOT="${QUARK_TEST_APP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$TEST_ROOT/home with spaces" ZHOUKEER_APP_DIR="$TEST_ROOT/apps with spaces"
export ZHOUKEER_LAUNCHER_BASE="$TEST_ROOT/storage with spaces"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export ZHOUKEER_DESKTOP_DIR="$HOME/桌面"
export ZHOUKEER_TEST_MODE=1
export QUARK_TEST_ROOT="$TEST_ROOT" QUARK_TEST_SOURCE="$ROOT"
mkdir -p "$HOME/.config" "$HOME/桌面" "$TEST_ROOT/steam/steamapps"
printf 'XDG_DESKTOP_DIR="$HOME/桌面"\n' > "$HOME/.config/user-dirs.dirs"
source "$ROOT/modules/quark.sh"
launcher_details quark
[ "$LAUNCHER_GITEE_MIRROR_ID" = quark-portable ] || fail 'wrong portable payload'
[ -z "$LAUNCHER_URL" ] && [ -z "$LAUNCHER_FALLBACK_URL" ] || fail 'old installer fallback remains'
[ "$(gitee_mirror_manifest_repo quark-portable)" = zhoukeer-toolbox-mirror-6 ] || fail 'wrong mirror route'
[ "$(gitee_mirror_manifest_repo quark)" = zhoukeer-toolbox-mirror-6 ] || fail 'legacy route lost'
detect_platform() { IS_STEAMOS=1; }
log() { :; }
find_steam_root() { printf '%s\n' "$TEST_ROOT/steam"; }
select_launcher_storage_base() { printf '%s\n' "$ZHOUKEER_LAUNCHER_BASE"; }
ensure_launcher_proton_runner() { printf '%s\n' "$TEST_ROOT/proton"; }
if [ "$#" -gt 0 ]; then
    FIXTURE="$1"
    [ "$(launcher_file_sha256 "$FIXTURE")" = "$LAUNCHER_FIXED_SHA256" ] || fail 'real portable package SHA mismatch'
    cp "$ROOT/data/quark_portable_files.json" "$TEST_ROOT/inventory.json"
else
    FIXTURE="$TEST_ROOT/fixture.tar.xz"
    python3 - <<'PY'
from pathlib import Path
import os,tarfile,io,hashlib,json
root=Path(os.environ['QUARK_TEST_ROOT'])
files={'QuarkCloudDrive.exe':b'MZportable bootstrap','app-3.24.0/QuarkCloudDrive.exe':b'MZportable app','app-3.24.0/resources/app.asar':b'complete resources'}
with tarfile.open(root/'fixture.tar.xz','w:xz') as tar:
 for name,data in files.items():
  m=tarfile.TarInfo('quark-cloud-drive/'+name);m.size=len(data);tar.addfile(m,io.BytesIO(data))
(root/'inventory.json').write_text(json.dumps({n:{'size':len(d),'sha256':hashlib.sha256(d).hexdigest()} for n,d in files.items()}))
PY
fi
EXPECTED_SHA="$(launcher_file_sha256 "$FIXTURE")"
ORIGINAL_DETAILS="$(declare -f launcher_details)"
source <(printf '%s\n' "$ORIGINAL_DETAILS" | sed '1s/launcher_details/real_launcher_details/')
launcher_details() { real_launcher_details "$@"; LAUNCHER_FIXED_SHA256="$EXPECTED_SHA"; LAUNCHER_GITEE_MIRROR_SHA256="$EXPECTED_SHA"; LAUNCHER_MIN_BYTES=2; }
# Run the real extraction code using the local fixture's inventory.
cat > "$TEST_ROOT/helper.py" <<'PY'
import os,sys,importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('portable',Path(os.environ['QUARK_TEST_SOURCE'])/'scripts/quark_portable.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.INVENTORY=Path(os.environ['QUARK_TEST_ROOT'])/'inventory.json'
sys.argv=sys.argv[1:]
raise SystemExit(m.main())
PY
python3() {
    if [ "${1:-}" = "$ROOT/scripts/quark_portable.py" ]; then
        command python3 "$TEST_ROOT/helper.py" "$@"
    else
        command python3 "$@"
    fi
}
MODE=good
download_gitee_mirror_file() {
    [ "$1" = quark-portable ] || fail 'downloaded old installer'
    printf 'download\n' >> "$TEST_ROOT/downloads"
    case "$MODE" in
        fail) return 1 ;;
        bad) printf 'HTML error page' > "$2" ;;
        *) cp "$FIXTURE" "$2" ;;
    esac
}
# Unexpected system/network operations are always fatal, including in child shells.
mkdir -p "$TEST_ROOT/bin"
for tool in sudo pacman systemctl curl wget steam; do
    printf '#!/bin/bash\necho "Forbidden command: %%s" "$0" >&2\nexit 97\n' > "$TEST_ROOT/bin/$tool"
    chmod +x "$TEST_ROOT/bin/$tool"
done
export PATH="$TEST_ROOT/bin:$PATH"
cat > "$TEST_ROOT/proton" <<'PROTON'
#!/bin/bash
printf '%s\n' "$@" >> "$QUARK_TEST_LOG"
printf '%s\n' "$PWD" > "$QUARK_TEST_CWD"
PROTON
chmod +x "$TEST_ROOT/proton"
export QUARK_TEST_LOG="$TEST_ROOT/proton.log" QUARK_TEST_CWD="$TEST_ROOT/cwd"
# Include a previous full installation and real customer-file sentinels.
drive="$ZHOUKEER_LAUNCHER_BASE/quark/drive_c"
mkdir -p "$drive/Program Files/QuarkCloudDrive" "$drive/users/steamuser/AppData/Roaming/quark-cloud-drive"
printf 'MZold app' > "$drive/Program Files/QuarkCloudDrive/QuarkCloudDrive.exe"
printf 'customer data' > "$drive/customer.data"
printf 'account settings' > "$drive/users/steamuser/AppData/Roaming/quark-cloud-drive/preference.json"
install_quark > "$TEST_ROOT/install.out" 2>&1
DESKTOP="$HOME/桌面/夸克网盘.desktop"
APPLICATION="$HOME/.local/share/applications/renkit-quark.desktop"
[ -f "$DESKTOP" ] && [ -f "$APPLICATION" ] || fail 'missing entries'
[ ! -e "$QUARK_TEST_LOG" ] || fail 'installation executed a Windows program'
grep -Fq 'Categories=Network;FileTransfer;' "$DESKTOP" || fail 'wrong category'
grep -Fq 'Icon='"$ROOT/assets/software/quark.png" "$DESKTOP" || fail 'missing icon'
install_quark > "$TEST_ROOT/repeat.out" 2>&1
[ "$(wc -l < "$TEST_ROOT/downloads" | tr -d ' ')" = 1 ] || fail 'repeated download'
bash "$QUARK_APP_DIR/launch-quark.sh"
resolved_drive="$(cd "$drive" && pwd -P)"
grep -Fqx "$resolved_drive/QuarkCloudDrive-Portable-3.24.0/QuarkCloudDrive.exe" "$QUARK_TEST_LOG" || fail 'wrapper did not select portable bootstrap'
[ "$(cat "$QUARK_TEST_CWD")" = "$resolved_drive/QuarkCloudDrive-Portable-3.24.0" ] || fail 'incorrect portable working directory'
[ "$(wc -l < "$QUARK_TEST_LOG" | tr -d ' ')" = 2 ] || fail 'installer switches or scripts executed'
[ "$(cat "$drive/customer.data")" = 'customer data' ] || fail 'customer data removed'
[ "$(cat "$drive/users/steamuser/AppData/Roaming/quark-cloud-drive/preference.json")" = 'account settings' ] || fail 'account configuration replaced'
[ "$(cat "$drive/Program Files/QuarkCloudDrive/QuarkCloudDrive.exe")" = 'MZold app' ] || fail 'old app removed'
# Failed or mismatched downloads cannot replace a complete previous archive.
launcher_details quark
cp "$FIXTURE" "$TEST_ROOT/retained.tar.xz"
for MODE in bad fail; do
    if quark_download_portable "$TEST_ROOT/retained.tar.xz" > "$TEST_ROOT/$MODE.out" 2>&1; then fail "$MODE download accepted"; fi
    cmp "$TEST_ROOT/retained.tar.xz" "$FIXTURE" || fail 'damaged download replaced old payload'
done
MODE=good
# Missing resource must fail, preserving the existing program and entry.
rm -- "$drive/QuarkCloudDrive-Portable-3.24.0/app-3.24.0/resources/app.asar"
if install_quark > "$TEST_ROOT/incomplete.out" 2>&1; then fail 'incomplete portable app accepted'; fi
[ -f "$DESKTOP" ] && [ -f "$drive/customer.data" ] || fail 'failed repair removed data'
remove_quark_shortcuts > "$TEST_ROOT/remove.out"
[ ! -e "$DESKTOP" ] && [ ! -e "$APPLICATION" ] || fail 'managed entries not removed'
[ -f "$drive/customer.data" ] || fail 'shortcut removal deleted user data'
# Use a clean location to exercise cancellation and shortcut conflict safely.
QUARK_APP_DIR="$TEST_ROOT/new-apps/game-launchers/quark"; APP_DIR="$TEST_ROOT/new-apps"
ZHOUKEER_LAUNCHER_BASE="$TEST_ROOT/new-storage"
select_launcher_storage_base() { return 2; }
install_quark > "$TEST_ROOT/cancel.out" 2>&1
[ ! -e "$QUARK_APP_DIR" ] || fail 'cancellation installed files'
select_launcher_storage_base() { printf '%s\n' "$ZHOUKEER_LAUNCHER_BASE"; }
printf '[Desktop Entry]\nName=customer entry\n' > "$DESKTOP"
if install_quark > "$TEST_ROOT/conflict.out" 2>&1; then fail 'unmanaged shortcut overwritten'; fi
grep -Fq 'Name=customer entry' "$DESKTOP" || fail 'customer shortcut changed'
rm -- "$DESKTOP"
ln -s "$TEST_ROOT/outside" "$QUARK_APP_DIR/launch-quark.sh.link"
mv -- "$QUARK_APP_DIR/launch-quark.sh.link" "$QUARK_APP_DIR/launch-quark.sh"
if install_quark > "$TEST_ROOT/symlink.out" 2>&1; then fail 'unsafe wrapper accepted'; fi
[ ! -e "$TEST_ROOT/outside" ] || fail 'followed wrapper symlink'
if grep -Ei 'gitee|分块|镜像|https://' "$TEST_ROOT"/*.out; then fail 'internal details in UI'; fi
printf '%s\n' 'PASS: Quark portable extraction, no installer execution, wrapper, repeat, integrity, cancellation and customer data preservation'
