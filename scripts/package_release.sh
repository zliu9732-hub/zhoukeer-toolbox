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
VERIFY_FILES="VERSION main.sh launch.sh install.sh update.sh bootstrap.sh modules/software.sh modules/domestic_source.sh modules/steam_accelerator.sh modules/steam302_root_start.sh modules/plugin_store.sh modules/game_launchers.sh modules/ge_proton.sh modules/todesk.sh modules/memory_tuning.sh modules/clover_boot.sh modules/dual_system.sh modules/dual_system_tools.sh scripts/steam_shortcut.py scripts/install-decky-plugin.sh core/gui.sh core/platform.sh assets/icon.png assets/icon-round.png assets/clover/config.plist assets/clover/zhoukeer-phantom/theme.plist assets/clover/zhoukeer-phantom/background.png third_party/decky-lsfg-vk-zh-v0.12.5/dist/index.js third_party/decky-framegen-zh-v0.15.6/dist/index.js utils/github_download.sh"
PACKAGE_SOURCES=()

mkdir -p "$DIST_DIR"

cd "$PROJECT_ROOT" || exit 1

# macOS 打包时排除扩展属性，避免 SteamOS 解压时产生无关警告
# 只打包 Git 已跟踪文件，避免把本机临时文件或未提交资料带入公开包。
while IFS= read -r -d '' source_path; do
    case "$source_path" in
        dist/*|decky-plugins/zhoukeer-localizer/*) continue ;;
        third_party/decky-lsfg-vk-zh-v0.12.5/dist/*.map) continue ;;
        # FSR4 的 TypeScript 源码仅用于开发；安装器只会使用下列运行文件。
        # 不把整套源码塞进自更新包，避免 Gitee 对大文件原始下载返回 403。
        third_party/decky-framegen-zh-v0.15.6/*)
            case "$source_path" in
                third_party/decky-framegen-zh-v0.15.6/plugin.json|\
                third_party/decky-framegen-zh-v0.15.6/package.json|\
                third_party/decky-framegen-zh-v0.15.6/LICENSE|\
                third_party/decky-framegen-zh-v0.15.6/main.py|\
                third_party/decky-framegen-zh-v0.15.6/dist/assets/*|\
                third_party/decky-framegen-zh-v0.15.6/dist/index.js|\
                third_party/decky-framegen-zh-v0.15.6/defaults/*) ;;
                *) continue ;;
            esac
            ;;
    esac
    PACKAGE_SOURCES+=("./$source_path")
done < <(git ls-files -z)

if [ "${#PACKAGE_SOURCES[@]}" -eq 0 ]; then
    echo "没有找到可打包的 Git 已跟踪文件。"
    exit 1
fi

tar \
    --no-xattrs \
    --exclude=".git" \
    --exclude=".DS_Store" \
    --exclude="logs" \
    --exclude="apps" \
    --exclude="decky-plugins/*/node_modules" \
    --exclude="*.save" \
    --exclude="*.bak.*" \
    --exclude="管理员密码.txt" \
    --exclude="config/settings.conf" \
    -czf "$PACKAGE_PATH" "${PACKAGE_SOURCES[@]}"

for packaged_file in $VERIFY_FILES; do
    if ! tar -xOf "$PACKAGE_PATH" "./$packaged_file" | \
        cmp -s - "$PROJECT_ROOT/$packaged_file"; then
        echo "发布包内容与当前源码不一致：$packaged_file"
        rm -f -- "$PACKAGE_PATH" "$SHA256SUMS_PATH"
        exit 1
    fi
done

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
