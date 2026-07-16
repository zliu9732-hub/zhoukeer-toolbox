#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

DOWNLOAD_TIMEOUT="${ZHOUKEER_LAUNCHER_DOWNLOAD_TIMEOUT:-600}"
WATCH_TIMEOUT="${ZHOUKEER_LAUNCHER_WATCH_TIMEOUT:-7200}"
WATCH_INTERVAL="${ZHOUKEER_LAUNCHER_WATCH_INTERVAL:-10}"
STEAM_SHORTCUT_HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"

launcher_details() {
    case "$1" in
        epic)
            LAUNCHER_NAME="Epic Games 启动器"
            LAUNCHER_FILE_NAME="EpicGamesLauncherInstaller.msi"
            LAUNCHER_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
            LAUNCHER_MIN_BYTES=52428800
            LAUNCHER_MAGIC="d0cf11e0"
            LAUNCHER_TARGET_RELATIVE="Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
            ;;
        battlenet)
            LAUNCHER_NAME="战网启动器"
            LAUNCHER_FILE_NAME="Battle.net-Setup.exe"
            LAUNCHER_URL="https://www.battle.net/download/getInstallerForGame?os=win&installer=Battle.net-Setup.exe"
            LAUNCHER_MIN_BYTES=1048576
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVE="Program Files (x86)/Battle.net/Battle.net.exe"
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

find_steam_root() {
    local candidate

    if [ -n "${ZHOUKEER_STEAM_ROOT:-}" ] && [ -d "$ZHOUKEER_STEAM_ROOT/steamapps" ]; then
        printf '%s\n' "$ZHOUKEER_STEAM_ROOT"
        return 0
    fi
    for candidate in "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
        if [ -d "$candidate/steamapps" ] && [ -d "$candidate/userdata" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    echo "未找到已初始化的 Steam 库。请先正常打开 Steam 并登录一次后再试。" >&2
    return 1
}

find_shortcut_file() {
    local steam_root="$1"
    local candidate
    local newest=""
    local newest_time=0
    local modified

    if [ -n "${ZHOUKEER_SHORTCUT_FILE:-}" ]; then
        printf '%s\n' "$ZHOUKEER_SHORTCUT_FILE"
        return 0
    fi
    while IFS= read -r -d '' candidate; do
        modified="$(stat -c '%Y' "$candidate" 2>/dev/null || printf '0')"
        if [ "$modified" -ge "$newest_time" ]; then
            newest="$candidate"
            newest_time="$modified"
        fi
    done < <(find "$steam_root/userdata" -mindepth 2 -maxdepth 2 -type d -name config -print0 2>/dev/null)

    if [ -z "$newest" ]; then
        echo "未找到 Steam 当前账号的 userdata/config。请先完整登录 Steam 后再试。" >&2
        return 1
    fi
    printf '%s/shortcuts.vdf\n' "$newest"
}

steam_is_running() {
    command -v pgrep >/dev/null 2>&1 && pgrep -u "$(id -u)" -x steam >/dev/null 2>&1
}

steam_command() {
    if command -v steam >/dev/null 2>&1; then
        command -v steam
    elif [ -x "$HOME/.steam/steam/steam.sh" ]; then
        printf '%s\n' "$HOME/.steam/steam/steam.sh"
    else
        return 1
    fi
}

stop_steam_for_vdf() {
    local steam_bin
    local attempt

    [ "${ZHOUKEER_SKIP_STEAM_RESTART:-0}" = "1" ] && return 0
    steam_is_running || return 0
    steam_bin="$(steam_command)" || {
        echo "Steam 正在运行，但找不到 Steam 启动命令，无法安全写入非 Steam 游戏列表。"
        return 1
    }
    echo "正在让 Steam 安全退出，以写入非 Steam 游戏条目..."
    "$steam_bin" -shutdown >/dev/null 2>&1 || true
    for attempt in $(seq 1 20); do
        steam_is_running || return 0
        sleep 1
    done
    echo "Steam 未能在 20 秒内退出。请确认没有游戏运行后重试，原有库未被修改。"
    return 1
}

start_steam() {
    local steam_bin

    [ "${ZHOUKEER_SKIP_STEAM_RESTART:-0}" = "1" ] && return 0
    steam_bin="$(steam_command)" || return 0
    "$steam_bin" >/dev/null 2>&1 &
}

find_installed_launcher() {
    local steam_root="$1"
    local relative_path="$2"
    local candidate

    [ -d "$steam_root/steamapps/compatdata" ] || return 1
    candidate="$(find "$steam_root/steamapps/compatdata" -type f \
        -path "*/pfx/drive_c/$relative_path" -print -quit 2>/dev/null)"
    [ -n "$candidate" ] || return 1
    printf '%s\n' "$candidate"
}

notify_launcher_ready() {
    local name="$1"
    local message="$name 已安装完成，Steam 条目已自动切换到启动器本体。"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "周克儿工具箱" "$message" >/dev/null 2>&1 || true
    fi
    echo "$message"
}

watch_for_installed_launcher() {
    local target="$1"
    local steam_root="$2"
    local shortcut_file="$3"
    local installer_file="$4"
    local elapsed=0
    local installed_file

    launcher_details "$target" || return 1
    while [ "$elapsed" -lt "$WATCH_TIMEOUT" ]; do
        installed_file="$(find_installed_launcher "$steam_root" "$LAUNCHER_TARGET_RELATIVE" || true)"
        if [ -n "$installed_file" ]; then
            stop_steam_for_vdf || return 1
            python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" update \
                --old-exe "$installer_file" --new-exe "$installed_file" || return 1
            start_steam
            notify_launcher_ready "$LAUNCHER_NAME"
            log "$LAUNCHER_NAME 已自动切换到安装后的主EXE: $installed_file"
            return 0
        fi
        sleep "$WATCH_INTERVAL"
        elapsed=$((elapsed + WATCH_INTERVAL))
    done
    echo "$LAUNCHER_NAME 安装监测已到时；下次点击工具箱中的同一安装项会重新检测。"
    return 0
}

start_launcher_watch() {
    local target="$1"
    local steam_root="$2"
    local shortcut_file="$3"
    local installer_file="$4"
    local log_dir="$APP_DIR/game-launchers/logs"

    mkdir -p "$log_dir" || return 1
    nohup /usr/bin/env bash "$PROJECT_ROOT/modules/game_launchers.sh" watch \
        "$target" "$steam_root" "$shortcut_file" "$installer_file" \
        > "$log_dir/${target}-watch.log" 2>&1 &
}

install_launcher() {
    local target="$1"
    local launcher_dir
    local installer_file
    local temp_file
    local steam_root
    local shortcut_file
    local shortcut_exe
    local installed_file

    launcher_details "$target" || return 1
    for command_name in curl od python3; do
        command -v "$command_name" >/dev/null 2>&1 || {
            echo "系统缺少 $command_name，无法继续。"
            return 1
        }
    done
    [ -f "$STEAM_SHORTCUT_HELPER" ] || {
        echo "Steam 入库组件缺失，请更新工具箱后再试。"
        return 1
    }

    steam_root="$(find_steam_root)" || return 1
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    launcher_dir="$APP_DIR/game-launchers/$target"
    installer_file="$launcher_dir/$LAUNCHER_FILE_NAME"
    mkdir -p "$launcher_dir" || return 1

    if [ ! -f "$installer_file" ]; then
        temp_file="$(mktemp "$launcher_dir/.${target}-installer.XXXXXX")" || return 1
        trap 'rm -f "$temp_file"' EXIT
        echo "正在下载 $LAUNCHER_NAME 官方 Windows 安装包..."
        if ! curl -fL --retry 2 --connect-timeout 15 --max-time "$DOWNLOAD_TIMEOUT" \
            -o "$temp_file" "$LAUNCHER_URL"; then
            echo "下载失败或超时，未创建 Steam 条目。"
            return 1
        fi
        verify_installer "$temp_file" || return 1
        mv -f "$temp_file" "$installer_file" || return 1
        trap - EXIT
    fi
    verify_installer "$installer_file" || return 1

    installed_file="$(find_installed_launcher "$steam_root" "$LAUNCHER_TARGET_RELATIVE" || true)"
    shortcut_exe="${installed_file:-$installer_file}"

    stop_steam_for_vdf || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$shortcut_exe" \
        --start-dir "$(dirname "$shortcut_exe")" || return 1
    if [ -z "$installed_file" ]; then
        start_launcher_watch "$target" "$steam_root" "$shortcut_file" "$installer_file" || return 1
    fi
    start_steam

    if [ -n "$installed_file" ]; then
        echo "$LAUNCHER_NAME 已安装，已确认 Steam 条目直接指向主 EXE。"
    else
        echo "$LAUNCHER_NAME 已加入 Steam 非 Steam 游戏列表。"
        echo "首次请在 Steam 库运行它，并在兼容性中选择 PE 或 GE-Proton 10.0-4 后完成官方安装。"
        echo "工具箱会检测同一 compatdata/pfx/drive_c 内的主 EXE，并自动把原 Steam 条目切换到启动器本体。"
    fi
    log "$LAUNCHER_NAME 安装器已下载或复用，并已加入Steam: $shortcut_exe"
}

case "${1:-}" in
    epic|battlenet) install_launcher "$1" ;;
    watch) watch_for_installed_launcher "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
    *) echo "用法: $0 {epic|battlenet}"; exit 1 ;;
esac
