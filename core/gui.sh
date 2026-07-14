#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

GUI_TITLE="周克儿工具箱 V4"
GUI_ICON="$PROJECT_ROOT/assets/icon.png"

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
    local title="$1"
    shift

    print_header
    print_section_title "$title"
    echo ""
    if "$@"; then
        gui_notice "$title 已完成。"
    else
        gui_dialog --error "$title 未完成，请查看终端中的提示。"
    fi
}

software_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "选择要安装的软件" \
            wechat "微信" \
            qq "QQ" \
            protonup "ProtonUp-Qt 兼容层管理器" \
            back "返回主菜单")" || return 0
        case "$choice" in
            wechat)
                gui_confirm "将通过 Flathub 安装微信，是否继续？" && \
                    run_gui_action "安装微信" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" wechat
                ;;
            qq)
                gui_confirm "将通过 Flathub 安装 QQ，是否继续？" && \
                    run_gui_action "安装QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" qq
                ;;
            protonup)
                gui_confirm "将安装 ProtonUp-Qt 兼容层管理器，是否继续？" && \
                    run_gui_action "安装ProtonUp-Qt" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" protonup
                ;;
            back) return 0 ;;
        esac
    done
}

remote_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "选择远程协助工具" \
            todesk "ToDesk" \
            rustdesk-install "安装或更新 RustDesk" \
            rustdesk-config "查看 RustDesk 服务器配置" \
            back "返回主菜单")" || return 0
        case "$choice" in
            todesk)
                gui_confirm "ToDesk 将请求管理员密码并临时关闭 SteamOS 只读保护，完成后会恢复。是否继续？" && \
                    run_gui_action "安装ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --install
                ;;
            rustdesk-install)
                gui_confirm "将下载并校验 RustDesk 1.4.8，是否继续？" && \
                    run_gui_action "安装RustDesk" \
                    bash "$PROJECT_ROOT/modules/rustdesk.sh" --install
                ;;
            rustdesk-config)
                run_gui_action "RustDesk服务器配置" \
                    bash "$PROJECT_ROOT/modules/rustdesk.sh" --config
                ;;
            back) return 0 ;;
        esac
    done
}

plugin_menu() {
    local choice

    choice="$(gui_dialog --menu "Decky Loader 插件商城" \
        install "安装或更新 Decky Loader" \
        back "返回主菜单")" || return 0
    if [ "$choice" = "install" ] && \
        gui_confirm "将运行已校验的 Decky 官方安装器，是否继续？"; then
        run_gui_action "安装Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
            bash "$PROJECT_ROOT/modules/plugin_store.sh"
    fi
}

settings_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "系统设置与检测" \
            info "查看系统信息" \
            network "网络检测与修复" \
            back "返回主菜单")" || return 0
        case "$choice" in
            info) run_gui_action "系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            network) run_gui_action "网络检测与修复" bash "$PROJECT_ROOT/modules/network.sh" ;;
            back) return 0 ;;
        esac
    done
}

steam_optimization_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "Steam Deck 优化" \
            download-cache "清理 Steam 下载缓存" \
            performance "查看性能模式建议" \
            shader-cache "清理着色器缓存" \
            back "返回上一级")" || return 0
        case "$choice" in
            download-cache|shader-cache)
                gui_confirm "该操作会清理对应缓存目录，是否继续？" && \
                    run_gui_action "Steam Deck优化" env ZHOUKEER_AUTO_CONFIRM=1 \
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

optimization_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "系统优化与维护" \
            steam "Steam Deck 优化" \
            cleanup "系统清理" \
            fixall "一键修复模式" \
            back "返回主菜单")" || return 0
        case "$choice" in
            steam) steam_optimization_menu ;;
            cleanup) cleanup_menu ;;
            fixall)
                gui_confirm "一键修复会检测网络并清理 Steam 下载缓存，是否继续？" && \
                    run_gui_action "一键修复模式" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/fixall.sh"
                ;;
            back) return 0 ;;
        esac
    done
}

main_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "请用触屏或触控板选择功能" \
            new-machine "⭐ 一键新机初始化" \
            software "📦 常用软件" \
            remote "🖥 远程协助" \
            plugins "🧩 插件商城" \
            settings "⚙️ 系统设置" \
            optimization "🛠 系统优化" \
            update "🔄 更新工具箱" \
            exit "❌ 退出")" || exit 0

        case "$choice" in
            new-machine)
                gui_confirm "将依次处理网络检测、Decky、微信、QQ、ToDesk 和 ProtonUp-Qt。过程中可能需要管理员密码。是否开始？" && \
                    run_gui_action "一键新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/new_machine.sh"
                ;;
            software) software_menu ;;
            remote) remote_menu ;;
            plugins) plugin_menu ;;
            settings) settings_menu ;;
            optimization) optimization_menu ;;
            update)
                gui_confirm "将下载经过 SHA256 校验的新版本，是否继续？" && \
                    run_gui_action "更新工具箱" bash "$PROJECT_ROOT/update.sh"
                ;;
            exit) exit 0 ;;
        esac
    done
}

if ! command -v kdialog >/dev/null 2>&1; then
    echo "未找到 kdialog，无法启动图形菜单。"
    exit 1
fi

main_gui_menu
