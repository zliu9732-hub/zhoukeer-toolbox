#!/bin/bash

# 通过 Decky 的 execute_in_tab 通道调用 SteamClient.Apps.SetCustomArtworkForApp，
# 让启动器 Steam 库封面即时生效，与 SteamGridDB 插件使用同一套 API。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$ROOT/modules/decky_bundle.sh"

find_launcher_shortcut_appid() {
    local target="$1" name vdf

    case "$target" in
        epic) name="Epic Games 启动器" ;;
        battlenet) name="战网启动器" ;;
        ubisoft|uplay) name="育碧" ;;
        heihe) name="黑盒工坊" ;;
    esac
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
    python3 "$ROOT/scripts/steam_shortcut.py" --shortcut-file "$vdf" \
        find-appid --name "$name"
}

target="${1:-}"
shift || true
case "$target" in
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
