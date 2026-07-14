#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

ensure_runtime_dirs

# V4 默认就是纯触控界面。不再提供数字或字母菜单，避免键盘和触屏事件冲突。
case "${1:-}" in
    ""|--touch) ;;
    --gui) exec bash "$PROJECT_ROOT/core/gui.sh" ;;
    *) echo "请从桌面的“周克儿工具箱”图标启动。"; exit 1 ;;
esac

enable_mouse_tracking
trap 'disable_mouse_tracking' EXIT INT TERM

NEXT_CATEGORY="home"

pause_menu() {
    echo ""
    echo "请点击窗口任意位置返回工具箱"
    enable_mouse_tracking
    read_touch_click || true
}

run_action() {
    local status
    local title="$1"
    shift

    disable_mouse_tracking
    print_header
    print_section_title "$title"
    echo ""
    "$@"
    status=$?

    # 自更新会原子替换整个安装目录；父菜单必须主动进入新目录。
    if ! cd "$PROJECT_ROOT" 2>/dev/null; then
        cd "$HOME" 2>/dev/null || true
    fi

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
    ui_panel_line 9 '\033[1;38;5;255m' "请确认是否继续这项操作"
    ui_touch_button 12 '\033[1;30;48;5;114m' "继续执行" "已授权工具箱完成该操作"
    ui_touch_button 18 '\033[1;97;48;5;160m' "取消" "不做任何更改，返回菜单"
    ui_prompt
    choice="$(read_menu_choice right:12-13:yes right:18-19:no)"
    if [ "$choice" = "yes" ]; then
        run_action "$title" env ZHOUKEER_AUTO_CONFIRM=1 "$@"
    fi
}

read_touch_menu() {
    read_menu_choice \
        left:3-4:nav-init \
        left:6-7:nav-software \
        left:9-10:nav-remote \
        left:12-13:nav-plugins \
        left:15-16:nav-settings \
        left:18-19:nav-optimize \
        left:21-22:nav-update \
        left:26-27:nav-exit \
        "$@"
}

apply_navigation() {
    case "$1" in
        nav-init) NEXT_CATEGORY="init" ;;
        nav-software) NEXT_CATEGORY="software" ;;
        nav-remote) NEXT_CATEGORY="remote" ;;
        nav-plugins) NEXT_CATEGORY="plugins" ;;
        nav-settings) NEXT_CATEGORY="settings" ;;
        nav-optimize) NEXT_CATEGORY="optimize" ;;
        nav-update) NEXT_CATEGORY="update" ;;
        nav-exit) NEXT_CATEGORY="exit" ;;
        *) return 1 ;;
    esac
    return 0
}

common_software_menu() {
    local choice

    while true; do
        draw_category_frame software "常用软件" "国内缓存优先，安装完成自动创建桌面图标"
        ui_touch_button 9 '\033[1;97;48;5;24m' "微信" "安装或修复微信，同步创建桌面快捷方式"
        ui_touch_button 13 '\033[1;97;48;5;24m' "QQ" "安装或修复 QQ，同步创建桌面快捷方式"
        ui_touch_button 17 '\033[1;97;48;5;24m' "ProtonUp-Qt" "管理 Proton-GE 等游戏兼容层"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:9-10:wechat right:13-14:qq right:17-18:protonup right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            wechat) confirm_and_run "安装微信" "国内缓存优先；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            qq) confirm_and_run "安装QQ" "国内缓存优先；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            protonup) confirm_and_run "安装ProtonUp-Qt" "安装完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" protonup ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame remote "远程协助" "售后支持和故障处理，RustDesk 已配置自建服务器"
        ui_touch_button 9 '\033[1;97;48;5;24m' "ToDesk" "国内远程协助，安装时需要管理员密码"
        ui_touch_button 13 '\033[1;97;48;5;24m' "RustDesk" "123云盘高速源优先，失败自动切换备用源"
        ui_touch_button 17 '\033[1;97;48;5;24m' "服务器配置" "查看 RustDesk ID、中继和 API 服务器"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:9-10:todesk right:13-14:rustdesk right:17-18:config right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            todesk) confirm_and_run "ToDesk远程工具" "安装时仍需输入 Steam Deck 管理员密码" bash "$PROJECT_ROOT/modules/todesk.sh" --install ;;
            rustdesk) confirm_and_run "RustDesk远程工具" "下载、校验并安装 RustDesk 1.4.8" bash "$PROJECT_ROOT/modules/rustdesk.sh" --install ;;
            config) run_action "RustDesk服务器配置" bash "$PROJECT_ROOT/modules/rustdesk.sh" --config ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

steam_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "Steam Deck 优化" "安全处理 Steam 缓存，并查看性能建议"
        ui_touch_button 9 '\033[1;97;48;5;24m' "清理 Steam 下载缓存" "删除未完成的下载残留"
        ui_touch_button 13 '\033[1;97;48;5;24m' "查看性能模式建议" "只读检查，不修改系统"
        ui_touch_button 17 '\033[1;97;48;5;24m' "清理着色器缓存" "释放空间，游戏会在下次启动时重建"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回系统优化" "查看其他优化功能"
        ui_prompt
        choice="$(read_touch_menu right:9-10:download-cache right:13-14:performance right:17-18:shader-cache right:23-24:back)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            download-cache) confirm_and_run "清理下载缓存" "清理后未完成的 Steam 下载需要重新开始" bash "$PROJECT_ROOT/modules/steam.sh" download-cache ;;
            performance) run_action "性能模式建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            shader-cache) confirm_and_run "清理着色器缓存" "清理后游戏着色器需要重新生成" bash "$PROJECT_ROOT/modules/steam.sh" shader-cache ;;
            back) return 0 ;;
        esac
    done
}

clean_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "系统清理" "只处理可重建的缓存，不删除游戏和个人文件"
        ui_touch_button 9 '\033[1;97;48;5;24m' "清理 Steam 下载残留" "释放未完成下载占用的空间"
        ui_touch_button 13 '\033[1;97;48;5;24m' "清理 Steam 着色器缓存" "下次运行游戏时会自动重建"
        ui_touch_button 17 '\033[1;97;48;5;24m' "清理 Linux 用户缓存" "不触碰 SteamOS 只读系统分区"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回系统优化" "查看其他优化功能"
        ui_prompt
        choice="$(read_touch_menu right:9-10:download-cache right:13-14:shader-cache right:17-18:user-cache right:23-24:back)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            download-cache) confirm_and_run "清理下载残留" "将删除 Steam 未完成的下载残留" bash "$PROJECT_ROOT/modules/clean.sh" download-cache ;;
            shader-cache) confirm_and_run "清理着色器缓存" "着色器会在下次运行游戏时重新生成" bash "$PROJECT_ROOT/modules/clean.sh" shader-cache ;;
            user-cache) confirm_and_run "清理用户缓存" "部分应用会在下次启动时重新生成缓存" bash "$PROJECT_ROOT/modules/clean.sh" user-cache ;;
            back) return 0 ;;
        esac
    done
}

plugin_store_menu() {
    local choice

    while true; do
        draw_category_frame plugins "插件商城" "管理 Steam Deck 的 Decky Loader 插件环境"
        ui_touch_button 10 '\033[1;97;48;5;24m' "安装或更新 Decky Loader" "执行经过校验的 Decky 官方安装器"
        ui_panel_line 15 '\033[1;38;5;255m' "安装后可以在游戏模式的快捷菜单中使用插件"
        ui_touch_button 21 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:10-11:install right:21-22:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            install) confirm_and_run "Decky Loader插件商城" "执行经过校验的 Decky 官方安装器" bash "$PROJECT_ROOT/modules/plugin_store.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

system_settings_menu() {
    local choice

    while true; do
        draw_category_frame settings "系统设置" "查看设备状态，检测网络并处理常见问题"
        ui_touch_button 10 '\033[1;97;48;5;24m' "查看系统信息" "SteamOS 版本、设备架构和基础环境"
        ui_touch_button 15 '\033[1;97;48;5;24m' "网络检测与修复" "检查 DNS、连通性和常用下载源"
        ui_touch_button 22 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:10-11:info right:15-16:network right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            info) run_action "系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            network) run_action "网络检测与修复" bash "$PROJECT_ROOT/modules/network.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

system_optimization_menu() {
    local choice

    while true; do
        draw_category_frame optimize "系统优化" "缓存清理、性能建议和常见问题修复"
        ui_touch_button 9 '\033[1;97;48;5;24m' "Steam Deck 优化" "下载缓存、着色器缓存和性能建议"
        ui_touch_button 13 '\033[1;97;48;5;24m' "系统清理" "安全释放用户缓存和 Steam 缓存"
        ui_touch_button 17 '\033[1;97;48;5;24m' "一键修复模式" "检测网络并处理常见下载问题"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:9-10:steam right:13-14:clean right:17-18:fix right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            steam) steam_touch_menu ;;
            clean) clean_touch_menu ;;
            fix) confirm_and_run "一键修复模式" "检测网络并安全清理 Steam 下载缓存" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

home_menu() {
    local choice

    draw_category_frame "" "欢迎使用" "全界面只需点击，无需输入任何数字或字母"
    ui_panel_line 9 '\033[1;38;5;220m' "⭐ 第一次使用：点击左侧“新机初始化”"
    ui_panel_line 12 '\033[1;38;5;255m' "💻 常用软件：微信、QQ、ProtonUp-Qt"
    ui_panel_line 14 '\033[1;38;5;255m' "📡 远程协助：ToDesk、RustDesk"
    ui_panel_line 16 '\033[1;38;5;255m' "🧩 插件商城：Decky Loader"
    ui_panel_line 18 '\033[1;38;5;255m' "⚙  系统设置：设备信息、网络检测"
    ui_panel_line 20 '\033[1;38;5;255m' "🚀 系统优化：清理、性能建议、一键修复"
    ui_panel_line 23 '\033[1;38;5;114m' "🔄 工具箱更新：国内 Gitee 优先，GitHub 备用"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init)
            confirm_and_run "一键新机初始化" "安装新机常用项目，部分步骤需要管理员密码" bash "$PROJECT_ROOT/modules/new_machine.sh"
            NEXT_CATEGORY="home"
            ;;
        software) common_software_menu ;;
        remote) remote_assistance_menu ;;
        plugins) plugin_store_menu ;;
        settings) system_settings_menu ;;
        optimize) system_optimization_menu ;;
        update)
            confirm_and_run "更新工具箱" "下载、校验并安全替换为最新版本" bash "$PROJECT_ROOT/update.sh"
            NEXT_CATEGORY="home"
            ;;
        exit)
            log "用户退出工具箱"
            exit 0
            ;;
        *) NEXT_CATEGORY="home" ;;
    esac
done
