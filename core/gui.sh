#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

GUI_TITLE="周克儿工具箱 V4"
GUI_ICON="$PROJECT_ROOT/assets/icon-round.png"
GUI_NAV_HOME=0

# Decky 官方商店插件：保留英文官方名，后面附小白可理解的中文作用。
DECKY_OFFICIAL_PLUGIN_NAMES=(
    "CSS Loader" "vibrantDeck" "Animation Changer" "Audio Loader" "SteamGridDB"
    "PowerTools" "Storage Cleaner" "AutoFlatpaks" "Bluetooth" "ProtonDB Badges"
    "Deck Settings" "HLTB for Deck" "PlayCount" "TabMaster"
    "Wine Cellar" "Pause Games" "Controller Tools" "Volume Mixer" "Battery Tracker"
    "PlayTime" "Free Loader" "DeckMTP" "MangoPeel"
    "Freedeck"
)
DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS=(
    "自定义界面样式" "调整界面配色" "更换开机动画" "更换系统音效" "自动补游戏封面"
    "性能与功耗控制" "清理游戏缓存" "自动更新应用" "管理蓝牙设备" "显示兼容性评分"
    "更多 Deck 设置" "显示通关时长" "记录游玩次数" "整理游戏库标签"
    "管理 Wine 与 Proton" "后台自动暂停游戏" "手柄辅助工具" "分应用调节音量" "查看电池状态"
    "下载游戏和模拟器游戏"
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
        choice="$(gui_dialog --menu "常用软件｜安装聊天、浏览器和远程工具" \
            wechat "微信" \
            qq "QQ" \
            browser "Firefox 浏览器" \
            chrome "Chrome 浏览器" \
            edge "Edge 浏览器" \
            rustdesk "RustDesk 远程协助｜安装开源远程工具" \
            todesk "ToDesk 远程协助｜安装前需完成系统设置" \
            bottles "Windows 软件工具｜安装 Bottles 运行工具" \
            baidunetdisk "百度网盘｜Flathub 安装百度网盘 Linux 版" \
            protontricks "游戏兼容设置｜安装 Protontricks" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            wechat)
                gui_confirm "将从微信Linux版官网下载官方x86_64 AppImage，并自动创建桌面图标。是否继续？" && \
                    run_gui_action "安装微信" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" wechat
                ;;
            qq)
                gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 QQ，不连接腾讯 QQ AppImage 下载地址。是否继续？" && \
                    run_gui_action "安装QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" qq
                ;;
            browser)
                gui_confirm "将通过上海交大与中科大 Flathub 国内缓存安装 Firefox。是否继续？" && \
                    run_gui_action "安装 Firefox 浏览器" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" browser
                ;;
            chrome) gui_confirm "将通过 Flatpak 安装 Google Chrome。是否继续？" && run_gui_action "安装 Google Chrome" bash "$PROJECT_ROOT/modules/software.sh" chrome ;;
            edge) gui_confirm "将通过 Flatpak 安装 Microsoft Edge。是否继续？" && run_gui_action "安装 Microsoft Edge" bash "$PROJECT_ROOT/modules/software.sh" edge ;;
            rustdesk)
                gui_confirm "将从 RustDesk 作者 GitHub Release 下载 AppImage，并创建桌面图标；不会修改服务器配置。是否继续？" && \
                    run_gui_action "安装 RustDesk 远程协助" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" rustdesk
                ;;
            todesk)
                gui_confirm "ToDesk 会使用管理员权限并临时修改 SteamOS 只读系统。请先在游戏模式开启开发者模式和旧版 X11 桌面模式。确认继续？" && \
                    run_gui_action "安装 ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/todesk.sh" --install
                ;;
            baidunetdisk) gui_confirm "将通过 Flatpak 安装百度网盘。是否继续？" && run_gui_action "安装百度网盘" bash "$PROJECT_ROOT/modules/software.sh" baidunetdisk ;;
            protontricks) gui_confirm "将通过 Flatpak 安装 Protontricks。是否继续？" && run_gui_action "安装 Protontricks" bash "$PROJECT_ROOT/modules/software.sh" protontricks ;;
            bottles) gui_confirm "将通过 Flatpak 安装 Bottles。是否继续？" && run_gui_action "安装 Bottles" bash "$PROJECT_ROOT/modules/software.sh" bottles ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

remote_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "选择远程协助工具" \
            rustdesk "下载 RustDesk（作者 GitHub Release）" \
            todesk "ToDesk" \
            back "返回主菜单")" || return 0
        case "$choice" in
            rustdesk)
                gui_confirm "将从 RustDesk 作者 GitHub Release 下载 AppImage，并创建桌面图标；不会写入或修改 RustDesk 服务器配置。是否继续？" && \
                    run_gui_action "下载 RustDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/software.sh" rustdesk
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

game_environment_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "游戏与插件｜插件商城" \
            features "常用插件组合｜安装小黄鸭等三款插件" \
            all "常用插件加27款精选插件｜优先安装三件套，已装则跳过；再补27款精选" \
            browse "浏览官方插件｜逐个查看插件作用" \
            ge-proton "GE 游戏运行组件｜提高 Windows 游戏兼容性" \
            epic "Epic 游戏启动器｜安装并添加到 Steam" \
            decky-install "安装插件商城｜进入系统与密码确认｜高级操作" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            features)
                gui_confirm "未安装插件商城时会先安装插件商城，再继续安装三款插件；会使用管理员权限。是否继续？" && \
                    run_gui_action "安装常用插件组合" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" features
                ;;
            all)
                gui_confirm "未安装插件商城时会先安装插件商城，再继续安装常用与精选插件；会使用管理员权限。是否继续？" && \
                    run_gui_action "安装常用插件加27款精选插件" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" all
                ;;
            browse)
                plugin_official_gui_pages
                [ "$GUI_NAV_HOME" -eq 0 ] || return 0
                ;;
            ge-proton)
                gui_confirm "将安装第三方 GE-Proton 游戏兼容组件。是否继续？" && \
                    run_gui_action "安装 GE 游戏运行组件" \
                    bash "$PROJECT_ROOT/modules/ge_proton.sh" install
                ;;
            epic)
                run_gui_action "安装 Epic 游戏启动器并自动入库" \
                    env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/game_launchers.sh" epic
                ;;
            decky-install) advanced_tools_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
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
            menu_args+=(back "返回游戏与插件")
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            menu_args+=(next "下一页")
        else
            menu_args+=(back-last "返回游戏与插件")
        fi
        menu_args+=(home "返回首页" nav-exit "退出工具箱")

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
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

dual_system_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "双系统与互通盘｜磁盘和开机菜单设置｜高级操作" \
            health "双系统健康检查｜识别 Clover、rEFInd、GRUB、OpenCore 等｜只读" \
            mount "挂载双系统互通盘｜自动排除 Windows 系统分区｜高级操作" \
            tf-format "初始化并挂载 TF 卡｜清空并格式化为 exFAT｜高风险" \
            repair-drive "修复磁盘写入错误｜NTFS/exFAT 基础修复｜高级操作" \
            clover-install "安装或修复 Clover｜SteamOS / Windows｜写入 EFI｜高级操作" \
            protect "双系统互通盘保护｜防止 SteamOS 误写入｜高级操作" \
            windows-shortcut "一键切换 Windows｜创建桌面图标｜仅下一次启动" \
            unprotect "恢复互通盘写入｜重新以可写方式挂载｜高级操作" \
            clover-status "查看 Clover 状态｜检查主题、启动文件和 NVRAM" \
            clover-delete "删除 Clover 双系统引导｜恢复 BootOrder 和原 Clover｜高级操作" \
            cleanup-boot "清理第三方引导项｜保护 SteamOS / Windows｜保留 EFI 文件" \
            windows-next "立即切换 Windows｜设置 BootNext 并重启｜高级操作" \
            back "返回系统与密码" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            health) run_gui_action "双系统健康检查" bash "$PROJECT_ROOT/modules/dual_system_tools.sh" health ;;
            mount)
                gui_confirm "将自动排除 Windows 系统分区，挂载唯一安全的 NTFS/exFAT 互通盘，并创建快捷入口。是否继续？" && \
                    run_gui_action "挂载互通盘" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" mount
                ;;
            tf-format)
                gui_confirm "将永久清空自动识别出的唯一 TF 卡并格式化为 exFAT；随后仍需输入完整设备名确认。是否继续？" && \
                    run_gui_action "初始化并挂载 TF 卡" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" tf-format-mount
                ;;
            repair-drive)
                gui_confirm "将卸载唯一互通盘并运行 NTFS/exFAT 基础修复；严重 NTFS 错误仍需 Windows chkdsk。是否继续？" && \
                    run_gui_action "修复磁盘写入错误" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" repair-drive
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
            clover-install)
                gui_confirm "将备份已有 EFI/CLOVER 和 BootOrder，再安装官方 Clover 5173 与自定义怪盗掌机主题。不会覆盖 BOOTX64.EFI 或 Windows bootmgfw.efi。确认继续？" && \
                    run_gui_action "安装 Clover 开机菜单" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" install
                ;;
            windows-shortcut)
                gui_confirm "将创建一键切换 Windows 桌面图标；使用时仍需确认，且只改变下一次启动目标。是否继续？" && \
                    run_gui_action "创建一键切换 Windows" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" windows-shortcut
                ;;
            clover-status) run_gui_action "Clover 状态" bash "$PROJECT_ROOT/modules/clover_boot.sh" status ;;
            clover-delete)
                gui_confirm "仅删除工具箱创建的 Clover 启动项，并恢复安装前的 BootOrder 和原 Clover 目录。确认继续？" && \
                    run_gui_action "删除 Clover 双系统引导" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clover_boot.sh" delete
                ;;
            cleanup-boot)
                gui_confirm "SteamOS、Windows 和 systemd-boot 受保护；其他第三方项仍需输入 Boot 编号和完整删除口令。是否继续？" && \
                    run_gui_action "清理第三方引导项" \
                    bash "$PROJECT_ROOT/modules/dual_system_tools.sh" cleanup-boot
                ;;
            windows-next)
                run_gui_action "切换到 Windows" bash "$PROJECT_ROOT/modules/dual_system_tools.sh" windows-next
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

network_store_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "网络与应用商店｜检查网络和软件源状态" \
            network-status "网络状态检查｜检查当前网络是否可用" \
            source-status "软件源状态｜查看当前应用下载来源" \
            manage-advanced "管理国内源与加速｜进入高级网络设置｜高级操作" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            network-status) run_gui_action "网络状态检查" bash "$PROJECT_ROOT/modules/network.sh" ;;
            source-status) run_gui_action "软件源状态" bash "$PROJECT_ROOT/modules/domestic_source.sh" status ;;
            manage-advanced) advanced_tools_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

steam_accelerator_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "Steamcommunity 302｜加速 Steam 和 GitHub" \
            install "安装或更新 Steamcommunity 302" \
            start "一键开启 Steam + GitHub 加速" \
            status "查看运行状态" \
            uninstall "安全卸载" \
            back "返回系统与密码" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            install)
                gui_confirm "安装后开启加速会修改网络设置并需要管理员权限。是否继续？" && \
                    run_gui_action "安装Steamcommunity 302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
                ;;
            start)
                gui_confirm "开启加速会修改网络设置并需要管理员权限。是否继续？" && \
                    run_gui_action "开启 Steamcommunity 302 加速" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" enable
                ;;
            status)
                run_gui_action "Steamcommunity 302状态" \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status
                ;;
            uninstall)
                gui_confirm "会停止工具箱启动的进程；官方 systemd、hosts、DNS 和证书需按官方程序另行处理。确认继续？" && \
                    run_gui_action "卸载Steamcommunity 302" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            back) return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

steam_optimization_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "SteamOS 掌机优化" \
            download-cache "清理 Steam 下载缓存" \
            performance "查看性能模式建议" \
            shader-cache "清理着色器缓存" \
            back "返回上一级")" || return 0
        case "$choice" in
            download-cache|shader-cache)
                gui_confirm "该操作会清理对应缓存目录，是否继续？" && \
                    run_gui_action "SteamOS掌机优化" env ZHOUKEER_AUTO_CONFIRM=1 \
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

maintenance_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "系统维护｜清理缓存和检查系统" \
            health "系统健康检查｜检查空间和常用环境" \
            diagnose "游戏启动检查｜检查游戏无法启动原因" \
            download-cache "清理下载残留｜删除未完成下载文件｜会删除缓存" \
            shader-cache "清理着色器缓存｜释放空间并自动重建｜会删除缓存" \
            user-cache "清理用户缓存｜清理可重新生成的缓存｜会删除缓存" \
            performance "查看性能建议｜查看推荐性能设置" \
            fix "常见问题处理｜检测网络并清理下载残留｜会删除缓存" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            health) run_gui_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            diagnose) run_gui_action "游戏启动检查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            download-cache|shader-cache|user-cache)
                gui_confirm "该操作会删除可重新生成的缓存，是否继续？" && \
                    run_gui_action "清理缓存" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/clean.sh" "$choice"
                ;;
            performance) run_gui_action "查看性能建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            fix)
                gui_confirm "将检查网络状态并清理 Steam 未完成的下载残留，是否继续？" && \
                    run_gui_action "常见问题处理" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/fixall.sh"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

help_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "检测与帮助｜查看信息、指南和日志" \
            system-info "查看系统信息｜查看系统和设备信息" \
            report "导出诊断报告｜保存检查结果到桌面" \
            new-guide "新手使用指南｜查看基础操作说明" \
            game-guide "游戏兼容指南｜查看游戏运行建议" \
            shortcuts "掌机常用快捷键｜查看常用按键方法" \
            peripherals "外接设备检查｜检查显示器和蓝牙" \
            records "操作记录｜导出最近工具箱记录" \
            changelog "更新日志｜查看版本改动内容" \
            update "检查并更新工具箱｜下载并安装最新版本｜会联网并更新" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            system-info) run_gui_action "查看系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            report) run_gui_action "导出诊断报告" bash "$PROJECT_ROOT/core/detect.sh" --report ;;
            new-guide) run_gui_action "新手使用指南" bash "$PROJECT_ROOT/modules/safety_center.sh" guide ;;
            game-guide) run_gui_action "游戏兼容指南" bash "$PROJECT_ROOT/modules/game_guides.sh" show ;;
            shortcuts) run_gui_action "掌机常用快捷键" bash "$PROJECT_ROOT/modules/handheld_helper.sh" shortcuts ;;
            peripherals) run_gui_action "外接设备检查" bash "$PROJECT_ROOT/modules/handheld_helper.sh" peripherals ;;
            records) run_gui_action "操作记录" bash "$PROJECT_ROOT/modules/safety_center.sh" records ;;
            changelog) gui_dialog --textbox "$PROJECT_ROOT/CHANGELOG.md" 900 650 ;;
            update)
                gui_confirm "将联网下载经过校验的新版本并替换当前工具箱，是否继续？" && \
                    run_gui_action "检查并更新工具箱" bash "$PROJECT_ROOT/update.sh"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

new_machine_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "新机必备｜第一次使用从这里开始" \
            recommended "推荐软件安装｜选择需要的常用软件" \
            advanced-init "新机初始化｜连续安装并配置新机器" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            recommended) software_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            advanced-init)
                gui_confirm "新机初始化会配置国内软件源，并安装多项常用软件、Decky 和 ToDesk。确认继续？" && \
                    run_gui_action "新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/new_machine.sh"
                ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

support_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "维护与帮助｜系统检查、清理、指南和日志" \
            maintenance "系统维护｜检查系统、清理缓存和处理常见问题" \
            help "检测与使用帮助｜查看信息、指南、记录和更新" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            maintenance) maintenance_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            help) help_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

domestic_source_gui_preflight() {
    local choice

    choice="$(gui_dialog --menu "国内软件源｜国内缓存会关闭 GPG 验证；可恢复官方源" \
        configure "配置国内缓存｜运行 pacman 并临时关闭只读保护｜高风险" \
        restore "恢复官方 Flathub｜重新启用 GPG 验证并移除国内缓存" \
        back "返回系统与密码")" || return 0
    case "$choice" in
        configure)
            gui_confirm "国内软件源会修改 Flatpak 软件源、关闭 GPG 验证、运行 pacman，并临时关闭 SteamOS 只读保护。

远程名称：flathub-cn
地址：https://mirror.sjtu.edu.cn/flathub

备用名称：flathub-ustc
地址：https://mirrors.ustc.edu.cn/flathub

确认信任以上镜像并继续？" && \
                run_gui_action "国内软件源" env ZHOUKEER_AUTO_CONFIRM=1 \
                bash "$PROJECT_ROOT/modules/domestic_source.sh" init
            ;;
        restore)
            gui_confirm "将恢复 https://dl.flathub.org/repo/，重新启用 GPG 验证，并移除两个国内缓存源。确认继续？" && \
                run_gui_action "恢复 Flathub 官方源" env ZHOUKEER_AUTO_CONFIRM=1 \
                bash "$PROJECT_ROOT/modules/domestic_source.sh" restore
            ;;
    esac
}

advanced_tools_gui_menu() {
    local choice

    while true; do
        choice="$(gui_dialog --menu "系统与密码｜以下功能会修改系统、网络、软件源、密码或磁盘设置。请确认了解风险后继续。" \
            domestic-source "国内软件源｜会修改 Flatpak 软件源｜高级操作" \
            accelerator "Steamcommunity 302｜可能修改 DNS 和证书｜高级操作" \
            set-password "设置管理员密码｜会修改 SteamOS 管理密码｜高级操作" \
            change-password "修改管理员密码｜会更换 SteamOS 管理密码｜高级操作" \
            decky-install "安装插件商城｜会使用管理员权限｜高级操作" \
            dual "双系统与互通盘｜管理磁盘和开机菜单｜高级操作" \
            home "返回首页" \
            nav-exit "退出工具箱")" || return 0
        case "$choice" in
            domestic-source) domestic_source_gui_preflight ;;
            accelerator) steam_accelerator_gui_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            set-password)
                gui_confirm "新密码会明文保存到桌面管理员密码.txt；当前用户运行的软件都可能读取。确认继续？" && \
                    run_gui_action "设置管理员密码" bash "$PROJECT_ROOT/modules/password.sh" set
                ;;
            change-password)
                gui_confirm "将读取旧记录并明文保存新密码；当前用户运行的软件都可能读取。确认继续？" && \
                    run_gui_action "修改管理员密码" bash "$PROJECT_ROOT/modules/password.sh" change
                ;;
            decky-install)
                gui_confirm "请先在游戏模式开启开发者模式和 CEF 远程调试。安装会使用管理员权限并启动后台服务，是否继续？" && \
                    run_gui_action "安装插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
                    bash "$PROJECT_ROOT/modules/plugin_store.sh" store
                ;;
            dual) dual_system_menu; [ "$GUI_NAV_HOME" -eq 0 ] || return 0 ;;
            home) GUI_NAV_HOME=1; return 0 ;;
            nav-exit) exit 0 ;;
        esac
    done
}

main_gui_menu() {
    local choice

    while true; do
        GUI_NAV_HOME=0
        choice="$(gui_dialog --menu "请用触屏或触控板选择功能" \
            nav-init "新机必备｜第一次使用从这里开始" \
            nav-software "常用软件｜安装聊天、浏览器和远程工具" \
            nav-games "游戏与插件｜浏览插件商城和游戏组件" \
            nav-network "网络与应用商店｜检查网络和软件源状态" \
            nav-help "维护与帮助｜系统检查、清理、指南和日志" \
            nav-advanced "系统与密码｜设置密码和管理系统功能" \
            nav-exit "退出工具箱")" || exit 0

        case "$choice" in
            nav-init) new_machine_gui_menu ;;
            nav-software) software_menu ;;
            nav-games) game_environment_gui_menu ;;
            nav-network) network_store_gui_menu ;;
            nav-help) support_gui_menu ;;
            nav-advanced) advanced_tools_gui_menu ;;
            nav-exit) exit 0 ;;
        esac
    done
}

ensure_gui_password_ready() {
    local choice

    if load_toolbox_password >/dev/null 2>&1; then
        TOOLBOX_PASSWORD=""
        unset TOOLBOX_PASSWORD
        return 0
    fi

    while true; do
        choice="$(gui_dialog --menu "首次使用必须先准备管理员密码记录，但不会强制修改已有密码。" \
            import "我已有管理员密码｜输入一次并保存到桌面" \
            set "我还没有管理员密码｜按系统提示设置新密码" \
            exit "退出工具箱")" || exit 0
        case "$choice" in
            import) run_gui_action "录入现有管理员密码" bash "$PROJECT_ROOT/modules/password.sh" import ;;
            set) run_gui_action "设置管理员密码" bash "$PROJECT_ROOT/modules/password.sh" set ;;
            exit) exit 0 ;;
        esac
        if load_toolbox_password >/dev/null 2>&1; then
            TOOLBOX_PASSWORD=""
            unset TOOLBOX_PASSWORD
            return 0
        fi
    done
}

if ! command -v kdialog >/dev/null 2>&1; then
    echo "未找到 kdialog，无法启动图形菜单。"
    exit 1
fi

ensure_gui_password_ready
main_gui_menu
