#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/download_policy.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

download_policy_url_allowed 'https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.AppImage' || fail "固定 GitHub Release 被拒绝"
download_policy_url_allowed 'https://github.com/eugeniosegala/MAKO/releases/download/plugin-v2.1.0/MAKO-Decky-v2.1.0.zip' || fail "MAKO v2.1.0 官方 GitHub Release 被拒绝"
download_policy_url_allowed 'https://github.com/SteamDeckHomebrew/decky-loader/releases/download/v3.2.6/PluginLoader' || fail "Decky 官方 Loader 被拒绝"
download_policy_url_allowed 'https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest' || fail "GitHub 最新 Release API 被拒绝"
download_policy_url_allowed 'https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.6/dist/plugin_loader-release.service' || fail "Decky 官方服务模板被拒绝"
download_policy_url_allowed 'https://dl.todesk.com/linux/todesk-v4.8.6.2-amd64.deb' || fail "ToDesk 官方 DEB 被拒绝"
download_policy_url_allowed 'https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/v6.0.25/todesk-v4.8.6.2-amd64.deb' || fail "ToDesk Release 镜像被拒绝"
download_policy_url_allowed 'https://github.com/panyiwei-home/Friendeck/releases/download/0.7.7/Friendeck.v.0.7.7.zip' || fail "Friendeck 官方 Release 被拒绝"
download_policy_url_allowed 'https://github.com/jinzhongjia/decky-music/releases/download/v1.0.2/Decky.Music.full.zip' || fail "Decky Music 完整包官方 Release 被拒绝"
download_policy_url_allowed 'https://github.com/Ren-Amamiya-pixle/SavePulse/releases/download/v0.2.0-alpha.1/SavePulse.zip' || fail "SavePulse 作者 Release 被拒绝"
download_policy_url_allowed 'https://github.com/HMCL-dev/HMCL/releases/download/v3.16.3/HMCL-3.16.3.jar' || fail "HMCL 官方 Release 被拒绝"
download_policy_url_allowed 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12%2B8/OpenJDK21U-jre_x64_linux_hotspot_21.0.12_8.tar.gz' || fail "Temurin JRE 官方 Release 被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror/raw/main/savepulse/v0.2.0-alpha.1/part.0001' || fail "SavePulse Gitee 分块被拒绝"
download_policy_url_allowed 'https://epicgames-download1.akamaized.net/Builds/UnrealEngineLauncher/Installers/Windows/EpicInstaller-20.1.4.msi?launcherfilename=EpicInstaller-20.1.4.msi' || fail "Epic Akamai CDN 备用地址被拒绝"
download_policy_url_allowed 'https://epicgames-download1.akamaized.net/Builds/UnrealEngineLauncher/Installers/Windows/EpicInstaller-20.1.4.exe' || fail "Epic Akamai EXE 地址被拒绝"
download_policy_url_allowed 'https://gitee.com/easylife2025/battle/releases/download/v1.0.0/Battle.net.7z.001' || fail "战网预装客户端分卷 1 被拒绝"
download_policy_url_allowed 'https://gitee.com/easylife2025/battle/releases/download/v1.0.0/Battle.net.7z.004' || fail "战网预装客户端分卷 4 被拒绝"
[ "$(download_policy_max_bytes 'https://gitee.com/easylife2025/battle/releases/download/v1.0.0/Battle.net.7z.001')" -le 104857600 ] || fail "战网预装客户端分卷大小限制过大"
if download_policy_url_allowed 'https://gitee.com/mclanbai/archtodesk.git'; then fail "旧 ToDesk 第三方仓库仍在白名单"; fi
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/VERSION' || fail "Renkit Gitee 地址被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/VERSION' || fail "Renkit新 Gitee 地址被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror/raw/main/lsfg/latest.txt' || fail "独立镜像仓库地址被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/latest.txt' || fail "Decky Gitee 镜像清单地址被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/PluginLoader-pre.part.00' || fail "Decky Gitee 镜像分块地址被拒绝"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/PluginLoader-pre.part.00' || fail "Decky 新 Gitee 镜像分块地址被拒绝"
[ "$(download_policy_max_bytes 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/latest.txt')" -le 2097152 ] || fail "Decky Gitee 镜像清单大小限制过大"
[ "$(download_policy_max_bytes 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/dist/renkit.tar.gz')" -le 9437184 ] || fail "Renkit新 Gitee 发布包大小限制过大"
for mirror_id in 4 5 6 7; do
    download_policy_url_allowed "https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-${mirror_id}/raw/main/ge-proton-trainer-7-55/latest.txt" || fail "修改器兼容层镜像仓库 mirror-${mirror_id} 未列入白名单"
    download_policy_url_allowed "https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-${mirror_id}/raw/main/ge-proton-trainer-7-55/GE-Proton7-55.tar.gz" || fail "修改器兼容层文件地址被拒绝：mirror-${mirror_id}"
    [ "$(download_policy_max_bytes "https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-${mirror_id}/raw/main/ge-proton-trainer-7-55/part.0001")" -le 8388608 ] || fail "修改器兼容层分块大小限制异常：mirror-${mirror_id}"
done
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-8/raw/main/ge-proton/latest.txt' || fail "GE-Proton mirror-8 清单地址未列入白名单"
[ "$(download_policy_max_bytes 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-8/raw/main/ge-proton/GE-Proton11-5/part.0001')" -le 8388608 ] || fail "GE-Proton mirror-8 分块大小限制异常"
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-9/raw/main/proton-cachyos/latest.txt' || fail "Proton-CachyOS mirror-9 清单地址未列入白名单"
[ "$(download_policy_max_bytes 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-9/raw/main/proton-cachyos/proton-cachyos-11.0-test-slr-x86_64/part.0001')" -le 8388608 ] || fail "Proton-CachyOS mirror-9 分块大小限制异常"
download_policy_github_repo_allowed 'CachyOS/proton-cachyos' || fail "Proton-CachyOS 上游仓库未列入白名单"
if download_policy_url_allowed 'https://evil.example/payload.sh'; then fail "任意域名被白名单接受"; fi
download_policy_github_mirror_allowed 'https://ghfast.top/' || fail "GitHub Release 加速源被拒绝"
for mirror in \
    'https://ghproxy.net/' \
    'https://gh.api.99988866.xyz/' \
    'https://github.moeyy.xyz/' \
    'https://gh.llkk.cc/' \
    'https://mirror.ghproxy.com/' \
    'https://gh.ddlc.com/' \
    'https://gh-proxy.lanqier.me/'; do
    download_policy_github_mirror_allowed "$mirror" || fail "现有 GitHub 加速源被拒绝：$mirror"
done
if download_policy_github_mirror_allowed 'https://unknown-mirror.example/'; then fail "未知 GitHub 加速源被接受"; fi

printf '<!doctype html><html>403</html>\n' > "$TMP_ROOT/error.zip"
if download_policy_response_is_safe 'https://github.com/SheffeyG/CheatDeck/releases/download/v2.0.0/CheatDeck.zip' "$TMP_ROOT/error.zip"; then
    fail "HTML 错误页被当成 ZIP"
fi
printf '\x50\x4b\x03\x04payload' > "$TMP_ROOT/good.zip"
download_policy_response_is_safe 'https://github.com/SheffeyG/CheatDeck/releases/download/v2.0.0/CheatDeck.zip' "$TMP_ROOT/good.zip" || fail "合法 ZIP 魔数被拒绝"
printf '!<arch>\npackage' > "$TMP_ROOT/good.deb"
download_policy_response_is_safe 'https://dl.todesk.com/linux/todesk-v4.8.6.2-amd64.deb' "$TMP_ROOT/good.deb" || fail "合法 DEB 魔数被拒绝"
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
download_policy_github_mirror_allowed "$GITHUB_RELEASE_PROXY" || fail "GitHub Release 代理未列入白名单：$GITHUB_RELEASE_PROXY"

for stale_proxy in https://ghproxy.com https://ghfast.top.cn https://ghproxy.cc https://unknown-mirror.example; do
    if rg -F "$stale_proxy" \
        "$PROJECT_ROOT/config/settings.conf" \
        "$PROJECT_ROOT/config/settings.example.conf" \
        "$PROJECT_ROOT/core/env.sh" \
        "$PROJECT_ROOT/core/download_policy.sh" >/dev/null; then
        fail "过期 GitHub 代理仍在运行时配置中：$stale_proxy"
    fi
done

if rg -n -- '--show-error' \
    "$PROJECT_ROOT/modules" \
    "$PROJECT_ROOT/utils" \
    "$PROJECT_ROOT/bootstrap.sh" \
    "$PROJECT_ROOT/update.sh" >/dev/null 2>&1; then
    fail "下载路径仍会向界面泄漏 curl 原始错误（--show-error）"
fi

echo "PASS: 下载白名单、大小限制、危险响应和受控回退清单测试通过"
