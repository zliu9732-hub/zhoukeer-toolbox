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

TOUCH_MODE=0
case "${1:-}" in
    --touch) TOUCH_MODE=1 ;;
    --gui)
    exec bash "$PROJECT_ROOT/core/gui.sh"
        ;;
    --text|"") ;;
    *) echo "未知参数: $1"; exit 1 ;;
esac

if [ "$TOUCH_MODE" -eq 1 ]; then
    enable_mouse_tracking
    trap 'disable_mouse_tracking' EXIT INT TERM
fi

pause_menu() {
    echo ""
    if [ "$TOUCH_MODE" -eq 1 ]; then
        echo "点击窗口任意位置返回菜单"
        read_ui_event || true
    else
        read -r -p "回车继续"
    fi
}

run_action() {
    local status
    local title="$1"
    shift

    [ "$TOUCH_MODE" -eq 0 ] || disable_mouse_tracking
    print_header
    print_section_title "$title"
    echo ""
    "$@"
    status=$?

    # 自更新会原子替换整个安装目录；父菜单必须主动进入新目录，避免getcwd指向已删除目录。
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
    [ "$TOUCH_MODE" -eq 0 ] || enable_mouse_tracking
    pause_menu
}

confirm_and_run() {
    local title="$1"
    local message="$2"
    local choice
    shift 2

    if [ "$TOUCH_MODE" -eq 0 ]; then
        run_action "$title" "$@"
        return
    fi

    draw_category_frame "" "$title" "$message"
    ui_panel_line 11 '\033[1;30;48;5;114m' "  ✓ 点击继续  "
    ui_panel_line 14 '\033[1;97;48;5;160m' "  ✗ 取消  "
    ui_prompt
    choice="$(read_menu_choice right:11:yes right:14:no)"
    if [ "$choice" = "yes" ]; then
        run_action "$title" env ZHOUKEER_AUTO_CONFIRM=1 "$@"
    fi
}

common_software_menu() {
    local choice

    while true; do
        draw_category_frame B "常用软件" "常用桌面应用与游戏兼容层管理工具"
        ui_panel_line 9 '\033[97m' "1. 微信"
        ui_panel_line 11 '\033[97m' "2. QQ"
        ui_panel_line 13 '\033[97m' "3. ProtonUp-Qt 兼容层管理器"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        if [ "$TOUCH_MODE" -eq 1 ]; then
            choice="$(read_menu_choice right:9:1 right:11:2 right:13:3 right:16:0)"
        else
            read -r choice
        fi

        case "$choice" in
            1) confirm_and_run "安装微信" "国内缓存优先；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            2) confirm_and_run "安装QQ" "国内缓存优先；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            3) confirm_and_run "安装ProtonUp-Qt" "安装完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" protonup ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame C "远程协助" "安装远程协助工具，便于售后和故障处理"
        ui_panel_line 9 '\033[97m' "1. ToDesk"
        ui_panel_line 11 '\033[97m' "2. RustDesk（已配置自建服务器）"
        ui_panel_line 13 '\033[97m' "3. 查看RustDesk服务器配置"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        if [ "$TOUCH_MODE" -eq 1 ]; then
            choice="$(read_menu_choice right:9:1 right:11:2 right:13:3 right:16:0)"
        else
            read -r choice
        fi

        case "$choice" in
            1) confirm_and_run "ToDesk远程工具" "安装时仍需输入Steam Deck管理员密码" bash "$PROJECT_ROOT/modules/todesk.sh" --install ;;
            2) confirm_and_run "RustDesk远程工具" "下载、校验并安装RustDesk 1.4.8" bash "$PROJECT_ROOT/modules/rustdesk.sh" --install ;;
            3) run_action "RustDesk服务器配置" bash "$PROJECT_ROOT/modules/rustdesk.sh" --config ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

steam_touch_menu() {
    local choice

    while true; do
        draw_category_frame F "Steam Deck优化" "选择需要执行的单项优化"
        ui_panel_line 9 '\033[97m' "1. 清理Steam下载缓存"
        ui_panel_line 11 '\033[97m' "2. 查看性能模式建议"
        ui_panel_line 13 '\033[97m' "3. 清理着色器缓存"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回上一级"
        ui_prompt
        choice="$(read_menu_choice right:9:1 right:11:2 right:13:3 right:16:0)"

        case "$choice" in
            1) confirm_and_run "清理下载缓存" "清理后未完成的Steam下载需要重新开始" bash "$PROJECT_ROOT/modules/steam.sh" download-cache ;;
            2) run_action "性能模式建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            3) confirm_and_run "清理着色器缓存" "清理后游戏着色器需要重新生成" bash "$PROJECT_ROOT/modules/steam.sh" shader-cache ;;
            0) return 0 ;;
        esac
    done
}

clean_touch_menu() {
    local choice

    while true; do
        draw_category_frame F "系统清理" "所有清理操作执行前都会再次确认"
        ui_panel_line 9 '\033[97m' "1. 清理Steam下载残留"
        ui_panel_line 11 '\033[97m' "2. 清理Steam着色器缓存"
        ui_panel_line 13 '\033[97m' "3. 清理Linux用户缓存"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回上一级"
        ui_prompt
        choice="$(read_menu_choice right:9:1 right:11:2 right:13:3 right:16:0)"

        case "$choice" in
            1) confirm_and_run "清理下载残留" "将删除Steam未完成的下载残留" bash "$PROJECT_ROOT/modules/clean.sh" download-cache ;;
            2) confirm_and_run "清理着色器缓存" "着色器会在下次运行游戏时重新生成" bash "$PROJECT_ROOT/modules/clean.sh" shader-cache ;;
            3) confirm_and_run "清理用户缓存" "部分应用会在下次启动时重新生成缓存" bash "$PROJECT_ROOT/modules/clean.sh" user-cache ;;
            0) return 0 ;;
        esac
    done
}

plugin_store_menu() {
    local choice

    while true; do
        draw_category_frame D "插件商城" "管理 Steam Deck 的 Decky Loader 插件环境"
        ui_panel_line 9 '\033[97m' "1. 安装或更新 Decky Loader"
        ui_panel_line 12 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        if [ "$TOUCH_MODE" -eq 1 ]; then
            choice="$(read_menu_choice right:9:1 right:12:0)"
        else
            read -r choice
        fi

        case "$choice" in
            1) confirm_and_run "Decky Loader插件商城" "执行经过校验的Decky官方安装器" bash "$PROJECT_ROOT/modules/plugin_store.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

system_settings_menu() {
    local choice

    while true; do
        draw_category_frame E "系统设置" "查看设备状态并处理基础网络问题"
        ui_panel_line 9 '\033[97m' "1. 查看系统信息"
        ui_panel_line 11 '\033[97m' "2. 网络检测与修复"
        ui_panel_line 14 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        if [ "$TOUCH_MODE" -eq 1 ]; then
            choice="$(read_menu_choice right:9:1 right:11:2 right:14:0)"
        else
            read -r choice
        fi

        case "$choice" in
            1) run_action "系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            2) run_action "网络检测与修复" bash "$PROJECT_ROOT/modules/network.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

system_optimization_menu() {
    local choice

    while true; do
        draw_category_frame F "系统优化" "缓存清理、性能建议与常见问题修复"
        ui_panel_line 9 '\033[97m' "1. Steam Deck优化"
        ui_panel_line 11 '\033[97m' "2. 系统清理"
        ui_panel_line 13 '\033[97m' "3. 一键修复模式"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        if [ "$TOUCH_MODE" -eq 1 ]; then
            choice="$(read_menu_choice right:9:1 right:11:2 right:13:3 right:16:0)"
        else
            read -r choice
        fi

        case "$choice" in
            1)
                if [ "$TOUCH_MODE" -eq 1 ]; then
                    steam_touch_menu
                else
                    run_action "Steam Deck优化" bash "$PROJECT_ROOT/modules/steam.sh"
                fi
                ;;
            2)
                if [ "$TOUCH_MODE" -eq 1 ]; then
                    clean_touch_menu
                else
                    run_action "系统清理" bash "$PROJECT_ROOT/modules/clean.sh"
                fi
                ;;
            3) confirm_and_run "一键修复模式" "检测网络并安全清理Steam下载缓存" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

while true; do
    draw_category_frame "" "欢迎使用" "输入左侧字母进入对应分类"
    ui_panel_line 9 '\033[1;38;5;220m' "⭐ A：第一次使用推荐运行新机初始化"
    ui_panel_line 11 '\033[38;5;250m' "B：微信、QQ、ProtonUp-Qt"
    ui_panel_line 12 '\033[38;5;250m' "C：ToDesk、RustDesk"
    ui_panel_line 13 '\033[38;5;250m' "D：Decky Loader 插件商城"
    ui_panel_line 14 '\033[38;5;250m' "E：系统信息、网络检测"
    ui_panel_line 15 '\033[38;5;250m' "F：优化、清理、一键修复"
    ui_panel_line 17 '\033[38;5;114m' "G：检查并更新周克儿工具箱"
    ui_prompt
    if [ "$TOUCH_MODE" -eq 1 ]; then
        num="$(read_menu_choice \
            left:3:A left:5:B left:7:C left:9:D \
            left:11:E left:13:F left:15:G left:20:X)"
    else
        read -r num
    fi

    case "$num" in
        A|a|1) confirm_and_run "一键新机初始化" "安装新机常用项目，部分步骤需要管理员密码" bash "$PROJECT_ROOT/modules/new_machine.sh" ;;
        B|b|2) common_software_menu ;;
        C|c|3) remote_assistance_menu ;;
        D|d|4) plugin_store_menu ;;
        E|e|5) system_settings_menu ;;
        F|f|6) system_optimization_menu ;;
        G|g|7) confirm_and_run "更新工具箱" "下载并校验最新发布包" bash "$PROJECT_ROOT/update.sh" ;;
        X|x|0)
            log "用户退出工具箱"
            exit 0
            ;;
        *)
            echo "输入错误"
            pause_menu
            ;;
    esac
done
