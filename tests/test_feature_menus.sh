#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_FILE="$PROJECT_ROOT/main.sh"
GUI_FILE="$PROJECT_ROOT/core/gui.sh"
UI_FILE="$PROJECT_ROOT/core/ui.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

function_source() {
    local file="$1"
    local name="$2"
    sed -n "/^${name}()/,/^}/p" "$file"
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local label="$3"
    grep -Fq -- "$expected" <<< "$text" || fail "$label"
}

assert_not_contains() {
    local text="$1"
    local unexpected="$2"
    local label="$3"
    if grep -Fq -- "$unexpected" <<< "$text"; then
        fail "$label"
    fi
}

touch_home="$(function_source "$MAIN_FILE" home_menu)"
gui_home="$(function_source "$GUI_FILE" main_gui_menu)"
sidebar="$(function_source "$UI_FILE" draw_category_frame)"

for item in \
    '新机器设置｜第一次使用从这里开始' \
    '安装常用软件｜聊天、浏览器和远程工具' \
    '游戏与插件｜浏览插件商城和游戏组件' \
    '模拟器｜Switch、Wii U、PS1 至 3DS 模拟器' \
    '检查与维护｜检查网络、常见问题并生成诊断包' \
    '更多设置｜国内下载、内存、密码和双系统' \
    '免责声明与使用须知｜查看完整图文说明'; do
    assert_contains "$touch_home" "$item" "触控首页缺少：$item"
    assert_contains "$gui_home" "$item" "GUI 首页缺少：$item"
done

[ "$(printf '%s\n' "$sidebar" | grep -c 'ui_sidebar_item')" -eq 9 ] || fail "触控侧栏不是八分类加退出"

touch_software="$(function_source "$MAIN_FILE" common_software_menu)"
gui_software="$(function_source "$GUI_FILE" software_menu)"
touch_software_more="$(function_source "$MAIN_FILE" common_software_more_menu)"
for menu in "$touch_software" "$gui_software"; do
    for item in '微信' 'QQ' 'Firefox 浏览器' 'Chrome 浏览器' 'Edge 浏览器' 'RustDesk 远程协助' 'AnyDesk 远程协助' 'ToDesk 远程协助' 'Windows 软件工具' '游戏兼容设置'; do
        assert_contains "$menu" "$item" "常用软件缺少：$item"
    done
done
assert_not_contains "$touch_software" '网易云音乐' "常用软件第一页不应显示：网易云音乐"
for menu in "$touch_software" "$gui_software"; do
    assert_not_contains "$menu" '战网' "常用软件不应显示：战网"
done

for menu in "$touch_software_more" "$gui_software"; do
    for item in 'LibreOffice 办公套件' 'VLC 播放器' 'OBS Studio' 'LocalSend 局域网传文件' 'PeaZip 压缩工具' 'WiliWili' '中文输入法' 'Xbox 云游戏' 'QQ音乐' '网易云音乐' 'YesPlayMusic' 'qBittorrent' 'Motrix 下载器' 'Free Download Manager' 'Media Downloader' 'Flameshot 截图' 'OnlyOffice 办公套件' 'Joplin 笔记' 'Heroic 游戏启动器' 'Lutris' 'Chiaki4Deck（PS5串流）' 'Parsec'; do
        assert_contains "$menu" "$item" "更多常用软件缺少：$item"
    done
done

touch_remote="$(function_source "$MAIN_FILE" remote_assistance_menu)"
gui_remote="$(function_source "$GUI_FILE" remote_menu)"
for menu in "$touch_remote" "$gui_remote"; do
    assert_not_contains "$menu" 'AnyDesk' "AnyDesk 不应重复显示在远程协助"
done

touch_plugin_page_2="$(function_source "$MAIN_FILE" plugin_page_2_menu)"
gui_games="$(function_source "$GUI_FILE" game_environment_gui_menu)"
touch_freedeck="$(function_source "$MAIN_FILE" freedeck_versions_menu)"
touch_handheld_plugins="$(function_source "$MAIN_FILE" handheld_plugins_menu)"
assert_contains "$touch_plugin_page_2" '战网启动器' "插件第二页缺少战网启动器"
assert_contains "$gui_games" '战网启动器' "GUI 游戏与插件缺少战网启动器"
assert_contains "$touch_plugin_page_2" 'ToMoon' "插件第二页缺少 ToMoon"
assert_contains "$gui_games" 'ToMoon' "GUI 游戏与插件缺少 ToMoon"
assert_not_contains "$touch_plugin_page_2" '安装模拟器' "插件第二页仍显示模拟器入口"
assert_not_contains "$gui_games" '安装模拟器' "GUI 游戏与插件仍显示模拟器入口"
assert_contains "$touch_plugin_page_2" 'right:19-20:repair' "插件第二页缺少修复封面坐标"
assert_contains "$touch_plugin_page_2" 'right:21-22:previous' "插件第二页缺少调整后的上一页坐标"
assert_contains "$touch_plugin_page_2" 'right:23-24:home' "插件第二页缺少调整后的返回首页坐标"
assert_contains "$touch_plugin_page_2" 'modules/plugin_store.sh" tomoon' "触控 ToMoon 未使用独立安装器"
assert_contains "$gui_games" 'modules/plugin_store.sh" tomoon' "GUI ToMoon 未使用独立安装器"
assert_contains "$touch_plugin_page_2" 'right:5-6:handheld-plugins' "插件第二页缺少掌机控制插件子菜单"
for menu in "$touch_handheld_plugins" "$gui_games"; do
    assert_contains "$menu" 'Ally 控制中心' "掌机控制插件菜单缺少中文名称"
    assert_contains "$menu" 'ROG Ally / Ally X' "Ally Center 入口缺少适用机型"
    assert_contains "$menu" 'RGB' "Ally Center 入口缺少 RGB 功能说明"
    assert_contains "$menu" 'modules/plugin_store.sh" allycenter' "Ally Center 未调用独立插件安装动作"
done
for menu in "$touch_freedeck" "$gui_games"; do
    assert_contains "$menu" 'Freedeck 0.6 稳定版' "Freedeck 版本菜单缺少稳定版"
    assert_contains "$menu" 'NewFreedeck v0.1' "Freedeck 版本菜单缺少重构版"
    assert_contains "$menu" '部分功能' "NewFreedeck 入口缺少上游未完成提示"
done
touch_software_buttons="$(printf '%s\n' "$touch_software" | grep 'ui_touch_button')"
gui_software_entries="$(printf '%s\n' "$gui_software" | sed -n '/choice="$(gui_dialog --menu/,/)" || return 0/p')"
for obsolete_hint in '安装适合 SteamOS 的微信' '安装适合 SteamOS 的 QQ' \
    '安装 Firefox 浏览器' '安装 Chrome 浏览器' '安装 Edge 浏览器'; do
    assert_not_contains "$touch_software_buttons" "$obsolete_hint" "触控常用软件仍显示多余说明：$obsolete_hint"
    assert_not_contains "$gui_software_entries" "$obsolete_hint" "GUI 常用软件仍显示多余说明：$obsolete_hint"
done

touch_games="$(function_source "$MAIN_FILE" game_environment_menu)
$(function_source "$MAIN_FILE" decky_loader_menu)
$(function_source "$MAIN_FILE" plugin_page_2_menu)
$(function_source "$MAIN_FILE" handheld_plugins_menu)
$(function_source "$MAIN_FILE" battlenet_submenu)"
gui_games="$(function_source "$GUI_FILE" game_environment_gui_menu)"
for menu in "$touch_games" "$gui_games"; do
    assert_contains "$menu" '游戏与插件｜插件商城' "插件商城页面标题不统一"
    assert_not_contains "$menu" '游戏与插件｜Decky 插件商城' "插件商城页面仍显示英文标题"
    for item in '常用插件组合' '浏览官方插件' 'Epic 游戏启动器' '安装插件商城'; do
        assert_contains "$menu" "$item" "游戏环境缺少：$item"
    done
    assert_contains "$menu" '黑盒工坊' "战网子菜单缺少黑盒工坊"
    assert_contains "$menu" '预装客户端' "战网子菜单缺少预装客户端提示"
    assert_contains "$gui_games" '常用插件加27款精选插件' "GUI 缺少常用加精选插件入口"
    assert_contains "$menu" '插帧神器（必装）' "小黄鸭缺少功能说明"
    assert_contains "$menu" '画质补丁（阅读桌面文档慎用）' "FSR4 缺少功能说明"
    assert_not_contains "$menu" 'Gitee' "小黄鸭/FSR4 仍显示 Gitee 入口说明"
    assert_contains "$menu" '国内失败自动切换官方源' "插件商城缺少国内到官方源的自动回退说明"
    assert_contains "$menu" '高级操作' "Decky Loader 缺少高级说明"
    assert_contains "$menu" '安装测试版插件商城' "Decky Loader 缺少测试版入口"
    assert_contains "$menu" '测试或预览' "Decky 测试版入口缺少系统通道说明"
    assert_not_contains "$menu" '25 个精选插件' "plugin_store all 仍被错误描述为 25 个精选插件"
    assert_not_contains "$menu" '兼容层管理' "不存在的兼容层管理仍可见"
done
assert_contains "$touch_games" '根据系统版本安装' "Decky Loader 子菜单缺少自动安装入口"
assert_contains "$gui_games" '根据系统版本安装' "GUI 插件商城缺少自动安装入口"

touch_maintenance="$(function_source "$MAIN_FILE" maintenance_menu)"
gui_maintenance="$(function_source "$GUI_FILE" maintenance_gui_menu)"
for menu in "$touch_maintenance" "$gui_maintenance"; do
    for item in '系统健康检查' '游戏启动检查' '清理下载残留' '清理着色器缓存' '清理用户缓存' '查看性能建议' '常见问题处理'; do
        assert_contains "$menu" "$item" "系统维护缺少：$item"
    done
    [ "$(printf '%s\n' "$menu" | grep -o '会删除缓存' | wc -l | tr -d ' ')" -ge 4 ] || fail "缓存删除风险说明不足"
    assert_not_contains "$menu" '权限修复' "不存在的权限修复仍可见"
    assert_not_contains "$menu" '一键修复模式' "旧的一键修复名称仍可见"
done

touch_help="$(function_source "$MAIN_FILE" help_menu)"
gui_help="$(function_source "$GUI_FILE" help_gui_menu)"
for menu in "$touch_help" "$gui_help"; do
    for item in '查看系统信息' '生成诊断包' '备份Renkit设置' '恢复Renkit设置' '查看详细网络信息' '导出旧版文字报告' '新手使用指南' '游戏兼容指南' '掌机常用快捷键' '外接设备检查' '操作记录' '更新日志' '检查并更新Renkit'; do
        assert_contains "$menu" "$item" "检测与帮助缺少：$item"
    done
    assert_contains "$menu" '会联网并更新' "Renkit更新缺少联网更新说明"
done

touch_support="$(function_source "$MAIN_FILE" support_menu)"
gui_support="$(function_source "$GUI_FILE" support_gui_menu)"
for menu in "$touch_support" "$gui_support"; do
    for item in '一键检查网络' '检查常见问题' '查看下载状态' '发给维护人员' '使用帮助与设置' '更多设置'; do
        assert_contains "$menu" "$item" "检查与维护缺少：$item"
    done
    for hidden in '网络修复' 'Discover 应用商店修复' '恢复官方源'; do
        assert_not_contains "$menu" "$hidden" "检查与维护页不应显示：$hidden"
    done
    assert_not_contains "$menu" 'domestic_source.sh" init' "检查与维护页不应直接执行国内源初始化"
    assert_contains "$menu" '发给维护人员' "检查问题页缺少面向新手的诊断包入口"
    assert_contains "$menu" '不包含密码和隐私信息' "诊断包入口缺少隐私说明"
    assert_contains "$menu" 'modules/diagnostics.sh" bundle' "诊断包入口映射错误"
done

touch_advanced="$(function_source "$MAIN_FILE" advanced_tools_menu)"
gui_advanced="$(function_source "$GUI_FILE" advanced_tools_gui_menu)"
for menu in "$touch_advanced" "$gui_advanced"; do
    assert_contains "$menu" '国内下载、网络加速、内存、密码与双系统' "更多设置缺少功能概览"
    for item in '国内软件源' 'Steamcommunity 302' '虚拟内存' '修改管理员密码' '双系统与互通盘' '掌机适配'; do
        assert_contains "$menu" "$item" "系统设置缺少：$item"
    done
    for removed in '设置管理员密码' '安装插件商城' '安装 ToDesk'; do
        assert_not_contains "$menu" "$removed" "系统设置仍显示重复入口：$removed"
    done
    for risk_text in 'Flatpak 软件源' '修改 DNS' 'zram' '管理密码' '管理磁盘和开机菜单' '不使用 sudo'; do
        assert_contains "$menu" "$risk_text" "系统设置缺少风险说明：$risk_text"
    done
done

touch_memory="$(function_source "$MAIN_FILE" memory_touch_menu)"
gui_memory="$(function_source "$GUI_FILE" memory_gui_menu)"
for menu in "$touch_memory" "$gui_memory"; do
    for item in '一键优化' '查看状态' '撤销Renkit优化' '系统原 swap'; do
        assert_contains "$menu" "$item" "虚拟内存子菜单缺少：$item"
    done
    assert_contains "$menu" 'modules/memory_tuning.sh" restore' "虚拟内存子菜单未调用安全撤销动作"
done

touch_f1="$(function_source "$MAIN_FILE" f1_handheld_menu)"
gui_f1="$(function_source "$GUI_FILE" f1_screen_fix_gui_menu)"
for menu in "$touch_f1" "$gui_f1"; do
    for item in '安装修复' '检查状态' '卸载修复' '立即重启 SteamOS' 'ONEXPLAYER F1' '不使用 sudo'; do
        assert_contains "$menu" "$item" "飞行家 F1 子菜单缺少：$item"
    done
    assert_contains "$touch_f1" 'right:7-8:install' "飞行家 F1 安装坐标错误"
    assert_contains "$touch_f1" 'right:13-14:reboot' "飞行家 F1 重启坐标错误"
done

touch_uninstall="$(function_source "$MAIN_FILE" uninstall_software_menu)"
gui_uninstall="$(function_source "$GUI_FILE" uninstall_software_gui_menu)"
for menu in "$touch_uninstall" "$gui_uninstall"; do
    for item in '卸载微信' '卸载 QQ' '卸载 Firefox' '卸载 Chrome' '卸载 Edge' '卸载 RustDesk' '卸载 ToDesk' '卸载百度网盘' '卸载 AnyDesk' '卸载 WiliWili' '卸载 Xbox 云游戏' '卸载 LibreOffice' '卸载 VLC' '卸载 OBS Studio' '卸载 LocalSend' '卸载 PeaZip' '卸载中文输入法' '卸载 Protontricks' '卸载 Bottles' '卸载 QQ音乐' '卸载网易云音乐' '卸载 YesPlayMusic' '卸载 qBittorrent' '卸载 Motrix' '卸载 Free Download Manager' '卸载 Media Downloader' '卸载 Flameshot 截图' '卸载 OnlyOffice' '卸载 Joplin 笔记' '卸载 Heroic' '卸载 Lutris' '卸载 Chiaki4Deck' '卸载 Parsec' '卸载战网启动器' '卸载 Epic' '卸载育碧' '卸载黑盒工坊' '卸载 Yuzu' '卸载 Cemu' '卸载 DuckStation' '卸载 PCSX2' '卸载 RPCS3' '卸载 ShadPS4' '卸载 PPSSPP' '卸载 mGBA' '卸载 Azahar' '卸载 Steam302' '卸载 GE-Proton' '卸载 Decky Loader' '清空全部 Decky 插件'; do
        assert_contains "$menu" "$item" "卸载已安装缺少：$item"
    done
    for page in 1 2 3 4 5 6 7; do
        assert_contains "$menu" "第 $page/7 页" "卸载菜单缺少第 $page 页"
    done
done

touch_games_page_1="$(function_source "$MAIN_FILE" game_environment_menu)"
gui_games_page_1="$(function_source "$GUI_FILE" game_environment_gui_menu)"
for menu in "$touch_games_page_1" "$gui_games_page_1"; do
    assert_contains "$menu" 'Steam 键 → 设置 → 启用开发者模式' "插件商城或插件组合缺少开发者模式开启路径"
    assert_contains "$menu" '设置左侧出现“开发者”后 → 开发者 → 杂项' "插件商城或插件组合缺少 CEF 菜单路径"
    assert_contains "$menu" 'CEF 远程调试' "插件商城或插件组合缺少 CEF 远程调试提示"
done
touch_games_page_2="$(function_source "$MAIN_FILE" plugin_page_2_menu)"
touch_emulators="$(function_source "$MAIN_FILE" emulator_menu)"
gui_emulators="$(function_source "$GUI_FILE" emulator_gui_menu)"
assert_contains "$touch_games_page_1" 'right:13-14:cheatdeck' "CheatDeck 未移动到插件第一页原 TDP 位置"
assert_contains "$touch_games_page_2" 'right:5-6:handheld-plugins' "掌机控制插件子菜单未放在插件第二页原功耗控制位置"
touch_handheld_plugins="$(function_source "$MAIN_FILE" handheld_plugins_menu)"
assert_contains "$touch_handheld_plugins" 'right:5-6:simpledeckytdp' "掌机控制插件子菜单缺少 SimpleDeckyTDP"
assert_contains "$touch_handheld_plugins" 'right:9-10:allycenter' "掌机控制插件子菜单缺少 Ally Center"
assert_contains "$touch_games_page_2" 'right:9-10:tomoon' "ToMoon 未紧挨 Unifideck 排列"
assert_contains "$touch_games_page_2" 'right:17-18:ubisoft' "Ubisoft Connect 未加入插件第二页"
assert_contains "$touch_games_page_2" '"育碧"' "育碧菜单仍显示旧名称"
for menu in "$touch_emulators" "$gui_emulators"; do
    for item in 'Yuzu' 'Cemu' 'DuckStation' 'PCSX2' 'RPCS3' 'ShadPS4' 'PPSSPP' 'mGBA' 'Azahar'; do
        assert_contains "$menu" "$item" "模拟器菜单缺少：$item"
    done
    assert_contains "$menu" '桌面图标' "模拟器菜单未说明桌面入口"
    assert_contains "$menu" 'Steam 库' "模拟器菜单未说明 Steam 入库"
    assert_not_contains "$menu" 'EmuDeck' "模拟器菜单不应包含 EmuDeck"
    assert_not_contains "$menu" '返回游戏与插件' "模拟器独立入口仍返回游戏与插件"
done

touch_dual="$(function_source "$MAIN_FILE" dual_system_menu)"
gui_dual="$(function_source "$GUI_FILE" dual_system_menu)"
for menu in "$touch_dual" "$gui_dual"; do
    for item in '挂载双系统互通盘' '初始化并挂载 TF 卡' '修复磁盘写入错误' '双系统互通盘保护' '双系统健康检查' '恢复互通盘写入' '清理第三方引导项' '修复双系统引导' '一键切换至 Windows'; do
        assert_contains "$menu" "$item" "双系统与互通盘缺少：$item"
    done
    for removed_item in '安装或修复 Clover' '查看 Clover 状态' '删除 Clover 双系统引导'; do
        assert_not_contains "$menu" "$removed_item" "已移除的 Clover 功能仍显示：$removed_item"
    done
    for marker in 'B1 ' 'B2 ' 'B3 ' 'B4 ' 'B5 ' 'B6 '; do
        assert_not_contains "$menu" "$marker" "双系统菜单仍显示参考序号：$marker"
    done
    assert_not_contains "$menu" 'modules/dual_system.sh" add' "双系统菜单仍可执行旧 systemd-boot 显示动作"
    assert_not_contains "$menu" 'modules/dual_system.sh" remove' "双系统菜单仍可执行旧 systemd-boot 隐藏动作"
done

for gui_menu_name in software_menu game_environment_gui_menu emulator_gui_menu support_gui_menu plugin_official_gui_pages dual_system_menu steam_accelerator_gui_menu maintenance_gui_menu help_gui_menu new_machine_gui_menu advanced_tools_gui_menu memory_gui_menu f1_screen_fix_gui_menu; do
    gui_menu="$(function_source "$GUI_FILE" "$gui_menu_name")"
    assert_contains "$gui_menu" 'home "返回首页"' "GUI 页面缺少返回首页：$gui_menu_name"
    assert_contains "$gui_menu" 'nav-exit "退出Renkit"' "GUI 页面缺少退出Renkit：$gui_menu_name"
done

touch_accelerator="$(function_source "$MAIN_FILE" steam_accelerator_touch_menu)"
gui_accelerator="$(function_source "$GUI_FILE" steam_accelerator_gui_menu)"
for menu in "$touch_accelerator" "$gui_accelerator"; do
    assert_contains "$menu" '重置加速' "Steamcommunity 302 菜单缺少重置入口"
    assert_contains "$menu" '打开官方配置界面' "Steamcommunity 302 菜单缺少配置界面入口"
    assert_not_contains "$menu" '自动启动 Steam' "Steamcommunity 302 菜单仍提示自动启动 Steam"
done

touch_ge_proton="$(function_source "$MAIN_FILE" ge_proton_menu)"
gui_ge_proton="$(function_source "$GUI_FILE" ge_proton_gui_menu)"
for menu in "$touch_ge_proton" "$gui_ge_proton"; do
    assert_contains "$menu" '安装最新 GE 兼容层' "GE 兼容层子菜单缺少最新版入口"
    assert_contains "$menu" '安装修改器所需常用兼容层' "GE 兼容层子菜单缺少修改器常用入口"
    assert_contains "$menu" '1.72GB' "GE 兼容层子菜单缺少下载体积提示"
done

touch_source="$(function_source "$MAIN_FILE" domestic_source_preflight)"
gui_source="$(function_source "$GUI_FILE" domestic_source_gui_preflight)"
for menu in "$touch_source" "$gui_source"; do
    for detail in 'flathub-cn' 'https://mirror.sjtu.edu.cn/flathub' 'flathub-ustc' 'https://mirrors.ustc.edu.cn/flathub' 'archlinuxcn' 'GPG' 'pacman' 'locale' '只读' '恢复'; do
        assert_contains "$menu" "$detail" "国内源风险页缺少：$detail"
    done
done
assert_contains "$touch_source" '上海交大 → 中科大 → 官方回退' "触控国内源页缺少 archlinuxcn 回退顺序"
for repo_url in 'https://mirror.sjtu.edu.cn/archlinux-cn/' 'https://mirrors.ustc.edu.cn/archlinuxcn/' 'https://repo.archlinuxcn.org/'; do
    assert_contains "$gui_source" "$repo_url" "GUI 国内源页缺少 archlinuxcn 回退地址：$repo_url"
done

for visible in "$MAIN_FILE" "$GUI_FILE"; do
    if grep -Eq 'modules/dual_system\.sh" refind-(install|hide|show|remove)' "$visible"; then
        fail "可见菜单仍可执行已停用的 rEFInd 动作：$visible"
    fi
    if grep -Eq '\[(只读|只读检查|会安装软件|会安装插件|会安装组件|会创建文件|普通|普通检查|引导|只读为主|部分会删除缓存)\]' "$visible"; then
        fail "普通菜单仍包含冗余状态标签：$visible"
    fi
    if grep -Eq '\[(会删除缓存|会联网并更新|实验功能|高级操作|高风险|安装软件/修改软件源|会修改软件源|会修改网络设置|会修改系统密码|会修改只读系统|会使用管理员权限|磁盘/启动高级操作)\]' "$visible"; then
        fail "菜单风险说明仍使用方括号：$visible"
    fi
done

echo "PASS: 触控与 GUI 的名称、说明、风险标签和功能集合一致"
