#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

GUI_TITLE="Renkit V$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION" 2>/dev/null || printf '?')"
GUI_ICON="$PROJECT_ROOT/assets/icon-round.png"
GUI_NAV_HOME=0

# GUI 父进程不驻留在会被自更新替换的安装目录中。
cd "$HOME" 2>/dev/null || cd / || exit 1

# Decky 官方商店插件：保留英文官方名，后面附小白可理解的中文作用。
DECKY_OFFICIAL_PLUGIN_NAMES=(
    "CSS Loader" "vibrantDeck" "Animation Changer" "Audio Loader" "SteamGridDB"
    "PowerTools" "Storage Cleaner" "AutoFlatpaks" "Bluetooth" "ProtonDB Badges"
    "Deck Settings" "HLTB for Deck" "PlayCount" "TabMaster"
    "Wine Cellar" "Pause Games" "Controller Tools" "Volume Mixer" "Battery Tracker"
    "PlayTime" "Free Loader" "DeckMTP" "MangoPeel"
    "Freedeck"
)
DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS=(
    "自定义界面样式" "调整界面配色" "更换开机动画" "更换系统音效" "自动补游戏封面"
    "性能与功耗控制" "清理游戏缓存" "自动更新应用" "管理蓝牙设备" "显示兼容性评分"
    "更多 Deck 设置" "显示通关时长" "记录游玩次数" "整理游戏库标签"
    "管理 Wine 与 Proton" "后台自动暂停游戏" "手柄辅助工具" "分应用调节音量" "查看电池状态"
    "下载游戏和模拟器游戏"
    "记录游戏时长" "下载功能扩展" "USB 文件传输" "优化 Steam 界面"
)

gui_dialog() {
    if [ -f "$GUI_ICON" ]; then
        kdialog --title "$GUI_TITLE" --icon "$GUI_ICON" "$@"
    else
        kdialog --title "$GUI_TITLE" "$@"
    fi
}

gui_confirm() {
    gui_dialog --yesno "$1" --yes-label "继续" --no-label "取消"
}

gui_notice() {
    gui_dialog --msgbox "$1"
}

run_gui_action() {
    local status action_log failure_detail
    local title="$1"
    shift

    print_header
    print_section_title "$title"
    echo ""
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    action_log="$(mktemp "$LOG_DIR/gui-action.XXXXXX" 2>/dev/null || true)"
    if [ -n "$action_log" ]; then
        "$@" 2>&1 | tee "$action_log"
        status="${PIPESTATUS[0]}"
    else
        "$@"
        status=$?
    fi
    cd "$HOME" 2>/dev/null || cd / || true
    if [ "$status" -eq 0 ]; then
        gui_notice "$title 已完成。"
    else
        failure_detail="$(tail -n 12 "$action_log" 2>/dev/null || true)"
        if [ -n "$failure_detail" ]; then
            gui_dialog --error "$title 未完成。\n\n失败详情：\n$failure_detail\n\n完整日志：$action_log"
        else
            gui_dialog --error "$title 未完成，请查看终端中的提示。"
        fi
    fi
    return "$status"
}

software_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "常用软件｜安装聊天、浏览器和远程工具" \
            wechat "微信" \
            qq "QQ" \
            browser "Firefox 浏览器" \
            chrome "Chrome 浏览器" \
            edge "Edge 浏览器" \
            rustdesk "RustDesk 远程协助｜安装开源远程工具" \
            anydesk "AnyDesk 远程协助｜通过 Flathub 国内镜像安装" \
            todesk "ToDesk 远程协助｜安装前需完成系统设置" \
            bottles "Windows 软件工具｜安装 Bottles 运行工具" \
            baidunetdisk "百度网盘｜Flathub 安装百度网盘 Linux 版" \
            libreoffice "LibreOffice 办公套件｜文档、表格与演示文稿" \
            vlc "VLC 播放器｜本地视频与音频播放" \
            obs "OBS Studio｜录屏、直播与视频采集" \
            localsend "LocalSend 局域网传文件｜手机与电脑免登录互传" \
            peazip "PeaZip 压缩工具｜解压与压缩常用格式" \
            willwill "WiliWili｜Flathub 安装，完成后加入 Steam 库" \
            fcitx5 "中文输入法｜Fcitx5 与中文输入插件" \
            xbox-cloud "Xbox 云游戏｜Flathub 安装 Greenlight，云游戏需 Xbox 账号" \
            qqmusic "QQ音乐｜Flathub 安装" \
            netease-music "网易云音乐｜Flathub 安装" \
            yesplaymusic "YesPlayMusic｜Flathub 安装第三方网易云音乐客户端" \
            qbittorrent "qBittorrent｜BT 种子与磁力下载" \
            motrix "Motrix 下载器｜多协议下载管理" \
            freedownloadmanager "Free Download Manager｜下载管理工具" \
            media-downloader "Media Downloader｜视频与媒体下载" \
            flameshot "Flameshot 截图｜截图与标注" \
            onlyoffice "OnlyOffice 办公套件｜兼容 Office 文档" \
            joplin "Joplin 笔记｜笔记与待办管理" \
            heroic "Heroic 游戏启动器｜Epic 与 GOG 游戏库" \
            lutris "Lutris｜多平台游戏管理" \
            chiaki4deck "Chiaki4Deck（PS5串流）｜PS5 远程串流" \
            parsec "Parsec｜远程串流与协作" \
            protontricks "游戏兼容设置｜安装 Protontricks" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            wechat)
                gui_confirm "将从微信Linux版官网下载官方x86_64 AppImage，并自动创建桌面图标。是否继续？" && \
                    run_gui_action "安装微信" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" wechat
                ;;
            qq)
                gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 QQ，不连接腾讯 QQ AppImage 下载地址。是否继续？" && \
                    run_gui_action "安装QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" qq
                ;;
            browser)
                gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 Firefox。是否继续？" && \
                    run_gui_action "安装 Firefox 浏览器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" browser
                ;;
            chrome) gui_confirm "将通过 Flatpak 安装 Google Chrome。是否继续？" && run_gui_action "安装 Google Chrome" bash "$PROJECT_ROOT/modules/software.sh" chrome ;;
            edge) gui_confirm "将通过 Flatpak 安装 Microsoft Edge。是否继续？" && run_gui_action "安装 Microsoft Edge" bash "$PROJECT_ROOT/modules/software.sh" edge ;;
            rustdesk)
                gui_confirm "将从 RustDesk 作者 GitHub Release 下载 AppImage，并创建桌面图标；不会修改服务器配置。是否继续？" && \
                    run_gui_action "安装 RustDesk 远程协助" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" rustdesk
                ;;
            anydesk) gui_confirm "将通过 Flathub 国内镜像以当前用户身份安装 AnyDesk。是否继续？" && run_gui_action "安装 AnyDesk 远程协助" bash "$PROJECT_ROOT/modules/software.sh" anydesk ;;
            todesk)
                gui_confirm "ToDesk 会使用管理员权限并临时修改 SteamOS 只读系统。请先在游戏模式开启开发者模式和旧版 X11 桌面模式。确认继续？" && \
                    run_gui_action "安装 ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --install
                ;;
            baidunetdisk) gui_confirm "将通过 Flatpak 安装百度网盘。是否继续？" && run_gui_action "安装百度网盘" bash "$PROJECT_ROOT/modules/software.sh" baidunetdisk ;;
            libreoffice) gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 LibreOffice。是否继续？" && run_gui_action "安装 LibreOffice 办公套件" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" libreoffice ;;
            vlc) gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 VLC。是否继续？" && run_gui_action "安装 VLC 播放器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" vlc ;;
            obs) gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 OBS Studio。是否继续？" && run_gui_action "安装 OBS Studio" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" obs ;;
            localsend) gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 LocalSend。是否继续？" && run_gui_action "安装 LocalSend 局域网传文件" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" localsend ;;
            peazip) gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 PeaZip。是否继续？" && run_gui_action "安装 PeaZip 压缩工具" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" peazip ;;
            willwill) gui_confirm "将通过 Flathub 国内缓存安装 WiliWili（B站客户端），完成后加入 Steam 库。是否继续？" && run_gui_action "安装 WiliWili" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" willwill ;;
            fcitx5) gui_confirm "将通过 Flathub 国内缓存安装 Fcitx5 中文输入法及中文输入插件。是否继续？" && run_gui_action "安装中文输入法" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" fcitx5 ;;
            xbox-cloud) gui_confirm "将通过 Flathub 安装 Greenlight（Xbox 云游戏客户端），云游戏需要 Xbox 账号。是否继续？" && run_gui_action "安装 Xbox 云游戏" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" xbox-cloud ;;
            qqmusic) gui_confirm "将通过 Flathub 国内缓存安装 QQ音乐，并自动创建桌面图标。是否继续？" && run_gui_action "安装 QQ音乐" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" qqmusic ;;
            netease-music) gui_confirm "将通过 Flathub 国内缓存安装网易云音乐，并自动创建桌面图标。是否继续？" && run_gui_action "安装网易云音乐" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" netease-music ;;
            yesplaymusic) gui_confirm "将通过 Flathub 国内缓存安装 YesPlayMusic，并自动创建桌面图标。是否继续？" && run_gui_action "安装 YesPlayMusic" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" yesplaymusic ;;
            qbittorrent) gui_confirm "将通过 Flathub 国内缓存安装 qBittorrent，并自动创建桌面图标。是否继续？" && run_gui_action "安装 qBittorrent" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" qbittorrent ;;
            motrix) gui_confirm "将通过 Flathub 国内缓存安装 Motrix 下载器，并自动创建桌面图标。是否继续？" && run_gui_action "安装 Motrix 下载器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" motrix ;;
            freedownloadmanager) gui_confirm "将通过 Flathub 国内缓存安装 Free Download Manager，并自动创建桌面图标。是否继续？" && run_gui_action "安装 Free Download Manager" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" freedownloadmanager ;;
            media-downloader) gui_confirm "将通过 Flathub 国内缓存安装 Media Downloader，并自动创建桌面图标。是否继续？" && run_gui_action "安装 Media Downloader" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" media-downloader ;;
            flameshot) gui_confirm "将通过 Flathub 国内缓存安装 Flameshot 截图，并自动创建桌面图标。是否继续？" && run_gui_action "安装 Flameshot 截图" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" flameshot ;;
            onlyoffice) gui_confirm "将通过 Flathub 国内缓存安装 OnlyOffice 办公套件，并自动创建桌面图标。是否继续？" && run_gui_action "安装 OnlyOffice 办公套件" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" onlyoffice ;;
            joplin) gui_confirm "将通过 Flathub 国内缓存安装 Joplin 笔记，并自动创建桌面图标。是否继续？" && run_gui_action "安装 Joplin 笔记" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" joplin ;;
            heroic) gui_confirm "将通过 Flathub 国内缓存安装 Heroic 游戏启动器，并自动加入 Steam 库。是否继续？" && run_gui_action "安装 Heroic 游戏启动器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" heroic ;;
            lutris) gui_confirm "将通过 Flathub 国内缓存安装 Lutris，并自动加入 Steam 库。是否继续？" && run_gui_action "安装 Lutris" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" lutris ;;
            chiaki4deck) gui_confirm "将通过 Flathub 国内缓存安装 Chiaki4Deck（PS5串流），并自动加入 Steam 库。是否继续？" && run_gui_action "安装 Chiaki4Deck（PS5串流）" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" chiaki4deck ;;
            parsec) gui_confirm "将通过 Flathub 国内缓存安装 Parsec，并自动加入 Steam 库。是否继续？" && run_gui_action "安装 Parsec" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" parsec ;;
            protontricks) gui_confirm "将通过 Flatpak 安装 Protontricks。是否继续？" && run_gui_action "安装 Protontricks" bash "$PROJECT_ROOT/modules/software.sh" protontricks ;;
            bottles) gui_confirm "将通过 Flatpak 安装 Bottles。是否继续？" && run_gui_action "安装 Bottles" bash "$PROJECT_ROOT/modules/software.sh" bottles ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

remote_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "选择远程协助工具" \
            rustdesk "下载 RustDesk（作者 GitHub Release）" \
            todesk "ToDesk" \
            back "返回主菜单")" || return 0
        case "$choice" in
            rustdesk)
                gui_confirm "将从 RustDesk 作者 GitHub Release 下载 AppImage，并创建桌面图标；不会写入或修改 RustDesk 服务器配置。是否继续？" && \
                    run_gui_action "下载 RustDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" rustdesk
                ;;
            todesk)
                gui_confirm "ToDesk 使用前必须先在游戏模式完成：① Steam键→设置→系统，开启“启用开发者模式”；② 设置侧栏→开发者→杂项，开启“使用旧版X11桌面模式”；③ 重新进入桌面模式。ToDesk安装会临时关闭只读保护并在完成后恢复。是否已完成全部设置并继续？" && \
                    run_gui_action "安装ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --install
                ;;
            back) return 0 ;;
        esac
    done
}

ge_proton_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "GE 兼容层｜安装最新版或修改器常用兼容层" \
            latest "安装最新 GE 兼容层｜自动检测最新版本，不再删除旧版" \
            trainer "安装修改器所需常用兼容层｜四个版本约1.72GB，下载较慢为正常现象" \
            back "返回游戏与插件" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            latest)
                gui_confirm "将自动检测并安装最新 GE-Proton，不会删除已安装的旧版兼容层。是否继续？" && \
                    run_gui_action "安装最新 GE 兼容层" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install
                ;;
            trainer)
                gui_confirm "将安装 GE-Proton 7-55、8-25、9-27、10-29 四个修改器常用兼容层；合计约1.72GB，下载较慢为正常现象。是否继续？" && \
                    run_gui_action "安装修改器所需常用兼容层" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install-trainer
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

game_environment_gui_menu() {
    local choice
    local decky_choice
    local battlenet_choice
    local freedeck_choice
    local handheld_plugin_choice
    local repair_choice

    while true; do
        choice="$(gui_dialog --menu "游戏与插件｜插件商城" \
            features "常用插件组合｜安装小黄鸭等三款插件" \
            all "常用插件加27款精选插件｜优先安装三件套，已装则跳过；再补27款精选" \
            lsfg "小黄鸭｜插帧神器（必装）" \
            fsr4 "FSR4｜画质补丁（阅读桌面文档慎用）" \
            freedeck "Freedeck｜选择 0.6 稳定版或 NewFreedeck" \
            handheld-plugins "掌机控制插件｜掌机功耗控制与 ROG Ally Center" \
            browse "浏览官方插件｜逐个查看插件作用" \
            ge-proton "安装 GE 兼容层｜提高 Windows 游戏兼容性" \
            epic "Epic 游戏启动器｜安装并添加到 Steam" \
            tomoon "ToMoon｜网络工具" \
            battlenet "战网启动器｜自动下载预装客户端并绑定 Proton 10.0-4" \
            ubisoft "育碧｜安装育碧游戏平台并添加到 Steam" \
            repair "修复启动器封面｜重写 Steam 库封面并重启 Steam" \
            decky-install "安装插件商城｜稳定版国内失败自动切换官方源｜可选测试版｜高级操作" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            features)
                gui_confirm "请先在游戏模式：Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，完成后重新进入桌面模式。未安装插件商城时会先安装插件商城，再继续安装三款插件；会使用管理员权限。是否继续？" && \
                    run_gui_action "安装常用插件组合" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" features
                ;;
            all)
                gui_confirm "请先在游戏模式：Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，完成后重新进入桌面模式。未安装插件商城时会先安装插件商城，再继续安装常用与精选插件；会使用管理员权限。是否继续？" && \
                    run_gui_action "安装常用插件加27款精选插件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" all
                ;;
            lsfg)
                run_gui_action "安装小黄鸭（插帧神器）" \
                    env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-zh-gitee
                ;;
            fsr4)
                run_gui_action "安装 FSR4（画质补丁）" \
                    env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4-zh-gitee
                ;;
            freedeck)
                freedeck_choice="$(gui_dialog --menu "Freedeck 版本选择" \
                    stable "Freedeck 0.6 稳定版｜现有稳定版本" \
                    new "NewFreedeck v0.1｜独立重构版，上游注明部分功能未完成" \
                    back "返回游戏与插件")" || continue
                case "$freedeck_choice" in
                    stable)
                        run_gui_action "安装 Freedeck 0.6 稳定版" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" freedeck
                        ;;
                    new)
                        gui_confirm "NewFreedeck v0.1 是作者独立重构版；上游注明部分功能尚未完成，可能使用异常。是否继续安装？" && \
                            run_gui_action "安装 NewFreedeck v0.1" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" newfreedeck
                        ;;
                esac
                ;;
            handheld-plugins)
                handheld_plugin_choice="$(gui_dialog --menu "掌机控制插件" \
                    simpledeckytdp "掌机功耗控制｜SimpleDeckyTDP 汉化版·自动检测版本" \
                    allycenter "Ally 控制中心｜ROG Ally / Ally X 的 RGB、TDP、风扇与充电上限" \
                    huesync "通用掌机 RGB｜HueSync 官方简体中文·支持多品牌掌机" \
                    legiongo-remapper "Legion Go 控制中心｜初代 Legion Go 按键、RGB、充电与风扇" \
                    gpd-control "GPD 控制中心｜GPD Win 系列 RGB 与按游戏配置" \
                    lego-vibe "Legion Go 震动控制｜Go / Go 2 震动与触控板反馈" \
                    lego2-fan "Legion Go 2 风扇控制｜仅 Go 2·不受限风扇曲线" \
                    back "返回游戏与插件")" || continue
                case "$handheld_plugin_choice" in
                    simpledeckytdp)
                        run_gui_action "安装/修复掌机功耗控制汉化版" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" simpledeckytdp-zh-gitee
                        ;;
                    allycenter)
                        gui_confirm "Ally Center 仅适用于 ROG Ally / Ally X，可控制摇杆 RGB、TDP、风扇和充电上限，插件需要 Decky root 权限。将优先使用国内源，失败自动改用作者 GitHub Release。是否继续？" && \
                            run_gui_action "安装 Ally Center" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" allycenter
                        ;;
                    huesync)
                        gui_confirm "HueSync 官方已内置简体中文，支持多品牌掌机 RGB，插件需要 Decky root 权限。请勿与其他灯光插件同时控制同一设备。将优先使用国内源，失败自动改用作者 GitHub Release。是否继续？" && \
                            run_gui_action "安装通用掌机 RGB" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" huesync
                        ;;
                    legiongo-remapper)
                        gui_confirm "仅适用于初代 Legion Go，不支持 Legion Go S；可控制按键、RGB、80% 充电上限及实验性风扇曲线，需要 Decky root 权限，HHD 可能覆盖灯光设置。是否继续？" && \
                            run_gui_action "安装 Legion Go 控制中心" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" legiongo-remapper
                        ;;
                    gpd-control)
                        gui_confirm "适用于支持的 GPD Win 掌机 RGB，支持按游戏配置，需要 Decky root 权限。是否继续？" && \
                            run_gui_action "安装 GPD 控制中心" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" gpd-control
                        ;;
                    lego-vibe)
                        gui_confirm "适用于 Legion Go / Go 2，不支持 Go S；需要 SteamOS 3.8+、内核 6.18+、hid-lenovo-go 驱动与 Decky root 权限。是否继续？" && \
                            run_gui_action "安装 Legion Go 震动控制" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" lego-vibe
                        ;;
                    lego2-fan)
                        gui_confirm "高风险：仅适用于 Legion Go 2。此插件允许不受限制的风扇曲线，错误设置可能在高温时使用过低转速并损伤设备；需要 Decky root 权限。确认理解风险后继续？" && \
                            run_gui_action "安装 Legion Go 2 风扇控制" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" lego2-fan
                        ;;
                esac
                ;;
            browse)
                plugin_official_gui_pages
                [ "$GUI_NAV_HOME" -eq 0 ] || return 0
                ;;
            ge-proton)
                ge_proton_gui_menu
                [ "$GUI_NAV_HOME" -eq 0 ] || return 0
                ;;
            epic)
                run_gui_action "安装 Epic 游戏启动器并自动入库" \
                    env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" epic
                ;;
            tomoon)
                gui_confirm "将下载 ToMoon 网络工具插件并校验 SHA256，随后安装到 Decky。是否继续？" && \
                    run_gui_action "安装 ToMoon" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" tomoon
                ;;
            battlenet)
                battlenet_choice="$(gui_dialog --menu "战网安装｜请选择" \
                    battlenet "战网启动器｜自动下载预装客户端并添加到 Steam" \
                    heihe "黑盒工坊｜魔兽插件管理工具，自动下载预装客户端并添加到 Steam" \
                    back "返回插件列表")" || continue
                case "$battlenet_choice" in
                    battlenet)
                        run_gui_action "安装战网启动器并自动入库" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/game_launchers.sh" battlenet
                        ;;
                    heihe)
                        run_gui_action "安装黑盒工坊并自动入库" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/game_launchers.sh" heihe
                        ;;
                esac
                ;;
            ubisoft)
                run_gui_action "安装育碧并自动入库" \
                    env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" ubisoft
                ;;
            repair)
                repair_choice="$(gui_dialog --menu "修复启动器封面｜选择启动器" \
                    epic "Epic 游戏启动器" \
                    battlenet "战网启动器" \
                    ubisoft "育碧" \
                    heihe "黑盒工坊" \
                    back "返回游戏与插件")" || continue
                case "$repair_choice" in
                    epic|battlenet|ubisoft|heihe)
                        run_gui_action "重新应用封面" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/game_launchers.sh" apply-artwork "$repair_choice"
                        ;;
                esac
                ;;
            decky-install)
                decky_choice="$(gui_dialog --menu "安装插件商城｜请选择与 SteamOS 系统通道匹配的版本" \
                    stable "安装稳定版｜适合 SteamOS 正式系统" \
                    test "安装测试版｜仅适合 SteamOS 测试或预览系统｜国内源优先" \
                    auto "根据系统版本安装｜自动检测稳定版或测试版" \
                    back "返回插件列表")" || continue
                case "$decky_choice" in
                    auto)
                        gui_confirm "会自动检测 SteamOS 正式或测试通道并安装对应版本；会先停用旧服务再安装，已有插件和设置保留。是否继续？" && \
                            run_gui_action "按系统版本自动安装插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" store-auto
                        ;;
                    stable)
                        gui_confirm "适合 SteamOS 正式系统。优先使用国内线路，失败自动切换 Decky 官方 Release；会停用旧版用户服务并切换到稳定通道，已有插件和设置保留。是否继续？" && \
                            run_gui_action "安装稳定版插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" store
                        ;;
                    test)
                        gui_confirm "仅当 SteamOS 使用测试或预览通道、稳定版 Decky 明确不兼容时使用。优先从国内镜像下载，失败自动回退 Decky 官方 prerelease Release；已有插件和设置保留。是否继续？" && \
                            run_gui_action "安装测试版插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" store-test
                        ;;
                esac
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

emulator_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "安装模拟器｜完成后自动创建桌面图标并添加到 Steam 库" \
            install-all "一键安装 6 款｜Switch、Wii U、PS1、PS2、PS3、PS4" \
            yuzu "Yuzu｜Switch 模拟器" \
            cemu "Cemu｜Wii U 模拟器" \
            duckstation "DuckStation｜PS1 模拟器" \
            pcsx2 "PCSX2｜PS2 模拟器" \
            rpcs3 "RPCS3｜PS3 模拟器" \
            shadps4 "ShadPS4｜PS4 模拟器" \
            ppsspp "PPSSPP｜PSP 模拟器" \
            mgba "mGBA｜GBA 模拟器" \
            azahar "Azahar｜3DS 模拟器" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            install-all)
                gui_confirm "将依次安装 Yuzu、Cemu、DuckStation、PCSX2、RPCS3 和 ShadPS4；只安装模拟器本体，不包含游戏、BIOS、固件或密钥。已完整安装的项目会跳过，单项失败不会中断后续安装。是否继续？" && \
                    run_gui_action "一键安装 6 款模拟器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/emulators.sh" install-all
                ;;
            yuzu)
                choice="$(gui_dialog --menu "Yuzu｜仅导入本人合法备份的密钥" \
                    install "安装 Yuzu 本体" \
                    keys "导入本人备份的 prod.keys / title.keys" \
                    status "查看密钥状态（不显示内容）" \
                    back "返回模拟器列表")" || continue
                case "$choice" in
                    install) gui_confirm "只安装模拟器本体；不包含游戏、BIOS、固件或密钥。是否继续？" && run_gui_action "安装 Yuzu" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" yuzu ;;
                    keys) gui_confirm "仅可导入本人合法备份的 prod.keys / title.keys；Renkit不会下载、显示或分享密钥。是否继续？" && run_gui_action "导入 Yuzu 密钥" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" yuzu-keys ;;
                    status) run_gui_action "Yuzu 密钥状态" bash "$PROJECT_ROOT/modules/emulators.sh" yuzu-keys-status ;;
                esac
                ;;
            cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                gui_confirm "只安装模拟器本体；不包含游戏、BIOS 或固件。完成后会创建桌面图标并添加到 Steam 库；写入 Steam 前会安全退出并重启 Steam。是否继续？" && \
                    run_gui_action "安装模拟器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/emulators.sh" "$choice"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

plugin_official_gui_pages() {
    local choice
    local page=0
    local page_size=8
    local total="${#DECKY_OFFICIAL_PLUGIN_NAMES[@]}"
    local total_pages=$(((total + page_size - 1) / page_size))
    local start
    local end
    local index
    local -a menu_args

    while true; do
        start=$((page * page_size))
        end=$((start + page_size))
        [ "$end" -le "$total" ] || end="$total"
        menu_args=(--menu "官方插件（第 $((page + 1)) / $total_pages 页）")
        for ((index = start; index < end; index++)); do
            menu_args+=("plugin-$index" "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}｜${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}")
        done
        if [ "$page" -gt 0 ]; then
            menu_args+=(previous "上一页")
        else
            menu_args+=(back "返回游戏与插件")
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            menu_args+=(next "下一页")
        else
            menu_args+=(back-last "返回游戏与插件")
        fi
        menu_args+=(home "返回首页" nav-exit "退出Renkit")

        choice="$(gui_dialog "${menu_args[@]}")" || return 0
        case "$choice" in
            plugin-*)
                index="${choice#plugin-}"
                gui_confirm "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}：${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}。安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将由 Decky 官方商店安装，是否继续？" && \
                    run_gui_action "安装 ${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/decky_bundle.sh" plugin "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}"
                ;;
            previous) page=$((page - 1)) ;;
            next) page=$((page + 1)) ;;
            back|back-last) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

dual_system_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "双系统与互通盘｜磁盘和开机菜单设置｜高级操作" \
            health "双系统健康检查｜识别 Clover、rEFInd、GRUB、OpenCore 等｜只读" \
            mount "挂载双系统互通盘｜自动排除 Windows 系统分区｜高级操作" \
            tf-format "初始化并挂载 TF 卡｜清空并格式化为 NTFS｜高风险" \
            repair-drive "修复磁盘写入错误｜NTFS/exFAT 基础修复｜高级操作" \
            protect "双系统互通盘保护｜防止 SteamOS 误写入｜高级操作" \
            unprotect "恢复互通盘写入｜重新以可写方式挂载｜高级操作" \
            cleanup-boot "清理第三方引导项｜保护 SteamOS / Windows｜保留 EFI 文件" \
            repair-boot "修复双系统引导｜补齐缺失的 SteamOS / Windows / Clover 引导项｜高级操作" \
            switch-to-windows "一键切换至 Windows｜设置 BootNext 后立即重启｜高风险" \
            back "返回系统设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            health) run_gui_action "双系统健康检查" bash "$PROJECT_ROOT/modules/dual_system_tools.sh" health ;;
            mount)
                gui_confirm "将自动排除 Windows 系统分区，挂载唯一安全的 NTFS/exFAT 互通盘，并创建快捷入口。是否继续？" && \
                    run_gui_action "挂载互通盘" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" mount
                ;;
            tf-format)
                gui_confirm "将永久清空自动识别出的唯一 TF 卡并格式化为 NTFS；随后仍需输入完整设备名确认。是否继续？" && \
                    run_gui_action "初始化并挂载 TF 卡" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" tf-format-mount
                ;;
            repair-drive)
                gui_confirm "将卸载唯一互通盘并运行 NTFS/exFAT 基础修复；严重 NTFS 错误仍需 Windows chkdsk。是否继续？" && \
                    run_gui_action "修复磁盘写入错误" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" repair-drive
                ;;
            protect)
                gui_confirm "将重新以只读模式挂载互通盘，SteamOS 下无法写入或删除该盘文件。是否继续？" && \
                    run_gui_action "保护双系统互通盘" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" protect
                ;;
            unprotect)
                gui_confirm "将重新以可写模式挂载互通盘，恢复 SteamOS 下的正常读写。是否继续？" && \
                    run_gui_action "恢复互通盘写入" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" unprotect
                ;;
            cleanup-boot)
                gui_confirm "SteamOS、Windows 和 systemd-boot 受保护；其他第三方项仍需输入 Boot 编号和完整删除口令。是否继续？" && \
                    run_gui_action "清理第三方引导项" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" cleanup-boot
                ;;
            repair-boot)
                gui_confirm "将按设备配置安装并修复 Clover 开机菜单、恢复 BootOrder，并启用开机修复服务；会修改 EFI/NVRAM。是否继续？" && \
                    run_gui_action "修复双系统引导" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" install
                ;;
            switch-to-windows)
                gui_confirm "将设置 BootNext 到 Windows 并立即重启进入 Windows；请先保存所有工作。是否继续？" && \
                    run_gui_action "一键切换至 Windows" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" switch-to-windows
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

steam_accelerator_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "Steamcommunity 302｜加速 Steam 和 GitHub" \
            install "安装或更新 Steamcommunity 302" \
            start "一键开启 Steam + GitHub 加速" \
            launch "打开官方配置界面" \
            reset "重置加速服务" \
            status "查看运行状态" \
            uninstall "安全卸载" \
            back "返回系统设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            install)
                gui_confirm "安装后开启加速会修改网络设置并需要管理员权限。是否继续？" && \
                    run_gui_action "安装Steamcommunity 302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
                ;;
            start)
                gui_confirm "开启加速会修改网络设置并需要管理员权限。是否继续？" && \
                    run_gui_action "开启 Steamcommunity 302 加速" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" enable
                ;;
            launch)
                run_gui_action "打开 Steamcommunity 302 配置界面" \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" launch
                ;;
            reset)
                gui_confirm "将停止并重新启动 Steam + GitHub 后台加速。是否继续？" && \
                    run_gui_action "重置 Steamcommunity 302 加速" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" reset
                ;;
            status)
                run_gui_action "Steamcommunity 302状态" \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status
                ;;
            uninstall)
                gui_confirm "会停止Renkit启动的进程；官方 systemd、hosts、DNS 和证书需按官方程序另行处理。确认继续？" && \
                    run_gui_action "卸载Steamcommunity 302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

steam_optimization_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "SteamOS 掌机优化" \
            download-cache "清理 Steam 下载缓存" \
            performance "查看性能模式建议" \
            shader-cache "清理着色器缓存" \
            back "返回上一级")" || return 0
        case "$choice" in
            download-cache|shader-cache)
                gui_confirm "该操作会清理对应缓存目录，是否继续？" && \
                    run_gui_action "SteamOS掌机优化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam.sh" "$choice"
                ;;
            performance)
                run_gui_action "性能模式建议" bash "$PROJECT_ROOT/modules/steam.sh" performance
                ;;
            back) return 0 ;;
        esac
    done
}

cleanup_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "安全清理" \
            download-cache "清理 Steam 下载残留" \
            shader-cache "清理 Steam 着色器缓存" \
            user-cache "清理 Linux 用户缓存" \
            back "返回上一级")" || return 0
        case "$choice" in
            download-cache|shader-cache|user-cache)
                gui_confirm "清理后相应缓存需要重新生成，是否继续？" && \
                    run_gui_action "系统清理" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clean.sh" "$choice"
                ;;
            back) return 0 ;;
        esac
    done
}

maintenance_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "系统维护｜清理缓存和检查系统" \
            health "系统健康检查｜检查空间和常用环境" \
            diagnose "游戏启动检查｜检查游戏无法启动原因" \
            download-cache "清理下载残留｜删除未完成下载文件｜会删除缓存" \
            shader-cache "清理着色器缓存｜释放空间并自动重建｜会删除缓存" \
            user-cache "清理用户缓存｜清理可重新生成的缓存｜会删除缓存" \
            performance "查看性能建议｜查看推荐性能设置" \
            fix "常见问题处理｜检测网络并清理下载残留｜会删除缓存" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            health) run_gui_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            diagnose) run_gui_action "游戏启动检查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            download-cache|shader-cache|user-cache)
                gui_confirm "该操作会删除可重新生成的缓存，是否继续？" && \
                    run_gui_action "清理缓存" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clean.sh" "$choice"
                ;;
            performance) run_gui_action "查看性能建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            fix)
                gui_confirm "将检查网络状态并清理 Steam 未完成的下载残留，是否继续？" && \
                    run_gui_action "常见问题处理" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/fixall.sh"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

help_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "使用帮助与设置｜默认显示结果，需要时再看详细信息" \
            system-info "查看系统信息｜查看系统和设备信息" \
            diagnostic-bundle "生成诊断包｜可直接发给维护人员，不包含密码和隐私信息" \
            new-guide "新手使用指南｜查看基础操作说明" \
            game-guide "游戏兼容指南｜查看游戏运行建议" \
            shortcuts "掌机常用快捷键｜查看常用按键方法" \
            peripherals "外接设备检查｜检查显示器和蓝牙" \
            backup-settings "备份Renkit设置｜只备份Renkit管理的内容" \
            restore-settings "恢复Renkit设置｜先列出内容并备份当前状态" \
            network-details "查看详细网络信息｜查看各条连接的技术详情" \
            report "导出旧版文字报告｜兼容旧排查流程" \
            records "操作记录｜导出最近Renkit记录" \
            changelog "更新日志｜查看版本改动内容" \
            update "检查并更新Renkit｜下载并安装最新版本｜会联网并更新" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            system-info) run_gui_action "查看系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            diagnostic-bundle) run_gui_action "生成诊断包" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            report) run_gui_action "导出诊断报告" bash "$PROJECT_ROOT/core/detect.sh" --report ;;
            backup-settings) run_gui_action "备份Renkit设置" bash "$PROJECT_ROOT/modules/settings_backup.sh" backup ;;
            restore-settings) run_gui_action "恢复Renkit设置" bash "$PROJECT_ROOT/modules/settings_backup.sh" restore ;;
            network-details) run_gui_action "详细网络信息" bash "$PROJECT_ROOT/modules/network.sh" --details ;;
            new-guide) run_gui_action "新手使用指南" bash "$PROJECT_ROOT/modules/safety_center.sh" guide ;;
            game-guide) run_gui_action "游戏兼容指南" bash "$PROJECT_ROOT/modules/game_guides.sh" show ;;
            shortcuts) run_gui_action "掌机常用快捷键" bash "$PROJECT_ROOT/modules/handheld_helper.sh" shortcuts ;;
            peripherals) run_gui_action "外接设备检查" bash "$PROJECT_ROOT/modules/handheld_helper.sh" peripherals ;;
            records) run_gui_action "操作记录" bash "$PROJECT_ROOT/modules/safety_center.sh" records ;;
            changelog) gui_dialog --textbox "$PROJECT_ROOT/CHANGELOG.md" 900 650 ;;
            update)
                gui_confirm "将联网下载经过校验的新版本并替换当前Renkit，是否继续？" && \
                    run_gui_action "检查并更新Renkit" bash "$PROJECT_ROOT/update.sh"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

new_machine_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "新机必备｜第一次使用从这里开始" \
            recommended "推荐软件安装｜选择需要的常用软件" \
            advanced-init "新机初始化｜连续安装并配置新机器" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            recommended) software_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            advanced-init)
                gui_confirm "新机初始化会完整更新系统组件、配置国内源，再安装多项常用软件、Decky 和 ToDesk。请先在游戏模式开启“启用开发者模式”“使用旧版X11桌面模式”和“CEF远程调试”，再确认继续。" && \
                    run_gui_action "新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/new_machine.sh"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

support_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "检查与维护｜检查网络与常见问题，按结果处理或发给维护人员" \
            network-status "一键检查网络｜自动检查常用下载连接，不修改设置" \
            maintenance "检查常见问题｜检查系统、游戏和可安全清理的内容" \
            source-status "查看下载状态｜查看最近成功时间和失败原因" \
            diagnostic-bundle "发给维护人员｜生成诊断包，不包含密码和隐私信息" \
            help "使用帮助与设置｜查看指南、备份设置和Renkit更新" \
            manage-advanced "更多设置｜管理国内下载和加速功能" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            network-status) run_gui_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            maintenance) maintenance_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            source-status) run_gui_action "查看下载状态" bash "$PROJECT_ROOT/modules/diagnostics.sh" status ;;
            diagnostic-bundle) run_gui_action "发给维护人员" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            help) help_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            manage-advanced) advanced_tools_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

domestic_source_gui_preflight() {
    local choice

    choice="$(gui_dialog --menu "初始化国内源并检测系统组件｜Flatpak 缓存关闭 GPG；archlinuxcn 保持 GPG 验证" \
        configure "初始化国内源并检测系统组件｜完整更新系统组件，配置 locale 与国内缓存" \
        restore "恢复官方软件源｜恢复 Flathub 并移除Renkit archlinuxcn" \
        back "返回系统设置")" || return 0
    case "$choice" in
        configure)
            gui_confirm "将初始化国内源并检测系统组件：会完整更新系统组件（pacman -Syyu）、重装 archlinux/archlinuxcn 密钥环、修改 Flatpak 软件源、关闭 Flatpak 国内缓存的 GPG 验证、生成中英文 locale，并临时关闭 SteamOS 只读保护。

pacman 仓库：archlinuxcn
地址：https://mirrors.ustc.edu.cn/archlinuxcn/\$arch
备用：https://mirror.sjtu.edu.cn/archlinux-cn/\$arch → https://mirrors.ustc.edu.cn/archlinuxcn/\$arch → https://repo.archlinuxcn.org/\$arch
验证：安装并加载 archlinuxcn-keyring，保持软件包 GPG 验证；三条线路均失败时撤销该仓库并继续 Flatpak

远程名称：flathub-cn
地址：https://mirror.sjtu.edu.cn/flathub

备用名称：flathub-ustc
地址：https://mirrors.ustc.edu.cn/flathub

确认信任以上镜像并继续？" && \
                run_gui_action "初始化国内源并检测系统组件" env ZHOUKEER_AUTO_CONFIRM=1 \
                bash "$PROJECT_ROOT/modules/domestic_source.sh" init
            ;;
        restore)
            gui_confirm "将恢复 https://dl.flathub.org/repo/，重新启用 GPG 验证，移除两个 Flatpak 国内缓存，并移除Renkit管理的 archlinuxcn 配置。用户原有 archlinuxcn 配置不会删除。确认继续？" && \
                run_gui_action "恢复官方软件源" env ZHOUKEER_AUTO_CONFIRM=1 \
                bash "$PROJECT_ROOT/modules/domestic_source.sh" restore
            ;;
    esac
}

memory_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "虚拟内存｜优化、查看或撤销Renkit设置" \
            optimize "一键优化｜设置 zram 与磁盘 swap" \
            status "查看状态" \
            restore "撤销Renkit优化｜保留系统原 swap" \
            back "返回更多设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            optimize)
                gui_confirm "将设置 zram、磁盘 swap 和 swappiness；失败时自动恢复。确认继续？" && \
                    run_gui_action "一键优化虚拟内存" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/memory_tuning.sh" optimize
                return 0
                ;;
            status)
                run_gui_action "虚拟内存状态" bash "$PROJECT_ROOT/modules/memory_tuning.sh" status
                return 0
                ;;
            restore)
                gui_confirm "只删除Renkit创建的配置和独立 swap；系统原 swap 会保留。确认撤销？" && \
                    run_gui_action "撤销Renkit虚拟内存优化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/memory_tuning.sh" restore
                return 0
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

f1_screen_fix_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "掌机适配｜飞行家 F1 屏幕方向修复" \
            install "安装修复｜仅适用于 ONEXPLAYER F1｜不使用 sudo" \
            status "检查状态｜查看修复文件和 systemd override" \
            uninstall "卸载修复｜删除用户级修复并恢复原始启动方式" \
            reboot "立即重启 SteamOS｜重启后生效｜请先保存工作" \
            back "返回更多设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            install)
                gui_confirm "仅适用于 ONEXPLAYER F1；将创建用户级 gamescope wrapper 和 systemd override，不使用 sudo。确认继续？" && \
                    run_gui_action "安装飞行家 F1 屏幕方向修复" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" install
                return 0
                ;;
            status)
                run_gui_action "飞行家 F1 屏幕方向修复状态" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" status
                return 0
                ;;
            uninstall)
                gui_confirm "将删除用户级修复文件并刷新 systemd，不使用 sudo；重启后恢复原始启动方式。确认继续？" && \
                    run_gui_action "卸载飞行家 F1 屏幕方向修复" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" uninstall
                return 0
                ;;
            reboot)
                gui_confirm "将立即重启 SteamOS；请先保存所有工作。确认继续？" && \
                    run_gui_action "立即重启 SteamOS" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" reboot
                return 0
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

advanced_tools_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "更多设置｜国内下载、网络加速、内存、密码与双系统" \
            domestic-source "国内软件源｜会修改 Flatpak 软件源｜高级操作" \
            accelerator "Steamcommunity 302｜可能修改 DNS 和证书｜高级操作" \
            memory "虚拟内存｜设置 zram、swap 或撤销｜高级操作" \
            change-password "修改管理员密码｜会更换 SteamOS 管理密码｜高级操作" \
            dual "双系统与互通盘｜管理磁盘和开机菜单｜高级操作" \
            handheld "掌机适配｜飞行家 F1 屏幕方向修复｜不使用 sudo" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            domestic-source) domestic_source_gui_preflight ;;
            accelerator) steam_accelerator_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            memory) memory_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            change-password)
                gui_confirm "将读取旧记录并明文保存新密码；当前用户运行的软件都可能读取。确认继续？" && \
                    run_gui_action "修改管理员密码" bash "$PROJECT_ROOT/modules/password.sh" change
                ;;
            dual) dual_system_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            handheld) f1_screen_fix_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

uninstall_software_gui_menu() {
    local choice page=0 target

    while true; do
        case "$page" in
            0)
                choice="$(gui_dialog --menu "卸载已安装｜聊天、浏览器与远程工具｜第 1/7 页" \
                    wechat "卸载微信｜AppImage 和快捷方式" \
                    qq "卸载 QQ｜Flatpak" \
                    browser "卸载 Firefox｜Flatpak" \
                    chrome "卸载 Chrome｜Google Chrome Flatpak" \
                    edge "卸载 Edge｜Microsoft Edge Flatpak" \
                    rustdesk "卸载 RustDesk｜保留用户配置" \
                    todesk "卸载 ToDesk｜停止服务并卸载软件包｜高级操作" \
                    baidunetdisk "卸载百度网盘｜Flatpak" \
                    next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            1)
                choice="$(gui_dialog --menu "卸载已安装｜办公与创作｜第 2/7 页" \
                    anydesk "卸载 AnyDesk｜Flatpak" \
                    willwill "卸载 WiliWili｜Flatpak 与 Steam 条目" \
                    xbox-cloud "卸载 Xbox 云游戏｜Greenlight Flatpak" \
                    libreoffice "卸载 LibreOffice｜Flatpak" \
                    vlc "卸载 VLC｜Flatpak" \
                    obs "卸载 OBS Studio｜Flatpak" \
                    localsend "卸载 LocalSend｜Flatpak" \
                    peazip "卸载 PeaZip｜Flatpak" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            2)
                choice="$(gui_dialog --menu "卸载已安装｜兼容、音乐与下载｜第 3/7 页" \
                    fcitx5 "卸载中文输入法｜Fcitx5 与中文输入插件" \
                    protontricks "卸载 Protontricks｜Flatpak" \
                    bottles "卸载 Bottles｜Flatpak" \
                    qqmusic "卸载 QQ音乐｜Flatpak" \
                    netease-music "卸载网易云音乐｜Flatpak" \
                    yesplaymusic "卸载 YesPlayMusic｜Flatpak" \
                    qbittorrent "卸载 qBittorrent｜Flatpak" \
                    motrix "卸载 Motrix 下载器｜Flatpak" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            3)
                choice="$(gui_dialog --menu "卸载已安装｜下载、办公、笔记与串流｜第 4/7 页" \
                    freedownloadmanager "卸载 Free Download Manager｜Flatpak" \
                    media-downloader "卸载 Media Downloader｜Flatpak" \
                    flameshot "卸载 Flameshot 截图｜Flatpak" \
                    onlyoffice "卸载 OnlyOffice｜Flatpak" \
                    joplin "卸载 Joplin 笔记｜Flatpak" \
                    heroic "卸载 Heroic｜移除 Steam 库条目" \
                    lutris "卸载 Lutris｜移除 Steam 库条目" \
                    chiaki4deck "卸载 Chiaki4Deck｜移除 Steam 库条目" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            4)
                choice="$(gui_dialog --menu "卸载已安装｜游戏启动器与模拟器｜第 5/7 页" \
                    parsec "卸载 Parsec｜移除 Steam 库条目" \
                    battlenet "卸载战网启动器｜保留游戏与下载文件" \
                    epic "卸载 Epic｜保留游戏与下载文件" \
                    ubisoft "卸载育碧｜保留游戏与下载文件" \
                    heihe "卸载黑盒工坊｜保留插件与游戏文件" \
                    yuzu "卸载 Yuzu｜保留存档与配置" \
                    cemu "卸载 Cemu｜保留存档与配置" \
                    duckstation "卸载 DuckStation｜保留存档与配置" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            5)
                choice="$(gui_dialog --menu "卸载已安装｜模拟器与系统组件｜第 6/7 页" \
                    pcsx2 "卸载 PCSX2｜保留存档与配置" \
                    rpcs3 "卸载 RPCS3｜保留存档与配置" \
                    shadps4 "卸载 ShadPS4｜保留存档与配置" \
                    ppsspp "卸载 PPSSPP｜保留存档与配置" \
                    mgba "卸载 mGBA｜保留存档与配置" \
                    azahar "卸载 Azahar｜保留 3DS 存档与密钥" \
                    steam302 "卸载 Steam302｜停止后台加速和自启｜高级操作" \
                    ge-proton "卸载 GE-Proton｜只删Renkit当前版本" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            *)
                choice="$(gui_dialog --menu "卸载已安装｜Decky 组件｜第 7/7 页" \
                    decky-loader "卸载 Decky Loader｜保留插件文件" \
                    decky-plugins "清空全部 Decky 插件｜删除插件与设置｜高风险" \
                    previous "上一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
        esac
        case "$choice" in
            wechat|qq|browser|chrome|edge|rustdesk|anydesk|baidunetdisk|willwill|xbox-cloud|libreoffice|vlc|obs|localsend|peazip|fcitx5|protontricks|bottles|qqmusic|netease-music|yesplaymusic|qbittorrent|motrix|freedownloadmanager|media-downloader|flameshot|onlyoffice|joplin|heroic|lutris|chiaki4deck|parsec)
                target="$choice"
                gui_confirm "只卸载所选软件及Renkit创建的快捷方式，确认继续？" && \
                    run_gui_action "卸载软件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" uninstall "$target"
                ;;
            battlenet|epic|ubisoft|heihe)
                target="$choice"
                gui_confirm "会移除 Steam 库条目和桌面入口，保留游戏与下载文件。确认继续？" && \
                    run_gui_action "卸载游戏启动器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" uninstall "$target"
                ;;
            yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                target="$choice"
                gui_confirm "会移除 Steam 库条目和桌面入口，保留存档与配置。确认继续？" && \
                    run_gui_action "卸载模拟器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/emulators.sh" uninstall "$target"
                ;;
            todesk)
                gui_confirm "会停止 ToDesk 服务并临时关闭 SteamOS 只读保护，完成后自动恢复。确认继续？" && \
                    run_gui_action "卸载 ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --uninstall
                ;;
            steam302)
                gui_confirm "会停止后台加速并移除开机自启，确认继续？" && \
                    run_gui_action "卸载 Steam302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            ge-proton)
                gui_confirm "只删除Renkit当前 GE-Proton 版本，确认继续？" && \
                    run_gui_action "卸载 GE-Proton" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" uninstall
                ;;
            decky-loader)
                gui_confirm "会停止 Decky Loader，但保留全部插件文件与设置。确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" store-uninstall
                ;;
            decky-plugins)
                gui_confirm "会删除全部 Decky 插件和插件设置，但保留加载器。确认继续？" && \
                    run_gui_action "清空全部 Decky 插件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" uninstall
                ;;
            next) page=$((page + 1)); [ "$page" -le 6 ] || page=6 ;;
            previous) page=$((page - 1)); [ "$page" -ge 0 ] || page=0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

main_gui_menu() {
    local choice

    while true; do
        GUI_NAV_HOME=0
        choice="$(gui_dialog --menu "请用触屏或触控板选择功能" \
            nav-init "新机器设置｜第一次使用从这里开始" \
            nav-software "安装常用软件｜聊天、浏览器和远程工具" \
            nav-games "游戏与插件｜浏览插件商城和游戏组件" \
            nav-emulators "模拟器｜Switch、Wii U、PS1 至 3DS 模拟器" \
            nav-check "检查与维护｜检查网络、常见问题并生成诊断包" \
            nav-advanced "更多设置｜国内下载、内存、密码和双系统" \
            nav-uninstall "卸载已安装｜逐项安全移除软件和系统组件" \
            nav-notice "免责声明与使用须知｜查看完整图文说明" \
            nav-exit "退出Renkit")" || exit 0

        case "$choice" in
            nav-init) new_machine_gui_menu ;;
            nav-software) software_menu ;;
            nav-games) game_environment_gui_menu ;;
            nav-emulators) emulator_gui_menu ;;
            nav-check) support_gui_menu ;;
            nav-advanced) advanced_tools_gui_menu ;;
            nav-uninstall) uninstall_software_gui_menu ;;
            nav-notice)
                gui_dialog --yesno "请确认已阅读首次启动页的免责声明。\n\nRenkit不包含付费软件、破解、ROM、BIOS 或密钥；涉及下载、安装、权限或磁盘的操作都会另行提示并确认。\n\n点击“我已阅读并知悉”会关闭本页并返回首页。" \
                    --yes-label "我已阅读并知悉" --no-label "返回首页"
                ;;
            nav-exit) exit 0 ;;
        esac
    done
}

ensure_gui_password_ready() {
    local choice

    if load_toolbox_password >/dev/null 2>&1; then
        TOOLBOX_PASSWORD=""
        unset TOOLBOX_PASSWORD
        return 0
    fi

    while true; do
        choice="$(gui_dialog --menu "首次使用必须先准备管理员密码记录，但不会强制修改已有密码。" \
            import "我已有管理员密码｜输入一次并保存到桌面" \
            set "我还没有管理员密码｜按系统提示设置新密码" \
            exit "退出Renkit")" || exit 0
        case "$choice" in
            import) run_gui_action "录入现有管理员密码" bash "$PROJECT_ROOT/modules/password.sh" import ;;
            set) run_gui_action "设置管理员密码" bash "$PROJECT_ROOT/modules/password.sh" set ;;
            exit) exit 0 ;;
        esac
        if load_toolbox_password >/dev/null 2>&1; then
            TOOLBOX_PASSWORD=""
            unset TOOLBOX_PASSWORD
            return 0
        fi
    done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    if ! command -v kdialog >/dev/null 2>&1; then
        echo "未找到 kdialog，无法启动图形菜单。"
        exit 1
    fi

    ensure_gui_password_ready
    main_gui_menu
fi
