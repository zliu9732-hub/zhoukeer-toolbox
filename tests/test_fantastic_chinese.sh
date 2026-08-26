#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_ROOT/third_party/fantastic-zh-v0.5.1"
MODULE="$PROJECT_ROOT/modules/plugin_store.sh"
SELECTED_MODULE="$PROJECT_ROOT/modules/decky_bundle.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for file in plugin.json package.json LICENSE dist/index.js; do
    [ -s "$SOURCE/$file" ] || fail "Fantastic 汉化组件缺少 $file"
done

[ "$(shasum -a 256 "$SOURCE/dist/index.js" | awk '{print $1}')" = \
    "409cfcd0f762ae9d8b6d2b27483839fab59eacced642ce980ec2d837bcb96487" ] || \
    fail "Fantastic 汉化前端 SHA256 不一致"
grep -Fq '"name": "Fantastic"' "$SOURCE/plugin.json" || fail "Fantastic 上游身份被改写"
grep -Fq '"author": "NGnius"' "$SOURCE/plugin.json" || fail "Fantastic 原作者缺失"
grep -Fq 'RenAmamiya' "$SOURCE/plugin.json" || fail "Fantastic 清单缺少汉化署名"
grep -Fq 'GNU GENERAL PUBLIC LICENSE' "$SOURCE/LICENSE" || fail "Fantastic GPL-3.0 许可证缺失"
for text in 当前风扇转速 当前温度 自定义风扇曲线 线性插值 风扇控制 RenAmamiya; do
    grep -Fq "$text" "$SOURCE/dist/index.js" || fail "Fantastic 前端缺少：$text"
done
grep -Fq 'DECKY_FANTASTIC_SHA256="c2dbb0bf74dbea4a17c2cf5121941bc61176559eefdf033c7380c530b5bb54ba"' \
    "$MODULE" || fail "Fantastic Gitee 完整包 SHA256 未固定"
grep -Fq 'DECKY_FANTASTIC_MIRROR_REPO="zhoukeer-toolbox-mirror-3"' \
    "$SELECTED_MODULE" && fail "Fantastic 不应再由精选插件安装器处理"
grep -Fq 'fantastic-zh-signed/v0.5.1/Fantastic-zh-signed-v0.5.1.zip' \
    "$MODULE" || fail "Fantastic Gitee 路径不完整"
grep -Fq 'install_decky_zip \' "$MODULE" || fail "Fantastic 未使用Renkit直装函数"
grep -Fq 'install_configured_plugin fantastic' "$MODULE" || fail "Fantastic 未注册常用插件直装动作"
if grep -Fq 'DECKY_BUNDLE_CUSTOM_ONLY=fantastic' "$SELECTED_MODULE"; then
    fail "Fantastic 仍会弹出 Decky 精选安装窗口"
fi

mkdir -p "$TMP_ROOT/archive/Fantastic" "$TMP_ROOT/plugins"
cp -R "$SOURCE/." "$TMP_ROOT/archive/Fantastic/"
(cd "$TMP_ROOT/archive" && zip -qr "$TMP_ROOT/Fantastic.zip" Fantastic)

# 完全使用本地归档和临时插件目录，验证直装调用链不会访问网络或 Decky 商城。
# shellcheck disable=SC1090
source "$MODULE"
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; }
download_verified_package() { cp -- "$TMP_ROOT/Fantastic.zip" "$4"; }
reload_decky_plugins() { printf 'TEST_RELOAD: %s\n' "$1"; }
DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
ZHOUKEER_TEST_MODE=1
install_output="$(install_configured_plugin fantastic)" || fail "Fantastic Renkit直装模拟失败"
grep -Fq 'Fantastic v0.5.1 已直接安装' <<< "$install_output" || fail "Fantastic 直装未报告成功"
grep -Fq 'TEST_RELOAD:' <<< "$install_output" || fail "Fantastic 直装后未自动重载 Decky"
[ -s "$TMP_ROOT/plugins/Fantastic/dist/index.js" ] || fail "Fantastic 未写入临时插件目录"
[ "$(shasum -a 256 "$TMP_ROOT/plugins/Fantastic/dist/index.js" | awk '{print $1}')" = \
    "409cfcd0f762ae9d8b6d2b27483839fab59eacced642ce980ec2d837bcb96487" ] || \
    fail "Fantastic 直装后的汉化前端校验失败"

echo "PASS: Fantastic 0.5.1 中文界面、RenAmamiya署名、Gitee固定包与Renkit直装校验通过"
