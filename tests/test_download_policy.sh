#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/download_policy.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

download_policy_url_allowed 'https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.AppImage' || fail "固定 GitHub Release 被拒绝"
download_policy_url_allowed 'https://github.com/SteamDeckHomebrew/decky-loader/releases/download/v3.2.6/PluginLoader' || fail "Decky 官方 Loader 被拒绝"
download_policy_url_allowed 'https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.6/dist/plugin_loader-release.service' || fail "Decky 官方服务模板被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/VERSION' || fail "工具箱 Gitee 地址被拒绝"
if download_policy_url_allowed 'https://evil.example/payload.sh'; then fail "任意域名被白名单接受"; fi
download_policy_github_mirror_allowed 'https://ghproxy.net/' || fail "现有 GitHub 加速源被拒绝"
if download_policy_github_mirror_allowed 'https://unknown-mirror.example/'; then fail "未知 GitHub 加速源被接受"; fi

printf '<!doctype html><html>403</html>\n' > "$TMP_ROOT/error.zip"
if download_policy_response_is_safe 'https://github.com/SheffeyG/CheatDeck/releases/download/v1.2.1/CheatDeck.zip' "$TMP_ROOT/error.zip"; then
    fail "HTML 错误页被当成 ZIP"
fi
printf '\x50\x4b\x03\x04payload' > "$TMP_ROOT/good.zip"
download_policy_response_is_safe 'https://github.com/SheffeyG/CheatDeck/releases/download/v1.2.1/CheatDeck.zip' "$TMP_ROOT/good.zip" || fail "合法 ZIP 魔数被拒绝"
dd if=/dev/zero of="$TMP_ROOT/large.VERSION" bs=1048576 count=3 >/dev/null 2>&1
if download_policy_response_is_safe 'https://jktool.icu/VERSION' "$TMP_ROOT/large.VERSION"; then fail "超出大小限制的响应被接受"; fi

catalog="$(download_policy_source_catalog)"
for field in '用途' 'SHA256' '回退' '9437184'; do
    printf '%s\n' "$catalog" | grep -Fq "$field" || fail "受控来源清单缺少字段：$field"
done

# 配置中每个下载 URL 都必须能通过代码白名单；镜像列表也只能保留已审计项。
# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/env.sh"
load_config
while IFS= read -r key; do
    value="${!key:-}"
    [ -z "$value" ] || download_policy_url_allowed "$value" || fail "配置下载地址未列入白名单：$key"
done < <(sed -n 's/^\([A-Z][A-Z0-9_]*_URL\)=.*/\1/p' "$PROJECT_ROOT/config/settings.conf")
for mirror in $GITHUB_MIRRORS; do
    download_policy_github_mirror_allowed "$mirror" || fail "配置 GitHub 镜像未列入白名单：$mirror"
done

echo "PASS: 下载白名单、大小限制、危险响应和受控回退清单测试通过"
