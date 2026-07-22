#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

DOWNLOAD_TIMEOUT="${ZHOUKEER_LAUNCHER_DOWNLOAD_TIMEOUT:-600}"
POST_INSTALL_TIMEOUT="${ZHOUKEER_LAUNCHER_POST_INSTALL_TIMEOUT:-300}"
POST_INSTALL_INTERVAL="${ZHOUKEER_LAUNCHER_POST_INSTALL_INTERVAL:-5}"
BATTLE_NET_FIRST_ATTEMPT_TIMEOUT="${ZHOUKEER_BATTLENET_FIRST_ATTEMPT_TIMEOUT:-75}"
STEAM_SHORTCUT_HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"
PROTON_10_APP_ID="3658110"
PROTON_EXPERIMENTAL_APP_ID="1493710"
PROTON_INSTALL_TIMEOUT="${ZHOUKEER_PROTON_INSTALL_TIMEOUT:-900}"
PROTON_INSTALL_INTERVAL="${ZHOUKEER_PROTON_INSTALL_INTERVAL:-5}"

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
            LAUNCHER_URL="https://downloader.battle.net/download/getInstallerForGame?os=win&installer=Battle.net-Setup.exe"
            LAUNCHER_MIN_BYTES=1048576
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Battle.net/Battle.net Launcher.exe\nProgram Files (x86)/Battle.net/Battle.net.exe'
            ;;
        ubisoft|uplay)
            LAUNCHER_NAME="育碧"
            LAUNCHER_FILE_NAME="UbisoftConnectInstaller.exe"
            LAUNCHER_URL="https://static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe"
            LAUNCHER_MIN_BYTES=10485760
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe\nProgram Files (x86)/Ubisoft/Ubisoft Game Launcher/upc.exe'
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

download_launcher_installer() {
    local output="$1"
    local temporary="$output.new.$$"

    require_command curl || return 1
    rm -f -- "$temporary"
    echo "正在下载 $LAUNCHER_NAME 官方安装器…"
    if ! curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time "$DOWNLOAD_TIMEOUT" --retry 2 --retry-delay 2 \
        --output "$temporary" "$LAUNCHER_URL"; then
        rm -f -- "$temporary"
        echo "$LAUNCHER_NAME 官方安装器下载失败。"
        return 1
    fi
    if ! verify_installer "$temporary"; then
        rm -f -- "$temporary"
        return 1
    fi
    mv -f -- "$temporary" "$output" || return 1
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
    local loginusers_file steam_id account_id
    local candidate
    local newest=""
    local newest_time=0
    local modified

    if [ -n "${ZHOUKEER_SHORTCUT_FILE:-}" ]; then
        printf '%s\n' "$ZHOUKEER_SHORTCUT_FILE"
        return 0
    fi

    loginusers_file="$steam_root/config/loginusers.vdf"
    if [ -f "$loginusers_file" ] && [ ! -L "$loginusers_file" ]; then
        steam_id="$(awk '
            /^[[:space:]]*"[0-9]+"[[:space:]]*$/ {
                value=$0
                gsub(/[[:space:]\"]/, "", value)
                current=value
            }
            /^[[:space:]]*"MostRecent"[[:space:]]*"1"[[:space:]]*$/ && current != "" {
                print current
                exit
            }
        ' "$loginusers_file")"
        case "$steam_id" in
            ''|*[!0-9]*) ;;
            *)
                account_id=$((steam_id - 76561197960265728))
                if [ "$account_id" -gt 0 ] && [ -d "$steam_root/userdata/$account_id/config" ]; then
                    printf '%s/userdata/%s/config/shortcuts.vdf\n' "$steam_root" "$account_id"
                    return 0
                fi
                ;;
        esac
    fi

    # loginusers.vdf 不可用时，优先复用已有快捷方式文件，避免写进旧账号。
    while IFS= read -r -d '' candidate; do
        modified="$(stat -c '%Y' "$candidate" 2>/dev/null || printf '0')"
        if [ "$modified" -ge "$newest_time" ]; then
            newest="$candidate"
            newest_time="$modified"
        fi
    done < <(find "$steam_root/userdata" -mindepth 3 -maxdepth 3 -type f -name shortcuts.vdf -print0 2>/dev/null)
    if [ -n "$newest" ]; then
        printf '%s\n' "$newest"
        return 0
    fi

    newest=""
    newest_time=0
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
    local install_mode="${7:-interactive}"

    launcher_details "$target" || return 1
    mkdir -p "$prefix_dir" || return 1
    if [ "$install_mode" = "silent" ]; then
        echo "正在静默安装 $LAUNCHER_NAME..." >&2
    else
        echo "正在打开 $LAUNCHER_NAME 官方安装器..." >&2
    fi
    case "$target:$install_mode" in
        epic:interactive) echo "弹出 Epic 安装窗口后，点击 Install（安装）；完成后点击 Finish（完成）。" >&2 ;;
        battlenet:*)
            echo "弹出战网安装窗口后，点击 Continue（继续），按中文界面完成安装。" >&2
            echo "若出现 BLZBNTBTS00000028，请关闭错误窗口并等待，工具箱会自动修复安装环境并重试。" >&2
            ;;
        ubisoft:interactive|uplay:interactive) echo "弹出育碧安装窗口后，选择中文并依次点击接受、安装、完成。" >&2 ;;
    esac

    case "$target" in
        epic)
            if [ "$install_mode" = "silent" ]; then
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                    STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                    "$proton_runner" run msiexec /i "$installer_file" /qn /norestart || status=$?
            else
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                    STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                    "$proton_runner" run msiexec /i "$installer_file" || status=$?
            fi
            ;;
        ubisoft|uplay)
            if [ "$install_mode" = "silent" ]; then
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                    STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                    "$proton_runner" run "$installer_file" /S || status=$?
            else
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                    STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                    "$proton_runner" run "$installer_file" || status=$?
            fi
            ;;
        battlenet)
            STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                "$proton_runner" run "$installer_file" || status=$?
            ;;
    esac
    printf '%s\n' "$status" > "$prefix_dir/.zhoukeer-installer-status" 2>/dev/null || true
    if [ "$target" = "battlenet" ] && [ "$status" -ne 0 ]; then
        echo "战网安装器本次运行失败，退出码：$status" >&2
        return 1
    fi

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
    local candidate

    if [ -n "${ZHOUKEER_PROTON_RUNNER:-}" ] && [ -x "$ZHOUKEER_PROTON_RUNNER" ]; then
        printf '%s
' "$ZHOUKEER_PROTON_RUNNER"
        return 0
    fi

    # 长期装机验证：优先 Proton 10.0-4，失败时仅回退到 Proton Experimental。
    candidate="$(find_proton_10_runner "$steam_root" || true)"
    if [ -n "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    find_proton_experimental_runner "$steam_root"

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
    local candidate version_file

    candidate="$steam_root/steamapps/common/Proton 10.0-4/proton"
    if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    candidate="$steam_root/steamapps/common/Proton 10.0/proton"
    version_file="$(dirname "$candidate")/version"
    if [ -x "$candidate" ] && [ -f "$version_file" ] && [ ! -L "$version_file" ] && \
       grep -Eqi '(^|[^0-9])10\.0-4([^0-9]|$)' "$version_file"; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

install_official_proton_10() {
    local steam_root="$1"
    local steam_bin runner elapsed=0

    case "$PROTON_INSTALL_TIMEOUT:$PROTON_INSTALL_INTERVAL" in
        *[!0-9:]*|:*|*:0) echo "安装环境等待参数无效。" >&2; return 1 ;;
    esac
    steam_bin="$(steam_command)" || {
        echo "找不到 Steam 客户端，无法自动准备安装环境。" >&2
        return 1
    }
    echo "正在通过 Steam 自动准备安装环境..." >&2
    "$steam_bin" "steam://install/$PROTON_10_APP_ID" >/dev/null 2>&1 &
    while [ "$elapsed" -le "$PROTON_INSTALL_TIMEOUT" ]; do
        runner="$(find_proton_10_runner "$steam_root" || true)"
        if [ -n "$runner" ]; then
            echo "安装环境已准备完成。" >&2
            printf '%s\n' "$runner"
            return 0
        fi
        sleep "$PROTON_INSTALL_INTERVAL"
        elapsed=$((elapsed + PROTON_INSTALL_INTERVAL))
    done
    echo "等待安装环境准备超时。请确认 Steam 在线且已登录后重试。" >&2
    return 1
}

ensure_proton_runner() {
    local steam_root="$1"
    local runner

    runner="$(find_proton_runner "$steam_root" || true)"
    if [ -n "$runner" ]; then
        printf '%s\n' "$runner"
        return 0
    fi
    install_official_proton_10 "$steam_root"
}

ensure_launcher_proton_runner() {
    local target="$1"
    local steam_root="$2"
    local runner

    if [ "$target" = "battlenet" ]; then
        ensure_proton_runner "$steam_root"
        return
    fi
    runner="$(find_proton_experimental_runner "$steam_root" || true)"
    [ -n "$runner" ] || runner="$(find_proton_10_runner "$steam_root" || true)"
    if [ -n "$runner" ]; then
        printf '%s\n' "$runner"
        return 0
    fi
    install_official_proton_10 "$steam_root"
}

find_battlenet_alternate_runner() {
    local steam_root="$1" current_runner="$2" candidate
    for candidate in "$(find_proton_10_runner "$steam_root" || true)" "$(find_proton_experimental_runner "$steam_root" || true)"; do
        [ -n "$candidate" ] && [ "$candidate" != "$current_runner" ] && {
            printf '%s\n' "$candidate"
            return 0
        }
    done
    return 1
}

install_official_proton_experimental() {
    local steam_root="$1"
    local steam_bin runner elapsed=0

    case "$PROTON_INSTALL_TIMEOUT:$PROTON_INSTALL_INTERVAL" in
        *[!0-9:]*|:*|*:) echo "安装环境等待参数无效。" >&2; return 1 ;;
    esac
    [ "$PROTON_INSTALL_INTERVAL" -gt 0 ] || {
        echo "安装环境检查间隔必须大于 0。" >&2
        return 1
    }
    steam_bin="$(steam_command)" || {
        echo "找不到 Steam 客户端，无法自动准备备用安装环境。" >&2
        return 1
    }
    echo "正在通过 Steam 自动准备战网备用安装环境..." >&2
    "$steam_bin" "steam://install/$PROTON_EXPERIMENTAL_APP_ID" >/dev/null 2>&1 &
    while [ "$elapsed" -le "$PROTON_INSTALL_TIMEOUT" ]; do
        runner="$(find_proton_experimental_runner "$steam_root" || true)"
        if [ -n "$runner" ]; then
            echo "战网备用安装环境已准备完成，将自动重试。" >&2
            printf '%s\n' "$runner"
            return 0
        fi
        sleep "$PROTON_INSTALL_INTERVAL"
        elapsed=$((elapsed + PROTON_INSTALL_INTERVAL))
    done
    echo "等待备用安装环境准备超时，战网暂时无法自动重试。" >&2
    return 1
}

ensure_battlenet_alternate_runner() {
    local steam_root="$1" current_runner="$2" alternate

    alternate="$(find_battlenet_alternate_runner "$steam_root" "$current_runner" || true)"
    if [ -n "$alternate" ]; then
        printf '%s\n' "$alternate"
        return 0
    fi
    case "$current_runner" in
        *"Proton - Experimental"*/proton)
            install_official_proton_10 "$steam_root"
            ;;
        *)
            install_official_proton_experimental "$steam_root"
            ;;
    esac
}

battlenet_prefix_has_setup_error() {
    local prefix_dir="$1" log_file
    [ -d "$prefix_dir/pfx/drive_c" ] || return 1
    while IFS= read -r -d '' log_file; do
        if grep -Eiq 'BLZBNTBTS[0-9]+|Failed to (connect|download|update)|update service.*(failed|unavailable)' \
            "$log_file" 2>/dev/null; then
            return 0
        fi
    done < <(find "$prefix_dir/pfx/drive_c" -type f \
        \( -iname '*.log' -o -iname '*.txt' \) -size -2M -print0 2>/dev/null)
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
    local target="$1" wrapper="$2" name icon
    case "$target" in
        epic) name="Epic Games 启动器"; icon="$PROJECT_ROOT/assets/game-launchers/epic.png" ;;
        battlenet) name="战网启动器"; icon="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        ubisoft|uplay) name="育碧"; icon="$PROJECT_ROOT/assets/game-launchers/ubisoft.png" ;;
        *) return 1 ;;
    esac
    mkdir -p "$HOME/Desktop" || return 1
    if [ "$target" = "ubisoft" ] || [ "$target" = "uplay" ]; then
        local old_shortcut="$HOME/Desktop/Ubisoft Connect（Uplay）.desktop"
        local old_cn_shortcut="$HOME/Desktop/育碧服务.desktop"
        if [ -f "$old_shortcut" ] && [ ! -L "$old_shortcut" ] && \
           grep -Eq '^Exec=.*/game-launchers/(ubisoft|uplay)/launch-(ubisoft|uplay)\.sh$' "$old_shortcut"; then
            rm -f -- "$old_shortcut"
        fi
        if [ -f "$old_cn_shortcut" ] && [ ! -L "$old_cn_shortcut" ] && \
           grep -Eq '^Exec=.*/game-launchers/(ubisoft|uplay)/launch-(ubisoft|uplay)\.sh$' "$old_cn_shortcut"; then
            rm -f -- "$old_cn_shortcut"
        fi
    fi
    cat > "$HOME/Desktop/$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$wrapper
Terminal=false
Icon=$icon
Categories=Game;
X-Zhoukeer-Managed=true
EOF
    chmod +x "$HOME/Desktop/$name.desktop"
}

install_launcher_steam_artwork() {
    local target="$1" shortcut_file="$2" app_id="$3"
    local asset_name grid_dir

    case "$target" in
        epic) asset_name="epic" ;;
        battlenet) asset_name="battlenet" ;;
        ubisoft|uplay) asset_name="ubisoft" ;;
        *) return 1 ;;
    esac
    case "$app_id" in
        ''|*[!0-9]*) echo "Steam 非 Steam 游戏编号无效，未写入库封面。"; return 1 ;;
    esac
    grid_dir="$(dirname "$shortcut_file")/grid"
    if [ -L "$grid_dir" ]; then
        echo "Steam 封面目录是符号链接，已停止写入：$grid_dir"
        return 1
    fi
    install -d -m 0755 -- "$grid_dir" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name.png" \
        "$grid_dir/${app_id}_icon.png" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name-grid.jpg" \
        "$grid_dir/${app_id}.jpg" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name-portrait.jpg" \
        "$grid_dir/${app_id}p.jpg" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name-hero.jpg" \
        "$grid_dir/${app_id}_hero.jpg" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name.png" \
        "$grid_dir/${app_id}_logo.png" || return 1
}

run_battlenet_installer_with_fallback() {
    local steam_root="$1" installer_file="$2" prefix_dir="$3" runner="$4" alternate installed status
    launcher_details battlenet || return 1
    POST_INSTALL_TIMEOUT="$BATTLE_NET_FIRST_ATTEMPT_TIMEOUT" run_launcher_installer battlenet "$steam_root" "$installer_file" "$prefix_dir" "$runner" || true
    installed="$(find_launcher_in_prefix "$prefix_dir" || true)"
    status="$(cat "$prefix_dir/.zhoukeer-installer-status" 2>/dev/null || printf '1')"
    if [ -n "$installed" ] && [ "$status" = "0" ] && ! battlenet_prefix_has_setup_error "$prefix_dir"; then
        printf '%s|%s\n' "$installed" "$runner"
        return 0
    fi
    alternate="$(ensure_battlenet_alternate_runner "$steam_root" "$runner")" || return 1
    echo "战网安装器未完成，正在自动修复安装环境并重试..." >&2
    installed="$(run_launcher_installer battlenet "$steam_root" "$installer_file" "$prefix_dir" "$alternate")" || return 1
    printf '%s|%s\n' "$installed" "$alternate"
}

install_launcher() {
    local target="$1" steam_root launcher_exe runner app_dir prefix wrapper shortcut_file installer_file launcher_result app_id icon_path
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "游戏启动器安装仅支持真实 SteamOS 环境。"
        return 1
    fi
    launcher_details "$target" || return 1
    steam_root="$(find_steam_root)" || return 1
    app_dir="$APP_DIR/game-launchers/$target"
    mkdir -p "$app_dir" || return 1
    prefix="$app_dir/compatdata"
    launcher_exe="$(find_launcher_in_prefix "$prefix" || find_installed_launcher "$steam_root" || true)"
    runner="$(ensure_launcher_proton_runner "$target" "$steam_root")" || return 1

    if [ -n "$launcher_exe" ]; then
        echo "检测到已安装的 ${LAUNCHER_NAME}，跳过安装包下载。"
        case "$launcher_exe" in
            "$prefix"/pfx/drive_c/*) ;;
            *) prefix="${launcher_exe%/pfx/drive_c/*}" ;;
        esac
    else
        installer_file="$app_dir/$LAUNCHER_FILE_NAME"
        download_launcher_installer "$installer_file" || return 1
        if [ "$target" = "battlenet" ]; then
            launcher_result="$(run_battlenet_installer_with_fallback "$steam_root" "$installer_file" "$prefix" "$runner")" || return 1
            launcher_exe="${launcher_result%%|*}"
            runner="${launcher_result#*|}"
        else
            case "$target" in
                epic|ubisoft|uplay)
                    launcher_exe="$(run_launcher_installer "$target" "$steam_root" "$installer_file" "$prefix" "$runner" 20 silent || true)"
                    if [ -z "$launcher_exe" ]; then
                        echo "$LAUNCHER_NAME 静默安装未完成，正在回退到官方可见安装窗口。"
                        launcher_exe="$(run_launcher_installer "$target" "$steam_root" "$installer_file" "$prefix" "$runner")" || return 1
                    fi
                    ;;
                *)
                    launcher_exe="$(run_launcher_installer "$target" "$steam_root" "$installer_file" "$prefix" "$runner")" || return 1
                    ;;
            esac
        fi
    fi
    wrapper="$(create_launcher_wrapper "$target" "$steam_root" "$prefix" "$runner" "$launcher_exe" "$app_dir")" || return 1
    create_launcher_desktop_shortcut "$target" "$wrapper" || return 1
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    stop_steam_for_vdf || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$wrapper" --start-dir "$app_dir" >/dev/null || return 1
    case "$target" in
        epic) icon_path="$PROJECT_ROOT/assets/game-launchers/epic.png" ;;
        battlenet) icon_path="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        ubisoft|uplay) icon_path="$PROJECT_ROOT/assets/game-launchers/ubisoft.png" ;;
        *) return 1 ;;
    esac
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$LAUNCHER_NAME" --exe "$wrapper" --icon "$icon_path" >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
        --name "$LAUNCHER_NAME" --exe "$wrapper" --icon "$icon_path" >/dev/null || {
        echo "$LAUNCHER_NAME 的 Steam 条目写入后校验失败，桌面图标仍可使用。"
        return 1
    }
    app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid \
        --name "$LAUNCHER_NAME" --exe "$wrapper")" || return 1
    install_launcher_steam_artwork "$target" "$shortcut_file" "$app_id" || return 1
    start_steam
    echo "$LAUNCHER_NAME 已添加到 Steam 库，桌面入口、封面与工具箱标识均已设置。"
    if [ "$target" = "epic" ]; then
        echo "Epic 改中文：右上角头像 → Settings → Language → 中文（简体）→ Restart Now。"
        echo "若下载管理器仍显示英文，请选择不带 System Default 的中文（简体）后重启。"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        epic|battlenet|ubisoft|uplay) install_launcher "$1" ;;
        *) echo "用法: $0 {epic|battlenet|ubisoft}"; exit 1 ;;
    esac
fi
