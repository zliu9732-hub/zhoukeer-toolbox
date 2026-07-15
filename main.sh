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

# Decky 官方插件的中文短说明。触控界面每页仅显示 5 个，避免小屏幕按钮拥挤。
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
        ui_disclaimer_line 12 '\033[38;5;220m' "部分国内下载分流由作者本人的123云盘提供"
        ui_disclaimer_line 13 '\033[1;38;5;114m' "喜欢本工具，欢迎来闲鱼支持作者"
        ui_disclaimer_line 14 '\033[38;5;220m' "若有侵权，请及时联系作者删除"
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
        left:12-13:nav-dual \
        left:14-15:nav-optimize \
        left:16-17:nav-changelog \
        left:18-19:nav-update \
        left:20-20:nav-exit \
        "$@"
}

apply_navigation() {
    case "$1" in
        nav-init) NEXT_CATEGORY="init" ;;
        nav-software) NEXT_CATEGORY="software" ;;
        nav-remote) NEXT_CATEGORY="remote" ;;
        nav-plugins) NEXT_CATEGORY="plugins" ;;
        nav-settings) NEXT_CATEGORY="settings" ;;
        nav-dual) NEXT_CATEGORY="dual" ;;
        nav-optimize) NEXT_CATEGORY="optimize" ;;
        nav-changelog) NEXT_CATEGORY="changelog" ;;
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
        ui_touch_button 7 '\033[1;97;48;5;24m' "微信" "安装或修复微信，同步创建桌面快捷方式"
        ui_touch_button 10 '\033[1;97;48;5;24m' "QQ" "安装或修复 QQ，同步创建桌面快捷方式"
        ui_touch_button 13 '\033[1;97;48;5;24m' "Firefox 浏览器" "安装完整包，不依赖Flatpak下载源"
        ui_touch_button 16 '\033[1;97;48;5;24m' "GE-Proton 兼容层" "安装到Steam兼容工具目录，无需管理员权限"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:wechat right:10-11:qq right:13-14:browser right:16-17:ge-proton right:18-19:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            wechat) confirm_and_run "安装微信" "腾讯官网AppImage；失败时保留原有版本" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            qq) confirm_and_run "安装QQ" "从腾讯官网国内CDN下载；完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            browser) confirm_and_run "安装Firefox浏览器" "完整包安装；失败时保留原有版本" bash "$PROJECT_ROOT/modules/software.sh" browser ;;
            ge-proton) confirm_and_run "安装GE-Proton兼容层" "安装到Steam compatibilitytools.d目录；完成后需要重启Steam" bash "$PROJECT_ROOT/modules/ge_proton.sh" install ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "software" ] || return 0
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame remote "远程协助" "安装完成后会自动在桌面创建启动图标"
        ui_touch_button 7 '\033[1;97;48;5;24m' "下载 RustDesk" "无需系统权限；可在软件内自行配置服务器"
        ui_touch_button 10 '\033[1;97;48;5;24m' "下载 AnyDesk" "通过用户级 Flatpak 安装，不修改系统只读分区"
        ui_touch_button 13 '\033[1;97;48;5;24m' "查看设置步骤并安装 ToDesk" "需先开启开发者模式和旧版 X11 桌面模式"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:rustdesk right:10-11:anydesk right:13-14:todesk right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            rustdesk) confirm_and_run "下载 RustDesk" "用户级安装，不会写入或修改你的 RustDesk 服务器配置" bash "$PROJECT_ROOT/modules/software.sh" rustdesk ;;
            anydesk) confirm_and_run "下载 AnyDesk" "用户级安装，完成后自动创建桌面图标" bash "$PROJECT_ROOT/modules/software.sh" anydesk ;;
            todesk) todesk_preflight ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "remote" ] || return 0
    done
}

todesk_preflight() {
    local choice

    while true; do
        draw_category_frame remote "ToDesk 使用前设置" "请先切回 Steam 游戏模式，按顺序完成全部步骤"
        ui_panel_line 7 '\033[1;38;5;220m' "① 按 Steam 键 → 设置 → 系统"
        ui_panel_line 9 '\033[1;38;5;45m' "② 开启“启用开发者模式”"
        ui_panel_line 11 '\033[1;38;5;45m' "③ 设置侧栏进入“开发者” → 找到“杂项”"
        ui_panel_line 13 '\033[1;38;5;45m' "④ 开启“使用旧版 X11 桌面模式”"
        ui_panel_line 15 '\033[1;38;5;220m' "⑤ 重新进入桌面模式，再安装并启动 ToDesk"
        ui_touch_button 16 '\033[1;30;48;5;114m' "以上设置已完成，继续安装" "点击即确认两项开关均已开启"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回远程协助" "暂不安装"
        choice="$(read_touch_menu right:16-17:continue right:18-19:back)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            continue)
                confirm_and_run "ToDesk远程工具" "将自动使用桌面管理员密码.txt验证；缺失时由系统询问" bash "$PROJECT_ROOT/modules/todesk.sh" --install
                return 0
                ;;
            back) NEXT_CATEGORY="remote"; return 0 ;;
        esac
    done
}

new_machine_preflight() {
    local choice

    while true; do
        draw_category_frame init "新机初始化前准备" "初始化包含 ToDesk，请先在 Steam 游戏模式完成设置"
        ui_panel_line 7 '\033[1;38;5;220m' "① Steam 键 → 设置 → 系统 → 启用开发者模式"
        ui_panel_line 9 '\033[1;38;5;45m' "② 设置侧栏 → 开发者 → 杂项"
        ui_panel_line 11 '\033[1;38;5;45m' "③ 开启“使用旧版 X11 桌面模式”"
        ui_panel_line 13 '\033[1;38;5;220m' "④ 重新进入桌面模式，再开始初始化"
        ui_panel_line 14 '\033[1;38;5;45m' "继续后将安装国内源、常用软件、Decky 和 ToDesk"
        ui_touch_button 16 '\033[1;30;48;5;114m' "设置已完成，开始新机初始化" "点击即确认已开启开发者模式和旧版 X11"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回首页" "暂不初始化"
        choice="$(read_touch_menu right:16-17:start right:18-19:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            start)
                run_action "一键新机初始化" env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/new_machine.sh"
                NEXT_CATEGORY="home"
                return 0
                ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
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
        draw_category_frame plugins "插件商城" "Decky内置安装器、29款插件与商店最新版"
        ui_touch_button 6 '\033[1;97;48;5;24m' "安装或更新 Decky Loader" "使用经过固定校验的国内安装源"
        ui_touch_button 8 '\033[1;97;48;5;24m' "一键安装常用功能插件" "小黄鸭、FSR4、CheatDeck 一次装好"
        ui_touch_button 10 '\033[1;97;48;5;30m' "一键安装当前列表全部插件" "3款独立功能 + 26款精选插件，共29款"
        ui_touch_button 12 '\033[1;97;48;5;24m' "浏览官方插件（分页）" "每页 5 个插件，均附中文功能说明"
        ui_touch_button 14 '\033[1;97;48;5;24m' "安装周克儿汉化（测试版）" "首批基础词库，不修改原插件文件"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:6-7:install right:8-9:features right:10-11:all right:12-13:browse right:14-15:localizer right:18-19:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            install) confirm_and_run "Decky Loader插件商城" "安装前请先回游戏模式：Steam键→设置→系统→开启“启用开发者模式”；再到开发者菜单开启“CEF远程调试”。完成后回桌面模式继续。将使用国内镜像安装器，执行前会校验固定 SHA256" bash "$PROJECT_ROOT/modules/plugin_store.sh" store ;;
            features) confirm_and_run "安装常用功能插件" "安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将依次安装小黄鸭、FSR4 和 CheatDeck；单项失败不会覆盖旧版本" bash "$PROJECT_ROOT/modules/plugin_store.sh" features ;;
            all) confirm_and_run "安装当前列表全部插件" "安装前请先在游戏模式开启“启用开发者模式”和“CEF远程调试”。将安装 Decky、3款独立功能插件和26款精选插件，其中包括 SimpleDeckyTDP 与 Unifideck；商店插件仍需在Steam界面确认" bash "$PROJECT_ROOT/modules/plugin_store.sh" all ;;
            browse) plugin_official_touch_pages ;;
            localizer) confirm_and_run "安装周克儿汉化" "这是独立的 Decky 汉化层测试版：不会改写原插件文件，首批仅覆盖基础文案。安装后请回游戏模式，在 Decky 菜单中启用。是否继续？" bash "$PROJECT_ROOT/modules/plugin_store.sh" localizer ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "plugins" ] || return 0
    done
}

plugin_store_preflight() {
    local choice

    while true; do
        draw_category_frame plugins "插件商城使用前设置" "Decky 插件安装前，请先在游戏模式完成以下两项设置"
        ui_panel_line 7 '\033[1;38;5;220m' "① 按 Steam 键 → 设置 → 系统"
        ui_panel_line 9 '\033[1;38;5;45m' "② 开启“启用开发者模式”"
        ui_panel_line 11 '\033[1;38;5;45m' "③ 在设置侧栏进入“开发者”菜单"
        ui_panel_line 13 '\033[1;38;5;45m' "④ 开启“CEF 远程调试”"
        ui_panel_line 15 '\033[1;38;5;220m' "⑤ 完成后回到桌面模式，再打开插件商城"
        ui_touch_button 16 '\033[1;30;48;5;114m' "以上设置已完成，进入插件商城" "Decky 官方插件安装需要这两项设置"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回首页" "暂不进入插件商城"
        choice="$(read_touch_menu right:16-17:continue right:18-19:home)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            continue) NEXT_CATEGORY="plugins-menu"; return 0 ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
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
        draw_category_frame plugins "官方插件（第 $((page + 1)) / $total_pages 页）" "点击插件即可安装；每项均来自 Decky 官方商店"
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
            ui_touch_button 16 '\033[1;97;48;5;238m' "返回插件商城" "查看一键安装功能"
        fi
        if [ "$page" -lt $((total_pages - 1)) ]; then
            ui_touch_button 18 '\033[1;97;48;5;30m' "下一页" "继续查看更多插件"
        else
            ui_touch_button 18 '\033[1;97;48;5;238m' "返回插件商城" "已是最后一页"
        fi
        ui_prompt
        choice="$(read_touch_menu \
            right:6-7:plugin-$((start)) \
            right:8-9:plugin-$((start + 1)) \
            right:10-11:plugin-$((start + 2)) \
            right:12-13:plugin-$((start + 3)) \
            right:14-15:plugin-$((start + 4)) \
            right:16-17:previous \
            right:18-19:next)"
        if apply_navigation "$choice"; then return 0; fi

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
        esac
        [ "$NEXT_CATEGORY" = "plugins" ] || return 0
    done
}

dual_system_menu() {
    local choice

    while true; do
        draw_category_frame dual "双系统设置" "互通盘挂载与已存在的 systemd-boot 菜单设置"
        ui_touch_button 7 '\033[1;97;48;5;24m' "一键挂载互通盘" "仅自动挂载唯一的未挂载 NTFS/exFAT 分区"
        ui_touch_button 9 '\033[1;97;48;5;30m' "保护双系统互通盘" "只读挂载，防止 SteamOS 下误写入或误删除"
        ui_touch_button 11 '\033[1;97;48;5;24m' "恢复互通盘写入" "重新以可写模式挂载互通盘"
        ui_touch_button 13 '\033[1;97;48;5;30m' "添加 Steam Deck 双引导" "启用启动菜单，默认等待 5 秒"
        ui_touch_button 15 '\033[1;97;48;5;160m' "删除 Steam Deck 双引导" "仅将菜单等待时间改为 0 秒，不删除系统"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:mount right:9-10:protect right:11-12:unprotect right:13-14:add right:15-16:remove right:18-19:home)"
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
                confirm_and_run "添加 Steam Deck 双引导" "只启用已有 systemd-boot 菜单并备份配置；不会安装或重写 EFI 引导程序" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" add
                ;;
            remove)
                confirm_and_run "删除 Steam Deck 双引导" "仅把引导菜单等待时间设置为 0 秒；不会删除 SteamOS、Windows 或启动项" \
                    bash "$PROJECT_ROOT/modules/dual_system.sh" remove
                ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "dual" ] || return 0
    done
}

system_settings_menu() {
    local choice

    while true; do
        draw_category_frame settings "系统设置" "下载源、Steam加速、系统密码和一键体检"
        ui_touch_button 7 '\033[1;97;48;5;24m' "添加国内下载源" "自动测速后优先使用更快的用户级 Flatpak 源"
        ui_touch_button 9 '\033[1;97;48;5;24m' "Steamcommunity 302" "安装、查看状态或安全卸载 Steam 加速器"
        ui_touch_button 11 '\033[1;97;48;5;24m' "设置系统密码" "明文保存到桌面；同一用户运行的软件也能读取"
        ui_touch_button 13 '\033[1;97;48;5;24m' "修改系统密码" "同步更新明文记录；同一用户软件也能读取"
        ui_touch_button 15 '\033[1;97;48;5;24m' "一键体检" "检查空间、网络、Steam、Decky 和常用软件；不修改系统"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:source right:9-10:accelerator right:11-12:set-password right:13-14:change-password right:15-16:info right:18-19:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            source) confirm_and_run "添加国内下载源" "只添加用户级 Flatpak 国内缓存，不修改只读分区" bash "$PROJECT_ROOT/modules/domestic_source.sh" enable ;;
            accelerator) steam_accelerator_touch_menu ;;
            set-password) confirm_and_run "设置系统密码" "新密码将明文保存到桌面管理员密码.txt；所有以当前用户身份运行的软件都可能读取" bash "$PROJECT_ROOT/modules/password.sh" set ;;
            change-password) confirm_and_run "修改系统密码" "将读取旧记录并明文保存新密码；所有以当前用户身份运行的软件都可能读取" bash "$PROJECT_ROOT/modules/password.sh" change ;;
            info) run_action "一键体检" bash "$PROJECT_ROOT/core/detect.sh" --health ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "settings" ] || return 0
    done
}

steam_accelerator_touch_menu() {
    local choice

    while true; do
        draw_category_frame settings "Steamcommunity 302" "官方 Linux AMD64 固定版本，安装包双重校验"
        ui_touch_button 8 '\033[1;97;48;5;24m' "安装或更新" "安装后在官方界面按需开启后台服务"
        ui_touch_button 11 '\033[1;97;48;5;24m' "查看运行状态" "查看版本、桌面图标和后台服务状态"
        ui_touch_button 14 '\033[1;97;48;5;160m' "安全卸载" "后台服务仍启用时会拒绝删除"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回系统设置" "查看其他系统功能"
        ui_prompt
        choice="$(read_touch_menu right:8-9:install right:11-12:status right:14-15:uninstall right:17-18:settings)"
        if apply_navigation "$choice"; then return 0; fi
        case "$choice" in
            install)
                confirm_and_run "Steamcommunity 302" "涉及本机代理、hosts/DNS和根证书；安装后由你选择是否开启后台服务" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
                ;;
            status) run_action "Steamcommunity 302 状态" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" status ;;
            uninstall)
                confirm_and_run "卸载 Steamcommunity 302" "请先在官方界面禁用后台服务并恢复 hosts、DNS 和证书" bash "$PROJECT_ROOT/modules/steam_accelerator.sh" uninstall
                ;;
            settings) NEXT_CATEGORY="settings"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "settings" ] || return 0
    done
}

system_optimization_menu() {
    local choice

    while true; do
        draw_category_frame optimize "系统优化" "缓存清理、性能建议和常见问题修复"
        ui_touch_button 7 '\033[1;97;48;5;24m' "游戏与掌机助手" "非 Steam 入库、启动诊断、快捷键和外接设备检查"
        ui_touch_button 10 '\033[1;97;48;5;24m' "Steam Deck 优化" "下载缓存、着色器缓存和性能建议"
        ui_touch_button 13 '\033[1;97;48;5;24m' "系统清理" "安全释放用户缓存和 Steam 缓存"
        ui_touch_button 16 '\033[1;97;48;5;24m' "一键修复模式" "检测网络并处理常见下载问题"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:7-8:game-tools right:10-11:steam right:13-14:clean right:16-17:fix right:18-19:home)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            game-tools) game_tools_touch_menu ;;
            steam) steam_touch_menu ;;
            clean) clean_touch_menu ;;
            fix) confirm_and_run "一键修复模式" "检测网络并安全清理 Steam 下载缓存" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            home) NEXT_CATEGORY="home"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "optimize" ] || return 0
    done
}

game_tools_touch_menu() {
    local choice

    while true; do
        draw_category_frame optimize "游戏与掌机助手" "安全检测和引导，不删除游戏或修改 Steam 游戏库"
        ui_touch_button 7 '\033[1;97;48;5;24m' "安装 Epic 并 Add to Steam" "下载官方 MSI；安装后把原 Steam 条目目标换成主 EXE"
        ui_touch_button 10 '\033[1;97;48;5;24m' "安装战网并 Add to Steam" "下载官方 EXE；安装后把原 Steam 条目目标换成主 EXE"
        ui_touch_button 13 '\033[1;97;48;5;24m' "游戏启动诊断" "检查 Steam、兼容层、空间和日志；不删除游戏文件"
        ui_touch_button 16 '\033[1;97;48;5;24m' "掌机常用快捷键 / 外接设备" "快捷键说明及显示器、蓝牙设备只读检查"
        ui_touch_button 18 '\033[1;97;48;5;238m' "返回系统优化" "查看清理和修复功能"
        ui_prompt
        choice="$(read_touch_menu right:7-8:epic right:10-11:battlenet right:13-14:diagnose right:16-17:handheld right:18-19:optimize)"
        if apply_navigation "$choice"; then return 0; fi

        case "$choice" in
            epic) confirm_and_run "安装 Epic 并 Add to Steam" "下载官方 MSI 到桌面；随后按提示右键 Add to Steam 并手动选择 PE 或 GE-Proton 10-4" bash "$PROJECT_ROOT/modules/game_launchers.sh" epic ;;
            battlenet) confirm_and_run "安装战网并 Add to Steam" "下载官方 EXE 到桌面；随后按提示右键 Add to Steam 并手动选择 PE 或 GE-Proton 10-4" bash "$PROJECT_ROOT/modules/game_launchers.sh" battlenet ;;
            diagnose) run_action "游戏启动诊断" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose ;;
            handheld)
                run_action "掌机常用快捷键" bash "$PROJECT_ROOT/modules/handheld_helper.sh" shortcuts
                run_action "外接设备检查" bash "$PROJECT_ROOT/modules/handheld_helper.sh" peripherals
                ;;
            optimize) NEXT_CATEGORY="optimize"; return 0 ;;
        esac
        [ "$NEXT_CATEGORY" = "optimize" ] || return 0
    done
}

changelog_menu() {
    local choice

    while true; do
        draw_category_frame changelog "更新日志" "周克儿工具箱 V4 · 2026-07-14"
        ui_panel_line 7 '\033[1;38;5;114m' "✓ 新增纯触控分类界面、黑白背景和工具箱图标"
        ui_panel_line 9 '\033[1;38;5;45m' "✓ 新增国内双缓存、Firefox 和 Steamcommunity 302"
        ui_panel_line 11 '\033[1;38;5;45m' "✓ 新增系统密码设置、修改和自动验证"
        ui_panel_line 13 '\033[1;38;5;45m' "✓ 完善 Decky、常用插件、ToDesk 和新机初始化"
        ui_panel_line 15 '\033[1;38;5;220m' "✓ 修复旧版密码记录无法识别的问题"
        ui_touch_button 17 '\033[1;97;48;5;238m' "返回首页" "查看全部功能分类"
        ui_prompt
        choice="$(read_touch_menu right:17-18:home)"
        if apply_navigation "$choice"; then return 0; fi
        [ "$choice" = "home" ] && { NEXT_CATEGORY="home"; return 0; }
    done
}

home_menu() {
    local choice

    draw_category_frame "" "欢迎使用" "全界面只需点击，无需输入任何数字或字母"
    ui_panel_line 8 '\033[1;38;5;220m' "⭐ 新机初始化：国内源、软件、Decky、ToDesk"
    ui_panel_line 9 '\033[1;38;5;45m' "💻 常用软件：微信、QQ、Firefox 浏览器"
    ui_panel_line 10 '\033[1;38;5;45m' "📡 远程协助：RustDesk、AnyDesk、ToDesk"
    ui_panel_line 11 '\033[1;38;5;45m' "🧩 插件商城：Decky、29款插件、官方商城分页"
    ui_panel_line 12 '\033[1;38;5;45m' "⚙ 系统设置：国内源、加速器、密码、设备信息"
    ui_panel_line 13 '\033[1;38;5;45m' "💿 双系统设置：互通盘、双引导菜单"
    ui_panel_line 14 '\033[1;38;5;114m' "🚀 系统优化：缓存清理、性能建议、问题修复"
    ui_panel_line 15 '\033[1;38;5;114m' "📋 更新日志：查看版本改动和修复内容"
    ui_panel_line 16 '\033[1;38;5;114m' "🔄 工具箱更新：检查并更新到最新版本"
    ui_prompt
    choice="$(read_touch_menu)"
    apply_navigation "$choice" || true
}

show_disclaimer

while true; do
    case "$NEXT_CATEGORY" in
        home) home_menu ;;
        init) new_machine_preflight ;;
        software) common_software_menu ;;
        remote) remote_assistance_menu ;;
        plugins) plugin_store_preflight ;;
        plugins-menu) plugin_store_menu ;;
        settings) system_settings_menu ;;
        dual) dual_system_menu ;;
        optimize) system_optimization_menu ;;
        changelog) changelog_menu ;;
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
