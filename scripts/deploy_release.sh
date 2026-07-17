#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

echo "================================"
echo " 周克儿工具箱 发布部署脚本"
echo "================================"
echo ""

# 1. 获取新版本号
CURRENT_VERSION="$(cat VERSION | tr -d '\r\n')"
echo "当前版本: v$CURRENT_VERSION"
echo ""

read -r -p "请输入新版本号（不包含 v，例如 4.0.68）: " NEW_VERSION
[ -n "$NEW_VERSION" ] || { echo "版本号不能为空。"; exit 1; }
case "$NEW_VERSION" in
    *[!0-9.]*) echo "版本号格式无效。"; exit 1 ;;
esac

# 2. 更新 VERSION 文件
printf '%s\n' "$NEW_VERSION" > VERSION
echo "→ VERSION: $NEW_VERSION"

# 3. 获取更新日志描述
echo ""
echo "请输入本次更新描述（一行，用于 Git tag 信息，输入空行跳过）:"
read -r TAG_MESSAGE
[ -n "$TAG_MESSAGE" ] || TAG_MESSAGE="v$NEW_VERSION"

# 4. 运行打包脚本
echo ""
echo "正在构建发布包..."
bash scripts/package_release.sh || { echo "打包失败，已停止。"; exit 1; }

# 5. Git 操作：暂存全部、提交、打标签
echo ""
echo "正在提交并打标签..."
git add -A || { echo "git add 失败。"; exit 1; }
git commit -m "v$NEW_VERSION: $TAG_MESSAGE" || { echo "提交失败（可能无变更）。"; }

# 判断 origin 是否有多个 pushURL（双推配置）
HAS_DUAL_PUSH=0
if git remote get-url origin --push --all 2>/dev/null | grep -q .; then
    PUSH_COUNT=$(git remote get-url origin --push --all 2>/dev/null | wc -l)
    [ "$PUSH_COUNT" -ge 2 ] && HAS_DUAL_PUSH=1
fi

# 删除旧标签（如果存在）
git tag -d "v$NEW_VERSION" 2>/dev/null || true
git tag -a "v$NEW_VERSION" -m "$TAG_MESSAGE" || { echo "打标签失败。"; exit 1; }

# 6. 推送
echo ""
echo "正在推送..."
if [ "$HAS_DUAL_PUSH" -eq 1 ]; then
    # 单 origin 双推配置
    git push origin main --follow-tags || {
        echo "推送失败，正在单独推送..."
        git push origin main
        git push origin "v$NEW_VERSION"
    }
else
    # 分别推送到 GitHub 和 Gitee
    git push origin main
    git push origin "v$NEW_VERSION" || true
    git push gitee main
    git push gitee "v$NEW_VERSION" || true
fi

echo ""
echo "================================"
echo " v$NEW_VERSION 发布完成"
echo "================================"
