#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_ROOT/third_party/fantastic-zh-v0.5.1"
MODULE="$PROJECT_ROOT/modules/decky_bundle.sh"

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
    "$MODULE" || fail "Fantastic 未固定使用 Gitee mirror-3"
grep -Fq 'fantastic-zh-signed/v0.5.1/Fantastic-zh-signed-v0.5.1.zip' \
    "$MODULE" || fail "Fantastic Gitee 路径不完整"

echo "PASS: Fantastic 0.5.1 中文界面、RenAmamiya署名、上游身份与Gitee固定包校验通过"
