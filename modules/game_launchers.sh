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
            LAUNCHER_TARGET_RELATIVES="Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
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

find_proton_runner() {
    local steam_root="$1"
    local compatibility_root
    local candidate

    if [ -n "${ZHOUKEER_PROTON_RUNNER:-}" ] && [ -x "$ZHOUKEER_PROTON_RUNNER" ]; then
        printf '%s\n' "$ZHOUKEER_PROTON_RUNNER"
        return 0
    fi

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

    for candidate in \
        "$steam_root/steamapps/common/Proton - Experimental/proton" \
        "$steam_root/steamapps/common/Proton 10.0/proton"; do
        if [ -x "$candidate" ]; then
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
    local steam_root="$1"
    local current_runner="$2"
    local alternate

    # Battle.net 在不同客户端版本下对 PE 和 Proton 10.0-4 的兼容性不同。
    # 首次失败时只在这两套官方兼容层间切换，不会随意更换用户的 GE-Proton。
    case "$current_runner" in
        *'/Proton - Experimental/proton')
            alternate="$(find_proton_10_runner "$steam_root" || true)"
            ;;
        *'/Proton 10.0'*'/proton')
            alternate="$(find_proton_experimental_runner "$steam_root" || true)"
            ;;
        *)
            alternate="$(find_proton_10_runner "$steam_root" || true)"
            [ -n "$alternate" ] || \
                alternate="$(find_proton_experimental_runner "$steam_root" || true)"
            ;;
    esac

    [ -n "$alternate" ] && [ "$alternate" != "$current_runner" ] || return 1
    printf '%s\n' "$alternate"
}

ensure_proton_runner() {
    local steam_root="$1"
    local runner

    runner="$(find_proton_runner "$steam_root" || true)"
    if [ -n "$runner" ]; then
        printf '%s\n' "$runner"
        return 0
    fi

    echo "未检测到可直接调用的 GE-Proton 或 Proton Experimental。" >&2
    echo "正在自动安装工具箱内置的 GE-Proton，完成后继续启动官方安装器..." >&2
    if ! bash "$PROJECT_ROOT/modules/ge_proton.sh" install >&2; then
        echo "GE-Proton 自动安装失败，启动器尚未写入 Steam。" >&2
        return 1
    fi
    runner="$(find_proton_runner "$steam_root" || true)"
    [ -n "$runner" ] || {
        echo "GE-Proton 已安装，但没有找到 proton 启动文件。" >&2
        return 1
    }
    printf '%s\n' "$runner"
}

ensure_battlenet_runner() {
    local steam_root="$1"
    local runner

    # 战网只在 PE 与 Proton 10.0-4 之间自动选择，避免客户还要进入
    # Steam 兼容性页面手动试错。显式设置的调试兼容层仍优先保留。
    if [ -n "${ZHOUKEER_PROTON_RUNNER:-}" ] && [ -x "$ZHOUKEER_PROTON_RUNNER" ]; then
        printf '%s\n' "$ZHOUKEER_PROTON_RUNNER"
        return 0
    fi
    runner="$(find_proton_experimental_runner "$steam_root" || true)"
    if [ -n "$runner" ]; then
        printf '%s\n' "$runner"
        return 0
    fi
    runner="$(find_proton_10_runner "$steam_root" || true)"
    if [ -n "$runner" ]; then
        printf '%s\n' "$runner"
        return 0
    fi

    # 两套官方兼容层都不存在时，才回退到工具箱原有的 GE-Proton 方案，
    # 并在首次失败后提示用户安装 PE 或 Proton 10.0-4。
    ensure_proton_runner "$steam_root"
}

notify_launcher_ready() {
    local name="$1"
    local message="$name 已安装完成，Steam 条目和桌面启动图标都已生成。"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "周克儿工具箱" "$message" >/dev/null 2>&1 || true
    fi
    echo "$message"
}

desktop_exec_escape() {
    local value="$1"

    case "$value" in
        *$'\n'*|*$'\r'*) return 1 ;;
    esac
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

create_launcher_desktop_shortcut() {
    local name="$1"
    local wrapper_file="$2"
    local launcher_dir="$3"
    local desktop_dir="$HOME/Desktop"
    local desktop_file="$desktop_dir/$name.desktop"
    local temporary_file
    local escaped_wrapper
    local escaped_dir

    escaped_wrapper="$(desktop_exec_escape "$wrapper_file")" || return 1
    escaped_dir="$(desktop_exec_escape "$launcher_dir")" || return 1
    mkdir -p -- "$desktop_dir" || return 1
    temporary_file="$(mktemp "$desktop_dir/.${name}.XXXXXX")" || return 1
    {
        printf '%s\n' '[Desktop Entry]' 'Type=Application'
        printf 'Name=%s\n' "$name"
        printf 'Exec=%s\n' "$escaped_wrapper"
        printf 'Path=%s\n' "$escaped_dir"
        printf '%s\n' 'Icon=steam' 'Terminal=false' 'Categories=Game;'
    } > "$temporary_file" || {
        rm -f -- "$temporary_file"
        return 1
    }
    chmod 755 "$temporary_file" || {
        rm -f -- "$temporary_file"
        return 1
    }
    mv -f -- "$temporary_file" "$desktop_file" || {
        rm -f -- "$temporary_file"
        return 1
    }
    printf '%s\n' "$desktop_file"
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
            STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" \
            STEAM_COMPAT_DATA_PATH="$prefix_dir" \
            STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                "$proton_runner" run msiexec /i "$installer_file" || status=$?
            ;;
        battlenet)
            STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" \
            STEAM_COMPAT_DATA_PATH="$prefix_dir" \
            STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                "$proton_runner" run "$installer_file" || status=$?
            ;;
    esac

    while [ "$elapsed" -le "$timeout" ]; do
        installed_file="$(find_launcher_in_prefix "$prefix_dir" || true)"
        if [ -n "$installed_file" ]; then
            printf '%s\n' "$installed_file"
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

run_battlenet_installer_with_fallback() {
    local steam_root="$1"
    local installer_file="$2"
    local prefix_dir="$3"
    local primary_runner="$4"
    local alternate_runner

    local installed_file

    if installed_file="$(run_launcher_installer battlenet "$steam_root" "$installer_file" "$prefix_dir" \
        "$primary_runner" "$BATTLE_NET_FIRST_ATTEMPT_TIMEOUT")"; then
        printf '%s|%s\n' "$installed_file" "$primary_runner"
        return 0
    fi

    alternate_runner="$(find_battlenet_alternate_runner "$steam_root" "$primary_runner" || true)"
    if [ -z "$alternate_runner" ]; then
        echo "战网首次启动失败，未找到另一套 Proton Experimental 或 Proton 10.0-4 可切换。" >&2
        echo "请在 Steam 的兼容工具列表安装其中一套后，再点击工具箱中的战网安装。" >&2
        return 1
    fi

    echo "战网首次未完成，正在从 $(basename "$(dirname "$primary_runner")") 切换到 $(basename "$(dirname "$alternate_runner")") 重试..." >&2
    installed_file="$(run_launcher_installer battlenet "$steam_root" "$installer_file" "$prefix_dir" \
        "$alternate_runner")" || return 1
    printf '%s|%s\n' "$installed_file" "$alternate_runner"
}

create_launcher_wrapper() {
    local target="$1"
    local steam_root="$2"
    local prefix_dir="$3"
    local proton_runner="$4"
    local installed_file="$5"
    local launcher_dir="$6"
    local wrapper_file="$launcher_dir/launch-$target.sh"
    local temporary_wrapper

    temporary_wrapper="$(mktemp "$launcher_dir/.launch-${target}.XXXXXX")" || return 1
    {
        printf '%s\n' '#!/bin/bash' 'set -u'
        printf 'STEAM_ROOT=%q\n' "$steam_root"
        printf 'PREFIX_DIR=%q\n' "$prefix_dir"
        printf 'PROTON_RUNNER=%q\n' "$proton_runner"
        printf 'TARGET_EXE=%q\n' "$installed_file"
        printf '%s\n' \
            'if [ ! -x "$PROTON_RUNNER" ] || [ ! -f "$TARGET_EXE" ]; then' \
            '    echo "启动器或兼容层文件缺失，请重新执行周克儿工具箱里的安装项。"' \
            '    exit 1' \
            'fi' \
            'export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"' \
            'export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"' \
            'export STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0' \
            'exec "$PROTON_RUNNER" run "$TARGET_EXE"'
    } > "$temporary_wrapper" || {
        rm -f "$temporary_wrapper"
        return 1
    }
    chmod +x "$temporary_wrapper" || {
        rm -f "$temporary_wrapper"
        return 1
    }
    mv -f "$temporary_wrapper" "$wrapper_file" || {
        rm -f "$temporary_wrapper"
        return 1
    }
    printf '%s\n' "$wrapper_file"
}

install_launcher() {
    local target="$1"
    local launcher_dir
    local installer_file
    local temp_file
    local steam_root
    local shortcut_file
    local proton_runner
    local prefix_dir
    local wrapper_file
    local installed_file
    local detected_prefix
    local desktop_shortcut
    local battlenet_result
    local command_name

    launcher_details "$target" || return 1
    for command_name in python3 find; do
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
    prefix_dir="$launcher_dir/compatdata"
    mkdir -p "$launcher_dir" || return 1

    installed_file="$(find_launcher_in_prefix "$prefix_dir" || true)"
    if [ -z "$installed_file" ]; then
        installed_file="$(find_installed_launcher "$steam_root" || true)"
        if [ -n "$installed_file" ]; then
            detected_prefix="${installed_file%%/pfx/drive_c/*}"
            [ -n "$detected_prefix" ] && prefix_dir="$detected_prefix"
        fi
    fi
    if [ "$target" = "battlenet" ]; then
        proton_runner="$(ensure_battlenet_runner "$steam_root")" || return 1
    else
        proton_runner="$(ensure_proton_runner "$steam_root")" || return 1
    fi
    if [ -z "$installed_file" ]; then
        for command_name in curl od; do
            command -v "$command_name" >/dev/null 2>&1 || {
                echo "系统缺少 $command_name，无法下载安装程序。"
                return 1
            }
        done
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
        if [ "$target" = "battlenet" ]; then
            battlenet_result="$(run_battlenet_installer_with_fallback \
                "$steam_root" "$installer_file" "$prefix_dir" "$proton_runner")" || return 1
            installed_file="${battlenet_result%%|*}"
            proton_runner="${battlenet_result#*|}"
            [ -n "$installed_file" ] && [ "$proton_runner" != "$battlenet_result" ] || {
                echo "战网兼容层重试结果异常，未创建 Steam 条目。"
                return 1
            }
        else
            installed_file="$(run_launcher_installer \
                "$target" "$steam_root" "$installer_file" "$prefix_dir" "$proton_runner")" || return 1
        fi
    else
        echo "已找到安装完成的 ${LAUNCHER_NAME}，直接调用主程序并跳过安装包下载。"
    fi
    wrapper_file="$(create_launcher_wrapper \
        "$target" "$steam_root" "$prefix_dir" "$proton_runner" \
        "$installed_file" "$launcher_dir")" || return 1

    stop_steam_for_vdf || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$wrapper_file" \
        --start-dir "$launcher_dir" || return 1
    if ! desktop_shortcut="$(create_launcher_desktop_shortcut \
        "$LAUNCHER_NAME" "$wrapper_file" "$launcher_dir")"; then
        echo "Steam 条目已写入，但桌面启动图标创建失败：$HOME/Desktop"
        desktop_shortcut=""
    fi
    start_steam

    notify_launcher_ready "$LAUNCHER_NAME"
    echo "Steam 已重新打开；进入“非 Steam 游戏”即可直接启动，无需再选择兼容层。"
    [ -n "$desktop_shortcut" ] && echo "桌面启动图标：$desktop_shortcut"
    echo "关闭 Epic 或战网登录窗口只会退出启动器，不会删除安装；之后可从 Steam 或桌面图标再次打开。"
    log "$LAUNCHER_NAME 已通过包装器加入Steam: $wrapper_file -> $installed_file"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        epic|battlenet) install_launcher "$1" ;;
        *) echo "用法: $0 {epic|battlenet}"; exit 1 ;;
    esac
fi
