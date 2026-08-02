#!/bin/bash

# 下载供应链策略由工具箱代码维护，不能从用户配置扩展域名。
# 调用方仍须校验固定版本的 SHA256/签名；白名单只决定是否允许发起请求。

if [ -n "${ZHOUKEER_DOWNLOAD_POLICY_LOADED:-}" ]; then
    return 0
fi
ZHOUKEER_DOWNLOAD_POLICY_LOADED=1

download_policy_source_catalog() {
    cat <<'EOF'
ID|域名|用途|允许文件类型|版本策略|校验方式|大小上限（字节）|回退规则
toolbox-gitee|gitee.com|工具箱版本、校验文件与固定归档|text,sha256,tar.gz,zip|固定 main 或固定标签|SHA256+包内版本|9437184|域名源→GitHub
toolbox-github|raw.githubusercontent.com,github.com|工具箱更新与固定 Release|text,sha256,tar.gz,zip,AppImage|固定仓库、版本或标签|SHA256+结构检查|1073741824|Gitee/域名源
toolbox-domain|jktool.icu|工具箱更新备用|text,sha256,tar.gz|固定 main 发布内容|SHA256+包内版本|9437184|GitHub→Gitee
github-proxy|ghproxy.net,gh.api.99988866.xyz,github.moeyy.xyz,gh.llkk.cc,mirror.ghproxy.com,gh.ddlc.com,gh-proxy.lanqier.me,ghfast.top|固定 GitHub 文件加速|同原始文件|只转发白名单 GitHub URL|调用方固定 SHA256|1073741824|GitHub 官方源
github-api|api.github.com|GitHub 最新正式 Release 元数据|json|仅最新正式 Release|GitHub SHA256 digest|2097152|固定版本回退
decky|www.mhhf.com,github.com,raw.githubusercontent.com,plugins.deckbrew.xyz,cdn.tzatzikiweeb.moe|Decky 国内镜像、官方国外源和官方插件|binary,service,json,zip|固定版本或 Decky 官方数据库|SHA256/Decky hash|536870912|国内镜像→Decky官方源→停止安装
flathub|mirror.sjtu.edu.cn,mirrors.ustc.edu.cn,dl.flathub.org|Flatpak 国内缓存与官方源|flatpakrepo,repo|固定远程|Flatpak GPG；国内缓存例外需明确确认|2097152|上海交大→中科大→官方
vendors|qq-web.cdn-go.cn,im.qq.com,qqdl.gtimg.cn,dldir1v6.qq.com,launcher-public-service-prod06.ol.epicgames.com,epicgames-download1.akamaized.net,downloader.battle.net,static3.cdn.ubi.com|官方应用安装包|json,AppImage,exe,msi|官方当前版或固定版|官方HTTPS+固定路径+类型/大小；固定版另验SHA256|536870912|停止安装
steam302|www.dogfight360.com|Steamcommunity 302 固定版本|tar.gz|固定版本|MD5+SHA256+结构检查|536870912|停止安装
todesk|github.com,dl.todesk.com|ToDesk 官方 Linux 客户端的未修改镜像与官网|deb|固定官方版本|SHA256+DEB/包内结构|268435456|GitHub镜像源→官网→停止安装
EOF
}

download_policy_github_repo_allowed() {
    case "$1" in
        SteamDeckHomebrew/decky-loader|xXJSONDeruloXx/decky-lsfg-vk|xXJSONDeruloXx/Decky-Framegen|SheffeyG/CheatDeck|YukiCoco/ToMoon|Ren-Amamiya-pixle/DeckRecall|aarron-lee/SimpleDeckyTDP|mubaraknumann/unifideck|panyiwei-home/Freedeck|GloriousEggroll/proton-ge-custom|rustdesk/rustdesk|zliu9732-hub/zhoukeer-toolbox) return 0 ;;
        *) return 1 ;;
    esac
}

download_policy_github_mirror_allowed() {
    case "${1%/}" in
        https://github.com|https://ghproxy.net|https://gh.api.99988866.xyz|https://github.moeyy.xyz|https://gh.llkk.cc|https://mirror.ghproxy.com|https://gh.ddlc.com|https://gh-proxy.lanqier.me|https://ghfast.top) return 0 ;;
        *) return 1 ;;
    esac
}

download_policy_url_allowed() {
    local url="$1"
    local rest repo

    case "$url" in
        https://api.github.com/repos/*/releases/latest) return 0 ;;
        https://github.com/*)
            rest="${url#https://github.com/}"
            repo="${rest%%/releases/*}"
            [ "$repo" != "$rest" ] || repo="${rest%%/archive/*}"
            download_policy_github_repo_allowed "$repo"
            ;;
        https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/*) return 0 ;;
        https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.6/dist/plugin_loader-release.service) return 0 ;;
        https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.8-pre1/dist/plugin_loader-prerelease.service) return 0 ;;
        https://gitee.com/zliu9732-hub/zhoukeer-toolbox/*) return 0 ;;
        https://dl.todesk.com/linux/todesk-v4.8.6.2-amd64.deb) return 0 ;;
        https://jktool.icu/VERSION|https://jktool.icu/dist/SHA256SUMS|https://jktool.icu/dist/zhoukeer-toolbox.tar.gz) return 0 ;;
        https://www.mhhf.com/Deck/decky/*|https://plugins.deckbrew.xyz/plugins|https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/*) return 0 ;;
        https://mirror.sjtu.edu.cn/flathub*|https://mirrors.ustc.edu.cn/flathub*|https://mirrors.ustc.edu.cn/archlinuxcn/*|https://dl.flathub.org/repo/*) return 0 ;;
        https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json|https://im.qq.com/proxy/domain/qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json|https://qqdl.gtimg.cn/qqfile/*.AppImage|https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage) return 0 ;;
        https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi|https://downloader.battle.net/download/getInstallerForGame\?os=win\&installer=Battle.net-Setup.exe|https://static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe) return 0 ;;
        https://epicgames-download1.akamaized.net/Builds/UnrealEngineLauncher/Installers/Windows/EpicInstaller-20.1.4.msi*) return 0 ;;
        https://www.dogfight360.com/blog/wp-content/uploads/2026/02/steamcommunity_302_Linux_AMD64_V14.0.02.tar.gz) return 0 ;;
        *)
            if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ]; then
                case "$url" in https://*) return 0 ;; esac
            fi
            return 1
            ;;
    esac
}

download_policy_max_bytes() {
    case "${1%%\?*}" in
        https://api.github.com/*) printf '%s\n' 2097152 ;;
        https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/dist/zhoukeer-toolbox.tar.gz|https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/dist/zhoukeer-toolbox.tar.gz|https://jktool.icu/dist/zhoukeer-toolbox.tar.gz) printf '%s\n' 9437184 ;;
        */VERSION|*/SHA256SUMS|*.json|*.flatpakrepo|*.service) printf '%s\n' 2097152 ;;
        *.deb) printf '%s\n' 268435456 ;;
        *.AppImage|*.exe|*.msi|*.zip) printf '%s\n' 536870912 ;;
        *.tar.gz|*.tar.zst) printf '%s\n' 1073741824 ;;
        *) printf '%s\n' 134217728 ;;
    esac
}

download_policy_file_size() {
    if stat -c '%s' -- "$1" >/dev/null 2>&1; then
        stat -c '%s' -- "$1"
    else
        stat -f '%z' -- "$1"
    fi
}

download_policy_response_is_safe() {
    local url="$1"
    local file="$2"
    local size max prefix

    [ -f "$file" ] && [ ! -L "$file" ] && [ -s "$file" ] || return 1
    size="$(download_policy_file_size "$file")" || return 1
    max="$(download_policy_max_bytes "$url")"
    case "$size" in ''|*[!0-9]*) return 1 ;; esac
    [ "$size" -le "$max" ] || return 1
    if LC_ALL=C head -c 512 "$file" 2>/dev/null | grep -Eiq '<(!doctype[[:space:]]+html|html[[:space:]>])|access[[:space:]]+denied|error[[:space:]]+403'; then
        return 1
    fi
    prefix="$(LC_ALL=C od -An -tx1 -N4 "$file" 2>/dev/null | tr -d ' \n')"
    case "${url%%\?*}" in
        *.zip) case "$prefix" in 504b0304|504b0506|504b0708) ;; *) return 1 ;; esac ;;
        *.tar.gz) [ "${prefix#1f8b}" != "$prefix" ] || return 1 ;;
        *.deb) [ "$prefix" = "213c6172" ] || return 1 ;;
        *.AppImage) [ "$prefix" = "7f454c46" ] || return 1 ;;
        *.exe) [ "${prefix#4d5a}" != "$prefix" ] || return 1 ;;
        *.msi) case "$prefix" in d0cf11e0|4d5a*) ;; *) return 1 ;; esac ;;
    esac
}
