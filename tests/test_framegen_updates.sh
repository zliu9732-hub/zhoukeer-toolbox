#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps" ZHOUKEER_TEST_MODE=1
source "$PROJECT_ROOT/modules/plugin_store.sh"
export DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
require_existing_chimera_plugin_environment() { return 0; }
prepare_plugin_root() { mkdir -p "$1"; PLUGIN_NEEDS_SUDO=0; }
reload_decky_plugins() { return 0; }
log() { return 0; }
toolbox_sudo() { [ "$1" = systemctl ]; }
python3 - "$PROJECT_ROOT/scripts" "$TMP_ROOT" <<'PY'
import sys,json,hashlib,zipfile
from pathlib import Path
sys.path.insert(0,sys.argv[1]);from framegen_package import KINDS
root=Path(sys.argv[2]);c={'schema':1,'packages':{}}
for kind,v in [('lsfg-v2','0.14.5'),('fsr4','0.18')]:
 k=KINDS[kind];name=k['names'][1];folder=k['roots'][1 if kind=='lsfg-v2' else 0]
 files={'plugin.json':json.dumps({'name':name}).encode(),'package.json':json.dumps({'version':v}).encode(),
        'dist/index.js':b'Chinese frontend '+kind.encode(),'main.py':b'# backend\n','LICENSE':b'Original license',
        'bin/new-runtime-2.1.tar.xz':b'new runtime'}
 p=root/(kind+'.zip')
 with zipfile.ZipFile(p,'w') as z:
  for n,b in files.items():z.writestr(folder+'/'+n,b)
 c['packages'][kind]={'upstream_version':v,'upstream_sha256':'a'*64,'package_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
 'frontend_sha256':hashlib.sha256(files['dist/index.js']).hexdigest(),'mirror_id':k['ids'][1],'archive_root':folder,'plugin_name':name,
 'attribution':'RenAmamiya','translation_revision':2,'files':{n:hashlib.sha256(b).hexdigest() for n,b in files.items()}}
(root/'catalog.json').write_text(json.dumps(c,ensure_ascii=False))
PY
MODE=ok
CALLS="$TMP_ROOT/calls"
download_github_file() {
    [ "$1" = "$FRAMEGEN_CATALOG_URL" ] || fail '使用了未知版本信息地址'
    printf 'catalog\n' >> "$CALLS"
    case "$MODE" in
        offline) return 1 ;;
        bad-catalog) printf '{bad' > "$2" ;;
        *) cp "$TMP_ROOT/catalog.json" "$2" ;;
    esac
}
download_gitee_mirror_file() {
    local kind
    case "$1" in lsfg-v2-zh-auto) kind=lsfg-v2 ;; fsr4-zh-auto) kind=fsr4 ;; *) fail '请求了其他插件' ;; esac
    [ "$GITEE_MIRROR_REPO" = "$(gitee_mirror_manifest_repo "$1")" ] || fail '下载仓库不匹配'
    [ "$3" = "$(shasum -a 256 "$TMP_ROOT/$kind.zip" | awk '{print $1}')" ] || fail '没有使用当前版本的完整校验值'
    printf 'package:%s\n' "$kind" >> "$CALLS"
    [ "$MODE" != download-fail ] || return 1
    cp "$TMP_ROOT/$kind.zip" "$2"
    [ "$MODE" != corrupt ] || printf 'corrupt' >> "$2"
    return 0
}
mkdir -p "$DECKY_PLUGIN_DIR/Decky LSFG-VK" "$DECKY_PLUGIN_DIR/小黄鸭2.0" "$DECKY_PLUGIN_DIR/Mako"
# The broken automatic build had the same upstream version, but renamed only plugin.json.
# A repaired catalog must replace that installation rather than skip on version equality.
python3 - "$TMP_ROOT" "$DECKY_PLUGIN_DIR/Decky LSFG-VK" <<'PY'
import sys,json,zipfile
from pathlib import Path
root,target=map(Path,sys.argv[1:]);c=json.loads((root/'catalog.json').read_text())
with zipfile.ZipFile(root/'lsfg-v2.zip') as z:
 for name in z.namelist():
  p=target/Path(name).relative_to('小黄鸭2.0');p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(z.read(name))
(target/'plugin.json').write_text(json.dumps({'name':'小黄鸭2.0'}))
PY
printf 'old program' > "$DECKY_PLUGIN_DIR/Decky LSFG-VK/old"
printf '{"name":"小黄鸭2.0"}' > "$DECKY_PLUGIN_DIR/小黄鸭2.0/plugin.json"
printf 'keep Mako' > "$DECKY_PLUGIN_DIR/Mako/user-settings"
MODE=download-fail
if install_lsfg_v2_from_gitee 0 > "$TMP_ROOT/fail.out"; then fail '自动包下载失败仍成功'; fi
[ -f "$DECKY_PLUGIN_DIR/Decky LSFG-VK/old" ] || fail '下载失败先删除了旧插件'
MODE=corrupt
if install_lsfg_v2_from_gitee 0 > "$TMP_ROOT/corrupt.out"; then fail '损坏自动包仍成功'; fi
[ -f "$DECKY_PLUGIN_DIR/Decky LSFG-VK/old" ] || fail '损坏包替换了旧插件'
MODE=ok
install_lsfg_v2_from_gitee 0 > "$TMP_ROOT/ok.out" || fail '新版中文包不能安装'
[ ! -e "$DECKY_PLUGIN_DIR/Decky LSFG-VK/old" ] || fail '新版没有覆盖旧目录'
[ ! -e "$DECKY_PLUGIN_DIR/小黄鸭2.0" ] || fail '新版没有清理重复目录'
[ -f "$DECKY_PLUGIN_DIR/Decky LSFG-VK/bin/new-runtime-2.1.tar.xz" ] || fail '仍只允许固定旧运行组件'
grep -Fq 'Decky LSFG-VK' "$DECKY_PLUGIN_DIR/Decky LSFG-VK/plugin.json" || fail '同版本修复未恢复后端内部名称'
grep -Fxq 'keep Mako' "$DECKY_PLUGIN_DIR/Mako/user-settings" || fail '改动了 Mako'
[ "$LSFG_V2_VERSION" = 0.14.5 ] || fail '没有更新当前版本信息'
lsfg_v2_is_current "$DECKY_PLUGIN_DIR" || fail '新版未通过完整性检查'
: > "$CALLS"
install_lsfg_v2_from_gitee 0 >/dev/null || fail '当前新版无法清理后重新安装'
grep -q '^package:lsfg-v2' "$CALLS" || fail '当前 2.0 没有重新安装'
install_fsr4_zh_from_gitee 0 > "$TMP_ROOT/fsr4.out" || fail 'FSR4 新版不能安装'
[ "$FSR4_OFFICIAL_VERSION" = 0.18 ] || fail 'FSR4 仍写死旧版'
framegen_auto_is_current fsr4 "$DECKY_PLUGIN_DIR" || fail 'FSR4 新版文件验证失败'
cp "$TMP_ROOT/catalog.json" "$TMP_ROOT/catalog.saved"
python3 - "$TMP_ROOT/catalog.json" <<'PY'
import sys,json
from pathlib import Path
p=Path(sys.argv[1]);j=json.loads(p.read_text());j['packages']['fsr4']['upstream_version']='0.17';p.write_text(json.dumps(j))
PY
install_fsr4_zh_from_gitee 0 >/dev/null || fail '旧下载缓存导致新版安装失败'
[ "$FSR4_OFFICIAL_VERSION" = 0.18 ] || fail '旧下载缓存覆盖了较新版本信息'
mv "$TMP_ROOT/catalog.saved" "$TMP_ROOT/catalog.json"
MODE=offline
install_fsr4_zh_from_gitee 0 >/dev/null || fail '获取版本信息失败不能使用缓存'
MODE=bad-catalog
install_fsr4_zh_from_gitee 0 >/dev/null || fail '错误版本信息影响现有缓存'
printf '{"version":"9.0.0"}' > "$DECKY_PLUGIN_DIR/Decky-Framegen/package.json"
MODE=ok
install_fsr4_zh_from_gitee 0 > "$TMP_ROOT/newer.out" || fail '较新版本检测失败'
grep -Fq 9.0.0 "$DECKY_PLUGIN_DIR/Decky-Framegen/package.json" || fail '降级了用户较新版本'
rm "$FRAMEGEN_CATALOG_CACHE"
MODE=offline
status=0
install_framegen_auto fsr4 0 >/dev/null || status=$?
[ "$status" -eq 0 ] || fail '离线时没有采用内置已核对版本信息'
python3 - "$FRAMEGEN_CATALOG_CACHE" <<'PY'
import sys,json
e=json.load(open(sys.argv[1]))['packages']['lsfg-v2']
assert e['translation_revision']>=5
e['translation_revision']=4
c=json.load(open(sys.argv[1]));c['packages']['lsfg-v2']=e
open(sys.argv[1],'w').write(json.dumps(c))
PY
refresh_framegen_catalog || fail '旧缓存不能升级到内置汉化修订'
python3 - "$FRAMEGEN_CATALOG_CACHE" <<'PY'
import sys,json
assert json.load(open(sys.argv[1]))['packages']['lsfg-v2']['translation_revision']>=5
PY
(
    rm "$FRAMEGEN_CATALOG_CACHE"
    refresh_framegen_catalog() { return 1; }
    status=0
    install_framegen_auto fsr4 0 >/dev/null || status=$?
    [ "$status" -eq 2 ] || fail '没有可用版本信息时未允许固定包回退'
)
(
    ensure_plugin_store_ready() { return 0; }
    refresh_framegen_catalog() { return 1; }
    feature_plugin_is_current() { [ "$2" != "$FSR4_OFFICIAL_DIRECTORY" ]; }
    install_lsfg_zh_from_gitee() { fail '版本缓存丢失时常用组合把新版 2.0 改回了 1.0'; }
    install_lsfg_v2_from_gitee() { echo 'SELECTED_V2_CHECKED'; }
    install_fsr4_zh_from_gitee() { return 0; }
    install_configured_plugin() { return 0; }
    mako_official_is_current() { return 0; }
    deckymusic_full_is_current() { return 0; }
    refresh_feature_usage_guides() { return 0; }
    print_feature_plugin_status() { return 0; }
    check_lossless_scaling_installation() { return 0; }
    print_cef_remote_debugging_tip() { return 0; }
    ZHOUKEER_LSFG_VARIANT=v2 ZHOUKEER_FEATURE_PLUGIN_CLEANUP=keep install_feature_plugins
) > "$TMP_ROOT/selected.out" || fail '版本缓存丢失后组合安装失败'
grep -Fxq 'SELECTED_V2_CHECKED' "$TMP_ROOT/selected.out" || fail '组合安装没有保留较新的 2.0 选择'
if grep -Eiq 'gitee|镜像|https://' "$TMP_ROOT/ok.out" "$TMP_ROOT/fsr4.out"; then fail '安装界面显示内部来源'; fi
echo 'PASS: 自动中文包的最新版本、完整校验、失败保留、缓存、目录覆盖及禁止降级模拟通过'
