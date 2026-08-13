#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DECKY_DIR="${ZHOUKEER_DECKY_SYNC_DIR:-$ROOT/decky-installer-cn}"
API="${ZHOUKEER_DECKY_SYNC_API:-https://api.github.com/repos/SteamDeckHomebrew/decky-loader}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT
STAGED_DECKY_DIR="$TMP_DIR/decky-installer-cn"
CURL_RETRIES="${ZHOUKEER_DECKY_SYNC_CURL_RETRIES:-5}"
CURL_RETRY_DELAY="${ZHOUKEER_DECKY_SYNC_CURL_RETRY_DELAY:-3}"

mkdir -p "$DECKY_DIR" "$STAGED_DECKY_DIR"

curl_decky() {
    local max_time="$1"
    shift
    local auth_args=()

    # Actions 的令牌只用于 GitHub 官方接口，降低匿名 API 限流和临时 503 的概率。
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    curl -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time "$max_time" \
        --retry "$CURL_RETRIES" --retry-delay "$CURL_RETRY_DELAY" \
        --retry-all-errors "${auth_args[@]}" "$@"
}

keep_existing_mirror() {
    echo "::warning::$1；保留现有已校验 Decky 镜像，本次同步跳过。"
    exit 0
}

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
        return 1
    }

    curl_decky 600 -o "$TMP_DIR/$prefix" "$url" || return 1
    [ "$(sha_of "$TMP_DIR/$prefix")" = "$sha" ] || {
        echo "Decky $channel loader SHA256 mismatch"
        return 1
    }

    service_url="https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/$tag/dist/$service_name"
    curl_decky 60 -o "$TMP_DIR/$service_name" "$service_url" || return 1

    split -b 8388608 -d -a 2 "$TMP_DIR/$prefix" "$STAGED_DECKY_DIR/$prefix.part."
    cp -- "$TMP_DIR/$service_name" "$STAGED_DECKY_DIR/$service_name"

    part_sha="$(for f in "$STAGED_DECKY_DIR/$prefix".part.*; do sha_of "$f"; done | paste -sd, -)"
    parts="$(find "$STAGED_DECKY_DIR" -maxdepth 1 -name "$prefix.part.*" | wc -l | tr -d ' ')"
    loader_sha="$(sha_of "$TMP_DIR/$prefix")"
    service_sha="$(sha_of "$STAGED_DECKY_DIR/$service_name")"

    printf '%s_version=%s\n' "$channel" "$tag"
    printf '%s_parts=%s\n' "$channel" "$parts"
    printf '%s_sha256=%s\n' "$channel" "$loader_sha"
    printf '%s_part_sha256=%s\n' "$channel" "$part_sha"
    printf '%s_service_sha256=%s\n' "$channel" "$service_sha"
}

stable_json="$(curl_decky 60 "$API/releases/latest")" || \
    keep_existing_mirror "Decky 稳定版元数据暂时不可用"
prerelease_response="$(curl_decky 60 "$API/releases?per_page=20")" || \
    keep_existing_mirror "Decky 测试版元数据暂时不可用"
prerelease_json="$(printf '%s' "$prerelease_response" | jq -c '
    [.[] | select(.prerelease == true)] | .[0]')" || \
    keep_existing_mirror "Decky 测试版元数据解析失败"

sync_channel stable PluginLoader plugin_loader-release.service "$stable_json" \
    > "$TMP_DIR/stable.txt" || keep_existing_mirror "Decky 稳定版资源暂时不可用或校验失败"
sync_channel prerelease PluginLoader-pre plugin_loader-prerelease.service "$prerelease_json" \
    > "$TMP_DIR/prerelease.txt" || keep_existing_mirror "Decky 测试版资源暂时不可用或校验失败"

cat "$TMP_DIR/stable.txt" "$TMP_DIR/prerelease.txt" > "$STAGED_DECKY_DIR/latest.txt"

# 两个通道全部下载并校验后才替换工作区，任何临时网络错误都不会留下半套镜像。
rm -f -- \
    "$DECKY_DIR"/PluginLoader.part.* \
    "$DECKY_DIR"/PluginLoader-pre.part.* \
    "$DECKY_DIR/plugin_loader-release.service" \
    "$DECKY_DIR/plugin_loader-prerelease.service" \
    "$DECKY_DIR/latest.txt"
cp -a -- "$STAGED_DECKY_DIR/." "$DECKY_DIR/"
echo "Decky Gitee mirror synced"
