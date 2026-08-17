#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Renkit会原子更新自身目录；主菜单始终停在稳定目录，避免旧目录被替换后
# 子命令持续输出 shell-init/getcwd 错误。
cd "$HOME" 2>/dev/null || cd / || exit 1

# 直接在 Konsole 中运行 main.sh 时，自动转入专用主题窗口。
# launch.sh 会设置标记，避免新窗口再次重启形成循环。
if [ "${ZHOUKEER_LAUNCHED:-0}" != "1" ] && \
    [ -x "$PROJECT_ROOT/launch.sh" ] && \
    command -v konsole >/dev/null 2>&1; then
    exec bash "$PROJECT_ROOT/launch.sh"
fi

# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

ensure_runtime_dirs

show_startup_loading() {
    # 终端恢复尺寸前可能会短暂只显示背景横线；先给出明确反馈，避免误以为卡住。
    printf '\033[0m\033[2J\033[H\n\n  Renkit启动中，请耐心等待…\n  若启动较慢，Renkit可能正在更新，请耐心等待。\n'
}

# 首次启动时 Konsole 可能还未应用Renkit的 120×32 配置；先等画布就绪，
# 避免固定第 24 行的触控导航被裁掉而看起来像菜单或插件分页丢失。
show_startup_loading
ui_apply_screen_font
ui_wait_for_minimum_canvas || true

# V5 默认就是纯触控界面。不再提供数字或字母菜单，避免键盘和触屏事件冲突。
case "${1:-}" in
    ""|--touch) ;;
    --gui) exec bash "$PROJECT_ROOT/core/gui.sh" ;;
    *) echo "请从桌面的“Renkit”图标启动。"; exit 1 ;;
esac

enable_mouse_tracking
trap 'disable_mouse_tracking' EXIT INT TERM

NEXT_CATEGORY="home"

# Decky 官方插件的中文短说明。触控界面每页仅显示 5 个，避免小屏幕按钮拥挤。
DECKY_OFFICIAL_PLUGIN_NAMES=(
    "CSS Loader" "vibrantDeck" "Animation Changer" "Audio Loader" "SteamGridDB"
    "PowerTools" "Storage Cleaner" "AutoFlatpaks" "Bluetooth" "ProtonDB Badges"
    "Deck Settings" "HLTB for Deck" "PlayCount" "TabMaster"
    "Wine Cellar" "Pause Games" "Controller Tools" "Volume Mixer" "Battery Tracker"
    "PlayTime" "Free Loader" "DeckMTP" "MangoPeel"
)
DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS=(
    "自定义界面样式" "调整界面配色" "更换开机动画" "更换系统音效" "自动补游戏封面"
    "性能与功耗控制" "清理游戏缓存" "自动更新应用" "管理蓝牙设备" "显示兼容性评分"
    "更多 Deck 设置" "显示通关时长" "记录游玩次数" "整理游戏库标签"
    "管理 Wine 与 Proton" "后台自动暂停游戏" "手柄辅助工具" "分应用调节音量" "查看电池状态"
    "记录游戏时长" "下载功能扩展" "USB 文件传输" "优化 Steam 界面"
)
DECKY_TOUCH_PAGE_SIZE=5

pause_menu() {
    echo ""
    echo "请点击窗口任意位置返回Renkit"
    enable_mouse_tracking
    read_touch_click || true
    disable_mouse_tracking
    ui_discard_pending_input
}

run_action() {
    local status
    local title="$1"
    shift

    disable_mouse_tracking
    sleep 0.05
    ui_discard_pending_input
    print_header
    print_section_title "$title"
    echo ""
    "$@"
    status=$?

    cd "$HOME" 2>/dev/null || cd / || true

    if [ "$status" -eq 0 ]; then
        echo ""
        echo "✓ 操作完成"
    else
        echo ""
        echo "✗ 操作未完成，请查看上方提示"
    fi
    pause_menu
}

confirm_and_run() {
    local title="$1"
    local message="$2"
    local choice
    shift 2

    draw_category_frame "" "$title" "$message"
    ui_panel_line 8 '\033[1;38;5;220m' "请确认是否继续这项操作"
    ui_touch_button 10 '\033[1;30;48;5;114m' "继续执行" "已授权Renkit完成该操作"
    ui_touch_button 15 '\033[1;97;48;5;160m' "返回主菜单" "不做任何更改"
    ui_prompt
    choice="$(read_touch_menu right:10-11:yes right:15-16:no)"
    if apply_navigation "$choice"; then
        return 0
    fi
    if [ "$choice" = "yes" ]; then
        run_action "$title" env ZHOUKEER_AUTO_CONFIRM=1 "$@"
    fi
}

show_disclaimer() {
    local choice

    while true; do
        # 免责声明统一使用终端文字版，不再依赖免责声明大图主题。
        draw_disclaimer_frame
        ui_disclaimer_line 8 '\033[1;38;5;220m' "Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）制作"
        ui_disclaimer_line 9 '\033[38;5;45m' "GitHub：Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）"
        ui_disclaimer_line 10 '\033[38;5;45m' "支持免费使用；禁止商业、销售、转卖或借此盈利"
        ui_disclaimer_line 11 '\033[38;5;45m' "下载内容均来自官方免费发布或开源项目"
        ui_disclaimer_line 12 '\033[38;5;45m' "不包含付费软件本体、破解或商业授权"
        ui_disclaimer_line 13 '\033[1;38;5;220m' "第三方软件与插件均从作者或官方发布页获取；欢迎支持作者"
        ui_disclaimer_button 16 '\033[1;38;5;114m' "点击窗口任意位置开始使用" "点击即表示已阅读上述说明；关闭窗口即可退出"
        # 非全屏 Konsole 的可见行数和触屏坐标可能在首帧不同步，不能再把进入
        # Renkit限定在固定的第 12–19 行；欢迎页不执行任何系统操作，因此任意
        # 主指针点击均视为确认，关闭窗口仍可直接退出。
        choice="$(read_menu_choice any:1-999:agree)"
        case "$choice" in
            agree)
                return 0
                ;;
        esac
    done
}

ensure_password_ready() {
    local choice

    if load_toolbox_password >/dev/null 2>&1; then
        TOOLBOX_PASSWORD=""
        unset TOOLBOX_PASSWORD
        return 0
    fi

    while true; do
        draw_category_frame "" "首次使用准备" "先准备管理员密码记录，后续安装无需反复输入"
        ui_panel_line 7 '\033[1;38;5;220m' "首次使用必须完成此步骤，但不会强制修改已有密码"
        ui_touch_button 10 '\033[1;97;48;5;24m' "我已有管理员密码" "输入一次并保存到桌面，不修改密码"
        ui_touch_button 15 '\033[1;97;48;5;58m' "我还没有管理员密码" "按系统提示设置新密码"
        ui_touch_button 20 '\033[1;97;48;5;160m' "退出Renkit" "暂不进行任何操作"
        ui_prompt
        choice="$(read_touch_menu right:10-11:import right:15-16:set right:20-21:exit)"
        case "$choice" in
            import)
                run_action "录入现有管理员密码" \
                    bash "$PROJECT_ROOT/modules/password.sh" import
                ;;
            set)
                run_action "设置管理员密码" \
                    bash "$PROJECT_ROOT/modules/password.sh" set
                ;;
            exit) exit 0 ;;
        esac
        if load_toolbox_password >/dev/null 2>&1; then
            TOOLBOX_PASSWORD=""
            unset TOOLBOX_PASSWORD
            return 0
        fi
    done
}

read_touch_menu() {
    read_menu_choice \
        left:2-3:nav-init \
        left:4-5:nav-software \
        left:6-7:nav-games \
        left:8-9:nav-emulators \
        left:10-11:nav-check \
        left:12-13:nav-advanced \
        left:14-15:nav-uninstall \
        left:16-17:nav-notice \
        left:18-19:nav-exit \
        "$@"
}

apply_navigation() {
    case "$1" in
        nav-init) NEXT_CATEGORY="init" ;;
        nav-software) NEXT_CATEGORY="software" ;;
        nav-games) NEXT_CATEGORY="games" ;;
        nav-emulators) NEXT_CATEGORY="emulators" ;;
        nav-network|nav-maintenance|nav-help|nav-check) NEXT_CATEGORY="support" ;;
        nav-advanced) NEXT_CATEGORY="advanced" ;;
        nav-uninstall) NEXT_CATEGORY="uninstall" ;;
        nav-notice) NEXT_CATEGORY="notice" ;;
        # 旧导航 ID 仅保留兼容，不再显示在首页。
        nav-remote) NEXT_CATEGORY="software" ;;
        nav-plugins) NEXT_CATEGORY="games" ;;
        nav-settings) NEXT_CATEGORY="support" ;;
        nav-optimize|nav-guides|nav-changelog|nav-update) NEXT_CATEGORY="support" ;;
        nav-dual) NEXT_CATEGORY="advanced" ;;
        nav-exit) NEXT_CATEGORY="exit" ;;
        *) return 1 ;;
    esac
    return 0
}

usage_notice_menu() {
    local choice

    while true; do
        # 图片中的“我已阅读并知悉”只是静态内容，不能接收触控事件。这里使用
        # 真实的终端按钮，点击后立即返回首页，避免用户被图片查看器困住。
        draw_category_frame notice "免责声明及使用须知" "请阅读并用下方真实按钮确认"
        ui_panel_line 8 '\033[1;38;5;203m' "Renkit不包含付费软件、破解、ROM、BIOS 或密钥"
        ui_panel_line 10 '\033[38;5;250m' "第三方软件由其作者或官方渠道提供；请自行确认授权"
        ui_panel_line 12 '\033[38;5;250m' "涉及下载、安装、权限与磁盘的操作都会另行说明并确认"
        ui_panel_line 14 '\033[38;5;250m' "完整说明已在首次启动页展示；本页不执行任何系统操作"
        ui_touch_button 18 '\033[1;97;48;5;24m' "我已阅读并知悉" "关闭免责声明并返回首页"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页" "暂不确认，继续使用Renkit"
        ui_prompt
        choice="$(read_touch_menu right:18-19:acknowledge right:21-22:home)"
        case "$choice" in
            nav-*) apply_navigation "$choice"; return 0 ;;
            acknowledge|home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

common_software_menu() {
    local choice

    while true; do
        draw_category_frame software "" "" 0
        ui_touch_button 2 '\033[1;97;48;5;24m' "微信"
        ui_touch_button 4 '\033[1;97;48;5;24m' "QQ"
        ui_touch_button 6 '\033[1;97;48;5;24m' "Firefox 浏览器"
        ui_touch_button 8 '\033[1;97;48;5;24m' "Chrome 浏览器"
        ui_touch_button 10 '\033[1;97;48;5;24m' "Edge 浏览器"
        ui_touch_button 12 '\033[1;97;48;5;24m' "RustDesk 远程协助" "安装开源远程工具"
        ui_touch_button 14 '\033[1;97;48;5;24m' "ToDesk 远程协助" "安装前需完成系统设置"
        ui_touch_button 16 '\033[1;97;48;5;24m' "Windows 软件工具" "安装 Bottles 运行工具"
        ui_touch_button 18 '\033[1;97;48;5;24m' "游戏兼容设置" "安装 Protontricks"
        ui_touch_button 20 '\033[1;97;48;5;24m' "AnyDesk 远程协助" "Flathub 国内镜像安装"
        ui_touch_button 22 '\033[1;97;48;5;238m' "更多常用软件" "百度网盘等更多工具"
        ui_prompt
        choice="$(read_touch_menu right:2-3:wechat right:4-5:qq right:6-7:browser right:8-9:chrome right:10-11:edge right:12-13:rustdesk right:14-15:todesk right:16-17:bottles right:18-19:protontricks right:20-21:anydesk right:22-23:more)"
        case "$choice" in
            nav-*) apply_navigation "$choice"; return 0 ;;
        esac

        case "$choice" in
            wechat) confirm_and_run "安装微信" "腾讯官网AppImage；失败时保留原有版本" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            qq) confirm_and_run "安装QQ" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            browser) confirm_and_run "安装 Firefox 浏览器" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" browser ;;
            chrome) confirm_and_run "安装 Google Chrome" "Flathub 安装，通过国内镜像加速" bash "$PROJECT_ROOT/modules/software.sh" chrome ;;
            edge) confirm_and_run "安装 Microsoft Edge" "Flathub 安装，通过国内镜像加速" bash "$PROJECT_ROOT/modules/software.sh" edge ;;
            rustdesk) confirm_and_run "安装 RustDesk 远程协助" "从作者 GitHub Release 安装，不会修改服务器配置" bash "$PROJECT_ROOT/modules/software.sh" rustdesk ;;
            todesk) todesk_preflight software ;;
            protontricks) confirm_and_run "安装 Protontricks" "修复与配置 Steam 游戏 Proton 环境" bash "$PROJECT_ROOT/modules/software.sh" protontricks ;;
            bottles) confirm_and_run "安装 Bottles" "独立运行第三方 Windows 应用与游戏" bash "$PROJECT_ROOT/modules/software.sh" bottles ;;
            anydesk) confirm_and_run "安装 AnyDesk 远程协助" "通过 Flathub 国内镜像以当前用户身份安装" bash "$PROJECT_ROOT/modules/software.sh" anydesk ;;
            more) common_software_more_menu || return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "software" ] || return 0
    done
}

common_software_more_menu() {
    local choice page=0

    while true; do
        case "$page" in
            0)
                draw_category_frame software "更多常用软件" "办公与工具 · 第 1/3 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "LibreOffice 办公套件" "文档、表格与演示文稿"
                ui_touch_button 4 '\033[1;97;48;5;24m' "VLC 播放器" "本地视频与音频播放"
                ui_touch_button 6 '\033[1;97;48;5;24m' "OBS Studio" "录屏、直播与视频采集"
                ui_touch_button 8 '\033[1;97;48;5;24m' "LocalSend 局域网传文件" "手机与电脑免登录互传"
                ui_touch_button 10 '\033[1;97;48;5;24m' "百度网盘" "Flathub 安装百度网盘 Linux 版"
                ui_touch_button 12 '\033[1;97;48;5;24m' "PeaZip 压缩工具" "解压与压缩常用格式"
                ui_touch_button 14 '\033[1;97;48;5;24m' "WiliWili" "Flathub 安装 WiliWili（B站客户端）"
                ui_touch_button 16 '\033[1;97;48;5;24m' "中文输入法" "Flathub 安装 Fcitx5 及中文输入插件"
                ui_touch_button 18 '\033[1;97;48;5;24m' "下一页" "音乐、下载与游戏串流"
                ui_touch_button 20 '\033[1;97;48;5;238m' "返回常用软件" "查看常用软件第一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:libreoffice right:4-5:vlc right:6-7:obs right:8-9:localsend right:10-11:baidunetdisk right:12-13:peazip right:14-15:willwill right:16-17:fcitx5 right:18-19:next right:20-21:back right:22-23:home)"
                ;;
            1)
                draw_category_frame software "更多常用软件" "音乐、下载与云游戏 · 第 2/3 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "Xbox 云游戏" "Flathub 安装 Greenlight，云游戏需 Xbox 账号"
                ui_touch_button 4 '\033[1;97;48;5;24m' "QQ音乐" "Flathub 安装 QQ音乐"
                ui_touch_button 6 '\033[1;97;48;5;24m' "网易云音乐" "Flathub 安装网易云音乐"
                ui_touch_button 8 '\033[1;97;48;5;24m' "YesPlayMusic" "Flathub 安装第三方网易云音乐客户端"
                ui_touch_button 10 '\033[1;97;48;5;24m' "qBittorrent" "BT 种子与磁力下载"
                ui_touch_button 12 '\033[1;97;48;5;24m' "Motrix 下载器" "多协议下载管理"
                ui_touch_button 14 '\033[1;97;48;5;24m' "Free Download Manager" "下载管理工具"
                ui_touch_button 16 '\033[1;97;48;5;24m' "Media Downloader" "视频与媒体下载"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "办公与常用工具"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页" "截图、笔记与游戏串流"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:xbox-cloud right:4-5:qqmusic right:6-7:netease-music right:8-9:yesplaymusic right:10-11:qbittorrent right:12-13:motrix right:14-15:freedownloadmanager right:16-17:media-downloader right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            *)
                draw_category_frame software "更多常用软件" "截图、办公、笔记与游戏串流 · 第 3/3 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "Flameshot 截图" "截图与标注"
                ui_touch_button 4 '\033[1;97;48;5;24m' "OnlyOffice 办公套件" "兼容 Office 文档"
                ui_touch_button 6 '\033[1;97;48;5;24m' "Joplin 笔记" "笔记与待办管理"
                ui_touch_button 8 '\033[1;97;48;5;24m' "Heroic 游戏启动器" "Epic 与 GOG 游戏库"
                ui_touch_button 10 '\033[1;97;48;5;24m' "Lutris" "多平台游戏管理"
                ui_touch_button 12 '\033[1;97;48;5;24m' "Chiaki4Deck（PS5串流）" "PS5 远程串流"
                ui_touch_button 14 '\033[1;97;48;5;24m' "Parsec" "远程串流与协作"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "音乐与下载工具"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:flameshot right:4-5:onlyoffice right:6-7:joplin right:8-9:heroic right:10-11:lutris right:12-13:chiaki4deck right:14-15:parsec right:18-19:previous right:22-23:home)"
                ;;
        esac
        case "$choice" in
            nav-*) apply_navigation "$choice"; return 0 ;;
        esac
        case "$choice" in
            libreoffice) confirm_and_run "安装 LibreOffice 办公套件" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" libreoffice ;;
            vlc) confirm_and_run "安装 VLC 播放器" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" vlc ;;
            obs) confirm_and_run "安装 OBS Studio" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" obs ;;
            localsend) confirm_and_run "安装 LocalSend 局域网传文件" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" localsend ;;
            baidunetdisk) confirm_and_run "安装百度网盘" "Flathub 安装百度网盘 Linux 版，通过国内镜像加速" bash "$PROJECT_ROOT/modules/software.sh" baidunetdisk ;;
            peazip) confirm_and_run "安装 PeaZip 压缩工具" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" peazip ;;
            willwill) confirm_and_run "安装 WiliWili" "Flathub 安装 WiliWili（B站客户端），完成后加入 Steam 库" bash "$PROJECT_ROOT/modules/software.sh" willwill ;;
            fcitx5) confirm_and_run "安装中文输入法" "通过 Flathub 国内缓存安装 Fcitx5 及中文输入插件" bash "$PROJECT_ROOT/modules/software.sh" fcitx5 ;;
            xbox-cloud) confirm_and_run "安装 Xbox 云游戏" "通过 Flathub 安装 Greenlight，云游戏需 Xbox 账号" bash "$PROJECT_ROOT/modules/software.sh" xbox-cloud ;;
            qqmusic) confirm_and_run "安装 QQ音乐" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" qqmusic ;;
            netease-music) confirm_and_run "安装网易云音乐" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" netease-music ;;
            yesplaymusic) confirm_and_run "安装 YesPlayMusic" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" yesplaymusic ;;
            qbittorrent) confirm_and_run "安装 qBittorrent" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" qbittorrent ;;
            motrix) confirm_and_run "安装 Motrix 下载器" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" motrix ;;
            freedownloadmanager) confirm_and_run "安装 Free Download Manager" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" freedownloadmanager ;;
            media-downloader) confirm_and_run "安装 Media Downloader" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" media-downloader ;;
            flameshot) confirm_and_run "安装 Flameshot 截图" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" flameshot ;;
            onlyoffice) confirm_and_run "安装 OnlyOffice 办公套件" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" onlyoffice ;;
            joplin) confirm_and_run "安装 Joplin 笔记" "通过 Flathub 国内缓存安装，自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" joplin ;;
            heroic) confirm_and_run "安装 Heroic 游戏启动器" "通过 Flathub 国内缓存安装，完成后加入 Steam 库" bash "$PROJECT_ROOT/modules/software.sh" heroic ;;
            lutris) confirm_and_run "安装 Lutris" "通过 Flathub 国内缓存安装，完成后加入 Steam 库" bash "$PROJECT_ROOT/modules/software.sh" lutris ;;
            chiaki4deck) confirm_and_run "安装 Chiaki4Deck（PS5串流）" "通过 Flathub 国内缓存安装，完成后加入 Steam 库" bash "$PROJECT_ROOT/modules/software.sh" chiaki4deck ;;
            parsec) confirm_and_run "安装 Parsec" "通过 Flathub 国内缓存安装，完成后加入 Steam 库" bash "$PROJECT_ROOT/modules/software.sh" parsec ;;
            next) page=$((page + 1)); [ "$page" -le 2 ] || page=2 ;;
            previous) page=$((page - 1)); [ "$page" -ge 0 ] || page=0 ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame remote "远程协助" "安装完成后会自动在桌面创建启动图标"
        ui_touch_button 7 '\033[1;97;48;5;24m' "下载 RustDesk" "作者 GitHub Release；无需系统权限"
        ui_touch_button 11 '\033[1;97;48;5;24m' "查看设置步骤并安装 ToDesk" "需先开启开发者模式和旧版 X11 桌面模式"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:rustdesk right:11-12:todesk right:21-22:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            rustdesk) confirm_and_run "下载 RustDesk" "从作者 GitHub Release 安装，不会写入或修改你的 RustDesk 服务器配置" bash "$PROJECT_ROOT/modules/software.sh" rustdesk ;;
            todesk) todesk_preflight remote ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "remote" ] || return 0
    done
}

todesk_preflight() {
    local choice
    local return_target="${1:-software}"
    local return_label="返回常用软件"

    [ "$return_target" != "remote" ] || return_label="返回远程协助"

    while true; do
        draw_category_frame advanced "安装 ToDesk" "会修改 SteamOS 只读系统 · 高级操作"
        ui_panel_line 7 '\033[1;38;5;220m' "① 按 Steam 键 → 设置 → 系统"
        ui_panel_line 9 '\033[1;38;5;45m' "② 开启“启用开发者模式”"
        ui_panel_line 11 '\033[1;38;5;45m' "③ 设置侧栏进入“开发者” → 找到“杂项”"
        ui_panel_line 13 '\033[1;38;5;45m' "④ 开启“使用旧版 X11 桌面模式”"
        ui_panel_line 15 '\033[1;38;5;220m' "⑤ 重新进入桌面模式，再安装并启动 ToDesk"
        ui_touch_button 16 '\033[1;30;48;5;114m' "以上设置已完成，继续安装" "点击即确认两项开关均已开启"
        ui_touch_button 18 '\033[1;97;48;5;238m' "$return_label" "暂不安装"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        choice="$(read_touch_menu right:16-17:continue right:18-19:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            continue)
                confirm_and_run "安装 ToDesk" "将使用管理员权限并临时修改 SteamOS 只读系统；完成后应恢复只读保护" bash "$PROJECT_ROOT/modules/todesk.sh" --install
                return 0
                ;;
            back) NEXT_CATEGORY="$return_target"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

new_machine_menu() {
    local choice

    while true; do
        draw_category_frame init "新机必备" "第一次使用从这里开始"
        ui_touch_button 8 '\033[1;97;48;5;24m' "推荐软件安装" "选择需要的常用软件"
        ui_touch_button 13 '\033[1;97;48;5;24m' "新机初始化" "连续安装并配置新机器"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:recommended right:13-14:advanced-init right:20-21:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            recommended) NEXT_CATEGORY="software"; return 0 ;;
            advanced-init) new_machine_preflight; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

new_machine_preflight() {
    local choice

    while true; do
        draw_category_frame init "新机初始化" "更新系统组件后安装常用软件并初始化国内源"
        ui_panel_line 7 '\033[1;38;5;220m' "① Steam 键 → 设置 → 启用开发者模式"
        ui_panel_line 9 '\033[1;38;5;45m' "② 设置左侧出现“开发者”后 → 开发者 → 杂项"
        ui_panel_line 11 '\033[1;38;5;220m' "③ 开启“CEF 远程调试”（Decky 插件商城）"
        ui_panel_line 13 '\033[1;38;5;45m' "④ 重新进入桌面模式，再开始初始化"
        ui_panel_line 15 '\033[1;38;5;45m' "继续后将更新系统组件，并安装常用软件、插件、兼容层和 Epic"
        ui_panel_line 16 '\033[1;38;5;45m' "Epic 与 FreeDeck 默认安装；战网、育碧、黑盒工坊按需选择"
        ui_touch_button 18 '\033[1;30;48;5;114m' "设置已完成，开始新机初始化" "点击即确认已开启开发者模式和 CEF 远程调试"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回新机必备" "暂不初始化"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        choice="$(read_touch_menu right:18-19:start right:20-21:init right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            start)
                run_action "新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/new_machine.sh"
                NEXT_CATEGORY="init"
                return 0
                ;;
            init) NEXT_CATEGORY="init"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

steam_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "SteamOS 掌机优化" "安全处理 Steam 缓存，并查看性能建议"
        ui_touch_button 8 '\033[1;97;48;5;24m' "清理 Steam 下载缓存" "删除未完成的下载残留"
        ui_touch_button 11 '\033[1;97;48;5;24m' "查看性能模式建议" "只读检查，不修改系统"
        ui_touch_button 14 '\033[1;97;48;5;24m' "清理着色器缓存" "释放空间，游戏会在下次启动时重建"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回系统优化" "查看其他优化功能"
        ui_prompt
        choice="$(read_touch_menu right:8-9:download-cache right:11-12:performance right:14-15:shader-cache right:17-18:back)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            download-cache) confirm_and_run "清理下载缓存" "清理后未完成的 Steam 下载需要重新开始" bash "$PROJECT_ROOT/modules/steam.sh" download-cache ;;
            performance) run_action "性能模式建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            shader-cache) confirm_and_run "清理着色器缓存" "清理后游戏着色器需要重新生成" bash "$PROJECT_ROOT/modules/steam.sh" shader-cache ;;
            back) return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "optimize" ] || return 0
    done
}

clean_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "系统清理" "只处理可重建的缓存，不删除游戏和个人文件"
        ui_touch_button 8 '\033[1;97;48;5;24m' "清理 Steam 下载残留" "释放未完成下载占用的空间"
        ui_touch_button 11 '\033[1;97;48;5;24m' "清理 Steam 着色器缓存" "下次运行游戏时会自动重建"
        ui_touch_button 14 '\033[1;97;48;5;24m' "清理 Linux 用户缓存" "不触碰 SteamOS 只读系统分区"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回系统优化" "查看其他优化功能"
        ui_prompt
        choice="$(read_touch_menu right:8-9:download-cache right:11-12:shader-cache right:14-15:user-cache right:17-18:back)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            download-cache) confirm_and_run "清理下载残留" "将删除 Steam 未完成的下载残留" bash "$PROJECT_ROOT/modules/clean.sh" download-cache ;;
            shader-cache) confirm_and_run "清理着色器缓存" "着色器会在下次运行游戏时重新生成" bash "$PROJECT_ROOT/modules/clean.sh" shader-cache ;;
            user-cache) confirm_and_run "清理用户缓存" "部分应用会在下次启动时重新生成缓存" bash "$PROJECT_ROOT/modules/clean.sh" user-cache ;;
            back) return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "optimize" ] || return 0
    done
}

game_environment_menu() {
    local choice

    while true; do
        draw_category_frame games "游戏与插件｜插件商城" "浏览插件商城、运行组件和启动器" 0
        ui_touch_button 5 '\033[1;97;48;5;160m' "安装插件商城" "稳定版国内失败自动切换官方源 · 可选测试版 · 高级操作"
        ui_touch_button 7 '\033[1;97;48;5;24m' "常用插件组合" "安装小黄鸭、FSR4、封面、主题等七款插件"
        ui_touch_button 9 '\033[1;97;48;5;24m' "浏览官方插件" "逐个查看插件作用"
        ui_touch_button 11 '\033[1;97;48;5;24m' "CheatDeck" "风灵月影修改器和启动项启动插件"
        ui_touch_button 13 '\033[1;97;48;5;24m' "小黄鸭" "插帧神器（必装）·汉化作者：Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）"
        ui_touch_button 15 '\033[1;97;48;5;24m' "FSR4" "画质补丁（阅读桌面文档慎用）·汉化作者：Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）"
        ui_touch_button 17 '\033[1;97;48;5;24m' "Freedeck 版本选择" "0.6 稳定版或 NewFreedeck 重构版"
        ui_touch_button 21 '\033[1;97;48;5;238m' "下一页…" "查看剩余插件"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:decky-install right:7-8:features right:9-10:browse right:11-12:cheatdeck right:13-14:lsfg right:15-16:fsr4 right:17-18:freedeck right:21-22:next right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            decky-install) NEXT_CATEGORY="decky_loader"; return 0 ;;
            features) confirm_and_run "安装常用插件组合" "请先在游戏模式：Steam 键 → 设置 → 启用开发者模式；设置左侧出现“开发者”后 → 开发者 → 杂项，开启“CEF 远程调试”，完成后重新进入桌面模式；未安装插件商城时会先安装插件商城，再继续安装七款常用插件；会使用管理员权限" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" features ;;
            browse) plugin_official_touch_pages ;;
            cheatdeck) confirm_and_run "安装 CheatDeck" "风灵月影修改器和启动项启动插件；来自作者 GitHub Release" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" cheatdeck ;;
            lsfg) confirm_and_run "安装小黄鸭" "插帧神器（必装）·国内源优先，失败自动改用 GitHub Release；汉化作者：Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-zh-gitee ;;
            fsr4) confirm_and_run "安装 FSR4" "画质补丁（阅读桌面文档慎用）·国内源优先，失败自动改用 GitHub Release；汉化作者：Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4-zh-gitee ;;
            freedeck) NEXT_CATEGORY="freedeck_versions"; return 0 ;;
            next) NEXT_CATEGORY="plugin_page_2"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "game_environment" ] || return 0
    done
}

freedeck_versions_menu() {
    local choice

    while true; do
        draw_category_frame games "Freedeck 版本选择" "稳定版与独立重构版" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "Freedeck 0.6 稳定版" "现有稳定版本·感谢作者b站一苇Isidf"
        ui_touch_button 9 '\033[1;97;48;5;160m' "NewFreedeck v0.1" "独立重构版·上游注明部分功能未完成"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回插件列表" "返回游戏与插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:stable right:9-10:new right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            stable)
                confirm_and_run "安装 Freedeck 0.6 稳定版" "安装现有稳定版本；感谢作者b站一苇Isidf" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" freedeck
                ;;
            new)
                confirm_and_run "安装 NewFreedeck v0.1" "作者独立重构版；上游注明部分功能尚未完成，可能使用异常" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" newfreedeck
                ;;
            back) NEXT_CATEGORY="games"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "freedeck_versions" ] || return 0
    done
}

decky_loader_menu() {
    local choice

    while true; do
        draw_category_frame games "安装插件商城｜Decky Loader" "稳定版适合正式系统 · 测试版只适合测试或预览系统 · 也可根据系统版本自动选择" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "安装稳定版插件商城" "国内失败自动切换 Decky 官方 Release"
        ui_touch_button 7 '\033[1;97;48;5;160m' "安装测试版插件商城" "仅用于 SteamOS 测试或预览通道 · 国内源优先"
        ui_touch_button 9 '\033[1;97;48;5;24m' "根据系统版本安装" "自动检测正式或测试通道并安装对应版本"
        ui_touch_button 12 '\033[1;97;48;5;24m' "安装 ROG White 白色主题" "白色主题美化 · 需先安装主题美化（CSS Loader）"
        ui_touch_button 14 '\033[1;97;48;5;24m' "安装 掌机 Pink 粉色主题" "粉色主题美化 · 需先安装主题美化（CSS Loader）"
        ui_touch_button 16 '\033[1;97;48;5;24m' "安装 粉白渐变 粉色主题" "浅粉渐变主题 · 需先安装主题美化（CSS Loader）"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回插件列表" "不进行安装"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:stable right:7-8:test right:9-10:auto right:12-13:rog-white-install right:14-15:handheld-pink-install right:16-17:pink-white-gradient-install right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            auto)
                confirm_and_run "按系统版本自动安装插件商城" "自动检测 SteamOS 正式或测试通道并安装对应版本；会先停用旧服务再安装，已有插件和设置保留" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" store-auto
                ;;
            stable)
                confirm_and_run "安装稳定版插件商城" "适合 SteamOS 正式系统；优先使用国内线路，失败自动切换 Decky 官方 Release；会停用旧版用户服务并切换到稳定通道，已有插件和设置保留" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" store
                ;;
            test)
                confirm_and_run "安装测试版插件商城" "仅当 SteamOS 使用测试或预览通道、稳定版 Decky 明确不兼容时使用；优先从国内镜像下载，失败自动回退 Decky 官方 prerelease Release；已有插件和设置保留" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" store-test
                ;;
            rog-white-install)
                confirm_and_run "安装 ROG White 白色主题" "将 Renkit 内置的 ROG White v1.4.6 白色主题放入 CSS Loader 主题目录；安装后请在 CSS Loader 中开启该主题" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/rog_white_theme.sh" install
                ;;
            handheld-pink-install)
                confirm_and_run "安装 掌机 Pink 粉色主题" "将 Renkit 内置的 Handheld Pink v1.0.1 粉色主题放入 CSS Loader 主题目录；安装后请在 CSS Loader 中开启该主题" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/handheld_pink_theme.sh" install
                ;;
            pink-white-gradient-install)
                confirm_and_run "安装 粉白渐变 粉色主题" "将 Renkit 内置的 Pink White Gradient v1.0.0 浅粉渐变主题放入 CSS Loader 主题目录；安装后请在 CSS Loader 中开启该主题" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/pink_white_gradient_theme.sh" install
                ;;
            back) NEXT_CATEGORY="games"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "decky_loader" ] || return 0
    done
}

plugin_page_2_menu() {
    local choice

    while true; do
        draw_category_frame games "插件安装｜更多" "更多独立插件和启动器" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "DeckRecall" "添加启动项及恢复游戏可玩状态"
        ui_touch_button 7 '\033[1;97;48;5;24m' "SavePulse" "自动版本存档、个人 WebDAV 云备份与换机恢复"
        ui_touch_button 9 '\033[1;97;48;5;24m' "掌机控制插件" "掌机功耗控制与 ROG Ally Center"
        ui_touch_button 11 '\033[1;97;48;5;24m' "Unifideck" "入库第三方平台游戏"
        ui_touch_button 13 '\033[1;97;48;5;24m' "ToMoon" "网络工具"
        ui_touch_button 15 '\033[1;97;48;5;24m' "安装 GE 兼容层" "提高 Windows 游戏兼容性"
        ui_touch_button 17 '\033[1;97;48;5;24m' "启动器与封面" "Epic、战网、育碧及封面修复"
        ui_touch_button 21 '\033[1;97;48;5;238m' "上一页" "返回插件列表"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:deckrecall right:7-8:savepulse right:9-10:handheld-plugins right:11-12:unifideck right:13-14:tomoon right:15-16:ge-proton right:17-18:launchers right:21-22:previous right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            deckrecall) confirm_and_run "安装 DeckRecall" "添加启动项及恢复游戏可玩状态；来自作者 GitHub Release，下载后会校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" deckrecall ;;
            savepulse) confirm_and_run "安装 SavePulse" "自动版本存档、个人坚果云或标准 WebDAV 云备份与换机恢复；来自作者 GitHub Release，下载后校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" savepulse ;;
            handheld-plugins) NEXT_CATEGORY="handheld_plugins"; return 0 ;;
            unifideck) confirm_and_run "安装 Unifideck" "入库第三方平台游戏；来自作者 GitHub Release" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" unifideck ;;
            tomoon) confirm_and_run "安装 ToMoon" "网络工具插件，下载后校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" tomoon ;;
            ge-proton) ge_proton_menu ;;
            launchers) NEXT_CATEGORY="launcher_tools"; return 0 ;;
            previous) NEXT_CATEGORY="games"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "plugin_page_2" ] || return 0
    done
}

launcher_tools_menu() {
    local choice

    while true; do
        draw_category_frame games "启动器与封面" "第三方启动器安装及 Steam 库封面修复" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "Epic 游戏启动器" "安装并添加到 Steam"
        ui_touch_button 7 '\033[1;97;48;5;24m' "战网与黑盒工坊" "进入战网安装子菜单"
        ui_touch_button 9 '\033[1;97;48;5;24m' "育碧" "安装并添加到 Steam"
        ui_touch_button 11 '\033[1;97;48;5;24m' "重新应用启动器封面" "重写 Steam 库封面，不依赖 Decky"
        ui_touch_button 13 '\033[1;97;48;5;24m' "HMCL 启动器" "Linux 原生 Minecraft 启动器 · 中文界面"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回插件第二页"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:5-6:epic right:7-8:battlenet right:9-10:ubisoft right:11-12:repair right:13-14:hmcl right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            epic) confirm_and_run "安装 Epic 游戏启动器" "安装并添加到 Steam" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" epic ;;
            battlenet) NEXT_CATEGORY="battlenet_submenu"; return 0 ;;
            ubisoft) confirm_and_run "安装育碧" "自动安装育碧游戏平台、创建桌面入口并添加到 Steam" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" ubisoft ;;
            hmcl) confirm_and_run "安装 HMCL 启动器" "Linux 原生 Minecraft 启动器；自动下载 HMCL 与 Java 运行环境并校验 SHA256，加入 Steam 与桌面" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" hmcl ;;
            repair) NEXT_CATEGORY="launcher_repair"; return 0 ;;
            back) NEXT_CATEGORY="plugin_page_2"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "launcher_tools" ] || return 0
    done
}

handheld_plugins_menu() {
    local choice

    while true; do
        draw_category_frame games "掌机控制插件" "功耗、灯光、按键、震动与风扇控制" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "掌机功耗控制" "SimpleDeckyTDP 汉化版·自动检测版本"
        ui_touch_button 7 '\033[1;97;48;5;24m' "Ally 控制中心" "ROG Ally / Ally X 的 RGB、TDP、风扇与充电上限"
        ui_touch_button 9 '\033[1;97;48;5;24m' "通用掌机 RGB" "HueSync 官方简体中文·支持多品牌掌机"
        ui_touch_button 11 '\033[1;97;48;5;24m' "Legion Go 控制中心" "初代 Legion Go 的按键、RGB、充电与风扇控制"
        ui_touch_button 13 '\033[1;97;48;5;24m' "GPD 控制中心" "GPD Win 系列 RGB 与按游戏配置"
        ui_touch_button 15 '\033[1;97;48;5;24m' "Legion Go 震动控制" "Legion Go / Go 2 震动与触控板反馈"
        ui_touch_button 17 '\033[1;97;48;5;24m' "Legion Go 2 风扇控制" "仅 Legion Go 2·不受限风扇曲线"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回插件列表" "返回游戏与插件第二页"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:simpledeckytdp right:7-8:allycenter right:9-10:huesync right:11-12:legiongo-remapper right:13-14:gpd-control right:15-16:lego-vibe right:17-18:lego2-fan right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            simpledeckytdp)
                confirm_and_run "安装/修复掌机功耗控制汉化版" "自动检测版本：非最新汉化版或检测到原版/旧版会自动替换；国内源优先，失败自动改用 GitHub Release；汉化作者：Ren-Amamiya-pixle / zliu9732-hub（闲鱼RenAmamiya）" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" simpledeckytdp-zh-gitee
                ;;
            allycenter)
                confirm_and_run "安装 Ally Center" "仅适用于 ROG Ally / Ally X；可控制摇杆 RGB、TDP、风扇和充电上限，插件需要 Decky root 权限；国内源优先，失败自动改用作者 GitHub Release" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" allycenter
                ;;
            huesync)
                confirm_and_run "安装通用掌机 RGB" "HueSync 官方已内置简体中文；支持多品牌掌机 RGB；需要 Decky root 权限；请勿与其他灯光插件同时控制同一设备；国内源优先，失败自动改用作者 GitHub Release" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" huesync
                ;;
            legiongo-remapper)
                confirm_and_run "安装 Legion Go 控制中心" "仅适用于初代 Legion Go，不支持 Legion Go S；可控制按键、RGB、80% 充电上限及实验性风扇曲线；需要 Decky root 权限；HHD 可能覆盖灯光设置" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" legiongo-remapper
                ;;
            gpd-control)
                confirm_and_run "安装 GPD 控制中心" "适用于支持的 GPD Win 掌机 RGB，支持按游戏配置；需要 Decky root 权限；国内源优先，失败自动改用作者 GitHub Release" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" gpd-control
                ;;
            lego-vibe)
                confirm_and_run "安装 Legion Go 震动控制" "适用于 Legion Go / Go 2，不支持 Go S；需要 SteamOS 3.8+、内核 6.18+ 和 hid-lenovo-go 驱动；需要 Decky root 权限" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lego-vibe
                ;;
            lego2-fan)
                confirm_and_run "安装 Legion Go 2 风扇控制" "高风险：仅适用于 Legion Go 2；插件允许不受限制的风扇曲线，错误设置可能在高温时使用过低转速并损伤设备；需要 Decky root 权限。确认理解风险后继续" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lego2-fan
                ;;
            back) NEXT_CATEGORY="plugin_page_2"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "handheld_plugins" ] || return 0
    done
}

ge_proton_menu() {
    local choice

    while true; do
        draw_category_frame games "GE 兼容层" "安装最新版或修改器常用兼容层" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "安装最新 GE 兼容层" "自动检测最新版本，不再删除旧版"
        ui_touch_button 9 '\033[1;97;48;5;24m' "安装修改器所需常用兼容层" "四个版本约1.72GB，下载较慢为正常现象"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回插件列表" "查看其他游戏组件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:latest right:9-10:trainer right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            latest)
                confirm_and_run "安装最新 GE 兼容层" "自动检测最新版本，不再删除旧版兼容层" bash "$PROJECT_ROOT/modules/ge_proton.sh" install
                ;;
            trainer)
                confirm_and_run "安装修改器所需常用兼容层" "安装 GE-Proton 7-55、8-25、9-27、10-29；约1.72GB，下载较慢为正常现象" bash "$PROJECT_ROOT/modules/ge_proton.sh" install-trainer
                ;;
            back) NEXT_CATEGORY="plugin_page_2"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "plugin_page_2" ] || return 0
    done
}

battlenet_submenu() {
    local choice

    while true; do
        draw_category_frame games "战网安装" "战网启动器与黑盒工坊" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "战网启动器" "自动下载预装客户端并添加到 Steam"
        ui_touch_button 7 '\033[1;97;48;5;24m' "黑盒工坊" "魔兽插件管理工具；自动下载预装客户端并添加到 Steam"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回" "返回更多插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:battlenet right:7-8:heihe right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            battlenet) confirm_and_run "安装战网启动器" "自动下载预装客户端并绑定 Proton 10.0-4，写入 Steam 库" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" battlenet ;;
            heihe) confirm_and_run "安装黑盒工坊" "自动下载预装客户端并绑定 Proton 10.0-4，写入 Steam 库；需要先安装战网启动器" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" heihe ;;
            back) NEXT_CATEGORY="launcher_tools"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "battlenet_submenu" ] || return 0
    done
}

launcher_repair_menu() {
    local choice

    while true; do
        draw_category_frame games "重新应用启动器封面" "重写 Steam 库封面并重启 Steam" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "Epic 游戏启动器" "重写 Epic 封面"
        ui_touch_button 7 '\033[1;97;48;5;24m' "战网启动器" "重写战网封面"
        ui_touch_button 9 '\033[1;97;48;5;24m' "育碧" "重写育碧封面"
        ui_touch_button 11 '\033[1;97;48;5;24m' "黑盒工坊" "重写黑盒工坊封面"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回" "返回更多插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:epic right:7-8:battlenet right:9-10:ubisoft right:11-12:heihe right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            epic) confirm_and_run "重新应用 Epic 封面" "重写 Steam 库封面并重启 Steam，不依赖 Decky" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" apply-artwork epic ;;
            battlenet) confirm_and_run "重新应用战网封面" "重写 Steam 库封面并重启 Steam，不依赖 Decky" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" apply-artwork battlenet ;;
            ubisoft) confirm_and_run "重新应用育碧封面" "重写 Steam 库封面并重启 Steam，不依赖 Decky" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" apply-artwork ubisoft ;;
            heihe) confirm_and_run "重新应用黑盒工坊封面" "重写 Steam 库封面并重启 Steam，不依赖 Decky" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/game_launchers.sh" apply-artwork heihe ;;
            back) NEXT_CATEGORY="launcher_tools"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "launcher_repair" ] || return 0
    done
}

emulator_menu() {
    local choice

    while true; do
        draw_category_frame emulators "安装模拟器" "安装后自动创建桌面图标，并添加到 Steam 库" 0
        ui_touch_button 2 '\033[1;97;48;5;28m' "一键安装 6 款" "Switch、Wii U、PS1、PS2、PS3、PS4"
        ui_touch_button 5 '\033[1;97;48;5;24m' "Yuzu" "Switch 模拟器"
        ui_touch_button 7 '\033[1;97;48;5;24m' "Cemu" "Wii U 模拟器"
        ui_touch_button 9 '\033[1;97;48;5;24m' "DuckStation" "PS1 模拟器"
        ui_touch_button 11 '\033[1;97;48;5;24m' "PCSX2" "PS2 模拟器"
        ui_touch_button 13 '\033[1;97;48;5;24m' "RPCS3" "PS3 模拟器"
        ui_touch_button 15 '\033[1;97;48;5;24m' "ShadPS4" "PS4 模拟器"
        ui_touch_button 17 '\033[1;97;48;5;24m' "PPSSPP" "PSP 模拟器"
        ui_touch_button 19 '\033[1;97;48;5;24m' "mGBA" "GBA 模拟器"
        ui_touch_button 21 '\033[1;97;48;5;24m' "Azahar" "3DS 模拟器"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:2-3:install-all right:5-6:yuzu right:7-8:cemu right:9-10:duckstation right:11-12:pcsx2 right:13-14:rpcs3 right:15-16:shadps4 right:17-18:ppsspp right:19-20:mgba right:21-22:azahar right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            install-all)
                confirm_and_run "一键安装 6 款模拟器" "依次安装 Yuzu、Cemu、DuckStation、PCSX2、RPCS3 和 ShadPS4；只安装模拟器本体，不包含游戏、BIOS、固件或密钥。已完整安装的项目会跳过，单项失败不会中断后续安装。" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" install-all
                ;;
            yuzu) yuzu_menu ;;
            cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                confirm_and_run "安装模拟器" "只安装模拟器本体；不包含游戏、BIOS 或固件。完成后会创建桌面图标并添加到 Steam 库；写入 Steam 前会安全退出并重启 Steam。" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" "$choice"
                ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "emulators" ] || return 0
    done
}

yuzu_menu() {
    local choice

    while true; do
        draw_category_frame emulators "Yuzu｜Switch 模拟器" "只导入本人合法备份的密钥；不下载或提供密钥" 0
        ui_touch_button 7 '\033[1;97;48;5;24m' "安装 Yuzu" "仅安装模拟器本体"
        ui_touch_button 12 '\033[1;97;48;5;24m' "导入本人备份的密钥" "从桌面 Yuzu密钥 文件夹导入 prod.keys"
        ui_touch_button 17 '\033[1;97;48;5;238m' "查看密钥状态" "只显示是否已就绪，不显示密钥内容"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回模拟器列表" "不做任何修改"
        ui_prompt
        choice="$(read_touch_menu right:7-8:install right:12-13:keys right:17-18:status right:22-23:back)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            install) confirm_and_run "安装 Yuzu" "只安装模拟器本体；不包含游戏、BIOS、固件或密钥。" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" yuzu ;;
            keys) confirm_and_run "导入 Yuzu 密钥" "仅导入你本人合法备份的 prod.keys / title.keys；不会下载、显示或分享密钥。" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" yuzu-keys ;;
            status) run_action "Yuzu 密钥状态" bash "$PROJECT_ROOT/modules/emulators.sh" yuzu-keys-status ;;
            back) return 0 ;;
        esac
    done
}

plugin_official_touch_pages() {
    local choice
    local page=0
    local total="${#DECKY_OFFICIAL_PLUGIN_NAMES[@]}"
    local total_pages=$(((total + DECKY_TOUCH_PAGE_SIZE - 1) / DECKY_TOUCH_PAGE_SIZE))
    local start
    local index
    local slot
    local row

    while true; do
        draw_category_frame games "官方插件（第 $((page + 1)) / $total_pages 页）" "点击插件即可安装"
        start=$((page * DECKY_TOUCH_PAGE_SIZE))
        for slot in 0 1 2 3 4; do
            index=$((start + slot))
            [ "$index" -lt "$total" ] || break
            row=$((6 + slot * 2))
            ui_touch_button "$row" '\033[1;97;48;5;24m' \
                "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}" \
                "${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}"
        done
        if [ "$page" -gt 0 ]; then
            ui_touch_button 16 '\033[1;97;48;5;238m' "上一页" "查看前一组插件"
        else
            ui_touch_button 16 '\033[1;97;48;5;238m' "返回游戏与插件" "查看其他游戏组件"
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            ui_touch_button 18 '\033[1;97;48;5;30m' "下一页" "继续查看更多插件"
        else
            ui_touch_button 18 '\033[1;97;48;5;238m' "返回游戏与插件" "已是最后一页"
        fi
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu \
            right:6-7:plugin-$((start)) \
            right:8-9:plugin-$((start + 1)) \
            right:10-11:plugin-$((start + 2)) \
            right:12-13:plugin-$((start + 3)) \
            right:14-15:plugin-$((start + 4)) \
            right:16-17:previous \
            right:18-19:next \
            right:20-21:home)"
        case "$choice" in
            nav-*) apply_navigation "$choice"; return 0 ;;
        esac

        case "$choice" in
            plugin-*)
                index="${choice#plugin-}"
                if [ "$index" -lt "$total" ]; then
                    confirm_and_run "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}" \
                        "${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}；安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将由 Decky 官方商店安装" \
                        env ZHOUKEER_AUTO_CONFIRM=1 \
                        bash "$PROJECT_ROOT/modules/decky_bundle.sh" plugin "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}"
                fi
                ;;
            previous)
                if [ "$page" -gt 0 ]; then
                    page=$((page - 1))
                else
                    return 0
                fi
                ;;
            next)
                if [ "$page" -lt $((total_pages - 1)) ]; then
                    page=$((page + 1))
                else
                    return 0
                fi
                ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

dual_system_menu() {
    local choice page=0

    while true; do
        if [ "$page" -eq 0 ]; then
            draw_category_frame advanced "双系统常用工具" "磁盘与互通盘 · 第 1/2 页"
            ui_touch_button 5 '\033[1;97;48;5;24m' "挂载双系统互通盘" "自动排除 Windows 系统分区"
            ui_touch_button 7 '\033[1;97;48;5;160m' "初始化并挂载 TF 卡" "会清空目标卡并格式化为 NTFS"
            ui_touch_button 9 '\033[1;97;48;5;160m' "修复磁盘写入错误" "NTFS/exFAT 基础修复 · 会卸载磁盘"
            ui_touch_button 11 '\033[1;97;48;5;30m' "双系统互通盘保护" "重新挂载为只读，防止升级后掉盘"
            ui_touch_button 19 '\033[1;97;48;5;24m' "更多双系统工具" "状态、删除与第三方引导清理"
            ui_touch_button 21 '\033[1;97;48;5;238m' "返回系统设置" "查看其他系统功能"
            ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
            ui_prompt
            choice="$(read_touch_menu right:5-6:mount right:7-8:tf-format right:9-10:repair-drive right:11-12:protect right:19-20:next right:21-22:advanced right:23-24:home)"
        else
            draw_category_frame advanced "更多双系统工具" "只读检查、恢复与引导清理 · 第 2/2 页"
            ui_touch_button 5 '\033[1;97;48;5;24m' "双系统健康检查" "识别 Clover、rEFInd、GRUB、OpenCore 等"
            ui_touch_button 7 '\033[1;97;48;5;24m' "恢复互通盘写入" "退出只读保护并重新挂载"
            ui_touch_button 9 '\033[1;97;48;5;160m' "清理第三方引导项" "仅删选定 NVRAM，保留 EFI 文件"
            ui_touch_button 11 '\033[1;97;48;5;24m' "修复双系统引导" "补齐缺失引导项并恢复启动顺序"
            ui_touch_button 13 '\033[1;97;48;5;24m' "创建切换至 Windows 快捷方式" "仅创建桌面图标，本次不会重启"
            ui_touch_button 15 '\033[1;97;48;5;24m' "应用 Renkit 开机背景" "替换 Clover Apocalypse 主题背景"
            ui_touch_button 19 '\033[1;97;48;5;24m' "返回常用工具" "回到双系统常用功能"
            ui_touch_button 21 '\033[1;97;48;5;238m' "返回系统设置" "查看其他系统功能"
            ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
            ui_prompt
            choice="$(read_touch_menu right:5-6:health right:7-8:unprotect right:9-10:cleanup-boot right:11-12:repair-boot right:13-14:switch-to-windows right:15-16:clover-background right:19-20:previous right:21-22:advanced right:23-24:home)"
        fi
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            mount)
                confirm_and_run "挂载互通盘" "将自动识别唯一的未挂载 NTFS/exFAT 分区并创建快捷入口" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" mount
                ;;
            tf-format)
                confirm_and_run "初始化并挂载 TF 卡" "会永久清空自动识别出的唯一 TF 卡，并格式化为 NTFS；随后仍需输入完整设备名确认" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" tf-format-mount
                ;;
            repair-drive)
                confirm_and_run "修复磁盘写入错误" "会卸载唯一互通盘并运行 NTFS/exFAT 基础修复；严重 NTFS 错误仍需 Windows chkdsk" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" repair-drive
                ;;
            protect)
                confirm_and_run "保护双系统互通盘" "会重新以只读模式挂载互通盘；SteamOS 下将无法写入或删除该盘文件" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" protect
                ;;
            unprotect)
                confirm_and_run "恢复互通盘写入" "会重新以可写模式挂载互通盘，恢复 SteamOS 下的正常读写" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" unprotect
                ;;
            health) run_action "双系统健康检查" bash "$PROJECT_ROOT/modules/dual_system_tools.sh" health ;;
            cleanup-boot)
                confirm_and_run "清理第三方引导项" "SteamOS、Windows 和 systemd-boot 受保护；其他项还需输入 Boot 编号和完整删除口令" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" cleanup-boot
                ;;
            repair-boot)
                confirm_and_run "修复双系统引导" "将按设备安装/修复 Clover 开机菜单，并启用开机修复服务；会修改 EFI/NVRAM" \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" install
                ;;
            switch-to-windows)
                confirm_and_run "创建切换至 Windows 快捷方式" "只在桌面创建图标；本次不会设置 BootNext，也不会重启" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" windows-shortcut
                ;;
            clover-background)
                confirm_and_run "应用 Renkit 开机背景" "仅替换 esp/efi/clover/themes/Apocalypse/background.png，不修改其他 Clover 文件" \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" apply-background
                ;;
            next) page=1; continue ;;
            previous) page=0; continue ;;
            advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

domestic_source_preflight() {
    local choice

    while true; do
        draw_category_frame advanced "初始化国内源并检测系统组件" "提高国内应用下载速度，完整更新系统组件"
        ui_panel_line 7 '\033[1;38;5;220m' "flathub-cn｜https://mirror.sjtu.edu.cn/flathub"
        ui_panel_line 9 '\033[1;38;5;220m' "flathub-ustc｜https://mirrors.ustc.edu.cn/flathub"
        ui_panel_line 11 '\033[1;38;5;220m' "archlinuxcn｜上海交大 → 中科大 → 官方回退"
        ui_panel_line 13 '\033[1;38;5;203m' "Flatpak 缓存关闭 GPG；archlinuxcn 保持 GPG 验证"
        ui_panel_line 15 '\033[1;38;5;203m' "pacman 完整更新 + locale｜临时关闭只读保护｜可恢复"
        ui_touch_button 17 '\033[1;97;48;5;160m' "初始化国内源并检测系统组件" "完整更新系统组件并配置国内缓存"
        ui_touch_button 19 '\033[1;97;48;5;30m' "恢复官方软件源" "恢复 Flathub 并移除Renkit archlinuxcn"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回系统设置" "不做任何修改"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:17-18:confirm-source right:19-20:restore-source right:21-22:advanced right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            confirm-source)
                run_action "初始化国内源并检测系统组件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/domestic_source.sh" init
                NEXT_CATEGORY="advanced"
                return 0
                ;;
            restore-source)
                run_action "恢复官方软件源" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/domestic_source.sh" restore
                NEXT_CATEGORY="advanced"
                return 0
                ;;
            advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

memory_touch_menu() {
    local choice

    while true; do
        draw_category_frame advanced "虚拟内存" "优化、查看或撤销Renkit设置"
        ui_touch_button 7 '\033[1;97;48;5;24m' "一键优化" "设置 zram 与磁盘 swap"
        ui_touch_button 11 '\033[1;97;48;5;24m' "查看状态" "查看当前 zram 与 swap"
        ui_touch_button 15 '\033[1;97;48;5;160m' "撤销Renkit优化" "保留系统原 swap"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回更多设置" "查看其他系统功能"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:optimize right:11-12:status right:15-16:restore right:19-20:advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            optimize)
                confirm_and_run "一键优化虚拟内存" "会设置 zram、磁盘 swap 和 swappiness；失败时自动恢复" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/memory_tuning.sh" optimize
                return 0
                ;;
            status)
                run_action "虚拟内存状态" bash "$PROJECT_ROOT/modules/memory_tuning.sh" status
                return 0
                ;;
            restore)
                confirm_and_run "撤销Renkit虚拟内存优化" "只删除Renkit创建的配置和独立 swap；系统原 swap 会保留" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/memory_tuning.sh" restore
                return 0
                ;;
            advanced) return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

f1_handheld_menu() {
    local choice

    while true; do
        draw_category_frame advanced "掌机适配" "飞行家 F1 屏幕方向修复 · 不使用 sudo"
        ui_touch_button 7 '\033[1;97;48;5;24m' "安装修复" "仅适用于 ONEXPLAYER F1"
        ui_touch_button 9 '\033[1;97;48;5;24m' "检查状态" "查看修复文件和 systemd override"
        ui_touch_button 11 '\033[1;97;48;5;160m' "卸载修复" "删除用户级修复并恢复原始启动方式"
        ui_touch_button 13 '\033[1;97;48;5;160m' "立即重启 SteamOS" "重启后生效 · 请先保存工作"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回更多设置" "查看其他系统功能"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:install right:9-10:status right:11-12:uninstall right:13-14:reboot right:19-20:advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            install)
                confirm_and_run "安装飞行家 F1 屏幕方向修复" "仅适用于 ONEXPLAYER F1；使用用户级 systemd override，不使用 sudo" \
                    bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" install
                return 0
                ;;
            status)
                run_action "飞行家 F1 屏幕方向修复状态" bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" status
                return 0
                ;;
            uninstall)
                confirm_and_run "卸载飞行家 F1 屏幕方向修复" "将删除用户级修复文件并刷新 systemd，不使用 sudo" \
                    bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" uninstall
                return 0
                ;;
            reboot)
                confirm_and_run "立即重启 SteamOS" "将立即重启；请先保存所有工作" \
                    bash "$PROJECT_ROOT/modules/f1_screen_fix.sh" reboot
                return 0
                ;;
            advanced) return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

advanced_tools_menu() {
    local choice

    while true; do
        draw_category_frame advanced "更多设置" "国内下载、网络加速、内存、密码与双系统"
        ui_touch_button 7 '\033[1;97;48;5;160m' "国内软件源" "会修改 Flatpak 软件源 · 高级操作"
        ui_touch_button 9 '\033[1;97;48;5;160m' "Steamcommunity 302" "可能修改 DNS 和证书 · 高级操作"
        ui_touch_button 11 '\033[1;97;48;5;160m' "虚拟内存" "设置 zram、swap 或撤销 · 高级操作"
        ui_touch_button 13 '\033[1;97;48;5;160m' "修改管理员密码" "会更换 SteamOS 管理密码 · 高级操作"
        ui_touch_button 15 '\033[1;97;48;5;160m' "双系统与互通盘" "管理磁盘和开机菜单 · 高级操作"
        ui_touch_button 17 '\033[1;97;48;5;24m' "掌机适配" "飞行家 F1 屏幕方向修复 · 不使用 sudo"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:domestic-source right:9-10:accelerator right:11-12:memory right:13-14:change-password right:15-16:dual right:17-18:handheld right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            domestic-source) domestic_source_preflight ;;
            accelerator) steam_accelerator_touch_menu ;;
            memory) memory_touch_menu ;;
            change-password) confirm_and_run "修改管理员密码" "将读取旧记录并明文保存新密码；当前用户运行的软件都可能读取" bash "$PROJECT_ROOT/modules/password.sh" change ;;
            dual) dual_system_menu ;;
            handheld) f1_handheld_menu ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

uninstall_software_menu() {
    local choice page=0

    while true; do
        case "$page" in
            0)
                draw_category_frame uninstall "卸载已安装" "聊天、浏览器与远程工具 · 第 1/7 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载微信" "只删除微信 AppImage 和快捷方式"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 QQ" "卸载 QQ Flatpak"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Firefox" "卸载 Firefox Flatpak"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 Chrome" "卸载 Google Chrome Flatpak"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 Edge" "卸载 Microsoft Edge Flatpak"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 RustDesk" "保留用户自行配置的数据"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 ToDesk" "停止服务并卸载系统软件包"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载百度网盘" "卸载百度网盘 Flatpak"
                ui_touch_button 18 '\033[1;97;48;5;24m' "下一页" "办公与创作工具"
                ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:2-3:wechat right:4-5:qq right:6-7:browser right:8-9:chrome right:10-11:edge right:12-13:rustdesk right:14-15:todesk right:16-17:baidunetdisk right:18-19:next right:20-21:home)"
                ;;
            1)
                draw_category_frame uninstall "卸载已安装" "办公与创作 · 第 2/7 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 AnyDesk" "卸载 AnyDesk Flatpak"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 WiliWili" "卸载 WiliWili Flatpak 与 Steam 条目"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Xbox 云游戏" "卸载 Greenlight Flatpak"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 LibreOffice" "卸载 LibreOffice Flatpak"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 VLC" "卸载 VLC Flatpak"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 OBS Studio" "卸载 OBS Studio Flatpak"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 LocalSend" "卸载 LocalSend Flatpak"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 PeaZip" "卸载 PeaZip Flatpak"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "返回常用应用"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页" "兼容、音乐与下载工具"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:2-3:anydesk right:4-5:willwill right:6-7:xbox-cloud right:8-9:libreoffice right:10-11:vlc right:12-13:obs right:14-15:localsend right:16-17:peazip right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            2)
                draw_category_frame uninstall "卸载已安装" "兼容、音乐与下载 · 第 3/7 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载中文输入法" "卸载 Fcitx5 及中文输入插件"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 Protontricks" "卸载 Protontricks Flatpak"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Bottles" "卸载 Bottles Flatpak"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 QQ音乐" "卸载 QQ音乐 Flatpak"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载网易云音乐" "卸载网易云音乐 Flatpak"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 YesPlayMusic" "卸载 YesPlayMusic Flatpak"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 qBittorrent" "卸载 qBittorrent Flatpak"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 Motrix" "卸载 Motrix 下载器 Flatpak"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "返回办公与创作"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页" "下载、笔记与游戏串流"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:2-3:fcitx5 right:4-5:protontricks right:6-7:bottles right:8-9:qqmusic right:10-11:netease-music right:12-13:yesplaymusic right:14-15:qbittorrent right:16-17:motrix right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            3)
                draw_category_frame uninstall "卸载已安装" "下载、办公、笔记与串流 · 第 4/7 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 Free Download Manager" "卸载 Free Download Manager Flatpak"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 Media Downloader" "卸载 Media Downloader Flatpak"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Flameshot 截图" "卸载 Flameshot Flatpak"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 OnlyOffice" "卸载 OnlyOffice Flatpak"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 Joplin 笔记" "卸载 Joplin Flatpak"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 Heroic" "移除 Heroic 及 Steam 库条目"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 Lutris" "移除 Lutris 及 Steam 库条目"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 Chiaki4Deck" "移除 Chiaki4Deck 及 Steam 库条目"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "返回兼容、音乐与下载"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页" "游戏启动器与模拟器"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:2-3:freedownloadmanager right:4-5:media-downloader right:6-7:flameshot right:8-9:onlyoffice right:10-11:joplin right:12-13:heroic right:14-15:lutris right:16-17:chiaki4deck right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            4)
                draw_category_frame uninstall "卸载已安装" "游戏启动器与模拟器 · 第 5/7 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 Parsec" "移除 Parsec 及 Steam 库条目"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载战网启动器" "保留战网游戏与下载文件"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Epic" "保留 Epic 游戏与下载文件"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载育碧" "保留育碧游戏与下载文件"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载黑盒工坊" "保留插件与游戏文件"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 Yuzu" "保留游戏存档与配置"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 Cemu" "保留游戏存档与配置"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 DuckStation" "保留游戏存档与配置"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "返回下载、笔记与串流"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页" "更多模拟器与系统组件"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:2-3:parsec right:4-5:battlenet right:6-7:epic right:8-9:ubisoft right:10-11:heihe right:12-13:yuzu right:14-15:cemu right:16-17:duckstation right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            5)
                draw_category_frame uninstall "卸载已安装" "模拟器与系统组件 · 第 6/7 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 PCSX2" "保留游戏存档与配置"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 RPCS3" "保留游戏存档与配置"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 ShadPS4" "保留游戏存档与配置"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 PPSSPP" "保留游戏存档与配置"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 mGBA" "保留游戏存档与配置"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 Azahar" "保留 3DS 存档与密钥"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 Steam302" "停止后台加速并移除开机自启"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 GE-Proton" "只删除Renkit当前版本"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页" "返回游戏启动器与模拟器"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页" "Decky 组件"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:2-3:pcsx2 right:4-5:rpcs3 right:6-7:shadps4 right:8-9:ppsspp right:10-11:mgba right:12-13:azahar right:14-15:steam302 right:16-17:ge-proton right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            *)
                draw_category_frame uninstall "卸载已安装" "Decky 组件 · 第 7/7 页"
                ui_touch_button 5 '\033[1;97;48;5;160m' "卸载 Decky Loader" "保留全部插件文件与设置"
                ui_touch_button 8 '\033[1;97;48;5;160m' "清空全部 Decky 插件" "删除插件与插件设置 · 高风险"
                ui_touch_button 20 '\033[1;97;48;5;24m' "上一页" "返回模拟器与系统组件"
                ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "不卸载任何软件"
                ui_prompt
                choice="$(read_touch_menu right:5-6:decky-loader right:8-9:decky-plugins right:20-21:previous right:23-24:home)"
                ;;
        esac
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            wechat|qq|browser|chrome|edge|rustdesk|anydesk|baidunetdisk|libreoffice|vlc|obs|localsend|peazip|willwill|fcitx5|protontricks|bottles|xbox-cloud|qqmusic|netease-music|yesplaymusic|qbittorrent|motrix|freedownloadmanager|media-downloader|flameshot|onlyoffice|joplin|heroic|lutris|chiaki4deck|parsec)
                confirm_and_run "卸载软件" "只卸载所选软件及Renkit创建的快捷方式" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" uninstall "$choice"
                ;;
            battlenet|epic|ubisoft|heihe)
                confirm_and_run "卸载游戏启动器" "会移除 Steam 库条目和桌面入口，保留游戏与下载文件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" uninstall "$choice"
                ;;
            yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                confirm_and_run "卸载模拟器" "会移除 Steam 库条目和桌面入口，保留存档与配置" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/emulators.sh" uninstall "$choice"
                ;;
            todesk)
                confirm_and_run "卸载 ToDesk" "会停止服务并临时关闭 SteamOS 只读保护，完成后自动恢复" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --uninstall
                ;;
            steam302)
                confirm_and_run "卸载 Steam302" "会停止后台加速并移除开机自启" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            ge-proton)
                confirm_and_run "卸载 GE-Proton" "只删除Renkit当前 GE-Proton 版本" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" uninstall
                ;;
            decky-loader)
                confirm_and_run "卸载 Decky Loader" "会停止加载器并保留全部插件目录" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" store-uninstall
                ;;
            decky-plugins)
                confirm_and_run "清空全部 Decky 插件" "会删除全部插件文件和插件设置，但保留 Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" uninstall
                ;;
            next) page=$((page + 1)); [ "$page" -le 6 ] || page=6 ;;
            previous) page=$((page - 1)); [ "$page" -ge 0 ] || page=0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

steam_accelerator_touch_menu() {
    local choice

    while true; do
        draw_category_frame advanced "Steamcommunity 302" "加速 Steam 和 GitHub"
        ui_touch_button 5 '\033[1;97;48;5;24m' "安装或更新" "安装 Steamcommunity 302"
        ui_touch_button 7 '\033[1;97;48;5;30m' "一键开启加速" "自动准备并启动 Steam + GitHub 后台加速"
        ui_touch_button 9 '\033[1;97;48;5;24m' "打开官方配置界面" "官方配置窗口"
        ui_touch_button 11 '\033[1;97;48;5;24m' "重置加速" "停止并重新启动后台加速服务"
        ui_touch_button 13 '\033[1;97;48;5;24m' "查看运行状态" "检查加速是否开启"
        ui_touch_button 15 '\033[1;97;48;5;160m' "安全卸载" "先停止Renkit进程，再删除程序文件"
        ui_touch_button 17 '\033[1;97;48;5;24m' "主机加速器" "奇游、迅游、UU 官方安装与配置入口"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回系统设置" "查看其他系统功能"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:install right:7-8:start right:9-10:launch right:11-12:reset right:13-14:status right:15-16:uninstall right:17-18:console-accelerators right:19-20:advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            install)
                confirm_and_run "Steamcommunity 302" "安装后开启加速会修改网络设置并需要管理员权限" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
                ;;
            start)
                confirm_and_run "开启 Steamcommunity 302" "会修改网络设置并需要管理员权限" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" enable
                ;;
            launch)
                confirm_and_run "打开 Steamcommunity 302 配置界面" "会启动官方配置窗口" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" launch
                ;;
            reset)
                confirm_and_run "重置 Steamcommunity 302 加速" "会停止并重新启动后台加速服务" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" reset
                ;;
            status) run_action "Steamcommunity 302 状态" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status ;;
            uninstall)
                confirm_and_run "卸载 Steamcommunity 302" "会停止Renkit启动的进程；官方 systemd、hosts、DNS 和证书需按官方程序另行处理" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            console-accelerators) console_accelerator_touch_menu ;;
            advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

console_accelerator_touch_menu() {
    local choice

    while true; do
        draw_category_frame advanced "主机加速器" "打开奇游、迅游、UU 官方安装与配置页面"
        ui_touch_button 7 '\033[1;97;48;5;24m' "奇游主机加速" "手机 App、联机宝或路由方案"
        ui_touch_button 10 '\033[1;97;48;5;24m' "迅游主机加速" "打开官方主机加速页面"
        ui_touch_button 13 '\033[1;97;48;5;24m' "网易UU主机加速" "手机 App、路由插件或加速盒"
        ui_panel_line 16 '\033[1;38;5;220m' "三家均无 SteamOS 原生客户端，不安装 Windows 版"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回加速设置" "回到 Steamcommunity 302"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:qiyou right:10-11:xunyou right:13-14:uu right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            qiyou|xunyou|uu)
                run_action "打开主机加速器官方页面" \
                    bash "$PROJECT_ROOT/modules/console_accelerators.sh" "$choice"
                ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

support_menu() {
    local choice

    while true; do
        draw_category_frame support "检查与维护" "检查网络与常见问题，按结果处理或发给维护人员"
        ui_touch_button 5 '\033[1;97;48;5;24m' "一键检查网络" "自动检查常用下载连接，不修改设置"
        ui_touch_button 7 '\033[1;97;48;5;24m' "检查常见问题" "检查系统、游戏和可安全清理的内容"
        ui_touch_button 9 '\033[1;97;48;5;24m' "查看下载状态" "查看最近成功时间和失败原因"
        ui_touch_button 11 '\033[1;97;48;5;24m' "发给维护人员" "生成诊断包，不包含密码和隐私信息"
        ui_touch_button 13 '\033[1;97;48;5;24m' "使用帮助与设置" "查看指南、备份设置和Renkit更新"
        ui_touch_button 15 '\033[1;97;48;5;160m' "更多设置" "管理国内下载和加速功能"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:network-status right:7-8:maintenance right:9-10:source-status right:11-12:diagnostic-bundle right:13-14:help right:15-16:manage-advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            network-status) run_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            maintenance) maintenance_menu; return 0 ;;
            source-status) run_action "查看下载状态" bash "$PROJECT_ROOT/modules/diagnostics.sh" status ;;
            diagnostic-bundle) run_action "发给维护人员" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            help) help_menu; return 0 ;;
            manage-advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

maintenance_menu() {
    local choice

    while true; do
        draw_category_frame support "系统维护" "清理缓存和检查系统"
        ui_touch_button 5 '\033[1;97;48;5;24m' "系统健康检查" "检查空间和常用环境"
        ui_touch_button 7 '\033[1;97;48;5;24m' "游戏启动检查" "检查游戏无法启动原因"
        ui_touch_button 9 '\033[1;97;48;5;160m' "清理下载残留" "删除未完成下载文件 · 会删除缓存"
        ui_touch_button 11 '\033[1;97;48;5;160m' "清理着色器缓存" "释放空间并自动重建 · 会删除缓存"
        ui_touch_button 13 '\033[1;97;48;5;160m' "清理用户缓存" "清理可重新生成的缓存 · 会删除缓存"
        ui_touch_button 15 '\033[1;97;48;5;24m' "查看性能建议" "查看推荐性能设置"
        ui_touch_button 17 '\033[1;97;48;5;160m' "常见问题处理" "检测网络并清理下载残留 · 会删除缓存"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:health right:7-8:diagnose right:9-10:download-cache right:11-12:shader-cache right:13-14:user-cache right:15-16:performance right:17-18:fix right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            health) run_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            diagnose) run_action "游戏启动检查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            download-cache) confirm_and_run "清理下载残留" "将删除 Steam 未完成的下载残留" bash "$PROJECT_ROOT/modules/clean.sh" download-cache ;;
            shader-cache) confirm_and_run "清理着色器缓存" "着色器会在下次运行游戏时重新生成" bash "$PROJECT_ROOT/modules/clean.sh" shader-cache ;;
            user-cache) confirm_and_run "清理用户缓存" "部分应用会在下次启动时重新生成缓存" bash "$PROJECT_ROOT/modules/clean.sh" user-cache ;;
            performance) run_action "查看性能建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            fix) confirm_and_run "常见问题处理" "将检查网络状态并清理 Steam 未完成的下载残留" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "maintenance" ] || return 0
    done
}

help_menu() {
    local choice
    local page=1

    while true; do
        draw_category_frame support "使用帮助与设置（第 $page / 2 页）" "默认显示结果，需要时再看详细信息"
        if [ "$page" -eq 1 ]; then
            ui_touch_button 5 '\033[1;97;48;5;24m' "查看系统信息" "查看系统和设备信息"
            ui_touch_button 7 '\033[1;97;48;5;24m' "生成诊断包" "可直接发给维护人员，不包含密码和隐私信息"
            ui_touch_button 9 '\033[1;97;48;5;24m' "新手使用指南" "查看基础操作说明"
            ui_touch_button 11 '\033[1;97;48;5;24m' "游戏兼容指南" "查看游戏运行建议"
            ui_touch_button 13 '\033[1;97;48;5;24m' "掌机常用快捷键" "查看常用按键方法"
            ui_touch_button 15 '\033[1;97;48;5;24m' "外接设备检查" "检查显示器和蓝牙"
            ui_touch_button 19 '\033[1;97;48;5;30m' "下一页" "查看记录和Renkit更新"
        else
            ui_touch_button 5 '\033[1;97;48;5;24m' "备份Renkit设置" "只备份Renkit管理的内容"
            ui_touch_button 7 '\033[1;97;48;5;160m' "恢复Renkit设置" "先列出内容并备份当前状态"
            ui_touch_button 9 '\033[1;97;48;5;24m' "查看详细网络信息" "查看各条连接的技术详情"
            ui_touch_button 11 '\033[1;97;48;5;24m' "导出旧版文字报告" "仅用于兼容旧排查流程"
            ui_touch_button 13 '\033[1;97;48;5;24m' "操作记录" "导出最近Renkit记录"
            ui_touch_button 15 '\033[1;97;48;5;24m' "更新日志" "查看版本改动内容"
            ui_touch_button 17 '\033[1;97;48;5;160m' "检查并更新Renkit" "下载并安装最新版本 · 会联网并更新"
            ui_touch_button 19 '\033[1;97;48;5;238m' "上一页" "返回系统信息和指南"
        fi
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        if [ "$page" -eq 1 ]; then
            choice="$(read_touch_menu right:5-6:system-info right:7-8:diagnostic-bundle right:9-10:new-guide right:11-12:game-guide right:13-14:shortcuts right:15-16:peripherals right:19-20:next right:22-23:home)"
        else
            choice="$(read_touch_menu right:5-6:backup-settings right:7-8:restore-settings right:9-10:network-details right:11-12:report right:13-14:records right:15-16:changelog right:17-18:update right:19-20:previous right:22-23:home)"
        fi
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            system-info) run_action "查看系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            diagnostic-bundle) run_action "生成诊断包" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            report) run_action "导出诊断报告" bash "$PROJECT_ROOT/core/detect.sh" --report ;;
            backup-settings) run_action "备份Renkit设置" bash "$PROJECT_ROOT/modules/settings_backup.sh" backup ;;
            restore-settings) run_action "恢复Renkit设置" bash "$PROJECT_ROOT/modules/settings_backup.sh" restore ;;
            network-details) run_action "详细网络信息" bash "$PROJECT_ROOT/modules/network.sh" --details ;;
            new-guide) run_action "新手使用指南" bash "$PROJECT_ROOT/modules/safety_center.sh" guide ;;
            game-guide) run_action "游戏兼容指南" bash "$PROJECT_ROOT/modules/game_guides.sh" show ;;
            shortcuts) run_action "掌机常用快捷键" bash "$PROJECT_ROOT/modules/handheld_helper.sh" shortcuts ;;
            peripherals) run_action "外接设备检查" bash "$PROJECT_ROOT/modules/handheld_helper.sh" peripherals ;;
            records) run_action "操作记录" bash "$PROJECT_ROOT/modules/safety_center.sh" records ;;
            changelog) changelog_menu ;;
            update) NEXT_CATEGORY="update"; return 0 ;;
            next) page=2 ;;
            previous) page=1 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "help" ] || return 0
    done
}

changelog_menu() {
    local choice
    local release_heading="当前版本"
    local line
    local in_latest_release=0
    local -a release_notes=()

    if [ -r "$PROJECT_ROOT/CHANGELOG.md" ]; then
        while IFS= read -r line; do
            case "$line" in
                "## "*)
                    if [ "$in_latest_release" -eq 1 ]; then
                        break
                    fi
                    release_heading="${line#\#\# }"
                    in_latest_release=1
                    ;;
                "- "*)
                    if [ "$in_latest_release" -eq 1 ]; then
                        release_notes+=("${line#- }")
                    fi
                    ;;
            esac
        done < "$PROJECT_ROOT/CHANGELOG.md"
    fi

    if [ -r "$PROJECT_ROOT/VERSION" ]; then
        release_heading="V$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION") · ${release_heading#*— }"
    fi

    while true; do
        draw_category_frame support "更新日志" "$release_heading"
        ui_panel_line 7 '\033[1;38;5;114m' "✓ ${release_notes[0]:-当前版本已安装，暂无摘要}"
        ui_panel_line 10 '\033[1;38;5;45m' "✓ ${release_notes[1]:-完整改动以 CHANGELOG.md 为准}"
        ui_panel_line 13 '\033[1;38;5;220m' "完整日志随Renkit自动更新，不再显示旧版固定日期"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回检测与帮助" "查看其他说明"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:17-18:help right:20-21:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            help) NEXT_CATEGORY="help"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

home_menu() {
    local choice

    draw_category_frame "" "" ""
    ui_panel_line 2 '\033[1;38;5;220m' "新机器设置｜第一次使用从这里开始"
    ui_panel_line 4 '\033[1;38;5;45m' "安装常用软件｜聊天、浏览器和远程工具"
    ui_panel_line 6 '\033[1;38;5;45m' "游戏与插件｜浏览插件商城和游戏组件"
    ui_panel_line 8 '\033[1;38;5;45m' "模拟器｜Switch、Wii U、PS1 至 3DS 模拟器"
    ui_panel_line 10 '\033[1;38;5;114m' "检查与维护｜检查网络、常见问题并生成诊断包"
    ui_panel_line 12 '\033[1;38;5;203m' "更多设置｜国内下载、内存、密码和双系统"
    ui_panel_line 14 '\033[1;38;5;203m' "卸载已安装｜逐项安全移除软件和系统组件"
    ui_panel_line 16 '\033[1;38;5;250m' "免责声明与使用须知｜查看完整图文说明"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

if [ "${ZHOUKEER_SKIP_DISCLAIMER:-0}" != "1" ]; then
    show_disclaimer
fi
ensure_password_ready

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init) new_machine_menu ;;
        software) common_software_menu ;;
        games) game_environment_menu ;;
        freedeck_versions) freedeck_versions_menu ;;
        decky_loader) decky_loader_menu ;;
        plugin_page_2) plugin_page_2_menu ;;
        launcher_tools) launcher_tools_menu ;;
        handheld_plugins) handheld_plugins_menu ;;
        battlenet_submenu) battlenet_submenu ;;
        launcher_repair) launcher_repair_menu ;;
        emulators) emulator_menu ;;
        network|support) support_menu ;;
        advanced) advanced_tools_menu ;;
        uninstall) uninstall_software_menu ;;
        notice) usage_notice_menu ;;
        # 旧分类仅保留内部兼容，不再显示在首页。
        remote) NEXT_CATEGORY="software" ;;
        plugins|plugins-menu) NEXT_CATEGORY="games" ;;
        settings) NEXT_CATEGORY="support" ;;
        dual) NEXT_CATEGORY="advanced" ;;
        maintenance|help|optimize|guides|changelog) NEXT_CATEGORY="support" ;;
        update)
            confirm_and_run "检查并更新Renkit" "会联网下载、校验并安全替换为最新版本" bash "$PROJECT_ROOT/update.sh"
            [ "$NEXT_CATEGORY" = "update" ] && NEXT_CATEGORY="support"
            ;;
        exit)
            log "用户退出Renkit"
            exit 0
            ;;
        *) NEXT_CATEGORY="home" ;;
    esac
done
