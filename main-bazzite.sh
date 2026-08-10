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
    ui_panel_line 14 '\033[1;38;5;250m' "系统调优、pacman、ToDesk、EFI 功能不会出现在本版"
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
        if [ "$page" -eq 0 ]; then
            draw_category_frame software "安装常用软件" "Flatpak 与 AppImage · 第 1/2 页"
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
        else
            draw_category_frame software "安装常用软件" "办公、媒体与工具 · 第 2/2 页"
            ui_touch_button 2 '\033[1;97;48;5;24m' "LibreOffice"
            ui_touch_button 4 '\033[1;97;48;5;24m' "VLC 播放器"
            ui_touch_button 6 '\033[1;97;48;5;24m' "OBS Studio"
            ui_touch_button 8 '\033[1;97;48;5;24m' "LocalSend"
            ui_touch_button 10 '\033[1;97;48;5;24m' "PeaZip"
            ui_touch_button 12 '\033[1;97;48;5;24m' "Heroic 游戏启动器"
            ui_touch_button 14 '\033[1;97;48;5;24m' "Lutris"
            ui_touch_button 16 '\033[1;97;48;5;24m' "Chiaki4Deck"
            ui_touch_button 19 '\033[1;97;48;5;24m' "上一页"
            ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
            ui_prompt
            choice="$(read_touch_menu right:2-3:libreoffice right:4-5:vlc right:6-7:obs right:8-9:localsend right:10-11:peazip right:12-13:heroic right:14-15:lutris right:16-17:chiaki4deck right:19-20:previous right:22-23:home)"
        fi
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            next) page=1; continue ;;
            previous) page=0; continue ;;
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

games_menu() {
    local choice
    while true; do
        draw_category_frame games "游戏与插件" "Bazzite 官方 Decky · Proton · 启动器"
        ui_touch_button 2 '\033[1;97;48;5;24m' "安装 Decky Loader" "Bazzite 官方 ujust"
        ui_touch_button 4 '\033[1;97;48;5;24m' "安装常用 Decky 插件" "只使用 Decky 官方商店"
        ui_touch_button 6 '\033[1;97;48;5;24m' "安装最新 GE-Proton"
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
            plugins) confirm_and_run "安装常用 Decky 插件" "从 Decky 官方商店读取最新版本；不安装硬件控制插件" env DECKY_BUNDLE_INCLUDE_CUSTOM=0 bash "$PROJECT_ROOT/modules/decky_bundle.sh" install ;;
            ge) confirm_and_run "安装最新 GE-Proton" "安装到当前用户的 Steam 兼容工具目录" bash "$PROJECT_ROOT/modules/ge_proton.sh" install ;;
            epic|battlenet|ubisoft|heihe) confirm_and_run "安装游戏启动器" "安装完成后写入 Steam 库与封面" bash "$PROJECT_ROOT/modules/game_launchers.sh" "$choice" ;;
            repair) launcher_repair_menu || return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
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
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:2-3:yuzu right:4-5:cemu right:6-7:duckstation right:8-9:pcsx2 right:10-11:rpcs3 right:12-13:shadps4 right:14-15:ppsspp right:16-17:mgba right:18-19:azahar right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            home) NEXT_CATEGORY="home"; return 0 ;;
            yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4|ppsspp|mgba|azahar)
                title="$choice"
                confirm_and_run "安装模拟器" "只安装模拟器本体，不包含游戏、BIOS、固件或密钥" bash "$PROJECT_ROOT/modules/emulators.sh" "$title"
                ;;
        esac
    done
}

support_menu() {
    local choice
    while true; do
        draw_category_frame support "检查与维护" "只读检查、安全清理与Renkit更新"
        ui_touch_button 2 '\033[1;97;48;5;24m' "一键检查网络"
        ui_touch_button 4 '\033[1;97;48;5;24m' "系统健康检查"
        ui_touch_button 6 '\033[1;97;48;5;24m' "游戏启动检查"
        ui_touch_button 8 '\033[1;97;48;5;24m' "生成诊断包"
        ui_touch_button 10 '\033[1;97;48;5;24m' "清理 Steam 下载残留"
        ui_touch_button 12 '\033[1;97;48;5;24m' "清理着色器缓存"
        ui_touch_button 14 '\033[1;97;48;5;24m' "清理 Linux 用户缓存"
        ui_touch_button 16 '\033[1;97;48;5;24m' "检查并更新Renkit"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:2-3:network right:4-5:health right:6-7:game right:8-9:diagnostic right:10-11:download-cache right:12-13:shader-cache right:14-15:user-cache right:16-17:update right:21-22:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            network) run_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            health) run_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            game) run_action "游戏启动检查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            diagnostic) run_action "生成诊断包" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            download-cache|shader-cache|user-cache) confirm_and_run "安全清理" "只删除可重新生成的缓存" bash "$PROJECT_ROOT/modules/clean.sh" "$choice" ;;
            update) confirm_and_run "检查并更新Renkit" "下载、校验并安全替换当前 Bazzite 版" bash "$PROJECT_ROOT/update.sh" ;;
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
        ui_panel_line 13 '\033[1;38;5;220m' "暂不开放：系统调优、ToDesk、EFI、Clover、pacman 国内源"
        ui_panel_line 16 '\033[1;38;5;250m' "这些功能与 SteamOS 版完全隔离，不会误调用"
        ui_touch_button 20 '\033[1;97;48;5;24m' "查看 Bazzite 与 Decky 状态"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:20-21:status right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            status) NEXT_CATEGORY="init"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

uninstall_menu() {
    local choice
    draw_category_frame uninstall "卸载" "Bazzite 版首期只提供安全的Renkit自身卸载"
    ui_panel_line 8 '\033[1;38;5;220m' "软件、启动器和模拟器可在对应菜单重复安装或维护"
    ui_panel_line 11 '\033[1;38;5;250m' "Decky 请使用 Bazzite 官方工具维护"
    ui_touch_button 15 '\033[1;97;48;5;160m' "卸载 Renkit" "删除工具箱本体，不删除已安装软件和游戏"
    ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页"
    ui_prompt
    choice="$(read_touch_menu right:15-16:renkit right:21-22:home)"
    if apply_navigation "$choice"; then return 0; fi
    case "$choice" in
        renkit) confirm_and_run "卸载 Renkit" "只删除Renkit安装目录和桌面入口" bash "$PROJECT_ROOT/uninstall.sh" ;;
        home) NEXT_CATEGORY="home" ;;
    esac
}

notice_menu() {
    local choice
    draw_category_frame notice "免责声明与使用须知" "Bazzite 版功能与 SteamOS 版相互隔离"
    ui_panel_line 8 '\033[1;38;5;203m' "Renkit不包含付费软件、破解、ROM、BIOS 或密钥"
    ui_panel_line 11 '\033[38;5;250m' "第三方软件与插件由各自作者或官方渠道提供"
    ui_panel_line 14 '\033[38;5;250m' "硬件控制和系统级修改尚未在 Bazzite 版开放"
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
