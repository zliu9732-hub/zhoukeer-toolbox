#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
DIST_DIR="$PROJECT_ROOT/dist"
PACKAGE_NAME="zhoukeer-toolbox.tar.gz"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"
VERSIONED_PACKAGE_NAME="zhoukeer-toolbox-$VERSION.tar.gz"
VERSIONED_PACKAGE_PATH="$DIST_DIR/$VERSIONED_PACKAGE_NAME"
SHA256SUMS_PATH="$DIST_DIR/SHA256SUMS"

mkdir -p "$DIST_DIR"

cd "$PROJECT_ROOT" || exit 1

tar \
    --exclude=".git" \
    --exclude=".DS_Store" \
    --exclude="dist" \
    --exclude="logs" \
    --exclude="apps" \
    --exclude="*.save" \
    --exclude="*.bak.*" \
    --exclude="管理员密码.txt" \
    --exclude="config/settings.conf" \
    -czf "$PACKAGE_PATH" .

cp "$PACKAGE_PATH" "$VERSIONED_PACKAGE_PATH"

if command -v sha256sum >/dev/null 2>&1; then
    PACKAGE_SHA256="$(sha256sum "$PACKAGE_PATH" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    PACKAGE_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"
else
    echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
    exit 1
fi

printf '%s  %s\n' "$PACKAGE_SHA256" "$PACKAGE_NAME" > "$SHA256SUMS_PATH"
printf '%s  %s\n' "$PACKAGE_SHA256" "$VERSIONED_PACKAGE_NAME" > \
    "$VERSIONED_PACKAGE_PATH.sha256"

echo "仓库更新包: $PACKAGE_PATH"
echo "Release发布包: $VERSIONED_PACKAGE_PATH"
echo "Release校验文件: $VERSIONED_PACKAGE_PATH.sha256"
echo "仓库校验文件: $SHA256SUMS_PATH"
