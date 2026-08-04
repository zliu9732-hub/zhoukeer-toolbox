#!/bin/bash

# 通过 Decky execute_in_tab 调用 SteamClient.Browser.OpenUrl，
# 在 Steam 内置浏览器中打开指定 https 地址。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$ROOT/modules/decky_bundle.sh"

url="${1:-}"
case "$url" in
    https://*) ;;
    *)
        echo "用法: bash scripts/open_steam_internal_browser.sh <https://...>"
        exit 1
        ;;
esac

open_steam_internal_browser_via_decky "$url"
