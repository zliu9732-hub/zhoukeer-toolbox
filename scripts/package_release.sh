#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
DIST_DIR="$PROJECT_ROOT/dist"
PACKAGE_NAME="zhoukeer-toolbox-$VERSION.tar.gz"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"
SHA256SUMS_PATH="$DIST_DIR/SHA256SUMS"

mkdir -p "$DIST_DIR"

cd "$PROJECT_ROOT" || exit 1

tar \
    --exclude=".git" \
    --exclude=".DS_Store" \
    --exclude="dist" \
    --exclude="logs" \
    --exclude="apps" \
    --exclude="config/settings.conf" \
    -czf "$PACKAGE_PATH" .

if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$PACKAGE_PATH" > "$PACKAGE_PATH.sha256"
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$PACKAGE_PATH" > "$PACKAGE_PATH.sha256"
else
    echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
    exit 1
fi

cp "$PACKAGE_PATH.sha256" "$SHA256SUMS_PATH"

echo "发布包: $PACKAGE_PATH"
echo "校验文件: $PACKAGE_PATH.sha256"
echo "统一校验文件: $SHA256SUMS_PATH"
