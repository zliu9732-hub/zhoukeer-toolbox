#!/bin/bash

# 优先用 Steam 自带 steam://openurl 协议打开内置浏览器；
# 找不到 steam 命令时才走 Decky execute_in_tab 兜底。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"

url="${1:-}"
case "$url" in
    https://*) ;;
    *)
        echo "用法: bash scripts/open_steam_internal_browser.sh <https://...>"
        exit 1
        ;;
esac

steam_bin="${ZHOUKEER_STEAM_BIN:-}"
if [ -z "$steam_bin" ]; then
    if command -v steam >/dev/null 2>&1; then
        steam_bin="$(command -v steam)"
    elif [ -x "$HOME/.steam/steam/steam.sh" ]; then
        steam_bin="$HOME/.steam/steam/steam.sh"
    elif [ -x "$HOME/.local/share/Steam/steam.sh" ]; then
        steam_bin="$HOME/.local/share/Steam/steam.sh"
    fi
fi
if [ -n "$steam_bin" ]; then
    "$steam_bin" "steam://openurl/$url" >/dev/null 2>&1
    echo "已用 Steam 内置浏览器打开：$url"
    exit 0
fi

# shellcheck disable=SC1091
source "$ROOT/modules/decky_bundle.sh"
open_steam_internal_browser_via_decky "$url"
