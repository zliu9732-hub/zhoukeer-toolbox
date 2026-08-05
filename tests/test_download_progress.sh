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
    local allow_conditional_silent="${4:-0}"
    local body

    body="$(function_section "$file" "$start" "$end")"
    [ -n "$body" ] || fail "没有找到下载函数：$file $start"
    printf '%s\n' "$body" | grep -Fq -- '--progress-meter' || \
        fail "$file 的 $start 没有显示实时下载速度"
    if printf '%s\n' "$body" | grep -Fq -- '--silent'; then
        if [ "$allow_conditional_silent" = "1" ]; then
            printf '%s\n' "$body" | grep -Fq 'if [ "$quiet" = "1" ]; then' || \
                fail "$file 的 $start 的静默开关未限制在 quiet 分支"
        else
            fail "$file 的 $start 仍用静默模式隐藏下载进度"
        fi
    fi
}

assert_payload_progress utils/github_download.sh download_github_file _parse_latest_github_release 1
assert_payload_progress modules/software.sh install_official_qq_appimage install_official_wechat_appimage
assert_payload_progress modules/software.sh install_official_wechat_appimage install_rustdesk_appimage
assert_payload_progress modules/software.sh install_firefox_archive software_is_installed
assert_payload_progress modules/game_launchers.sh download_launcher_installer find_steam_root
assert_payload_progress utils/gitee_download.sh _gitee_mirror_download_one download_gitee_mirror_file 1
assert_payload_progress modules/todesk.sh download_todesk_package has_trusted_ca_bundle
assert_payload_progress modules/plugin_store.sh download_decky_component download_decky_component_with_fallback
assert_payload_progress update.sh download_one download_version_one
assert_payload_progress bootstrap.sh download_one valid_sha256
grep -Eq '^download_progress_filter\(\)' "$PROJECT_ROOT/bootstrap.sh" || \
    fail "bootstrap.sh 缺少独立 download_progress_filter 定义"

# curl --progress-meter 自带的英文表头、警告和错误不能漏到终端。
# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/download_policy.sh"
filtered="$(
    printf '%s\n' \
        '  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current' \
        '                                 Dload  Upload   Total   Spent    Left  Speed' \
        '  100  1234  100  1234    0     0   5678      0 --:--:-- --:--:-- --:--:--  5678' \
        'curl: (28) Operation timed out' \
        'warning: some proxy warning' |
        download_progress_filter "测试下载"
)"
printf '%s\n' "$filtered" | grep -Fq '正在下载 测试下载' || \
    fail "实时下载速度被过滤掉了"
if printf '%s\n' "$filtered" | grep -Eq 'Dload|% Total|curl: \(|warning:'; then
    fail "curl 英文表头/警告/错误泄漏到终端"
fi

# 版本查询、测速和 API 元数据请求不是安装包下载，必须继续保持静默，
# 否则一次安装会闪出多个没有意义的 100%。
function_section update.sh download_version_one valid_release_version | \
    grep -Fq -- '--silent' || fail "版本查询不应显示伪进度"

if grep -Eq 'flatpak install .*2>/dev/null' "$PROJECT_ROOT/modules/software.sh"; then
    fail "Flatpak 安装仍把原生百分比进度重定向隐藏"
fi

echo "PASS: 软件、插件、启动器和更新包下载均显示实时速度，元数据请求保持静默"
