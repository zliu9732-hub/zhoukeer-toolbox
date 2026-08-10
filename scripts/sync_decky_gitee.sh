#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DECKY_DIR="$ROOT/decky-installer-cn"
API="https://api.github.com/repos/SteamDeckHomebrew/decky-loader"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

sha_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    else
        shasum -a 256 -- "$1" | awk '{print $1}'
    fi
}

sync_channel() {
    local channel="$1" prefix="$2" service_name="$3" release_json="$4"
    local tag url sha service_url loader_sha service_sha part_sha

    tag="$(printf '%s' "$release_json" | jq -r '.tag_name')"
    url="$(printf '%s' "$release_json" | jq -r '
        .assets[]? | select(.name == "PluginLoader") | .browser_download_url' | head -n 1)"
    sha="$(printf '%s' "$release_json" | jq -r '
        .assets[]? | select(.name == "PluginLoader") | .digest' | head -n 1)"
    sha="${sha#sha256:}"
    [ -n "$tag" ] && [ -n "$url" ] && [ "${#sha}" -eq 64 ] || {
        echo "Decky $channel release metadata incomplete"
        exit 1
    }

    curl -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 600 -o "$TMP_DIR/$prefix" "$url"
    [ "$(sha_of "$TMP_DIR/$prefix")" = "$sha" ] || {
        echo "Decky $channel loader SHA256 mismatch"
        exit 1
    }

    service_url="https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/$tag/dist/$service_name"
    curl -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 60 -o "$TMP_DIR/$service_name" "$service_url"

    rm -f -- "$DECKY_DIR/$prefix".part.*
    split -b 8388608 -d -a 2 "$TMP_DIR/$prefix" "$DECKY_DIR/$prefix.part."
    cp -- "$TMP_DIR/$service_name" "$DECKY_DIR/$service_name"

    part_sha="$(for f in "$DECKY_DIR/$prefix".part.*; do sha_of "$f"; done | paste -sd, -)"
    parts="$(find "$DECKY_DIR" -maxdepth 1 -name "$prefix.part.*" | wc -l | tr -d ' ')"
    loader_sha="$(sha_of "$TMP_DIR/$prefix")"
    service_sha="$(sha_of "$DECKY_DIR/$service_name")"

    printf '%s_version=%s\n' "$channel" "$tag"
    printf '%s_parts=%s\n' "$channel" "$parts"
    printf '%s_sha256=%s\n' "$channel" "$loader_sha"
    printf '%s_part_sha256=%s\n' "$channel" "$part_sha"
    printf '%s_service_sha256=%s\n' "$channel" "$service_sha"
}

stable_json="$(curl -fsSL --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 60 "$API/releases/latest")"
prerelease_json="$(curl -fsSL --proto '=https' --proto-redir '=https' \
    --connect-timeout 15 --max-time 60 "$API/releases?per_page=20" | jq -c '
        [.[] | select(.prerelease == true)] | .[0]')"

sync_channel stable PluginLoader plugin_loader-release.service "$stable_json" > "$TMP_DIR/stable.txt"
sync_channel prerelease PluginLoader-pre plugin_loader-prerelease.service "$prerelease_json" > "$TMP_DIR/prerelease.txt"

cat "$TMP_DIR/stable.txt" "$TMP_DIR/prerelease.txt" > "$DECKY_DIR/latest.txt"
echo "Decky Gitee mirror synced"
