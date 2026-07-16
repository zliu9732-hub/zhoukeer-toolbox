#!/bin/bash

set -eu

PLUGIN_ID="${1:-}"
PLUGIN_ROOT="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"

case "$PLUGIN_ID" in
    lsfg)
        PLUGIN_NAME="Decky LSFG-VK（小黄鸭）"
        PLUGIN_URL="https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip"
        PLUGIN_SHA256="13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"
        PLUGIN_DIRECTORY="Decky LSFG-VK"
        PLUGIN_AUTHOR="xXJSONDeruloXx"
        ;;
    framegen)
        PLUGIN_NAME="Decky-Framegen（FSR4）"
        PLUGIN_URL="https://github.com/xXJSONDeruloXx/Decky-Framegen/releases/download/v0.15.6/Decky-Framegen.zip"
        PLUGIN_SHA256="236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"
        PLUGIN_DIRECTORY="Decky-Framegen"
        PLUGIN_AUTHOR="xXJSONDeruloXx"
        ;;
    cheatdeck)
        PLUGIN_NAME="CheatDeck"
        PLUGIN_URL="https://github.com/SheffeyG/CheatDeck/releases/download/v1.2.1/CheatDeck.zip"
        PLUGIN_SHA256="83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"
        PLUGIN_DIRECTORY="CheatDeck"
        PLUGIN_AUTHOR="SheffeyG"
        ;;
    *)
        echo "用法: $0 {lsfg|framegen|cheatdeck}"
        exit 2
        ;;
esac

for command_name in curl unzip find sha256sum; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "缺少命令：$command_name"
        exit 1
    }
done

[ -d "$PLUGIN_ROOT" ] || {
    echo "未找到 Decky 插件目录：$PLUGIN_ROOT"
    echo "请先安装 Decky Loader 并至少进入一次游戏模式。"
    exit 1
}

if [ -w "$PLUGIN_ROOT" ]; then
    RUN_AS_ROOT=0
else
    command -v sudo >/dev/null 2>&1 || {
        echo "插件目录无写入权限，且系统没有 sudo。"
        exit 1
    }
    RUN_AS_ROOT=1
fi

run_file_operation() {
    if [ "$RUN_AS_ROOT" -eq 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT INT TERM
ARCHIVE="$TMP_DIR/plugin.zip"
EXTRACT_DIR="$TMP_DIR/extracted"
STAGING_DIR="$PLUGIN_ROOT/.${PLUGIN_DIRECTORY}.new.$$"
BACKUP_DIR="$PLUGIN_ROOT/.${PLUGIN_DIRECTORY}.backup.$$"
TARGET_DIR="$PLUGIN_ROOT/$PLUGIN_DIRECTORY"

echo "正在从作者官方 GitHub Release 下载 $PLUGIN_NAME..."
curl --fail --location --show-error --progress-bar \
    --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 1200 --retry 3 --retry-delay 2 \
    --output "$ARCHIVE" "$PLUGIN_URL"

ACTUAL_SHA256="$(sha256sum "$ARCHIVE" | awk '{print tolower($1)}')"
if [ "$ACTUAL_SHA256" != "$PLUGIN_SHA256" ]; then
    echo "SHA256 校验失败，已停止安装。"
    echo "期望：$PLUGIN_SHA256"
    echo "实际：$ACTUAL_SHA256"
    exit 1
fi

if unzip -Z1 "$ARCHIVE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    echo "压缩包包含不安全路径，已停止安装。"
    exit 1
fi

mkdir -p "$EXTRACT_DIR"
unzip -q "$ARCHIVE" -d "$EXTRACT_DIR"
PLUGIN_SOURCE="$(find "$EXTRACT_DIR" -mindepth 2 -maxdepth 3 -type f -name plugin.json -print -quit)"
[ -n "$PLUGIN_SOURCE" ] || {
    echo "官方安装包中未找到 plugin.json。"
    exit 1
}
PLUGIN_SOURCE="$(dirname "$PLUGIN_SOURCE")"
[ "$(basename "$PLUGIN_SOURCE")" = "$PLUGIN_DIRECTORY" ] || {
    echo "官方安装包目录结构与预期不符，已停止安装。"
    exit 1
}
[ -s "$PLUGIN_SOURCE/dist/index.js" ] || {
    echo "官方安装包缺少 Decky 前端文件。"
    exit 1
}

run_file_operation rm -rf -- "$STAGING_DIR" "$BACKUP_DIR"
run_file_operation cp -a -- "$PLUGIN_SOURCE" "$STAGING_DIR"
if [ -e "$TARGET_DIR" ]; then
    run_file_operation mv -- "$TARGET_DIR" "$BACKUP_DIR"
fi
if ! run_file_operation mv -- "$STAGING_DIR" "$TARGET_DIR"; then
    if [ -e "$BACKUP_DIR" ] && [ ! -e "$TARGET_DIR" ]; then
        run_file_operation mv -- "$BACKUP_DIR" "$TARGET_DIR" || true
    fi
    echo "安装切换失败，已尽量恢复旧版本。"
    exit 1
fi
run_file_operation rm -rf -- "$BACKUP_DIR"

echo "$PLUGIN_NAME 已安装到 $TARGET_DIR"
echo "来源：$PLUGIN_URL"
echo "插件作者：$PLUGIN_AUTHOR，请支持插件原作者。"
echo "请完全退出游戏模式后重新进入一次，让 Decky 重新扫描插件。"
