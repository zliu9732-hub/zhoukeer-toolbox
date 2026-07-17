#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

DOWNLOAD_TIMEOUT="${ZHOUKEER_LAUNCHER_DOWNLOAD_TIMEOUT:-600}"
POST_INSTALL_TIMEOUT="${ZHOUKEER_LAUNCHER_POST_INSTALL_TIMEOUT:-300}"
POST_INSTALL_INTERVAL="${ZHOUKEER_LAUNCHER_POST_INSTALL_INTERVAL:-5}"
BATTLE_NET_FIRST_ATTEMPT_TIMEOUT="${ZHOUKEER_BATTLENET_FIRST_ATTEMPT_TIMEOUT:-75}"
STEAM_SHORTCUT_HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"

launcher_details() {
    case "$1" in
        epic)
            LAUNCHER_NAME="Epic Games 启动器"
            LAUNCHER_FILE_NAME="EpicGamesLauncherInstaller.msi"
            LAUNCHER_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
            LAUNCHER_MIN_BYTES=52428800
            LAUNCHER_MAGIC="d0cf11e0"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe\nProgram Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe'
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

find_launcher_in_prefix() {
    local prefix_dir="$1"
    local relative_path

    while IFS= read -r relative_path; do
        [ -n "$relative_path" ] || continue
        if [ -f "$prefix_dir/pfx/drive_c/$relative_path" ]; then
            printf '%s\n' "$prefix_dir/pfx/drive_c/$relative_path"
            return 0
        fi
    done <<< "$LAUNCHER_TARGET_RELATIVES"
    return 1
}

find_installed_launcher() {
    local steam_root="$1"
    local relative_path
    local candidate

    [ -d "$steam_root/steamapps/compatdata" ] || return 1
    while IFS= read -r relative_path; do
        [ -n "$relative_path" ] || continue
        candidate="$(find "$steam_root/steamapps/compatdata" -type f \
            -path "*/pfx/drive_c/$relative_path" -print -quit 2>/dev/null)"
        if [ -n "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done <<< "$LAUNCHER_TARGET_RELATIVES"
    return 1
}

find_proton_runner() {
    local steam_root="$1"
    local compatibility_root
    local candidate

    if [ -n "${ZHOUKEER_PROTON_RUNNER:-}" ] && [ -x "$ZHOUKEER_PROTON_RUNNER" ]; then
        printf '%s
' "$ZHOUKEER_PROTON_RUNNER"
        return 0
    fi

    # Proton Experimental 优先
    for candidate in \
        "$steam_root/steamapps/common/Proton - Experimental/proton" \
        "$steam_root/steamapps/common/Proton 10.0/proton"; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    # 其次 GE-Proton
    for compatibility_root in \
        "$HOME/.steam/root/compatibilitytools.d" \
        "$HOME/.steam/steam/compatibilitytools.d" \
        "$HOME/.local/share/Steam/compatibilitytools.d" \
        "$steam_root/compatibilitytools.d"; do
        [ -d "$compatibility_root" ] || continue
        candidate="$(find "$compatibility_root" -mindepth 2 -maxdepth 2 \
            -type f -path '*/GE-Proton*/proton' -perm -u+x -print 2>/dev/null | \
            sort -V | tail -n 1)"
        if [ -n "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_proton_experimental_runner() {
    local steam_root="$1"
    local candidate

    for candidate in \
        "$steam_root/steamapps/common/Proton - Experimental/proton" \
        "$HOME/.steam/root/compatibilitytools.d/Proton - Experimental/proton"; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

find_proton_10_runner() {
    local steam_root="$1"
    local candidate

    candidate="$(find "$steam_root/steamapps/common" -mindepth 2 -maxdepth 2 \
        -type f -path '*/Proton 10.0*/proton' -perm -u+x -print 2>/dev/null | \
        LC_ALL=C sort | tail -n 1)"
    if [ -n "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

