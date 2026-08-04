#!/bin/bash

# 生成战网 + 黑盒工坊独立安装包，只包含相关模块、脚本与素材。
# 输出: dist/zhoukeer-battlenet-heihe-<VERSION>.tar.gz 及 .sha256

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
OUTPUT_DIR="${ZHOUKEER_STANDALONE_OUTPUT_DIR:-$PROJECT_ROOT/dist}"
MAX_BYTES="${ZHOUKEER_STANDALONE_MAX_BYTES:-9437184}"
STAGE_DIR="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$STAGE_DIR"' EXIT

PACKAGE_NAME="zhoukeer-battlenet-heihe-$VERSION.tar.gz"
PACKAGE_PATH="$OUTPUT_DIR/$PACKAGE_NAME"

FILES_TO_COPY=(
    modules/game_launchers.sh
    core/env.sh
    core/platform.sh
    core/logger.sh
    core/download_policy.sh
    utils/github_download.sh
    utils/gitee_download.sh
    scripts/steam_shortcut.py
    scripts/steam_compat.py
    scripts/open_steam_internal_browser.sh
)

ASSET_FILES=(
    battlenet.png
    battlenet-grid.png
    battlenet-portrait.png
    battlenet-hero.png
    battlenet-background.jpg
    heihe.png
    heihe-grid.png
    heihe-portrait.png
    heihe-hero.png
    heihe-background.png
)

mkdir -p "$OUTPUT_DIR" "$STAGE_DIR/modules" "$STAGE_DIR/core" \
    "$STAGE_DIR/utils" "$STAGE_DIR/scripts" "$STAGE_DIR/assets/game-launchers" || exit 1

cp "$PROJECT_ROOT/standalone/battlenet-heihe/install.sh" "$STAGE_DIR/install.sh" || exit 1
cp "$PROJECT_ROOT/standalone/battlenet-heihe/README.md" "$STAGE_DIR/README.md" || exit 1
cp "$PROJECT_ROOT/VERSION" "$STAGE_DIR/VERSION" || exit 1
cp "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" "$STAGE_DIR/THIRD_PARTY_LICENSES.md" || exit 1

for file in "${FILES_TO_COPY[@]}"; do
    cp "$PROJECT_ROOT/$file" "$STAGE_DIR/$file" || exit 1
done

for file in "${ASSET_FILES[@]}"; do
    cp "$PROJECT_ROOT/assets/game-launchers/$file" "$STAGE_DIR/assets/game-launchers/$file" || exit 1
done

chmod 0755 "$STAGE_DIR/install.sh" || exit 1

# 逐文件核对复制结果与源码一致，避免打包到旧内容。
cmp -s "$PROJECT_ROOT/standalone/battlenet-heihe/install.sh" "$STAGE_DIR/install.sh" || exit 1
cmp -s "$PROJECT_ROOT/standalone/battlenet-heihe/README.md" "$STAGE_DIR/README.md" || exit 1
cmp -s "$PROJECT_ROOT/VERSION" "$STAGE_DIR/VERSION" || exit 1
cmp -s "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" "$STAGE_DIR/THIRD_PARTY_LICENSES.md" || exit 1
for file in "${FILES_TO_COPY[@]}"; do
    cmp -s "$PROJECT_ROOT/$file" "$STAGE_DIR/$file" || exit 1
done
for file in "${ASSET_FILES[@]}"; do
    cmp -s "$PROJECT_ROOT/assets/game-launchers/$file" \
        "$STAGE_DIR/assets/game-launchers/$file" || exit 1
done

bash -n "$STAGE_DIR/install.sh" || exit 1
bash -n "$STAGE_DIR/modules/game_launchers.sh" || exit 1
for file in "$STAGE_DIR/core/"*.sh "$STAGE_DIR/utils/"*.sh "$STAGE_DIR/scripts/"*.sh; do
    bash -n "$file" || exit 1
done

cd "$STAGE_DIR" || exit 1
COPYFILE_DISABLE=1 tar --no-xattrs --exclude='.DS_Store' --exclude='._*' \
    --exclude='*/._*' -czf "$PACKAGE_PATH" . || exit 1

if tar -tzf "$PACKAGE_PATH" | grep -Eq '(^|/)\._'; then
    echo "独立工具包包含 macOS AppleDouble 元数据文件，已停止生成。"
    exit 1
fi
if tar -tzf "$PACKAGE_PATH" | grep -Eq '(^|/)\.DS_Store'; then
    echo "独立工具包包含 .DS_Store，已停止生成。"
    exit 1
fi

PACKAGE_BYTES="$(stat -f '%z' "$PACKAGE_PATH" 2>/dev/null || stat -c '%s' "$PACKAGE_PATH" 2>/dev/null)"
if [ -z "$PACKAGE_BYTES" ] || [ "$PACKAGE_BYTES" -le 0 ] || [ "$PACKAGE_BYTES" -gt "$MAX_BYTES" ]; then
    echo "独立工具包大小异常或超过 ${MAX_BYTES} 字节，已停止生成。"
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    PACKAGE_SHA256="$(sha256sum "$PACKAGE_PATH" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    PACKAGE_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"
else
    echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
    exit 1
fi
printf '%s  %s\n' "$PACKAGE_SHA256" "$PACKAGE_NAME" > "$PACKAGE_PATH.sha256"

echo "独立工具包: $PACKAGE_PATH"
echo "独立工具校验: $PACKAGE_PATH.sha256"
