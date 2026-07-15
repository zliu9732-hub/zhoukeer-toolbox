#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

DOWNLOAD_TIMEOUT="${ZHOUKEER_LAUNCHER_DOWNLOAD_TIMEOUT:-600}"

launcher_details() {
    case "$1" in
        epic)
            LAUNCHER_NAME="Epic Games 启动器"
            LAUNCHER_FILE="$HOME/Desktop/EpicInstaller.msi"
            LAUNCHER_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
            LAUNCHER_MIN_BYTES=52428800
            LAUNCHER_MAGIC="d0cf11e0"
            ;;
        battlenet)
            LAUNCHER_NAME="战网启动器"
            LAUNCHER_FILE="$HOME/Desktop/Battle.net-Setup.exe"
            LAUNCHER_URL="https://www.battle.net/download/getInstallerForGame?os=win&installer=Battle.net-Setup.exe"
            LAUNCHER_MIN_BYTES=1048576
            LAUNCHER_MAGIC="4d5a"
            ;;
        *)
            echo "未知启动器: $1"
            return 1
            ;;
    esac
}

verify_installer() {
    local file="$1"
    local size magic
    size="$(wc -c < "$file" | tr -d ' ')"
    magic="$(od -An -tx1 -N4 "$file" | tr -d ' \n')"

    if [ "${size:-0}" -lt "$LAUNCHER_MIN_BYTES" ]; then
        echo "下载文件过小，已保留原有安装包。"
        return 1
    fi
    if [ "${magic#"$LAUNCHER_MAGIC"}" = "$magic" ]; then
        echo "下载文件格式不正确，已保留原有安装包。"
        return 1
    fi
}

show_add_to_steam_steps() {
    echo ""
    echo "下一步只需这样做："
    echo "1. 在桌面文件夹中右键 $LAUNCHER_FILE，选择“Add to Steam”。"
    echo "2. 打开 Steam → 库 → 非 Steam 游戏 → 选中 $LAUNCHER_NAME。"
    echo "3. 齿轮 → 属性 → 兼容性 → 强制使用 PE（Proton Experimental）或 GE-Proton 10-4。"
    echo "4. 从 Steam 启动安装包，完成安装。"
    echo "5. 仍在同一个 Steam 条目的 齿轮 → 属性 → 快捷方式 → 目标 中，改选安装目录里的真正启动器 EXE。"
    case "$1" in
        epic)
            echo "   Epic 目标文件：Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
            ;;
        battlenet)
            echo "   战网目标文件：Program Files (x86)/Battle.net/Battle.net.exe"
            ;;
    esac
    echo "提示：不要把已安装的 EXE 另加成一个新条目；在原条目换目标才能保留已安装的兼容环境。"
}

install_launcher() {
    local target="$1"
    local temp_file

    launcher_details "$target" || return 1
    command -v curl >/dev/null 2>&1 || { echo "系统缺少 curl，无法下载。"; return 1; }
    command -v od >/dev/null 2>&1 || { echo "系统缺少文件校验组件，已停止。"; return 1; }
    command -v timeout >/dev/null 2>&1 || { echo "系统缺少限时下载组件，已停止。"; return 1; }

    mkdir -p "$HOME/Desktop" || return 1
    temp_file="$(mktemp "$HOME/Desktop/.${target}-installer.XXXXXX")" || return 1
    trap 'rm -f "$temp_file"' EXIT

    echo "正在下载 $LAUNCHER_NAME 官方 Windows 安装包..."
    if ! timeout "$DOWNLOAD_TIMEOUT" curl -fL --retry 2 --connect-timeout 15 -o "$temp_file" "$LAUNCHER_URL"; then
        echo "下载失败或超时，已保留原有安装包。"
        return 1
    fi
    verify_installer "$temp_file" || return 1

    mv -f "$temp_file" "$LAUNCHER_FILE"
    trap - EXIT
    echo "$LAUNCHER_NAME 安装包已保存到：$LAUNCHER_FILE"
    show_add_to_steam_steps "$target"
    log "$LAUNCHER_NAME 官方安装包已下载: $LAUNCHER_FILE"

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$HOME/Desktop" >/dev/null 2>&1 &
    fi
}

case "${1:-}" in
    epic|battlenet) install_launcher "$1" ;;
    *) echo "用法: $0 [epic|battlenet]"; exit 1 ;;
esac
