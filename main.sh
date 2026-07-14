#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    ui_panel_line 8 '\033[1;38;5;255m' "请确认是否继续这项操作"
    ui_touch_button 10 '\033[1;30;48;5;114m' "继续执行" "已授权工具箱完成该操作"
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
        # 免责声明独占整个窗口，避免侧栏和长句把确认按钮挤出可见区域。
        draw_disclaimer_frame
        ui_disclaimer_line 8 '\033[1;38;5;255m' "本脚本由 闲鱼：超级妹宝双叶 制作"
        ui_disclaimer_line 9 '\033[38;5;255m' "支持所有人免费使用"
        ui_disclaimer_line 10 '\033[38;5;255m' "禁止商业使用、销售、转卖或借此盈利"
        ui_disclaimer_line 11 '\033[38;5;255m' "下载内容均来自官方免费发布或开源项目"
        ui_disclaimer_line 12 '\033[38;5;255m' "不包含付费软件本体、破解或商业授权"
        ui_disclaimer_line 13 '\033[38;5;250m' "若有侵权，请联系作者删除"
        ui_disclaimer_button 15 '\033[1;38;5;114m' "知悉并开始使用" "点击即表示已阅读上述说明"
        ui_disclaimer_button 18 '\033[1;38;5;203m' "退出工具箱" "暂不使用"
        choice="$(read_menu_choice any:15-16:agree any:18-19:exit)"
        case "$choice" in
            agree) return 0 ;;
            exit) exit 0 ;;
        esac
    done
}

read_touch_menu() {
    read_menu_choice \
        left:2-3:nav-init \
        left:4-5:nav-software \
        left:6-7:nav-remote \
        left:8-9:nav-plugins \
        left:10-11:nav-settings \
        left:12-13:nav-optimize \
        left:14-15:nav-update \
        left:17-18:nav-exit \
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
        ui_touch_button 8 '\033[1;97;48;5;24m' "微信" "安装或修复微信，同步创建桌面快捷方式"
        ui_touch_button 11 '\033[1;97;48;5;24m' "QQ" "安装或修复 QQ，同步创建桌面快捷方式"
        ui_touch_button 14 '\033[1;97;48;5;24m' "ProtonUp-Qt" "管理 Proton-GE 等游戏兼容层"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:wechat right:11-12:qq right:14-15:protonup right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            wechat) confirm_and_run "安装微信" "国内缓存优先；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            qq) confirm_and_run "安装QQ" "国内缓存优先；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            protonup) confirm_and_run "安装ProtonUp-Qt" "安装完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" protonup ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "software" ] || return 0
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame remote "远程协助" "售后支持和故障处理，RustDesk 已配置自建服务器"
        ui_touch_button 8 '\033[1;97;48;5;24m' "ToDesk" "国内远程协助，安装时需要管理员密码"
        ui_touch_button 11 '\033[1;97;48;5;24m' "RustDesk" "123云盘高速源优先，失败自动切换备用源"
        ui_touch_button 14 '\033[1;97;48;5;24m' "服务器配置" "查看 RustDesk ID、中继和 API 服务器"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:todesk right:11-12:rustdesk right:14-15:config right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            todesk) confirm_and_run "ToDesk远程工具" "安装时仍需输入 Steam Deck 管理员密码" bash "$PROJECT_ROOT/modules/todesk.sh" --install ;;
            rustdesk) confirm_and_run "RustDesk远程工具" "下载、校验并安装 RustDesk 1.4.8" bash "$PROJECT_ROOT/modules/rustdesk.sh" --install ;;
            config) run_action "RustDesk服务器配置" bash "$PROJECT_ROOT/modules/rustdesk.sh" --config ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "remote" ] || return 0
    done
}

steam_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "Steam Deck 优化" "安全处理 Steam 缓存，并查看性能建议"
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

plugin_store_menu() {
    local choice

    while true; do
        draw_category_frame plugins "插件商城" "Decky 与三个常用插件均使用 123 云盘国内分流"
        ui_touch_button 7 '\033[1;97;48;5;24m' "安装或更新 Decky Loader" "使用经过固定校验的国内安装源"
        ui_touch_button 9 '\033[1;97;48;5;24m' "小黄鸭（LSFG-VK）" "安装插件后自动打开 Steam 正版页面"
        ui_touch_button 11 '\033[1;97;48;5;24m' "FSR4（Decky Framegen）" "下载并安装到 Decky 插件目录"
        ui_touch_button 13 '\033[1;97;48;5;24m' "CheatDeck" "下载并安装到 Decky 插件目录"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:install right:9-10:lsfg right:11-12:fsr4 right:13-14:cheatdeck right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            install) confirm_and_run "Decky Loader插件商城" "使用国内镜像安装器，执行前会校验固定 SHA256" bash "$PROJECT_ROOT/modules/plugin_store.sh" store ;;
            lsfg) confirm_and_run "小黄鸭（LSFG-VK）" "安装插件后将打开 Lossless Scaling 的 Steam 正版页面" bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg ;;
            fsr4) confirm_and_run "FSR4（Decky Framegen）" "将安装到 Decky 插件目录" bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4 ;;
            cheatdeck) confirm_and_run "CheatDeck" "将安装到 Decky 插件目录" bash "$PROJECT_ROOT/modules/plugin_store.sh" cheatdeck ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "plugins" ] || return 0
    done
}

system_settings_menu() {
    local choice

    while true; do
        draw_category_frame settings "系统设置" "查看设备状态，检测网络并处理常见问题"
        ui_touch_button 8 '\033[1;97;48;5;24m' "查看系统信息" "SteamOS 版本、设备架构和基础环境"
        ui_touch_button 12 '\033[1;97;48;5;24m' "网络检测与修复" "检查 DNS、连通性和常用下载源"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:info right:12-13:network right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            info) run_action "系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            network) run_action "网络检测与修复" bash "$PROJECT_ROOT/modules/network.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "settings" ] || return 0
    done
}

system_optimization_menu() {
    local choice

    while true; do
        draw_category_frame optimize "系统优化" "缓存清理、性能建议和常见问题修复"
        ui_touch_button 8 '\033[1;97;48;5;24m' "Steam Deck 优化" "下载缓存、着色器缓存和性能建议"
        ui_touch_button 11 '\033[1;97;48;5;24m' "系统清理" "安全释放用户缓存和 Steam 缓存"
        ui_touch_button 14 '\033[1;97;48;5;24m' "一键修复模式" "检测网络并处理常见下载问题"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:steam right:11-12:clean right:14-15:fix right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            steam) steam_touch_menu ;;
            clean) clean_touch_menu ;;
            fix) confirm_and_run "一键修复模式" "检测网络并安全清理 Steam 下载缓存" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "optimize" ] || return 0
    done
}

home_menu() {
    local choice

    draw_category_frame "" "欢迎使用" "全界面只需点击，无需输入任何数字或字母"
    ui_panel_line 8 '\033[1;38;5;220m' "⭐ 第一次使用：点击左侧“新机初始化”"
    ui_panel_line 10 '\033[1;38;5;255m' "💻 常用软件：微信、QQ、ProtonUp-Qt"
    ui_panel_line 12 '\033[1;38;5;255m' "📡 远程协助：ToDesk、RustDesk"
    ui_panel_line 14 '\033[1;38;5;255m' "🧩 插件商城：Decky、小黄鸭、FSR4、CheatDeck"
    ui_panel_line 16 '\033[1;38;5;255m' "⚙  系统设置：设备信息、网络检测"
    ui_panel_line 17 '\033[1;38;5;255m' "🚀 系统优化：清理、性能建议、一键修复"
    ui_panel_line 18 '\033[1;38;5;114m' "🔄 工具箱更新：Gitee 优先，GitHub 备用"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

show_disclaimer

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init)
            confirm_and_run "一键新机初始化" "安装新机常用项目，部分步骤需要管理员密码" bash "$PROJECT_ROOT/modules/new_machine.sh"
            [ "$NEXT_CATEGORY" = "init" ] && NEXT_CATEGORY="home"
            ;;
        software) common_software_menu ;;
        remote) remote_assistance_menu ;;
        plugins) plugin_store_menu ;;
        settings) system_settings_menu ;;
        optimize) system_optimization_menu ;;
        update)
            confirm_and_run "更新工具箱" "下载、校验并安全替换为最新版本" bash "$PROJECT_ROOT/update.sh"
            [ "$NEXT_CATEGORY" = "update" ] && NEXT_CATEGORY="home"
            ;;
        exit)
            log "用户退出工具箱"
            exit 0
            ;;
        *) NEXT_CATEGORY="home" ;;
    esac
done
