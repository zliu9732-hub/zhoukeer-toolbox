#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
# 版本号规则：补丁位只允许 0 到 9；x.y.9 之后必须为 x.(y+1).0。
DIST_DIR="$PROJECT_ROOT/dist"
PACKAGE_NAME="renkit.tar.gz"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"
VERSIONED_PACKAGE_NAME="renkit-$VERSION.tar.gz"
VERSIONED_PACKAGE_PATH="$DIST_DIR/$VERSIONED_PACKAGE_NAME"
SHA256SUMS_PATH="$DIST_DIR/SHA256SUMS"
MAX_GITEE_RAW_PACKAGE_BYTES=9437184
VERIFY_FILES="VERSION LICENSE THIRD_PARTY_LICENSES.md main.sh launch.sh install.sh update.sh bootstrap.sh modules/software.sh modules/domestic_source.sh modules/new_machine.sh modules/network.sh modules/diagnostics.sh modules/preflight.sh modules/settings_backup.sh modules/steam_accelerator.sh modules/steam302_root_start.sh modules/console_accelerators.sh modules/plugin_store.sh modules/game_launchers.sh modules/emulators.sh modules/ge_proton.sh modules/todesk.sh modules/memory_tuning.sh modules/f1_screen_fix.sh modules/dual_system.sh modules/dual_system_tools.sh modules/clover_boot.sh scripts/steam_shortcut.py scripts/steam_compat.py scripts/install-decky-plugin.sh scripts/apply_steam_artwork.sh scripts/build_steam_artwork_payload.py scripts/decky_ws_call.py scripts/decky_probe.py scripts/open_steam_internal_browser.sh scripts/mirror_gitee_assets.sh core/gui.sh core/platform.sh core/download_policy.sh core/source_status.sh assets/icon.png assets/icon-round.png assets/icon-toolbox-deck.png assets/background.jpg assets/software/wechat.png assets/emulators/yuzu.png assets/emulators/cemu.png assets/emulators/duckstation.png assets/emulators/pcsx2.png assets/emulators/rpcs3.png assets/emulators/shadps4.png assets/clover/config.plist assets/clover/zhoukeer-phantom/background.png assets/clover/zhoukeer-phantom/theme.plist assets/clover/devices/SD-config.plist assets/clover/drivers/asusrogally.efi assets/clover/bootmanager/clover-bootmanager.sh third_party/decky-lsfg-vk-zh-v0.12.5/dist/index.js third_party/decky-framegen-zh-v0.17/dist/index.js third_party/decky-simpledeckytdp-zh-v1.0.5/dist/index.js third_party/decky-simpledeckytdp-zh-v1.0.5/plugin.json third_party/decky-simpledeckytdp-zh-v1.0.5/package.json third_party/allycenter-zh-v1.2.0/dist/index.js third_party/allycenter-zh-v1.2.0/plugin.json third_party/allycenter-zh-v1.2.0/package.json third_party/allycenter-zh-v1.2.0/LICENSE third_party/huesync-cn-v3.9.0/dist/index.js third_party/huesync-cn-v3.9.0/plugin.json third_party/huesync-cn-v3.9.0/package.json third_party/huesync-cn-v3.9.0/LICENSE third_party/legion-go-remapper-zh-v0.3.0/dist/index.js third_party/legion-go-remapper-zh-v0.3.0/plugin.json third_party/legion-go-remapper-zh-v0.3.0/package.json third_party/legion-go-remapper-zh-v0.3.0/LICENSE third_party/gpd-control-zh-v0.0.2/dist/index.js third_party/gpd-control-zh-v0.0.2/plugin.json third_party/gpd-control-zh-v0.0.2/package.json third_party/gpd-control-zh-v0.0.2/LICENSE third_party/lego-vibe-control-zh-v1.5.0/dist/index.js third_party/lego-vibe-control-zh-v1.5.0/plugin.json third_party/lego-vibe-control-zh-v1.5.0/package.json third_party/lego-vibe-control-zh-v1.5.0/LICENSE third_party/lego2-fan-control-zh-v0.260430/dist/index.js third_party/lego2-fan-control-zh-v0.260430/plugin.json third_party/lego2-fan-control-zh-v0.260430/package.json third_party/lego2-fan-control-zh-v0.260430/LICENSE utils/github_download.sh utils/gitee_download.sh"
VERIFY_FILES="$VERIFY_FILES scripts/set_user_password_pty.py"
PACKAGE_SOURCES=()

validate_release_version() {
    local major minor patch extra

    IFS='.' read -r major minor patch extra <<< "$VERSION"
    if [ -n "${extra:-}" ] || [ -z "${major:-}" ] || [ -z "${minor:-}" ] || [ -z "${patch:-}" ]; then
        echo "版本号必须是三段纯数字格式（例如 1.4.0）：$VERSION"
        exit 1
    fi
    case "$major:$minor:$patch" in
        *[!0-9:]* )
            echo "版本号必须是三段纯数字格式（例如 1.4.0）：$VERSION"
            exit 1
            ;;
    esac
    if [ "$patch" -gt 9 ]; then
        echo "补丁版本只允许 0 到 9；x.y.9 之后必须发布 x.(y+1).0：$VERSION"
        exit 1
    fi
}

validate_release_version

# Bazzite 使用独立主程序和官方 Decky 入口，发布包必须同时携带这两个文件。
VERIFY_FILES="$VERIFY_FILES main-bazzite.sh modules/bazzite_decky.sh assets/clover/bootmanager/clover-bootmanager.service assets/clover/bootmanager/clover-whitelist.conf"

mkdir -p "$DIST_DIR"

cd "$PROJECT_ROOT" || exit 1

# macOS 打包时排除扩展属性，避免 SteamOS 解压时产生无关警告
# 只打包 Git 已跟踪文件，避免把本机临时文件或未提交资料带入公开包。
while IFS= read -r -d '' source_path; do
    case "$source_path" in
        dist/*|mirrors/*|launcher-covers/*|decky-installer-cn/*|decky-plugins/zhoukeer-localizer/*|assets/background.png|assets/welcome.png|assets/disclaimer-usage.png|assets/windows-switch.png|assets/game-launchers/*|website/*|index.html|todesk.html) continue ;;
        third_party/decky-lsfg-vk-zh-v0.12.5/dist/*.map) continue ;;
        # FSR4 的 TypeScript 源码仅用于开发；安装器只会使用下列运行文件。
        # 不把整套源码塞进自更新包，避免 Gitee 对大文件原始下载返回 403。
        third_party/decky-framegen-zh-v0.17/*)
            case "$source_path" in
                third_party/decky-framegen-zh-v0.17/plugin.json|\
                third_party/decky-framegen-zh-v0.17/package.json|\
                third_party/decky-framegen-zh-v0.17/LICENSE|\
                third_party/decky-framegen-zh-v0.17/main.py|\
                third_party/decky-framegen-zh-v0.17/dist/assets/*|\
                third_party/decky-framegen-zh-v0.17/dist/index.js|\
                third_party/decky-framegen-zh-v0.17/defaults/*) ;;
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

# macOS 的 Finder/归档工具可能附加 AppleDouble（._*）元数据文件。
# SteamOS 端会将扩展名为 .sh 的这类二进制元数据误当 Bash 脚本，必须从发布包中彻底排除。
COPYFILE_DISABLE=1 tar \
    --no-xattrs \
    --exclude=".git" \
    --exclude=".DS_Store" \
    --exclude="._*" \
    --exclude="*/._*" \
    --exclude="logs" \
    --exclude="apps" \
    --exclude="decky-plugins/*/node_modules" \
    --exclude="*.save" \
    --exclude="*.bak.*" \
    --exclude="管理员密码.txt" \
    --exclude="config/settings.conf" \
    -czf "$PACKAGE_PATH" "${PACKAGE_SOURCES[@]}"

if PACKAGE_BYTES="$(stat -f '%z' "$PACKAGE_PATH" 2>/dev/null || stat -c '%s' "$PACKAGE_PATH" 2>/dev/null)" && \
    [ "$PACKAGE_BYTES" -le "$MAX_GITEE_RAW_PACKAGE_BYTES" ]; then
    :
else
    echo "发布包超过 Gitee Raw 下载安全上限（9 MiB），已停止发布。"
    rm -f -- "$PACKAGE_PATH" "$SHA256SUMS_PATH"
    exit 1
fi

if tar -tzf "$PACKAGE_PATH" | grep -Eq '(^|/)\._'; then
    echo "发布包包含 macOS AppleDouble 元数据文件，已停止发布。"
    rm -f -- "$PACKAGE_PATH" "$SHA256SUMS_PATH"
    exit 1
fi

for packaged_file in $VERIFY_FILES; do
    if ! tar -xOf "$PACKAGE_PATH" "./$packaged_file" | \
        cmp -s - "$PROJECT_ROOT/$packaged_file"; then
        echo "发布包内容与当前源码不一致：$packaged_file"
        rm -f -- "$PACKAGE_PATH" "$SHA256SUMS_PATH"
        exit 1
    fi
done

cp "$PACKAGE_PATH" "$VERSIONED_PACKAGE_PATH"
# 保留旧发布名作为兼容别名，原有下载链接不会失效。
cp "$PACKAGE_PATH" "$DIST_DIR/zhoukeer-toolbox.tar.gz"

if command -v sha256sum >/dev/null 2>&1; then
    PACKAGE_SHA256="$(sha256sum "$PACKAGE_PATH" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    PACKAGE_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"
else
    echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
    exit 1
fi

printf '%s  %s\n' "$PACKAGE_SHA256" "$PACKAGE_NAME" > "$SHA256SUMS_PATH"
printf '%s  %s\n' "$PACKAGE_SHA256" "zhoukeer-toolbox.tar.gz" >> "$SHA256SUMS_PATH"
printf '%s  %s\n' "$PACKAGE_SHA256" "$VERSIONED_PACKAGE_NAME" > \
    "$VERSIONED_PACKAGE_PATH.sha256"

echo "仓库更新包: $PACKAGE_PATH"
echo "旧链接兼容包: $DIST_DIR/zhoukeer-toolbox.tar.gz"
echo "Release发布包: $VERSIONED_PACKAGE_PATH"
echo "Release校验文件: $VERSIONED_PACKAGE_PATH.sha256"
echo "仓库校验文件: $SHA256SUMS_PATH"
