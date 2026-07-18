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
        battlenet)
            LAUNCHER_NAME="战网启动器"
            LAUNCHER_FILE_NAME="Battle.net-Setup.exe"
            LAUNCHER_URL="https://www.battle.net/download/getInstallerForGame?os=win&installer=Battle.net-Setup.exe"
            LAUNCHER_MIN_BYTES=1048576
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Battle.net/Battle.net Launcher.exe\nProgram Files (x86)/Battle.net/Battle.net.exe'
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


run_launcher_installer() {
    local target="$1"
    local steam_root="$2"
    local installer_file="$3"
    local prefix_dir="$4"
    local proton_runner="$5"
    local status=0
    local elapsed=0
    local installed_file
    local timeout="${6:-$POST_INSTALL_TIMEOUT}"

    launcher_details "$target" || return 1
    mkdir -p "$prefix_dir" || return 1
    echo "正在使用 $(basename "$(dirname "$proton_runner")") 直接打开 $LAUNCHER_NAME 官方安装器..." >&2
    echo "请在弹出的官方窗口中按提示完成安装；无需进入 Steam 选择兼容层。" >&2

    case "$target" in
        epic)
            STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root"             STEAM_COMPAT_DATA_PATH="$prefix_dir"             STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0                 "$proton_runner" run msiexec /i "$installer_file" || status=$?
            ;;
        battlenet)
            STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                "$proton_runner" run "$installer_file" || status=$?
            ;;
    esac

    while [ "$elapsed" -le "$timeout" ]; do
        installed_file="$(find_launcher_in_prefix "$prefix_dir" || true)"
        if [ -n "$installed_file" ]; then
            printf '%s
' "$installed_file"
            return 0
        fi
        [ "$elapsed" -eq 0 ] && echo "官方安装器已退出，正在确认主程序文件..." >&2
        sleep "$POST_INSTALL_INTERVAL"
        elapsed=$((elapsed + POST_INSTALL_INTERVAL))
    done
    echo "没有在预期位置找到 $LAUNCHER_NAME 主程序。" >&2
    if [ "$status" -ne 0 ]; then
        echo "官方安装器退出码：$status" >&2
    fi
    echo "请确认没有在官方安装窗口中取消安装，然后重试。已下载的安装包和前缀会保留。" >&2
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

find_battlenet_alternate_runner() {
    local steam_root="$1" current_runner="$2" candidate
    for candidate in "$(find_proton_experimental_runner "$steam_root" || true)" "$(find_proton_10_runner "$steam_root" || true)"; do
        [ -n "$candidate" ] && [ "$candidate" != "$current_runner" ] && {
            printf '%s\n' "$candidate"
            return 0
        }
    done
    return 1
}

create_launcher_wrapper() {
    local target="$1" steam_root="$2" prefix_dir="$3" proton_runner="$4" launcher_exe="$5" destination_dir="$6"
    local wrapper="$destination_dir/launch-$target.sh"
    mkdir -p "$destination_dir" || return 1
    cat > "$wrapper" <<EOF
#!/bin/bash
PREFIX_DIR=$(printf '%q' "$prefix_dir")
PROTON_RUNNER=$(printf '%q' "$proton_runner")
LAUNCHER_EXE=$(printf '%q' "$launcher_exe")
STEAM_ROOT=$(printf '%q' "$steam_root")
export STEAM_COMPAT_DATA_PATH="\$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$STEAM_ROOT"
exec "\$PROTON_RUNNER" run "\$LAUNCHER_EXE"
EOF
    chmod +x "$wrapper" || return 1
    printf '%s\n' "$wrapper"
}

create_launcher_desktop_shortcut() {
    local target="$1" wrapper="$2" name
    case "$target" in
        epic) name="Epic Games 启动器" ;;
        battlenet) name="战网启动器" ;;
        *) return 1 ;;
    esac
    mkdir -p "$HOME/Desktop" || return 1
    cat > "$HOME/Desktop/$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$wrapper
Terminal=false
Categories=Game;
EOF
    chmod +x "$HOME/Desktop/$name.desktop"
}

run_battlenet_installer_with_fallback() {
    local steam_root="$1" installer_file="$2" prefix_dir="$3" runner="$4" alternate installed
    launcher_details battlenet || return 1
    POST_INSTALL_TIMEOUT="$BATTLE_NET_FIRST_ATTEMPT_TIMEOUT" run_launcher_installer battlenet "$steam_root" "$installer_file" "$prefix_dir" "$runner" || true
    installed="$(find_launcher_in_prefix "$prefix_dir" || true)"
    if [ -n "$installed" ]; then
        printf '%s|%s\n' "$installed" "$runner"
        return 0
    fi
    alternate="$(find_battlenet_alternate_runner "$steam_root" "$runner")" || return 1
    installed="$(run_launcher_installer battlenet "$steam_root" "$installer_file" "$prefix_dir" "$alternate")" || return 1
    printf '%s|%s\n' "$installed" "$alternate"
}

install_launcher() {
    local target="$1" steam_root launcher_exe runner app_dir prefix wrapper shortcut_file
    launcher_details "$target" || return 1
    steam_root="$(find_steam_root)" || return 1
    launcher_exe="$(find_installed_launcher "$steam_root" || true)"
    runner="$(find_proton_runner "$steam_root")" || { echo "未找到可用 Proton/GE-Proton。"; return 1; }
    app_dir="$APP_DIR/game-launchers/$target"
    mkdir -p "$app_dir" || return 1

    if [ -n "$launcher_exe" ]; then
        echo "检测到已安装的 ${LAUNCHER_NAME}，跳过安装包下载。"
        prefix="${launcher_exe%/pfx/drive_c/*}"
    else
        echo "当前版本仅支持已安装启动器的自动入库，请先完成官方安装。"
        return 1
    fi
    wrapper="$(create_launcher_wrapper "$target" "$steam_root" "$prefix" "$runner" "$launcher_exe" "$app_dir")" || return 1
    create_launcher_desktop_shortcut "$target" "$wrapper" || return 1
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    stop_steam_for_vdf || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$wrapper" --start-dir "$app_dir" >/dev/null || return 1
    start_steam
    echo "$LAUNCHER_NAME 已添加到 Steam 库，无需再选择兼容层。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        epic|battlenet) install_launcher "$1" ;;
        *) echo "用法: $0 {epic|battlenet}"; exit 1 ;;
    esac
fi
