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
    local status
    local title="$1"
    shift

    print_header
    print_section_title "$title"
    echo ""
    "$@"
    status=$?
    cd "$PROJECT_ROOT" 2>/dev/null || cd "$HOME" 2>/dev/null || true
    if [ "$status" -eq 0 ]; then
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
            browser "Chrome 浏览器" \
            back "返回主菜单")" || return 0
        case "$choice" in
            wechat)
                gui_confirm "将优先通过国内Flathub缓存安装微信，并自动创建桌面图标。是否继续？" && \
                    run_gui_action "安装微信" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" wechat
                ;;
            qq)
                gui_confirm "将优先通过国内Flathub缓存安装QQ，并自动创建桌面图标。是否继续？" && \
                    run_gui_action "安装QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" qq
                ;;
            browser)
                gui_confirm "将安装Chrome浏览器并自动创建桌面图标，是否继续？" && \
                    run_gui_action "安装Chrome浏览器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" browser
                ;;
            back) return 0 ;;
        esac
    done
}

remote_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "选择远程协助工具" \
            rustdesk "下载 RustDesk（可在软件内自行配置服务器）" \
            anydesk "下载 AnyDesk（社区维护的 Flathub 包）" \
            todesk "ToDesk" \
            back "返回主菜单")" || return 0
        case "$choice" in
            rustdesk)
                gui_confirm "将以当前用户身份安装 RustDesk，并创建桌面图标；不会写入或修改 RustDesk 服务器配置。是否继续？" && \
                    run_gui_action "下载 RustDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" rustdesk
                ;;
            anydesk)
                gui_confirm "将以当前用户身份安装 AnyDesk 的 Flathub 社区包，并创建桌面图标。是否继续？" && \
                    run_gui_action "下载 AnyDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" anydesk
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

plugin_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "Decky Loader 插件商城" \
            install "安装或更新 Decky Loader" \
            lsfg "小黄鸭（LSFG-VK）" \
            fsr4 "FSR4（Decky Framegen）" \
            cheatdeck "CheatDeck" \
            back "返回主菜单")" || return 0
        case "$choice" in
            install)
                gui_confirm "将运行已校验的 Decky 国内安装器，是否继续？" && \
                    run_gui_action "安装Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" store
                ;;
            lsfg)
                gui_confirm "安装后可打开Steam正版页面，或选择自己合法取得的本地备份，是否继续？" && \
                    run_gui_action "安装小黄鸭" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg
                ;;
            fsr4)
                gui_confirm "将安装FSR4到Decky插件目录，是否继续？" && \
                    run_gui_action "安装FSR4" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4
                ;;
            cheatdeck)
                gui_confirm "将安装CheatDeck到Decky插件目录，是否继续？" && \
                    run_gui_action "安装CheatDeck" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" cheatdeck
                ;;
            back) return 0 ;;
        esac
    done
}

settings_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "系统设置与检测" \
            source "添加国内下载源" \
            accelerator "Steamcommunity 302" \
            set-password "设置系统密码" \
            change-password "修改系统密码" \
            info "查看系统信息" \
            back "返回主菜单")" || return 0
        case "$choice" in
            source)
                gui_confirm "将添加用户级Flathub国内缓存并保留官方备用源；软件安装时会测速并自动优先使用较快来源。是否继续？" && \
                    run_gui_action "添加国内下载源" \
                    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable
                ;;
            accelerator)
                steam_accelerator_gui_menu
                ;;
            set-password)
                gui_confirm "警告：新密码会明文保存到桌面密码.txt；所有以当前用户身份运行的软件都可能读取。确认继续？" && \
                    run_gui_action "设置系统密码" \
                        bash "$PROJECT_ROOT/modules/password.sh" set
                ;;
            change-password)
                gui_confirm "警告：工具箱会读取旧记录并明文保存新密码；所有以当前用户身份运行的软件都可能读取。确认继续？" && \
                    run_gui_action "修改系统密码" \
                        bash "$PROJECT_ROOT/modules/password.sh" change
                ;;
            info) run_gui_action "系统信息" bash "$PROJECT_ROOT/core/detect.sh" --report ;;
            back) return 0 ;;
        esac
    done
}

steam_accelerator_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "Steamcommunity 302" \
            install "安装或更新" \
            status "查看运行状态" \
            uninstall "安全卸载" \
            back "返回系统设置")" || return 0
        case "$choice" in
            install)
                gui_confirm "该工具会使用本机代理，并可能修改hosts/DNS及安装根证书。安装后由你在官方界面选择是否开启后台服务，是否继续？" && \
                    run_gui_action "安装Steamcommunity 302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
                ;;
            status)
                run_gui_action "Steamcommunity 302状态" \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status
                ;;
            uninstall)
                gui_confirm "请先在官方界面禁用后台服务并恢复hosts、DNS和证书。确认继续卸载程序文件？" && \
                    run_gui_action "卸载Steamcommunity 302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
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
            changelog "📋 更新日志" \
            update "🔄 更新工具箱" \
            exit "❌ 退出")" || exit 0

        case "$choice" in
            new-machine)
                gui_confirm "初始化包含ToDesk。开始前请先在游戏模式完成：① Steam键→设置→系统→开启开发者模式；② 设置侧栏→开发者→杂项→开启“使用旧版X11桌面模式”；③ 重新进入桌面模式。确认已完成后，将依次处理国内源、Decky、微信、QQ、Chrome和ToDesk。是否开始？" && \
                    run_gui_action "一键新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/new_machine.sh"
                ;;
            software) software_menu ;;
            remote) remote_menu ;;
            plugins) plugin_menu ;;
            settings) settings_menu ;;
            optimization) optimization_menu ;;
            changelog)
                gui_dialog --textbox "$PROJECT_ROOT/CHANGELOG.md" 900 650
                ;;
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
