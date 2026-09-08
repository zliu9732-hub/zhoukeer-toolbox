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
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

require_chimeraos || exit 1

RENKIT_PLATFORM_LABEL="CHIMERAOS 掌机  /  应用与插件"
RENKIT_CONSOLE_TITLE="ChimeraOS Application and Plugin Toolbox"
RENKIT_NAV_INIT_LABEL="◆ 使用准备"
RENKIT_NAV_SOFTWARE_LABEL="▣ 安装应用"
RENKIT_NAV_GAMES_LABEL="✦ 安装插件"
RENKIT_NAV_EMULATORS_LABEL="◎ 应用状态"
RENKIT_NAV_SUPPORT_LABEL="◇ 检查与维护"
RENKIT_NAV_ADVANCED_LABEL="! 平台说明"
RENKIT_NAV_UNINSTALL_LABEL="- 移除Renkit"
RENKIT_NAV_NOTICE_LABEL="▧ 免责声明与须知"
RENKIT_NAV_EXIT_LABEL="× 退出Renkit"
ZHOUKEER_FLATPAK_SOURCE_MODE="managed"
export RENKIT_PLATFORM_LABEL RENKIT_CONSOLE_TITLE
export RENKIT_NAV_INIT_LABEL RENKIT_NAV_SOFTWARE_LABEL RENKIT_NAV_GAMES_LABEL
export RENKIT_NAV_EMULATORS_LABEL RENKIT_NAV_SUPPORT_LABEL RENKIT_NAV_ADVANCED_LABEL
export RENKIT_NAV_UNINSTALL_LABEL RENKIT_NAV_NOTICE_LABEL RENKIT_NAV_EXIT_LABEL
export ZHOUKEER_FLATPAK_SOURCE_MODE

ensure_runtime_dirs

case "${1:-}" in
    ""|--touch) ;;
    *) echo "请从桌面的“Renkit ChimeraOS版”图标启动。"; exit 1 ;;
esac

APP_TARGETS=(
    wechat qq browser chrome edge rustdesk bottles protontricks
    libreoffice vlc obs localsend peazip heroic lutris chiaki4deck
    baidunetdisk willwill xbox-cloud qqmusic netease-music yesplaymusic qbittorrent motrix
)
APP_TITLES=(
    "微信" "QQ" "Firefox 浏览器" "Chrome 浏览器" "Edge 浏览器" "RustDesk" "Bottles" "Protontricks"
    "LibreOffice" "VLC 播放器" "OBS Studio" "LocalSend" "PeaZip" "Heroic" "Lutris" "Chiaki4Deck"
    "百度网盘" "WiliWili（B站）" "Xbox 云游戏" "QQ音乐" "网易云音乐" "YesPlayMusic" "qBittorrent" "Motrix"
)
APP_DESCRIPTIONS=(
    "腾讯官方 AppImage" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "作者官方 AppImage" "Flatpak（可选国内源）" "Flatpak（可选国内源）"
    "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Flatpak（可选国内源）"
    "Flatpak（可选国内源）" "Flatpak（可选国内源）" "Greenlight 云游戏客户端" "Flatpak（可选国内源）" "Flatpak（可选国内源）" "第三方开源客户端" "Flatpak（可选国内源）" "用户空间下载工具"
)

PLUGIN_ACTIONS=(
    lsfg-zh-gitee lsfg-mako fsr4-zh-gitee cheatdeck deckrecall savepulse steamgriddb cssloader
    friendeck deckymusic freedeck newfreedeck tomoon unifideck simpledeckytdp-zh-gitee
)
PLUGIN_TITLES=(
    "旧版小黄鸭" "MAKO 小黄鸭" "FSR4 帧生成" "CheatDeck" "DeckRecall" "SavePulse" "游戏封面更换" "主题美化"
    "文件传输助手" "音乐播放器" "Freedeck" "NewFreedeck" "ToMoon" "Unifideck" "掌机功耗控制"
)
PLUGIN_DESCRIPTIONS=(
    "v0.12.8 汉化稳定版" "上游官方中文最新版" "Decky-Framegen 中文版" "游戏启动参数工具" "游戏录像与回放" "存档备份与恢复" "SteamGridDB" "CSS Loader 中文版"
    "Friendeck" "Decky Music 完整包" "功能扩展" "重构版功能扩展" "网络辅助插件" "功能整合插件" "SimpleDeckyTDP 中文版，请核对机型"
)

show_startup_loading() {
    printf '\033[0m\033[2J\033[H\n\n  Renkit ChimeraOS版启动中，请耐心等待…\n'
}

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

run_confirmed_action() {
    ZHOUKEER_AUTO_CONFIRM=1 "$@"
}

confirm_and_run() {
    local title="$1" message="$2" choice
    shift 2
    draw_category_frame "" "$title" "$message"
    ui_panel_line 8 '\033[1;38;5;220m' "请确认是否继续这项操作"
    ui_touch_button 10 '\033[1;30;48;5;114m' "继续执行" "只写入当前用户的应用或插件目录"
    ui_touch_button 15 '\033[1;97;48;5;160m' "返回主菜单" "不做任何更改"
    ui_prompt
    choice="$(read_touch_menu right:10-11:yes right:15-16:no)"
    if apply_navigation "$choice"; then return 0; fi
    [ "$choice" = "yes" ] && run_action "$title" run_confirmed_action "$@"
}

chimera_plugin_environment_ready() {
    if [ -x "$HOME/homebrew/services/PluginLoader" ] || \
       [ -x "$HOME/.local/share/decky-loader/services/PluginLoader" ]; then
        return 0
    fi
    echo "未检测到 ChimeraOS 自带插件环境。"
    echo "请先在系统自带入口启用插件支持，再返回 Renkit 安装插件。"
    echo "Renkit不会安装、升级或替换插件商城本体。"
    return 1
}

chimera_plugin_environment_status() {
    require_chimeraos || return 1
    if chimera_plugin_environment_ready; then
        echo "ChimeraOS 插件环境：已检测到"
        echo "插件目录：${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    else
        echo "ChimeraOS 插件环境：未检测到"
    fi
}

chimera_install_plugin() {
    local action="$1"
    require_chimeraos || return 1
    chimera_plugin_environment_ready || return 1
    bash "$PROJECT_ROOT/modules/plugin_store.sh" "$action"
}

show_disclaimer() {
    local choice
    while true; do
        draw_disclaimer_frame
        ui_disclaimer_line 8 '\033[1;38;5;220m' "Renkit ChimeraOS版只管理当前用户的应用与插件"
        ui_disclaimer_line 9 '\033[38;5;45m' "插件商城本体由 ChimeraOS 自带功能负责"
        ui_disclaimer_line 10 '\033[38;5;45m' "不会执行 pacman、frzr、系统更新或系统服务替换"
        ui_disclaimer_line 11 '\033[38;5;45m' "不会提供双系统、互通盘、Clover、EFI 或磁盘操作"
        ui_disclaimer_line 12 '\033[38;5;45m' "Flatpak 可选官方签名源或经确认的国内缓存；AppImage 保持官方渠道"
        ui_disclaimer_line 13 '\033[1;38;5;220m' "插件下载完成后请重新进入游戏模式加载"
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
    draw_category_frame "" "Renkit ChimeraOS版" "只安装应用和插件，不修改系统或引导"
    ui_panel_line 8 '\033[1;38;5;220m' "已自动切换到 ChimeraOS 安全功能集"
    ui_panel_line 10 '\033[1;38;5;45m' "开放：用户级 Flatpak 下载线路、官方 AppImage、现有环境中的插件"
    ui_panel_line 12 '\033[1;38;5;114m' "插件商城本体继续由 ChimeraOS 自带功能维护"
    ui_panel_line 14 '\033[1;38;5;250m' "不开放：系统、磁盘、双系统、互通盘和 EFI 功能"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

confirm_domestic_flatpak_source() {
    local choice
    draw_category_frame init "启用 Flatpak 国内下载" "仅修改当前用户的 Flatpak 远程源"
    ui_panel_line 6 '\033[1;38;5;220m' "风险：两个国内缓存均会关闭 Flatpak GPG 验证"
    ui_panel_line 8 '\033[38;5;45m' "flathub-cn｜https://mirror.sjtu.edu.cn/flathub"
    ui_panel_line 10 '\033[38;5;45m' "flathub-ustc｜https://mirrors.ustc.edu.cn/flathub"
    ui_panel_line 12 '\033[38;5;250m' "不会运行 pacman、frzr、sudo 或修改 ChimeraOS 系统"
    ui_touch_button 15 '\033[1;30;48;5;114m' "确认信任并启用" "关闭上述两个缓存的 GPG 验证"
    ui_touch_button 19 '\033[1;97;48;5;160m' "取消" "不修改 Flatpak 远程源"
    ui_prompt
    choice="$(read_touch_menu right:15-16:yes right:19-20:no)"
    if apply_navigation "$choice"; then return 0; fi
    if [ "$choice" = "yes" ]; then
        run_action "启用 Flatpak 国内下载" env \
            ZHOUKEER_AUTO_CONFIRM=1 \
            ZHOUKEER_DOMESTIC_SOURCE_CONFIRMED=1 \
            ZHOUKEER_FLATPAK_SOURCE_MODE=managed \
            bash "$PROJECT_ROOT/modules/software.sh" enable-domestic-remotes
    fi
}

confirm_official_flatpak_restore() {
    local choice
    draw_category_frame init "恢复官方 Flathub" "仅修改当前用户的 Flatpak 远程源"
    ui_panel_line 7 '\033[1;38;5;114m' "恢复：https://dl.flathub.org/repo/"
    ui_panel_line 9 '\033[38;5;45m' "重新导入 Flathub 官方公钥并启用 GPG 验证"
    ui_panel_line 11 '\033[38;5;250m' "移除 flathub-cn 与 flathub-ustc 用户级缓存"
    ui_panel_line 13 '\033[38;5;250m' "不会修改 ChimeraOS 系统密钥或不可变系统"
    ui_touch_button 16 '\033[1;30;48;5;114m' "确认恢复官方源"
    ui_touch_button 20 '\033[1;97;48;5;160m' "取消"
    ui_prompt
    choice="$(read_touch_menu right:16-17:yes right:20-21:no)"
    if apply_navigation "$choice"; then return 0; fi
    [ "$choice" = "yes" ] && run_action "恢复官方 Flathub" env \
        ZHOUKEER_FLATPAK_SOURCE_MODE=managed \
        bash "$PROJECT_ROOT/modules/software.sh" restore-official-remote
}

flatpak_source_menu() {
    local choice
    while true; do
        draw_category_frame init "Flatpak 下载线路" "官方源或国内双缓存，只管理当前用户"
        ui_touch_button 5 '\033[1;97;48;5;24m' "查看当前线路" "显示地址与 GPG 验证状态"
        ui_touch_button 9 '\033[1;97;48;5;24m' "启用国内下载" "上海交大 → 中科大"
        ui_touch_button 13 '\033[1;97;48;5;24m' "恢复官方 Flathub" "修复官方公钥与 GPG 验证"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回使用准备"
        ui_prompt
        choice="$(read_touch_menu right:5-6:status right:9-10:domestic right:13-14:official right:21-22:back)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            status) run_action "查看 Flatpak 下载线路" env ZHOUKEER_FLATPAK_SOURCE_MODE=managed bash "$PROJECT_ROOT/modules/software.sh" source-status ;;
            domestic) confirm_domestic_flatpak_source ;;
            official) confirm_official_flatpak_restore ;;
            back) return 0 ;;
        esac
    done
}

setup_menu() {
    local choice
    while true; do
        draw_category_frame init "ChimeraOS 使用准备" "只读检查与用户级 Flatpak 下载线路"
        ui_touch_button 4 '\033[1;97;48;5;24m' "查看系统信息" "识别 ChimeraOS 版本与设备状态"
        ui_touch_button 7 '\033[1;97;48;5;24m' "一键检查网络" "检查 Steam、Flathub 与下载线路"
        ui_touch_button 10 '\033[1;97;48;5;24m' "查看插件环境" "只检测系统自带 Loader 和插件目录"
        ui_touch_button 13 '\033[1;97;48;5;24m' "Flatpak 下载线路" "国内双缓存或官方签名源"
        ui_touch_button 16 '\033[1;97;48;5;24m' "查看应用状态" "只读取 Flatpak 与 AppImage"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:4-5:system right:7-8:network right:10-11:plugins right:13-14:sources right:16-17:apps right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            system) run_action "查看 ChimeraOS 系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            network) run_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            plugins) run_action "查看插件环境" chimera_plugin_environment_status ;;
            sources) flatpak_source_menu ;;
            apps) run_action "查看应用状态" bash "$PROJECT_ROOT/modules/software.sh" status ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

software_menu() {
    local choice page=0 start index slot row total pages
    local -a touch_args
    total="${#APP_TARGETS[@]}"
    pages=$(((total + 6) / 7))
    while true; do
        draw_category_frame software "安装应用（第 $((page + 1)) / $pages 页）" "可切换 Flatpak 下载线路与已校验 AppImage"
        start=$((page * 7))
        touch_args=()
        for slot in 0 1 2 3 4 5 6; do
            index=$((start + slot))
            [ "$index" -lt "$total" ] || break
            row=$((4 + slot * 2))
            ui_touch_button "$row" '\033[1;97;48;5;24m' "${APP_TITLES[$index]}" "${APP_DESCRIPTIONS[$index]}"
            touch_args+=("right:${row}-$((row + 1)):app-$index")
        done
        [ "$page" -gt 0 ] && ui_touch_button 19 '\033[1;97;48;5;238m' "上一页"
        [ "$page" -lt $((pages - 1)) ] && ui_touch_button 21 '\033[1;97;48;5;24m' "下一页"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu "${touch_args[@]}" right:19-20:previous right:21-22:next right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            previous) [ "$page" -gt 0 ] && page=$((page - 1)) ;;
            next) [ "$page" -lt $((pages - 1)) ] && page=$((page + 1)) ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
            app-*)
                index="${choice#app-}"
                case "$index" in ''|*[!0-9]*) continue ;; esac
                [ "$index" -lt "$total" ] || continue
                confirm_and_run "安装${APP_TITLES[$index]}" "${APP_DESCRIPTIONS[$index]}；只管理当前用户安装" \
                    bash "$PROJECT_ROOT/modules/software.sh" "${APP_TARGETS[$index]}"
                ;;
        esac
    done
}

plugin_menu() {
    local choice page=0 start index slot row total pages
    local -a touch_args
    total="${#PLUGIN_ACTIONS[@]}"
    pages=$(((total + 5) / 6))
    while true; do
        draw_category_frame games "安装插件（第 $((page + 1)) / $pages 页）" "使用 ChimeraOS 已有插件环境，不管理 Loader"
        start=$((page * 6))
        touch_args=()
        for slot in 0 1 2 3 4 5; do
            index=$((start + slot))
            [ "$index" -lt "$total" ] || break
            row=$((4 + slot * 2))
            ui_touch_button "$row" '\033[1;97;48;5;24m' "${PLUGIN_TITLES[$index]}" "${PLUGIN_DESCRIPTIONS[$index]}"
            touch_args+=("right:${row}-$((row + 1)):plugin-$index")
        done
        ui_touch_button 17 '\033[1;97;48;5;24m' "查看插件状态" "不安装、不更新"
        [ "$page" -gt 0 ] && ui_touch_button 19 '\033[1;97;48;5;238m' "上一页"
        [ "$page" -lt $((pages - 1)) ] && ui_touch_button 21 '\033[1;97;48;5;24m' "下一页"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu "${touch_args[@]}" right:17-18:status right:19-20:previous right:21-22:next right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            previous) [ "$page" -gt 0 ] && page=$((page - 1)) ;;
            next) [ "$page" -lt $((pages - 1)) ] && page=$((page + 1)) ;;
            status) run_action "查看插件状态" bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
            plugin-*)
                index="${choice#plugin-}"
                case "$index" in ''|*[!0-9]*) continue ;; esac
                [ "$index" -lt "$total" ] || continue
                confirm_and_run "安装${PLUGIN_TITLES[$index]}" "${PLUGIN_DESCRIPTIONS[$index]}；安装后重新进入游戏模式" \
                    chimera_install_plugin "${PLUGIN_ACTIONS[$index]}"
                ;;
        esac
    done
}

status_menu() {
    local choice
    while true; do
        draw_category_frame emulators "应用与插件状态" "全部为只读检查"
        ui_touch_button 6 '\033[1;97;48;5;24m' "查看应用状态" "Flatpak 与 AppImage"
        ui_touch_button 10 '\033[1;97;48;5;24m' "查看插件环境" "系统自带 Loader"
        ui_touch_button 14 '\033[1;97;48;5;24m' "查看插件状态" "Renkit 可识别的插件"
        ui_touch_button 18 '\033[1;97;48;5;24m' "修复应用桌面图标" "不安装或卸载应用"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:6-7:apps right:10-11:environment right:14-15:plugins right:18-19:repair right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            apps) run_action "查看应用状态" bash "$PROJECT_ROOT/modules/software.sh" status ;;
            environment) run_action "查看插件环境" chimera_plugin_environment_status ;;
            plugins) run_action "查看插件状态" bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status ;;
            repair) confirm_and_run "修复应用桌面图标" "只重建已安装应用的入口" bash "$PROJECT_ROOT/modules/software.sh" repair-shortcuts ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

support_menu() {
    local choice
    while true; do
        draw_category_frame support "检查与维护" "诊断与 Renkit 自身维护"
        ui_touch_button 4 '\033[1;97;48;5;24m' "一键检查网络"
        ui_touch_button 7 '\033[1;97;48;5;24m' "系统健康检查" "只读"
        ui_touch_button 10 '\033[1;97;48;5;24m' "生成诊断包" "不会上传"
        ui_touch_button 13 '\033[1;97;48;5;24m' "导出Renkit操作记录" "不包含密码"
        ui_touch_button 16 '\033[1;97;48;5;24m' "检查并更新Renkit" "不更新 ChimeraOS"
        ui_touch_button 19 '\033[1;97;48;5;24m' "中文兼容攻略"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
        ui_prompt
        choice="$(read_touch_menu right:4-5:network right:7-8:health right:10-11:diagnostic right:13-14:records right:16-17:update right:19-20:guides right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            network) run_action "一键检查网络" bash "$PROJECT_ROOT/modules/network.sh" ;;
            health) run_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            diagnostic) run_action "生成诊断包" bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle ;;
            records) run_action "导出Renkit操作记录" bash "$PROJECT_ROOT/modules/safety_center.sh" records ;;
            update) confirm_and_run "检查并更新Renkit" "只更新 Renkit 用户目录，不更新 ChimeraOS" bash "$PROJECT_ROOT/update.sh" ;;
            guides) run_action "中文兼容攻略" bash "$PROJECT_ROOT/modules/game_guides.sh" show ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

advanced_menu() {
    local choice
    draw_category_frame advanced "ChimeraOS 版功能边界" "保持 frzr 不可变系统与系统自带应用能力"
    ui_panel_line 7 '\033[1;38;5;114m' "✓ 用户级应用与现有 Loader 中的插件"
    ui_panel_line 10 '\033[1;38;5;114m' "✓ 状态检查、诊断、日志与Renkit自更新"
    ui_panel_line 13 '\033[1;38;5;220m' "不提供：插件商城本体、pacman、frzr、系统服务替换"
    ui_panel_line 16 '\033[1;38;5;220m' "不提供：双系统、互通盘、Clover、EFI、磁盘与系统调优"
    ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页"
    ui_prompt
    choice="$(read_touch_menu right:22-23:home)"
    if apply_navigation "$choice"; then return 0; fi
    [ "$choice" = "home" ] && NEXT_CATEGORY="home"
}

uninstall_menu() {
    local choice
    draw_category_frame uninstall "移除 Renkit" "应用与插件请使用 ChimeraOS 自带管理入口"
    ui_panel_line 8 '\033[1;38;5;250m' "Renkit不会卸载系统级 Flatpak、插件商城或系统组件"
    ui_panel_line 11 '\033[1;38;5;250m' "移除Renkit不会删除已安装的应用、插件、游戏或配置"
    ui_touch_button 15 '\033[1;97;48;5;160m' "卸载 Renkit" "只删除Renkit安装目录和桌面入口"
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
    draw_category_frame notice "免责声明与使用须知" "ChimeraOS 独立安全功能集"
    ui_panel_line 8 '\033[1;38;5;203m' "Renkit不包含付费软件、破解、ROM、BIOS 或密钥"
    ui_panel_line 11 '\033[38;5;250m' "应用与插件由各自作者或官方渠道提供"
    ui_panel_line 14 '\033[38;5;250m' "插件兼容性取决于 ChimeraOS、Steam 与 Loader 当前版本"
    ui_panel_line 17 '\033[38;5;250m' "安装插件前请保存游戏进度，完成后重新进入游戏模式"
    ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页"
    ui_prompt
    choice="$(read_touch_menu right:21-22:home)"
    if apply_navigation "$choice"; then return 0; fi
    [ "$choice" = "home" ] && NEXT_CATEGORY="home"
}

show_startup_loading
ui_apply_screen_font
ui_wait_for_minimum_canvas || true
enable_mouse_tracking
trap 'disable_mouse_tracking' EXIT INT TERM

NEXT_CATEGORY="home"
if [ "${ZHOUKEER_SKIP_DISCLAIMER:-0}" != "1" ]; then
    show_disclaimer
fi

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init) setup_menu ;;
        software) software_menu ;;
        games) plugin_menu ;;
        emulators) status_menu ;;
        support) support_menu ;;
        advanced) advanced_menu ;;
        uninstall) uninstall_menu ;;
        notice) notice_menu ;;
        exit) log "用户退出 Renkit ChimeraOS版"; exit 0 ;;
        *) NEXT_CATEGORY="home" ;;
    esac
done
