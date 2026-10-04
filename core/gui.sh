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
    "PowerTools" "Storage Cleaner" "AutoFlatpaks" "Bluetooth"
    "Deck Settings" "HLTB for Deck" "PlayCount" "TabMaster"
    "Wine Cellar" "Pause Games" "Controller Tools" "Volume Mixer" "Battery Tracker"
    "PlayTime" "Free Loader" "DeckMTP" "MangoPeel"
    "Freedeck"
)
DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS=(
    "自定义界面样式" "调整界面配色" "更换开机动画" "更换系统音效" "自动补游戏封面"
    "性能与功耗控制" "清理游戏缓存" "自动更新应用" "管理蓝牙设备"
    "更多掌机设置" "显示通关时长" "记录游玩次数" "整理游戏库标签"
    "管理 Windows 游戏运行工具" "后台自动暂停游戏" "手柄辅助工具" "分应用调节音量" "查看电池状态"
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
        ZHOUKEER_PROGRESS_DIRECT_TTY=1 "$@" 2>&1 | tee "$action_log"
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
            rustdesk "RustDesk 远程协助｜让别人远程操作这台机器，协助解决问题" \
            anydesk "AnyDesk 远程协助｜让别人远程操作这台机器，协助解决问题" \
            todesk "ToDesk 远程协助｜安装前需完成系统设置" \
            bottles "Windows 软件工具｜运行 Windows 软件和游戏" \
            baidunetdisk "百度网盘｜上传、下载和管理百度网盘文件" \
            libreoffice "LibreOffice 办公套件｜编辑文档、表格和演示文稿" \
            vlc "VLC 播放器｜播放视频和音乐" \
            obs "OBS Studio｜录制屏幕和直播" \
            localsend "LocalSend 局域网传文件｜在同一 Wi-Fi 下与手机、电脑互传文件" \
            peazip "PeaZip 压缩工具｜压缩和解压文件" \
            willwill "WiliWili｜观看 B 站视频，安装后可从 Steam 打开" \
            fcitx5 "中文输入法｜用拼音等方式输入中文" \
            xbox-cloud "Xbox 云游戏｜在线游玩 Xbox 游戏，需要 Xbox 账号及相应订阅" \
            qqmusic "QQ音乐｜听 QQ 音乐" \
            netease-music "网易云音乐｜听网易云音乐" \
            yesplaymusic "YesPlayMusic｜用另一款播放器听网易云音乐" \
            qbittorrent "qBittorrent｜下载种子文件和磁力链接" \
            motrix "Motrix 下载器｜管理下载任务，支持种子和磁力链接" \
            freedownloadmanager "Free Download Manager｜管理下载任务" \
            media-downloader "Media Downloader｜下载视频和音频" \
            flameshot "Flameshot 截图｜截图、画箭头和添加文字" \
            onlyoffice "OnlyOffice 办公套件｜编辑 Office 文档、表格和演示文稿" \
            joplin "Joplin 笔记｜记录笔记和待办事项" \
            heroic "Heroic 游戏启动器｜安装和管理 Epic、GOG 游戏，安装后可从 Steam 打开" \
            lutris "Lutris｜集中安装和管理多个平台的游戏" \
            chiaki4deck "Chiaki4Deck（PS5串流）｜在掌机上远程游玩自己的 PS5 游戏" \
            parsec "Parsec｜远程游玩电脑游戏" \
            sunshine "Sunshine 游戏画面共享｜把这台机器的画面传到其他设备游玩；会使用管理员权限配置手柄和键鼠控制" \
            protontricks "游戏兼容设置｜为打不开的 Windows 游戏补充所需组件" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            wechat)
                gui_confirm "将安装微信，用于聊天和收发文件，并创建桌面图标。是否继续？" && \
                    run_gui_action "安装微信" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" wechat
                ;;
            qq)
                gui_confirm "将安装 QQ，用于聊天和收发文件。是否继续？" && \
                    run_gui_action "安装QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" qq
                ;;
            browser)
                gui_confirm "将安装 Firefox，用于浏览网页。是否继续？" && \
                    run_gui_action "安装 Firefox 浏览器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" browser
                ;;
            chrome) gui_confirm "将安装此工具，用于浏览网页、搜索资料和下载文件。是否继续？" && run_gui_action "安装 Google Chrome" bash "$PROJECT_ROOT/modules/software.sh" chrome ;;
            edge) gui_confirm "将安装此工具，用于浏览网页、搜索资料和下载文件。是否继续？" && run_gui_action "安装 Microsoft Edge" bash "$PROJECT_ROOT/modules/software.sh" edge ;;
            rustdesk)
                gui_confirm "将安装 RustDesk，用于远程协助，并创建桌面图标。是否继续？" && \
                    run_gui_action "安装 RustDesk 远程协助" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" rustdesk
                ;;
            anydesk) gui_confirm "将安装此工具，用于让别人远程操作这台机器，协助解决问题。是否继续？" && run_gui_action "安装 AnyDesk 远程协助" bash "$PROJECT_ROOT/modules/software.sh" anydesk ;;
            todesk)
                gui_confirm "ToDesk 会使用管理员权限并临时修改 SteamOS 只读系统。请先在游戏模式开启开发者模式和旧版 X11 桌面模式。确认继续？" && \
                    run_gui_action "安装 ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --install
                ;;
            baidunetdisk) gui_confirm "将安装此工具，用于上传、下载和管理百度网盘文件。是否继续？" && run_gui_action "安装百度网盘" bash "$PROJECT_ROOT/modules/software.sh" baidunetdisk ;;
            libreoffice) gui_confirm "将安装此工具，用于编辑文档、表格和演示文稿。是否继续？" && run_gui_action "安装 LibreOffice 办公套件" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" libreoffice ;;
            vlc) gui_confirm "将安装此工具，用于播放视频和音乐。是否继续？" && run_gui_action "安装 VLC 播放器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" vlc ;;
            obs) gui_confirm "将安装此工具，用于录制屏幕和直播。是否继续？" && run_gui_action "安装 OBS Studio" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" obs ;;
            localsend) gui_confirm "将安装此工具，用于在同一 Wi-Fi 下与手机、电脑互传文件。是否继续？" && run_gui_action "安装 LocalSend 局域网传文件" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" localsend ;;
            peazip) gui_confirm "将安装此工具，用于压缩和解压文件。是否继续？" && run_gui_action "安装 PeaZip 压缩工具" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" peazip ;;
            willwill) gui_confirm "将安装此工具，用于观看 B 站视频，安装后可从 Steam 打开。是否继续？" && run_gui_action "安装 WiliWili" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" willwill ;;
            fcitx5) gui_confirm "将安装此工具，用于用拼音等方式输入中文。是否继续？" && run_gui_action "安装中文输入法" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" fcitx5 ;;
            xbox-cloud) gui_confirm "将安装此工具，用于在线游玩 Xbox 游戏，需要 Xbox 账号及相应订阅。是否继续？" && run_gui_action "安装 Xbox 云游戏" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" xbox-cloud ;;
            qqmusic) gui_confirm "将安装此工具，用于听 QQ 音乐。是否继续？" && run_gui_action "安装 QQ音乐" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" qqmusic ;;
            netease-music) gui_confirm "将安装此工具，用于听网易云音乐。是否继续？" && run_gui_action "安装网易云音乐" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" netease-music ;;
            yesplaymusic) gui_confirm "将安装此工具，用于用另一款播放器听网易云音乐。是否继续？" && run_gui_action "安装 YesPlayMusic" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" yesplaymusic ;;
            qbittorrent) gui_confirm "将安装此工具，用于下载种子文件和磁力链接。是否继续？" && run_gui_action "安装 qBittorrent" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" qbittorrent ;;
            motrix) gui_confirm "将安装此工具，用于管理下载任务，支持种子和磁力链接。是否继续？" && run_gui_action "安装 Motrix 下载器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" motrix ;;
            freedownloadmanager) gui_confirm "将安装此工具，用于管理下载任务。是否继续？" && run_gui_action "安装 Free Download Manager" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" freedownloadmanager ;;
            media-downloader) gui_confirm "将安装此工具，用于下载视频和音频。是否继续？" && run_gui_action "安装 Media Downloader" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" media-downloader ;;
            flameshot) gui_confirm "将安装此工具，用于截图、画箭头和添加文字。是否继续？" && run_gui_action "安装 Flameshot 截图" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" flameshot ;;
            onlyoffice) gui_confirm "将安装此工具，用于编辑 Office 文档、表格和演示文稿。是否继续？" && run_gui_action "安装 OnlyOffice 办公套件" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" onlyoffice ;;
            joplin) gui_confirm "将安装此工具，用于记录笔记和待办事项。是否继续？" && run_gui_action "安装 Joplin 笔记" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" joplin ;;
            heroic) gui_confirm "将安装此工具，用于安装和管理 Epic、GOG 游戏，安装后可从 Steam 打开。是否继续？" && run_gui_action "安装 Heroic 游戏启动器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" heroic ;;
            lutris) gui_confirm "将安装此工具，用于集中安装和管理多个平台的游戏。是否继续？" && run_gui_action "安装 Lutris" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" lutris ;;
            chiaki4deck) gui_confirm "将安装此工具，用于在掌机上远程游玩自己的 PS5 游戏。是否继续？" && run_gui_action "安装 Chiaki4Deck（PS5串流）" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" chiaki4deck ;;
            parsec) gui_confirm "将安装此工具，用于远程游玩电脑游戏。是否继续？" && run_gui_action "安装 Parsec" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" parsec ;;
            sunshine) gui_confirm "将安装此工具，用于把这台机器的画面传到其他设备游玩；会使用管理员权限配置手柄和键鼠控制。是否继续？" && run_gui_action "安装 Sunshine 游戏画面共享" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/software.sh" sunshine ;;
            protontricks) gui_confirm "将安装此工具，用于为打不开的 Windows 游戏补充所需组件。是否继续？" && run_gui_action "安装游戏修复工具（Protontricks）" bash "$PROJECT_ROOT/modules/software.sh" protontricks ;;
            bottles) gui_confirm "将安装此工具，用于运行 Windows 软件和游戏。是否继续？" && run_gui_action "安装 Bottles" bash "$PROJECT_ROOT/modules/software.sh" bottles ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

remote_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "选择远程协助工具" \
            rustdesk "安装 RustDesk 远程协助" \
            todesk "ToDesk" \
            back "返回主菜单")" || return 0
        case "$choice" in
            rustdesk)
                gui_confirm "将安装 RustDesk，用于远程协助，并创建桌面图标。是否继续？" && \
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

trainer_ge_proton_gui_menu() {
    local choice version

    while true; do
        choice="$(gui_dialog --menu "修改器运行工具｜选择单个版本或全部安装" \
            trainer-7-55 "安装 GE-Proton 7-55｜只安装此版本" \
            trainer-8-25 "安装 GE-Proton 8-25｜只安装此版本" \
            trainer-9-27 "安装 GE-Proton 9-27｜只安装此版本" \
            trainer-10-29 "安装 GE-Proton 10-29｜只安装此版本" \
            trainer-all "安装全部四个运行工具｜原一键安装功能，约1.72GB" \
            back "返回 GE 兼容层" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            trainer-7-55|trainer-8-25|trainer-9-27|trainer-10-29)
                version="${choice#trainer-}"
                gui_confirm "将只安装所选的 GE 兼容层，不下载其他版本。是否继续？" && \
                    run_gui_action "安装 GE-Proton $version" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install-trainer-one "$version"
                ;;
            trainer-all)
                gui_confirm "将安装 GE-Proton 7-55、8-25、9-27、10-29 四个修改器常用运行工具；合计约1.72GB，下载较慢为正常现象。是否继续？" && \
                    run_gui_action "安装全部四个修改器运行工具" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install-trainer
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

ge_proton_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "GE 兼容层｜选择需要的版本" \
            latest "安装最新 GE 兼容层｜帮助运行 Windows 游戏，保留已有版本" \
            trainer "安装修改器常用运行工具｜四个版本约1.72GB，下载较慢为正常现象" \
            cachyos "安装 Proton-CachyOS｜另一款运行 Windows 游戏的工具" \
            back "返回游戏与插件" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            latest)
                gui_confirm "将自动检测并安装最新 GE-Proton，不会删除已安装的旧版 GE 兼容层。是否继续？" && \
                    run_gui_action "安装最新 GE 兼容层" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install
                ;;
            trainer)
                trainer_ge_proton_gui_menu
                [ "$GUI_NAV_HOME" -eq 0 ] || return 0
                ;;
            cachyos)
                gui_confirm "将安装另一款运行 Windows 游戏的工具，保留现有版本。是否继续？" && \
                    run_gui_action "安装 Proton-CachyOS" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/proton_cachyos.sh" install
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
    local feature_choice
    local handheld_plugin_choice
    local game_info_choice
    local lsfg_choice
    local repair_choice

    while true; do
        choice="$(gui_dialog --menu "游戏与插件｜插件商城" \
            features "常用插件组合｜两版小黄鸭、FSR4、Fantastic等九款插件" \
            all "常用插件加精选插件｜优先安装九款常用插件，已装则跳过；再补精选" \
            feature-singles "其余常用插件｜封面、主题、Fantastic等插件单独安装" \
            lsfg "小黄鸭｜让游戏画面更流畅｜汉化：RenAmamiya" \
            fsr4 "FSR4｜改善支持游戏的画面｜请先阅读使用说明" \
            browse "浏览官方插件｜逐个查看插件作用" \
            freedeck "Freedeck｜选择 0.6 稳定版或 NewFreedeck" \
            handheld-plugins "掌机控制插件｜掌机功耗控制与 ROG Ally Center" \
            ge-proton "安装 GE 兼容层｜提高 Windows 游戏兼容性" \
            epic "Epic 游戏启动器｜安装并添加到 Steam" \
            tomoon "ToMoon｜在游戏模式管理网络连接和加速设置" \
            battlenet "战网启动器｜安装战网并添加到 Steam，方便下载和游玩暴雪游戏" \
            ubisoft "育碧｜安装育碧游戏平台并添加到 Steam" \
            hmcl "HMCL 启动器｜安装和启动 Minecraft，并自动准备运行所需组件" \
            repair "修复启动器封面｜重写 Steam 库封面并重启 Steam" \
            deckrecall "DeckRecall｜添加游戏到 Steam，并恢复游戏启动设置" \
            savepulse "SavePulse｜自动备份游戏存档，支持自己的坚果云或其他网盘，方便换机恢复" \
            game-info-tools "SteamDB 游戏数据｜价格史低与在线峰值" \
            decky-install "安装插件商城｜给游戏模式增加插件功能｜可选测试版" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            features)
                gui_confirm "请先在游戏模式：Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，完成后重新进入桌面模式。未安装插件商城时会先安装插件商城，再继续安装九款常用插件（含 MAKO）。Fantastic 会覆盖默认风扇曲线；会使用管理员权限。是否继续？" && \
                    run_gui_action "安装常用插件组合" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" features
                ;;
            all)
                gui_confirm "请先在游戏模式：Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，完成后重新进入桌面模式。未安装插件商城时会先安装插件商城，再继续安装常用与精选插件；会使用管理员权限。是否继续？" && \
                    run_gui_action "安装常用插件加精选插件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" all
                ;;
            feature-singles)
                feature_choice="$(gui_dialog --menu "其余常用插件｜可分别安装" \
                    steamgriddb "游戏封面更换｜SteamGridDB｜更换 Steam 游戏封面" \
                    cssloader "主题美化｜CSS Loader 中文版｜更换游戏模式的界面主题和样式" \
                    friendeck "文件传输助手｜Friendeck｜在掌机和其他设备之间传文件" \
                    deckymusic "音乐播放器｜Decky Music v1.0.2 完整包｜在游戏模式听音乐，支持 QQ 音乐和网易云音乐" \
                    fantastic "Fantastic 风扇控制｜完整汉化版｜汉化：RenAmamiya｜注意温度" \
                    back "返回游戏与插件")" || continue
                case "$feature_choice" in
                    steamgriddb) run_gui_action "安装游戏封面更换" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" steamgriddb ;;
                    cssloader) run_gui_action "安装主题美化" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" cssloader ;;
                    friendeck) run_gui_action "安装文件传输助手" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" friendeck ;;
                    deckymusic) run_gui_action "安装音乐播放器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" deckymusic ;;
                    fantastic)
                        gui_confirm "高风险：Fantastic 会覆盖 SteamOS 默认风扇曲线，过低转速可能导致设备过热；仅适用于 Steam Deck。将直接安装带 RenAmamiya 署名的完整汉化包，是否继续？" && \
                            run_gui_action "安装 Fantastic 风扇控制" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" fantastic
                        ;;
                esac
                ;;
            lsfg)
                lsfg_choice="$(gui_dialog --menu "小黄鸭版本选择" \
                    stable "小黄鸭 1.0｜v0.12.8 汉化版·稳定" \
                    v2 "小黄鸭 2.0｜仅正版小黄鸭用户用｜覆盖 1.0 小黄鸭｜可与 MAKO 共存" \
                    mako "MAKO 小黄鸭｜让游戏画面更流畅｜自动检查新版本｜中文界面" \
                    back "返回游戏与插件")" || continue
                case "$lsfg_choice" in
                    stable)
                        run_gui_action "安装小黄鸭 1.0" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-zh-gitee
                        ;;
                    v2)
                        gui_confirm "小黄鸭 2.0 可让游戏画面更流畅；仅供正版小黄鸭用户使用；会替换 1.0，小黄鸭 1.0 和 2.0 只保留一个，可与 MAKO 一起保留。是否继续？" && \
                            run_gui_action "安装小黄鸭 2.0" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-v2
                        ;;
                    mako)
                        gui_confirm "将安装或更新 MAKO，让游戏画面更流畅。请按桌面使用说明完成设置。是否继续？" && \
                            run_gui_action "安装或更新 MAKO 小黄鸭" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-mako
                        ;;
                esac
                ;;
            fsr4)
                run_gui_action "安装 FSR4（画质补丁）" \
                    env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4-zh-gitee
                ;;
            deckrecall)
                run_gui_action "安装 DeckRecall" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" deckrecall
                ;;
            savepulse)
                run_gui_action "安装 SavePulse" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" savepulse
                ;;
            game-info-tools)
                game_info_choice="$(gui_dialog --menu "SteamDB 游戏数据" \
                    steamdb-info "SteamDB 游戏数据｜商店页显示价格史低与在线峰值｜中文版" \
                    back "返回游戏与插件")" || continue
                case "$game_info_choice" in
                    steamdb-info)
                        gui_confirm "将增加游戏历史最低价格和最多同时在线人数查询；需要开启“CEF 远程调试”。是否继续？" && \
                            run_gui_action "安装 SteamDB 游戏数据" env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" steamdb-info
                        ;;
                esac
                ;;
            freedeck)
                freedeck_choice="$(gui_dialog --menu "Freedeck 版本选择" \
                    stable "Freedeck 0.6 稳定版｜现有稳定版本" \
                    new "NewFreedeck｜自动更新到最新版，部分模拟器暂时无法使用" \
                    back "返回游戏与插件")" || continue
                case "$freedeck_choice" in
                    stable)
                        run_gui_action "安装 Freedeck 0.6 稳定版" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" freedeck
                        ;;
                    new)
                        gui_confirm "将自动检测并安装 NewFreedeck 作者最新版；作者说明个别模拟器仍不可用。是否继续？" && \
                            run_gui_action "安装/更新 NewFreedeck" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" newfreedeck
                        ;;
                esac
                ;;
            handheld-plugins)
                handheld_plugin_choice="$(gui_dialog --menu "掌机控制插件" \
                    powercontrol "PowerControl 功耗控制｜调节性能、耗电和风扇转速" \
                    simpledeckytdp "掌机功耗控制｜调节游戏性能和耗电·中文界面" \
                    allycenter "Ally 控制中心｜调节灯光、耗电、风扇和充电上限" \
                    huesync "通用掌机灯光｜调节掌机灯光·中文界面" \
                    legiongo-remapper "Legion Go 控制中心｜初代 Legion Go 按键、RGB、充电与风扇" \
                    gpd-control "GPD 控制中心｜调节灯光，并为每个游戏保存设置" \
                    lego-vibe "Legion Go 震动控制｜Go / Go 2 震动与触控板反馈" \
                    lego2-fan "Legion Go 2 风扇控制｜仅 Go 2·不受限风扇曲线" \
                    onexplayer-tools "OneXPlayer 机型工具｜X2 Mini Pro 亮度修复（已实测）/ Apex 工具" \
                    back "返回游戏与插件")" || continue
                case "$handheld_plugin_choice" in
                    powercontrol)
                        gui_confirm "高风险：调节掌机性能、耗电和风扇，需要管理员权限；仅适用于支持的机型。不要与其他功耗或风扇插件同时启用，设置不当可能导致过热或系统不稳定。是否继续？" && \
                            run_gui_action "安装 PowerControl" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" powercontrol
                        ;;
                    simpledeckytdp)
                        run_gui_action "安装/修复掌机功耗控制汉化版" \
                            env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" simpledeckytdp-zh-gitee
                        ;;
                    allycenter)
                        gui_confirm "Ally Center 仅适用于 ROG Ally / Ally X，可控制摇杆 灯光和耗电、风扇和充电上限，插件需要管理员权限。是否继续？" && \
                            run_gui_action "安装 Ally Center" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" allycenter
                        ;;
                    huesync)
                        gui_confirm "HueSync 官方已内置简体中文，支持多品牌掌机灯光，插件需要管理员权限。请勿与其他灯光插件同时控制同一设备。是否继续？" && \
                            run_gui_action "安装通用掌机灯光" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" huesync
                        ;;
                    legiongo-remapper)
                        gui_confirm "仅适用于初代 Legion Go，不支持 Legion Go S；可控制按键、RGB、80% 充电上限及实验性风扇曲线，需要管理员权限，HHD 可能覆盖灯光设置。是否继续？" && \
                            run_gui_action "安装 Legion Go 控制中心" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" legiongo-remapper
                        ;;
                    gpd-control)
                        gui_confirm "适用于支持的 GPD Win 掌机 灯光，支持按游戏配置，需要管理员权限。是否继续？" && \
                            run_gui_action "安装 GPD 控制中心" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" gpd-control
                        ;;
                    lego-vibe)
                        gui_confirm "适用于 Legion Go / Go 2，不支持 Go S；需要 SteamOS 3.8+、内核 6.18+、hid-lenovo-go 驱动与 管理员权限。是否继续？" && \
                            run_gui_action "安装 Legion Go 震动控制" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" lego-vibe
                        ;;
                    lego2-fan)
                        gui_confirm "高风险：仅适用于 Legion Go 2。此插件允许不受限制的风扇曲线，错误设置可能在高温时使用过低转速并损伤设备；需要管理员权限。确认理解风险后继续？" && \
                            run_gui_action "安装 Legion Go 2 风扇控制" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" lego2-fan
                        ;;
                    onexplayer-tools)
                        onexplayer_tool_choice="$(gui_dialog --menu "OneXPlayer 机型工具" \
                            x2-mini-pro-brightness "X2 Mini Pro 亮度修复｜已实测·游戏模式下的屏幕亮度调节" \
                            apex "OneXPlayer Apex 工具｜仅 Apex·功耗、按键、灯光与休眠修复" \
                            back "返回掌机控制插件")" || continue
                        case "$onexplayer_tool_choice" in
                            x2-mini-pro-brightness)
                                gui_confirm "仅适用于 ONEXPLAYER X2 Mini Pro（388 处理器、三星 AMS881KB01-0 OLED 屏幕）的原版 SteamOS，已实测。可修复开启 HDR 后游戏模式无法调节亮度的问题；首次设置可能短暂黑屏，需要重启游戏模式。不会调整耗电或风扇，已有屏幕设置会先备份。是否继续？" && \
                                    run_gui_action "安装 X2 Mini Pro 亮度修复" \
                                        env ZHOUKEER_AUTO_CONFIRM=1 \
                                        bash "$PROJECT_ROOT/modules/plugin_store.sh" lego2-brightness-fix
                                ;;
                            apex)
                                gui_confirm "高风险：仅适用于 OneXPlayer Apex（Strix Halo）原版 SteamOS。插件以管理员权限修改硬件设置、按键/灯光与休眠相关配置，可能需要重启；请勿与其他功耗、风扇、按键或灯光控制插件同时启用。错误操作可能导致输入失效、休眠异常或系统不稳定。将校验安装包并自动接入 Renkit 汉化。确认理解风险后继续？" && \
                                    run_gui_action "安装 OneXPlayer Apex 工具" \
                                        env ZHOUKEER_AUTO_CONFIRM=1 \
                                        bash "$PROJECT_ROOT/modules/plugin_store.sh" onexplayer-apex
                                ;;
                        esac
                        ;;
                    onexplayer-apex)
                        gui_confirm "高风险：仅适用于 OneXPlayer Apex（Strix Halo）原版 SteamOS。插件以管理员权限修改硬件设置、按键/灯光与休眠相关配置，可能需要重启；请勿与其他功耗、风扇、按键或灯光控制插件同时启用。错误操作可能导致输入失效、休眠异常或系统不稳定。将校验安装包并自动接入 Renkit 汉化。确认理解风险后继续？" && \
                            run_gui_action "安装 OneXPlayer Apex 工具" \
                                env ZHOUKEER_AUTO_CONFIRM=1 \
                                bash "$PROJECT_ROOT/modules/plugin_store.sh" onexplayer-apex
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
                gui_confirm "将在游戏模式增加网络连接和加速设置。是否继续？" && \
                    run_gui_action "安装 ToMoon" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" tomoon
                ;;
            battlenet)
                battlenet_choice="$(gui_dialog --menu "战网安装｜请选择" \
                    battlenet "战网启动器｜安装战网并添加到 Steam，方便下载和游玩暴雪游戏" \
                    heihe "黑盒工坊｜安装黑盒工坊并添加到 Steam；需要先安装战网" \
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
            hmcl)
                run_gui_action "安装 HMCL 启动器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" hmcl
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
                    test "安装测试版｜仅适合测试版或预览版系统" \
                    auto "根据系统版本安装｜自动检测稳定版或测试版" \
                    rog-white-install "安装 ROG White 白色主题｜需先安装主题美化（CSS Loader）" \
                    handheld-pink-install "安装 掌机 Pink 粉色主题｜需先安装主题美化（CSS Loader）" \
                    pink-white-gradient-install "安装 粉白渐变 粉色主题｜需先安装主题美化（CSS Loader）" \
                    back "返回插件列表")" || continue
                case "$decky_choice" in
                    auto)
                        gui_confirm "会自动检测 SteamOS 正式或测试通道并安装对应版本；会先停用旧服务再安装，已有插件和设置保留。是否继续？" && \
                            run_gui_action "按系统版本自动安装插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" store-auto
                        ;;
                    stable)
                        gui_confirm "适合正式版 SteamOS，将安装或更新稳定版插件商城，需要管理员权限；已有插件和设置会保留。是否继续？" && \
                            run_gui_action "安装稳定版插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" store
                        ;;
                    test)
                        gui_confirm "仅在测试版或预览版系统无法使用稳定版插件商城时安装；已有插件和设置保留。是否继续？" && \
                            run_gui_action "安装测试版插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/plugin_store.sh" store-test
                        ;;
                    rog-white-install)
                        gui_confirm "将 Renkit 内置的 ROG White v1.4.9 白色主题放入 CSS Loader 主题目录。需要已安装主题美化（CSS Loader），安装后请在 CSS Loader 中开启。是否继续？" && \
                            run_gui_action "安装 ROG White 白色主题" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/rog_white_theme.sh" install
                        ;;
                    handheld-pink-install)
                        gui_confirm "将 Renkit 内置的 Handheld Pink v1.0.3 粉色主题放入 CSS Loader 主题目录。需要已安装主题美化（CSS Loader），安装后请在 CSS Loader 中开启。是否继续？" && \
                            run_gui_action "安装 掌机 Pink 粉色主题" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/handheld_pink_theme.sh" install
                        ;;
                    pink-white-gradient-install)
                        gui_confirm "将 Renkit 内置的 Pink White Gradient v1.0.2 浅粉渐变主题放入 CSS Loader 主题目录。需要已安装主题美化（CSS Loader），安装后请在 CSS Loader 中开启。是否继续？" && \
                            run_gui_action "安装 粉白渐变 粉色主题" env ZHOUKEER_AUTO_CONFIRM=1 \
                            bash "$PROJECT_ROOT/modules/pink_white_gradient_theme.sh" install
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
    local install_description

    while true; do
        start=$((page * page_size))
        end=$((start + page_size))
        [ "$end" -le "$total" ] || end="$total"
        menu_args=(--menu "精选插件（第 $((page + 1)) / $total_pages 页）")
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
                install_description="${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}：${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}。安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”，是否继续？"
                gui_confirm "$install_description" && \
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

dual_system_more_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "更多双系统工具｜只读检查、恢复与引导清理｜第 2/2 页" \
            health "双系统健康检查｜识别 Clover、rEFInd、GRUB、OpenCore 等｜只读" \
            unprotect "恢复互通盘写入｜重新以可写方式挂载｜高级操作" \
            cleanup-boot "清理第三方引导项｜保护 SteamOS / Windows｜保留 EFI 文件" \
            repair-boot "修复双系统引导｜补齐缺失的 SteamOS / Windows / Clover 引导项｜高级操作" \
            switch-to-windows "Switch to Windows｜安装一键重启插件｜本人制作：RenAmamiya" \
            clover-hide "隐藏 Clover 菜单｜等待时间设为 0 秒｜默认系统不变" \
            clover-menu "重新显示 Clover 菜单｜恢复 8 秒开机选择时间" \
            previous "上一页：返回常用工具｜回到磁盘与互通盘｜第 1/2 页" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            health) run_gui_action "双系统健康检查" bash "$PROJECT_ROOT/modules/dual_system_tools.sh" health ;;
            unprotect)
                gui_confirm "将重新以可写模式挂载互通盘，恢复 SteamOS 下的正常读写。是否继续？" && \
                    run_gui_action "恢复互通盘写入" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" unprotect
                ;;
            cleanup-boot)
                gui_confirm "系统正常启动所需项目会保留；删除其他项目必须输入编号和删除口令。是否继续？" && \
                    run_gui_action "清理第三方引导项" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" cleanup-boot
                ;;
            repair-boot)
                gui_confirm "只补齐缺失的 SteamOS、Windows 或 Clover NVRAM 启动项，并备份修复前清单；不会安装 Clover 或修改 EFI 文件。是否继续？" && \
                    run_gui_action "修复双系统引导项" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" repair-boot
                ;;
            switch-to-windows)
                gui_confirm "将安装 RenAmamiya 本人制作的 Switch to Windows Decky 插件；安装完成后请在游戏模式插件菜单点击它，即可设置单次启动项并立即重启进入 Windows。当前不会立即重启。是否继续？" && \
                    run_gui_action "安装 Switch to Windows" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" switch-to-windows
                ;;
            clover-hide)
                gui_confirm "将备份并修改 Clover config.plist，只把菜单等待时间设为 0 秒；当前默认系统保持不变。是否继续？" && \
                    run_gui_action "隐藏 Clover 菜单" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" hide-menu
                ;;
            clover-menu)
                gui_confirm "将备份并修改 Clover config.plist，把菜单等待时间恢复为 8 秒；当前默认系统保持不变。是否继续？" && \
                    run_gui_action "重新显示 Clover 菜单" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" show-menu
                ;;
            previous) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

dual_system_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "双系统用户专用｜磁盘与互通盘｜第 1/2 页" \
            mount "挂载双系统互通盘｜自动排除 Windows 系统分区｜高级操作" \
            tf-format "初始化并挂载 TF 卡｜清空并格式化为 NTFS｜高风险" \
            repair-drive "修复 Steam 磁盘写入错误｜共享游戏盘下载失败和更新失败，检查游戏启动设置｜高级操作" \
            protect "双系统互通盘保护｜防止 SteamOS 误写入｜高级操作" \
            clover-steamos "默认进入 SteamOS｜只修改 Clover 默认项｜菜单状态不变" \
            clover-background "应用 Renkit 开机背景｜仅替换 Clover Apocalypse 主题背景" \
            clover-windows "默认进入 Windows｜只修改 Clover 默认项｜菜单状态不变" \
            next "下一页：更多双系统工具｜健康检查、恢复与引导清理｜第 2/2 页" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
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
                gui_confirm "修复 Windows 和 SteamOS 共享游戏盘的写入错误、游戏下载和更新失败，并检查游戏启动设置。是否继续？" && \
                    run_gui_action "修复 Steam 磁盘写入错误" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" repair-drive
                ;;
            protect)
                gui_confirm "将重新以只读模式挂载互通盘，SteamOS 下无法写入或删除该盘文件。是否继续？" && \
                    run_gui_action "保护双系统互通盘" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" protect
                ;;
            clover-windows)
                gui_confirm "将备份并修改 Clover config.plist，只把 Windows 设为默认项；菜单显示状态保持不变。是否继续？" && \
                    run_gui_action "默认进入 Windows" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" default-windows
                ;;
            clover-steamos)
                gui_confirm "将备份并修改 Clover config.plist，只把 SteamOS 设为默认项；菜单显示状态保持不变。是否继续？" && \
                    run_gui_action "默认进入 SteamOS" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" default-steamos
                ;;
            clover-background)
                gui_confirm "仅替换 esp/efi/clover/themes/Apocalypse/background.png，不修改其他 Clover 文件。是否继续？" && \
                    run_gui_action "应用 Renkit 开机背景" \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" apply-background
                ;;
            next)
                dual_system_more_menu
                [ "$GUI_NAV_HOME" -eq 0 ] || return 0
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

steam_accelerator_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "网络加速｜加速 Steam 社区和游戏下载" \
            install "安装或更新 Steamcommunity 302" \
            start "一键开启网络加速" \
            launch "打开官方配置界面" \
            reset "重置加速服务" \
            status "查看运行状态" \
            uninstall "安全卸载" \
            console "奇游 / 迅游 / UU 主机加速器" \
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
                gui_confirm "将重新启动网络加速。是否继续？" && \
                    run_gui_action "重置 Steamcommunity 302 加速" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" reset
                ;;
            status)
                run_gui_action "Steamcommunity 302状态" \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status
                ;;
            uninstall)
                gui_confirm "会停止 Renkit 开启的加速；其他工具修改过的网络设置需要另行恢复。确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            console) console_accelerator_gui_menu ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

console_accelerator_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "主机加速器｜官方安装与配置入口｜无 SteamOS 原生客户端" \
            qiyou "奇游主机加速｜手机 App、联机宝或路由方案" \
            xunyou "迅游主机加速｜打开官方主机加速页面" \
            uu "网易UU主机加速｜手机 App、路由插件或加速盒" \
            back "返回加速设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            qiyou|xunyou|uu)
                run_gui_action "打开主机加速器官方页面" \
                    bash "$PROJECT_ROOT/modules/console_accelerators.sh" "$choice"
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
            user-cache "清理 应用临时文件" \
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
                gui_confirm "新机初始化开始后会询问是否跳过系统组件更新；修改器运行工具仅安装 GE-Proton 10-29，其余软件、Decky、FreeDeck、MAKO 小黄鸭、国内源和 Epic 继续按计划处理。请先在游戏模式开启“启用开发者模式”和“CEF远程调试”，再确认继续。" && \
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

    choice="$(gui_dialog --menu "软件下载加速与系统修复｜注意：加速下载会关闭部分软件的签名检查，存在安全风险" \
        configure "软件下载加速与系统修复｜更新系统组件、配置国内缓存并修复 Discover" \
        restore "恢复默认下载设置｜恢复默认下载设置和安全检查" \
        back "返回系统设置")" || return 0
    case "$choice" in
        configure)
            gui_confirm "将设置软件下载加速、更新系统所需组件、修复应用商店并配置中英文显示；需要管理员权限，会临时关闭系统保护。

系统组件下载设置：archlinuxcn
地址：https://mirrors.ustc.edu.cn/archlinuxcn/\$arch
备用：https://mirror.sjtu.edu.cn/archlinux-cn/\$arch → https://mirrors.ustc.edu.cn/archlinuxcn/\$arch → https://repo.archlinuxcn.org/\$arch
安全检查：系统组件保留软件签名检查；下载失败时保留原有设置，继续处理应用下载。
注意：下列应用下载地址会关闭软件签名检查，可能增加安装不可信软件的风险。

远程名称：flathub-cn
地址：https://mirror.sjtu.edu.cn/flathub

备用名称：flathub-ustc
地址：https://mirrors.ustc.edu.cn/flathub

确认了解风险并信任以上下载地址，继续？" && \
                run_gui_action "软件下载加速与系统修复" env ZHOUKEER_AUTO_CONFIRM=1 \
                bash "$PROJECT_ROOT/modules/domestic_source.sh" init
            ;;
        restore)
            gui_confirm "将恢复默认下载设置，重新开启软件签名检查，并移除 Renkit 添加的下载加速设置；原有设置保留。确认继续？" && \
                run_gui_action "恢复默认下载设置" env ZHOUKEER_AUTO_CONFIRM=1 \
                bash "$PROJECT_ROOT/modules/domestic_source.sh" restore
            ;;
    esac
}

memory_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "虚拟内存｜优化、查看或撤销Renkit设置" \
            optimize "一键优化｜改善内存不足时的运行表现" \
            status "查看状态" \
            restore "撤销Renkit优化｜保留系统原有虚拟内存" \
            back "返回更多设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            optimize)
                gui_confirm "将设置 内存压缩、虚拟内存 和 内存使用设置；失败时自动恢复。确认继续？" && \
                    run_gui_action "一键优化虚拟内存" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/memory_tuning.sh" optimize
                return 0
                ;;
            status)
                run_gui_action "虚拟内存状态" bash "$PROJECT_ROOT/modules/memory_tuning.sh" status
                return 0
                ;;
            restore)
                gui_confirm "只删除Renkit创建的配置和虚拟内存；系统原有虚拟内存会保留。确认撤销？" && \
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
    local choice plan_output

    while true; do
        choice="$(gui_dialog --menu "掌机适配" \
            install "安装屏幕修复｜F1 7840U 与 8840U OLED（F1L）｜无需管理员权限" \
            status "查看屏幕修复状态｜查看屏幕方向修复是否已启用" \
            uninstall "卸载屏幕修复｜删除用户级修复并恢复原始启动方式" \
            button-install "安装特殊按键修复｜F1L 仅限 F1 8840U｜确认后5秒自动重启" \
            button-status "特殊按键修复状态｜验证机型、配置、备份与 InputPlumber" \
            button-restore "恢复特殊按键修复｜完成后5秒自动重启" \
            inputplumber-update "更新 InputPlumber｜更新并启用手柄功能" \
            bios "准备 V1.14 BIOS｜仅 7840U 普通黑白版｜复制到互通盘" \
            g3e-audio "微星 G3E 无声音修复｜仅 Claw 8 EX｜实验性" \
            reboot "立即重启 SteamOS｜重启后生效｜请先保存工作" \
            back "返回更多设置" \
            home "返回首页" \
            nav-exit "退出Renkit")" || return 0
        case "$choice" in
            install)
                gui_confirm "适用于 ONEXPLAYER F1 7840U 与 F1L OLED 8840U；将修复屏幕方向和游戏模式启动设置，无需管理员权限。确认继续？" && \
                    run_gui_action "安装飞行家 F1 屏幕方向修复" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" install
                return 0
                ;;
            status)
                run_gui_action "飞行家 F1 屏幕方向修复状态" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" status
                return 0
                ;;
            uninstall)
                gui_confirm "将删除用户级修复文件并刷新启动设置，无需管理员权限；重启后恢复原始启动方式。确认继续？" && \
                    run_gui_action "卸载 Decky Loader" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" uninstall
                return 0
                ;;
            button-install)
                if ! plan_output="$(bash "$PROJECT_ROOT/modules/onexplayer_button_fix.sh" plan-install 2>&1)"; then
                    gui_dialog --error "$plan_output"
                    return 0
                fi
                gui_confirm "$plan_output

确认继续？" && \
                    run_gui_action "壹号掌机 SteamOS 特殊按键修复" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/onexplayer_button_fix.sh" install
                return 0
                ;;
            button-status)
                run_gui_action "壹号掌机 SteamOS 特殊按键修复状态" \
                    bash "$PROJECT_ROOT/modules/onexplayer_button_fix.sh" status
                return 0
                ;;
            button-restore)
                if ! plan_output="$(bash "$PROJECT_ROOT/modules/onexplayer_button_fix.sh" plan-restore 2>&1)"; then
                    gui_dialog --error "$plan_output"
                    return 0
                fi
                gui_confirm "$plan_output

确认继续？" && \
                    run_gui_action "恢复壹号掌机 SteamOS 特殊按键修复" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/onexplayer_button_fix.sh" restore
                return 0
                ;;
            inputplumber-update)
                if ! plan_output="$(bash "$PROJECT_ROOT/modules/inputplumber_update.sh" plan 2>&1)"; then
                    gui_dialog --error "$plan_output"
                    return 0
                fi
                gui_confirm "$plan_output

确认继续？" && \
                    run_gui_action "更新 InputPlumber" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/inputplumber_update.sh" update
                return 0
                ;;
            bios)
                gui_confirm "仅适用于 ONEXPLAYER F1/ONEXFLY 7840U 普通黑白版，不适用于 8840U、EVA、F1 Pro。Renkit 只校验并复制 BIOS 到互通盘；必须进入 Windows 后手动运行 OXF.bat，刷写期间严禁断电。确认继续？" && \
                    run_gui_action "准备飞行家 F1 V1.14 BIOS" bash "$PROJECT_ROOT/modules/f1_bios_prepare.sh" prepare
                return 0
                ;;
            g3e-audio)
                if ! plan_output="$(bash "$PROJECT_ROOT/modules/claw_g3e_audio.sh" plan 2>&1)"; then
                    gui_dialog --error "$plan_output"
                    return 0
                fi
                gui_confirm "$plan_output

确认继续？" && run_gui_action "修复微星 G3E 无声音" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/claw_g3e_audio.sh" install
                return 0
                ;;
            reboot)
                gui_confirm "将立即重启 SteamOS；请先保存所有工作。确认继续？" && \
                    run_gui_action "立即重启 SteamOS" bash "$PROJECT_ROOT/modules/onexplayer_button_fix.sh" reboot
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
        choice="$(gui_dialog --menu "更多设置｜国内下载、网络加速、内存、密码与掌机适配" \
            domestic-source "软件下载加速｜提高下载速度，请先阅读风险说明" \
            accelerator "Steamcommunity 302｜可能修改 DNS 和证书｜高级操作" \
            memory "虚拟内存｜改善内存不足，支持撤销｜高级操作" \
            change-password "修改管理员密码｜会更换 SteamOS 管理密码｜高级操作" \
            handheld "掌机适配｜F1 屏幕、壹号掌机按键与微星 G3E 音频" \
            sdweak "安装 SDWEAK｜可提升游戏性能·仅 Steam Deck 可用" \
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
            handheld) f1_screen_fix_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            sdweak)
                local plan_output
                if ! plan_output="$(bash "$PROJECT_ROOT/modules/sdweak.sh" plan 2>&1)"; then
                    gui_dialog --error "$plan_output"
                elif gui_confirm "$plan_output
确认了解以上警告并安装 SDWEAK？"; then
                    run_gui_action "安装 SDWEAK" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/sdweak.sh" install
                fi
                ;;
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
                    wechat "卸载微信｜软件文件 和快捷方式" \
                    qq "卸载 QQ｜删除软件和快捷方式" \
                    browser "卸载 Firefox｜删除软件和快捷方式" \
                    chrome "卸载 Chrome｜Google Chrome 删除软件和快捷方式" \
                    edge "卸载 Edge｜Microsoft Edge 删除软件和快捷方式" \
                    rustdesk "卸载 RustDesk｜保留用户配置" \
                    todesk "卸载 ToDesk｜停止服务并卸载软件包｜高级操作" \
                    baidunetdisk "卸载百度网盘｜删除软件和快捷方式" \
                    next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            1)
                choice="$(gui_dialog --menu "卸载已安装｜办公与创作｜第 2/7 页" \
                    anydesk "卸载 AnyDesk｜删除软件和快捷方式" \
                    willwill "卸载 WiliWili｜删除软件和快捷方式 与 Steam 条目" \
                    xbox-cloud "卸载 Xbox 云游戏｜Greenlight 删除软件和快捷方式" \
                    libreoffice "卸载 LibreOffice｜删除软件和快捷方式" \
                    vlc "卸载 VLC｜删除软件和快捷方式" \
                    obs "卸载 OBS Studio｜删除软件和快捷方式" \
                    localsend "卸载 LocalSend｜删除软件和快捷方式" \
                    peazip "卸载 PeaZip｜删除软件和快捷方式" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            2)
                choice="$(gui_dialog --menu "卸载已安装｜兼容、音乐与下载｜第 3/7 页" \
                    fcitx5 "卸载中文输入法｜Fcitx5 与中文输入插件" \
                    protontricks "卸载 Protontricks｜删除软件和快捷方式" \
                    bottles "卸载 Bottles｜删除软件和快捷方式" \
                    qqmusic "卸载 QQ音乐｜删除软件和快捷方式" \
                    netease-music "卸载网易云音乐｜删除软件和快捷方式" \
                    yesplaymusic "卸载 YesPlayMusic｜删除软件和快捷方式" \
                    qbittorrent "卸载 qBittorrent｜删除软件和快捷方式" \
                    motrix "卸载 Motrix 下载器｜删除软件和快捷方式" \
                    previous "上一页" next "下一页" home "返回首页" nav-exit "退出Renkit")" || return 0
                ;;
            3)
                choice="$(gui_dialog --menu "卸载已安装｜下载、办公、笔记与串流｜第 4/7 页" \
                    freedownloadmanager "卸载 Free Download Manager｜删除软件和快捷方式" \
                    media-downloader "卸载 Media Downloader｜删除软件和快捷方式" \
                    flameshot "卸载 Flameshot 截图｜删除软件和快捷方式" \
                    onlyoffice "卸载 OnlyOffice｜删除软件和快捷方式" \
                    joplin "卸载 Joplin 笔记｜删除软件和快捷方式" \
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
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" uninstall "$target"
                ;;
            battlenet|epic|ubisoft|heihe)
                target="$choice"
                gui_confirm "会移除 Steam 库条目和桌面入口，保留游戏与下载文件。确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" uninstall "$target"
                ;;
            yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                target="$choice"
                gui_confirm "会移除 Steam 库条目和桌面入口，保留存档与配置。确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/emulators.sh" uninstall "$target"
                ;;
            todesk)
                gui_confirm "会停止 ToDesk 服务并临时关闭 SteamOS 只读保护，完成后自动恢复。确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --uninstall
                ;;
            steam302)
                gui_confirm "会停止后台加速并移除开机自启，确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            ge-proton)
                gui_confirm "只删除Renkit当前 GE-Proton 版本，确认继续？" && \
                    run_gui_action "卸载 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
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
            nav-advanced "更多设置｜国内下载、内存、密码和掌机适配" \
            nav-dual "双系统用户专用｜互通盘、Windows 与 Clover 设置" \
            nav-uninstall "卸载已安装｜逐项安全移除软件和系统组件" \
            nav-notice "免责声明与使用须知｜查看完整图文说明" \
            nav-help "帮助｜扫码联系、查看资讯与使用指南" \
            nav-exit "退出Renkit")" || exit 0

        case "$choice" in
            nav-init) new_machine_gui_menu ;;
            nav-software) software_menu ;;
            nav-games) game_environment_gui_menu ;;
            nav-emulators) emulator_gui_menu ;;
            nav-help) bash "$PROJECT_ROOT/modules/help.sh" ;;
            nav-check) support_gui_menu ;;
            nav-advanced) advanced_tools_gui_menu ;;
            nav-dual) dual_system_menu ;;
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
