#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME" 2>/dev/null || cd / || exit 1

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

RENKIT_PLATFORM_LABEL="BAZZITE 掌机  /  中文工具"
RENKIT_CONSOLE_TITLE="Bazzite Handheld Toolbox"
ZHOUKEER_FLATPAK_SOURCE_MODE="official"
export RENKIT_PLATFORM_LABEL
export RENKIT_CONSOLE_TITLE
export ZHOUKEER_FLATPAK_SOURCE_MODE

ensure_runtime_dirs

case "${1:-}" in
    ""|--touch) ;;
    *) echo "请从桌面的“Renkit Bazzite版”图标启动。"; exit 1 ;;
esac

show_startup_loading() {
    printf '\033[0m\033[2J\033[H\n\n  Renkit Bazzite版启动中，请耐心等待…\n'
}

show_startup_loading
ui_apply_screen_font
ui_wait_for_minimum_canvas || true
enable_mouse_tracking
trap 'disable_mouse_tracking' EXIT INT TERM

NEXT_CATEGORY="home"

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
    local status title="$1"
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
    local title="$1" message="$2" choice
    shift 2
    draw_category_frame "" "$title" "$message"
    ui_panel_line 8 '\033[1;38;5;220m' "请确认是否继续这项操作"
    ui_touch_button 10 '\033[1;30;48;5;114m' "继续执行" "已授权Renkit完成该操作"
    ui_touch_button 15 '\033[1;97;48;5;160m' "返回主菜单" "不做任何更改"
    ui_prompt
    choice="$(read_touch_menu right:10-11:yes right:15-16:no)"
    if apply_navigation "$choice"; then return 0; fi
    [ "$choice" = "yes" ] && run_action "$title" env ZHOUKEER_AUTO_CONFIRM=1 "$@"
}

show_disclaimer() {
    local choice
    while true; do
        draw_disclaimer_frame
        ui_disclaimer_line 8 '\033[1;38;5;220m' "Renkit Bazzite版与 SteamOS 版使用独立功能菜单"
        ui_disclaimer_line 9 '\033[38;5;45m' "当前版本只开放已适配的 Bazzite 用户空间功能"
        ui_disclaimer_line 10 '\033[38;5;45m' "不会执行 pacman、steamos-readonly 或 SteamOS 系统修复"
        ui_disclaimer_line 11 '\033[38;5;45m' "下载内容来自官方免费发布、开源项目或Renkit镜像"
        ui_disclaimer_line 12 '\033[38;5;45m' "不包含付费软件、破解、ROM、BIOS 或密钥"
        ui_disclaimer_line 13 '\033[1;38;5;220m' "Decky 使用 Bazzite 官方 ujust 安装入口"
        ui_disclaimer_button 16 '\033[1;38;5;114m' "点击窗口任意位置开始使用" "关闭窗口即可退出"
        choice="$(read_menu_choice any:1-999:agree)"
        [ "$choice" = "agree" ] && return 0
    done
}

read_touch_menu() {
    read_menu_choice \
        left:2-3:nav-init \
        left:4-5:nav-software \
        left:6-7:nav-games \
        left:8-9:nav-emulators \
        left:10-11:nav-support \
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
        nav-support) NEXT_CATEGORY="support" ;;
        nav-advanced) NEXT_CATEGORY="advanced" ;;
        nav-uninstall) NEXT_CATEGORY="uninstall" ;;
        nav-notice) NEXT_CATEGORY="notice" ;;
        nav-exit) NEXT_CATEGORY="exit" ;;
        *) return 1 ;;
    esac
    return 0
}

home_menu() {
    local choice
    draw_category_frame "" "Renkit Bazzite版" "独立菜单 · 不调用 SteamOS 系统功能"
    ui_panel_line 8 '\033[1;38;5;220m' "已自动切换到 Bazzite 功能集"
    ui_panel_line 10 '\033[1;38;5;45m' "常用软件、启动器、兼容层、模拟器和诊断已开放"
    ui_panel_line 12 '\033[1;38;5;114m' "Decky 由 Bazzite 官方 ujust 负责安装和维护"
    ui_panel_line 14 '\033[1;38;5;250m' "系统调优、pacman、ToDesk仍隔离；Clover需单独确认"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

bazzite_setup_menu() {
    local choice
    while true; do
        draw_category_frame init "Bazzite 使用准备" "只读检查与官方组件入口"
        ui_touch_button 6 '\033[1;97;48;5;24m' "查看系统信息" "识别 Bazzite 版本与设备状态"
        ui_touch_button 9 '\033[1;97;48;5;24m' "一键检查网络" "检查 Steam、国内线路与 Flathub"
        ui_touch_button 12 '\033[1;97;48;5;24m' "安装 Decky Loader" "调用 Bazzite 官方 ujust setup-decky"
        ui_touch_button 15 '\033[1;97;48;5;24m' "查看 Decky 状态" "只读检查，不修改系统"
        ui_touch_button 18 '\033[1;97;48;5;24m' "Flatpak 下载源" "默认官方；可手动切换国内镜像"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:6-7:system right:9-10:network right:12-13:decky right:15-16:decky-status right:18-19:flatpak-source right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            system) run_action "查看 Bazzite 系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            network) run_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            decky) confirm_and_run "安装 Decky Loader" "使用 Bazzite 官方 ujust 安装，不替换 SteamOS 服务文件" bash "$PROJECT_ROOT/modules/bazzite_decky.sh" install ;;
            decky-status) run_action "查看 Decky 状态" bash "$PROJECT_ROOT/modules/bazzite_decky.sh" status ;;
            flatpak-source) bazzite_flatpak_source_menu ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

bazzite_flatpak_source_menu() {
    local choice
    while true; do
        draw_category_frame init "Bazzite Flatpak 下载源" "默认官方 Flathub · 国内镜像需主动确认"
        ui_panel_line 6 '\033[1;38;5;114m' "默认：官方 Flathub，保持 GPG 签名验证"
        ui_panel_line 8 '\033[1;38;5;220m' "风险：启用以下国内镜像会关闭 GPG 验证"
        ui_panel_line 10 '\033[38;5;250m' "flathub-cn: https://mirror.sjtu.edu.cn/flathub"
        ui_panel_line 12 '\033[38;5;250m' "flathub-ustc: https://mirrors.ustc.edu.cn/flathub"
        ui_touch_button 15 '\033[1;30;48;5;220m' "确认信任并启用国内源" "仅修改用户级 Flatpak，不改 Bazzite 系统源"
        ui_touch_button 18 '\033[1;97;48;5;24m' "恢复官方 Flathub" "重新启用 GPG 验证"
        ui_touch_button 20 '\033[1;97;48;5;24m' "查看当前 Flatpak 源"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回"
        ui_prompt
        choice="$(read_touch_menu right:15-16:enable-domestic right:18-19:restore-official right:20-21:status right:23-24:back)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            enable-domestic) run_action "启用国内 Flatpak 源" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/domestic_source.sh" enable ;;
            restore-official) run_action "恢复官方 Flathub" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/domestic_source.sh" restore ;;
            status) run_action "查看 Flatpak 下载源" bash "$PROJECT_ROOT/modules/domestic_source.sh" status ;;
            back) return 0 ;;
        esac
    done
}

software_menu() {
    local choice page=0 target title description
    while true; do
        case "$page" in
            0)
                draw_category_frame software "安装常用软件" "Flatpak 与 AppImage · 第 1/4 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "微信"
                ui_touch_button 4 '\033[1;97;48;5;24m' "QQ"
                ui_touch_button 6 '\033[1;97;48;5;24m' "Firefox 浏览器"
                ui_touch_button 8 '\033[1;97;48;5;24m' "Chrome 浏览器"
                ui_touch_button 10 '\033[1;97;48;5;24m' "Edge 浏览器"
                ui_touch_button 12 '\033[1;97;48;5;24m' "RustDesk 远程协助"
                ui_touch_button 14 '\033[1;97;48;5;24m' "Bottles"
                ui_touch_button 16 '\033[1;97;48;5;24m' "Protontricks"
                ui_touch_button 19 '\033[1;97;48;5;24m' "下一页" "办公、媒体与工具"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
                ui_prompt
                choice="$(read_touch_menu right:2-3:wechat right:4-5:qq right:6-7:browser right:8-9:chrome right:10-11:edge right:12-13:rustdesk right:14-15:bottles right:16-17:protontricks right:19-20:next right:22-23:home)"
                ;;
            1)
                draw_category_frame software "安装常用软件" "办公、媒体与工具 · 第 2/4 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "LibreOffice"
                ui_touch_button 4 '\033[1;97;48;5;24m' "VLC 播放器"
                ui_touch_button 6 '\033[1;97;48;5;24m' "OBS Studio"
                ui_touch_button 8 '\033[1;97;48;5;24m' "LocalSend"
                ui_touch_button 10 '\033[1;97;48;5;24m' "PeaZip"
                ui_touch_button 12 '\033[1;97;48;5;24m' "Heroic 游戏启动器"
                ui_touch_button 14 '\033[1;97;48;5;24m' "Lutris"
                ui_touch_button 16 '\033[1;97;48;5;24m' "Chiaki4Deck"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
                ui_prompt
                choice="$(read_touch_menu right:2-3:libreoffice right:4-5:vlc right:6-7:obs right:8-9:localsend right:10-11:peazip right:12-13:heroic right:14-15:lutris right:16-17:chiaki4deck right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            2)
                draw_category_frame software "安装常用软件" "影音、输入与云游戏 · 第 3/4 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "百度网盘"
                ui_touch_button 4 '\033[1;97;48;5;24m' "WiliWili（B站）"
                ui_touch_button 6 '\033[1;97;48;5;24m' "Fcitx5 中文输入法"
                ui_touch_button 8 '\033[1;97;48;5;24m' "Xbox 云游戏"
                ui_touch_button 10 '\033[1;97;48;5;24m' "QQ音乐"
                ui_touch_button 12 '\033[1;97;48;5;24m' "网易云音乐"
                ui_touch_button 14 '\033[1;97;48;5;24m' "YesPlayMusic"
                ui_touch_button 16 '\033[1;97;48;5;24m' "qBittorrent"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
                ui_prompt
                choice="$(read_touch_menu right:2-3:baidunetdisk right:4-5:willwill right:6-7:fcitx5 right:8-9:xbox-cloud right:10-11:qqmusic right:12-13:netease-music right:14-15:yesplaymusic right:16-17:qbittorrent right:18-19:previous right:20-21:next right:22-23:home)"
                ;;
            *)
                draw_category_frame software "安装常用软件" "下载、截图与笔记 · 第 4/4 页"
                ui_touch_button 2 '\033[1;97;48;5;24m' "Motrix 下载器"
                ui_touch_button 4 '\033[1;97;48;5;24m' "Free Download Manager"
                ui_touch_button 6 '\033[1;97;48;5;24m' "Media Downloader"
                ui_touch_button 8 '\033[1;97;48;5;24m' "Flameshot 截图"
                ui_touch_button 10 '\033[1;97;48;5;24m' "OnlyOffice"
                ui_touch_button 12 '\033[1;97;48;5;24m' "Joplin 笔记"
                ui_touch_button 14 '\033[1;97;48;5;24m' "Parsec"
                ui_touch_button 19 '\033[1;97;48;5;24m' "上一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
                ui_prompt
                choice="$(read_touch_menu right:2-3:motrix right:4-5:freedownloadmanager right:6-7:media-downloader right:8-9:flameshot right:10-11:onlyoffice right:12-13:joplin right:14-15:parsec right:19-20:previous right:22-23:home)"
                ;;
        esac
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            next) page=$((page + 1)); [ "$page" -le 3 ] || page=3; continue ;;
            previous) page=$((page - 1)); [ "$page" -ge 0 ] || page=0; continue ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        target="$choice"
        case "$target" in
            wechat) title="微信"; description="腾讯官网 AppImage" ;;
            qq) title="QQ"; description="Flathub 用户级安装" ;;
            browser) title="Firefox 浏览器"; description="Flathub 用户级安装" ;;
            chrome) title="Google Chrome"; description="Flathub 用户级安装" ;;
            edge) title="Microsoft Edge"; description="Flathub 用户级安装" ;;
            rustdesk) title="RustDesk 远程协助"; description="作者官方 AppImage" ;;
            bottles) title="Bottles"; description="通过 Flatpak 运行 Windows 应用" ;;
            protontricks) title="Protontricks"; description="配置 Steam Proton 环境" ;;
            libreoffice) title="LibreOffice"; description="Flathub 用户级安装" ;;
            vlc) title="VLC 播放器"; description="Flathub 用户级安装" ;;
            obs) title="OBS Studio"; description="Flathub 用户级安装" ;;
            localsend) title="LocalSend"; description="Flathub 用户级安装" ;;
            peazip) title="PeaZip"; description="Flathub 用户级安装" ;;
            heroic) title="Heroic 游戏启动器"; description="安装后加入 Steam 库" ;;
            lutris) title="Lutris"; description="安装后加入 Steam 库" ;;
            chiaki4deck) title="Chiaki4Deck"; description="PS5 远程串流" ;;
            baidunetdisk) title="百度网盘"; description="官方 Flathub 用户级安装" ;;
            willwill) title="WiliWili"; description="B站客户端，安装后加入 Steam 库" ;;
            fcitx5) title="Fcitx5 中文输入法"; description="安装 Fcitx5 与中文输入插件" ;;
            xbox-cloud) title="Xbox 云游戏"; description="安装 Greenlight，需 Xbox 账号" ;;
            qqmusic) title="QQ音乐"; description="官方 Flathub 用户级安装" ;;
            netease-music) title="网易云音乐"; description="Flathub 用户级安装" ;;
            yesplaymusic) title="YesPlayMusic"; description="第三方网易云音乐客户端" ;;
            qbittorrent) title="qBittorrent"; description="BT 与磁力下载工具" ;;
            motrix) title="Motrix 下载器"; description="多协议下载管理" ;;
            freedownloadmanager) title="Free Download Manager"; description="用户级下载管理工具" ;;
            media-downloader) title="Media Downloader"; description="视频与媒体下载工具" ;;
            flameshot) title="Flameshot 截图"; description="截图与标注工具" ;;
            onlyoffice) title="OnlyOffice"; description="兼容 Office 文档" ;;
            joplin) title="Joplin 笔记"; description="笔记与待办管理" ;;
            parsec) title="Parsec"; description="远程串流与协作" ;;
            *) continue ;;
        esac
        confirm_and_run "安装$title" "$description" bash "$PROJECT_ROOT/modules/software.sh" "$target"
    done
}

launcher_repair_menu() {
    local choice
    while true; do
        draw_category_frame games "修复启动器封面" "重写 Steam 库封面，不依赖 Decky"
        ui_touch_button 5 '\033[1;97;48;5;24m' "修复 Epic 封面"
        ui_touch_button 8 '\033[1;97;48;5;24m' "修复战网封面"
        ui_touch_button 11 '\033[1;97;48;5;24m' "修复育碧封面"
        ui_touch_button 14 '\033[1;97;48;5;24m' "修复黑盒工坊封面"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回游戏与插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:5-6:epic right:8-9:battlenet right:11-12:ubisoft right:14-15:heihe right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            epic|battlenet|ubisoft|heihe) confirm_and_run "修复启动器封面" "会安全退出 Steam、重写封面并重新启动" bash "$PROJECT_ROOT/modules/game_launchers.sh" apply-artwork "$choice" ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

bazzite_ge_proton_menu() {
    local choice
    while true; do
        draw_category_frame games "GE-Proton 兼容层" "安装到当前用户的 Steam 兼容工具目录"
        ui_touch_button 6 '\033[1;97;48;5;24m' "安装最新版 GE-Proton" "已安装的旧版本不会删除"
        ui_touch_button 10 '\033[1;97;48;5;24m' "安装修改器常用版本" "7-55、8-25、9-27、10-29 · 约 1.72GB"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回游戏与插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:6-7:latest right:10-11:trainer right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            latest) confirm_and_run "安装最新版 GE-Proton" "自动检测最新版并保留现有兼容层" bash "$PROJECT_ROOT/modules/ge_proton.sh" install ;;
            trainer) confirm_and_run "安装修改器常用兼容层" "安装 GE-Proton 7-55、8-25、9-27、10-29；约 1.72GB" bash "$PROJECT_ROOT/modules/ge_proton.sh" install-trainer ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

bazzite_official_plugin_pages() {
    local choice page=0 start index slot row
    local total="${#DECKY_OFFICIAL_PLUGIN_NAMES[@]}"
    local total_pages=$(((total + DECKY_TOUCH_PAGE_SIZE - 1) / DECKY_TOUCH_PAGE_SIZE))

    while true; do
        draw_category_frame games "Decky 官方插件（第 $((page + 1)) / $total_pages 页）" "点击插件后由 Decky 官方商店安装"
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
            ui_touch_button 16 '\033[1;97;48;5;238m' "上一页"
        else
            ui_touch_button 16 '\033[1;97;48;5;238m' "返回插件分类"
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            ui_touch_button 18 '\033[1;97;48;5;30m' "下一页"
        else
            ui_touch_button 18 '\033[1;97;48;5;238m' "返回插件分类"
        fi
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu \
            right:6-7:plugin-$start \
            right:8-9:plugin-$((start + 1)) \
            right:10-11:plugin-$((start + 2)) \
            right:12-13:plugin-$((start + 3)) \
            right:14-15:plugin-$((start + 4)) \
            right:16-17:previous right:18-19:next right:21-22:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            plugin-*)
                index="${choice#plugin-}"
                if [ "$index" -lt "$total" ]; then
                    confirm_and_run "安装 ${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}" \
                        "${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}；安装请求只提交给本机 Decky 官方商店" \
                        bash "$PROJECT_ROOT/modules/decky_bundle.sh" plugin "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}"
                fi
                ;;
            previous)
                if [ "$page" -gt 0 ]; then page=$((page - 1)); else return 0; fi
                ;;
            next)
                if [ "$page" -lt $((total_pages - 1)) ]; then page=$((page + 1)); else return 0; fi
                ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

bazzite_decky_plugins_menu() {
    local choice
    while true; do
        draw_category_frame games "Decky 插件" "官方插件与 Renkit 汉化功能插件"
        ui_touch_button 6 '\033[1;97;48;5;24m' "安装常用官方插件" "由 Decky 官方商店读取最新版本"
        ui_touch_button 10 '\033[1;97;48;5;24m' "逐个浏览官方插件" "共 23 个官方插件"
        ui_touch_button 14 '\033[1;97;48;5;24m' "汉化功能插件" "小黄鸭、FSR4 与 CheatDeck · 国内分块镜像"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回游戏与插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:6-7:recommended right:10-11:browse right:14-15:features right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            recommended) confirm_and_run "安装常用 Decky 插件" "只使用 Decky 官方商店，不安装自定义或硬件控制插件" env DECKY_BUNDLE_INCLUDE_CUSTOM=0 bash "$PROJECT_ROOT/modules/decky_bundle.sh" install ;;
            browse) bazzite_official_plugin_pages || return 1 ;;
            features) bazzite_feature_plugins_menu || return 1 ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

bazzite_feature_plugins_menu() {
    local choice
    while true; do
        draw_category_frame games "汉化功能插件" "Gitee 分块镜像优先 · 安装后核对真实插件文件"
        ui_touch_button 4 '\033[1;97;48;5;24m' "一键安装三款" "小黄鸭、FSR4 与 CheatDeck"
        ui_touch_button 7 '\033[1;97;48;5;24m' "小黄鸭版本选择" "旧版稳定汉化 · MAKO 尝鲜版"
        ui_touch_button 10 '\033[1;97;48;5;24m' "安装 FSR4" "Decky-Framegen 汉化版"
        ui_touch_button 13 '\033[1;97;48;5;24m' "安装 CheatDeck" "修改器启动插件"
        ui_touch_button 16 '\033[1;97;48;5;24m' "更多功能插件" "Freedeck、ToMoon、Unifideck 与掌机控制"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回 Decky 插件"
        ui_prompt
        choice="$(read_touch_menu right:4-5:all right:7-8:lsfg right:10-11:fsr4 right:13-14:cheatdeck right:16-17:more right:22-23:back)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            all) confirm_and_run "安装三款汉化功能插件" "使用 Gitee 分块镜像并校验 SHA256；插件目录不可写时可能请求管理员权限" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" features ;;
            lsfg) bazzite_lsfg_versions_menu || return 1 ;;
            fsr4) confirm_and_run "安装 FSR4" "仅从 Gitee mirror-3 分块安装署名完整包并校验 SHA256；汉化：RenAmamiya" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4-zh-gitee ;;
            cheatdeck) confirm_and_run "安装 CheatDeck" "Gitee 分块镜像优先并校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" cheatdeck ;;
            more) bazzite_extra_plugins_menu || return 1 ;;
            back) return 0 ;;
        esac
    done
}

bazzite_lsfg_versions_menu() {
    local choice
    while true; do
        draw_category_frame games "小黄鸭版本选择" "旧版稳定汉化 · MAKO 实验尝鲜"
        ui_touch_button 4 '\033[1;97;48;5;24m' "旧版小黄鸭" "v0.12.8 汉化版·稳定"
        ui_touch_button 7 '\033[1;97;48;5;160m' "MAKO 小黄鸭" "实验仓库尝鲜版·Renkit 汉化"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回汉化功能插件" "查看其他功能插件"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:4-5:stable right:7-8:mako right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            stable)
                confirm_and_run "安装旧版小黄鸭" "v0.12.8 汉化版；仅从 Gitee mirror-3 分块安装署名完整包；汉化：RenAmamiya" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-zh-gitee
                ;;
            mako)
                confirm_and_run "安装 MAKO 小黄鸭（尝鲜版）" "来自 eugeniosegala/MAKO 尝鲜仓库；功能尚未稳定，安装官方运行核心后叠加 Renkit 汉化；汉化作者：RenAmamiya" \
                    env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-mako
                ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

bazzite_extra_plugins_menu() {
    local choice
    while true; do
        draw_category_frame games "更多功能插件" "现有 Renkit 插件 · Gitee 国内镜像优先"
        ui_touch_button 3 '\033[1;97;48;5;24m' "安装 DeckRecall" "添加启动项并恢复游戏可玩状态"
        ui_touch_button 5 '\033[1;97;48;5;24m' "安装 SavePulse" "自动存档、个人 WebDAV 云备份与换机恢复"
        ui_touch_button 7 '\033[1;97;48;5;24m' "安装 Freedeck" "0.6 稳定版"
        ui_touch_button 9 '\033[1;97;48;5;24m' "安装 NewFreedeck" "0.1 重构测试版，可与稳定版共存"
        ui_touch_button 11 '\033[1;97;48;5;24m' "安装 ToMoon" "第三方游戏工具插件"
        ui_touch_button 13 '\033[1;97;48;5;24m' "安装 Unifideck" "统一游戏库插件"
        ui_touch_button 15 '\033[1;97;48;5;24m' "掌机控制插件" "功耗、RGB、按键、震动与风扇"
        ui_touch_button 17 '\033[1;97;48;5;30m' "检查三款常用插件" "小黄鸭、FSR4 与 CheatDeck"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回汉化功能插件"
        ui_prompt
        choice="$(read_touch_menu right:3-4:deckrecall right:5-6:savepulse right:7-8:freedeck right:9-10:newfreedeck right:11-12:tomoon right:13-14:unifideck right:15-16:handheld right:17-18:status right:22-23:back)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            deckrecall) confirm_and_run "安装 DeckRecall" "作者 GitHub Release，下载后校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" deckrecall ;;
            savepulse) confirm_and_run "安装 SavePulse" "自动版本存档、个人坚果云或标准 WebDAV 云备份与换机恢复；作者 GitHub Release，下载后校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" savepulse ;;
            freedeck) confirm_and_run "安装 Freedeck" "Gitee 分块镜像优先并校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" freedeck ;;
            newfreedeck) confirm_and_run "安装 NewFreedeck" "上游重构测试版，部分功能可能尚未完成；Gitee 分块镜像优先" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" newfreedeck ;;
            tomoon) confirm_and_run "安装 ToMoon" "Gitee 分块镜像优先并校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" tomoon ;;
            unifideck) confirm_and_run "安装 Unifideck" "Gitee 分块镜像优先并校验 SHA256" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" unifideck ;;
            handheld) bazzite_handheld_plugins_menu || return 1 ;;
            status) run_action "汉化功能插件状态" bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status ;;
            back) return 0 ;;
        esac
    done
}

bazzite_handheld_plugins_menu() {
    local choice
    while true; do
        draw_category_frame games "掌机控制插件" "请按实际机型安装 · 错误机型不要启用硬件控制"
        ui_touch_button 2 '\033[1;97;48;5;24m' "掌机功耗控制" "SimpleDeckyTDP 中文版"
        ui_touch_button 5 '\033[1;97;48;5;24m' "Ally 控制中心" "仅 ROG Ally / Ally X"
        ui_touch_button 8 '\033[1;97;48;5;24m' "通用掌机 RGB" "HueSync，上游自带中文"
        ui_touch_button 11 '\033[1;97;48;5;24m' "Legion Go 控制中心" "按键映射与控制"
        ui_touch_button 14 '\033[1;97;48;5;24m' "GPD 控制中心" "GPD 掌机专用"
        ui_touch_button 17 '\033[1;97;48;5;24m' "Legion Go 震动控制" "Legion Go 专用"
        ui_touch_button 20 '\033[1;97;48;5;30m' "更多掌机插件" "Legion Go 2 与 OneXPlayer Apex"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回掌机插件第一页"
        ui_prompt
        choice="$(read_touch_menu right:2-3:simpletdp right:5-6:allycenter right:8-9:huesync right:11-12:legionremap right:14-15:gpd right:17-18:legovibe right:20-21:more right:22-23:back)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            simpletdp) confirm_and_run "安装掌机功耗控制" "安装 SimpleDeckyTDP 中文版；Gitee 国内镜像优先" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" simpledeckytdp-zh-gitee ;;
            allycenter) confirm_and_run "安装 Ally 控制中心" "仅用于 ROG Ally / Ally X；会调用硬件控制后端" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" allycenter ;;
            huesync) confirm_and_run "安装通用掌机 RGB" "HueSync 上游自带中文；请确认设备灯效受支持" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" huesync ;;
            legionremap) confirm_and_run "安装 Legion Go 控制中心" "仅用于 Legion Go；会调用按键控制后端" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" legiongo-remapper ;;
            gpd) confirm_and_run "安装 GPD 控制中心" "仅用于 GPD 掌机；会调用硬件控制后端" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" gpd-control ;;
            legovibe) confirm_and_run "安装 Legion Go 震动控制" "仅用于 Legion Go；会修改震动控制参数" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lego-vibe ;;
            more) bazzite_handheld_plugins_more_menu || return 1 ;;
            back) return 0 ;;
        esac
    done
}

bazzite_handheld_plugins_more_menu() {
    local choice
    while true; do
        draw_category_frame games "更多掌机插件" "机型专用硬件控制 · 安装前必须核对设备"
        ui_touch_button 6 '\033[1;97;48;5;24m' "Legion Go 2 风扇控制" "仅 Legion Go 2 · 错误设置可能过热"
        ui_touch_button 10 '\033[1;97;48;5;24m' "OneXPlayer Apex 工具" "仅 Apex（Strix Halo）· HHD、睡眠与风扇修复"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回上一页"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回更多功能插件"
        ui_prompt
        choice="$(read_touch_menu right:6-7:lego2fan right:10-11:onexplayer right:19-20:previous right:22-23:back)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            lego2fan) confirm_and_run "安装 Legion Go 2 风扇控制" "仅用于 Legion Go 2；错误设置可能导致过热，请确认机型" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lego2-fan ;;
            onexplayer) confirm_and_run "安装 OneXPlayer Apex 工具" "仅用于 OneXPlayer Apex（Strix Halo）；会修改 HHD、睡眠设置并加载机型专用内核模块，其他机型严禁安装" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" onexplayer-apex ;;
            previous) return 0 ;;
            back) return 0 ;;
        esac
    done
}

games_menu() {
    local choice
    while true; do
        draw_category_frame games "游戏与插件" "Bazzite 官方 Decky · Proton · 启动器"
        ui_touch_button 2 '\033[1;97;48;5;24m' "安装 Decky Loader" "Bazzite 官方 ujust"
        ui_touch_button 4 '\033[1;97;48;5;24m' "Decky 插件" "官方插件与汉化功能插件"
        ui_touch_button 6 '\033[1;97;48;5;24m' "GE-Proton 兼容层" "最新版与修改器常用版本"
        ui_touch_button 8 '\033[1;97;48;5;24m' "安装 Epic 启动器"
        ui_touch_button 10 '\033[1;97;48;5;24m' "安装战网启动器"
        ui_touch_button 12 '\033[1;97;48;5;24m' "安装育碧启动器"
        ui_touch_button 14 '\033[1;97;48;5;24m' "安装黑盒工坊" "需先安装战网"
        ui_touch_button 16 '\033[1;97;48;5;24m' "修复启动器封面"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:2-3:decky right:4-5:plugins right:6-7:ge right:8-9:epic right:10-11:battlenet right:12-13:ubisoft right:14-15:heihe right:16-17:repair right:21-22:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            decky) confirm_and_run "安装 Decky Loader" "调用 Bazzite 官方 ujust setup-decky" bash "$PROJECT_ROOT/modules/bazzite_decky.sh" install ;;
            plugins) bazzite_decky_plugins_menu || return 0 ;;
            ge) bazzite_ge_proton_menu || return 0 ;;
            epic|battlenet|ubisoft|heihe) confirm_and_run "安装游戏启动器" "安装完成后写入 Steam 库与封面" bash "$PROJECT_ROOT/modules/game_launchers.sh" "$choice" ;;
            repair) launcher_repair_menu || return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

bazzite_yuzu_menu() {
    local choice
    while true; do
        draw_category_frame emulators "Yuzu（Switch 模拟器）" "只提供模拟器与本人合法备份密钥导入"
        ui_touch_button 6 '\033[1;97;48;5;24m' "安装 Yuzu" "不包含游戏、固件或密钥"
        ui_touch_button 10 '\033[1;97;48;5;24m' "导入本人备份的密钥" "从桌面 Yuzu密钥 文件夹导入"
        ui_touch_button 14 '\033[1;97;48;5;24m' "查看密钥状态" "不显示或记录密钥内容"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回模拟器列表"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:6-7:install right:10-11:keys right:14-15:status right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            install) confirm_and_run "安装 Yuzu" "只安装模拟器本体，不包含游戏、固件或密钥" bash "$PROJECT_ROOT/modules/emulators.sh" yuzu ;;
            keys) confirm_and_run "导入 Yuzu 密钥" "仅导入你本人合法备份的 prod.keys / title.keys；不会下载、分享或显示密钥" bash "$PROJECT_ROOT/modules/emulators.sh" yuzu-keys ;;
            status) run_action "Yuzu 密钥状态" bash "$PROJECT_ROOT/modules/emulators.sh" yuzu-keys-status ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

emulator_menu() {
    local choice title
    while true; do
        draw_category_frame emulators "安装模拟器" "完成后创建桌面入口并加入 Steam 库"
        ui_touch_button 2 '\033[1;97;48;5;24m' "Yuzu（Switch）"
        ui_touch_button 4 '\033[1;97;48;5;24m' "Cemu（Wii U）"
        ui_touch_button 6 '\033[1;97;48;5;24m' "DuckStation（PS1）"
        ui_touch_button 8 '\033[1;97;48;5;24m' "PCSX2（PS2）"
        ui_touch_button 10 '\033[1;97;48;5;24m' "RPCS3（PS3）"
        ui_touch_button 12 '\033[1;97;48;5;24m' "ShadPS4（PS4）"
        ui_touch_button 14 '\033[1;97;48;5;24m' "PPSSPP（PSP）"
        ui_touch_button 16 '\033[1;97;48;5;24m' "mGBA（GBA）"
        ui_touch_button 18 '\033[1;97;48;5;24m' "Azahar（3DS）"
        ui_touch_button 20 '\033[1;97;48;5;28m' "一键安装 6 款"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:2-3:yuzu right:4-5:cemu right:6-7:duckstation right:8-9:pcsx2 right:10-11:rpcs3 right:12-13:shadps4 right:14-15:ppsspp right:16-17:mgba right:18-19:azahar right:20-21:install-all right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            home) NEXT_CATEGORY="home"; return 0 ;;
            install-all)
                confirm_and_run "一键安装 6 款模拟器" "依次安装 Yuzu、Cemu、DuckStation、PCSX2、RPCS3 和 ShadPS4；只安装模拟器本体，不包含游戏、BIOS、固件或密钥。已完整安装的项目会跳过，单项失败不会中断后续安装。" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/emulators.sh" install-all
                ;;
            yuzu) bazzite_yuzu_menu || return 0 ;;
            cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                title="$choice"
                confirm_and_run "安装模拟器" "只安装模拟器本体，不包含游戏、BIOS、固件或密钥" bash "$PROJECT_ROOT/modules/emulators.sh" "$title"
                ;;
        esac
    done
}

support_menu() {
    local choice page=0
    while true; do
        if [ "$page" -eq 0 ]; then
            draw_category_frame support "检查与维护" "诊断、清理与Renkit更新 · 第 1/2 页"
            ui_touch_button 2 '\033[1;97;48;5;24m' "一键检查网络"
            ui_touch_button 4 '\033[1;97;48;5;24m' "系统健康检查"
            ui_touch_button 6 '\033[1;97;48;5;24m' "游戏启动检查"
            ui_touch_button 8 '\033[1;97;48;5;24m' "生成诊断包"
            ui_touch_button 10 '\033[1;97;48;5;24m' "清理 Steam 下载残留"
            ui_touch_button 12 '\033[1;97;48;5;24m' "清理着色器缓存"
            ui_touch_button 14 '\033[1;97;48;5;24m' "清理 Linux 用户缓存"
            ui_touch_button 16 '\033[1;97;48;5;24m' "检查并更新Renkit"
            ui_touch_button 19 '\033[1;97;48;5;24m' "下一页" "软件状态、攻略与外设检查"
            ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
            ui_prompt
            choice="$(read_touch_menu right:2-3:network right:4-5:health right:6-7:game right:8-9:diagnostic right:10-11:download-cache right:12-13:shader-cache right:14-15:user-cache right:16-17:update right:19-20:next right:22-23:home)"
        else
            draw_category_frame support "检查与维护" "软件状态、攻略与记录 · 第 2/2 页"
            ui_touch_button 4 '\033[1;97;48;5;24m' "查看常用软件状态" "只读取 Flatpak 与 AppImage 状态"
            ui_touch_button 6 '\033[1;97;48;5;24m' "修复软件桌面图标" "仅重建已安装应用的入口"
            ui_touch_button 8 '\033[1;97;48;5;24m' "中文兼容攻略"
            ui_touch_button 10 '\033[1;97;48;5;24m' "掌机常用快捷键"
            ui_touch_button 12 '\033[1;97;48;5;24m' "外接设备检查" "只读取显示与蓝牙状态"
            ui_touch_button 14 '\033[1;97;48;5;24m' "导出Renkit操作记录" "不包含密码"
            ui_touch_button 19 '\033[1;97;48;5;24m' "上一页"
            ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
            ui_prompt
            choice="$(read_touch_menu right:4-5:software-status right:6-7:repair-shortcuts right:8-9:guides right:10-11:shortcuts right:12-13:peripherals right:14-15:records right:19-20:previous right:22-23:home)"
        fi
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            next) page=1 ;;
            previous) page=0 ;;
            network) run_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            health) run_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            game) run_action "游戏启动检查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            diagnostic) run_action "生成诊断包" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            download-cache|shader-cache|user-cache) confirm_and_run "安全清理" "只删除可重新生成的缓存" bash "$PROJECT_ROOT/modules/clean.sh" "$choice" ;;
            update) confirm_and_run "检查并更新Renkit" "下载、校验并安全替换当前 Bazzite 版" bash "$PROJECT_ROOT/update.sh" ;;
            software-status) run_action "查看常用软件状态" bash "$PROJECT_ROOT/modules/software.sh" status ;;
            repair-shortcuts) confirm_and_run "修复软件桌面图标" "只重建已安装应用的桌面入口，不安装或卸载软件" bash "$PROJECT_ROOT/modules/software.sh" repair-shortcuts ;;
            guides) run_action "中文兼容攻略" bash "$PROJECT_ROOT/modules/game_guides.sh" show ;;
            shortcuts) run_action "掌机常用快捷键" bash "$PROJECT_ROOT/modules/handheld_helper.sh" shortcuts ;;
            peripherals) run_action "外接设备检查" bash "$PROJECT_ROOT/modules/handheld_helper.sh" peripherals ;;
            records) run_action "导出Renkit操作记录" bash "$PROJECT_ROOT/modules/safety_center.sh" records ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

bazzite_clover_menu() {
    local choice
    while true; do
        draw_category_frame advanced "Bazzite Clover 双系统引导" "高风险功能 · 仅用于已有 Windows 的双系统"
        ui_panel_line 5 '\033[1;38;5;203m' "会写入 EFI、修改 UEFI BootOrder，并备份原文件"
        ui_panel_line 7 '\033[1;38;5;220m' "请先关闭 Secure Boot；失败时可从本页执行恢复"
        ui_touch_button 8 '\033[1;97;48;5;24m' "应用 Renkit 开机背景" "替换 Clover Apocalypse 主题背景"
        ui_touch_button 10 '\033[1;30;48;5;220m' "安装/修复 Clover 双系统引导" "自动识别 EFI，并备份清理旧 SteamOS 引导"
        ui_touch_button 14 '\033[1;97;48;5;24m' "查看 Clover 状态" "只读检查 EFI 与 NVRAM 启动项"
        ui_touch_button 18 '\033[1;97;48;5;160m' "恢复安装前引导" "恢复原 BootOrder 与 Windows 启动文件"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回高级功能"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:8-9:clover-background right:10-11:install right:14-15:status right:18-19:restore right:21-22:back right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            clover-background) confirm_and_run "应用 Renkit 开机背景" "仅替换 esp/efi/clover/themes/Apocalypse/background.png" bash "$PROJECT_ROOT/modules/clover_boot.sh" apply-background ;;
            install) confirm_and_run "安装/修复 Clover 双系统引导" "会写入 EFI、修改 BootOrder 并备份原 Clover；Bazzite 下检测到旧 SteamOS 引导时先备份再清理，保留 Windows 官方启动项且不删除系统分区" bash "$PROJECT_ROOT/modules/clover_boot.sh" install ;;
            status) run_action "查看 Clover 状态" bash "$PROJECT_ROOT/modules/clover_boot.sh" status ;;
            restore) confirm_and_run "恢复安装前引导" "删除Renkit创建的 Clover 启动项，并恢复原 BootOrder 和 Windows 启动文件" bash "$PROJECT_ROOT/modules/clover_boot.sh" restore ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

advanced_menu() {
    local choice
    while true; do
        draw_category_frame advanced "Bazzite 版说明" "本版功能边界与后续适配状态"
        ui_panel_line 7 '\033[1;38;5;114m' "✓ Flatpak / AppImage / GE-Proton / 启动器 / 模拟器"
        ui_panel_line 10 '\033[1;38;5;114m' "✓ Bazzite 官方 Decky 安装与官方插件队列"
        ui_panel_line 13 '\033[1;38;5;220m' "暂不开放：系统调优、ToDesk、通用 EFI 工具、pacman 国内源"
        ui_panel_line 16 '\033[1;38;5;250m' "这些功能与 SteamOS 版完全隔离，不会误调用"
        ui_touch_button 18 '\033[1;30;48;5;220m' "Clover 双系统引导" "Bazzite 专用检测，安装与恢复均需确认"
        ui_touch_button 20 '\033[1;97;48;5;24m' "查看 Bazzite 与 Decky 状态"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:18-19:clover right:20-21:status right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            clover) bazzite_clover_menu ;;
            status) NEXT_CATEGORY="init"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

bazzite_uninstall_software_menu() {
    local choice page=0
    while true; do
        case "$page" in
            0)
                draw_category_frame uninstall "卸载常用软件" "用户级应用 · 第 1/4 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载微信"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 QQ"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Firefox"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 Chrome"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 Edge"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 RustDesk"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 Bottles"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 Protontricks"
                ui_touch_button 19 '\033[1;97;48;5;24m' "下一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回卸载分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:wechat right:4-5:qq right:6-7:browser right:8-9:chrome right:10-11:edge right:12-13:rustdesk right:14-15:bottles right:16-17:protontricks right:19-20:next right:22-23:back)"
                ;;
            1)
                draw_category_frame uninstall "卸载常用软件" "办公、媒体与工具 · 第 2/4 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 LibreOffice"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 VLC"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 OBS Studio"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 LocalSend"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 PeaZip"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 Heroic"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 Lutris"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 Chiaki4Deck"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回卸载分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:libreoffice right:4-5:vlc right:6-7:obs right:8-9:localsend right:10-11:peazip right:12-13:heroic right:14-15:lutris right:16-17:chiaki4deck right:18-19:previous right:20-21:next right:22-23:back)"
                ;;
            2)
                draw_category_frame uninstall "卸载常用软件" "影音、输入与云游戏 · 第 3/4 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载百度网盘"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 WiliWili"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Fcitx5"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 Xbox 云游戏"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 QQ音乐"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载网易云音乐"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 YesPlayMusic"
                ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 qBittorrent"
                ui_touch_button 18 '\033[1;97;48;5;24m' "上一页"
                ui_touch_button 20 '\033[1;97;48;5;24m' "下一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回卸载分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:baidunetdisk right:4-5:willwill right:6-7:fcitx5 right:8-9:xbox-cloud right:10-11:qqmusic right:12-13:netease-music right:14-15:yesplaymusic right:16-17:qbittorrent right:18-19:previous right:20-21:next right:22-23:back)"
                ;;
            *)
                draw_category_frame uninstall "卸载常用软件" "下载、截图与笔记 · 第 4/4 页"
                ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 Motrix"
                ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 Free Download Manager"
                ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 Media Downloader"
                ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 Flameshot"
                ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 OnlyOffice"
                ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 Joplin"
                ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 Parsec"
                ui_touch_button 19 '\033[1;97;48;5;24m' "上一页"
                ui_touch_button 22 '\033[1;97;48;5;238m' "返回卸载分类"
                ui_prompt
                choice="$(read_touch_menu right:2-3:motrix right:4-5:freedownloadmanager right:6-7:media-downloader right:8-9:flameshot right:10-11:onlyoffice right:12-13:joplin right:14-15:parsec right:19-20:previous right:22-23:back)"
                ;;
        esac
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            next) page=$((page + 1)); [ "$page" -le 3 ] || page=3 ;;
            previous) page=$((page - 1)); [ "$page" -ge 0 ] || page=0 ;;
            back) return 0 ;;
            wechat|qq|browser|chrome|edge|rustdesk|bottles|protontricks|libreoffice|vlc|obs|localsend|peazip|heroic|lutris|chiaki4deck|baidunetdisk|willwill|fcitx5|xbox-cloud|qqmusic|netease-music|yesplaymusic|qbittorrent|motrix|freedownloadmanager|media-downloader|flameshot|onlyoffice|joplin|parsec)
                confirm_and_run "卸载软件" "只移除所选用户级应用与Renkit创建的入口；不删除用户配置" \
                    bash "$PROJECT_ROOT/modules/software.sh" uninstall "$choice"
                ;;
        esac
    done
}

bazzite_uninstall_launcher_menu() {
    local choice
    while true; do
        draw_category_frame uninstall "卸载游戏启动器" "移除 Steam 与桌面入口，保留游戏文件"
        ui_touch_button 5 '\033[1;97;48;5;160m' "卸载 Epic"
        ui_touch_button 8 '\033[1;97;48;5;160m' "卸载战网"
        ui_touch_button 11 '\033[1;97;48;5;160m' "卸载育碧"
        ui_touch_button 14 '\033[1;97;48;5;160m' "卸载黑盒工坊"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回卸载分类"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:5-6:epic right:8-9:battlenet right:11-12:ubisoft right:14-15:heihe right:19-20:back right:22-23:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            epic|battlenet|ubisoft|heihe)
                confirm_and_run "卸载游戏启动器" "移除 Steam 库条目、桌面入口和Renkit包装器；保留游戏与下载文件" \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" uninstall "$choice"
                ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

bazzite_uninstall_emulator_menu() {
    local choice
    while true; do
        draw_category_frame uninstall "卸载模拟器" "移除程序与入口，保留存档和配置"
        ui_touch_button 2 '\033[1;97;48;5;160m' "卸载 Yuzu"
        ui_touch_button 4 '\033[1;97;48;5;160m' "卸载 Cemu"
        ui_touch_button 6 '\033[1;97;48;5;160m' "卸载 DuckStation"
        ui_touch_button 8 '\033[1;97;48;5;160m' "卸载 PCSX2"
        ui_touch_button 10 '\033[1;97;48;5;160m' "卸载 RPCS3"
        ui_touch_button 12 '\033[1;97;48;5;160m' "卸载 ShadPS4"
        ui_touch_button 14 '\033[1;97;48;5;160m' "卸载 PPSSPP"
        ui_touch_button 16 '\033[1;97;48;5;160m' "卸载 mGBA"
        ui_touch_button 18 '\033[1;97;48;5;160m' "移除 Azahar 入口" "保留自行放入的 AppImage"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回卸载分类"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:2-3:yuzu right:4-5:cemu right:6-7:duckstation right:8-9:pcsx2 right:10-11:rpcs3 right:12-13:shadps4 right:14-15:ppsspp right:16-17:mgba right:18-19:azahar right:21-22:back right:23-24:home)"
        if apply_navigation "$choice"; then return 1; fi
        case "$choice" in
            yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                confirm_and_run "卸载模拟器" "移除程序、Steam 条目与桌面入口；保留存档、配置、固件和密钥" \
                    bash "$PROJECT_ROOT/modules/emulators.sh" uninstall "$choice"
                ;;
            back) return 0 ;;
            home) NEXT_CATEGORY="home"; return 1 ;;
        esac
    done
}

uninstall_menu() {
    local choice
    while true; do
        draw_category_frame uninstall "卸载与移除" "Bazzite 用户空间功能 · 分类管理"
        ui_touch_button 5 '\033[1;97;48;5;160m' "卸载常用软件" "只管理用户级 Flatpak 与 AppImage"
        ui_touch_button 8 '\033[1;97;48;5;160m' "卸载游戏启动器" "保留游戏和下载文件"
        ui_touch_button 11 '\033[1;97;48;5;160m' "卸载模拟器" "保留存档与配置"
        ui_touch_button 14 '\033[1;97;48;5;160m' "卸载当前 GE-Proton" "不删除其他兼容层版本"
        ui_touch_button 17 '\033[1;97;48;5;160m' "卸载 Renkit" "不删除已安装的软件和游戏"
        ui_panel_line 20 '\033[1;38;5;250m' "Decky 与系统级 Flatpak 请使用 Bazzite 自带工具维护"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:5-6:software-remove right:8-9:launcher-remove right:11-12:emulator-remove right:14-15:ge-proton right:17-18:renkit right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            software-remove) bazzite_uninstall_software_menu || return 0 ;;
            launcher-remove) bazzite_uninstall_launcher_menu || return 0 ;;
            emulator-remove) bazzite_uninstall_emulator_menu || return 0 ;;
            ge-proton) confirm_and_run "卸载当前 GE-Proton" "只删除Renkit当前识别的 GE-Proton 版本" bash "$PROJECT_ROOT/modules/ge_proton.sh" uninstall ;;
            renkit) confirm_and_run "卸载 Renkit" "只删除Renkit安装目录和桌面入口" bash "$PROJECT_ROOT/uninstall.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

notice_menu() {
    local choice
    draw_category_frame notice "免责声明与使用须知" "Bazzite 版功能与 SteamOS 版相互隔离"
    ui_panel_line 8 '\033[1;38;5;203m' "Renkit不包含付费软件、破解、ROM、BIOS 或密钥"
    ui_panel_line 11 '\033[38;5;250m' "第三方软件与插件由各自作者或官方渠道提供"
    ui_panel_line 14 '\033[38;5;250m' "硬件控制仍未开放；Clover 是单独确认的高风险功能"
    ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页"
    ui_prompt
    choice="$(read_touch_menu right:20-21:home)"
    if apply_navigation "$choice"; then return 0; fi
    [ "$choice" = "home" ] && NEXT_CATEGORY="home"
}

if [ "${ZHOUKEER_SKIP_DISCLAIMER:-0}" != "1" ]; then
    show_disclaimer
fi

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init) bazzite_setup_menu ;;
        software) software_menu ;;
        games) games_menu ;;
        emulators) emulator_menu ;;
        support) support_menu ;;
        advanced) advanced_menu ;;
        uninstall) uninstall_menu ;;
        notice) notice_menu ;;
        exit) log "用户退出 Renkit Bazzite版"; exit 0 ;;
        *) NEXT_CATEGORY="home" ;;
    esac
done
