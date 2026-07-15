#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

GUI_TITLE="周克儿工具箱 V4"
GUI_ICON="$PROJECT_ROOT/assets/icon-round.png"

# Decky 官方商店插件：保留英文官方名，后面附小白可理解的中文作用。
DECKY_OFFICIAL_PLUGIN_NAMES=(
    "CSS Loader" "vibrantDeck" "Animation Changer" "Audio Loader" "SteamGridDB"
    "PowerTools" "Storage Cleaner" "AutoFlatpaks" "Bluetooth" "ProtonDB Badges"
    "Deck Settings" "HLTB for Deck" "PlayCount" "TabMaster" "Game Theme Music"
    "Wine Cellar" "Pause Games" "Controller Tools" "Volume Mixer" "Battery Tracker"
    "PlayTime" "Free Loader" "DeckMTP" "MangoPeel"
)
DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS=(
    "自定义界面样式" "调整界面配色" "更换开机动画" "更换系统音效" "自动补游戏封面"
    "性能与功耗控制" "清理游戏缓存" "自动更新应用" "管理蓝牙设备" "显示兼容性评分"
    "更多 Deck 设置" "显示通关时长" "记录游玩次数" "整理游戏库标签" "播放游戏主题音乐"
    "管理 Wine 与 Proton" "后台自动暂停游戏" "手柄辅助工具" "分应用调节音量" "查看电池状态"
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
            browser "Firefox 浏览器" \
            ge-proton "GE-Proton 兼容层" \
            back "返回主菜单")" || return 0
        case "$choice" in
            wechat)
                gui_confirm "将从微信Linux版官网下载官方x86_64 AppImage，并自动创建桌面图标。是否继续？" && \
                    run_gui_action "安装微信" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" wechat
                ;;
            qq)
                gui_confirm "将从腾讯QQ官网国内CDN下载官方AppImage，并自动创建桌面图标。是否继续？" && \
                    run_gui_action "安装QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" qq
                ;;
            browser)
                gui_confirm "将从123云盘国内直链下载Firefox Linux x86_64中文完整包并安装到工具箱目录，不依赖Flatpak。是否继续？" && \
                    run_gui_action "安装Firefox浏览器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" browser
                ;;
            ge-proton)
                gui_confirm "将把GE-Proton安装到Steam兼容工具目录；完成后需要完全重启Steam。是否继续？" && \
                    run_gui_action "安装GE-Proton兼容层" \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install
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

    gui_notice "插件商城使用前设置：
① 回到游戏模式，按 Steam 键 → 设置 → 系统；
② 开启“启用开发者模式”；
③ 在设置侧栏进入“开发者”菜单；
④ 开启“CEF 远程调试”；
⑤ 再回到桌面模式使用本商城。

这两项设置是 Decky 官方插件安装所需的前置条件。"

    while true; do
        choice="$(gui_dialog --menu "Decky Loader 插件商城" \
            install "安装或更新 Decky Loader" \
            features "一键安装常用功能插件（小黄鸭、FSR4、CheatDeck）" \
            all "一键安装当前列表全部插件（共29款）" \
            browse "浏览官方插件（分页｜中文说明）" \
            localizer "安装周克儿汉化（测试版）" \
            back "返回主菜单")" || return 0
        case "$choice" in
            install)
                gui_confirm "安装前请先回到游戏模式：① Steam键→设置→系统→开启“启用开发者模式”；② 设置侧栏→开发者→开启“CEF远程调试”。完成后再回桌面模式继续。将运行已校验的 Decky 国内安装器，是否继续？" && \
                    run_gui_action "安装Decky Loader" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" store
                ;;
            features)
                gui_confirm "安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将依次安装小黄鸭、FSR4 和 CheatDeck；单项失败不会覆盖旧版本。是否继续？" && \
                    run_gui_action "安装常用功能插件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" features
                ;;
            all)
                gui_confirm "安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将安装 Decky、3款独立功能插件和26款精选插件，其中包括 SimpleDeckyTDP 与 Unifideck；商店插件仍需在Steam界面确认。是否继续？" && \
                    run_gui_action "安装当前列表全部插件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" all
                ;;
            browse)
                plugin_official_gui_pages
                ;;
            localizer)
                gui_confirm "这是独立的 Decky 汉化层测试版：不会改写原插件文件，首批仅覆盖基础文案。安装后请回游戏模式，在 Decky 菜单中启用。是否继续？" && \
                    run_gui_action "安装周克儿汉化" bash "$PROJECT_ROOT/modules/plugin_store.sh" localizer
                ;;
            back) return 0 ;;
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

    while true; do
        start=$((page * page_size))
        end=$((start + page_size))
        [ "$end" -le "$total" ] || end="$total"
        menu_args=(--menu "官方插件（第 $((page + 1)) / $total_pages 页）")
        for ((index = start; index < end; index++)); do
            menu_args+=("plugin-$index" "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}｜${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}")
        done
        if [ "$page" -gt 0 ]; then
            menu_args+=(previous "上一页")
        else
            menu_args+=(back "返回插件商城")
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            menu_args+=(next "下一页")
        else
            menu_args+=(back-last "返回插件商城")
        fi

        choice="$(gui_dialog "${menu_args[@]}")" || return 0
        case "$choice" in
            plugin-*)
                index="${choice#plugin-}"
                gui_confirm "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}：${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}。安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将由 Decky 官方商店安装，是否继续？" && \
                    run_gui_action "安装 ${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/decky_bundle.sh" plugin "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}"
                ;;
            previous) page=$((page - 1)) ;;
            next) page=$((page + 1)) ;;
            back|back-last) return 0 ;;
        esac
    done
}

dual_system_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "双系统设置" \
            mount "一键挂载互通盘" \
            protect "保护双系统互通盘（只读）" \
            unprotect "恢复互通盘写入" \
            add "添加 Steam Deck 双引导" \
            remove "删除 Steam Deck 双引导（等待时间设为 0）" \
            back "返回主菜单")" || return 0
        case "$choice" in
            mount)
                gui_confirm "将自动挂载唯一的未挂载 NTFS/exFAT 分区，并创建互通盘快捷入口。是否继续？" && \
                    run_gui_action "挂载互通盘" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" mount
                ;;
            protect)
                gui_confirm "将重新以只读模式挂载互通盘，SteamOS 下无法写入或删除该盘文件。是否继续？" && \
                    run_gui_action "保护双系统互通盘" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" protect
                ;;
            unprotect)
                gui_confirm "将重新以可写模式挂载互通盘，恢复 SteamOS 下的正常读写。是否继续？" && \
                    run_gui_action "恢复互通盘写入" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" unprotect
                ;;
            add)
                gui_confirm "将启用已有的 systemd-boot 菜单并备份配置，不会安装或重写 EFI 引导程序。是否继续？" && \
                    run_gui_action "添加 Steam Deck 双引导" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" add
                ;;
            remove)
                gui_confirm "将把 systemd-boot 菜单等待时间设为 0 秒；不会删除 SteamOS、Windows 或 EFI 启动项。是否继续？" && \
                    run_gui_action "删除 Steam Deck 双引导" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" remove
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
                gui_confirm "将添加上海交大和中科大两个用户级Flathub缓存；软件安装只在两个国内缓存间测速切换，其他来源保持不变。是否继续？" && \
                    run_gui_action "添加国内下载源" \
                    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable
                ;;
            accelerator)
                steam_accelerator_gui_menu
                ;;
            set-password)
                gui_confirm "警告：新密码会明文保存到桌面管理员密码.txt；所有以当前用户身份运行的软件都可能读取。确认继续？" && \
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
            plugins "🧩 插件商城（29款插件）" \
            settings "⚙️ 系统设置" \
            dual "💿 双系统设置" \
            optimization "🛠 系统优化" \
            changelog "📋 更新日志" \
            update "🔄 更新工具箱" \
            exit "❌ 退出")" || exit 0

        case "$choice" in
            new-machine)
                gui_confirm "初始化包含ToDesk。开始前请先在游戏模式完成：① Steam键→设置→系统→开启开发者模式；② 设置侧栏→开发者→杂项→开启“使用旧版X11桌面模式”；③ 重新进入桌面模式。确认已完成后，将依次处理国内源、Decky、微信、QQ、Firefox和ToDesk。是否开始？" && \
                    run_gui_action "一键新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/new_machine.sh"
                ;;
            software) software_menu ;;
            remote) remote_menu ;;
            plugins) plugin_menu ;;
            settings) settings_menu ;;
            dual) dual_system_menu ;;
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
