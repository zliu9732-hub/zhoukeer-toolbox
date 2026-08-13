#!/bin/bash

# 把本地已核验的安装包分块推送到 Gitee 独立镜像仓库，供Renkit分块下载。
# 用法:
#   GITEE_TOKEN=xxx bash scripts/seed_gitee_local_asset.sh <id> <name> <version> <file> <source_url> <local_file>
# 未设置 GITEE_TOKEN 时，使用当前机器已配置的 Gitee SSH 认证。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OWNER="${GITEE_MIRROR_OWNER:-zliu9732-hub}"
REPO="${GITEE_MIRROR_REPO:-zhoukeer-toolbox-mirror}"
BRANCH="${GITEE_MIRROR_BRANCH:-main}"

if [ "$#" -ne 6 ]; then
    echo "用法: bash scripts/seed_gitee_local_asset.sh <id> <name> <version> <file> <source_url> <local_file>" >&2
    exit 1
fi

id="$1"
name="$2"
version="$3"
file="$4"
source_url="$5"
local_file="$6"

bash "$ROOT/scripts/mirror_gitee_assets.sh" --local \
    "$id" "$name" "$version" "$file" "$source_url" "$local_file"

MIRROR_SOURCE="$ROOT/mirrors/$id"
[ -d "$MIRROR_SOURCE" ] || {
    echo "本地镜像生成失败：$MIRROR_SOURCE"
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT

# Gitee 大仓库整包 clone 容易挂起；只拉提交/树对象即可添加新分块并推送。
if [ -n "${GITEE_TOKEN:-}" ]; then
    git clone -q --filter=blob:none --no-checkout \
        "https://${OWNER}:${GITEE_TOKEN}@gitee.com/${OWNER}/${REPO}.git" "$TMP/mirror"
else
    git clone -q --filter=blob:none --no-checkout \
        "git@gitee.com:${OWNER}/${REPO}.git" "$TMP/mirror"
fi
# 部分克隆默认不写出索引；先读回 HEAD 树，后续 add 新 id 时保留仓库已有分块。
if git -C "$TMP/mirror" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$TMP/mirror" read-tree HEAD
fi

# 空仓库默认分支可能是 master，统一切到发布分支再提交推送。
if ! git -C "$TMP/mirror" rev-parse --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
    git -C "$TMP/mirror" checkout -b "$BRANCH" 2>/dev/null || \
        git -C "$TMP/mirror" symbolic-ref HEAD "refs/heads/$BRANCH"
fi

rm -rf -- "$TMP/mirror/$id"
cp -R -- "$MIRROR_SOURCE" "$TMP/mirror/$id"
git -C "$TMP/mirror" add -- "$id"
if git -C "$TMP/mirror" diff --cached --quiet; then
    echo "镜像仓库没有变更：$id"
else
    git -C "$TMP/mirror" -c user.name="zhoukeer-toolbox[bot]" \
        -c user.email="bot@users.noreply.github.com" \
        -c commit.gpgsign=false \
        commit -q -m "Mirror $id $version"
    git -C "$TMP/mirror" push -q origin "$BRANCH"
    echo "已推送 $id/$version 到 Gitee 镜像仓库 $OWNER/$REPO"
fi

rm -rf -- "$MIRROR_SOURCE"
