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
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

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

# Decky 官方插件的中文短说明。触控界面每页仅显示 5 个，避免小屏幕按钮拥挤。
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
DECKY_TOUCH_PAGE_SIZE=5

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
    sleep 0.05
    ui_discard_pending_input
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
    ui_panel_line 8 '\033[1;38;5;220m' "请确认是否继续这项操作"
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
        ui_disclaimer_line 8 '\033[1;38;5;220m' "本脚本由 闲鱼：超级妹宝双叶 制作"
        ui_disclaimer_line 9 '\033[38;5;45m' "支持免费使用；禁止商业、销售、转卖或借此盈利"
        ui_disclaimer_line 10 '\033[38;5;45m' "下载内容均来自官方免费发布或开源项目"
        ui_disclaimer_line 11 '\033[38;5;45m' "不包含付费软件本体、破解或商业授权"
        ui_disclaimer_line 12 '\033[38;5;220m' "第三方软件与插件均从作者或官方发布页获取"
        ui_disclaimer_line 13 '\033[1;38;5;114m' "欢迎支持作者；若有侵权请及时联系删除"
        ui_disclaimer_button 15 '\033[1;38;5;114m' "知悉并开始使用" "点击即表示已阅读上述说明"
        ui_disclaimer_button 18 '\033[1;38;5;203m' "退出工具箱" "暂不使用"
        choice="$(read_menu_choice any:15-16:agree any:18-19:exit)"
        case "$choice" in
            agree)
                if [ "${ZHOUKEER_STARTUP_SPLASH:-0}" = "1" ]; then
                    disable_mouse_tracking
                    exec bash "$PROJECT_ROOT/launch.sh" --open-main
                    echo "无法切换到工具箱主界面。"
                    return 1
                fi
                return 0
                ;;
            exit) exit 0 ;;
        esac
    done
}

ensure_password_ready() {
    local choice

    if load_toolbox_password >/dev/null 2>&1; then
        TOOLBOX_PASSWORD=""
        unset TOOLBOX_PASSWORD
        return 0
    fi

    while true; do
        draw_category_frame "" "首次使用准备" "先准备管理员密码记录，后续安装无需反复输入"
        ui_panel_line 7 '\033[1;38;5;220m' "首次使用必须完成此步骤，但不会强制修改已有密码"
        ui_touch_button 10 '\033[1;97;48;5;24m' "我已有管理员密码" "输入一次并保存到桌面，不修改密码"
        ui_touch_button 15 '\033[1;97;48;5;58m' "我还没有管理员密码" "按系统提示设置新密码"
        ui_touch_button 20 '\033[1;97;48;5;160m' "退出工具箱" "暂不进行任何操作"
        ui_prompt
        choice="$(read_touch_menu right:10-11:import right:15-16:set right:20-21:exit)"
        case "$choice" in
            import)
                run_action "录入现有管理员密码" \
                    bash "$PROJECT_ROOT/modules/password.sh" import
                ;;
            set)
                run_action "设置管理员密码" \
                    bash "$PROJECT_ROOT/modules/password.sh" set
                ;;
            exit) exit 0 ;;
        esac
        if load_toolbox_password >/dev/null 2>&1; then
            TOOLBOX_PASSWORD=""
            unset TOOLBOX_PASSWORD
            return 0
        fi
    done
}

read_touch_menu() {
    read_menu_choice \
        left:2-3:nav-init \
        left:5-6:nav-software \
        left:8-9:nav-games \
        left:11-12:nav-network \
        left:14-15:nav-help \
        left:18-19:nav-advanced \
        left:22-23:nav-exit \
        "$@"
}

apply_navigation() {
    case "$1" in
        nav-init) NEXT_CATEGORY="init" ;;
        nav-software) NEXT_CATEGORY="software" ;;
        nav-games) NEXT_CATEGORY="games" ;;
        nav-network) NEXT_CATEGORY="network" ;;
        nav-maintenance|nav-help) NEXT_CATEGORY="support" ;;
        nav-advanced) NEXT_CATEGORY="advanced" ;;
        # 旧导航 ID 仅保留兼容，不再显示在首页。
        nav-remote) NEXT_CATEGORY="software" ;;
        nav-plugins) NEXT_CATEGORY="games" ;;
        nav-settings) NEXT_CATEGORY="network" ;;
        nav-optimize|nav-guides|nav-changelog|nav-update) NEXT_CATEGORY="support" ;;
        nav-dual) NEXT_CATEGORY="advanced" ;;
        nav-exit) NEXT_CATEGORY="exit" ;;
        *) return 1 ;;
    esac
    return 0
}

common_software_menu() {
    local choice

    while true; do
        draw_category_frame software "" "" 0
        ui_touch_button 2 '\033[1;97;48;5;24m' "微信"
        ui_touch_button 4 '\033[1;97;48;5;24m' "QQ"
        ui_touch_button 6 '\033[1;97;48;5;24m' "Firefox 浏览器"
        ui_touch_button 8 '\033[1;97;48;5;24m' "Chrome 浏览器"
        ui_touch_button 10 '\033[1;97;48;5;24m' "Edge 浏览器"
        ui_touch_button 12 '\033[1;97;48;5;24m' "RustDesk 远程协助" "安装开源远程工具"
        ui_touch_button 14 '\033[1;97;48;5;24m' "ToDesk 远程协助" "安装前需完成系统设置"
        ui_touch_button 16 '\033[1;97;48;5;24m' "Windows 软件工具" "安装 Bottles 运行工具"
        ui_touch_button 18 '\033[1;97;48;5;24m' "游戏兼容设置" "安装 Protontricks"
        ui_touch_button 20 '\033[1;97;48;5;24m' "百度网盘" "Flathub 安装百度网盘 Linux 版"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:2-3:wechat right:4-5:qq right:6-7:browser right:8-9:chrome right:10-11:edge right:12-13:rustdesk right:14-15:todesk right:16-17:bottles right:18-19:protontricks right:20-21:baidunetdisk right:22-23:home)"
        case "$choice" in
            nav-*) apply_navigation "$choice"; return 0 ;;
        esac

        case "$choice" in
            wechat) confirm_and_run "安装微信" "腾讯官网AppImage；失败时保留原有版本" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            qq) confirm_and_run "安装QQ" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            browser) confirm_and_run "安装 Firefox 浏览器" "通过上海交大与中科大 Flathub 国内缓存安装" bash "$PROJECT_ROOT/modules/software.sh" browser ;;
            chrome) confirm_and_run "安装 Google Chrome" "Flathub 安装，通过国内镜像加速" bash "$PROJECT_ROOT/modules/software.sh" chrome ;;
            edge) confirm_and_run "安装 Microsoft Edge" "Flathub 安装，通过国内镜像加速" bash "$PROJECT_ROOT/modules/software.sh" edge ;;
            rustdesk) confirm_and_run "安装 RustDesk 远程协助" "从作者 GitHub Release 安装，不会修改服务器配置" bash "$PROJECT_ROOT/modules/software.sh" rustdesk ;;
            todesk) todesk_preflight software ;;
            protontricks) confirm_and_run "安装 Protontricks" "修复与配置 Steam 游戏 Proton 环境" bash "$PROJECT_ROOT/modules/software.sh" protontricks ;;
            bottles) confirm_and_run "安装 Bottles" "独立运行第三方 Windows 应用与游戏" bash "$PROJECT_ROOT/modules/software.sh" bottles ;;
            baidunetdisk) confirm_and_run "安装百度网盘" "Flathub 安装百度网盘 Linux 版，通过国内镜像加速" bash "$PROJECT_ROOT/modules/software.sh" baidunetdisk ;;

            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "software" ] || return 0
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame remote "远程协助" "安装完成后会自动在桌面创建启动图标"
        ui_touch_button 7 '\033[1;97;48;5;24m' "下载 RustDesk" "作者 GitHub Release；无需系统权限"
        ui_touch_button 11 '\033[1;97;48;5;24m' "查看设置步骤并安装 ToDesk" "需先开启开发者模式和旧版 X11 桌面模式"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:rustdesk right:11-12:todesk right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            rustdesk) confirm_and_run "下载 RustDesk" "从作者 GitHub Release 安装，不会写入或修改你的 RustDesk 服务器配置" bash "$PROJECT_ROOT/modules/software.sh" rustdesk ;;
            todesk) todesk_preflight remote ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "remote" ] || return 0
    done
}

todesk_preflight() {
    local choice
    local return_target="${1:-software}"
    local return_label="返回常用软件"

    [ "$return_target" != "remote" ] || return_label="返回远程协助"

    while true; do
        draw_category_frame advanced "安装 ToDesk" "会修改 SteamOS 只读系统 · 高级操作"
        ui_panel_line 7 '\033[1;38;5;220m' "① 按 Steam 键 → 设置 → 系统"
        ui_panel_line 9 '\033[1;38;5;45m' "② 开启“启用开发者模式”"
        ui_panel_line 11 '\033[1;38;5;45m' "③ 设置侧栏进入“开发者” → 找到“杂项”"
        ui_panel_line 13 '\033[1;38;5;45m' "④ 开启“使用旧版 X11 桌面模式”"
        ui_panel_line 15 '\033[1;38;5;220m' "⑤ 重新进入桌面模式，再安装并启动 ToDesk"
        ui_touch_button 16 '\033[1;30;48;5;114m' "以上设置已完成，继续安装" "点击即确认两项开关均已开启"
        ui_touch_button 18 '\033[1;97;48;5;238m' "$return_label" "暂不安装"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        choice="$(read_touch_menu right:16-17:continue right:18-19:back right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            continue)
                confirm_and_run "安装 ToDesk" "将使用管理员权限并临时修改 SteamOS 只读系统；完成后应恢复只读保护" bash "$PROJECT_ROOT/modules/todesk.sh" --install
                return 0
                ;;
            back) NEXT_CATEGORY="$return_target"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

new_machine_menu() {
    local choice

    while true; do
        draw_category_frame init "新机必备" "第一次使用从这里开始"
        ui_touch_button 8 '\033[1;97;48;5;24m' "推荐软件安装" "选择需要的常用软件"
        ui_touch_button 13 '\033[1;97;48;5;24m' "新机初始化" "连续安装并配置新机器"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:recommended right:13-14:advanced-init right:20-21:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            recommended) NEXT_CATEGORY="software"; return 0 ;;
            advanced-init) new_machine_preflight; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

new_machine_preflight() {
    local choice

    while true; do
        draw_category_frame init "新机初始化" "安装常用软件并配置国内软件源"
        ui_panel_line 7 '\033[1;38;5;220m' "① Steam 键 → 设置 → 系统 → 启用开发者模式"
        ui_panel_line 9 '\033[1;38;5;45m' "② 设置侧栏 → 开发者 → 杂项"
        ui_panel_line 11 '\033[1;38;5;45m' "③ 开启“使用旧版 X11 桌面模式”"
        ui_panel_line 13 '\033[1;38;5;220m' "④ 重新进入桌面模式，再开始初始化"
        ui_panel_line 14 '\033[1;38;5;45m' "继续后将安装国内源、常用软件、Decky 和 ToDesk"
        ui_touch_button 16 '\033[1;30;48;5;114m' "设置已完成，开始新机初始化" "点击即确认已开启开发者模式和旧版 X11"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回新机必备" "暂不初始化"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        choice="$(read_touch_menu right:16-17:start right:18-19:init right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            start)
                run_action "新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/new_machine.sh"
                NEXT_CATEGORY="init"
                return 0
                ;;
            init) NEXT_CATEGORY="init"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

steam_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "SteamOS 掌机优化" "安全处理 Steam 缓存，并查看性能建议"
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

game_environment_menu() {
    local choice

    while true; do
        draw_category_frame games "游戏与插件｜插件安装" "浏览插件商城、运行组件和启动器" 0
        ui_touch_button 5 '\033[1;97;48;5;24m' "常用插件组合" "安装小黄鸭等三款插件"
        ui_touch_button 7 '\033[1;97;48;5;24m' "常用插件加27款精选插件" "优先安装三件套，已装则跳过；再补精选"
        ui_touch_button 9 '\033[1;97;48;5;24m' "浏览官方插件" "逐个查看插件作用"
        ui_touch_button 11 '\033[1;97;48;5;24m' "SimpleDeckyTDP" "TDP/功耗性能控制"
        ui_touch_button 13 '\033[1;97;48;5;24m' "小黄鸭" "单独安装小黄鸭汉化版·汉化作者：闲鱼双叶"
        ui_touch_button 15 '\033[1;97;48;5;24m' "FSR4" "单独安装 FSR4 汉化版·汉化作者：闲鱼双叶"
        ui_touch_button 17 '\033[1;97;48;5;24m' "Freedeck" "下载游戏和模拟器游戏·感谢作者b站一苇Isidf"
        ui_touch_button 19 '\033[1;97;48;5;24m' "CheatDeck" "风灵月影修改器和启动项启动插件"
        ui_touch_button 21 '\033[1;97;48;5;238m' "下一页…" "继续查看安装插件商城"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:features right:7-8:all right:9-10:browse right:11-12:simpledeckytdp right:13-14:lsfg right:15-16:fsr4 right:17-18:freedeck right:19-20:cheatdeck right:21-22:next right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            features) confirm_and_run "安装常用插件组合" "未安装插件商城时会先安装插件商城，再继续安装三款插件；会使用管理员权限" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" features ;;
            all) confirm_and_run "安装常用插件加27款精选插件" "三件套已装则跳过，未装则安装；再补27款精选；会使用管理员权限" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" all ;;
            browse) plugin_official_touch_pages ;;
            simpledeckytdp) confirm_and_run "安装 SimpleDeckyTDP" "TDP/功耗性能控制插件；来自作者 GitHub Release" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" simpledeckytdp ;;
            lsfg) confirm_and_run "安装小黄鸭" "单独安装小黄鸭汉化版，无需装其他插件；汉化作者：闲鱼双叶" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg-zh-gitee ;;
            fsr4) confirm_and_run "安装 FSR4" "单独安装 FSR4 汉化版，无需装其他插件；汉化作者：闲鱼双叶" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" fsr4-zh-gitee ;;
            freedeck) confirm_and_run "安装 Freedeck" "下载游戏和模拟器游戏；感谢作者b站一苇Isidf" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" freedeck ;;
            cheatdeck) confirm_and_run "安装 CheatDeck" "风灵月影修改器和启动项启动插件；来自作者 GitHub Release" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" cheatdeck ;;
            next) NEXT_CATEGORY="plugin_page_2"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "game_environment" ] || return 0
    done
}
plugin_page_2_menu() {
    local choice

    while true; do
        draw_category_frame games "插件安装｜下一页" "安装插件商城与剩余插件" 0
        ui_touch_button 5 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 7 '\033[1;97;48;5;24m' "Unifideck" "入库第三方平台游戏"
        ui_touch_button 9 '\033[1;97;48;5;238m' "上一页" "返回插件列表"
        ui_touch_button 23 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:decky-install right:7-8:unifideck right:9-10:previous right:23-24:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            decky-install) NEXT_CATEGORY="advanced"; return 0 ;;
            unifideck) confirm_and_run "安装 Unifideck" "入库第三方平台游戏；来自作者 GitHub Release" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" unifideck ;;
            previous) NEXT_CATEGORY="games"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "plugin_page_2" ] || return 0
    done
}

plugin_official_touch_pages() {
    local choice
    local page=0
    local total="${#DECKY_OFFICIAL_PLUGIN_NAMES[@]}"
    local total_pages=$(((total + DECKY_TOUCH_PAGE_SIZE - 1) / DECKY_TOUCH_PAGE_SIZE))
    local start
    local index
    local slot
    local row

    while true; do
        draw_category_frame games "官方插件（第 $((page + 1)) / $total_pages 页）" "点击插件即可安装"
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
            ui_touch_button 16 '\033[1;97;48;5;238m' "上一页" "查看前一组插件"
        else
            ui_touch_button 16 '\033[1;97;48;5;238m' "返回游戏与插件" "查看其他游戏组件"
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            ui_touch_button 18 '\033[1;97;48;5;30m' "下一页" "继续查看更多插件"
        else
            ui_touch_button 18 '\033[1;97;48;5;238m' "返回游戏与插件" "已是最后一页"
        fi
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu \
            right:6-7:plugin-$((start)) \
            right:8-9:plugin-$((start + 1)) \
            right:10-11:plugin-$((start + 2)) \
            right:12-13:plugin-$((start + 3)) \
            right:14-15:plugin-$((start + 4)) \
            right:16-17:previous \
            right:18-19:next \
            right:20-21:home)"
        case "$choice" in
            nav-*) apply_navigation "$choice"; return 0 ;;
        esac

        case "$choice" in
            plugin-*)
                index="${choice#plugin-}"
                if [ "$index" -lt "$total" ]; then
                    confirm_and_run "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}" \
                        "${DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS[$index]}；安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将由 Decky 官方商店安装" \
                        env ZHOUKEER_AUTO_CONFIRM=1 \
                        bash "$PROJECT_ROOT/modules/decky_bundle.sh" plugin "${DECKY_OFFICIAL_PLUGIN_NAMES[$index]}"
                fi
                ;;
            previous)
                if [ "$page" -gt 0 ]; then
                    page=$((page - 1))
                else
                    return 0
                fi
                ;;
            next)
                if [ "$page" -lt $((total_pages - 1)) ]; then
                    page=$((page + 1))
                else
                    return 0
                fi
                ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

dual_system_menu() {
    local choice

    while true; do
        draw_category_frame advanced "双系统与互通盘" "磁盘和开机菜单设置 · 高级操作"
        ui_touch_button 7 '\033[1;97;48;5;24m' "挂载互通盘" "连接唯一未挂载的共享盘 · 高级操作"
        ui_touch_button 9 '\033[1;97;48;5;30m' "只读保护互通盘" "防止 SteamOS 误写入 · 高级操作"
        ui_touch_button 11 '\033[1;97;48;5;24m' "恢复互通盘写入" "重新以可写模式挂载互通盘"
        ui_touch_button 13 '\033[1;97;48;5;24m' "显示开机系统菜单" "显示 systemd-boot 5 秒 · 高级操作"
        ui_touch_button 15 '\033[1;97;48;5;160m' "隐藏开机系统菜单" "将等待时间设置为 0 秒 · 高级操作"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回系统与密码" "查看其他系统功能"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:mount right:9-10:protect right:11-12:unprotect right:13-14:add right:15-16:remove right:18-19:advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            mount)
                confirm_and_run "挂载互通盘" "将自动识别唯一的未挂载 NTFS/exFAT 分区并创建快捷入口" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" mount
                ;;
            protect)
                confirm_and_run "保护双系统互通盘" "会重新以只读模式挂载互通盘；SteamOS 下将无法写入或删除该盘文件" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" protect
                ;;
            unprotect)
                confirm_and_run "恢复互通盘写入" "会重新以可写模式挂载互通盘，恢复 SteamOS 下的正常读写" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" unprotect
                ;;
            add)
                confirm_and_run "添加 systemd-boot 引导" "只启用已有 systemd-boot 菜单并备份配置；不会安装或重写 EFI 引导程序" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" add
                ;;
            remove)
                confirm_and_run "删除 systemd-boot 引导" "仅把引导菜单等待时间设置为 0 秒；不会删除 SteamOS、Windows 或启动项" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" remove
                ;;
            advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

domestic_source_preflight() {
    local choice

    while true; do
        draw_category_frame advanced "国内软件源" "提高国内应用下载速度 · 会修改软件源"
        ui_panel_line 7 '\033[1;38;5;220m' "远程：flathub-cn｜https://mirror.sjtu.edu.cn/flathub"
        ui_panel_line 9 '\033[1;38;5;220m' "备用：flathub-ustc｜https://mirrors.ustc.edu.cn/flathub"
        ui_panel_line 11 '\033[1;38;5;203m' "会修改 Flatpak 软件源，并可能调整 GPG 验证"
        ui_panel_line 13 '\033[1;38;5;203m' "还会运行 pacman，并临时关闭 SteamOS 只读保护"
        ui_panel_line 15 '\033[1;38;5;203m' "恢复官方源功能尚未完成，请确认了解后继续"
        ui_touch_button 17 '\033[1;97;48;5;160m' "确认修改国内软件源" "执行现有初始化动作 · 高风险"
        ui_touch_button 19 '\033[1;97;48;5;238m' "返回系统与密码" "不做任何修改"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:17-18:confirm-source right:19-20:advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            confirm-source)
                run_action "国内软件源" bash "$PROJECT_ROOT/modules/domestic_source.sh" init
                NEXT_CATEGORY="advanced"
                return 0
                ;;
            advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

advanced_tools_menu() {
    local choice

    while true; do
        draw_category_frame advanced "系统与密码" "以下功能会修改系统、网络、软件源、密码或磁盘设置。请确认了解风险后继续。"
        ui_touch_button 7 '\033[1;97;48;5;160m' "国内软件源" "会修改 Flatpak 软件源 · 高级操作"
        ui_touch_button 9 '\033[1;97;48;5;160m' "Steamcommunity 302" "可能修改 DNS 和证书 · 高级操作"
        ui_touch_button 11 '\033[1;97;48;5;160m' "设置管理员密码" "会修改 SteamOS 管理密码 · 高级操作"
        ui_touch_button 13 '\033[1;97;48;5;160m' "修改管理员密码" "会更换 SteamOS 管理密码 · 高级操作"
        ui_touch_button 17 '\033[1;97;48;5;160m' "双系统与互通盘" "管理磁盘和开机菜单 · 高级操作"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:domestic-source right:9-10:accelerator right:11-12:set-password right:13-14:change-password right:15-16:decky-install right:17-18:dual right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            domestic-source) domestic_source_preflight ;;
            accelerator) steam_accelerator_touch_menu ;;
            set-password) confirm_and_run "设置管理员密码" "新密码会明文保存到桌面管理员密码.txt；当前用户运行的软件都可能读取" bash "$PROJECT_ROOT/modules/password.sh" set ;;
            change-password) confirm_and_run "修改管理员密码" "将读取旧记录并明文保存新密码；当前用户运行的软件都可能读取" bash "$PROJECT_ROOT/modules/password.sh" change ;;
            decky-install) confirm_and_run "安装插件商城" "请先在游戏模式开启开发者模式和 CEF 远程调试。安装会使用管理员权限并启动后台服务" bash "$PROJECT_ROOT/modules/plugin_store.sh" store ;;
            dual) dual_system_menu ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

network_store_menu() {
    local choice

    while true; do
        draw_category_frame network "网络与应用商店" "检查网络和软件源状态"
        ui_touch_button 7 '\033[1;97;48;5;24m' "网络状态检查" "检查当前网络是否可用"
        ui_touch_button 11 '\033[1;97;48;5;24m' "软件源状态" "查看当前应用下载来源"
        ui_touch_button 15 '\033[1;97;48;5;160m' "管理国内源与加速" "进入高级网络设置 · 高级操作"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:network-status right:11-12:source-status right:15-16:manage-advanced right:20-21:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            network-status) run_action "网络状态检查" bash "$PROJECT_ROOT/modules/network.sh" ;;
            source-status) run_action "软件源状态" bash "$PROJECT_ROOT/modules/domestic_source.sh" status ;;
            manage-advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "network" ] || return 0
    done
}

steam_accelerator_touch_menu() {
    local choice

    while true; do
        draw_category_frame advanced "Steamcommunity 302" "加速 Steam 和 GitHub"
        ui_touch_button 6 '\033[1;97;48;5;24m' "安装或更新" "安装 Steamcommunity 302"
        ui_touch_button 9 '\033[1;97;48;5;30m' "一键开启加速" "自动准备并启动 Steam + GitHub 后台加速"
        ui_touch_button 12 '\033[1;97;48;5;24m' "查看运行状态" "检查加速是否开启"
        ui_touch_button 15 '\033[1;97;48;5;160m' "安全卸载" "先停止工具箱进程，再删除程序文件"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回系统与密码" "查看其他系统功能"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:6-7:install right:9-10:start right:12-13:status right:15-16:uninstall right:18-19:advanced right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            install)
                confirm_and_run "Steamcommunity 302" "安装后开启加速会修改网络设置并需要管理员权限" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
                ;;
            start)
                confirm_and_run "开启 Steamcommunity 302" "会修改网络设置并需要管理员权限" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" enable
                ;;
            status) run_action "Steamcommunity 302 状态" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status ;;
            uninstall)
                confirm_and_run "卸载 Steamcommunity 302" "会停止工具箱启动的进程；官方 systemd、hosts、DNS 和证书需按官方程序另行处理" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            advanced) NEXT_CATEGORY="advanced"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "advanced" ] || return 0
    done
}

support_menu() {
    local choice

    while true; do
        draw_category_frame support "维护与帮助" "系统检查、清理、指南和日志"
        ui_touch_button 8 '\033[1;97;48;5;24m' "系统维护" "检查系统、清理缓存和处理常见问题"
        ui_touch_button 13 '\033[1;97;48;5;24m' "检测与使用帮助" "查看信息、指南、记录和更新"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:8-9:maintenance right:13-14:help right:20-21:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            maintenance) maintenance_menu; return 0 ;;
            help) help_menu; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

maintenance_menu() {
    local choice

    while true; do
        draw_category_frame support "系统维护" "清理缓存和检查系统"
        ui_touch_button 5 '\033[1;97;48;5;24m' "系统健康检查" "检查空间和常用环境"
        ui_touch_button 7 '\033[1;97;48;5;24m' "游戏启动检查" "检查游戏无法启动原因"
        ui_touch_button 9 '\033[1;97;48;5;160m' "清理下载残留" "删除未完成下载文件 · 会删除缓存"
        ui_touch_button 11 '\033[1;97;48;5;160m' "清理着色器缓存" "释放空间并自动重建 · 会删除缓存"
        ui_touch_button 13 '\033[1;97;48;5;160m' "清理用户缓存" "清理可重新生成的缓存 · 会删除缓存"
        ui_touch_button 15 '\033[1;97;48;5;24m' "查看性能建议" "查看推荐性能设置"
        ui_touch_button 17 '\033[1;97;48;5;160m' "常见问题处理" "检测网络并清理下载残留 · 会删除缓存"
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:5-6:health right:7-8:diagnose right:9-10:download-cache right:11-12:shader-cache right:13-14:user-cache right:15-16:performance right:17-18:fix right:22-23:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            health) run_action "系统健康检查" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            diagnose) run_action "游戏启动检查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            download-cache) confirm_and_run "清理下载残留" "将删除 Steam 未完成的下载残留" bash "$PROJECT_ROOT/modules/clean.sh" download-cache ;;
            shader-cache) confirm_and_run "清理着色器缓存" "着色器会在下次运行游戏时重新生成" bash "$PROJECT_ROOT/modules/clean.sh" shader-cache ;;
            user-cache) confirm_and_run "清理用户缓存" "部分应用会在下次启动时重新生成缓存" bash "$PROJECT_ROOT/modules/clean.sh" user-cache ;;
            performance) run_action "查看性能建议" bash "$PROJECT_ROOT/modules/steam.sh" performance ;;
            fix) confirm_and_run "常见问题处理" "将检查网络状态并清理 Steam 未完成的下载残留" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "maintenance" ] || return 0
    done
}

help_menu() {
    local choice
    local page=1

    while true; do
        draw_category_frame support "检测与帮助（第 $page / 2 页）" "查看信息、指南和日志"
        if [ "$page" -eq 1 ]; then
            ui_touch_button 5 '\033[1;97;48;5;24m' "查看系统信息" "查看系统和设备信息"
            ui_touch_button 7 '\033[1;97;48;5;24m' "导出诊断报告" "保存检查结果到桌面"
            ui_touch_button 9 '\033[1;97;48;5;24m' "新手使用指南" "查看基础操作说明"
            ui_touch_button 11 '\033[1;97;48;5;24m' "游戏兼容指南" "查看游戏运行建议"
            ui_touch_button 13 '\033[1;97;48;5;24m' "掌机常用快捷键" "查看常用按键方法"
            ui_touch_button 15 '\033[1;97;48;5;24m' "外接设备检查" "检查显示器和蓝牙"
            ui_touch_button 19 '\033[1;97;48;5;30m' "下一页" "查看记录和工具箱更新"
        else
            ui_touch_button 7 '\033[1;97;48;5;24m' "操作记录" "导出最近工具箱记录"
            ui_touch_button 11 '\033[1;97;48;5;24m' "更新日志" "查看版本改动内容"
            ui_touch_button 15 '\033[1;97;48;5;160m' "检查并更新工具箱" "下载并安装最新版本 · 会联网并更新"
            ui_touch_button 19 '\033[1;97;48;5;238m' "上一页" "返回系统信息和指南"
        fi
        ui_touch_button 23 '\033[1;97;48;5;160m' "安装插件商城" "前往系统与密码确认 · 高级操作"
        ui_touch_button 25 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        if [ "$page" -eq 1 ]; then
            choice="$(read_touch_menu right:5-6:system-info right:7-8:report right:9-10:new-guide right:11-12:game-guide right:13-14:shortcuts right:15-16:peripherals right:19-20:next right:22-23:home)"
        else
            choice="$(read_touch_menu right:7-8:records right:11-12:changelog right:15-16:update right:19-20:previous right:22-23:home)"
        fi
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            system-info) run_action "查看系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            report) run_action "导出诊断报告" bash "$PROJECT_ROOT/core/detect.sh" --report ;;
            new-guide) run_action "新手使用指南" bash "$PROJECT_ROOT/modules/safety_center.sh" guide ;;
            game-guide) run_action "游戏兼容指南" bash "$PROJECT_ROOT/modules/game_guides.sh" show ;;
            shortcuts) run_action "掌机常用快捷键" bash "$PROJECT_ROOT/modules/handheld_helper.sh" shortcuts ;;
            peripherals) run_action "外接设备检查" bash "$PROJECT_ROOT/modules/handheld_helper.sh" peripherals ;;
            records) run_action "操作记录" bash "$PROJECT_ROOT/modules/safety_center.sh" records ;;
            changelog) changelog_menu ;;
            update) NEXT_CATEGORY="update"; return 0 ;;
            next) page=2 ;;
            previous) page=1 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "help" ] || return 0
    done
}

changelog_menu() {
    local choice
    local release_heading="当前版本"
    local line
    local in_latest_release=0
    local -a release_notes=()

    if [ -r "$PROJECT_ROOT/CHANGELOG.md" ]; then
        while IFS= read -r line; do
            case "$line" in
                "## "*)
                    if [ "$in_latest_release" -eq 1 ]; then
                        break
                    fi
                    release_heading="${line#\#\# }"
                    in_latest_release=1
                    ;;
                "- "*)
                    if [ "$in_latest_release" -eq 1 ]; then
                        release_notes+=("${line#- }")
                    fi
                    ;;
            esac
        done < "$PROJECT_ROOT/CHANGELOG.md"
    fi

    if [ -r "$PROJECT_ROOT/VERSION" ]; then
        release_heading="V$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION") · ${release_heading#*— }"
    fi

    while true; do
        draw_category_frame support "更新日志" "$release_heading"
        ui_panel_line 7 '\033[1;38;5;114m' "✓ ${release_notes[0]:-当前版本已安装，暂无摘要}"
        ui_panel_line 10 '\033[1;38;5;45m' "✓ ${release_notes[1]:-完整改动以 CHANGELOG.md 为准}"
        ui_panel_line 13 '\033[1;38;5;220m' "完整日志随工具箱自动更新，不再显示旧版固定日期"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回检测与帮助" "查看其他说明"
        ui_touch_button 20 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:17-18:help right:20-21:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            help) NEXT_CATEGORY="help"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
    done
}

home_menu() {
    local choice

    draw_category_frame "" "" ""
    ui_panel_line 2 '\033[1;38;5;220m' "新机必备｜第一次使用从这里开始"
    ui_panel_line 5 '\033[1;38;5;45m' "常用软件｜安装聊天、浏览器和远程工具"
    ui_panel_line 8 '\033[1;38;5;45m' "游戏与插件｜浏览插件商城和游戏组件"
    ui_panel_line 11 '\033[1;38;5;45m' "网络与应用商店｜检查网络和软件源状态"
    ui_panel_line 14 '\033[1;38;5;114m' "维护与帮助｜系统检查、清理、指南和日志"
    ui_panel_line 18 '\033[1;38;5;203m' "系统与密码｜设置密码和管理系统功能"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

if [ "${ZHOUKEER_SKIP_DISCLAIMER:-0}" != "1" ]; then
    show_disclaimer
fi
ensure_password_ready

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init) new_machine_menu ;;
        software) common_software_menu ;;
        games) game_environment_menu ;;
        plugin_page_2) plugin_page_2_menu ;;
        network) network_store_menu ;;
        support) support_menu ;;
        advanced) advanced_tools_menu ;;
        # 旧分类仅保留内部兼容，不再显示在首页。
        remote) NEXT_CATEGORY="software" ;;
        plugins|plugins-menu) NEXT_CATEGORY="games" ;;
        settings) NEXT_CATEGORY="network" ;;
        dual) NEXT_CATEGORY="advanced" ;;
        maintenance|help|optimize|guides|changelog) NEXT_CATEGORY="support" ;;
        update)
            confirm_and_run "检查并更新工具箱" "会联网下载、校验并安全替换为最新版本" bash "$PROJECT_ROOT/update.sh"
            [ "$NEXT_CATEGORY" = "update" ] && NEXT_CATEGORY="support"
            ;;
        exit)
            log "用户退出工具箱"
            exit 0
            ;;
        *) NEXT_CATEGORY="home" ;;
    esac
done
