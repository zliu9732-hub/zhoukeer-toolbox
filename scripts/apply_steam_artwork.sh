#!/bin/bash

# 通过 Decky 的 execute_in_tab 通道调用 SteamClient.Apps.SetCustomArtworkForApp，
# 让启动器 Steam 库封面即时生效，与 SteamGridDB 插件使用同一套 API。

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$ROOT/modules/decky_bundle.sh"

target="${1:-}"
shift || true
case "$target" in
    epic|battlenet|ubisoft|uplay) ;;
    *)
        echo "用法: bash scripts/apply_steam_artwork.sh <epic|battlenet|ubisoft> <appid> [appid...]"
        exit 1
        ;;
esac

apply_steam_launcher_artwork_via_decky "$target" "$@"
