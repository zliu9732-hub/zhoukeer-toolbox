#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/steam_accelerator.sh"

load_config

# Decky 的认证接口固定为本机回环地址，不能从配置或环境覆盖。
DECKY_API_BASE="http://127.0.0.1:1337"
DECKY_LOADER_URL="${DECKY_LOADER_URL:-https://www.mhhf.com/Deck/decky/v.3.2.6/PluginLoader}"
DECKY_LOADER_SHA256="${DECKY_LOADER_SHA256:-30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e}"
DECKY_SERVICE_URL="${DECKY_SERVICE_URL:-https://www.mhhf.com/Deck/decky/plugin_loader-release.service}"
DECKY_SERVICE_SHA256="${DECKY_SERVICE_SHA256:-64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1}"
# 国内镜像不可用时，只回退到 Decky 官方固定版本文件；两条线路共用同一组 SHA256。
DECKY_LOADER_OFFICIAL_URL="https://github.com/SteamDeckHomebrew/decky-loader/releases/download/v3.2.6/PluginLoader"
DECKY_SERVICE_OFFICIAL_URL="https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.6/dist/plugin_loader-release.service"
DECKY_STABLE_VERSION="v3.2.6"
# 测试版优先使用 Gitee 国内镜像，失败后回退 Decky 官方 prerelease，并通过统一 GitHub 下载链路选择传输源。
DECKY_PRERELEASE_VERSION="v3.2.8-pre1"
DECKY_PRERELEASE_LOADER_URL="https://github.com/SteamDeckHomebrew/decky-loader/releases/download/v3.2.8-pre1/PluginLoader"
DECKY_PRERELEASE_LOADER_SHA256="9df160a81df3fc49c96e5665a1d1b3ba5c79de5bf271adc266d6bfedfda399d8"
DECKY_PRERELEASE_SERVICE_URL="https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.8-pre1/dist/plugin_loader-prerelease.service"
DECKY_PRERELEASE_SERVICE_SHA256="f6fd73f68dca18a64e4cffa2962ae697b247aaf5f3fd9cd8526597f0291fb63e"
# Decky 安装文件镜像托管在本仓库 decky-installer-cn 目录；latest.txt 由发布时同步更新。
DECKY_GITEE_MIRROR_BASE="https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn"
DECKY_GITEE_MIRROR_META="$DECKY_GITEE_MIRROR_BASE/latest.txt"
DECKY_HOMEBREW_DIR="${ZHOUKEER_DECKY_HOMEBREW_DIR:-$HOME/homebrew}"
DECKY_UNIT_PATH="${ZHOUKEER_DECKY_UNIT_PATH:-/etc/systemd/system/plugin_loader.service}"
DECKY_USER_UNIT_PATH="$HOME/.config/systemd/user/plugin_loader.service"
DECKY_SERVICE_NAME="plugin_loader.service"
DECKY_TMP_DIR=""
PLUGIN_INSTALL_CHANGED=0
LSFG_OFFICIAL_DIRECTORY="Decky LSFG-VK"
LSFG_OFFICIAL_VERSION="0.12.8"
LSFG_RUNTIME_ARCHIVE="lsfg-vk_noui.zip"
LSFG_MAKO_DIRECTORY="Mako"
LSFG_MAKO_ZH_JSON="$PROJECT_ROOT/data/mako_zh.json"
LSFG_MAKO_ZH_EN_JSON="$PROJECT_ROOT/data/mako_zh_en.json"
DECKY_LSFG_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
DECKY_MAKO_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
LSFG_ZH_MIRROR_ID="lsfg-zh-signed"
LSFG_ZH_PACKAGE_SHA256="7f846c28bf5f9d08f6589a618c4e0c4ee4dffb05ad15938c39359c6460f1157b"
LSFG_ZH_INDEX_SHA256="49d475932c6508a2c58113f605857ba9d26b92646ae49f31804e8f1a913d7d1b"
FSR4_OFFICIAL_DIRECTORY="Decky-Framegen"
FSR4_OFFICIAL_VERSION="0.17"
FSR4_ZH_MIRROR_ID="fsr4-zh-signed"
FSR4_ZH_PACKAGE_SHA256="409aa32b843500a6828b73feeed5cc7307d9c7c60a470e288f2c8cf777d03adb"
FSR4_ZH_INDEX_SHA256="961d4571a5068f8410885617f3fdf1016ea7b1284a9c9cc6311dc1251de21515"
FSR4_RUNTIME_ARCHIVE="Optiscaler_0.9.4-final.20260718._MM.7z"
FSR4_RUNTIME_UPSCALER="amd_fidelityfx_upscaler_dx12.dll"
FSR4_RUNTIME_PATCHER="OptiPatcher_rolling.asi"
SIMPLEDECKYTDP_OFFICIAL_DIRECTORY="SimpleDeckyTDP"
SIMPLEDECKYTDP_OFFICIAL_VERSION="1.0.5"
SIMPLEDECKYTDP_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/decky-simpledeckytdp-zh-v1.0.5"
SIMPLEDECKYTDP_ZH_INDEX_SHA256="22dccfb29db66eeca399246eba07942ad0ca7b9d89334801def256c76d4d2a38"
STEAMGRIDDB_OFFICIAL_DIRECTORY="decky-steamgriddb"
STEAMGRIDDB_OFFICIAL_VERSION="1.7.1"
CSSLOADER_OFFICIAL_DIRECTORY="SDH-CssLoader"
CSSLOADER_OFFICIAL_VERSION="2.1.2"
CSSLOADER_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/cssloader-zh-v2.1.2"
CSSLOADER_ZH_INDEX_SHA256="38ec628efcc1238247e0cf771bde98b26be49349dca9c2d7de4270ad242a2567"

# 独立插件固定使用作者 GitHub Release，避免被用户旧配置改回过期镜像。
DECKY_LSFG_URL="https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.8/Decky.LSFG-VK.zip"
DECKY_LSFG_SHA256="322f6eec21a489ef9f12938ea2ec4e43c234093876f95b7245fbd260f882ce9c"
DECKY_LSFG_MAKO_URL="https://github.com/eugeniosegala/MAKO/releases/download/plugin-v2.0.0/MAKO-Decky-v2.0.0.zip"
DECKY_LSFG_MAKO_SHA256="5a801dab4d0171a8b50fcb032479aedc644efebe684c4dd984e86fd5e7fec3f1"
DECKY_FSR4_URL="https://github.com/xXJSONDeruloXx/Decky-Framegen/releases/download/v0.17/Decky-Framegen.zip"
DECKY_FSR4_SHA256="3300b617e3d979b483d03f995c75c829d6d54beaa4ac8dfae300c2560e4fc60f"
DECKY_CHEATDECK_URL="https://github.com/SheffeyG/CheatDeck/releases/download/v2.0.0/CheatDeck.zip"
DECKY_CHEATDECK_SHA256="32e2931f9ca8083c1605f04b4ed089b0bf210f79db236a7fd34f02c519e902d9"
DECKY_CHEATDECK_VERSION="2.0.0"
DECKY_STEAMGRIDDB_URL="https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3.zip"
DECKY_STEAMGRIDDB_SHA256="6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3"
DECKY_CSSLOADER_URL="https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350.zip"
DECKY_CSSLOADER_SHA256="1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350"
DECKY_FRIENDECK_URL="https://github.com/panyiwei-home/Friendeck/releases/download/0.7.7/Friendeck.v.0.7.7.zip"
DECKY_FRIENDECK_SHA256="65465ff115e105912adf72b5461e17b697ac07100ce7061de2e962851e41c653"
DECKY_FRIENDECK_RELEASE_VERSION="0.7.7"
DECKY_FRIENDECK_PACKAGE_VERSION="0.7.5"
DECKY_DECKYMUSIC_URL="https://github.com/jinzhongjia/decky-music/releases/download/v1.0.0/Decky.Music.zip"
DECKY_DECKYMUSIC_SHA256="ec2956bbee1d84b25b7f8749f06794b54014828a04707beccd06feb5d49dfa53"
DECKY_DECKYMUSIC_VERSION="1.0.0"
DECKY_TOMOON_URL="https://github.com/YukiCoco/ToMoon/releases/download/v0.2.8/tomoon-v0.2.8.zip"
DECKY_TOMOON_SHA256="5500e6ed2d110b0e077b9eba3f1908eb50593483e51158b9351978d9a03191a6"
DECKY_DECKRECALL_URL="https://github.com/Ren-Amamiya-pixle/DeckRecall/releases/download/v0.4.2/DeckRecall.zip"
DECKY_DECKRECALL_SHA256="38cbbaa94f39bbe7231f490fd3826f1347ce8c0acb53aa69c784d8511cc058fd"
DECKY_DECKRECALL_VERSION="0.4.2"
DECKY_DECKRECALL_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
DECKY_DECKRECALL_AUTO_UPDATE="${ZHOUKEER_DECKY_DECKRECALL_AUTO_UPDATE:-1}"
DECKY_SAVEPULSE_URL="${DECKY_SAVEPULSE_URL:-https://github.com/Ren-Amamiya-pixle/SavePulse/releases/download/v0.2.0-alpha.1/SavePulse.zip}"
DECKY_SAVEPULSE_SHA256="${DECKY_SAVEPULSE_SHA256:-e0680fc3995b8bbb2971673db43d5e9459d8fa8e4a1b431a1f5d4edad19a35ad}"
DECKY_SAVEPULSE_VERSION="${DECKY_SAVEPULSE_VERSION:-0.2.0-alpha.1}"
DECKY_LATEST_GITHUB_VERSION=""
DECKY_LATEST_GITHUB_URL=""
DECKY_LATEST_GITHUB_SHA256=""
# Unifideck 固定使用作者最新正式 Release，避免用户旧配置继续下载更大的 0.7.0 包。
DECKY_UNIFIDECK_URL="https://github.com/mubaraknumann/unifideck/releases/download/Release-0.7.2/unifideck.prod.v0.7.2.zip"
DECKY_UNIFIDECK_VERSION="0.7.2"
DECKY_UNIFIDECK_SHA256="a313be924cabe15255d222742a402cd98cb510a35dfe4b2d06cf1e59366936de"
# Freedeck 固定使用作者 GitHub Release 0.6 插件包，避免源码包或旧配置装成 0.2。
DECKY_FREEDECK_URL="https://github.com/panyiwei-home/Freedeck/releases/download/0.6/freedeck.v.0.6.zip"
DECKY_FREEDECK_SHA256="04329d07761c42cc481e97ddd4fc180fa51eb1d0388761424a8c90a18a822c62"
DECKY_FREEDECK_VERSION="0.6"
# NewFreedeck 是作者独立重构版，与 Freedeck 0.6 使用不同插件目录。
DECKY_NEWFREEDECK_URL="https://github.com/panyiwei-home/Freedeck/releases/download/New-0.1/NewFreedeck.v.0.1.zip"
DECKY_NEWFREEDECK_SHA256="60c9832a5808941d0940caef7fecfe6058532d6cdc52e0002463a5a512be0823"
DECKY_NEWFREEDECK_VERSION="0.1"
DECKY_NEWFREEDECK_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
# Ally Center 固定使用作者 v1.2.0 正式版；国内镜像与 NewFreedeck 共用 mirror-3。
DECKY_ALLYCENTER_URL="${ZHOUKEER_DECKY_ALLYCENTER_URL:-https://github.com/PixelAddictUnlocked/allycenter/releases/download/v1.2.0/allycenter-v1.2.0.zip}"
DECKY_ALLYCENTER_SHA256="${ZHOUKEER_DECKY_ALLYCENTER_SHA256:-a1059534de2a0e9556669adff3d933bcde802101faae7558f9b33db3a8e51bc7}"
DECKY_ALLYCENTER_VERSION="1.2.0"
DECKY_ALLYCENTER_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
ALLYCENTER_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/allycenter-zh-v1.2.0"
ALLYCENTER_ZH_INDEX_SHA256="72bb93d1f1a2a02fbbf670661d7f76f324d8f7d2077d3e763559f03332332031"
DECKY_HUESYNC_URL="${ZHOUKEER_DECKY_HUESYNC_URL:-https://github.com/honjow/HueSync/releases/download/v3.9.0/huesync.zip}"
DECKY_HUESYNC_SHA256="${ZHOUKEER_DECKY_HUESYNC_SHA256:-7510c96ed22278a914a3aae591c2393ff4e25812a765d1d633f77baa8a593e1f}"
DECKY_HUESYNC_VERSION="3.9.0"
DECKY_HUESYNC_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
HUESYNC_CN_SOURCE_DIR="$PROJECT_ROOT/third_party/huesync-cn-v3.9.0"
HUESYNC_CN_INDEX_SHA256="8af434b51c39f054b94ff71a39798569dc58b0fff36c74a5282edcb89e7bd0c5"
DECKY_LEGIONGO_REMAPPER_URL="${ZHOUKEER_DECKY_LEGIONGO_REMAPPER_URL:-https://github.com/aarron-lee/LegionGoRemapper/releases/download/v0.3.0/LegionGoRemapper.tar.gz}"
DECKY_LEGIONGO_REMAPPER_SHA256="${ZHOUKEER_DECKY_LEGIONGO_REMAPPER_SHA256:-b89084ece2df8854a732239043484f510a2384d01221441e3a4242fc85b6d9e1}"
DECKY_LEGIONGO_REMAPPER_VERSION="0.3.0"
LEGIONGO_REMAPPER_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/legion-go-remapper-zh-v0.3.0"
LEGIONGO_REMAPPER_ZH_INDEX_SHA256="8cc9faf4d5022be3e6584343dbc8cc9a70ce2d50fb7869efffd9ca96a24b40c6"
DECKY_GPD_CONTROL_URL="${ZHOUKEER_DECKY_GPD_CONTROL_URL:-https://github.com/aarron-lee/GpdControl/releases/download/v0.0.2/GpdControl.tar.gz}"
DECKY_GPD_CONTROL_SHA256="${ZHOUKEER_DECKY_GPD_CONTROL_SHA256:-3efc5694234fb7f2ae1131fd9dec9e342c1fee7c4a804e4f910920d327ae7fb4}"
DECKY_GPD_CONTROL_VERSION="0.0.2"
GPD_CONTROL_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/gpd-control-zh-v0.0.2"
GPD_CONTROL_ZH_INDEX_SHA256="3de06452b88959ab1cf828acfccaabf1f2c402de85ec0fcedcaa1385e2f3d505"
DECKY_LEGO_VIBE_URL="${ZHOUKEER_DECKY_LEGO_VIBE_URL:-https://github.com/Rayekkk/LeGo-Vibe-Control/releases/download/1.5.0/LeGo-Vibe-Control-1.5.0.zip}"
DECKY_LEGO_VIBE_SHA256="${ZHOUKEER_DECKY_LEGO_VIBE_SHA256:-adda3be351c14d1c8899fb0997565aa67e7439b988112340fad707cfe6be28b7}"
DECKY_LEGO_VIBE_VERSION="1.5.0"
LEGO_VIBE_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/lego-vibe-control-zh-v1.5.0"
LEGO_VIBE_ZH_INDEX_SHA256="e8c285a05f975bbf7cede8e43f48bbb49854c37e60b173e4045df84e01b9c49e"
DECKY_LEGO2_FAN_URL="${ZHOUKEER_DECKY_LEGO2_FAN_URL:-https://github.com/Rodpad/LeGo2-Fan-Control/releases/download/Decky/LeGo2FanControl_Decky.zip}"
DECKY_LEGO2_FAN_SHA256="${ZHOUKEER_DECKY_LEGO2_FAN_SHA256:-a46af0c53eef63b1ad77fff567a120784b6736686565a761524882d011cc6d3e}"
DECKY_LEGO2_FAN_VERSION="0.260430"
LEGO2_FAN_ZH_SOURCE_DIR="$PROJECT_ROOT/third_party/lego2-fan-control-zh-v0.260430"
LEGO2_FAN_ZH_INDEX_SHA256="9d93837925ccb2e95bf94942b291664f1cf645362d0f6b9972a03face0bb22d4"
# OneXPlayer Apex Tools 只适用于 Apex（Strix Halo）；上游包会操作 HHD、睡眠和内核模块。
DECKY_ONEXPLAYER_APEX_URL="https://github.com/srsholmes/onexplayer-apex-bazzite-fixes/releases/download/build-b696161/OneXPlayer_Apex_Tools.zip"
DECKY_ONEXPLAYER_APEX_SHA256="7c522bc8145697d78d6165f7f97671d4d67a5bf4f9e4ed5e6feccbb1154acb91"
DECKY_ONEXPLAYER_APEX_VERSION="build-b696161"
DECKY_ONEXPLAYER_APEX_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
DECKY_HANDHELD_PLUGIN_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
DECKY_GAME_INFO_MIRROR_REPO="zhoukeer-toolbox-mirror-3"
STEAMDB_INFO_DIRECTORY="SteamDBButton"
STEAMDB_INFO_VERSION="0.0.1"
STEAMDB_INFO_MIRROR_ID="steamdb-game-info-zh"
STEAMDB_INFO_PACKAGE_SHA256="cb072edfbed3e30abec76fc25ce74653380594feecba81e61284d72563b082bf"
STEAMDB_INFO_INDEX_SHA256="871586c9867bcc621b38618c52de884202eb72a66828ff447e0891327ae2b607"
STEAMDB_INFO_BACKEND_SHA256="9abcb7350ea051c8caa3d6a5d01632b6a3fb2165a0467f1fe0ee2b1cf8cb0f57"
DECKY_TRANSLATOR_DIRECTORY="decky-translator"
DECKY_TRANSLATOR_VERSION="0.8.0"
DECKY_TRANSLATOR_MIRROR_ID="decky-translator-zh"
DECKY_TRANSLATOR_PACKAGE_SHA256="a9e63de07bf01dcf27f8292cd5bb2b6488d08205d94ae323730a070f4b3002cd"
DECKY_TRANSLATOR_INDEX_SHA256="765a4d4d3f5d68053419123cbd8b4e0305639a3bf052af66274b57236a018669"
DECKY_TRANSLATOR_BACKEND_SHA256="f3a50b71fb6e35c5cb265a209a09cd07906389cd5e28802b118be566b86536db"
DECKY_TRANSLATOR_DEPENDENCIES_SHA256="3112dc9541e84d958670755a0a7f47d5a933368e4d48acebac3793834354fdd2"
# 小黄鸭与 FSR4 的署名完整包只允许从 mirror-3 分块镜像下载。
# 不配置 GitHub 回退地址，避免工具箱与其他账号仓库形成下载关联。
# Gitee 归档必须指向包含当前 dist 汉化包的稳定标签，避免旧归档校验失败。
DECKY_GITEE_ARCHIVE_URL="https://gitee.com/zliu9732-hub/zhoukeer-toolbox/repository/archive/v6.0.4.zip"
DECKY_GITEE_ARCHIVE_SHA256="cbe50c9dcd64bba1433713c1945ec73de2fa1cc51f8a8327ef0f9cdd0ace147a"
DECKY_GITEE_ARCHIVE_PREFIX="zhoukeer-toolbox-v6.0.4"

show_plugin_download_speed_tip() {
    # 不再显示多余说明；下载失败时会自动启用加速并重试。
    return 0
}

resolve_deckrecall_latest() {
    if [ "${DECKY_DECKRECALL_AUTO_UPDATE:-1}" != "1" ] || \
        [ -n "${ZHOUKEER_DECKY_DECKRECALL_URL:-}" ] || \
        [ -n "${ZHOUKEER_DECKY_DECKRECALL_SHA256:-}" ]; then
        return 0
    fi

    if resolve_latest_github_release "Ren-Amamiya-pixle/DeckRecall" \
        '^DeckRecall[.]zip$' "DeckRecall"; then
        DECKY_DECKRECALL_URL="$_LATEST_RELEASE_URL"
        DECKY_DECKRECALL_SHA256="$_LATEST_RELEASE_SHA256"
        DECKY_DECKRECALL_VERSION="${_LATEST_RELEASE_TAG#v}"
        log "DeckRecall 自动检测最新版本: $_LATEST_RELEASE_TAG"
    else
        echo "自动检测最新 DeckRecall 失败，继续使用固定版本。"
    fi
}

deckrecall_version_is_older() {
    local installed="$1"
    local latest="$2"
    local installed_major installed_minor installed_patch
    local latest_major latest_minor latest_patch

    [[ "$installed" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    [[ "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    IFS=. read -r installed_major installed_minor installed_patch <<< "$installed"
    IFS=. read -r latest_major latest_minor latest_patch <<< "$latest"
    [ "$installed_major" -lt "$latest_major" ] || \
        { [ "$installed_major" -eq "$latest_major" ] && [ "$installed_minor" -lt "$latest_minor" ]; } || \
        { [ "$installed_major" -eq "$latest_major" ] && [ "$installed_minor" -eq "$latest_minor" ] && [ "$installed_patch" -lt "$latest_patch" ]; }
}

resolve_plugin_latest() {
    local action="$1"

    case "$action" in
        lsfg)
            [ -z "${ZHOUKEER_DECKY_LSFG_URL:-}" ] || return 0
            if resolve_latest_github_release "xXJSONDeruloXx/decky-lsfg-vk" \
                '^Decky[.]LSFG-VK[.]zip$' "Decky LSFG-VK"; then
                DECKY_LSFG_URL="$_LATEST_RELEASE_URL"
                DECKY_LSFG_SHA256="$_LATEST_RELEASE_SHA256"
            fi
            ;;
        lsfg-mako)
            [ -n "$DECKY_LSFG_MAKO_URL" ] && [ -n "$DECKY_LSFG_MAKO_SHA256" ] && return 0
            if resolve_latest_github_release "eugeniosegala/MAKO" \
                '^MAKO-Decky-v[0-9.]+[.]zip$' "MAKO 小黄鸭"; then
                DECKY_LSFG_MAKO_URL="$_LATEST_RELEASE_URL"
                DECKY_LSFG_MAKO_SHA256="$_LATEST_RELEASE_SHA256"
            fi
            ;;
        fsr4)
            [ -z "${ZHOUKEER_DECKY_FSR4_URL:-}" ] || return 0
            if resolve_latest_github_release "xXJSONDeruloXx/Decky-Framegen" \
                '^Decky-Framegen[.]zip$' "Decky-Framegen"; then
                DECKY_FSR4_URL="$_LATEST_RELEASE_URL"
                DECKY_FSR4_SHA256="$_LATEST_RELEASE_SHA256"
            fi
            ;;
        cheatdeck)
            [ -z "${ZHOUKEER_DECKY_CHEATDECK_URL:-}" ] || return 0
            if resolve_latest_github_release "SheffeyG/CheatDeck" \
                '^CheatDeck[.]zip$' "CheatDeck"; then
                DECKY_CHEATDECK_URL="$_LATEST_RELEASE_URL"
                DECKY_CHEATDECK_SHA256="$_LATEST_RELEASE_SHA256"
                DECKY_CHEATDECK_VERSION="${_LATEST_RELEASE_TAG#v}"
            fi
            ;;
        steamgriddb)
            ensure_official_plugin_current \
                "游戏封面更换（SteamGridDB）" \
                "$STEAMGRIDDB_OFFICIAL_DIRECTORY" "$STEAMGRIDDB_OFFICIAL_VERSION" \
                "SteamGridDB" "游戏封面更换" \
                "$DECKY_STEAMGRIDDB_URL" "$DECKY_STEAMGRIDDB_SHA256"
            ;;
        cssloader)
            ensure_cssloader_chinese_current
            ;;
        friendeck)
            ensure_official_plugin_current \
                "文件传输助手（Friendeck $DECKY_FRIENDECK_RELEASE_VERSION）" \
                "Friendeck-plugin" "$DECKY_FRIENDECK_PACKAGE_VERSION" \
                "Friendeck" "文件传输助手" \
                "$DECKY_FRIENDECK_URL" "$DECKY_FRIENDECK_SHA256"
            ;;
        deckymusic)
            ensure_official_plugin_current \
                "音乐播放器（Decky Music）" \
                "Decky Music" "$DECKY_DECKYMUSIC_VERSION" \
                "Decky Music" "音乐播放器" \
                "$DECKY_DECKYMUSIC_URL" "$DECKY_DECKYMUSIC_SHA256"
            ;;
        tomoon)
            [ -z "${ZHOUKEER_DECKY_TOMOON_URL:-}" ] || return 0
            if resolve_latest_github_release "YukiCoco/ToMoon" \
                '^tomoon-v[0-9.]+[.]zip$' "ToMoon"; then
                DECKY_TOMOON_URL="$_LATEST_RELEASE_URL"
                DECKY_TOMOON_SHA256="$_LATEST_RELEASE_SHA256"
            fi
            ;;
        deckrecall)
            resolve_deckrecall_latest
            ;;
        unifideck)
            [ -z "${ZHOUKEER_DECKY_UNIFIDECK_URL:-}" ] || return 0
            if resolve_latest_github_release "mubaraknumann/unifideck" \
                '^unifideck[.]prod[.]v[0-9.]+[.]zip$' "Unifideck"; then
                DECKY_UNIFIDECK_URL="$_LATEST_RELEASE_URL"
                DECKY_UNIFIDECK_SHA256="$_LATEST_RELEASE_SHA256"
                DECKY_UNIFIDECK_VERSION="$_LATEST_RELEASE_TAG"
            fi
            ;;
        freedeck)
            [ -z "${ZHOUKEER_DECKY_FREEDECK_URL:-}" ] || return 0
            if resolve_latest_github_release "panyiwei-home/Freedeck" \
                '^freedeck[.]v[0-9.]+[.]zip$' "Freedeck" >/dev/null 2>&1; then
                DECKY_FREEDECK_URL="$_LATEST_RELEASE_URL"
                DECKY_FREEDECK_SHA256="$_LATEST_RELEASE_SHA256"
                DECKY_FREEDECK_VERSION="$_LATEST_RELEASE_TAG"
            fi
            ;;
        simpledeckytdp)
            [ -z "${ZHOUKEER_DECKY_SIMPLE_TDP_URL:-}" ] || return 0
            if resolve_latest_github_release "aarron-lee/SimpleDeckyTDP" \
                '^SimpleDeckyTDP[.]zip$' "SimpleDeckyTDP"; then
                DECKY_SIMPLE_TDP_URL="$_LATEST_RELEASE_URL"
                DECKY_SIMPLE_TDP_SHA256="$_LATEST_RELEASE_SHA256"
                DECKY_SIMPLE_TDP_VERSION="$_LATEST_RELEASE_TAG"
            fi
            ;;
        huesync)
            [ -z "${ZHOUKEER_DECKY_HUESYNC_URL:-}" ] || return 0
            if resolve_latest_github_release "honjow/HueSync" \
                '^huesync[.]zip$' "HueSync"; then
                DECKY_HUESYNC_URL="$_LATEST_RELEASE_URL"
                DECKY_HUESYNC_SHA256="$_LATEST_RELEASE_SHA256"
                DECKY_HUESYNC_VERSION="${_LATEST_RELEASE_TAG#v}"
            fi
            ;;
    esac
}

resolve_decky_latest() {
    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ]; then
        return 1
    fi
    if [ -n "$DECKY_LATEST_GITHUB_VERSION" ]; then
        return 0
    fi
    if resolve_latest_github_release "SteamDeckHomebrew/decky-loader" \
        '^PluginLoader$' "Decky Loader"; then
        DECKY_LATEST_GITHUB_VERSION="$_LATEST_RELEASE_TAG"
        DECKY_LATEST_GITHUB_URL="$_LATEST_RELEASE_URL"
        DECKY_LATEST_GITHUB_SHA256="$_LATEST_RELEASE_SHA256"
        log "Decky Loader 自动检测最新版本: $_LATEST_RELEASE_TAG"
    fi
}

resolve_decky_prerelease_latest() {
    local api_url temp_file latest_json

    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ]; then
        return 1
    fi
    if [ -n "$DECKY_LATEST_GITHUB_VERSION" ]; then
        return 0
    fi
    command -v jq >/dev/null 2>&1 || return 1
    api_url="https://api.github.com/repos/SteamDeckHomebrew/decky-loader/releases?per_page=20"
    download_policy_url_allowed "$api_url" || return 1
    temp_file="$(mktemp 2>/dev/null)" || return 1
    if ! curl --fail --location --silent --proto '=https' --proto-redir '=https' \
        --connect-timeout 10 --max-time 30 --retry 2 --retry-all-errors \
        --max-filesize 2097152 --output "$temp_file" "$api_url"; then
        rm -f -- "$temp_file"
        return 1
    fi
    latest_json="$(jq -r '
        [.[] | select(.prerelease == true) |
         .assets[]? | select(.name == "PluginLoader") |
         {tag: .tag_name, url: .browser_download_url,
          sha: (.digest // "" | sub("^sha256:"; ""))}] |
        map(select(.sha | test("^[0-9a-fA-F]{64}$"))) |
        .[0] | "\(.tag)\t\(.url)\t\(.sha)"
    ' "$temp_file")" || {
        rm -f -- "$temp_file"
        return 1
    }
    rm -f -- "$temp_file"
    [ -n "$latest_json" ] || return 1
    IFS=$'\t' read -r DECKY_LATEST_GITHUB_VERSION \
        DECKY_LATEST_GITHUB_URL DECKY_LATEST_GITHUB_SHA256 <<< "$latest_json"
    log "Decky Loader 自动检测测试版: $DECKY_LATEST_GITHUB_VERSION"
}

cleanup_decky_tmp() {
    if [ -n "$DECKY_TMP_DIR" ] && [ -d "$DECKY_TMP_DIR" ]; then
        rm -rf -- "$DECKY_TMP_DIR"
    fi
    DECKY_TMP_DIR=""
}

calculate_decky_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

validate_decky_gitee_part_hashes() {
    local parts="$1"
    local list="$2"
    local part_entries=()
    local entry

    case "$parts" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$parts" -ge 1 ] 2>/dev/null || return 1
    IFS=',' read -r -a part_entries <<< "$list"
    [ "${#part_entries[@]}" -eq "$parts" ] || return 1
    for entry in "${part_entries[@]}"; do
        case "$entry" in
            [0-9a-fA-F]*) ;;
            *) return 1 ;;
        esac
        [ "${#entry}" -eq 64 ] || return 1
    done
    return 0
}

load_decky_gitee_mirror_meta() {
    local meta_file="$1"
    local key value

    DECKY_GITEE_STABLE_VERSION=""
    DECKY_GITEE_STABLE_PARTS=""
    DECKY_GITEE_STABLE_SHA256=""
    DECKY_GITEE_STABLE_PART_SHA256=""
    DECKY_GITEE_STABLE_SERVICE_SHA256=""
    DECKY_GITEE_PRERELEASE_VERSION=""
    DECKY_GITEE_PRERELEASE_PARTS=""
    DECKY_GITEE_PRERELEASE_SHA256=""
    DECKY_GITEE_PRERELEASE_PART_SHA256=""
    DECKY_GITEE_PRERELEASE_SERVICE_SHA256=""

    if ! download_github_file "$DECKY_GITEE_MIRROR_META" "$meta_file" "" "Decky 镜像元数据"; then
        log "Decky Gitee镜像元数据获取失败，改用既有线路。"
        return 1
    fi
    while IFS='=' read -r key value; do
        case "$key" in
            stable_version) DECKY_GITEE_STABLE_VERSION="$value" ;;
            stable_parts) DECKY_GITEE_STABLE_PARTS="$value" ;;
            stable_sha256) DECKY_GITEE_STABLE_SHA256="$value" ;;
            stable_part_sha256) DECKY_GITEE_STABLE_PART_SHA256="$value" ;;
            stable_service_sha256) DECKY_GITEE_STABLE_SERVICE_SHA256="$value" ;;
            prerelease_version) DECKY_GITEE_PRERELEASE_VERSION="$value" ;;
            prerelease_parts) DECKY_GITEE_PRERELEASE_PARTS="$value" ;;
            prerelease_sha256) DECKY_GITEE_PRERELEASE_SHA256="$value" ;;
            prerelease_part_sha256) DECKY_GITEE_PRERELEASE_PART_SHA256="$value" ;;
            prerelease_service_sha256) DECKY_GITEE_PRERELEASE_SERVICE_SHA256="$value" ;;
        esac
    done < "$meta_file"

    case "$DECKY_GITEE_STABLE_VERSION" in ''|*[!-0-9A-Za-z._]*) return 1 ;; esac
    case "$DECKY_GITEE_PRERELEASE_VERSION" in ''|*[!-0-9A-Za-z._]*) return 1 ;; esac
    case "$DECKY_GITEE_STABLE_PARTS" in ''|*[!0-9]*) return 1 ;; esac
    case "$DECKY_GITEE_PRERELEASE_PARTS" in ''|*[!0-9]*) return 1 ;; esac
    [ "$DECKY_GITEE_STABLE_PARTS" -ge 1 ] 2>/dev/null || return 1
    [ "$DECKY_GITEE_PRERELEASE_PARTS" -ge 1 ] 2>/dev/null || return 1
    for value in \
        "$DECKY_GITEE_STABLE_SHA256" \
        "$DECKY_GITEE_STABLE_SERVICE_SHA256" \
        "$DECKY_GITEE_PRERELEASE_SHA256" \
        "$DECKY_GITEE_PRERELEASE_SERVICE_SHA256"; do
        case "$value" in
            [0-9a-fA-F]*) ;;
            *) return 1 ;;
        esac
        [ "${#value}" -eq 64 ] || return 1
    done
    validate_decky_gitee_part_hashes \
        "$DECKY_GITEE_STABLE_PARTS" "$DECKY_GITEE_STABLE_PART_SHA256" || return 1
    validate_decky_gitee_part_hashes \
        "$DECKY_GITEE_PRERELEASE_PARTS" "$DECKY_GITEE_PRERELEASE_PART_SHA256" || return 1
    return 0
}

download_decky_gitee_loader() {
    local channel="$1"
    local output="$2"
    local version parts expected_sha256 part_sha256 prefix
    local part_entries=()
    local i part_name part_file part_sha

    DECKY_LATEST_GITHUB_VERSION=""
    case "$channel" in
        stable)
            version="$DECKY_GITEE_STABLE_VERSION"
            parts="$DECKY_GITEE_STABLE_PARTS"
            expected_sha256="$DECKY_GITEE_STABLE_SHA256"
            part_sha256="$DECKY_GITEE_STABLE_PART_SHA256"
            prefix="PluginLoader"
            ;;
        prerelease)
            version="$DECKY_GITEE_PRERELEASE_VERSION"
            parts="$DECKY_GITEE_PRERELEASE_PARTS"
            expected_sha256="$DECKY_GITEE_PRERELEASE_SHA256"
            part_sha256="$DECKY_GITEE_PRERELEASE_PART_SHA256"
            prefix="PluginLoader-pre"
            ;;
        *) return 1 ;;
    esac
    if [ "$channel" = "stable" ]; then
        resolve_decky_latest
    else
        resolve_decky_prerelease_latest
    fi
    if [ -n "$DECKY_LATEST_GITHUB_VERSION" ] && \
        [ "$version" != "$DECKY_LATEST_GITHUB_VERSION" ]; then
        if download_github_file \
            "$DECKY_LATEST_GITHUB_URL" "$output" \
            "$DECKY_LATEST_GITHUB_SHA256" "Decky PluginLoader"; then
            DECKY_GITEE_SELECTED_VERSION="$DECKY_LATEST_GITHUB_VERSION"
            echo "Decky Loader 已自动检测最新版 $DECKY_LATEST_GITHUB_VERSION。"
            return 0
        fi
        echo "自动检测最新版下载失败，继续使用镜像版本 $version。"
    fi
    GITHUB_QUIET=1
    validate_decky_gitee_part_hashes "$parts" "$part_sha256" || return 1
    IFS=',' read -r -a part_entries <<< "$part_sha256"
    rm -f -- "$output"
    for ((i = 0; i < parts; i++)); do
        part_name="$(printf '%02d' "$i")"
        part_file="${output}.part.${i}"
        if ! download_github_file \
            "$DECKY_GITEE_MIRROR_BASE/${prefix}.part.${part_name}" \
            "$part_file" "${part_entries[$i]}" "Decky PluginLoader分块${part_name}" \
            >/dev/null 2>&1; then
            rm -f -- "$output"
            return 1
        fi
        if ! cat -- "$part_file" >> "$output"; then
            rm -f -- "$output" "$part_file"
            return 1
        fi
        rm -f -- "$part_file"
    done
    if [ "$(calculate_decky_sha256 "$output")" != "$expected_sha256" ]; then
        rm -f -- "$output"
        log "Decky Gitee镜像PluginLoader整体SHA256校验失败。"
        return 1
    fi
    DECKY_GITEE_SELECTED_VERSION="$version"
    return 0
}

download_decky_gitee_service() {
    local channel="$1"
    local output="$2"
    local service_file expected_sha256

    case "$channel" in
        stable)
            service_file="plugin_loader-release.service"
            expected_sha256="$DECKY_GITEE_STABLE_SERVICE_SHA256"
            ;;
        prerelease)
            service_file="plugin_loader-prerelease.service"
            expected_sha256="$DECKY_GITEE_PRERELEASE_SERVICE_SHA256"
            ;;
        *) return 1 ;;
    esac
    download_github_file \
        "$DECKY_GITEE_MIRROR_BASE/$service_file" \
        "$output" "$expected_sha256" "Decky systemd服务模板"
}

confirm_decky_install() {
    local channel="${1:-stable}"
    local answer

    echo "请先在游戏模式：Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，并重新进入桌面模式。"
    if [ "$channel" = "prerelease" ]; then
        echo "仅当 SteamOS 使用测试或预览通道、稳定版 Decky 不兼容时，才安装测试版插件商城。"
        echo "将从国内镜像安装测试版 ${DECKY_PRERELEASE_VERSION}，失败自动回退 Decky 官方 Release，已有插件和设置会保留。"
    else
        echo "将安装或更新 Decky Loader 稳定版（国内镜像优先），已有插件和设置会保留。"
    fi
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

detect_steamos_channel() {
    local os_release="${ZHOUKEER_OS_RELEASE_FILE:-/etc/os-release}"
    local key raw value tracked_branch=""

    # SteamOS 3.7+ 由 atomupd 记录当前跟踪分支；/etc/os-release 只描述已经
    # 安装的镜像，通常不会随用户在设置中选择测试/预览通道而改变。
    if command -v atomupd-manager >/dev/null 2>&1; then
        tracked_branch="$(atomupd-manager tracked-branch 2>/dev/null | head -n 1 || true)"
    fi
    # 较旧 SteamOS 仍使用 steamos-select-branch，保留只读查询兼容。
    if [ -z "$tracked_branch" ] && command -v steamos-select-branch >/dev/null 2>&1; then
        tracked_branch="$(steamos-select-branch -c 2>/dev/null | head -n 1 || true)"
    fi
    tracked_branch="${tracked_branch%$'\r'}"
    case "$tracked_branch" in
        rel|release|stable) printf '%s\n' stable; return 0 ;;
        beta|preview|main|staging) printf '%s\n' prerelease; return 0 ;;
    esac

    [ -r "$os_release" ] && [ ! -L "$os_release" ] || { printf '%s\n' stable; return 0; }
    while IFS='=' read -r key raw; do
        [ -n "$key" ] || continue
        value="${raw#\"}"
        value="${value%\"}"
        case "$value" in
            *[Pp]review*|*[Bb]eta*|*[Pp]re[.-]*) printf '%s\n' prerelease; return 0 ;;
        esac
    done < "$os_release"
    printf '%s\n' stable
}

install_plugin_store_auto() {
    local channel

    channel="$(detect_steamos_channel)"
    echo "检测到 SteamOS 系统通道：$channel"
    install_plugin_store "$channel"
}

prepare_decky_loader_channel_settings() {
    local input="$1"
    local output="$2"
    local branch="$3"

    case "$branch" in 0|1) ;; *) return 1 ;; esac
    [ -f "$input" ] && [ ! -L "$input" ] || return 1
    jq --argjson branch "$branch" \
        'if type == "object" then .branch = $branch else error("invalid loader settings") end' \
        "$input" > "$output" || {
        echo "Decky 分支配置无法安全读取，未修改：$input"
        return 1
    }
    jq -e --argjson branch "$branch" \
        'type == "object" and .branch == $branch' "$output" >/dev/null || return 1
    chmod 0600 "$output" || return 1
}

stop_legacy_decky_user_service() {
    DECKY_USER_OLD_ACTIVE=0
    DECKY_USER_OLD_ENABLED=0
    DECKY_USER_SERVICE_STOPPED=0

    if [ -e "$DECKY_USER_UNIT_PATH" ] && \
       [ ! -f "$DECKY_USER_UNIT_PATH" ] && [ ! -L "$DECKY_USER_UNIT_PATH" ]; then
        echo "旧版 Decky 用户服务路径类型异常，未继续：$DECKY_USER_UNIT_PATH"
        return 1
    fi
    systemctl --user is-active --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 && \
        DECKY_USER_OLD_ACTIVE=1
    systemctl --user is-enabled --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 && \
        DECKY_USER_OLD_ENABLED=1
    if [ "$DECKY_USER_OLD_ACTIVE" -eq 0 ] && \
       [ "$DECKY_USER_OLD_ENABLED" -eq 0 ]; then
        return 0
    fi

    echo "检测到旧版 Decky 用户服务，正在停用后切换到当前版本。"
    systemctl --user disable --now "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || {
        if systemctl --user is-active --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || \
           systemctl --user is-enabled --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1; then
            echo "旧版 Decky 用户服务无法停用，未替换现有文件。"
            return 1
        fi
    }
    DECKY_USER_SERVICE_STOPPED=1
}

remove_legacy_decky_user_unit() {
    if [ -e "$DECKY_USER_UNIT_PATH" ] || [ -L "$DECKY_USER_UNIT_PATH" ]; then
        toolbox_sudo rm -f -- "$DECKY_USER_UNIT_PATH" || return 1
    fi
    systemctl --user daemon-reload >/dev/null 2>&1 || return 1
}

write_flingtrainer_desktop_note() {
    local desktop_dir="${ZHOUKEER_DESKTOP_DIR:-$HOME/Desktop}"
    local note_file="$desktop_dir/风灵月影网址.txt"
    local temporary_file

    mkdir -p -- "$desktop_dir" || return 1
    temporary_file="$(mktemp "$desktop_dir/.flingtrainer-note.XXXXXX")" || return 1
    printf '%s\n' \
        'flingtrainer.com' \
        '' \
        '请将上方网址粘贴到浏览器，用英文搜索并下载对应游戏的最新修改器。' > "$temporary_file" || {
        rm -f -- "$temporary_file"
        return 1
    }
    chmod 0644 "$temporary_file" || {
        rm -f -- "$temporary_file"
        return 1
    }
    mv -f -- "$temporary_file" "$note_file" || {
        rm -f -- "$temporary_file"
        return 1
    }
    echo "已在桌面生成：风灵月影网址.txt"
}

print_cef_remote_debugging_tip() {
    echo "若返回游戏模式后没有看到 Decky 的插头图标：请按 Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，然后重新进入游戏模式。"
}

download_decky_component() {
    local name="$1"
    local url="$2"
    local expected_sha256="$3"
    local output="$4"
    local actual_sha256

    if [ -z "$url" ] || [ -z "$expected_sha256" ]; then
        echo "$name 的下载配置不完整，请先更新Renkit。"
        return 1
    fi
    download_policy_url_allowed "$url" || {
        echo "$name 的下载地址不在受控来源清单中，已停止。"
        return 1
    }

    local _dk_curl_options=(
        --fail
        --location
        --progress-meter
        --proto '=https'
        --proto-redir '=https'
        --connect-timeout 15
        --max-time 1200
        --retry 5
        --retry-connrefused
        --retry-delay 2
        --speed-limit 65536
        --speed-time 60
        --max-filesize "$(download_policy_max_bytes "$url")"
    )
    if [ -n "${DECKY_DOWNLOAD_PROXY:-}" ]; then
        _dk_curl_options+=(--proxy "$DECKY_DOWNLOAD_PROXY")
    fi
    if ! curl \
        "${_dk_curl_options[@]}" \
        --output "$output" \
        "$url" \
        2> >(download_progress_filter "$name" >&2); then
        rm -f -- "$output"
        log "$name 下载失败，未改动现有Decky安装。"
        return 1
    fi
    if ! download_policy_response_is_safe "$url" "$output"; then
        rm -f -- "$output"
        log "$name 下载响应格式或大小异常，已停止。"
        return 1
    fi

    actual_sha256="$(calculate_decky_sha256 "$output")" || {
        rm -f -- "$output"
        log "无法校验$name，已停止安装。"
        return 1
    }
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        rm -f -- "$output"
        log "Decky下载线路拒绝: $name SHA256变化"
        return 1
    fi
}

download_decky_component_with_fallback() {
    local name="$1"
    local domestic_url="$2"
    local official_url="$3"
    local expected_sha256="$4"
    local output="$5"

    if download_decky_component "$name" "$domestic_url" "$expected_sha256" "$output"; then
        echo "$name 下载完成。"
        log "Decky下载成功: $name source=domestic"
        return 0
    fi
    if [ "$domestic_url" = "$official_url" ]; then
        echo "$name 下载失败。"
        return 1
    fi

    log "Decky下载线路切换: $name domestic→official"
    if download_decky_component "$name" "$official_url" "$expected_sha256" "$output"; then
        echo "$name 下载完成。"
        log "Decky下载成功: $name source=official"
        return 0
    fi
    echo "$name 下载失败。"
    log "Decky下载失败: $name domestic+official"
    return 1
}

download_decky_prerelease_component() {
    local name="$1"
    local url="$2"
    local expected_sha256="$3"
    local output="$4"

    if ! download_github_file "$url" "$output" "$expected_sha256" "$name"; then
        echo "$name 下载失败，正在启用 Steam + GitHub 加速后重试..."
        ensure_steam302_for_download || true
        download_github_file "$url" "$output" "$expected_sha256" "$name"
    fi
}

render_decky_service() {
    local template="$1"
    local output="$2"
    local homebrew_dir="$3"
    local placeholder='${HOMEBREW_FOLDER}'
    local line

    case "$homebrew_dir" in
        /*) ;;
        *)
            echo "Decky安装目录必须是绝对路径。"
            return 1
            ;;
    esac
    case "$homebrew_dir" in
        *[!A-Za-z0-9_./-]*)
            echo "Decky安装目录包含systemd服务不支持的字符：$homebrew_dir"
            return 1
            ;;
    esac

    : > "$output" || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s\n' "${line//$placeholder/$homebrew_dir}" >> "$output" || return 1
    done < "$template"

    if grep -Fq "$placeholder" "$output" || \
        [ "$(grep -Fc "ExecStart=$homebrew_dir/services/PluginLoader" "$output")" -ne 1 ] || \
        [ "$(grep -Fc "WorkingDirectory=$homebrew_dir/services" "$output")" -ne 1 ] || \
        ! grep -Fxq 'User=root' "$output" || \
        ! grep -Fxq 'WantedBy=multi-user.target' "$output"; then
        echo "Decky服务模板内容不符合预期，已停止安装。"
        return 1
    fi
}

prepare_decky_homebrew_dirs() {
    local homebrew_dir="$1"
    local services_dir="$homebrew_dir/services"
    local plugins_dir="$homebrew_dir/plugins"

    if [ -L "$homebrew_dir" ] || [ -L "$services_dir" ]; then
        echo "Decky安装目录不能是符号链接，已停止安装。"
        return 1
    fi
    if { [ -e "$homebrew_dir" ] && [ ! -d "$homebrew_dir" ]; } || \
        { [ -e "$services_dir" ] && [ ! -d "$services_dir" ]; } || \
        { [ -e "$plugins_dir" ] && [ ! -d "$plugins_dir" ] && [ ! -L "$plugins_dir" ]; }; then
        echo "Decky安装路径被非目录文件占用，已停止安装。"
        return 1
    fi

    if ! mkdir -p -- "$services_dir"; then
        toolbox_sudo mkdir -p -- "$services_dir" || return 1
    fi
    if [ ! -e "$plugins_dir" ]; then
        if ! mkdir -p -- "$plugins_dir"; then
            toolbox_sudo install -d -m 0755 -o "$(id -u)" -g "$(id -g)" -- "$plugins_dir" || return 1
        fi
    fi

    if [ -w "$services_dir" ]; then
        DECKY_HOME_OP_SUDO=0
    else
        DECKY_HOME_OP_SUDO=1
    fi
}

run_decky_homebrew_operation() {
    if [ "${DECKY_HOME_OP_SUDO:-0}" -eq 1 ]; then
        toolbox_sudo "$@"
    else
        "$@"
    fi
}

rollback_decky_install() {
    if [ "${DECKY_SETTINGS_SWAP_STARTED:-0}" -eq 1 ]; then
        if [ "${DECKY_SETTINGS_HAD_OLD:-0}" -eq 1 ] && \
           run_decky_homebrew_operation test -f "$DECKY_SETTINGS_BACKUP"; then
            run_decky_homebrew_operation rm -f -- "$DECKY_SETTINGS_TARGET" || true
            run_decky_homebrew_operation mv -- \
                "$DECKY_SETTINGS_BACKUP" "$DECKY_SETTINGS_TARGET" || true
        else
            run_decky_homebrew_operation rm -f -- "$DECKY_SETTINGS_TARGET" || true
        fi
        run_decky_homebrew_operation rm -f -- "$DECKY_SETTINGS_NEW" || true
    fi

    if [ "${DECKY_VERSION_SWAP_STARTED:-0}" -eq 1 ]; then
        if [ "${DECKY_VERSION_HAD_OLD:-0}" -eq 1 ] && \
           run_decky_homebrew_operation test -f "$DECKY_VERSION_BACKUP"; then
            run_decky_homebrew_operation rm -f -- "$DECKY_VERSION_TARGET" || true
            run_decky_homebrew_operation mv -- \
                "$DECKY_VERSION_BACKUP" "$DECKY_VERSION_TARGET" || true
        else
            run_decky_homebrew_operation rm -f -- "$DECKY_VERSION_TARGET" || true
        fi
        run_decky_homebrew_operation rm -f -- "$DECKY_VERSION_NEW" || true
    fi

    if [ "${DECKY_UNIT_SWAP_STARTED:-0}" -eq 1 ]; then
        if [ "${DECKY_UNIT_HAD_OLD:-0}" -eq 1 ]; then
            if toolbox_sudo test -f "$DECKY_UNIT_BACKUP"; then
                toolbox_sudo rm -f -- "$DECKY_UNIT_PATH" || true
                toolbox_sudo mv -- "$DECKY_UNIT_BACKUP" "$DECKY_UNIT_PATH" || true
            fi
        else
            toolbox_sudo rm -f -- "$DECKY_UNIT_PATH" || true
        fi
        toolbox_sudo rm -f -- "$DECKY_UNIT_NEW" || true
    fi

    if [ "${DECKY_LOADER_SWAP_STARTED:-0}" -eq 1 ]; then
        if [ "${DECKY_LOADER_HAD_OLD:-0}" -eq 1 ]; then
            if run_decky_homebrew_operation test -f "$DECKY_LOADER_BACKUP"; then
                run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_TARGET" || true
                run_decky_homebrew_operation mv -- "$DECKY_LOADER_BACKUP" "$DECKY_LOADER_TARGET" || true
            fi
        else
            run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_TARGET" || true
        fi
        run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_NEW" || true
    fi

    if [ "${DECKY_UNIT_SWAP_STARTED:-0}" -eq 1 ]; then
        toolbox_sudo systemctl daemon-reload >/dev/null 2>&1 || true
        if [ "${DECKY_UNIT_HAD_OLD:-0}" -eq 1 ]; then
            if [ "${DECKY_OLD_ENABLED:-0}" -eq 1 ]; then
                toolbox_sudo systemctl enable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            else
                toolbox_sudo systemctl disable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            fi
            if [ "${DECKY_OLD_ACTIVE:-0}" -eq 1 ]; then
                toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            else
                toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            fi
        else
            toolbox_sudo systemctl disable --now "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
        fi
    fi

    if [ "${DECKY_UNIT_SWAP_STARTED:-0}" -eq 0 ] && \
       [ "${DECKY_SERVICE_STOPPED:-0}" -eq 1 ] && \
       [ "${DECKY_OLD_ACTIVE:-0}" -eq 1 ]; then
        toolbox_sudo systemctl start "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
    fi

    if [ "${DECKY_USER_SERVICE_STOPPED:-0}" -eq 1 ]; then
        if [ "${DECKY_USER_OLD_ENABLED:-0}" -eq 1 ]; then
            systemctl --user enable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
        fi
        if [ "${DECKY_USER_OLD_ACTIVE:-0}" -eq 1 ]; then
            systemctl --user start "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
        fi
    fi
}

finish_plugin_store_install() {
    local status="$1"

    trap - EXIT INT TERM
    if [ "${DECKY_INSTALL_COMMITTED:-0}" -ne 1 ]; then
        rollback_decky_install
    fi
    cleanup_decky_tmp
    exit "$status"
}

install_plugin_store() (
    local channel="${1:-stable}"
    local selected_version
    local loader_url
    local loader_official_url
    local loader_sha256
    local service_url
    local service_official_url
    local service_sha256
    local channel_branch

    case "$channel" in
        stable)
            selected_version="$DECKY_STABLE_VERSION"
            loader_url="$DECKY_LOADER_URL"
            loader_official_url="$DECKY_LOADER_OFFICIAL_URL"
            loader_sha256="$DECKY_LOADER_SHA256"
            service_url="$DECKY_SERVICE_URL"
            service_official_url="$DECKY_SERVICE_OFFICIAL_URL"
            service_sha256="$DECKY_SERVICE_SHA256"
            channel_branch=0
            ;;
        prerelease)
            selected_version="$DECKY_PRERELEASE_VERSION"
            loader_url="$DECKY_PRERELEASE_LOADER_URL"
            loader_official_url="$DECKY_PRERELEASE_LOADER_URL"
            loader_sha256="$DECKY_PRERELEASE_LOADER_SHA256"
            service_url="$DECKY_PRERELEASE_SERVICE_URL"
            service_official_url="$DECKY_PRERELEASE_SERVICE_URL"
            service_sha256="$DECKY_PRERELEASE_SERVICE_SHA256"
            channel_branch=1
            ;;
        *)
            echo "未知 Decky Loader 版本通道：$channel"
            return 1
            ;;
    esac
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" decky; then
        echo "插件商城安装已停止：准备检查未通过。"
        return 1
    fi
    local tmp_dir
    local loader_download
    local service_template
    local rendered_service
    local services_dir
    local settings_rendered
    local version_rendered
    local gitee_meta_file
    local gitee_meta_ok=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "插件商城安装仅支持真实SteamOS环境。"
        return 1
    fi
    if [ "$(id -u)" -eq 0 ]; then
        echo "请使用Steam Deck桌面用户运行Renkit，不要直接以root运行。"
        return 1
    fi
    for command_name in curl sudo install systemctl jq; do
        require_command "$command_name" || return 1
    done
    confirm_decky_install "$channel" || {
        echo "已取消插件商城更新。"
        return 0
    }

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    loader_download="$tmp_dir/PluginLoader.download"
    service_template="$tmp_dir/plugin_loader-release.service.download"
    rendered_service="$tmp_dir/plugin_loader.service"
    settings_rendered="$tmp_dir/loader.json"
    version_rendered="$tmp_dir/.loader.version"
    services_dir="$DECKY_HOMEBREW_DIR/services"
    gitee_meta_file="$tmp_dir/gitee-decky-mirror.txt"
    if load_decky_gitee_mirror_meta "$gitee_meta_file"; then
        gitee_meta_ok=1
    fi

    DECKY_INSTALL_COMMITTED=0
    DECKY_HOME_OP_SUDO=0
    DECKY_LOADER_TARGET="$services_dir/PluginLoader"
    DECKY_LOADER_NEW="$services_dir/.PluginLoader.new.$$"
    DECKY_LOADER_BACKUP="$services_dir/.PluginLoader.backup.$$"
    DECKY_LOADER_HAD_OLD=0
    DECKY_LOADER_SWAP_STARTED=0
    DECKY_UNIT_NEW="$DECKY_UNIT_PATH.new.$$"
    DECKY_UNIT_BACKUP="$DECKY_UNIT_PATH.backup.$$"
    DECKY_UNIT_HAD_OLD=0
    DECKY_UNIT_SWAP_STARTED=0
    DECKY_OLD_ENABLED=0
    DECKY_OLD_ACTIVE=0
    DECKY_SERVICE_STOPPED=0
    DECKY_USER_OLD_ENABLED=0
    DECKY_USER_OLD_ACTIVE=0
    DECKY_USER_SERVICE_STOPPED=0
    DECKY_VERSION_TARGET="$services_dir/.loader.version"
    DECKY_VERSION_NEW="$services_dir/.loader.version.new.$$"
    DECKY_VERSION_BACKUP="$services_dir/.loader.version.backup.$$"
    DECKY_VERSION_HAD_OLD=0
    DECKY_VERSION_SWAP_STARTED=0
    DECKY_SETTINGS_TARGET="$DECKY_HOMEBREW_DIR/settings/loader.json"
    DECKY_SETTINGS_NEW="$DECKY_HOMEBREW_DIR/settings/.loader.json.new.$$"
    DECKY_SETTINGS_BACKUP="$DECKY_HOMEBREW_DIR/settings/.loader.json.backup.$$"
    DECKY_SETTINGS_HAD_OLD=0
    DECKY_SETTINGS_SHOULD_SWAP=0
    DECKY_SETTINGS_SWAP_STARTED=0

    trap 'exit 130' INT TERM
    trap 'finish_plugin_store_install $?' EXIT

    if [ "$gitee_meta_ok" -eq 1 ] && download_decky_gitee_loader "$channel" "$loader_download"; then
        selected_version="$DECKY_GITEE_SELECTED_VERSION"
        echo "Decky PluginLoader 已从国内镜像下载。"
        log "Decky下载成功: Decky PluginLoader source=gitee"
    elif [ "$channel" = "prerelease" ]; then
        download_decky_prerelease_component \
            "Decky PluginLoader" \
            "$loader_url" \
            "$loader_sha256" \
            "$loader_download" || return 1
    else
        download_decky_component_with_fallback \
            "Decky PluginLoader" \
            "$loader_url" \
            "$loader_official_url" \
            "$loader_sha256" \
            "$loader_download" || return 1
    fi
    # 分块下载函数会静默每个分块；进入服务模板阶段后恢复进度输出。
    GITHUB_QUIET=0
    echo "正在下载 Decky systemd 服务模板..."
    if [ "$gitee_meta_ok" -eq 1 ] && download_decky_gitee_service "$channel" "$service_template"; then
        echo "Decky systemd服务模板 已从国内镜像下载。"
        log "Decky下载成功: Decky systemd服务模板 source=gitee"
    elif [ "$channel" = "prerelease" ]; then
        download_decky_prerelease_component \
            "Decky systemd服务模板" \
            "$service_url" \
            "$service_sha256" \
            "$service_template" || return 1
    else
        download_decky_component_with_fallback \
            "Decky systemd服务模板" \
            "$service_url" \
            "$service_official_url" \
            "$service_sha256" \
            "$service_template" || return 1
    fi
    render_decky_service "$service_template" "$rendered_service" "$DECKY_HOMEBREW_DIR" || return 1
    prepare_decky_homebrew_dirs "$DECKY_HOMEBREW_DIR" || return 1

    if [ -L "$DECKY_LOADER_TARGET" ] || \
        { [ -e "$DECKY_LOADER_TARGET" ] && [ ! -f "$DECKY_LOADER_TARGET" ]; } || \
        [ -L "$DECKY_UNIT_PATH" ] || \
        { [ -e "$DECKY_UNIT_PATH" ] && [ ! -f "$DECKY_UNIT_PATH" ]; } || \
        [ -L "$DECKY_VERSION_TARGET" ] || \
        { [ -e "$DECKY_VERSION_TARGET" ] && [ ! -f "$DECKY_VERSION_TARGET" ]; } || \
        [ -L "$DECKY_SETTINGS_TARGET" ] || \
        { [ -e "$DECKY_SETTINGS_TARGET" ] && [ ! -f "$DECKY_SETTINGS_TARGET" ]; }; then
        echo "Decky现有程序或服务文件类型异常，已停止安装。"
        return 1
    fi
    if [ -e "$DECKY_LOADER_NEW" ] || [ -e "$DECKY_LOADER_BACKUP" ] || \
        [ -e "$DECKY_VERSION_NEW" ] || [ -e "$DECKY_VERSION_BACKUP" ] || \
        [ -e "$DECKY_SETTINGS_NEW" ] || [ -e "$DECKY_SETTINGS_BACKUP" ] || \
        toolbox_sudo test -e "$DECKY_UNIT_NEW" || toolbox_sudo test -e "$DECKY_UNIT_BACKUP"; then
        echo "检测到未清理的Decky安装暂存文件，已停止以避免覆盖。"
        return 1
    fi

    if [ -f "$DECKY_LOADER_TARGET" ]; then
        DECKY_LOADER_HAD_OLD=1
    fi
    if toolbox_sudo test -f "$DECKY_UNIT_PATH"; then
        DECKY_UNIT_HAD_OLD=1
    fi
    # 稳定版和测试版最终都由 plugin_loader.service 承载。即使旧 unit 不在
    # 当前预期路径，也要先按 systemd 实际状态停掉旧服务，再替换任何文件。
    toolbox_sudo systemctl is-enabled --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 && \
        DECKY_OLD_ENABLED=1
    toolbox_sudo systemctl is-active --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 && \
        DECKY_OLD_ACTIVE=1
    [ ! -f "$DECKY_VERSION_TARGET" ] || DECKY_VERSION_HAD_OLD=1
    if [ -f "$DECKY_SETTINGS_TARGET" ]; then
        DECKY_SETTINGS_HAD_OLD=1
        prepare_decky_loader_channel_settings \
            "$DECKY_SETTINGS_TARGET" "$settings_rendered" "$channel_branch" || return 1
        DECKY_SETTINGS_SHOULD_SWAP=1
    fi

    if [ "$DECKY_LOADER_HAD_OLD" -eq 1 ] || [ "$DECKY_UNIT_HAD_OLD" -eq 1 ]; then
        echo "检测到已有 Decky Loader，正在更新并保留全部插件与设置。"
    else
        echo "未检测到完整 Decky Loader，正在执行首次安装。"
    fi
    if [ "$DECKY_OLD_ACTIVE" -eq 1 ]; then
        echo "正在停止旧 Decky Loader 服务..."
        toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME" || {
            echo "旧 Decky Loader 服务停止失败，未替换现有文件。"
            return 1
        }
        DECKY_SERVICE_STOPPED=1
    fi
    stop_legacy_decky_user_service || return 1

    run_decky_homebrew_operation install -m 0755 -- "$loader_download" "$DECKY_LOADER_NEW" || return 1
    toolbox_sudo install -m 0644 -- "$rendered_service" "$DECKY_UNIT_NEW" || return 1
    printf '%s\n' "$selected_version" > "$version_rendered" || return 1
    run_decky_homebrew_operation install -m 0644 -- \
        "$version_rendered" "$DECKY_VERSION_NEW" || return 1
    if [ "$DECKY_SETTINGS_SHOULD_SWAP" -eq 1 ]; then
        run_decky_homebrew_operation install -m 0600 -- \
            "$settings_rendered" "$DECKY_SETTINGS_NEW" || return 1
    fi

    DECKY_LOADER_SWAP_STARTED=1
    if [ "$DECKY_LOADER_HAD_OLD" -eq 1 ]; then
        run_decky_homebrew_operation mv -- "$DECKY_LOADER_TARGET" "$DECKY_LOADER_BACKUP" || return 1
    fi
    run_decky_homebrew_operation mv -- "$DECKY_LOADER_NEW" "$DECKY_LOADER_TARGET" || return 1

    DECKY_UNIT_SWAP_STARTED=1
    if [ "$DECKY_UNIT_HAD_OLD" -eq 1 ]; then
        toolbox_sudo mv -- "$DECKY_UNIT_PATH" "$DECKY_UNIT_BACKUP" || return 1
    fi
    toolbox_sudo mv -- "$DECKY_UNIT_NEW" "$DECKY_UNIT_PATH" || return 1

    DECKY_VERSION_SWAP_STARTED=1
    if [ "$DECKY_VERSION_HAD_OLD" -eq 1 ]; then
        run_decky_homebrew_operation mv -- \
            "$DECKY_VERSION_TARGET" "$DECKY_VERSION_BACKUP" || return 1
    fi
    run_decky_homebrew_operation mv -- \
        "$DECKY_VERSION_NEW" "$DECKY_VERSION_TARGET" || return 1

    if [ "$DECKY_SETTINGS_SHOULD_SWAP" -eq 1 ]; then
        DECKY_SETTINGS_SWAP_STARTED=1
        run_decky_homebrew_operation mv -- \
            "$DECKY_SETTINGS_TARGET" "$DECKY_SETTINGS_BACKUP" || return 1
        run_decky_homebrew_operation mv -- \
            "$DECKY_SETTINGS_NEW" "$DECKY_SETTINGS_TARGET" || return 1
    fi

    echo "正在启动更新后的 Decky Loader 服务..."
    toolbox_sudo systemctl daemon-reload || return 1
    toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME" || return 1
    toolbox_sudo systemctl enable "$DECKY_SERVICE_NAME" || return 1

    DECKY_INSTALL_COMMITTED=1
    run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_BACKUP" || true
    run_decky_homebrew_operation rm -f -- "$DECKY_VERSION_BACKUP" || true
    run_decky_homebrew_operation rm -f -- "$DECKY_SETTINGS_BACKUP" || true
    toolbox_sudo rm -f -- "$DECKY_UNIT_BACKUP" || true
    remove_legacy_decky_user_unit || \
        echo "Decky 已更新，但旧用户服务文件未能清理；请重启后再检查。"

    echo "Decky Loader $selected_version 更新完成，已有插件未被改动。请返回游戏模式检查插件菜单。"
    log "Decky Loader更新完成 channel=$channel version=$selected_version"
)

decky_plugin_store_is_installed() {
    [ -x "$DECKY_HOMEBREW_DIR/services/PluginLoader" ] && \
        [ -f "$DECKY_UNIT_PATH" ]
}

decky_plugin_loader_is_installed() {
    [ -x "$HOME/homebrew/services/PluginLoader" ] || \
        [ -x "$HOME/.local/share/decky-loader/services/PluginLoader" ]
}

ensure_plugin_store_ready() {
    detect_platform
    if [ "$IS_BAZZITE" -eq 1 ]; then
        if decky_plugin_loader_is_installed; then
            echo "已检测到 Bazzite Decky Loader，开始安装插件。"
            return 0
        fi
        echo "未检测到 Decky Loader，先调用 Bazzite 官方安装入口。"
        bash "$PROJECT_ROOT/modules/bazzite_decky.sh" install || {
            echo "Bazzite Decky Loader 未安装完成，已停止后续插件安装。"
            return 1
        }
        decky_plugin_loader_is_installed || {
            echo "Bazzite Decky Loader 安装后未通过文件检查，已停止后续插件安装。"
            return 1
        }
        echo "Bazzite Decky Loader 已安装完成，继续安装插件。"
        return 0
    fi

    if decky_plugin_store_is_installed; then
        echo "已检测到插件商城，开始安装插件。"
        return 0
    fi

    echo "未检测到插件商城，先安装插件商城。"
    install_plugin_store || {
        echo "插件商城未安装完成，已停止后续插件安装。"
        return 1
    }
    decky_plugin_store_is_installed || {
        echo "插件商城安装后未通过检查，已停止后续插件安装。"
        return 1
    }
    echo "插件商城已安装完成，继续安装插件。"
}

uninstall_plugin_store() {
    local loader_path="$DECKY_HOMEBREW_DIR/services/PluginLoader"
    local version_path="$DECKY_HOMEBREW_DIR/services/.loader.version"
    local saved_systemd_dir="$DECKY_HOMEBREW_DIR/services/.systemd"
    local managed_path
    local answer

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "插件商城卸载仅支持真实 SteamOS 环境。"
        return 1
    fi
    if ! decky_plugin_store_is_installed && \
       [ ! -e "$loader_path" ] && [ ! -L "$loader_path" ] && \
       [ ! -e "$version_path" ] && [ ! -L "$version_path" ] && \
       [ ! -e "$DECKY_UNIT_PATH" ] && [ ! -L "$DECKY_UNIT_PATH" ] && \
       [ ! -e "$DECKY_USER_UNIT_PATH" ] && [ ! -L "$DECKY_USER_UNIT_PATH" ] && \
       [ ! -e "$saved_systemd_dir/plugin_loader.service" ] && \
       [ ! -e "$saved_systemd_dir/plugin_loader-release.service" ] && \
       [ ! -e "$saved_systemd_dir/plugin_loader-prerelease.service" ]; then
        rmdir "$saved_systemd_dir" 2>/dev/null || true
        rmdir "$DECKY_HOMEBREW_DIR/services" 2>/dev/null || true
        echo "Decky Loader 插件商城未安装。"
        return 0
    fi
    for managed_path in \
        "$loader_path" \
        "$version_path" \
        "$DECKY_UNIT_PATH" \
        "$DECKY_USER_UNIT_PATH" \
        "$saved_systemd_dir/plugin_loader.service" \
        "$saved_systemd_dir/plugin_loader-release.service" \
        "$saved_systemd_dir/plugin_loader-prerelease.service"; do
        if [ -e "$managed_path" ] && [ ! -f "$managed_path" ] && [ ! -L "$managed_path" ]; then
            echo "Decky Loader 路径类型异常，拒绝自动删除：$managed_path"
            return 1
        fi
    done
    echo "将卸载 Decky Loader 稳定版或测试版本体，但保留全部插件目录和插件设置。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        read -r -p "确认卸载请输入 UNINSTALL：" answer
        [ "$answer" = "UNINSTALL" ] || { echo "已取消卸载。"; return 0; }
    fi
    require_command sudo || return 1
    require_command systemctl || return 1
    if toolbox_sudo systemctl is-active --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1; then
        toolbox_sudo systemctl disable --now "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || {
            echo "Decky Loader 系统服务无法停用，未继续删除。"
            return 1
        }
    else
        toolbox_sudo systemctl disable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
    fi
    if systemctl --user is-active --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1; then
        systemctl --user disable --now "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || {
            echo "Decky Loader 旧用户服务无法停用，未继续删除。"
            return 1
        }
    else
        systemctl --user disable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
    fi
    toolbox_sudo rm -f -- \
        "$loader_path" \
        "$version_path" \
        "$DECKY_UNIT_PATH" \
        "$DECKY_USER_UNIT_PATH" \
        "$saved_systemd_dir/plugin_loader.service" \
        "$saved_systemd_dir/plugin_loader-release.service" \
        "$saved_systemd_dir/plugin_loader-prerelease.service" || return 1
    toolbox_sudo systemctl daemon-reload >/dev/null 2>&1 || return 1
    systemctl --user daemon-reload >/dev/null 2>&1 || return 1
    toolbox_sudo rmdir "$saved_systemd_dir" 2>/dev/null || true
    toolbox_sudo rmdir "$DECKY_HOMEBREW_DIR/services" 2>/dev/null || true
    toolbox_sudo rmdir "$DECKY_HOMEBREW_DIR" 2>/dev/null || true
    echo "Decky Loader 稳定版和测试版残留已卸载；$DECKY_HOMEBREW_DIR/plugins 中的插件文件与设置已保留。"
    log "Decky Loader 稳定版和测试版残留已卸载并保留插件与设置"
}

download_verified_package() {
    local name="$1"
    local url="$2"
    local expected_sha256="$3"
    local output="$4"
    local mirror_id

    if [ -z "$url" ] || [ -z "$expected_sha256" ]; then
        echo "$name 的下载配置不完整，请先更新Renkit。"
        return 1
    fi
    mirror_id="$(gitee_mirror_id_for_url "$url" 2>/dev/null || true)"
    if [ -n "$mirror_id" ]; then
        download_with_gitee_mirror_fallback \
            "$mirror_id" "$url" "$expected_sha256" "$output" "$name"
    else
        download_github_file "$url" "$output" "$expected_sha256" "$name"
    fi
}

archive_paths_are_safe() {
    local archive="$1"
    local archive_type="$2"
    local paths

    case "$archive_type" in
        zip) paths="$(unzip -Z1 "$archive")" || return 1 ;;
        tar.gz) paths="$(tar -tzf "$archive")" || return 1 ;;
        *) return 1 ;;
    esac

    if printf '%s\n' "$paths" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        echo "压缩包包含不安全路径，已停止安装。"
        return 1
    fi
}

tar_archive_has_no_links() {
    local archive="$1"

    ! tar -tvzf "$archive" | awk '$1 ~ /^[lh]/ { found=1 } END { exit found ? 0 : 1 }'
}

run_plugin_file_operation() {
    if [ "${PLUGIN_NEEDS_SUDO:-0}" -eq 1 ]; then
        toolbox_sudo "$@"
    else
        "$@"
    fi
}

prepare_plugin_root() {
    local plugin_root="$1"

    if [ ! -d "$plugin_root" ]; then
        echo "未找到 Decky 插件目录：$plugin_root"
        echo "请先点击“安装或更新 Decky Loader”，完成后再安装插件。"
        return 1
    fi
    if [ -w "$plugin_root" ]; then
        PLUGIN_NEEDS_SUDO=0
    else
        require_command sudo || return 1
        PLUGIN_NEEDS_SUDO=1
    fi
}

install_tree_atomically() {
    local source_dir="$1"
    local target_parent="$2"
    local target_name="$3"
    local target_dir="$target_parent/$target_name"
    local staging_dir="$target_parent/.${target_name}.new.$$"
    local backup_dir="$target_parent/.${target_name}.backup.$$"

    run_plugin_file_operation rm -rf -- "$staging_dir" "$backup_dir" || return 1
    run_plugin_file_operation cp -a -- "$source_dir" "$staging_dir" || return 1

    if [ -e "$target_dir" ]; then
        run_plugin_file_operation mv -- "$target_dir" "$backup_dir" || {
            run_plugin_file_operation rm -rf -- "$staging_dir"
            return 1
        }
    fi

    if ! run_plugin_file_operation mv -- "$staging_dir" "$target_dir"; then
        if [ -e "$backup_dir" ] && [ ! -e "$target_dir" ]; then
            run_plugin_file_operation mv -- "$backup_dir" "$target_dir" || true
        fi
        return 1
    fi
    run_plugin_file_operation rm -rf -- "$backup_dir"
}

find_plugin_source() {
    local extract_dir="$1"
    local plugin_json

    if [ -f "$extract_dir/plugin.json" ] && [ ! -L "$extract_dir/plugin.json" ]; then
        printf '%s\n' "$extract_dir"
        return 0
    fi
    plugin_json="$(find "$extract_dir" -mindepth 2 -maxdepth 3 -type f -name plugin.json -print -quit)"
    [ -n "$plugin_json" ] || return 1
    dirname "$plugin_json"
}

decky_plugin_directory_is_complete() {
    local plugin_root="$1"
    local directory_name="$2"
    local plugin_dir="$plugin_root/$directory_name"
    local manifest_name

    [ -d "$plugin_dir" ] && \
        [ ! -L "$plugin_dir" ] && \
        [ -f "$plugin_dir/plugin.json" ] && \
        [ ! -L "$plugin_dir/plugin.json" ] && \
        [ -s "$plugin_dir/dist/index.js" ] && \
        [ ! -L "$plugin_dir/dist/index.js" ] || return 1
    manifest_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$plugin_dir/plugin.json" | head -n 1)"
    [ -n "$manifest_name" ]
}

patch_deckrecall_steam_browser() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local plugin_dir="$plugin_root/DeckRecall"
    local index_file="$plugin_dir/dist/index.js"
    local temporary
    local staged
    local index_size
    local installed_version
    local patched_marker='steamBrowser.OpenUrl("https://flingtrainer.com/");'

    [ -d "$plugin_dir" ] && [ ! -L "$plugin_dir" ] && \
        [ -d "$plugin_dir/dist" ] && [ ! -L "$plugin_dir/dist" ] && \
        [ -f "$index_file" ] && [ ! -L "$index_file" ] || {
        echo "DeckRecall 前端文件类型异常，未修改浏览器调用。"
        return 1
    }
    index_size="$(wc -c < "$index_file" | tr -d '[:space:]')"
    case "$index_size" in
        ''|*[!0-9]*)
            echo "无法确认 DeckRecall 前端文件大小，未修改浏览器调用。"
            return 1
            ;;
    esac
    if [ "$index_size" -le 0 ] || [ "$index_size" -gt 4194304 ]; then
        echo "DeckRecall 前端文件大小异常，未修改浏览器调用。"
        return 1
    fi
    installed_version="$(decky_plugin_version "$plugin_dir" || true)"
    if [[ "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && \
        ! deckrecall_version_is_older "$installed_version" "0.3.1"; then
        echo "[已内置] DeckRecall $installed_version 已使用新版下载与浏览器处理，无需兼容补丁。"
        return 0
    fi
    if grep -Fq -- "$patched_marker" "$index_file"; then
        echo "[已修复] DeckRecall 已直接调用 Steam 浏览器打开风灵月影网站。"
        return 0
    fi
    require_command python3 || return 1
    prepare_plugin_root "$plugin_root" || return 1
    temporary="$(mktemp "${TMPDIR:-/tmp}/deckrecall-browser.XXXXXX")" || return 1
    if ! python3 - "$index_file" "$temporary" <<'PY'
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
old = b'DFL.Navigation.NavigateToExternalWeb("https://flingtrainer.com/");'
wrong_system_browser = b'''const systemBrowser = globalThis.SteamClient?.System;
                                if (typeof systemBrowser?.OpenInSystemBrowser === "function") {
                                    systemBrowser.OpenInSystemBrowser("https://flingtrainer.com/");
                                    return;
                                }
                                DFL.Navigation.NavigateToExternalWeb("https://flingtrainer.com/");'''
new = b'''const steamBrowser = globalThis.SteamClient?.Browser;
                                if (typeof steamBrowser?.OpenUrl === "function") {
                                    steamBrowser.OpenUrl("https://flingtrainer.com/");
                                    return;
                                }
                                DFL.Navigation.NavigateToExternalWeb("https://flingtrainer.com/");'''
content = source_path.read_bytes()
if content.count(wrong_system_browser) == 1:
    content = content.replace(wrong_system_browser, new, 1)
elif content.count(old) == 1:
    content = content.replace(old, new, 1)
else:
    raise SystemExit(2)
output_path.write_bytes(content)
PY
    then
        rm -f -- "$temporary"
        echo "当前 DeckRecall 版本的浏览器调用与已核验版本不一致，未强行修改。"
        return 1
    fi
    chmod 0644 "$temporary" || {
        rm -f -- "$temporary"
        return 1
    }
    if ! grep -Fq -- "$patched_marker" "$temporary" || \
        grep -Fq 'systemBrowser.OpenInSystemBrowser("https://flingtrainer.com/");' "$temporary" || \
        [ "$(grep -Foc 'DFL.Navigation.NavigateToExternalWeb("https://flingtrainer.com/");' "$temporary")" -ne 1 ]; then
        rm -f -- "$temporary"
        echo "DeckRecall 浏览器兼容补丁校验失败，原文件保持不变。"
        return 1
    fi

    staged="$plugin_dir/dist/.index.js.renkit-new.$$"
    if [ -e "$staged" ] || [ -L "$staged" ]; then
        rm -f -- "$temporary"
        echo "DeckRecall 浏览器补丁临时路径已存在，未修改原文件。"
        return 1
    fi
    if ! run_plugin_file_operation cp -- "$temporary" "$staged" || \
        ! run_plugin_file_operation chmod 0644 "$staged" || \
        ! run_plugin_file_operation mv -- "$staged" "$index_file"; then
        run_plugin_file_operation rm -f -- "$staged" >/dev/null 2>&1 || true
        rm -f -- "$temporary"
        echo "DeckRecall 浏览器补丁写入失败，原文件保持不变。"
        return 1
    fi
    rm -f -- "$temporary"
    PLUGIN_INSTALL_CHANGED=1
    echo "DeckRecall 已改为直接调用 Steam 浏览器打开风灵月影网站。"
}

install_decky_zip() {
    local display_name="$1"
    local url="$2"
    local sha256="$3"
    local expected_dir="$4"
    local skip_existing="${5:-1}"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local tmp_dir
    local archive
    local extract_dir
    local plugin_source

    PLUGIN_INSTALL_CHANGED=0
    if [ "$skip_existing" = "1" ] && \
       decky_plugin_directory_is_complete "$plugin_root" "$expected_dir"; then
        echo "[已安装] $display_name 已存在且文件完整，无需重复安装。"
        return 0
    fi
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" decky; then
        echo "$display_name 安装已停止：准备检查未通过。"
        return 1
    fi
    for command_name in curl unzip; do
        require_command "$command_name" || return 1
    done
    prepare_plugin_root "$plugin_root" || return 1

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    archive="$tmp_dir/plugin.zip"
    extract_dir="$tmp_dir/extracted"
    mkdir -p "$extract_dir"
    trap cleanup_decky_tmp EXIT INT TERM

    if ! download_verified_package "$display_name" "$url" "$sha256" "$archive"; then
        bash "$PROJECT_ROOT/modules/steam_accelerator.sh" ensure || true
        download_verified_package "$display_name" "$url" "$sha256" "$archive" || return 1
    fi
    archive_paths_are_safe "$archive" zip || return 1
    unzip -q "$archive" -d "$extract_dir" || {
        echo "$display_name 解压失败，未改动现有插件。"
        return 1
    }
    plugin_source="$(find_plugin_source "$extract_dir")" || {
        echo "$display_name 压缩包中没有找到 plugin.json。"
        return 1
    }
    if [ "$plugin_source" != "$extract_dir" ] && \
        [ "$(basename "$plugin_source")" != "$expected_dir" ]; then
        echo "$display_name 的目录结构不符合预期，已停止安装。"
        return 1
    fi

    install_tree_atomically "$plugin_source" "$plugin_root" "$expected_dir" || {
        echo "$display_name 安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "$display_name 安装成功。"
    log "$display_name 安装完成"
    PLUGIN_INSTALL_CHANGED=1
    cleanup_decky_tmp
    trap - EXIT INT TERM
}

ensure_official_plugin_current() {
    local display_name="$1" directory_name="$2" package_version="$3"
    local legacy_localized_name="$4" official_name="$5" url="$6" sha256="$7"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local installed_version actual_name

    actual_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$plugin_root/$directory_name/plugin.json" 2>/dev/null | head -n 1)"
    # 旧版把 plugin.json name 改成了中文，会让 Decky 身份不匹配导致空白页/功能失效；
    # 检测到旧问题安装时直接重新安装官方包，原子替换整个插件目录，清理问题文件。
    if [ "$actual_name" = "$legacy_localized_name" ]; then
        echo "检测到旧版中文名插件，正在重新安装官方版本以清理问题文件。"
        install_decky_zip "$display_name" "$url" "$sha256" "$directory_name" 0 || return 1
        return 0
    fi
    if feature_plugin_is_current "$plugin_root" "$directory_name" "$package_version" \
        "$official_name"; then
        echo "[已安装] $display_name v$package_version 已存在且官方名称正确，无需重复安装。"
        PLUGIN_INSTALL_CHANGED=0
        return 0
    fi
    installed_version="$(decky_plugin_version "$plugin_root/$directory_name" || true)"
    if [ "$installed_version" != "$package_version" ] || \
       ! feature_plugin_is_present "$plugin_root" "$directory_name" \
            "$official_name"; then
        install_decky_zip "$display_name" "$url" "$sha256" "$directory_name" 0 || return 1
    else
        PLUGIN_INSTALL_CHANGED=0
    fi
}

ensure_cssloader_chinese_current() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local installed_version actual_sha256 work_dir staged_source

    installed_version="$(decky_plugin_version "$plugin_root/$CSSLOADER_OFFICIAL_DIRECTORY" || true)"
    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$CSSLOADER_OFFICIAL_DIRECTORY/dist/index.js" 2>/dev/null || true)"
    if feature_plugin_is_current "$plugin_root" "$CSSLOADER_OFFICIAL_DIRECTORY" \
        "$CSSLOADER_OFFICIAL_VERSION" "主题美化" && \
       [ "$actual_sha256" = "$CSSLOADER_ZH_INDEX_SHA256" ]; then
        echo "[已安装] 主题美化 v$CSSLOADER_OFFICIAL_VERSION 中文版已存在且校验通过。"
        PLUGIN_INSTALL_CHANGED=0
        return 0
    fi
    if [ "$installed_version" != "$CSSLOADER_OFFICIAL_VERSION" ] || \
       ! feature_plugin_is_present "$plugin_root" "$CSSLOADER_OFFICIAL_DIRECTORY" \
            "CSS Loader" "主题美化"; then
        install_decky_zip "主题美化（CSS Loader 中文版）" \
            "$DECKY_CSSLOADER_URL" "$DECKY_CSSLOADER_SHA256" \
            "$CSSLOADER_OFFICIAL_DIRECTORY" 0 || return 1
    fi
    if [ -L "$CSSLOADER_ZH_SOURCE_DIR" ] || \
       [ ! -f "$CSSLOADER_ZH_SOURCE_DIR/plugin.json" ] || \
       [ ! -s "$CSSLOADER_ZH_SOURCE_DIR/dist/index.js" ] || \
       [ ! -f "$CSSLOADER_ZH_SOURCE_DIR/LICENSE" ] || \
       [ "$(calculate_decky_sha256 "$CSSLOADER_ZH_SOURCE_DIR/dist/index.js" || true)" \
            != "$CSSLOADER_ZH_INDEX_SHA256" ]; then
        echo "主题美化中文组件不完整或校验失败，官方后端保持不变。"
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1
    work_dir="$(mktemp -d)" || return 1
    staged_source="$work_dir/$CSSLOADER_OFFICIAL_DIRECTORY"
    if ! cp -a -- "$plugin_root/$CSSLOADER_OFFICIAL_DIRECTORY" "$staged_source" || \
       ! cp -- "$CSSLOADER_ZH_SOURCE_DIR/dist/index.js" "$staged_source/dist/index.js" || \
       ! cp -- "$CSSLOADER_ZH_SOURCE_DIR/plugin.json" "$staged_source/plugin.json"; then
        rm -rf -- "$work_dir"
        echo "主题美化中文前端准备失败，官方插件保持不变。"
        return 1
    fi
    install_tree_atomically "$staged_source" "$plugin_root" \
        "$CSSLOADER_OFFICIAL_DIRECTORY" || {
        rm -rf -- "$work_dir"
        echo "主题美化中文前端安装失败，已尽量保留官方版本。"
        return 1
    }
    rm -rf -- "$work_dir"
    PLUGIN_INSTALL_CHANGED=1
    echo "CSS Loader v$CSSLOADER_OFFICIAL_VERSION 已完成中文化并显示为“主题美化”；官方后端未改动。"
}

install_decky_tar_gz() {
    local display_name="$1"
    local url="$2"
    local sha256="$3"
    local expected_dir="$4"
    local skip_existing="${5:-1}"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local tmp_dir archive extract_dir plugin_source

    PLUGIN_INSTALL_CHANGED=0
    if [ "$skip_existing" = "1" ] && \
       decky_plugin_directory_is_complete "$plugin_root" "$expected_dir"; then
        echo "[已安装] $display_name 已存在且文件完整，无需重复安装。"
        return 0
    fi
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" decky; then
        echo "$display_name 安装已停止：准备检查未通过。"
        return 1
    fi
    for command_name in curl tar; do require_command "$command_name" || return 1; done
    prepare_plugin_root "$plugin_root" || return 1

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    archive="$tmp_dir/plugin.tar.gz"
    extract_dir="$tmp_dir/extracted"
    mkdir -p "$extract_dir"
    trap cleanup_decky_tmp EXIT INT TERM

    if ! download_verified_package "$display_name" "$url" "$sha256" "$archive"; then
        bash "$PROJECT_ROOT/modules/steam_accelerator.sh" ensure || true
        download_verified_package "$display_name" "$url" "$sha256" "$archive" || return 1
    fi
    archive_paths_are_safe "$archive" tar.gz || return 1
    tar_archive_has_no_links "$archive" || {
        echo "$display_name 压缩包包含异常链接，已停止安装。"
        return 1
    }
    tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$extract_dir" || {
        echo "$display_name 解压失败，未改动现有插件。"
        return 1
    }
    plugin_source="$(find_plugin_source "$extract_dir")" || {
        echo "$display_name 压缩包中没有找到 plugin.json。"
        return 1
    }
    if [ "$(basename "$plugin_source")" != "$expected_dir" ]; then
        echo "$display_name 的目录结构不符合预期，已停止安装。"
        return 1
    fi
    install_tree_atomically "$plugin_source" "$plugin_root" "$expected_dir" || {
        echo "$display_name 安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "$display_name 安装成功。"
    log "$display_name 安装完成"
    PLUGIN_INSTALL_CHANGED=1
    cleanup_decky_tmp
    trap - EXIT INT TERM
}

extract_gitee_plugin_archive() {
    local repository_archive="$1"
    local archive_member="$2"
    local output="$3"
    local expected_sha256="$4"
    local actual_sha256

    case "$archive_member" in
        ''|/*|*'../'*|*'/..')
            echo "归档内插件路径不安全，已停止提取。"
            return 1
            ;;
    esac
    archive_paths_are_safe "$repository_archive" zip || return 1
    unzip -Z1 "$repository_archive" | grep -Fxq -- "$archive_member" || {
        echo "Gitee 镜像下载失败。"
        return 1
    }
    if ! unzip -p "$repository_archive" "$archive_member" > "$output"; then
        rm -f -- "$output"
        echo "下载失败，切换备用源。"
        return 1
    fi
    actual_sha256="$(calculate_decky_sha256 "$output")" || {
        rm -f -- "$output"
        return 1
    }
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        rm -f -- "$output"
        echo "下载失败，切换备用源。"
        return 1
    fi
    archive_paths_are_safe "$output" zip || {
        rm -f -- "$output"
        return 1
    }
}

install_decky_zip_from_gitee_archive() {
    local display_name="$1"
    local plugin_archive_name="$2"
    local plugin_sha256="$3"
    local expected_dir="$4"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local tmp_dir repository_archive plugin_archive extract_dir plugin_source archive_member

    PLUGIN_INSTALL_CHANGED=0
    cleanup_decky_tmp
    trap - EXIT INT TERM
    for command_name in curl unzip; do
        require_command "$command_name" || return 1
    done
    prepare_plugin_root "$plugin_root" || return 1
    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    repository_archive="$tmp_dir/gitee-repository.zip"
    plugin_archive="$tmp_dir/plugin.zip"
    extract_dir="$tmp_dir/extracted"
    archive_member="${DECKY_GITEE_ARCHIVE_PREFIX:-}/dist/$plugin_archive_name"
    mkdir -p "$extract_dir"
    trap cleanup_decky_tmp EXIT INT TERM

    echo "正在安装 $display_name..."
    download_github_file \
        "${DECKY_GITEE_ARCHIVE_URL:-}" \
        "$repository_archive" \
        "${DECKY_GITEE_ARCHIVE_SHA256:-}" \
        "Renkit归档" || return 1
    extract_gitee_plugin_archive \
        "$repository_archive" "$archive_member" "$plugin_archive" "$plugin_sha256" || return 1
    unzip -q "$plugin_archive" -d "$extract_dir" || {
        echo "$display_name 解压失败，未改动现有插件。"
        return 1
    }
    plugin_source="$(find_plugin_source "$extract_dir")" || {
        echo "$display_name 压缩包中没有找到 plugin.json。"
        return 1
    }
    if [ "$(basename "$plugin_source")" != "$expected_dir" ]; then
        echo "$display_name 的目录结构不符合预期，已停止安装。"
        return 1
    fi
    install_tree_atomically "$plugin_source" "$plugin_root" "$expected_dir" || {
        echo "$display_name 安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "$display_name 安装成功。"
    log "$display_name 通过 Gitee 国内源安装完成"
    PLUGIN_INSTALL_CHANGED=1
    cleanup_decky_tmp
    trap - EXIT INT TERM
}

install_decky_zip_from_mirror() {
    local display_name="$1"
    local mirror_id="$2"
    local plugin_sha256="$3"
    local expected_dir="$4"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local tmp_dir plugin_archive extract_dir plugin_source

    require_command unzip || return 1
    prepare_plugin_root "$plugin_root" || return 1
    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    plugin_archive="$tmp_dir/plugin.zip"
    extract_dir="$tmp_dir/extracted"
    mkdir -p "$extract_dir"
    trap cleanup_decky_tmp EXIT INT TERM

    if ! download_gitee_mirror_file \
        "$mirror_id" "$plugin_archive" "$plugin_sha256" "$display_name" \
        >/dev/null 2>&1; then
        cleanup_decky_tmp
        trap - EXIT INT TERM
        echo "下载失败，切换备用源。"
        return 1
    fi
    archive_paths_are_safe "$plugin_archive" zip || {
        cleanup_decky_tmp
        trap - EXIT INT TERM
        return 1
    }
    if ! unzip -q "$plugin_archive" -d "$extract_dir"; then
        cleanup_decky_tmp
        trap - EXIT INT TERM
        echo "$display_name 解压失败，未改动现有插件。"
        return 1
    fi
    plugin_source="$(find_plugin_source "$extract_dir")" || {
        cleanup_decky_tmp
        trap - EXIT INT TERM
        echo "$display_name 压缩包中没有找到 plugin.json。"
        return 1
    }
    if [ "$(basename "$plugin_source")" != "$expected_dir" ]; then
        cleanup_decky_tmp
        trap - EXIT INT TERM
        echo "$display_name 的目录结构不符合预期，已停止安装。"
        return 1
    fi
    if ! install_tree_atomically "$plugin_source" "$plugin_root" "$expected_dir"; then
        cleanup_decky_tmp
        trap - EXIT INT TERM
        echo "$display_name 安装失败，已尽量保留原版本。"
        return 1
    fi
    echo "$display_name 安装成功。"
    log "$display_name 通过 Gitee 镜像安装完成"
    PLUGIN_INSTALL_CHANGED=1
    cleanup_decky_tmp
    trap - EXIT INT TERM
}

reload_decky_plugins() {
    local success_message="$1"

    if command -v systemctl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        if toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME"; then
            echo "$success_message"
            return 0
        fi
        echo "插件文件已变更，但 Decky 重载未完成。请完全退出游戏模式后重新进入一次。"
        return 0
    fi

    echo "插件文件已变更。请完全退出游戏模式后重新进入一次，让 Decky 重新扫描插件目录。"
}

install_zhoukeer_localizer() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local source_dir="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "Renkit汉化仅支持真实 SteamOS 环境。"
        return 1
    fi
    if [ -L "$source_dir" ] || [ ! -f "$source_dir/plugin.json" ] || [ ! -s "$source_dir/dist/index.js" ]; then
        echo "Renkit汉化组件不完整，请更新Renkit后再试。"
        return 1
    fi
    if decky_plugin_directory_is_complete "$plugin_root" "zhoukeer-localizer"; then
        echo "[已安装] Renkit汉化已存在且文件完整，无需重复安装。"
        return 0
    fi
    prepare_plugin_root "$plugin_root" || return 1

    install_tree_atomically "$source_dir" "$plugin_root" "zhoukeer-localizer" || {
        echo "Renkit汉化安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "Renkit汉化修复版已安装，正在让 Decky 重新扫描插件目录..."
    reload_decky_plugins "Decky 已重新加载。返回游戏模式后，在插件列表中打开“Renkit汉化”，再打开需要汉化的插件页面。"
    log "Renkit汉化修复版安装完成"
}

uninstall_all_decky_plugins() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local entry
    local removed=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "Decky 插件卸载仅支持真实 SteamOS 环境。"
        return 1
    fi
    if [ -L "$plugin_root" ] || [ ! -d "$plugin_root" ]; then
        echo "Decky 插件目录异常，已停止卸载。"
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        if command -v kdialog >/dev/null 2>&1; then
            kdialog --title "确认清空 Decky 插件" --warningyesno \
                "确定清空插件根目录内的所有 Decky 插件吗？这会删除全部插件文件和插件设置，但不会删除 Decky Loader 本体。" \
                --yes-label "全部删除" --no-label "取消" >/dev/null 2>&1 || {
                echo "已取消卸载。"
                return 0
            }
        else
            echo "请从Renkit菜单点击“一键清空已装插件”后，在触控确认页继续。"
            return 1
        fi
    fi

    for entry in "$plugin_root"/* "$plugin_root"/.[!.]* "$plugin_root"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        run_plugin_file_operation rm -rf -- "$entry" || {
            echo "清空失败，已停止；未处理的插件仍保留。"
            return 1
        }
        removed=$((removed + 1))
    done

    echo "已清空插件根目录：共删除 $removed 个项目。"
    reload_decky_plugins "Decky 已重新加载，插件列表已清空。"
    log "Decky插件根目录已清空: $removed 项"
}

open_lossless_store() {
    echo "正在打开 Lossless Scaling 的 Steam 正版页面..."
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "steam://store/993090" >/dev/null 2>&1 &
    elif command -v steam >/dev/null 2>&1; then
        steam "steam://store/993090" >/dev/null 2>&1 &
    else
        echo "商店地址：https://store.steampowered.com/app/993090/"
    fi
}

LOSSLESS_WORK_DIR=""
LOSSLESS_LOCK_DIR=""
LOSSLESS_ARCHIVE_MEMBERS=0
LOSSLESS_ARCHIVE_BYTES=0

cleanup_lossless_import() {
    if [ -n "$LOSSLESS_WORK_DIR" ] && [ -d "$LOSSLESS_WORK_DIR" ]; then
        rm -rf -- "$LOSSLESS_WORK_DIR"
    fi
    if [ -n "$LOSSLESS_LOCK_DIR" ] && [ -d "$LOSSLESS_LOCK_DIR" ]; then
        rmdir -- "$LOSSLESS_LOCK_DIR" 2>/dev/null || true
    fi
    LOSSLESS_WORK_DIR=""
    LOSSLESS_LOCK_DIR=""
}

file_size_bytes() {
    local file="$1"

    if stat -c '%s' -- "$file" >/dev/null 2>&1; then
        stat -c '%s' -- "$file"
    else
        stat -f '%z' -- "$file"
    fi
}

free_space_bytes() {
    df -Pk "$1" 2>/dev/null | awk 'NR > 1 { free_kb=$4 } END { printf "%.0f\n", free_kb * 1024 }'
}

canonical_directory() {
    (cd "$1" 2>/dev/null && pwd -P)
}

append_steam_library_if_valid() {
    local candidate="$1"
    local output_file="$2"
    local canonical

    [ -n "$candidate" ] || return 0
    [ -d "$candidate/steamapps" ] || return 0
    canonical="$(canonical_directory "$candidate")" || return 0
    if ! grep -Fqx -- "$canonical" "$output_file" 2>/dev/null; then
        printf '%s\n' "$canonical" >> "$output_file"
    fi
}

discover_steam_libraries() {
    local output_file="$1"
    local candidate
    local steam_root
    local vdf
    local vdf_path

    : > "$output_file"
    for candidate in \
        "$HOME/.local/share/Steam" \
        "$HOME/.steam/steam" \
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
        append_steam_library_if_valid "$candidate" "$output_file"
    done

    # Steam 的 libraryfolders.vdf 记录了 SD 卡和其他自定义库。
    # 只接受当前真实存在且含 steamapps 的目录，避免把配置文字当成路径使用。
    while IFS= read -r steam_root; do
        [ -n "$steam_root" ] || continue
        vdf="$steam_root/steamapps/libraryfolders.vdf"
        [ -r "$vdf" ] || continue
        while IFS= read -r vdf_path; do
            case "$vdf_path" in
                /*) append_steam_library_if_valid "$vdf_path" "$output_file" ;;
            esac
        done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
    done < "$output_file"
}

choose_steam_library_root() {
    local requested="${LOSSLESS_STEAM_LIBRARY:-}"
    local libraries_file="$1"
    local count
    local selected
    local candidate
    local index
    local answer
    local -a menu_args

    if [ -n "$requested" ]; then
        [ -d "$requested/steamapps" ] || {
            echo "指定的 Steam 库无效：$requested"
            return 1
        }
        canonical_directory "$requested"
        return
    fi

    discover_steam_libraries "$libraries_file"
    count="$(wc -l < "$libraries_file" | tr -d '[:space:]')"
    [ "$count" -gt 0 ] || {
        echo "未找到 Steam 库，请先启动一次 Steam。"
        return 1
    }
    if [ "$count" -eq 1 ]; then
        sed -n '1p' "$libraries_file"
        return 0
    fi

    if command -v kdialog >/dev/null 2>&1; then
        menu_args=()
        index=0
        while IFS= read -r candidate; do
            index=$((index + 1))
            menu_args+=("$index" "$candidate")
        done < "$libraries_file"
        selected="$(kdialog --title "选择 Lossless Scaling 安装位置" \
            --menu "检测到多个 Steam 库，请选择要导入到哪一个库。" \
            "${menu_args[@]}" 2>/dev/null || true)"
        [ -n "$selected" ] || return 1
        sed -n "${selected}p" "$libraries_file"
        return 0
    fi

    if [ -t 0 ]; then
        echo "检测到多个 Steam 库：" >&2
        index=0
        while IFS= read -r candidate; do
            index=$((index + 1))
            printf '  %s. %s\n' "$index" "$candidate" >&2
        done < "$libraries_file"
        read -r -p "请选择安装位置 [1-$count]：" answer
        case "$answer" in
            *[!0-9]*|'') return 1 ;;
        esac
        [ "$answer" -ge 1 ] && [ "$answer" -le "$count" ] || return 1
        sed -n "${answer}p" "$libraries_file"
        return 0
    fi

    echo "检测到多个 Steam 库，无法在非交互模式中自动选择。" >&2
    echo "请设置 LOSSLESS_STEAM_LIBRARY=/你的/Steam库 后重试。" >&2
    return 1
}

lossless_archive_extension_is_supported() {
    case "$1" in
        *.zip|*.ZIP|*.tar|*.TAR|*.tar.gz|*.TAR.GZ|*.tgz|*.TGZ) return 0 ;;
        *)
            echo "仅支持可安全审计的 zip、tar、tar.gz 或 tgz 本地备份。"
            return 1
            ;;
    esac
}

lossless_limit_is_valid() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -gt 0 ] ;;
    esac
}

audit_lossless_archive() {
    local archive="$1"
    local audit_dir="$2"
    local names_file="$audit_dir/names.txt"
    local verbose_file="$audit_dir/verbose.txt"
    local stats
    local archive_size
    local max_members="${LOSSLESS_MAX_MEMBERS:-20000}"
    local max_total="${LOSSLESS_MAX_EXPANDED_BYTES:-8589934592}"
    local max_single="${LOSSLESS_MAX_SINGLE_FILE_BYTES:-4294967296}"
    local max_ratio="${LOSSLESS_MAX_COMPRESSION_RATIO:-2000}"
    local value

    for value in "$max_members" "$max_total" "$max_single" "$max_ratio"; do
        lossless_limit_is_valid "$value" || {
            echo "本地备份安全限制配置无效。"
            return 1
        }
    done

    # 使用同一个 libarchive/bsdtar 完成列表和解压，避免两套解析器理解不同。
    if ! LC_ALL=C bsdtar -tf "$archive" < /dev/null > "$names_file" 2>/dev/null || \
       ! LC_ALL=C bsdtar -tvf "$archive" < /dev/null > "$verbose_file" 2>/dev/null; then
        echo "本地备份无法读取，可能已损坏、加密或格式不受支持。"
        return 1
    fi
    [ -s "$names_file" ] || {
        echo "本地备份是空压缩包。"
        return 1
    }

    # bsdtar 会将文件名中的换行等控制字符显示成反斜杠转义；本流程完全拒绝
    # 反斜杠和其他控制符，从而不会把它们误当成普通路径。
    if LC_ALL=C grep -Eq '[[:cntrl:]\\]' "$names_file"; then
        echo "本地备份包含控制字符或反斜杠路径，已停止导入。"
        return 1
    fi
    while IFS= read -r value; do
        case "$value" in
            /*|[A-Za-z]:*|*\\*|*//*|.|./*|*/./*|*/.|..|../*|*/../*|*/..)
                echo "本地备份包含不安全路径，已停止导入。"
                return 1
                ;;
            Lossless\ Scaling|Lossless\ Scaling/*) ;;
            *)
                echo "本地备份包含 Lossless Scaling 目录以外的内容。"
                return 1
                ;;
        esac
        [ "${#value}" -le 1024 ] || {
            echo "本地备份包含过长路径，已停止导入。"
            return 1
        }
    done < "$names_file"
    if [ -n "$(LC_ALL=C sort "$names_file" | uniq -d)" ]; then
        echo "本地备份包含重复路径，已停止导入。"
        return 1
    fi
    if [ "$(grep -Fxc 'Lossless Scaling/LosslessScaling.exe' "$names_file")" -ne 1 ]; then
        echo "本地备份必须且只能包含一个 Lossless Scaling/LosslessScaling.exe。"
        return 1
    fi

    stats="$(awk -v max_members="$max_members" -v max_total="$max_total" -v max_single="$max_single" '
        {
            type=substr($1, 1, 1)
            if (type != "-" && type != "d") exit 20
            if ($5 !~ /^[0-9]+$/) exit 21
            count++
            if (type == "-") {
                size=$5 + 0
                if (size > max_single) exit 22
                total += size
                if (total > max_total) exit 23
            }
            if (count > max_members) exit 24
        }
        END {
            if (count > 0 && count <= max_members && total <= max_total)
                printf "%d %.0f\n", count, total
        }
    ' "$verbose_file")" || {
        echo "本地备份包含链接/特殊节点，或文件数量、大小超过安全限制。"
        return 1
    }
    [ -n "$stats" ] || {
        echo "本地备份成员信息不符合安全要求。"
        return 1
    }
    LOSSLESS_ARCHIVE_MEMBERS="${stats%% *}"
    LOSSLESS_ARCHIVE_BYTES="${stats#* }"

    archive_size="$(file_size_bytes "$archive")" || return 1
    [ "$archive_size" -gt 0 ] || {
        echo "本地备份文件大小异常。"
        return 1
    }
    if [ "$LOSSLESS_ARCHIVE_BYTES" -gt $((archive_size * max_ratio)) ]; then
        echo "本地备份压缩比异常，为避免压缩炸弹已停止导入。"
        return 1
    fi
}

sanitize_lossless_tree() {
    local root="$1"

    # 再检查实际落盘结果，拒绝解析器没有在列表阶段暴露的链接和特殊节点。
    if find "$root" ! -type f ! -type d -print -quit | grep -q .; then
        echo "本地备份解压后出现链接或特殊节点，已停止导入。"
        return 1
    fi
    if find "$root" -print | LC_ALL=C grep -Eq '[[:cntrl:]]'; then
        echo "本地备份解压后出现控制字符路径，已停止导入。"
        return 1
    fi
    find "$root" -type d -exec chmod 0755 {} + || return 1
    find "$root" -type f -exec chmod 0644 {} + || return 1
}

move_directory_without_clobber() {
    local source_dir="$1"
    local target_dir="$2"

    [ ! -e "$target_dir" ] && [ ! -L "$target_dir" ] || return 1
    if mv --help 2>&1 | grep -q -- '--no-target-directory'; then
        mv -nT -- "$source_dir" "$target_dir" || return 1
        [ ! -e "$source_dir" ] && [ ! -L "$source_dir" ]
    else
        # macOS 测试环境没有 -T；真实 SteamOS 使用上面的 GNU mv 安全分支。
        mv -- "$source_dir" "$target_dir"
    fi
}

import_lossless_backup() {
    local archive="$1"
    local source_size
    local free_bytes
    local required_bytes
    local extract_dir
    local game_source
    local steam_root
    local target_parent
    local target_dir
    local frozen_archive
    local libraries_file
    local margin="${LOSSLESS_FREE_SPACE_MARGIN_BYTES:-268435456}"
    local old_umask

    [ -f "$archive" ] || {
        echo "没有找到本地备份：$archive"
        return 1
    }
    lossless_archive_extension_is_supported "$archive" || return 1
    require_command bsdtar || return 1
    lossless_limit_is_valid "$margin" || return 1

    # 先发现库，再把压缩包冻结到目标盘的私有临时目录；之后所有审计与解压
    # 都只读取冻结副本，避免原文件在审计后被替换。
    libraries_file="$(mktemp)" || return 1
    steam_root="$(choose_steam_library_root "$libraries_file")" || {
        rm -f -- "$libraries_file"
        return 1
    }
    rm -f -- "$libraries_file"

    target_parent="$steam_root/steamapps/common"
    target_dir="$target_parent/Lossless Scaling"
    mkdir -p "$target_parent" || {
        return 1
    }
    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
        echo "Steam 库中已存在 Lossless Scaling，未覆盖任何文件。"
        echo "请在 Steam 中使用“验证游戏文件完整性”。"
        open_lossless_store
        return 0
    fi

    LOSSLESS_LOCK_DIR="$target_parent/.zhoukeer-lossless-import.lock"
    if ! mkdir -m 0700 -- "$LOSSLESS_LOCK_DIR" 2>/dev/null; then
        echo "已有另一个 Lossless Scaling 导入任务正在运行，请稍后再试。"
        return 1
    fi
    old_umask="$(umask)"
    umask 077
    LOSSLESS_WORK_DIR="$(mktemp -d "$target_parent/.zhoukeer-lossless.XXXXXX")" || {
        umask "$old_umask"
        cleanup_lossless_import
        return 1
    }
    umask "$old_umask"
    trap cleanup_lossless_import EXIT
    trap 'cleanup_lossless_import; exit 130' INT TERM

    source_size="$(file_size_bytes "$archive")" || return 1
    free_bytes="$(free_space_bytes "$target_parent")" || return 1
    required_bytes=$((source_size + margin))
    if [ "$free_bytes" -lt "$required_bytes" ]; then
        echo "Steam 库剩余空间不足，无法安全冻结并解压本地备份。"
        return 1
    fi
    frozen_archive="$LOSSLESS_WORK_DIR/archive"
    if ! cp -- "$archive" "$frozen_archive" || ! chmod 0600 "$frozen_archive"; then
        echo "无法在 Steam 库中创建本地备份的安全副本。"
        return 1
    fi
    audit_lossless_archive "$frozen_archive" "$LOSSLESS_WORK_DIR" || return 1
    free_bytes="$(free_space_bytes "$target_parent")" || return 1
    required_bytes=$((LOSSLESS_ARCHIVE_BYTES + margin))
    if [ "$free_bytes" -lt "$required_bytes" ]; then
        echo "Steam 库剩余空间不足；解压后约需 $LOSSLESS_ARCHIVE_BYTES 字节。"
        return 1
    fi

    extract_dir="$LOSSLESS_WORK_DIR/extracted"
    mkdir -m 0700 -- "$extract_dir" || return 1
    if ! bsdtar \
        --no-same-owner \
        --no-same-permissions \
        --no-acls \
        --no-xattrs \
        --no-fflags \
        -xf "$frozen_archive" \
        -C "$extract_dir" < /dev/null; then
        echo "本地备份解压失败；加密压缩包不会被导入。"
        return 1
    fi
    game_source="$extract_dir/Lossless Scaling"
    [ -d "$game_source" ] && [ ! -L "$game_source" ] && \
        [ -f "$game_source/LosslessScaling.exe" ] && \
        [ ! -L "$game_source/LosslessScaling.exe" ] || {
        echo "解压结果中没有唯一、有效的 Lossless Scaling 游戏目录。"
        return 1
    }
    sanitize_lossless_tree "$game_source" || return 1

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
        echo "导入期间目标目录已出现，已停止且未覆盖任何文件。"
        return 1
    fi
    if ! move_directory_without_clobber "$game_source" "$target_dir" || \
       [ ! -f "$target_dir/LosslessScaling.exe" ] || \
       [ -L "$target_dir/LosslessScaling.exe" ]; then
        echo "导入提交失败，未覆盖已有的 Steam 文件。"
        return 1
    fi

    echo "本地备份已导入：$target_dir"
    echo "已检查 $LOSSLESS_ARCHIVE_MEMBERS 个成员，解压大小 $LOSSLESS_ARCHIVE_BYTES 字节。"
    echo "接下来将由 Steam 检查正版授权并验证现有文件。"
    log "Lossless Scaling本地合法备份已导入"
    cleanup_lossless_import
    trap - EXIT INT TERM
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "steam://install/993090" >/dev/null 2>&1 &
    elif command -v steam >/dev/null 2>&1; then
        steam "steam://install/993090" >/dev/null 2>&1 &
    fi
}

select_and_import_lossless_backup() {
    local archive

    if command -v kdialog >/dev/null 2>&1; then
        archive="$(kdialog --title "选择 Lossless Scaling 本地合法备份" \
            --getopenfilename "$HOME" \
            "压缩包 (*.zip *.tar *.tar.gz *.tgz)" 2>/dev/null || true)"
        [ -n "$archive" ] || {
            echo "已取消选择本地备份。"
            return 0
        }
        import_lossless_backup "$archive"
    else
        echo "如需导入自己合法取得的本地备份，可执行："
        echo "bash modules/plugin_store.sh lsfg-import /本地/备份文件"
        return 1
    fi
}

install_lsfg_bundle() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local open_store_after="${1:-1}"
    local skip_existing="${2:-1}"
    local installed_version

    if [ "$skip_existing" = "1" ] && \
       ! feature_plugin_is_current "$plugin_root" "$LSFG_OFFICIAL_DIRECTORY" \
            "$LSFG_OFFICIAL_VERSION" "Decky LSFG-VK" "小黄鸭"; then
        if feature_plugin_is_present "$plugin_root" "$LSFG_OFFICIAL_DIRECTORY" \
            "Decky LSFG-VK" "小黄鸭"; then
            installed_version="$(decky_plugin_version "$plugin_root/$LSFG_OFFICIAL_DIRECTORY" || true)"
            echo "检测到小黄鸭旧版本 ${installed_version:-未知}，将更新到 $LSFG_OFFICIAL_VERSION。"
        fi
        skip_existing=0
    fi

    GITEE_MIRROR_REPO="$DECKY_LSFG_MIRROR_REPO" install_decky_zip \
        "小黄鸭（LSFG-VK）" \
        "${DECKY_LSFG_URL:-}" \
        "${DECKY_LSFG_SHA256:-}" \
        "$LSFG_OFFICIAL_DIRECTORY" \
        "$skip_existing" || return 1
    remove_legacy_lsfg_directories "$plugin_root"

    echo "汉化：RenAmamiya"
    if [ "$open_store_after" = "1" ]; then
        check_lossless_scaling_installation
    fi
}

install_lsfg_chinese() {
    install_lsfg_zh_from_gitee "${1:-1}"
}

apply_mako_zh_patch() {
    local dist_file="$1"
    local zh_json="${2:-$LSFG_MAKO_ZH_JSON}"
    local en_json="${3:-$LSFG_MAKO_ZH_EN_JSON}"
    local temporary

    [ -f "$dist_file" ] && [ ! -L "$dist_file" ] || {
        echo "MAKO 前端文件不存在，未应用汉化。"
        return 1
    }
    [ -f "$zh_json" ] && [ ! -L "$zh_json" ] || {
        echo "MAKO 汉化词条缺失，请更新Renkit后再试。"
        return 1
    }
    [ -f "$en_json" ] && [ ! -L "$en_json" ] || {
        echo "MAKO 英文替换表缺失，请更新Renkit后再试。"
        return 1
    }
    require_command python3 || return 1
    temporary="$(mktemp "${dist_file}.zh.XXXXXX" 2>/dev/null)" || return 1
    if ! python3 - "$dist_file" "$zh_json" "$en_json" "$temporary" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
json_path = Path(sys.argv[2])
en_path = Path(sys.argv[3])
output_path = Path(sys.argv[4])
translations = json.loads(json_path.read_text(encoding="utf-8"))
replacements = json.loads(en_path.read_text(encoding="utf-8"))
content = source_path.read_text(encoding="utf-8")

marker = "var languages = {\n\tja: ja,"
if "var zh = {" not in content:
    if marker not in content:
        raise SystemExit(2)
    zh_block = "var zh = " + json.dumps(translations, ensure_ascii=False, indent="\t") + ";\n"
    content = content.replace(marker, zh_block + "var languages = {\n\tzh: zh,\n\tja: ja,", 1)

language_marker = "const lang = normalizeLanguage(window.LocalizationManager.m_rgLocalesToUse[0]);"
if "const lang = \"zh\";" not in content:
    if language_marker not in content:
        raise SystemExit(2)
    content = content.replace(language_marker, 'const lang = "zh";', 1)

for english, chinese in replacements.items():
    content = content.replace(json.dumps(english, ensure_ascii=False), json.dumps(chinese, ensure_ascii=False))

attribution = "RenAmamiya汉化"
if attribution not in content:
    theme_marker = "window.SP_REACT.createElement(MakoButtonTheme, null),"
    if theme_marker not in content:
        raise SystemExit(2)
    pos = content.index(theme_marker)
    local_pos = content.index("localDevelopmentBuildInfo", pos)
    attribution_row = (
        "window.SP_REACT.createElement(DFL.PanelSectionRow, null,"
        ' window.SP_REACT.createElement("div", { style: { padding: "8px 12px", width: "100%",'
        ' boxSizing: "border-box", textAlign: "center", fontSize: "13px", color: "#ffcc66" } },'
        ' "RenAmamiya汉化")),\n            '
    )
    content = content[:local_pos] + attribution_row + content[local_pos:]

if "var zh =" not in content or attribution not in content:
    raise SystemExit(2)
output_path.write_text(content, encoding="utf-8")
PY
    then
        rm -f -- "$temporary"
        echo "MAKO 汉化补丁失败，原前端未改动。"
        return 1
    fi
    chmod 0644 "$temporary" || {
        rm -f -- "$temporary"
        return 1
    }
    if ! run_plugin_file_operation cp -- "$temporary" "$dist_file"; then
        rm -f -- "$temporary"
        echo "MAKO 汉化前端写入失败，原前端未改动。"
        return 1
    fi
    rm -f -- "$temporary"
    echo "MAKO 小黄鸭中文界面已写入，顶部署名已保留。"
}

# 署名完整包只从 Gitee mirror-3 下载；镜像失败时保留现有插件并返回失败。
install_lsfg_zh_from_gitee() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local reload_after="${1:-1}"
    local installed_version actual_sha256

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "小黄鸭仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$LSFG_OFFICIAL_DIRECTORY/dist/index.js" 2>/dev/null || true)"
    if feature_plugin_is_current "$plugin_root" "$LSFG_OFFICIAL_DIRECTORY" \
        "$LSFG_OFFICIAL_VERSION" "小黄鸭" && \
        [ "$actual_sha256" = "$LSFG_ZH_INDEX_SHA256" ]; then
        echo "[已安装] 小黄鸭 v$LSFG_OFFICIAL_VERSION 中文插件已存在且文件完整，无需重复安装。"
        return 0
    fi
    if feature_plugin_is_present "$plugin_root" "$LSFG_OFFICIAL_DIRECTORY" \
        "Decky LSFG-VK" "小黄鸭"; then
        installed_version="$(decky_plugin_version "$plugin_root/$LSFG_OFFICIAL_DIRECTORY" || true)"
        echo "检测到现有小黄鸭版本 ${installed_version:-未知}，正在更新中文插件到 ${LSFG_OFFICIAL_VERSION}。"
    fi

    echo "正在安装小黄鸭..."
    GITEE_MIRROR_REPO="$DECKY_LSFG_MIRROR_REPO" \
        install_decky_zip_from_mirror "小黄鸭（LSFG-VK）" \
        "$LSFG_ZH_MIRROR_ID" "$LSFG_ZH_PACKAGE_SHA256" \
        "$LSFG_OFFICIAL_DIRECTORY" || {
            echo "小黄鸭署名包的 Gitee 分块镜像不可用，已保留现有插件。"
            return 1
        }
    remove_legacy_lsfg_directories "$plugin_root"
    echo "小黄鸭安装成功。"
    echo "汉化：RenAmamiya"
    if [ "$reload_after" = "1" ]; then
        reload_decky_plugins "Decky 已重新加载；返回游戏模式打开小黄鸭即可使用。"
    fi
    log "小黄鸭 v$LSFG_OFFICIAL_VERSION 汉化完整包安装完成"
}

install_fsr4_chinese() {
    install_fsr4_zh_from_gitee "${1:-1}"
}

# 署名完整包只从 Gitee mirror-3 下载；镜像失败时保留现有插件并返回失败。
install_fsr4_zh_from_gitee() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local reload_after="${1:-1}"
    local installed_version actual_sha256

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "FSR4 中文界面仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$FSR4_OFFICIAL_DIRECTORY/dist/index.js" 2>/dev/null || true)"
    if feature_plugin_is_current "$plugin_root" "$FSR4_OFFICIAL_DIRECTORY" \
        "$FSR4_OFFICIAL_VERSION" "Decky-Framegen（FSR4）" && \
        [ "$actual_sha256" = "$FSR4_ZH_INDEX_SHA256" ]; then
        echo "[已安装] FSR4 v$FSR4_OFFICIAL_VERSION 中文插件已存在且文件完整，无需重复安装。"
        return 0
    fi
    if feature_plugin_is_present "$plugin_root" "$FSR4_OFFICIAL_DIRECTORY" \
        "Decky-Framegen" "FSR4" "Decky-Framegen(FSR4)" "Decky-Framegen（FSR4）"; then
        installed_version="$(decky_plugin_version "$plugin_root/$FSR4_OFFICIAL_DIRECTORY" || true)"
        echo "检测到现有 FSR4 版本 ${installed_version:-未知}，正在更新中文插件到 ${FSR4_OFFICIAL_VERSION}。"
    fi

    echo "正在安装 FSR4..."
    GITEE_MIRROR_REPO="zhoukeer-toolbox-mirror-3" \
        install_decky_zip_from_mirror "FSR4（Decky Framegen）" \
        "$FSR4_ZH_MIRROR_ID" "$FSR4_ZH_PACKAGE_SHA256" \
        "$FSR4_OFFICIAL_DIRECTORY" || {
            echo "FSR4 署名包的 Gitee 分块镜像不可用，已保留现有插件。"
            return 1
        }
    echo "FSR4 安装成功。"
    echo "汉化：RenAmamiya"
    if [ "$reload_after" = "1" ]; then
        reload_decky_plugins "Decky 已重新加载；返回游戏模式打开 FSR4 插帧即可看到中文界面。"
    fi
    log "FSR4 v$FSR4_OFFICIAL_VERSION 汉化完整包安装完成"
}

simpledeckytdp_chinese_is_current() {
    local plugin_root="$1"
    local actual_sha256

    feature_plugin_is_current "$plugin_root" "$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY" \
        "$SIMPLEDECKYTDP_OFFICIAL_VERSION" "掌机功耗控制" || return 1
    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY/dist/index.js" 2>/dev/null || true)"
    [ "$actual_sha256" = "$SIMPLEDECKYTDP_ZH_INDEX_SHA256" ]
}

install_simpledeckytdp_chinese() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local actual_sha256
    local bundled_version
    local reload_after="${1:-1}"
    local official_bin_dir
    local work_dir
    local staged_source

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "SimpleDeckyTDP 中文界面仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    if simpledeckytdp_chinese_is_current "$plugin_root"; then
        echo "[已安装] SimpleDeckyTDP v$SIMPLEDECKYTDP_OFFICIAL_VERSION 中文插件已存在且文件完整，无需重复安装。"
        return 0
    fi
    if [ -L "$SIMPLEDECKYTDP_ZH_SOURCE_DIR" ] || \
       [ ! -f "$SIMPLEDECKYTDP_ZH_SOURCE_DIR/plugin.json" ] || \
       [ ! -f "$SIMPLEDECKYTDP_ZH_SOURCE_DIR/package.json" ] || \
       [ ! -s "$SIMPLEDECKYTDP_ZH_SOURCE_DIR/dist/index.js" ] || \
       [ ! -f "$SIMPLEDECKYTDP_ZH_SOURCE_DIR/LICENSE" ]; then
        echo "SimpleDeckyTDP v$SIMPLEDECKYTDP_OFFICIAL_VERSION 中文组件不完整，请更新Renkit后再试。"
        return 1
    fi
    bundled_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$SIMPLEDECKYTDP_ZH_SOURCE_DIR/package.json" | head -n 1)"
    if [ "$bundled_version" != "$SIMPLEDECKYTDP_OFFICIAL_VERSION" ]; then
        echo "SimpleDeckyTDP 中文组件版本 $bundled_version 与目标 v$SIMPLEDECKYTDP_OFFICIAL_VERSION 不一致，已停止覆盖。"
        return 1
    fi
    actual_sha256="$(calculate_decky_sha256 "$SIMPLEDECKYTDP_ZH_SOURCE_DIR/dist/index.js")" || return 1
    if [ "$actual_sha256" != "$SIMPLEDECKYTDP_ZH_INDEX_SHA256" ]; then
        echo "SimpleDeckyTDP 中文组件校验失败，已停止覆盖。"
        return 1
    fi
    official_bin_dir="$plugin_root/$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY/bin"
    if [ ! -s "$official_bin_dir/ryzenadj" ] || \
       [ ! -s "$official_bin_dir/libryzenadj.so" ] || \
       [ ! -f "$official_bin_dir/LICENSE-ryzenadj" ]; then
        echo "SimpleDeckyTDP 运行核心缺失，请先安装官方插件再覆盖中文界面。"
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1
    work_dir="$(mktemp -d)" || return 1
    staged_source="$work_dir/$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY"
    if ! cp -a -- "$SIMPLEDECKYTDP_ZH_SOURCE_DIR" "$staged_source" || \
       ! cp -a -- "$official_bin_dir" "$staged_source/bin"; then
        rm -rf -- "$work_dir"
        echo "SimpleDeckyTDP 中文组件准备失败，原版未改动。"
        return 1
    fi
    install_tree_atomically "$staged_source" "$plugin_root" "$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY" || {
        rm -rf -- "$work_dir"
        echo "SimpleDeckyTDP 中文界面安装失败，已尽量保留原版。"
        return 1
    }
    rm -rf -- "$work_dir"
    echo "SimpleDeckyTDP v$SIMPLEDECKYTDP_OFFICIAL_VERSION 中文界面已安装（RenAmamiya汉化）。"
    echo "汉化作者：RenAmamiya，感谢支持！"
    echo "原作者：Aarron Lee；许可证：BSD 3-Clause。"
    if [ "$reload_after" = "1" ]; then
        reload_decky_plugins "Decky 已重新加载；返回游戏模式打开 SimpleDeckyTDP 即可看到中文界面。"
    fi
    log "SimpleDeckyTDP v$SIMPLEDECKYTDP_OFFICIAL_VERSION 中文界面安装完成"
}

# 优先使用 Gitee 国内源，失败后回退 GitHub Release，最后回退原版叠加。
install_simpledeckytdp_zh_from_gitee() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local reload_after="${1:-1}"
    local installed_version

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "SimpleDeckyTDP 中文版仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    if simpledeckytdp_chinese_is_current "$plugin_root"; then
        echo "[已安装] SimpleDeckyTDP v$SIMPLEDECKYTDP_OFFICIAL_VERSION 中文插件已存在且文件完整，无需重复安装。"
        return 0
    fi
    if feature_plugin_is_present "$plugin_root" "$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY" \
        "掌机功耗控制" "SimpleDeckyTDP"; then
        installed_version="$(decky_plugin_version "$plugin_root/$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY" || true)"
        echo "检测到现有 SimpleDeckyTDP 版本 ${installed_version:-未知}，正在更新中文插件到 $SIMPLEDECKYTDP_OFFICIAL_VERSION。"
    fi

    echo "正在安装 SimpleDeckyTDP 中文版..."
    if install_decky_zip_from_mirror \
        "SimpleDeckyTDP" \
        "simpledeckytdp" \
        "${DECKY_SIMPLE_TDP_SHA256:-}" \
        "$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY"; then
        install_simpledeckytdp_chinese "$reload_after" || return 1
    else
        cleanup_decky_tmp
        trap - EXIT INT TERM
        log "SimpleDeckyTDP Gitee 镜像不可用，切换 GitHub Release"
        install_configured_plugin simpledeckytdp 0 0 || return 1
        install_simpledeckytdp_chinese "$reload_after"
        return $?
    fi
    echo "SimpleDeckyTDP 安装成功。"
    echo "汉化作者：RenAmamiya，感谢支持！"
    if [ "$reload_after" = "1" ]; then
        reload_decky_plugins "Decky 已重新加载；返回游戏模式打开 SimpleDeckyTDP 即可看到中文界面。"
    fi
    log "SimpleDeckyTDP v$SIMPLEDECKYTDP_OFFICIAL_VERSION 中文版安装完成"
}

ensure_simpledeckytdp_chinese_current() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local installed_version=""

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "掌机功耗控制版本检测仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    if simpledeckytdp_chinese_is_current "$plugin_root"; then
        echo "[已检测] 掌机功耗控制已是最新汉化版 v$SIMPLEDECKYTDP_OFFICIAL_VERSION，无需处理。"
        return 0
    fi
    if [ -d "$plugin_root/$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY" ]; then
        installed_version="$(decky_plugin_version "$plugin_root/$SIMPLEDECKYTDP_OFFICIAL_DIRECTORY" || true)"
        echo "检测到现有 SimpleDeckyTDP 版本 ${installed_version:-未知}，不是最新汉化版，将替换为“掌机功耗控制”汉化版。"
    else
        echo "未检测到 SimpleDeckyTDP，正在安装“掌机功耗控制”汉化版。"
    fi
    install_simpledeckytdp_zh_from_gitee
}

allycenter_chinese_is_current() {
    local plugin_root="$1"
    local actual_sha256

    feature_plugin_is_current "$plugin_root" "Ally Center" \
        "$DECKY_ALLYCENTER_VERSION" "Ally 控制中心" || return 1
    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/Ally Center/dist/index.js" 2>/dev/null || true)"
    [ "$actual_sha256" = "$ALLYCENTER_ZH_INDEX_SHA256" ]
}

install_allycenter_chinese() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local reload_after="${1:-1}"
    local bundled_version actual_sha256 official_source work_dir staged_source

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "Ally Center 中文版仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    if allycenter_chinese_is_current "$plugin_root"; then
        echo "[已安装] Ally Center v$DECKY_ALLYCENTER_VERSION 中文版已存在且文件完整，无需重复安装。"
        return 0
    fi
    if [ -L "$ALLYCENTER_ZH_SOURCE_DIR" ] || \
       [ ! -f "$ALLYCENTER_ZH_SOURCE_DIR/plugin.json" ] || \
       [ ! -f "$ALLYCENTER_ZH_SOURCE_DIR/package.json" ] || \
       [ ! -s "$ALLYCENTER_ZH_SOURCE_DIR/dist/index.js" ] || \
       [ ! -f "$ALLYCENTER_ZH_SOURCE_DIR/LICENSE" ]; then
        echo "Ally Center v$DECKY_ALLYCENTER_VERSION 中文组件不完整，请更新Renkit后再试。"
        return 1
    fi
    bundled_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$ALLYCENTER_ZH_SOURCE_DIR/package.json" | head -n 1)"
    if [ "$bundled_version" != "$DECKY_ALLYCENTER_VERSION" ]; then
        echo "Ally Center 中文组件版本 $bundled_version 与目标 v$DECKY_ALLYCENTER_VERSION 不一致，已停止覆盖。"
        return 1
    fi
    actual_sha256="$(calculate_decky_sha256 "$ALLYCENTER_ZH_SOURCE_DIR/dist/index.js")" || return 1
    if [ "$actual_sha256" != "$ALLYCENTER_ZH_INDEX_SHA256" ]; then
        echo "Ally Center 中文组件校验失败，已停止覆盖。"
        return 1
    fi
    official_source="$plugin_root/Ally Center"
    if [ ! -f "$official_source/main.py" ] || \
       [ ! -f "$official_source/plugin.json" ] || \
       [ ! -f "$official_source/package.json" ]; then
        echo "Ally Center 官方后端不完整，请重新安装后再试。"
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1
    work_dir="$(mktemp -d)" || return 1
    staged_source="$work_dir/Ally Center"
    if ! cp -a -- "$official_source" "$staged_source" || \
       ! rm -rf -- "$staged_source/dist" || \
       ! mkdir -p "$staged_source/dist" || \
       ! cp -a -- "$ALLYCENTER_ZH_SOURCE_DIR/dist/index.js" "$staged_source/dist/index.js" || \
       ! cp -a -- "$ALLYCENTER_ZH_SOURCE_DIR/plugin.json" "$staged_source/plugin.json"; then
        rm -rf -- "$work_dir"
        echo "Ally Center 中文组件准备失败，原版未改动。"
        return 1
    fi
    install_tree_atomically "$staged_source" "$plugin_root" "Ally Center" || {
        rm -rf -- "$work_dir"
        echo "Ally Center 中文版安装失败，已尽量保留原版。"
        return 1
    }
    rm -rf -- "$work_dir"
    echo "Ally Center v$DECKY_ALLYCENTER_VERSION 中文版已安装。"
    echo "汉化作者：RenAmamiya，感谢支持！"
    echo "原作者：Keith Baker（Pixel Addict Games）；许可证：MIT。"
    if [ "$reload_after" = "1" ]; then
        reload_decky_plugins "Decky 已重新加载；返回游戏模式打开 Ally Center 即可看到中文界面。"
    fi
    log "Ally Center v$DECKY_ALLYCENTER_VERSION 中文版安装完成"
}

# 与其他插件一致：先从 Gitee 固定镜像下载作者原包，失败后自动回退 GitHub，
# 校验通过并完成原子安装后，再覆盖 Renkit 内置的同版本中文前端。
ensure_allycenter_chinese_current() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local installed_version=""

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "Ally Center 中文版仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    # 新机流程中若前一步 Decky 尚未完成，先补装 Loader 和插件目录，
    # 避免硬件配置步骤只报告 homebrew/plugins 不存在。
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        ensure_plugin_store_ready || {
            echo "Decky Loader 未安装完成，Ally Center 暂未开始安装。"
            return 1
        }
    fi
    if allycenter_chinese_is_current "$plugin_root"; then
        echo "[已检测] Ally Center 已是最新汉化版 v${DECKY_ALLYCENTER_VERSION}，无需处理。"
        return 0
    fi
    if [ -d "$plugin_root/Ally Center" ]; then
        installed_version="$(decky_plugin_version "$plugin_root/Ally Center" || true)"
        echo "检测到现有 Ally Center 版本 ${installed_version:-未知}，将替换为 v$DECKY_ALLYCENTER_VERSION 汉化版。"
    else
        echo "未检测到 Ally Center，正在安装 v$DECKY_ALLYCENTER_VERSION 汉化版。"
    fi
    GITEE_MIRROR_REPO="$DECKY_ALLYCENTER_MIRROR_REPO" \
        install_decky_zip \
        "Ally Center（ROG Ally / Ally X 控制中心）" \
        "$DECKY_ALLYCENTER_URL" \
        "$DECKY_ALLYCENTER_SHA256" \
        "Ally Center" \
        0 || return 1
    install_allycenter_chinese
}

handheld_overlay_is_current() {
    local plugin_root="$1"
    local directory_name="$2"
    local expected_version="$3"
    local display_name="$4"
    local expected_sha256="$5"
    local actual_sha256

    feature_plugin_is_current "$plugin_root" "$directory_name" \
        "$expected_version" "$display_name" || return 1
    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$directory_name/dist/index.js" 2>/dev/null || true)"
    [ "$actual_sha256" = "$expected_sha256" ]
}

# 保留作者官方插件的完整后端和驱动文件，仅原子替换同版本的清单与已构建前端。
install_handheld_frontend_overlay() {
    local directory_name="$1"
    local expected_version="$2"
    local display_name="$3"
    local overlay_source="$4"
    local expected_sha256="$5"
    local author_line="$6"
    local translated="${7:-1}"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local official_source="$plugin_root/$directory_name"
    local bundled_version actual_sha256 work_dir staged_source

    if handheld_overlay_is_current "$plugin_root" "$directory_name" \
        "$expected_version" "$display_name" "$expected_sha256"; then
        echo "[已安装] $display_name v$expected_version 已存在且文件完整，无需重复安装。"
        return 0
    fi
    if [ -L "$overlay_source" ] || \
       [ ! -f "$overlay_source/plugin.json" ] || \
       [ ! -f "$overlay_source/package.json" ] || \
       [ ! -s "$overlay_source/dist/index.js" ] || \
       [ ! -f "$overlay_source/LICENSE" ]; then
        echo "$display_name v$expected_version 中文组件不完整，请更新Renkit后再试。"
        return 1
    fi
    bundled_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$overlay_source/package.json" | head -n 1)"
    if [ "$bundled_version" != "$expected_version" ]; then
        echo "$display_name 中文组件版本 $bundled_version 与目标 v$expected_version 不一致，已停止覆盖。"
        return 1
    fi
    actual_sha256="$(calculate_decky_sha256 "$overlay_source/dist/index.js")" || return 1
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "$display_name 中文组件校验失败，已停止覆盖。"
        return 1
    fi
    if [ ! -f "$official_source/main.py" ] || \
       [ ! -f "$official_source/plugin.json" ] || \
       [ ! -f "$official_source/package.json" ]; then
        echo "$display_name 官方后端不完整，请重新安装后再试。"
        return 1
    fi

    prepare_plugin_root "$plugin_root" || return 1
    work_dir="$(mktemp -d)" || return 1
    staged_source="$work_dir/$directory_name"
    if ! cp -a -- "$official_source" "$staged_source" || \
       ! rm -rf -- "$staged_source/dist" || \
       ! mkdir -p "$staged_source/dist" || \
       ! cp -a -- "$overlay_source/dist/index.js" "$staged_source/dist/index.js" || \
       ! cp -a -- "$overlay_source/plugin.json" "$staged_source/plugin.json"; then
        rm -rf -- "$work_dir"
        echo "$display_name 中文组件准备失败，原版未改动。"
        return 1
    fi
    install_tree_atomically "$staged_source" "$plugin_root" "$directory_name" || {
        rm -rf -- "$work_dir"
        echo "$display_name 中文界面安装失败，已尽量保留原版。"
        return 1
    }
    rm -rf -- "$work_dir"
    echo "$display_name v$expected_version 已安装。"
    if [ "$translated" = "1" ]; then
        echo "汉化作者：RenAmamiya，感谢支持！"
    else
        echo "该插件由上游自带简体中文；Renkit 仅适配中文显示名。"
    fi
    echo "$author_line"
    reload_decky_plugins "Decky 已重新加载；返回游戏模式即可打开 ${display_name}。"
    log "$display_name v$expected_version 安装完成"
}

ensure_handheld_overlay_current() {
    local archive_type="$1"
    local directory_name="$2"
    local expected_version="$3"
    local display_name="$4"
    local url="$5"
    local archive_sha256="$6"
    local overlay_source="$7"
    local overlay_sha256="$8"
    local author_line="$9"
    local translated="${10:-1}"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "$display_name 仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    if handheld_overlay_is_current "$plugin_root" "$directory_name" \
        "$expected_version" "$display_name" "$overlay_sha256"; then
        echo "[已检测] $display_name 已是完整的 v$expected_version，无需处理。"
        return 0
    fi

    echo "正在安装 $display_name..."
    if [ "$archive_type" = "tar.gz" ]; then
        GITEE_MIRROR_REPO="$DECKY_HANDHELD_PLUGIN_MIRROR_REPO" \
            install_decky_tar_gz "$display_name" "$url" "$archive_sha256" "$directory_name" 0 || return 1
    else
        GITEE_MIRROR_REPO="$DECKY_HANDHELD_PLUGIN_MIRROR_REPO" \
            install_decky_zip "$display_name" "$url" "$archive_sha256" "$directory_name" 0 || return 1
    fi
    install_handheld_frontend_overlay "$directory_name" "$expected_version" \
        "$display_name" "$overlay_source" "$overlay_sha256" "$author_line" "$translated"
}

restore_lsfg_official() {
    echo "Renkit 只提供带 RenAmamiya 署名的 Gitee 分块版本。"
    install_lsfg_zh_from_gitee 1
}

remove_legacy_lsfg_directories() {
    local plugin_root="$1"
    local legacy_name
    local legacy_dir
    local manifest_name
    local removed=0

    # 旧Renkit曾把同一插件安装在中文或仓库名目录。Decky 会把它们当成
    # 独立插件继续加载，导致界面仍显示旧版本；只删除名称和清单都能确认的旧副本。
    for legacy_name in "小黄鸭" "LSFG-VK" "decky-lsfg-vk" "Decky.LSFG-VK"; do
        legacy_dir="$plugin_root/$legacy_name"
        [ -e "$legacy_dir" ] || [ -L "$legacy_dir" ] || continue
        if [ -L "$legacy_dir" ]; then
            echo "发现旧小黄鸭符号链接，未自动删除：$legacy_dir"
            continue
        fi
        [ -d "$legacy_dir" ] && [ -f "$legacy_dir/plugin.json" ] || continue
        manifest_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$legacy_dir/plugin.json" | head -n 1)"
        case "$manifest_name" in
            "Decky LSFG-VK"|"LSFG-VK"|"小黄鸭") ;;
            *) continue ;;
        esac
        run_plugin_file_operation rm -rf -- "$legacy_dir" || {
            echo "旧小黄鸭目录未能清理：$legacy_dir"
            continue
        }
        removed=$((removed + 1))
    done
    if [ "$removed" -gt 0 ]; then
        echo "已清理 $removed 个旧小黄鸭目录，只保留官方 $LSFG_OFFICIAL_DIRECTORY。"
    fi
}

check_lossless_scaling_installation() {
    local libraries_file
    local steam_root
    local game_dir

    libraries_file="$(mktemp)" || return 1
    discover_steam_libraries "$libraries_file"
    while IFS= read -r steam_root; do
        [ -n "$steam_root" ] || continue
        game_dir="$steam_root/steamapps/common/Lossless Scaling"
        if [ -d "$game_dir" ] && [ -f "$game_dir/LosslessScaling.exe" ]; then
            rm -f -- "$libraries_file"
            echo "已检测到 Steam 库中的 Lossless Scaling。"
            echo "小黄鸭插件已安装，可以返回游戏模式继续使用。"
            print_lossless_linux_branch_tip
            log "小黄鸭安装后检测到 Lossless Scaling: $game_dir"
            return 0
        fi
    done < "$libraries_file"
    rm -f -- "$libraries_file"

    echo "未检测到 Steam 库中的 Lossless Scaling。"
    echo "将为你打开 Steam 正版页面；完成购买和安装后即可配合插件使用。"
    print_lossless_linux_branch_tip
    open_lossless_store
}

print_lossless_linux_branch_tip() {
    echo ""
    echo "使用提示：安装完成后，请在 Steam 正版页面打开游戏右侧齿轮。"
    echo "进入“属性” → “测试版”，选择名称以 Linux 开头的可用版本。"
    echo "随后进入游戏模式：按 Steam Deck 机身右下角“三个点（…）”按钮。"
    echo "在打开的菜单中依次点击：插头图标 → 小黄鸭 → 安装 LSFG。"
}

feature_guide_desktop_dir() {
    local desktop_dir="${ZHOUKEER_DESKTOP_DIR:-}"

    if [ -z "$desktop_dir" ] && command -v xdg-user-dir >/dev/null 2>&1; then
        desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    fi
    [ -n "$desktop_dir" ] || desktop_dir="$HOME/Desktop"
    case "$desktop_dir/" in
        "$HOME/"*) ;;
        *) echo "桌面目录不在当前用户主目录内，未创建教程：$desktop_dir" >&2; return 1 ;;
    esac
    if [ -L "$desktop_dir" ]; then
        echo "桌面目录是符号链接，未自动写入教程：$desktop_dir" >&2
        return 1
    fi
    mkdir -p -- "$desktop_dir" || return 1
    printf '%s\n' "$desktop_dir"
}

prepare_managed_guide_target() {
    local target="$1"

    if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
        echo "教程目标不是普通文件，未覆盖：$target" >&2
        return 1
    fi
    if [ -f "$target" ] && ! grep -Fq '由Renkit管理' "$target"; then
        echo "发现同名的用户文件，未覆盖：$target" >&2
        return 1
    fi
}

create_feature_usage_guide() {
    local desktop_dir target temporary

    desktop_dir="$(feature_guide_desktop_dir)" || return 1
    target="$desktop_dir/风灵月影，小黄鸭，FSR4使用教程.txt"
    prepare_managed_guide_target "$target" || return 1
    temporary="$(mktemp "$desktop_dir/.zhoukeer-feature-guide.XXXXXX")" || return 1
    if ! cat > "$temporary" <<'EOF'
由Renkit管理
风灵月影、小黄鸭、FSR4 使用教程

【先看这句】FSR/FSR4 不适合所有游戏。只在明确支持的游戏中尝试；出现黑屏、闪退、花屏、画面变差或帧数下降时，立即关闭并恢复原设置。联网和竞技游戏还可能有反作弊风险，不要使用修改器或第三方注入功能。

一、用 CheatDeck 添加风灵月影修改器
1. 从可信来源下载与游戏版本完全对应的修改器 EXE，只建议在单机、离线游戏中使用。
2. 把修改器放进名称简单、不会移动的文件夹，文件夹和文件名不要包含引号、斜杠等特殊字符。
3. 回到 Steam 游戏模式，在目标游戏页面点击齿轮，选择 CheatDeck。
4. 在“常规”页打开“启用修改器”，点击“选择修改器”，找到修改器 EXE。
5. 点击“保存”，再启动游戏。修改器窗口没有出现时，按 Steam 键查看并切换到另一个窗口。
6. 仍打不开时，确认 Steam 已开启开发者模式、游戏使用 Windows/Proton 版本；可尝试窗口化。缺少 .NET 或 VC++ 的修改器可能还需要 Protontricks 补运行库。

视频参考：
《SteamDeck用最简单的方法开启风灵月影修改器》
https://www.bilibili.com/video/BV1ew411J7ab?vd_source=f3a5ba0de4c855bec0e80711bad63217
请从 35 秒开始看。感谢作者“败家君的游戏屋”的演示与分享。

二、按录屏给当前游戏添加小黄鸭（LSFG-VK）
1. 先确认 Steam 正版 Lossless Scaling 已安装，并在“属性 → 测试版”中选择名称以 Linux 开头的版本。
2. 先进入游戏模式右侧的 Decky 插头菜单，打开“小黄鸭”，完成 LSFG 安装。
3. 回到目标游戏页面，点击齿轮 → CheatDeck → “高级”。
4. 找到“LSFG-VK”开关并打开，其他看不懂的高级选项保持原样。
5. 点击页面底部“保存”，再启动游戏测试。异常时关闭 LSFG-VK 并恢复原设置。

三、按录屏给当前游戏添加 FSR4（OptiScaler）
1. 先安装 FSR4/Decky-Framegen，并确认目标游戏位于桌面的《FSR4支持游戏名单》中。
2. 在目标游戏页面点击齿轮 → CheatDeck → “高级”。
3. 找到“OptiScaler”开关并打开，这就是录屏中添加 FSR4 的位置。
4. 点击页面底部“保存”，再启动游戏测试；一次只改一个功能，方便出现问题时恢复。
5. 不要因为列表里有开关就默认游戏一定适用。FSR/FSR4 不适合所有游戏，名单也可能随插件和游戏更新发生变化。
EOF
    then
        rm -f -- "$temporary"
        return 1
    fi
    chmod 600 "$temporary" || { rm -f -- "$temporary"; return 1; }
    mv -f -- "$temporary" "$target" || { rm -f -- "$temporary"; return 1; }
    echo "已在桌面更新《风灵月影，小黄鸭，FSR4使用教程.txt》。"
}

create_fsr4_supported_games_guide() {
    local desktop_dir target temporary tested_games

    desktop_dir="$(feature_guide_desktop_dir)" || return 1
    target="$desktop_dir/FSR4支持游戏名单.txt"
    tested_games="$PROJECT_ROOT/data/fsr4_optiscaler_tested_games_2026-08-07.txt"
    if [ ! -f "$tested_games" ] || \
       [ "$(grep -vc '^#' "$tested_games" 2>/dev/null || true)" -ne 683 ]; then
        echo "FSR4 官方兼容游戏清单缺失或条目数异常，请先更新Renkit。"
        return 1
    fi
    prepare_managed_guide_target "$target" || return 1
    temporary="$(mktemp "$desktop_dir/.zhoukeer-fsr4-guide.XXXXXX")" || return 1
    if ! cat > "$temporary" <<'EOF'
由Renkit管理
FSR4 / OptiScaler 官方兼容游戏清单

资料来源：OptiScaler 官方 Wiki
兼容表：https://github.com/optiscaler/OptiScaler/wiki/Compatibility-List
FSR4 与 Linux 说明：https://github.com/optiscaler/OptiScaler/wiki/FSR4-Compatibility-List
资料日期：2026-08-07

【结论】上游统计为 685 个可工作条目（其中 2 个仅单一操作系统可用）；按游戏名去重并按既有要求排除《怪物猎人：荒野》后，下方列出 683 款。
这不是全部理论支持范围。OptiScaler 官方说明，多数带 DLSS 2+、FSR 2+ 或 XeSS 的游戏都可能兼容；下方只列社区已经测试并标记可工作的项目。

【Steam Deck / SteamOS 必看】
1. 官方 FSR4 当前只正式支持 RDNA3/RDNA4；Steam Deck 是 RDNA2，Renkit 提供的是社区验证的 Valve/RDNA2 兼容路径，不等于 AMD 官方支持。
2. Linux 使用 FSR 4.1.1 需要包含新版 VKD3D 的较新 Proton；FSR4 帧生成还要求 Mesa 25.2+，并可能需要把单个游戏的 Proton 前缀设为 Windows 11。
3. FSR4 官方仍不支持 Vulkan 或 DX11；相关游戏可能通过社区转换层运行，稳定性不能按原生 DX12 理解。
4. 不要在带反作弊的联网/竞技模式注入。上游明确列为不可用：EA Sports WRC、Gears of War: Reloaded；Atlas Fallen: Reign of Sand 也无法挂接输入。
5. Minecraft RTX 仅 Windows 可用；Wolfenstein: Youngblood 是仅 Linux 路径可用的特殊项。
6. 出现黑屏、闪退、花屏、画质下降或帧数下降，立即撤销修补；每款游戏的代理 DLL、输入方式和特殊参数请查上方官方兼容表。

添加方法：目标游戏页面 → 齿轮 → CheatDeck → 高级 → 打开 OptiScaler → 保存。
再次提醒：FSR/FSR4 不适合所有游戏，名单也不代表每台设备、每个游戏版本都一定正常。

====== 官方 Wiki 已测试可工作的游戏（排除指定游戏后 683 款）======
EOF
    then
        rm -f -- "$temporary"
        return 1
    fi
    if ! grep -v '^#' "$tested_games" >> "$temporary"; then
        rm -f -- "$temporary"
        return 1
    fi
    chmod 600 "$temporary" || { rm -f -- "$temporary"; return 1; }
    mv -f -- "$temporary" "$target" || { rm -f -- "$temporary"; return 1; }
    echo "已在桌面更新《FSR4支持游戏名单.txt》。"
}

refresh_feature_usage_guides() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local any_installed=0
    local fsr4_installed=0

    feature_plugin_is_present "$plugin_root" "$LSFG_OFFICIAL_DIRECTORY" "Decky LSFG-VK" "小黄鸭" && any_installed=1
    if feature_plugin_is_present "$plugin_root" "Decky-Framegen" "Decky-Framegen" "FSR4" "Decky-Framegen(FSR4)" "Decky-Framegen（FSR4）"; then
        any_installed=1
        fsr4_installed=1
    fi
    feature_plugin_is_present "$plugin_root" "CheatDeck" "CheatDeck" && any_installed=1
    [ "$any_installed" -eq 0 ] || create_feature_usage_guide
    [ "$fsr4_installed" -eq 0 ] || create_fsr4_supported_games_guide
}

install_configured_plugin() {
    local action="$1"
    local reload_after_install="${2:-1}"
    local open_lsfg_store="${3:-1}"
    local installed_version
    local deckrecall_ready=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "Decky 插件安装仅支持 SteamOS 或 Bazzite。"
        return 1
    fi

    case "$action" in
        lsfg)
            resolve_plugin_latest lsfg
            install_lsfg_bundle "$open_lsfg_store"
            ;;
        lsfg-mako)
            resolve_plugin_latest lsfg-mako
            if [ -z "${DECKY_LSFG_MAKO_URL:-}" ] || \
                [ -z "${DECKY_LSFG_MAKO_SHA256:-}" ]; then
                echo "MAKO 小黄鸭尝鲜版暂未获取到可校验的最新 Release，请稍后重试或更新Renkit。"
                return 1
            fi
            GITEE_MIRROR_REPO="$DECKY_MAKO_MIRROR_REPO" install_decky_zip \
                "MAKO 小黄鸭（尝鲜版）" \
                "$DECKY_LSFG_MAKO_URL" \
                "$DECKY_LSFG_MAKO_SHA256" \
                "$LSFG_MAKO_DIRECTORY" \
                0 || return 1
            apply_mako_zh_patch \
                "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/$LSFG_MAKO_DIRECTORY/dist/index.js" \
                || return 1
            remove_legacy_lsfg_directories "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
            ;;
        fsr4)
            resolve_plugin_latest fsr4
            if feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
                "$FSR4_OFFICIAL_DIRECTORY" "$FSR4_OFFICIAL_VERSION" \
                "Decky-Framegen" "FSR4" "Decky-Framegen(FSR4)"; then
                echo "[已安装] FSR4 v$FSR4_OFFICIAL_VERSION 已存在且文件完整，无需重复安装。"
                PLUGIN_INSTALL_CHANGED=0
            else
                installed_version="$(decky_plugin_version \
                    "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/$FSR4_OFFICIAL_DIRECTORY" || true)"
                [ -z "$installed_version" ] || \
                    echo "检测到 FSR4 旧版本 $installed_version，将更新到 $FSR4_OFFICIAL_VERSION。"
                install_decky_zip \
                    "FSR4（Decky Framegen）" \
                    "${DECKY_FSR4_URL:-}" \
                    "${DECKY_FSR4_SHA256:-}" \
                    "$FSR4_OFFICIAL_DIRECTORY" \
                    0
            fi
            ;;
        cheatdeck)
            echo "提示：强烈建议进入 游戏与插件，安装修改器所需兼容层。"
            resolve_plugin_latest cheatdeck
            if feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
                "CheatDeck" "$DECKY_CHEATDECK_VERSION" "CheatDeck"; then
                echo "[已安装] CheatDeck v$DECKY_CHEATDECK_VERSION 已存在且文件完整，无需重复安装。"
                PLUGIN_INSTALL_CHANGED=0
            else
                installed_version="$(decky_plugin_version \
                    "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/CheatDeck" || true)"
                [ -z "$installed_version" ] || \
                    echo "检测到 CheatDeck 旧版本 $installed_version，将更新到 $DECKY_CHEATDECK_VERSION。"
                install_decky_zip \
                    "CheatDeck" \
                    "${DECKY_CHEATDECK_URL:-}" \
                    "${DECKY_CHEATDECK_SHA256:-}" \
                    "CheatDeck" \
                    0
            fi
            ;;
        tomoon)
            resolve_plugin_latest tomoon
            install_decky_zip \
                "ToMoon" \
                "${DECKY_TOMOON_URL:-}" \
                "${DECKY_TOMOON_SHA256:-}" \
                "tomoon"
            ;;
        deckrecall)
            resolve_plugin_latest deckrecall
            installed_version="$(decky_plugin_version \
                "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/DeckRecall" || true)"
            if feature_plugin_is_present \
                "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "DeckRecall" "DeckRecall" && \
                [[ "$installed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && \
                ! deckrecall_version_is_older "$installed_version" "$DECKY_DECKRECALL_VERSION"; then
                echo "[已安装] DeckRecall $installed_version 已是最新正式版，无需重复下载。"
                PLUGIN_INSTALL_CHANGED=0
            else
                [ -z "$installed_version" ] || \
                    echo "检测到 DeckRecall 已安装版本 $installed_version，最新正式版 $DECKY_DECKRECALL_VERSION。"
                GITEE_MIRROR_REPO="$DECKY_DECKRECALL_MIRROR_REPO" \
                    GITHUB_RETRIES=1 GITHUB_MIN_SPEED_TIME=15 install_decky_zip \
                    "DeckRecall（添加启动项及恢复游戏可玩状态）" \
                    "${DECKY_DECKRECALL_URL:-}" \
                    "${DECKY_DECKRECALL_SHA256:-}" \
                    "DeckRecall" \
                    0
            fi
            patch_deckrecall_steam_browser || return 1
            if decky_plugin_directory_is_complete \
                "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "DeckRecall"; then
                deckrecall_ready=1
            fi
            ;;
        savepulse)
            if feature_plugin_is_current \
                "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
                "SavePulse" "$DECKY_SAVEPULSE_VERSION" "SavePulse"; then
                echo "[已安装] SavePulse $DECKY_SAVEPULSE_VERSION 已存在且文件完整，无需重复安装。"
                PLUGIN_INSTALL_CHANGED=0
            else
                installed_version="$(decky_plugin_version \
                    "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/SavePulse" || true)"
                [ -z "$installed_version" ] || \
                    echo "检测到 SavePulse 已安装版本 $installed_version，将更新到 $DECKY_SAVEPULSE_VERSION。"
                GITHUB_RETRIES=1 GITHUB_MIN_SPEED_TIME=15 install_decky_zip \
                    "SavePulse（自动存档与加密 WebDAV 换机恢复）" \
                    "$DECKY_SAVEPULSE_URL" \
                    "$DECKY_SAVEPULSE_SHA256" \
                    "SavePulse" \
                    0
            fi
            ;;
        freedeck)
            resolve_plugin_latest freedeck
            install_decky_zip \
                "Freedeck（下载游戏和模拟器游戏）感谢作者b站一苇Isidf" \
                "${DECKY_FREEDECK_URL:-}" \
                "${DECKY_FREEDECK_SHA256:-}" \
                "freedeck-plugin"
            ;;
        newfreedeck)
            (
                GITEE_MIRROR_REPO="$DECKY_NEWFREEDECK_MIRROR_REPO"
                export GITEE_MIRROR_REPO
                echo "提示：NewFreedeck v$DECKY_NEWFREEDECK_VERSION 为作者重构版，上游注明部分功能尚未完成。"
                install_decky_zip \
                    "NewFreedeck（重构测试版）" \
                    "$DECKY_NEWFREEDECK_URL" \
                    "$DECKY_NEWFREEDECK_SHA256" \
                    "NewFreedeck"
            )
            ;;
        steamdb-info|decky-translator)
            install_game_info_plugin_from_gitee "$action"
            ;;
        allycenter)
            ensure_allycenter_chinese_current
            ;;
        huesync)
            ensure_handheld_overlay_current zip "HueSync" \
                "$DECKY_HUESYNC_VERSION" "通用掌机 RGB" \
                "$DECKY_HUESYNC_URL" "$DECKY_HUESYNC_SHA256" \
                "$HUESYNC_CN_SOURCE_DIR" "$HUESYNC_CN_INDEX_SHA256" \
                "原作者：honjow；许可证：BSD 3-Clause。" 0
            ;;
        legiongo-remapper)
            ensure_handheld_overlay_current tar.gz "LegionGoRemapper" \
                "$DECKY_LEGIONGO_REMAPPER_VERSION" "Legion Go 控制中心" \
                "$DECKY_LEGIONGO_REMAPPER_URL" "$DECKY_LEGIONGO_REMAPPER_SHA256" \
                "$LEGIONGO_REMAPPER_ZH_SOURCE_DIR" "$LEGIONGO_REMAPPER_ZH_INDEX_SHA256" \
                "原作者：Aarron Lee；许可证：BSD 3-Clause。"
            ;;
        gpd-control)
            ensure_handheld_overlay_current tar.gz "GpdControl" \
                "$DECKY_GPD_CONTROL_VERSION" "GPD 控制中心" \
                "$DECKY_GPD_CONTROL_URL" "$DECKY_GPD_CONTROL_SHA256" \
                "$GPD_CONTROL_ZH_SOURCE_DIR" "$GPD_CONTROL_ZH_INDEX_SHA256" \
                "原作者：Aarron Lee；许可证：GPL-3.0。"
            ;;
        lego-vibe)
            ensure_handheld_overlay_current zip "LeGo-Vibe-Control" \
                "$DECKY_LEGO_VIBE_VERSION" "Legion Go 震动控制" \
                "$DECKY_LEGO_VIBE_URL" "$DECKY_LEGO_VIBE_SHA256" \
                "$LEGO_VIBE_ZH_SOURCE_DIR" "$LEGO_VIBE_ZH_INDEX_SHA256" \
                "原作者：Rayek；许可证：BSD 3-Clause。"
            ;;
        lego2-fan)
            ensure_handheld_overlay_current zip "lego2-fan-control" \
                "$DECKY_LEGO2_FAN_VERSION" "Legion Go 2 风扇控制" \
                "$DECKY_LEGO2_FAN_URL" "$DECKY_LEGO2_FAN_SHA256" \
                "$LEGO2_FAN_ZH_SOURCE_DIR" "$LEGO2_FAN_ZH_INDEX_SHA256" \
                "原作者：Luke Cama；许可证：GPL-3.0。"
            ;;
        onexplayer-apex)
            if [ "$IS_BAZZITE" -ne 1 ]; then
                echo "OneXPlayer Apex 工具仅支持 Bazzite，SteamOS 和其他 Linux 不会安装。"
                return 1
            fi
            (
                GITEE_MIRROR_REPO="$DECKY_ONEXPLAYER_APEX_MIRROR_REPO"
                export GITEE_MIRROR_REPO
                echo "警告：此插件仅适用于 OneXPlayer Apex（Strix Halo），其他机型不要安装或启用。"
                install_decky_zip \
                    "OneXPlayer Apex 工具" \
                    "$DECKY_ONEXPLAYER_APEX_URL" \
                    "$DECKY_ONEXPLAYER_APEX_SHA256" \
                    "OneXPlayer Apex Tools"
            )
            ;;
        simpledeckytdp)
            resolve_plugin_latest simpledeckytdp
            install_decky_zip \
                "SimpleDeckyTDP" \
                "${DECKY_SIMPLE_TDP_URL:-}" \
                "${DECKY_SIMPLE_TDP_SHA256:-}" \
                "SimpleDeckyTDP"
            ;;
        unifideck)
            resolve_plugin_latest unifideck
            ensure_steam302_for_download || true
            GITHUB_RETRIES=1 GITHUB_MIN_SPEED_TIME=20 install_decky_zip \
                "Unifideck" \
                "${DECKY_UNIFIDECK_URL:-}" \
                "${DECKY_UNIFIDECK_SHA256:-}" \
                "Unifideck"
            ;;
        steamgriddb)
            resolve_plugin_latest steamgriddb
            ;;
        cssloader)
            resolve_plugin_latest cssloader
            ;;
        friendeck)
            resolve_plugin_latest friendeck
            ;;
        deckymusic)
            resolve_plugin_latest deckymusic
            ;;
        *) return 1 ;;
    esac || return 1

    case "$action" in
        lsfg|lsfg-mako|fsr4|cheatdeck) refresh_feature_usage_guides || true ;;
    esac
    if [ "$action" = "cheatdeck" ]; then
        write_flingtrainer_desktop_note || \
            echo "CheatDeck 已处理，但未能在桌面生成风灵月影网址.txt。"
        print_cef_remote_debugging_tip
    fi

    # DeckRecall 旧版安装流程在子 shell 中丢失了 PLUGIN_INSTALL_CHANGED，
    # 文件已存在的用户再次执行时也会因幂等跳过而无法触发重载。只要确认
    # DeckRecall 目录完整，就允许重复执行专门修复 Decky 的扫描状态。
    if [ "$reload_after_install" = "1" ] && \
       { [ "$PLUGIN_INSTALL_CHANGED" -eq 1 ] || [ "$deckrecall_ready" -eq 1 ]; }; then
        reload_decky_plugins "Decky 已重新加载，返回游戏模式后可在插头菜单看到新插件。"
    fi
}

decky_plugin_version() {
    local plugin_dir="$1"

    [ -f "$plugin_dir/package.json" ] || return 1
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$plugin_dir/package.json" | head -n 1
}

feature_plugin_is_current() {
    local plugin_root="$1"
    local directory_name="$2"
    local expected_version="$3"
    local installed_version

    shift 3
    feature_plugin_is_present "$plugin_root" "$directory_name" "$@" || return 1
    installed_version="$(decky_plugin_version "$plugin_root/$directory_name" || true)"
    [ "$installed_version" = "$expected_version" ]
}

feature_plugin_is_present() {
    local plugin_root="$1"
    local directory_name="$2"
    local plugin_dir="$plugin_root/$directory_name"
    local actual_name
    local expected_name

    shift 2

    [ -d "$plugin_dir" ] && \
        [ -f "$plugin_dir/plugin.json" ] && \
        [ -s "$plugin_dir/dist/index.js" ] || return 1
    actual_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$plugin_dir/plugin.json" | head -n 1)"
    for expected_name in "$@"; do
        [ "$actual_name" = "$expected_name" ] && return 0
    done
    return 1
}

# SteamDB 游戏数据与沉浸式翻译均使用 mirror-3 上的固定完整汉化包。
# 不配置其它来源；清单、分块或整包校验失败时，原子安装尚未开始，旧插件会保留。
install_game_info_plugin_from_gitee() {
    local action="$1"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local directory version mirror_id package_sha256 index_sha256 backend_sha256 dependencies_sha256 display_name manifest_name author_line
    local actual_sha256 actual_backend_sha256 actual_dependencies_sha256 installed_version

    case "$action" in
        steamdb-info)
            directory="$STEAMDB_INFO_DIRECTORY"
            version="$STEAMDB_INFO_VERSION"
            mirror_id="$STEAMDB_INFO_MIRROR_ID"
            package_sha256="$STEAMDB_INFO_PACKAGE_SHA256"
            index_sha256="$STEAMDB_INFO_INDEX_SHA256"
            backend_sha256="$STEAMDB_INFO_BACKEND_SHA256"
            display_name="SteamDB 游戏数据"
            manifest_name="SteamDB 游戏数据"
            author_line="原作者：kedMertens；许可证：BSD 3-Clause。"
            ;;
        decky-translator)
            directory="$DECKY_TRANSLATOR_DIRECTORY"
            version="$DECKY_TRANSLATOR_VERSION"
            mirror_id="$DECKY_TRANSLATOR_MIRROR_ID"
            package_sha256="$DECKY_TRANSLATOR_PACKAGE_SHA256"
            index_sha256="$DECKY_TRANSLATOR_INDEX_SHA256"
            backend_sha256="$DECKY_TRANSLATOR_BACKEND_SHA256"
            dependencies_sha256="$DECKY_TRANSLATOR_DEPENDENCIES_SHA256"
            display_name="沉浸式翻译"
            manifest_name="沉浸式翻译"
            author_line="原作者：cat-in-a-box；许可证：GPL-3.0。"
            ;;
        *)
            echo "未知游戏信息插件：$action"
            return 1
            ;;
    esac

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "$display_name 仅支持 SteamOS 或 Bazzite。"
        return 1
    fi
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        ensure_plugin_store_ready || {
            echo "Decky Loader 未安装完成，$display_name 暂未开始安装。"
            return 1
        }
    fi

    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$directory/dist/index.js" 2>/dev/null || true)"
    actual_backend_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$directory/main.py" 2>/dev/null || true)"
    actual_dependencies_sha256=""
    if [ -n "${dependencies_sha256:-}" ] && \
       [ -s "$plugin_root/$directory/bin/plugin-dependencies.tar.gz" ]; then
        actual_dependencies_sha256="$(calculate_decky_sha256 \
            "$plugin_root/$directory/bin/plugin-dependencies.tar.gz" 2>/dev/null || true)"
    fi
    if feature_plugin_is_current "$plugin_root" "$directory" "$version" "$manifest_name" && \
        [ "$actual_sha256" = "$index_sha256" ] && \
        [ "$actual_backend_sha256" = "$backend_sha256" ] && \
        { [ -z "${dependencies_sha256:-}" ] || \
          [ "$actual_dependencies_sha256" = "$dependencies_sha256" ]; }; then
        echo "[已安装] $display_name v$version 已存在且校验通过，无需重复安装。"
        return 0
    fi
    if [ -d "$plugin_root/$directory" ]; then
        installed_version="$(decky_plugin_version "$plugin_root/$directory" || true)"
        echo "检测到 $display_name 版本 ${installed_version:-未知}，将通过 Gitee 分块更新到 v${version}。"
    else
        echo "正在通过 Gitee mirror-3 分块安装 $display_name v$version..."
    fi

    GITEE_MIRROR_REPO="$DECKY_GAME_INFO_MIRROR_REPO" \
        install_decky_zip_from_mirror "$display_name" "$mirror_id" \
        "$package_sha256" "$directory" || {
            echo "$display_name 的 Gitee 分块镜像不可用，已保留现有插件。"
            return 1
        }

    actual_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$directory/dist/index.js" 2>/dev/null || true)"
    actual_backend_sha256="$(calculate_decky_sha256 \
        "$plugin_root/$directory/main.py" 2>/dev/null || true)"
    actual_dependencies_sha256=""
    if [ -n "${dependencies_sha256:-}" ] && \
       [ -s "$plugin_root/$directory/bin/plugin-dependencies.tar.gz" ]; then
        actual_dependencies_sha256="$(calculate_decky_sha256 \
            "$plugin_root/$directory/bin/plugin-dependencies.tar.gz" 2>/dev/null || true)"
    fi
    if ! feature_plugin_is_current "$plugin_root" "$directory" "$version" "$manifest_name" || \
        [ "$actual_sha256" != "$index_sha256" ] || \
        [ "$actual_backend_sha256" != "$backend_sha256" ] || \
        { [ -n "${dependencies_sha256:-}" ] && \
          [ "$actual_dependencies_sha256" != "$dependencies_sha256" ]; }; then
        echo "$display_name 安装后校验失败，请更新Renkit后重试。"
        return 1
    fi
    echo "$display_name v$version 已安装；汉化：RenAmamiya。"
    echo "$author_line"
    reload_decky_plugins "Decky 已重新加载；返回游戏模式即可打开 ${display_name}。"
    log "$display_name v$version 通过 mirror-3 分块安装完成"
}

print_feature_plugin_status() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local missing=0
    local lsfg_version fsr4_version cheatdeck_version plugin_version

    echo ""
    echo "========== 常用功能插件状态 =========="
    if feature_plugin_is_present \
        "$plugin_root" "Decky LSFG-VK" "Decky LSFG-VK" "小黄鸭"; then
        lsfg_version="$(decky_plugin_version "$plugin_root/$LSFG_OFFICIAL_DIRECTORY" || true)"
        if [ "$lsfg_version" = "$LSFG_OFFICIAL_VERSION" ]; then
            echo "✓ 小黄鸭（LSFG-VK）：已写入 Decky，官方版本 $lsfg_version"
        else
            echo "✗ 小黄鸭（LSFG-VK）：检测到版本 ${lsfg_version:-未知}，请更新到 $LSFG_OFFICIAL_VERSION"
            missing=1
        fi
    else
        echo "✗ 小黄鸭（LSFG-VK）：未找到完整插件文件"
        missing=1
    fi
    if feature_plugin_is_present "$plugin_root" "Decky-Framegen" "Decky-Framegen" "FSR4" "Decky-Framegen(FSR4)" "Decky-Framegen（FSR4）"; then
        fsr4_version="$(decky_plugin_version "$plugin_root/$FSR4_OFFICIAL_DIRECTORY" || true)"
        if [ "$fsr4_version" = "$FSR4_OFFICIAL_VERSION" ]; then
            echo "✓ FSR4（Decky-Framegen）：已写入 Decky，官方版本 $fsr4_version"
        else
            echo "✗ FSR4（Decky-Framegen）：检测到版本 ${fsr4_version:-未知}，请更新到 $FSR4_OFFICIAL_VERSION"
            missing=1
        fi
    else
        echo "✗ FSR4（Decky-Framegen）：未找到完整插件文件"
        missing=1
    fi
    if feature_plugin_is_present "$plugin_root" "CheatDeck" "CheatDeck"; then
        cheatdeck_version="$(decky_plugin_version "$plugin_root/CheatDeck" || true)"
        if [ "$cheatdeck_version" = "$DECKY_CHEATDECK_VERSION" ]; then
            echo "✓ CheatDeck：已写入 Decky，官方版本 $cheatdeck_version"
        else
            echo "✗ CheatDeck：检测到版本 ${cheatdeck_version:-未知}，请更新到 $DECKY_CHEATDECK_VERSION"
            missing=1
        fi
    else
        echo "✗ CheatDeck：未找到完整插件文件"
        missing=1
    fi
    if feature_plugin_is_current "$plugin_root" "$STEAMGRIDDB_OFFICIAL_DIRECTORY" \
        "$STEAMGRIDDB_OFFICIAL_VERSION" "SteamGridDB"; then
        echo "✓ 游戏封面更换（SteamGridDB）：官方版本 $STEAMGRIDDB_OFFICIAL_VERSION，官方名称正确"
    else
        echo "✗ 游戏封面更换（SteamGridDB）：缺失、版本不符或官方名称未恢复"
        missing=1
    fi
    plugin_version="$(decky_plugin_version "$plugin_root/$CSSLOADER_OFFICIAL_DIRECTORY" || true)"
    if feature_plugin_is_current "$plugin_root" "$CSSLOADER_OFFICIAL_DIRECTORY" \
        "$CSSLOADER_OFFICIAL_VERSION" "主题美化" && \
       [ "$(calculate_decky_sha256 "$plugin_root/$CSSLOADER_OFFICIAL_DIRECTORY/dist/index.js" \
            2>/dev/null || true)" = "$CSSLOADER_ZH_INDEX_SHA256" ]; then
        echo "✓ 主题美化（CSS Loader）：官方后端 $plugin_version，中文前端校验通过"
    else
        echo "✗ 主题美化（CSS Loader）：缺失、版本不符或中文前端校验失败"
        missing=1
    fi
    if feature_plugin_is_current "$plugin_root" "Friendeck-plugin" \
        "$DECKY_FRIENDECK_PACKAGE_VERSION" "Friendeck"; then
        echo "✓ 文件传输助手（Friendeck）：Release $DECKY_FRIENDECK_RELEASE_VERSION，官方名称正确"
    else
        echo "✗ 文件传输助手（Friendeck）：缺失、版本不符或官方名称未恢复"
        missing=1
    fi
    if feature_plugin_is_current "$plugin_root" "Decky Music" \
        "$DECKY_DECKYMUSIC_VERSION" "Decky Music"; then
        echo "✓ 音乐播放器（Decky Music）：官方版本 $DECKY_DECKYMUSIC_VERSION，官方名称正确"
    else
        echo "✗ 音乐播放器（Decky Music）：缺失、版本不符或官方名称未恢复"
        missing=1
    fi
    echo ""
    echo "说明：插件侧栏中的 Decky-Framegen（FSR4）就是 FSR4。"
    echo "CheatDeck 安装完成后可在 Decky 右侧栏显示。"
    echo "若刚安装完仍未生效，请完全退出游戏模式后重新进入一次，让 Decky 重新加载插件。"
    return "$missing"
}

install_feature_plugins() {
    local plugin
    local failed=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "$IS_BAZZITE" -ne 1 ]; then
        echo "功能插件安装仅支持 SteamOS 或 Bazzite。"
        return 1
    fi

    ensure_plugin_store_ready || return 1

    # 先检测整组是否都已安装且本地名称/中文前端正确，是则跳过。
    local _all_installed=1
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "$LSFG_OFFICIAL_DIRECTORY" "$LSFG_OFFICIAL_VERSION" "小黄鸭"; then _all_installed=0; fi
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "$FSR4_OFFICIAL_DIRECTORY" "$FSR4_OFFICIAL_VERSION" "Decky-Framegen（FSR4）"; then _all_installed=0; fi
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
        "CheatDeck" "$DECKY_CHEATDECK_VERSION" "CheatDeck"; then _all_installed=0; fi
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
        "$STEAMGRIDDB_OFFICIAL_DIRECTORY" "$STEAMGRIDDB_OFFICIAL_VERSION" \
        "SteamGridDB"; then _all_installed=0; fi
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
        "$CSSLOADER_OFFICIAL_DIRECTORY" "$CSSLOADER_OFFICIAL_VERSION" \
        "主题美化" || \
       [ "$(calculate_decky_sha256 \
            "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/$CSSLOADER_OFFICIAL_DIRECTORY/dist/index.js" \
            2>/dev/null || true)" != "$CSSLOADER_ZH_INDEX_SHA256" ]; then _all_installed=0; fi
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
        "Friendeck-plugin" "$DECKY_FRIENDECK_PACKAGE_VERSION" \
        "Friendeck"; then _all_installed=0; fi
    if ! feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
        "Decky Music" "$DECKY_DECKYMUSIC_VERSION" \
        "Decky Music"; then _all_installed=0; fi
    if [ "$_all_installed" = "1" ]; then
        echo "七款常用功能插件已全部安装且校验通过，无需重复安装。"
        write_flingtrainer_desktop_note || \
            echo "常用插件已存在，但未能在桌面生成风灵月影网址.txt。"
        refresh_feature_usage_guides || true
        print_cef_remote_debugging_tip
        print_feature_plugin_status
        return 0
    fi

    echo "将依次安装：小黄鸭、FSR4、CheatDeck、游戏封面更换、主题美化、文件传输助手、音乐播放器。"
    for plugin in lsfg fsr4 cheatdeck steamgriddb cssloader friendeck deckymusic; do
        echo ""
        case "$plugin" in
            lsfg)
                echo "========== 小黄鸭（LSFG-VK） =========="
                if feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "$LSFG_OFFICIAL_DIRECTORY" "$LSFG_OFFICIAL_VERSION" "小黄鸭"; then
                    echo "[已安装] 小黄鸭 v$LSFG_OFFICIAL_VERSION 已安装，跳过。"
                    continue
                fi
                install_lsfg_zh_from_gitee 0 || failed=1
                ;;
            fsr4)
                echo "========== FSR4（Decky Framegen） =========="
                if feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "$FSR4_OFFICIAL_DIRECTORY" "$FSR4_OFFICIAL_VERSION" "Decky-Framegen（FSR4）"; then
                    echo "[已安装] FSR4 v$FSR4_OFFICIAL_VERSION 已安装，跳过。"
                    continue
                fi
                install_fsr4_zh_from_gitee 0 || failed=1
                ;;
            cheatdeck)
                echo "========== CheatDeck =========="
                echo "提示：强烈建议进入 游戏与插件，安装修改器所需兼容层。"
                if feature_plugin_is_current "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" \
                    "CheatDeck" "$DECKY_CHEATDECK_VERSION" "CheatDeck"; then
                    echo "[已安装] CheatDeck v$DECKY_CHEATDECK_VERSION 已安装，跳过。"
                    continue
                fi
                install_configured_plugin cheatdeck 0 0 || {
                    failed=1
                    echo "该插件未完成，继续尝试其余插件。"
                }
                ;;
            steamgriddb)
                echo "========== 游戏封面更换（SteamGridDB） =========="
                install_configured_plugin steamgriddb 0 0 || failed=1
                ;;
            cssloader)
                echo "========== 主题美化（CSS Loader 中文版） =========="
                install_configured_plugin cssloader 0 0 || failed=1
                ;;
            friendeck)
                echo "========== 文件传输助手（Friendeck） =========="
                install_configured_plugin friendeck 0 0 || failed=1
                ;;
            deckymusic)
                echo "========== 音乐播放器（Decky Music） =========="
                install_configured_plugin deckymusic 0 0 || failed=1
                ;;
        esac
    done

    refresh_feature_usage_guides || true
    if ! print_feature_plugin_status; then
        failed=1
        echo "至少有一项插件文件未写入完成，请单独重试对应项目。"
    fi

    reload_decky_plugins "Decky 已重新加载；返回游戏模式后，七款常用插件会出现在插头菜单中。"

    # 整组安装全部处理完后再打开正版页面，避免 Steam 窗口打断后两项插件。
    if feature_plugin_is_present         "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" "$LSFG_OFFICIAL_DIRECTORY" "Decky LSFG-VK" "小黄鸭"; then
        check_lossless_scaling_installation
    fi

    if [ "$failed" -eq 0 ]; then
        echo "七款常用功能插件已全部安装完成，名称、版本和关键文件均已确认。"
        print_cef_remote_debugging_tip
        log "常用功能插件整组安装完成"
        return 0
    fi

    echo "部分功能插件未完成，请查看上方提示后单独重试。"
    return 1
}

install_all_plugin_packages() {
    echo "将依次处理七款常用功能插件和27款精选插件，其中包括SimpleDeckyTDP与Unifideck。"
    echo "官方推荐插件仍由 Decky 内置安装器在 Steam 界面中确认。"

    install_feature_plugins || return 1

    # 等待 Decky Loader 就绪（安装常用插件组合可能重启了服务）
    local _dw_i
    for _dw_i in 1 2 3 4 5; do
        if curl -s --connect-timeout 2 --max-time 4             "$DECKY_API_BASE/auth/token" >/dev/null 2>&1; then
            break
        fi
        sleep 3
    done

    if ! bash "$PROJECT_ROOT/modules/decky_bundle.sh" install; then
        echo "官方推荐插件清单未完成提交；七款常用插件的结果请查看上方提示。"
        return 1
    fi

    echo "当前列表全部插件的安装流程已完成。"
    log "全部插件安装流程完成"
}


install_25_plugins() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "精选插件安装仅支持真实 SteamOS 环境。"
        return 1
    fi
    echo "将从 Decky 官方商店批量安装 26 款精选插件，其中包括 SimpleDeckyTDP 与 Unifideck。"
    echo "不会安装小黄鸭、FSR4 和 CheatDeck（请在常用功能插件中单独安装）。"
    echo "官方推荐插件仍由 Decky 内置安装器在 Steam 界面中确认。"
    if ! bash "$PROJECT_ROOT/modules/decky_bundle.sh" install; then
        echo "精选插件安装未完成提交。"
        return 1
    fi
    echo "26 款精选插件的安装流程已完成。"
    log "26款精选插件安装完成"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-store}" in
        store) show_plugin_download_speed_tip; install_plugin_store stable ;;
        store-test) show_plugin_download_speed_tip; install_plugin_store prerelease ;;
        store-auto) show_plugin_download_speed_tip; install_plugin_store_auto ;;
        store-uninstall) uninstall_plugin_store ;;
        lsfg) install_lsfg_zh_from_gitee && refresh_feature_usage_guides ;;
        lsfg-mako) show_plugin_download_speed_tip; install_configured_plugin lsfg-mako ;;
        lsfg-zh) install_lsfg_zh_from_gitee && refresh_feature_usage_guides ;;
        lsfg-zh-gitee) install_lsfg_zh_from_gitee && refresh_feature_usage_guides ;;
        fsr4-zh) install_fsr4_zh_from_gitee && refresh_feature_usage_guides ;;
        fsr4-zh-gitee) install_fsr4_zh_from_gitee && refresh_feature_usage_guides ;;
        simpledeckytdp-zh) install_simpledeckytdp_chinese ;;
        simpledeckytdp-zh-gitee) ensure_simpledeckytdp_chinese_current ;;
        lsfg-restore) show_plugin_download_speed_tip; restore_lsfg_official ;;
        lsfg-store) open_lossless_store ;;
        lsfg-import-select) select_and_import_lossless_backup ;;
        fsr4) install_fsr4_zh_from_gitee && refresh_feature_usage_guides ;;
        cheatdeck) show_plugin_download_speed_tip; install_configured_plugin cheatdeck ;;
        steamgriddb) show_plugin_download_speed_tip; install_configured_plugin steamgriddb ;;
        cssloader) show_plugin_download_speed_tip; install_configured_plugin cssloader ;;
        friendeck) show_plugin_download_speed_tip; install_configured_plugin friendeck ;;
        deckymusic) show_plugin_download_speed_tip; install_configured_plugin deckymusic ;;
        tomoon) show_plugin_download_speed_tip; install_configured_plugin tomoon ;;
        deckrecall) show_plugin_download_speed_tip; install_configured_plugin deckrecall ;;
        savepulse) show_plugin_download_speed_tip; install_configured_plugin savepulse ;;
        freedeck) show_plugin_download_speed_tip; install_configured_plugin freedeck ;;
        newfreedeck) show_plugin_download_speed_tip; install_configured_plugin newfreedeck ;;
        steamdb-info) install_configured_plugin steamdb-info ;;
        decky-translator) install_configured_plugin decky-translator ;;
        allycenter) show_plugin_download_speed_tip; install_configured_plugin allycenter ;;
        huesync) show_plugin_download_speed_tip; install_configured_plugin huesync ;;
        legiongo-remapper) show_plugin_download_speed_tip; install_configured_plugin legiongo-remapper ;;
        gpd-control) show_plugin_download_speed_tip; install_configured_plugin gpd-control ;;
        lego-vibe) show_plugin_download_speed_tip; install_configured_plugin lego-vibe ;;
        lego2-fan) show_plugin_download_speed_tip; install_configured_plugin lego2-fan ;;
        onexplayer-apex) show_plugin_download_speed_tip; install_configured_plugin onexplayer-apex ;;
        simpledeckytdp) show_plugin_download_speed_tip; install_configured_plugin simpledeckytdp ;;
        unifideck) show_plugin_download_speed_tip; install_configured_plugin unifideck ;;
        localizer)
            echo "旧版通用扫描式汉化已停用，请使用“常用插件组合”。"
            exit 1
            ;;
        feature-status) print_feature_plugin_status ;;
        uninstall) uninstall_all_decky_plugins ;;
        features) show_plugin_download_speed_tip; install_feature_plugins ;;
        all) show_plugin_download_speed_tip; install_all_plugin_packages ;;
        curated-25) show_plugin_download_speed_tip; install_25_plugins ;;
        lsfg-import)
            [ -n "${2:-}" ] || {
                echo "用法: $0 lsfg-import /本地/备份文件"
                exit 1
            }
            import_lossless_backup "$2"
            ;;
        *) echo "未知插件操作: $1"; exit 1 ;;
    esac
fi
