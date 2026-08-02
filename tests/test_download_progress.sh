#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

function_section() {
    local file="$1"
    local start="$2"
    local end="$3"

    sed -n "/^${start}()/,/^${end}()/p" "$PROJECT_ROOT/$file"
}

assert_payload_progress() {
    local file="$1"
    local start="$2"
    local end="$3"
    local body

    body="$(function_section "$file" "$start" "$end")"
    [ -n "$body" ] || fail "没有找到下载函数：$file $start"
    printf '%s\n' "$body" | grep -Fq -- '--progress-meter' || \
        fail "$file 的 $start 没有显示实时下载速度"
    if printf '%s\n' "$body" | grep -Fq -- '--silent'; then
        fail "$file 的 $start 仍用静默模式隐藏下载进度"
    fi
}

assert_payload_progress utils/github_download.sh download_github_file _parse_latest_github_release
assert_payload_progress modules/software.sh install_official_qq_appimage install_official_wechat_appimage
assert_payload_progress modules/software.sh install_official_wechat_appimage install_rustdesk_appimage
assert_payload_progress modules/software.sh install_firefox_archive software_is_installed
assert_payload_progress modules/game_launchers.sh download_launcher_installer find_steam_root
assert_payload_progress modules/steam_accelerator.sh download_steam302_archive verify_steam302_archive
assert_payload_progress modules/todesk.sh download_todesk_package has_trusted_ca_bundle
assert_payload_progress modules/plugin_store.sh download_decky_component download_decky_component_with_fallback
assert_payload_progress update.sh download_one download_version_one
assert_payload_progress bootstrap.sh download_one valid_sha256

# 版本查询、测速和 API 元数据请求不是安装包下载，必须继续保持静默，
# 否则一次安装会闪出多个没有意义的 100%。
function_section update.sh download_version_one valid_release_version | \
    grep -Fq -- '--silent' || fail "版本查询不应显示伪进度"

if grep -Eq 'flatpak install .*2>/dev/null' "$PROJECT_ROOT/modules/software.sh"; then
    fail "Flatpak 安装仍把原生百分比进度重定向隐藏"
fi

echo "PASS: 软件、插件、启动器和更新包下载均显示实时速度，元数据请求保持静默"
