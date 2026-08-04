#!/bin/bash

# 通过 Decky 的 execute_in_tab 通道调用 SteamClient.Apps.SetCustomArtworkForApp，
# 让启动器 Steam 库封面即时生效，与 SteamGridDB 插件使用同一套 API。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$ROOT/modules/decky_bundle.sh"

find_launcher_shortcut_file() {
    local vdf

    if [ -n "${ZHOUKEER_SHORTCUT_FILE:-}" ]; then
        vdf="$ZHOUKEER_SHORTCUT_FILE"
    else
        vdf="$(find "$HOME/.local/share/Steam/userdata" "$HOME/.steam/steam/userdata" \
            -maxdepth 3 -type f -name shortcuts.vdf -print0 2>/dev/null | \
            xargs -0 -r ls -t 2>/dev/null | head -n 1)"
    fi
    [ -n "$vdf" ] && [ -f "$vdf" ] || {
        echo "未找到 shortcuts.vdf，请先安装启动器并登录 Steam。"
        return 1
    }
    printf '%s\n' "$vdf"
}

find_launcher_shortcut_appid() {
    local target="$1" name vdf

    case "$target" in
        epic) name="Epic Games 启动器" ;;
        battlenet) name="战网启动器" ;;
        ubisoft|uplay) name="育碧" ;;
        heihe) name="黑盒工坊" ;;
    esac
    vdf="$(find_launcher_shortcut_file)" || return 1
    python3 "$ROOT/scripts/steam_shortcut.py" --shortcut-file "$vdf" \
        find-appid --name "$name"
}

verify_launcher_artwork() {
    local target="$1" name vdf app_id signed_app_id game_id grid_dir artwork missing token

    case "$target" in
        epic) name="Epic Games 启动器" ;;
        battlenet) name="战网启动器" ;;
        ubisoft|uplay) name="育碧" ;;
        heihe) name="黑盒工坊" ;;
    esac
    vdf="$(find_launcher_shortcut_file)" || return 1
    app_id="$(python3 "$ROOT/scripts/steam_shortcut.py" --shortcut-file "$vdf" \
        find-appid --name "$name")" || return 1
    signed_app_id="$app_id"
    if [ "$app_id" -gt 2147483647 ]; then
        signed_app_id=$((app_id - 4294967296))
    fi
    game_id="$(python3 -c 'import sys; print((int(sys.argv[1]) << 32) | 0x02000000)' "$app_id")" || return 1
    grid_dir="$(dirname "$vdf")/grid"
    missing=0

    echo "shortcuts.vdf: $vdf"
    echo "appid: $app_id"
    echo "grid: $grid_dir"
    for check_id in "$app_id" "$signed_app_id" "$game_id"; do
        for artwork in "$check_id.png" "${check_id}p.png" "${check_id}_hero.png" \
            "${check_id}_logo.png" "${check_id}_icon.png"; do
            if [ -f "$grid_dir/$artwork" ]; then
                echo "  $artwork 存在"
            else
                echo "  $artwork 缺失"
                missing=1
            fi
        done
        if [ -f "$grid_dir/${check_id}_background.jpg" ] || \
            [ -f "$grid_dir/${check_id}_background.png" ]; then
            echo "  ${check_id}_background 存在"
        else
            echo "  ${check_id}_background 缺失"
            missing=1
        fi
    done
    token="$(curl --fail --silent --connect-timeout 3 --max-time 10 \
        "$DECKY_API_BASE/auth/token" 2>/dev/null || true)"
    if [ -n "$token" ]; then
        echo "Decky Loader: 运行中"
    else
        echo "Decky Loader: 未检测到"
    fi
    [ "$missing" -eq 0 ] || return 1
}

target="${1:-}"
shift || true
case "$target" in
    verify)
        target="${1:-}"
        shift || true
        case "$target" in
            epic|battlenet|ubisoft|uplay|heihe) ;;
            *)
                echo "用法: bash scripts/apply_steam_artwork.sh verify <epic|battlenet|ubisoft|heihe>"
                exit 1
                ;;
        esac
        verify_launcher_artwork "$target"
        exit $?
        ;;
    epic|battlenet|ubisoft|uplay|heihe) ;;
    *)
        echo "用法: bash scripts/apply_steam_artwork.sh <epic|battlenet|ubisoft|heihe> [appid...]"
        exit 1
        ;;
esac

if [ "$#" -eq 0 ]; then
    found_appid="$(find_launcher_shortcut_appid "$target")" || exit 1
    set -- "$found_appid"
fi

apply_steam_launcher_artwork_via_decky "$target" "$@"
