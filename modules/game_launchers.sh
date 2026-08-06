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
STEAM_SHORTCUT_HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"
STEAM_COMPAT_HELPER="$PROJECT_ROOT/scripts/steam_compat.py"
PROTON_10_APP_ID="3658110"
PROTON_EXPERIMENTAL_APP_ID="1493710"
PROTON_INSTALL_TIMEOUT="${ZHOUKEER_PROTON_INSTALL_TIMEOUT:-900}"
PROTON_INSTALL_INTERVAL="${ZHOUKEER_PROTON_INSTALL_INTERVAL:-5}"
LAUNCHER_PREINSTALLED_BASE="${ZHOUKEER_LAUNCHER_PREINSTALLED_BASE:-https://gitee.com/easylife2025/battle/releases/download/v1.0.0}"
# Windows 虚拟 C 盘放在用户可见目录，避免隐藏目录导致战网插件、黑盒工坊等找不到游戏文件。
LAUNCHER_BASE="${ZHOUKEER_LAUNCHER_BASE:-$HOME/游戏启动器}"

launcher_details() {
    case "$1" in
        epic)
            LAUNCHER_NAME="Epic Games 启动器"
            LAUNCHER_FILE_NAME="EpicGamesLauncherInstaller.msi"
            LAUNCHER_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"
            LAUNCHER_FALLBACK_URL="https://epicgames-download1.akamaized.net/Builds/UnrealEngineLauncher/Installers/Windows/EpicInstaller-20.1.4.msi?launcherfilename=EpicInstaller-20.1.4.msi"
            LAUNCHER_FALLBACK_SHA256="1513d6cc2afda0367c8375b6f25f490c162da5607ce4b4adbb41906a2d742236"
            LAUNCHER_GITEE_MIRROR_ID="epic"
            LAUNCHER_GITEE_MIRROR_SHA256="1513d6cc2afda0367c8375b6f25f490c162da5607ce4b4adbb41906a2d742236"
            LAUNCHER_GITEE_MIRROR_URL="https://epicgames-download1.akamaized.net/Builds/UnrealEngineLauncher/Installers/Windows/EpicInstaller-20.1.4.msi"
            LAUNCHER_MIN_BYTES=52428800
            LAUNCHER_MAGIC="d0cf11e0"
            LAUNCHER_MAGIC_ALT="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe\nProgram Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe'
            ;;
        battlenet)
            LAUNCHER_NAME="战网启动器"
            LAUNCHER_FILE_NAME="Battle.net-Setup.exe"
            LAUNCHER_URL="https://downloader.battle.net/download/getInstallerForGame?os=win&installer=Battle.net-Setup.exe"
            LAUNCHER_FALLBACK_URL=""
            LAUNCHER_FALLBACK_SHA256=""
            LAUNCHER_PREINSTALLED=1
            LAUNCHER_PREINSTALLED_FILE="Battle.net.7z"
            LAUNCHER_PREINSTALLED_PARTS=4
            LAUNCHER_PREINSTALLED_TARGET_RELATIVE="Battle.net/Battle.net Launcher.exe"
            LAUNCHER_PREINSTALLED_BYTES=(94371840 94371840 94371840 32192646)
            LAUNCHER_PREINSTALLED_SHA256=(\
                61b8d62253f40ec599ab94c1e426c921377154c284f054e0f8854d9d0d99a12c \
                d6fd711531f29ccc4b73a318e22602f1d6bc0dc64bc71e9283139a1ed9aab99c \
                c7dc2e0129e345fdff6ddcce23e861e8c9826e33f1feb038213638356903b4c8 \
                174b546aa6c00f45b02b6eeea3e14820ba6908efb2ad46e2266bc449e315aacc)
            LAUNCHER_PREINSTALLED_ARCHIVE_SHA256="cedab076e12356eb0b61d47ad9479d66138fef3a3cec7c22d394e41a09413955"
            LAUNCHER_MIN_BYTES=1048576
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Battle.net/Battle.net Launcher.exe\nProgram Files (x86)/Battle.net/Battle.net.exe'
            ;;
        ubisoft|uplay)
            LAUNCHER_NAME="育碧"
            LAUNCHER_FILE_NAME="UbisoftConnectInstaller.exe"
            LAUNCHER_URL="https://static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe"
            LAUNCHER_FALLBACK_URL=""
            LAUNCHER_FALLBACK_SHA256=""
            LAUNCHER_MIN_BYTES=10485760
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe\nProgram Files (x86)/Ubisoft/Ubisoft Game Launcher/upc.exe'
            ;;
        heihe)
            LAUNCHER_NAME="黑盒工坊"
            LAUNCHER_FILE_NAME="wow_installer_1.9.51.0.exe"
            LAUNCHER_URL=""
            LAUNCHER_FALLBACK_URL=""
            LAUNCHER_FALLBACK_SHA256=""
            LAUNCHER_GITEE_MIRROR_ID="heihe"
            LAUNCHER_GITEE_MIRROR_SHA256="9e0bce560d8264eb015a020337167f57918babd755d1671c38a49f3cdb05654a"
            LAUNCHER_GITEE_MIRROR_URL="https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror/raw/main/heihe/1.9.51.0/wow_installer_1.9.51.0.exe"
            LAUNCHER_PREINSTALLED=1
            LAUNCHER_PREINSTALLED_MIRROR_ID="heihe-preinstalled"
            LAUNCHER_PREINSTALLED_FILE="heyboxwow.7z"
            LAUNCHER_PREINSTALLED_TARGET_RELATIVE="Qingfeng/HeyboxWow/heyboxwow.exe"
            LAUNCHER_PREINSTALLED_ARCHIVE_SHA256="8ef819da7291a7448ca346cc0e058bcf15b7da33dcec9a237b627a08331ede70"
            LAUNCHER_MIN_BYTES=10485760
            LAUNCHER_MAGIC="4d5a"
            LAUNCHER_TARGET_RELATIVES=$'Program Files (x86)/Qingfeng/HeyboxWow/heyboxwow.exe\nProgram Files (x86)/Qingfeng/HeyboxWow/HeyboxWow.exe\nProgram Files/Qingfeng/HeyboxWow/heyboxwow.exe\nProgram Files/Qingfeng/HeyboxWow/HeyboxWow.exe\nProgram Files (x86)/HeyboxWow/heyboxwow.exe\nProgram Files (x86)/HeyboxWow/HeyboxWow.exe\nProgram Files/HeyboxWow/heyboxwow.exe\nProgram Files/HeyboxWow/HeyboxWow.exe\nAppData/Local/Programs/Qingfeng/HeyboxWow/heyboxwow.exe\nAppData/Local/Programs/Qingfeng/HeyboxWow/HeyboxWow.exe\nAppData/Local/Programs/HeyboxWow/heyboxwow.exe\nAppData/Local/Programs/HeyboxWow/HeyboxWow.exe\nProgram Files (x86)/黑盒工坊/黑盒工坊.exe\nProgram Files (x86)/HeiHe/HeiHe.exe'
            ;;
        *)
            echo "未知启动器: $1"
            return 1
            ;;
    esac
}

verify_installer() {
    local file="$1"
    local size magic magic_ok

    size="$(wc -c < "$file" | tr -d ' ')"
    magic="$(od -An -tx1 -N4 "$file" | tr -d ' \n')"
    if [ "${size:-0}" -lt "$LAUNCHER_MIN_BYTES" ]; then
        echo "下载文件过小，已保留原有安装包。"
        return 1
    fi
    magic_ok=0
    case "$magic" in
        "$LAUNCHER_MAGIC"*) magic_ok=1 ;;
    esac
    if [ -n "${LAUNCHER_MAGIC_ALT:-}" ]; then
        case "$magic" in
            "$LAUNCHER_MAGIC_ALT"*) magic_ok=1 ;;
        esac
    fi
    if [ "$magic_ok" -ne 1 ]; then
        echo "下载文件格式不正确，已保留原有安装包。"
        return 1
    fi
}

launcher_file_sha256() {
    local file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

download_launcher_installer() {
    local output="$1"
    local temporary="$output.new.$$"
    local attempt
    local -a curl_options

    require_command curl || return 1
    if [ -n "${LAUNCHER_GITEE_MIRROR_ID:-}" ] && [ -n "${LAUNCHER_GITEE_MIRROR_SHA256:-}" ]; then
        rm -f -- "$temporary"
        if download_gitee_mirror_file "$LAUNCHER_GITEE_MIRROR_ID" "$temporary" \
            "$LAUNCHER_GITEE_MIRROR_SHA256" "$LAUNCHER_NAME" && \
            verify_installer "$temporary" >/dev/null 2>&1; then
            mv -f -- "$temporary" "$output" || return 1
            return 0
        fi
        rm -f -- "$temporary"
        echo "$LAUNCHER_NAME 镜像下载失败，切换官方源。"
    fi
    download_policy_url_allowed "$LAUNCHER_URL" || {
        echo "$LAUNCHER_NAME 下载地址不在受控来源清单中。"
        return 1
    }
    for attempt in 1 2 3; do
        rm -f -- "$temporary"
        echo "正在下载 $LAUNCHER_NAME 官方安装器…"
        curl_options=(
            --fail --location --progress-meter
            --proto '=https' --proto-redir '=https'
            --connect-timeout 15 --max-time "$DOWNLOAD_TIMEOUT"
            --retry 3 --retry-delay 2 --retry-connrefused --retry-all-errors
            --speed-limit 65536 --speed-time 60
            --max-filesize "$(download_policy_max_bytes "$LAUNCHER_URL")"
            --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36'
            --compressed
        )
        if [ "$attempt" -eq 2 ]; then
            curl_options+=(--http1.1)
        fi
        if curl "${curl_options[@]}" --output "$temporary" "$LAUNCHER_URL" \
            2> >(download_progress_filter "$LAUNCHER_NAME" >&2); then
            if download_policy_response_is_safe "$LAUNCHER_URL" "$temporary" && \
                verify_installer "$temporary" >/dev/null 2>&1; then
                mv -f -- "$temporary" "$output" || return 1
                return 0
            fi
        fi
        rm -f -- "$temporary"
        [ "$attempt" -eq 1 ] && echo "$LAUNCHER_NAME 下载响应异常，正在使用备用请求方式重试..."
    done
    if [ -n "${LAUNCHER_FALLBACK_URL:-}" ] && [ -n "${LAUNCHER_FALLBACK_SHA256:-}" ]; then
        rm -f -- "$temporary"
        echo "正在从 $LAUNCHER_NAME 官方 CDN 备用线路下载…"
        if download_policy_url_allowed "$LAUNCHER_FALLBACK_URL" && \
            curl --fail --location --progress-meter --proto '=https' --proto-redir '=https' \
                --connect-timeout 15 --max-time "$DOWNLOAD_TIMEOUT" --retry 2 --retry-delay 2 \
                --speed-limit 65536 --speed-time 60 \
                --max-filesize "$(download_policy_max_bytes "$LAUNCHER_FALLBACK_URL")" \
                --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36' \
                --compressed --http1.1 \
                --output "$temporary" "$LAUNCHER_FALLBACK_URL" \
                2> >(download_progress_filter "$LAUNCHER_NAME" >&2) && \
            download_policy_response_is_safe "$LAUNCHER_FALLBACK_URL" "$temporary" && \
            verify_installer "$temporary" >/dev/null 2>&1 && \
            [ "$(launcher_file_sha256 "$temporary")" = "$LAUNCHER_FALLBACK_SHA256" ]; then
            mv -f -- "$temporary" "$output" || return 1
            return 0
        fi
        rm -f -- "$temporary"
    fi
    echo "$LAUNCHER_NAME 下载响应格式或大小异常。"
    return 1
}

download_preinstalled_launcher_parts() {
    local workdir="$1"
    local index part_url part_file expected_size expected_sha actual_size actual_sha magic
    local -a curl_options

    [ "$LAUNCHER_PREINSTALLED_PARTS" -gt 0 ] || {
        echo "$LAUNCHER_NAME 客户端分卷配置无效。"
        return 1
    }
    mkdir -p "$workdir" || return 1
    echo "正在下载 $LAUNCHER_NAME 预装客户端..."
    for index in $(seq 1 "$LAUNCHER_PREINSTALLED_PARTS"); do
        part_url="$LAUNCHER_PREINSTALLED_BASE/$LAUNCHER_PREINSTALLED_FILE.$(printf '%03d' "$index")"
        part_file="$workdir/$LAUNCHER_PREINSTALLED_FILE.$(printf '%03d' "$index")"
        expected_size="${LAUNCHER_PREINSTALLED_BYTES[$((index - 1))]}"
        expected_sha="${LAUNCHER_PREINSTALLED_SHA256[$((index - 1))]}"
        download_policy_url_allowed "$part_url" || {
            echo "$LAUNCHER_NAME 下载地址不在受控来源清单中。"
            return 1
        }
        curl_options=(
            --fail --location --progress-meter
            --proto '=https' --proto-redir '=https'
            --connect-timeout 15 --max-time "$DOWNLOAD_TIMEOUT"
            --retry 3 --retry-delay 2 --retry-connrefused --retry-all-errors
            --speed-limit 65536 --speed-time 60
            --max-filesize "$(download_policy_max_bytes "$part_url")"
        )
        if ! curl "${curl_options[@]}" --output "$part_file" "$part_url" \
            2> >(download_progress_filter "$LAUNCHER_NAME 预装客户端" >&2); then
            echo "$LAUNCHER_NAME 客户端下载失败，已保留已下载分卷。"
            return 1
        fi
        download_policy_response_is_safe "$part_url" "$part_file" || {
            echo "$LAUNCHER_NAME 客户端响应异常，已保留已下载分卷。"
            return 1
        }
        actual_size="$(wc -c < "$part_file" | tr -d ' ')"
        [ "$actual_size" = "$expected_size" ] || {
            echo "$LAUNCHER_NAME 客户端分卷大小校验失败：${LAUNCHER_PREINSTALLED_FILE}.$(printf '%03d' "$index")"
            return 1
        }
        if [ "$index" -eq 1 ]; then
            magic="$(od -An -tx1 -N6 "$part_file" | tr -d ' \n')"
            [ "$magic" = "377abcaf271c" ] || {
                echo "$LAUNCHER_NAME 客户端分卷格式校验失败：${LAUNCHER_PREINSTALLED_FILE}.001"
                return 1
            }
        fi
        actual_sha="$(launcher_file_sha256 "$part_file")" || {
            echo "无法计算 $LAUNCHER_NAME 客户端分卷校验值。"
            return 1
        }
        [ "$actual_sha" = "$expected_sha" ] || {
            echo "$LAUNCHER_NAME 客户端分卷 SHA256 校验失败：${LAUNCHER_PREINSTALLED_FILE}.$(printf '%03d' "$index")"
            return 1
        }
    done
    echo "正在重组 $LAUNCHER_NAME 客户端文件..."
    : > "$workdir/$LAUNCHER_PREINSTALLED_FILE"
    for index in $(seq 1 "$LAUNCHER_PREINSTALLED_PARTS"); do
        cat -- "$workdir/$LAUNCHER_PREINSTALLED_FILE.$(printf '%03d' "$index")" \
            >> "$workdir/$LAUNCHER_PREINSTALLED_FILE" || return 1
    done
    [ "$(launcher_file_sha256 "$workdir/$LAUNCHER_PREINSTALLED_FILE")" = "$LAUNCHER_PREINSTALLED_ARCHIVE_SHA256" ] || {
        echo "$LAUNCHER_NAME 客户端重组后校验失败。"
        return 1
    }
    echo "$LAUNCHER_NAME 预装客户端下载完成。"
}

download_preinstalled_launcher() {
    local workdir="$1"

    mkdir -p "$workdir" || return 1
    if [ -n "${LAUNCHER_PREINSTALLED_MIRROR_ID:-}" ]; then
        download_gitee_mirror_file "$LAUNCHER_PREINSTALLED_MIRROR_ID" \
            "$workdir/$LAUNCHER_PREINSTALLED_FILE" \
            "$LAUNCHER_PREINSTALLED_ARCHIVE_SHA256" "$LAUNCHER_NAME"
        return
    fi
    download_preinstalled_launcher_parts "$workdir"
}

extract_preinstalled_launcher() {
    local archive="$1" drive_c="$2"
    local target_dir target_exe list_file entry

    require_command bsdtar || return 1
    list_file="$(mktemp)" || return 1
    if ! LC_ALL=C bsdtar -tf "$archive" < /dev/null > "$list_file" 2>/dev/null; then
        rm -f -- "$list_file"
        echo "$LAUNCHER_NAME 客户端压缩包无法读取，可能已损坏。"
        return 1
    fi
    if LC_ALL=C grep -Eq '[[:cntrl:]\\]|^/|^[A-Za-z]:' "$list_file"; then
        rm -f -- "$list_file"
        echo "$LAUNCHER_NAME 客户端压缩包路径不安全，已停止安装。"
        return 1
    fi
    while IFS= read -r entry; do
        case "$entry" in
            '..'|'../'*|*/'..'|*/'../'*)
                rm -f -- "$list_file"
                echo "$LAUNCHER_NAME 客户端压缩包路径越界，已停止安装。"
                return 1
                ;;
        esac
    done < "$list_file"
    rm -f -- "$list_file"
    target_dir="$drive_c/Program Files (x86)"
    mkdir -p "$target_dir" || return 1
    if ! bsdtar --no-same-owner --no-same-permissions --no-acls --no-xattrs \
        --no-fflags -xf "$archive" -C "$target_dir" < /dev/null; then
        echo "$LAUNCHER_NAME 客户端解压失败，已停止安装。"
        return 1
    fi
    target_exe="$target_dir/$LAUNCHER_PREINSTALLED_TARGET_RELATIVE"
    [ -f "$target_exe" ] && [ ! -L "$target_exe" ] || {
        echo "解压后未找到 $LAUNCHER_NAME 主程序。"
        return 1
    }
    if find "$target_dir" -type l -print -quit 2>/dev/null | grep -q .; then
        echo "$LAUNCHER_NAME 客户端解压产物包含异常链接，已停止安装。"
        return 1
    fi
    return 0
}

prepare_launcher_shared_prefix() {
    local target="$1" drive_c="$2"
    local prefix_dir="$APP_DIR/game-launchers/$target/compatdata"

    mkdir -p "$prefix_dir/pfx" || return 1
    if [ -L "$prefix_dir/pfx/drive_c" ]; then
        if [ "$(readlink "$prefix_dir/pfx/drive_c")" = "$drive_c" ]; then
            printf '%s\n' "$prefix_dir"
            return 0
        fi
        rm -f -- "$prefix_dir/pfx/drive_c" || return 1
    elif [ -e "$prefix_dir/pfx/drive_c" ]; then
        rm -rf -- "$prefix_dir/pfx/drive_c" || return 1
    fi
    ln -s -- "$drive_c" "$prefix_dir/pfx/drive_c" || return 1
    printf '%s\n' "$prefix_dir"
}

launcher_drive_c() {
    local target="$1"

    printf '%s/%s/drive_c\n' "$LAUNCHER_BASE" "$target"
}

link_steam_compatdata_drive() {
    local steam_root="$1" app_id="$2" prefix_dir="$3"
    local drive_c compat_pfx backup

    case "$app_id" in
        ''|*[!0-9]*) echo "Steam 兼容层编号无效。"; return 1 ;;
    esac
    drive_c="$prefix_dir/pfx/drive_c"
    [ -d "$drive_c" ] || return 0
    compat_pfx="$steam_root/steamapps/compatdata/$app_id/pfx"
    mkdir -p "$compat_pfx" || return 1
    if [ -L "$compat_pfx/drive_c" ]; then
        [ "$(readlink "$compat_pfx/drive_c")" = "$drive_c" ] || {
            echo "Steam 兼容层已有其他 drive_c 链接，已停止覆盖。"
            return 1
        }
        return 0
    fi
    if [ -e "$compat_pfx/drive_c" ]; then
        backup="$compat_pfx/.zhoukeer-drive-c-backup"
        [ ! -e "$backup" ] || {
            echo "Steam 兼容层已有旧目录备份，请先检查后重试。"
            return 1
        }
        mv -- "$compat_pfx/drive_c" "$backup" || return 1
    fi
    ln -s -- "$drive_c" "$compat_pfx/drive_c" || return 1
}

set_launcher_grid_icon() {
    local shortcut_file="$1" name="$2" exe="$3" grid_dir="$4"
    shift 4
    local candidate icon=""

    for candidate in "$@"; do
        if [ -f "$grid_dir/${candidate}_icon.png" ]; then
            icon="$grid_dir/${candidate}_icon.png"
            break
        fi
    done
    [ -n "$icon" ] || return 0
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$name" --exe "$exe" --icon "$icon" >/dev/null || return 1
    printf '%s\n' "$icon"
}

migrate_launcher_drive_to_visible() {
    local target="$1" prefix_dir="$2"
    local drive_c real_drive new_drive new_parent

    drive_c="$prefix_dir/pfx/drive_c"
    if [ -L "$drive_c" ]; then
        real_drive="$(readlink "$drive_c")"
    elif [ -d "$drive_c" ]; then
        real_drive="$drive_c"
    else
        return 0
    fi
    new_drive="$(launcher_drive_c "$target")"
    [ "$real_drive" = "$new_drive" ] && return 0
    case "$real_drive" in
        "$APP_DIR"/*) ;;
        *) return 0 ;;
    esac
    if [ -e "$new_drive" ] || [ -L "$new_drive" ]; then
        echo "$LAUNCHER_NAME 目标虚拟目录已存在，未迁移：$new_drive"
        return 1
    fi
    new_parent="$(dirname "$new_drive")"
    mkdir -p "$new_parent" || return 1
    mv -- "$real_drive" "$new_drive" || return 1
    prepare_launcher_shared_prefix "$target" "$new_drive" >/dev/null || return 1
    echo "已将 $LAUNCHER_NAME 虚拟目录迁移到 ${new_drive}。"
}

find_battle_platform_drive_c() {
    local steam_root="$1"
    local battle_drive_c candidate_dir

    battle_drive_c="$(launcher_drive_c battlenet)"
    if [ -d "$battle_drive_c" ] && [ ! -L "$battle_drive_c" ]; then
        printf '%s\n' "$battle_drive_c"
        return 0
    fi
    battle_drive_c="$APP_DIR/game-launchers/battlenet/drive_c"
    if [ -d "$battle_drive_c" ] && [ ! -L "$battle_drive_c" ]; then
        printf '%s\n' "$battle_drive_c"
        return 0
    fi
    for candidate_dir in "$steam_root/steamapps/compatdata"/*/; do
        [ -d "$candidate_dir" ] || continue
        candidate_dir="${candidate_dir%/}"
        if [ -f "$candidate_dir/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe" ]; then
            printf '%s\n' "$candidate_dir/pfx/drive_c"
            return 0
        fi
    done
    return 1
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
            {
                value=$0
                gsub(/[[:space:]"]/, "", value)
                if (value ~ /^[0-9]+$/) {
                    current=value
                } else if (value == "MostRecent1" && current != "") {
                    print current
                    exit
                }
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

wait_for_steam_running() {
    local attempt

    steam_command >/dev/null 2>&1 || return 1
    for attempt in $(seq 1 30); do
        steam_is_running && return 0
        sleep 1
    done
    return 1
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
    local relative_path candidate_dir candidate

    [ -d "$steam_root/steamapps/compatdata" ] || return 1
    while IFS= read -r relative_path; do
        [ -n "$relative_path" ] || continue
        for candidate_dir in "$steam_root/steamapps/compatdata"/*/; do
            [ -d "$candidate_dir" ] || continue
            candidate_dir="${candidate_dir%/}"
            candidate="$candidate_dir/pfx/drive_c/$relative_path"
            if [ -f "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done <<< "$LAUNCHER_TARGET_RELATIVES"
    return 1
}

installer_is_msi() {
    local file="$1" magic

    magic="$(od -An -tx1 -N4 "$file" 2>/dev/null | tr -d ' \n')"
    case "$magic" in
        d0cf11e0*) return 0 ;;
        *) return 1 ;;
    esac
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
        heihe:interactive) echo "弹出黑盒工坊安装窗口后，点击安装并等待完成即可。" >&2 ;;
        ubisoft:interactive|uplay:interactive) echo "弹出育碧安装窗口后，选择中文并依次点击接受、安装、完成。" >&2 ;;
    esac

    case "$target" in
        epic)
            if installer_is_msi "$installer_file"; then
                if [ "$install_mode" = "silent" ]; then
                    STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                        STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                        "$proton_runner" run msiexec /i "$installer_file" /qn /norestart 2>/dev/null || status=$?
                else
                    STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                        STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                        "$proton_runner" run msiexec /i "$installer_file" 2>/dev/null || status=$?
                fi
            else
                if [ "$install_mode" = "silent" ]; then
                    STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                        STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                        "$proton_runner" run "$installer_file" /S 2>/dev/null || status=$?
                else
                    STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                        STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                        "$proton_runner" run "$installer_file" 2>/dev/null || status=$?
                fi
            fi
            ;;
        battlenet|heihe|ubisoft|uplay)
            if [ "$install_mode" = "silent" ]; then
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                    STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                    "$proton_runner" run "$installer_file" /S 2>/dev/null || status=$?
            else
                STEAM_COMPAT_CLIENT_INSTALL_PATH="$steam_root" STEAM_COMPAT_DATA_PATH="$prefix_dir" \
                    STEAM_COMPAT_APP_ID=0 SteamAppId=0 SteamGameId=0 \
                    "$proton_runner" run "$installer_file" 2>/dev/null || status=$?
            fi
            ;;
    esac
    printf '%s\n' "$status" > "$prefix_dir/.zhoukeer-installer-status" 2>/dev/null || true
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

    if [ "$target" = "battlenet" ] || [ "$target" = "heihe" ]; then
        runner="$(find_proton_10_runner "$steam_root" || true)"
        if [ -n "$runner" ]; then
            printf '%s\n' "$runner"
            return 0
        fi
        install_official_proton_10 "$steam_root"
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
        echo "找不到 Steam 客户端，无法自动准备战网安装环境。" >&2
        return 1
    }
    echo "正在通过 Steam 自动准备战网安装环境..." >&2
    "$steam_bin" "steam://install/$PROTON_EXPERIMENTAL_APP_ID" >/dev/null 2>&1 &
    while [ "$elapsed" -le "$PROTON_INSTALL_TIMEOUT" ]; do
        runner="$(find_proton_experimental_runner "$steam_root" || true)"
        if [ -n "$runner" ]; then
            echo "战网安装环境已准备完成。" >&2
            printf '%s\n' "$runner"
            return 0
        fi
        sleep "$PROTON_INSTALL_INTERVAL"
        elapsed=$((elapsed + PROTON_INSTALL_INTERVAL))
    done
    echo "等待战网安装环境准备超时。请确认 Steam 在线且已登录后重试。" >&2
    return 1
}

create_launcher_wrapper() {
    local target="$1" steam_root="$2" prefix_dir="$3" proton_runner="$4" launcher_exe="$5" destination_dir="$6"
    local steam_app_id="${7:-0}" steam_game_id="${8:-0}"
    local wrapper="$destination_dir/launch-$target.sh"

    case "$steam_app_id:$steam_game_id" in
        *[!0-9:]*|:*)
            echo "Steam 游戏身份参数无效，未创建启动包装器。" >&2
            return 1
            ;;
    esac
    mkdir -p "$destination_dir" || return 1
    cat > "$wrapper" <<EOF
#!/bin/bash
PREFIX_DIR=$(shell_quote "$prefix_dir")
PROTON_RUNNER=$(shell_quote "$proton_runner")
LAUNCHER_EXE=$(shell_quote "$launcher_exe")
STEAM_ROOT=$(shell_quote "$steam_root")
export STEAM_COMPAT_DATA_PATH="\$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$STEAM_ROOT"
export STEAM_COMPAT_APP_ID=$(shell_quote "$steam_app_id")
export SteamAppId=$(shell_quote "$steam_app_id")
export SteamGameId=$(shell_quote "$steam_game_id")
exec "\$PROTON_RUNNER" run "\$LAUNCHER_EXE"
EOF
    chmod +x "$wrapper" || return 1
    printf '%s\n' "$wrapper"
}

shell_quote() {
    local value="$1" escaped

    escaped="${value//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//\$/\\\$}"
    escaped="${escaped//\`/\\\`}"
    printf '"%s"' "$escaped"
}

create_launcher_desktop_shortcut() {
    local target="$1" wrapper="$2" name icon
    case "$target" in
        epic) name="Epic Games 启动器"; icon="$PROJECT_ROOT/assets/game-launchers/epic.png" ;;
        battlenet) name="战网启动器"; icon="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        ubisoft|uplay) name="育碧"; icon="$PROJECT_ROOT/assets/game-launchers/ubisoft.png" ;;
        heihe) name="黑盒工坊"; icon="$PROJECT_ROOT/assets/game-launchers/heihe.png" ;;
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

create_steam_desktop_shortcut() {
    local target="$1" game_id="$2" name icon
    case "$target" in
        battlenet) name="战网启动器"; icon="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        *) return 1 ;;
    esac
    case "$game_id" in
        ''|*[!0-9]*) echo "Steam 游戏编号无效，未创建桌面入口。"; return 1 ;;
    esac
    mkdir -p "$HOME/Desktop" || return 1
    cat > "$HOME/Desktop/$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=steam steam://rungameid/$game_id
Terminal=false
Icon=$icon
Categories=Game;
X-Zhoukeer-Managed=true
EOF
    chmod +x "$HOME/Desktop/$name.desktop"
}

remove_pending_battlenet_desktop_shortcut() {
    local shortcut="$HOME/Desktop/战网启动器.desktop"

    [ -f "$shortcut" ] && [ ! -L "$shortcut" ] || return 0
    grep -Fqx 'X-Zhoukeer-Managed=true' "$shortcut" && \
        grep -Eq '^Exec=steam steam://rungameid/[0-9]+$' "$shortcut" || return 0
    rm -f -- "$shortcut" || return 1
    echo "已移除未完成安装阶段的旧战网桌面入口。"
}

remove_legacy_battlenet_steam_entries() {
    local shortcut_file="$1" keep_exe="$2" remove_output

    remove_output="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" remove \
        --exe-basename "Battle.net Launcher.exe" \
        --exe-basename "Battle.net.exe" \
        --exe-basename "Battle.net-Setup.exe" \
        --exe-basename "launch-battlenet.sh" \
        --keep-exe "$keep_exe" --keep-name "$LAUNCHER_NAME")" || return 1
    if [ "$remove_output" = "removed" ]; then
        echo "已清理旧版战网 Steam 条目，只保留“战网启动器”。"
    fi
}

remove_legacy_battlenet_desktop_installer() {
    local old_installer="$HOME/Desktop/Battle.net-Setup.exe" size magic

    [ -f "$old_installer" ] && [ ! -L "$old_installer" ] || return 0
    size="$(wc -c < "$old_installer" | tr -d ' ')"
    magic="$(od -An -tx1 -N2 "$old_installer" | tr -d ' \n')"
    case "$size" in
        ''|*[!0-9]*) return 0 ;;
    esac
    [ "$size" -ge "${LAUNCHER_MIN_BYTES:-1048576}" ] || return 0
    [ "$magic" = "4d5a" ] || return 0
    rm -f -- "$old_installer" || return 1
    echo "已移除旧版工具箱下载到桌面的战网安装包。"
}

install_launcher_steam_artwork() {
    local target="$1" shortcut_file="$2"
    local asset_name grid_dir app_id signed_app_id

    shift 2
    [ "$#" -gt 0 ] || return 1

    case "$target" in
        epic) asset_name="epic" ;;
        battlenet) asset_name="battlenet" ;;
        ubisoft|uplay) asset_name="ubisoft" ;;
        heihe) asset_name="heihe" ;;
        *) return 1 ;;
    esac
    grid_dir="$(dirname "$shortcut_file")/grid"
    if [ -L "$grid_dir" ]; then
        echo "Steam 封面目录是符号链接，已停止写入：$grid_dir"
        return 1
    fi
    install -d -m 0755 -- "$grid_dir" || return 1
    for app_id in "$@"; do
        case "$app_id" in
            ''|*[!0-9]*) echo "Steam 非 Steam 游戏编号无效，未写入库封面。"; return 1 ;;
        esac
        if [ "${#app_id}" -gt 10 ]; then
            install_launcher_artwork_for_id "$asset_name" "$grid_dir" "$app_id" || return 1
            continue
        fi
        signed_app_id="$app_id"
        if [ "$app_id" -gt 2147483647 ]; then
            signed_app_id=$((app_id - 4294967296))
        fi
        install_launcher_artwork_for_id "$asset_name" "$grid_dir" "$app_id" || return 1
        install_launcher_artwork_for_id "$asset_name" "$grid_dir" "$signed_app_id" || return 1
    done
}

install_launcher_artwork_for_id() {
    local asset_name="$1" grid_dir="$2" artwork_id="$3"

    # Steam 自己的 SetCustomArtworkForApp 写入 PNG；同 stem 残留的 jpg/jpeg
    # 会让取图结果不确定，必须先清理再写入。
    rm -f -- \
        "$grid_dir/${artwork_id}.jpg" \
        "$grid_dir/${artwork_id}.jpeg" \
        "$grid_dir/${artwork_id}.png" \
        "$grid_dir/${artwork_id}p.jpg" \
        "$grid_dir/${artwork_id}p.jpeg" \
        "$grid_dir/${artwork_id}p.png" \
        "$grid_dir/${artwork_id}_hero.jpg" \
        "$grid_dir/${artwork_id}_hero.jpeg" \
        "$grid_dir/${artwork_id}_hero.png" \
        "$grid_dir/${artwork_id}_logo.jpg" \
        "$grid_dir/${artwork_id}_logo.jpeg" \
        "$grid_dir/${artwork_id}_logo.png" \
        "$grid_dir/${artwork_id}_icon.jpg" \
        "$grid_dir/${artwork_id}_icon.jpeg" \
        "$grid_dir/${artwork_id}_icon.png" \
        "$grid_dir/${artwork_id}_background.jpg" \
        "$grid_dir/${artwork_id}_background.png"
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name.png" \
        "$grid_dir/${artwork_id}_icon.png" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name-grid.png" \
        "$grid_dir/${artwork_id}.png" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name-portrait.png" \
        "$grid_dir/${artwork_id}p.png" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name-hero.png" \
        "$grid_dir/${artwork_id}_hero.png" || return 1
    install -m 0644 -- "$PROJECT_ROOT/assets/game-launchers/$asset_name.png" \
        "$grid_dir/${artwork_id}_logo.png" || return 1
    background_file="$PROJECT_ROOT/assets/game-launchers/$asset_name-background.jpg"
    background_ext="jpg"
    if [ ! -f "$background_file" ]; then
        background_file="$PROJECT_ROOT/assets/game-launchers/$asset_name-background.png"
        background_ext="png"
    fi
    [ -f "$background_file" ] || return 1
    install -m 0644 -- "$background_file" \
        "$grid_dir/${artwork_id}_background.$background_ext" || return 1
}

apply_launcher_decky_artwork() {
    local target="$1" app_id="$2"
    local attempt

    [ "${IS_STEAMOS:-0}" -eq 1 ] || return 0
    for attempt in 1 2; do
        if bash "$PROJECT_ROOT/scripts/apply_steam_artwork.sh" "$target" "$app_id" >/dev/null 2>&1; then
            echo "$LAUNCHER_NAME Steam 库封面已即时应用。"
            return 0
        fi
        sleep 2
    done
    echo "$LAUNCHER_NAME Steam 库封面已写入，Steam 重启后生效。"
}

set_steam_proton_10() {
    local steam_root="$1" app_id="$2"
    local config_file="$steam_root/config/config.vdf"

    python3 "$STEAM_COMPAT_HELPER" --config-file "$config_file" \
        --app-id "$app_id" --tool proton_10 >/dev/null
}

print_launcher_proton_hint() {
    echo ""
    echo "============================================================"
    echo "重要：请启动 Steam 后，在库中点击“${LAUNCHER_NAME}”右侧的齿轮"
    echo "→ 属性 → 兼容性，勾选“强制使用兼容性工具”，并选择 Proton 10.0-4。"
    echo "============================================================"
}

prepare_launcher_steam_installer() {
    local target="$1" steam_root="$2" installer_file="$3" shortcut_file="$4"
    local app_id artwork_alt_app_id game_id icon_path

    launcher_details "$target" || return 1
    case "$target" in
        battlenet) icon_path="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        heihe) icon_path="$PROJECT_ROOT/assets/game-launchers/heihe.png" ;;
        *) return 1 ;;
    esac
    stop_steam_for_vdf || return 1
    if [ "$target" = "battlenet" ]; then
        remove_pending_battlenet_desktop_shortcut || return 1
    fi
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$installer_file" --start-dir "$(dirname "$installer_file")" \
        >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$LAUNCHER_NAME" --exe "$installer_file" --icon "$icon_path" >/dev/null || return 1
    app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid \
        --name "$LAUNCHER_NAME" --exe "$installer_file")" || return 1
    artwork_alt_app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid-raw \
        --name "$LAUNCHER_NAME" --exe "$installer_file")" || return 1
    game_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" gameid \
        --name "$LAUNCHER_NAME" --exe "$installer_file")" || return 1
    set_steam_proton_10 "$steam_root" "$app_id" || return 1
    install_launcher_steam_artwork "$target" "$shortcut_file" "$app_id" "$artwork_alt_app_id" "$game_id" || return 1
    echo "Steam 已停止，安装条目、兼容层和封面已写入文件。"
    echo "请手动启动 Steam（桌面模式打开 Steam，或重启进入游戏模式），再在库中点击“${LAUNCHER_NAME}”完成安装。"
    echo "安装阶段不会创建桌面入口，请只在 Steam 库点击“${LAUNCHER_NAME}”完成安装。"
    print_launcher_proton_hint
    echo "安装完成后，再点击一次工具箱的 $LAUNCHER_NAME 入口即可自动转为正式启动器并创建可用桌面入口。"
}

prepare_battlenet_steam_installer() {
    prepare_launcher_steam_installer battlenet "$@"
}

finish_launcher_steam_entry() {
    local target="$1" steam_root="$2" shortcut_file="$3" launcher_exe="$4" prefix_dir="$5" proton_runner="$6"
    local app_id artwork_alt_app_id game_id icon_path wrapper grid_dir grid_icon

    launcher_details "$target" || return 1
    case "$target" in
        battlenet) icon_path="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        heihe) icon_path="$PROJECT_ROOT/assets/game-launchers/heihe.png" ;;
        *) return 1 ;;
    esac
    stop_steam_for_vdf || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe" --start-dir "$(dirname "$launcher_exe")" \
        >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe" --icon "$icon_path" >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe" --icon "$icon_path" \
        >/dev/null || return 1
    if [ "$target" = "battlenet" ]; then
        remove_legacy_battlenet_steam_entries "$shortcut_file" "$launcher_exe" || return 1
    fi
    app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe")" || return 1
    artwork_alt_app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid-raw \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe")" || return 1
    game_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" gameid \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe")" || return 1
    link_steam_compatdata_drive "$steam_root" "$app_id" "$prefix_dir" || return 1
    install_launcher_steam_artwork "$target" "$shortcut_file" "$app_id" "$artwork_alt_app_id" "$game_id" || return 1
    grid_dir="$(dirname "$shortcut_file")/grid"
    grid_icon="$(set_launcher_grid_icon "$shortcut_file" "$LAUNCHER_NAME" "$launcher_exe" \
        "$grid_dir" "$app_id" "$artwork_alt_app_id" "$game_id" || true)"
    if [ -n "$grid_icon" ]; then
        icon_path="$grid_icon"
        python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
            --name "$LAUNCHER_NAME" --exe "$launcher_exe" --icon "$icon_path" \
            >/dev/null || return 1
    fi
    # 部分 Steam 客户端会在桌面 steam://rungameid 链接启动时丢失非 Steam
    # 游戏配置，改用与 Steam 条目同一前缀的包装器，避免“游戏配置文件不可用”。
    wrapper="$(create_launcher_wrapper "$target" "$steam_root" "$prefix_dir" "$proton_runner" \
        "$launcher_exe" "$APP_DIR/game-launchers/$target" "$app_id" "$game_id")" || return 1
    create_launcher_desktop_shortcut "$target" "$wrapper" || return 1
    if [ "$target" = "battlenet" ]; then
        remove_legacy_battlenet_desktop_installer || return 1
    fi
    echo "正在写入 Proton 10.0-4 兼容层..."
    set_steam_proton_10 "$steam_root" "$app_id" || return 1
    echo "Steam 已停止，正式条目、兼容层和封面已写入文件。"
    echo "请手动启动 Steam（桌面模式打开 Steam，或重启进入游戏模式）后确认兼容层和封面。"
    print_launcher_proton_hint
    if [ "$target" = "battlenet" ]; then
        echo "战网登录页：https://account.battle.net/login"
    fi
    echo "$LAUNCHER_NAME 已添加到 Steam 库，桌面入口、封面与工具箱标识均已设置。"
}

finish_battlenet_steam_entry() {
    finish_launcher_steam_entry battlenet "$@"
}

install_launcher() {
    local target="$1" steam_root launcher_exe runner app_dir prefix wrapper shortcut_file installer_file app_id artwork_alt_app_id game_id icon_path workdir platform_drive_c grid_dir grid_icon
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

    if [ "$target" = "battlenet" ] || [ "$target" = "heihe" ]; then
        shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
        if [ -n "$launcher_exe" ]; then
            echo "检测到已安装的 ${LAUNCHER_NAME}，跳过安装包下载。"
            case "$launcher_exe" in
                */pfx/drive_c/*) prefix="${launcher_exe%/pfx/drive_c/*}" ;;
                *) echo "无法确定 $LAUNCHER_NAME 安装环境，已停止写入 Steam 条目。"; return 1 ;;
            esac
            migrate_launcher_drive_to_visible "$target" "$prefix" || return 1
            launcher_exe="$(find_launcher_in_prefix "$prefix" || find_installed_launcher "$steam_root" || true)"
            [ -n "$launcher_exe" ] || {
                echo "$LAUNCHER_NAME 虚拟目录迁移后未找到主程序。"
                return 1
            }
        else
            if [ "$target" = "heihe" ]; then
                platform_drive_c="$(find_battle_platform_drive_c "$steam_root" || true)"
                if [ -z "$platform_drive_c" ]; then
                    echo "未检测到战网启动器，请先安装战网启动器再安装黑盒工坊。"
                    return 1
                fi
            else
                platform_drive_c="$(launcher_drive_c battlenet)"
                mkdir -p "$platform_drive_c" || return 1
            fi
            workdir="$app_dir/.download"
            if [ "${LAUNCHER_PREINSTALLED:-0}" = "1" ] && \
                download_preinstalled_launcher "$workdir" && \
                extract_preinstalled_launcher "$workdir/$LAUNCHER_PREINSTALLED_FILE" "$platform_drive_c"; then
                rm -rf -- "$workdir"
                prefix="$(prepare_launcher_shared_prefix "$target" "$platform_drive_c")" || return 1
                launcher_exe="$prefix/pfx/drive_c/Program Files (x86)/$LAUNCHER_PREINSTALLED_TARGET_RELATIVE"
            else
                rm -rf -- "$workdir"
                echo "$LAUNCHER_NAME 预装客户端不可用，正在回退到 Steam 库安装流程。"
                installer_file="$app_dir/$LAUNCHER_FILE_NAME"
                download_launcher_installer "$installer_file" || return 1
                prepare_launcher_steam_installer "$target" "$steam_root" "$installer_file" "$shortcut_file"
                return
            fi
        fi
        finish_launcher_steam_entry "$target" "$steam_root" "$shortcut_file" "$launcher_exe" "$prefix" "$runner"
        return
    fi

    if [ -n "$launcher_exe" ]; then
        echo "检测到已安装的 ${LAUNCHER_NAME}，跳过安装包下载。"
        case "$launcher_exe" in
            "$prefix"/pfx/drive_c/*) ;;
            *) prefix="${launcher_exe%/pfx/drive_c/*}" ;;
        esac
        migrate_launcher_drive_to_visible "$target" "$prefix" || return 1
        launcher_exe="$(find_launcher_in_prefix "$prefix" || find_installed_launcher "$steam_root" || true)"
        [ -n "$launcher_exe" ] || {
            echo "$LAUNCHER_NAME 虚拟目录迁移后未找到主程序。"
            return 1
        }
    else
        platform_drive_c="$(launcher_drive_c "$target")"
        mkdir -p "$platform_drive_c" || return 1
        prefix="$(prepare_launcher_shared_prefix "$target" "$platform_drive_c")" || return 1
        installer_file="$app_dir/$LAUNCHER_FILE_NAME"
        download_launcher_installer "$installer_file" || return 1
        case "$target" in
            epic|ubisoft|uplay)
                launcher_exe="$(run_launcher_installer "$target" "$steam_root" "$installer_file" "$prefix" "$runner" 120 silent || true)"
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
    case "$target" in
        epic) icon_path="$PROJECT_ROOT/assets/game-launchers/epic.png" ;;
        battlenet) icon_path="$PROJECT_ROOT/assets/game-launchers/battlenet.png" ;;
        ubisoft|uplay) icon_path="$PROJECT_ROOT/assets/game-launchers/ubisoft.png" ;;
        heihe) icon_path="$PROJECT_ROOT/assets/game-launchers/heihe.png" ;;
        *) return 1 ;;
    esac
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe")" || return 1
    artwork_alt_app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" appid-raw \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe")" || return 1
    game_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" gameid \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe")" || return 1
    wrapper="$(create_launcher_wrapper "$target" "$steam_root" "$prefix" "$runner" "$launcher_exe" \
        "$app_dir" "$app_id" "$game_id")" || return 1
    create_launcher_desktop_shortcut "$target" "$wrapper" || return 1
    stop_steam_for_vdf || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe" --start-dir "$(dirname "$launcher_exe")" \
        >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe" --icon "$icon_path" >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
        --name "$LAUNCHER_NAME" --exe "$launcher_exe" --icon "$icon_path" >/dev/null || {
        echo "$LAUNCHER_NAME 的 Steam 条目写入后校验失败，桌面图标仍可使用。"
        return 1
    }
    set_steam_proton_10 "$steam_root" "$app_id" || return 1
    link_steam_compatdata_drive "$steam_root" "$app_id" "$prefix" || return 1
    install_launcher_steam_artwork "$target" "$shortcut_file" "$app_id" "$artwork_alt_app_id" "$game_id" || return 1
    grid_dir="$(dirname "$shortcut_file")/grid"
    grid_icon="$(set_launcher_grid_icon "$shortcut_file" "$LAUNCHER_NAME" "$launcher_exe" \
        "$grid_dir" "$app_id" "$artwork_alt_app_id" "$game_id" || true)"
    if [ -n "$grid_icon" ]; then
        icon_path="$grid_icon"
        python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
            --name "$LAUNCHER_NAME" --exe "$launcher_exe" --icon "$icon_path" \
            >/dev/null || return 1
    fi
    echo "Steam 已停止，Steam 条目与封面已写入文件。"
    echo "请手动启动 Steam（桌面模式打开 Steam，或重启进入游戏模式）后查看。"
    echo "$LAUNCHER_NAME 已添加到 Steam 库，桌面入口、封面与工具箱标识均已设置。"
    if [ "$target" = "epic" ]; then
        echo "Epic 改中文：右上角头像 → Settings → Language → 中文（简体）→ Restart Now。"
        echo "若下载管理器仍显示英文，请选择不带 System Default 的中文（简体）后重启。"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        epic|battlenet|ubisoft|uplay|heihe) install_launcher "$1" ;;
        *) echo "用法: $0 {epic|battlenet|ubisoft}"; exit 1 ;;
    esac
fi
