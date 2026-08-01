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
    for hidden in '网易云音乐' '战网'; do
        assert_not_contains "$menu" "$hidden" "常用软件不应显示：$hidden"
    done
done

for menu in "$touch_software_more" "$gui_software"; do
    for item in 'LibreOffice 办公套件' 'VLC 播放器' 'OBS Studio' 'LocalSend 局域网传文件'; do
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
assert_contains "$touch_plugin_page_2" '战网启动器' "插件第二页缺少战网启动器"
assert_contains "$gui_games" '战网启动器' "GUI 游戏与插件缺少战网启动器"
assert_contains "$touch_plugin_page_2" 'ToMoon' "插件第二页缺少 ToMoon"
assert_contains "$gui_games" 'ToMoon' "GUI 游戏与插件缺少 ToMoon"
assert_not_contains "$touch_plugin_page_2" '安装模拟器' "插件第二页仍显示模拟器入口"
assert_not_contains "$gui_games" '安装模拟器' "GUI 游戏与插件仍显示模拟器入口"
assert_contains "$touch_plugin_page_2" 'right:19-20:previous' "插件第二页缺少调整后的上一页坐标"
assert_contains "$touch_plugin_page_2" 'right:22-23:home' "插件第二页缺少调整后的返回首页坐标"
assert_contains "$touch_plugin_page_2" 'modules/plugin_store.sh" tomoon' "触控 ToMoon 未使用独立安装器"
assert_contains "$gui_games" 'modules/plugin_store.sh" tomoon' "GUI ToMoon 未使用独立安装器"
touch_software_buttons="$(printf '%s\n' "$touch_software" | grep 'ui_touch_button')"
gui_software_entries="$(printf '%s\n' "$gui_software" | sed -n '/choice="$(gui_dialog --menu/,/)" || return 0/p')"
for obsolete_hint in '安装适合 SteamOS 的微信' '安装适合 SteamOS 的 QQ' \
    '安装 Firefox 浏览器' '安装 Chrome 浏览器' '安装 Edge 浏览器'; do
    assert_not_contains "$touch_software_buttons" "$obsolete_hint" "触控常用软件仍显示多余说明：$obsolete_hint"
    assert_not_contains "$gui_software_entries" "$obsolete_hint" "GUI 常用软件仍显示多余说明：$obsolete_hint"
done

touch_games="$(function_source "$MAIN_FILE" game_environment_menu)
$(function_source "$MAIN_FILE" decky_loader_menu)
$(function_source "$MAIN_FILE" plugin_page_2_menu)"
gui_games="$(function_source "$GUI_FILE" game_environment_gui_menu)"
for menu in "$touch_games" "$gui_games"; do
    assert_contains "$menu" '游戏与插件｜插件商城' "插件商城页面标题不统一"
    assert_not_contains "$menu" '游戏与插件｜Decky 插件商城' "插件商城页面仍显示英文标题"
    for item in '常用插件组合' '常用插件加27款精选插件' '浏览官方插件' 'Epic 游戏启动器' '安装插件商城'; do
        assert_contains "$menu" "$item" "游戏环境缺少：$item"
    done
    assert_contains "$menu" 'Gitee' "小黄鸭/FSR4 缺少 Gitee 国内源入口说明"
    assert_contains "$menu" '国内失败自动切换官方源' "插件商城缺少国内到官方源的自动回退说明"
    assert_contains "$menu" '高级操作' "Decky Loader 缺少高级说明"
    assert_contains "$menu" '安装测试版插件商城' "Decky Loader 缺少测试版入口"
    assert_contains "$menu" '测试或预览' "Decky 测试版入口缺少系统通道说明"
    assert_not_contains "$menu" '25 个精选插件' "plugin_store all 仍被错误描述为 25 个精选插件"
    assert_not_contains "$menu" '兼容层管理' "不存在的兼容层管理仍可见"
done

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
    for item in '查看系统信息' '生成诊断包' '备份工具箱设置' '恢复工具箱设置' '查看详细网络信息' '导出旧版文字报告' '新手使用指南' '游戏兼容指南' '掌机常用快捷键' '外接设备检查' '操作记录' '更新日志' '检查并更新工具箱'; do
        assert_contains "$menu" "$item" "检测与帮助缺少：$item"
    done
    assert_contains "$menu" '会联网并更新' "工具箱更新缺少联网更新说明"
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
    for item in '国内软件源' 'Steamcommunity 302' '虚拟内存' '修改管理员密码' '双系统与互通盘'; do
        assert_contains "$menu" "$item" "系统设置缺少：$item"
    done
    for removed in '设置管理员密码' '安装插件商城' '安装 ToDesk'; do
        assert_not_contains "$menu" "$removed" "系统设置仍显示重复入口：$removed"
    done
    for risk_text in 'Flatpak 软件源' '修改 DNS' 'zram' '管理密码' '管理磁盘和开机菜单'; do
        assert_contains "$menu" "$risk_text" "系统设置缺少风险说明：$risk_text"
    done
done

touch_memory="$(function_source "$MAIN_FILE" memory_touch_menu)"
gui_memory="$(function_source "$GUI_FILE" memory_gui_menu)"
for menu in "$touch_memory" "$gui_memory"; do
    for item in '一键优化' '查看状态' '撤销工具箱优化' '系统原 swap'; do
        assert_contains "$menu" "$item" "虚拟内存子菜单缺少：$item"
    done
    assert_contains "$menu" 'modules/memory_tuning.sh" restore' "虚拟内存子菜单未调用安全撤销动作"
done

touch_uninstall="$(function_source "$MAIN_FILE" uninstall_software_menu)"
gui_uninstall="$(function_source "$GUI_FILE" uninstall_software_gui_menu)"
for menu in "$touch_uninstall" "$gui_uninstall"; do
    for item in '卸载微信' '卸载 QQ' '卸载 Firefox' '卸载 Chrome' '卸载 Edge' '卸载 RustDesk' '卸载 ToDesk' '卸载百度网盘' '卸载 LibreOffice' '卸载 VLC' '卸载 OBS Studio' '卸载 LocalSend' '卸载 Protontricks' '卸载 Bottles' '卸载 Steam302' '卸载 GE-Proton' '卸载 Decky Loader' '清空全部 Decky 插件'; do
        assert_contains "$menu" "$item" "卸载已安装缺少：$item"
    done
    assert_contains "$menu" '第 1/4 页' "卸载菜单缺少第一页"
    assert_contains "$menu" '第 2/4 页' "卸载菜单缺少第二页"
    assert_contains "$menu" '第 3/4 页' "卸载菜单缺少第三页"
    assert_contains "$menu" '第 4/4 页' "卸载菜单缺少第四页"
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
assert_contains "$touch_games_page_2" 'right:5-6:simpledeckytdp' "SimpleDeckyTDP 未移动到插件第二页原 CheatDeck 位置"
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
    for item in '挂载双系统互通盘' '初始化并挂载 TF 卡' '修复磁盘写入错误' '双系统互通盘保护' '双系统健康检查' '恢复互通盘写入' '清理第三方引导项'; do
        assert_contains "$menu" "$item" "双系统与互通盘缺少：$item"
    done
    for removed_item in '安装或修复 Clover' '查看 Clover 状态' '删除 Clover 双系统引导'; do
        assert_not_contains "$menu" "$removed_item" "已移除的 Clover 功能仍显示：$removed_item"
    done
    assert_not_contains "$menu" '一键切换 Windows' "双系统菜单仍显示已移除的 Windows 一键切换"
    assert_not_contains "$menu" '立即切换 Windows' "双系统菜单仍显示已移除的 Windows 立即切换"
    for marker in 'B1 ' 'B2 ' 'B3 ' 'B4 ' 'B5 ' 'B6 '; do
        assert_not_contains "$menu" "$marker" "双系统菜单仍显示参考序号：$marker"
    done
    assert_not_contains "$menu" 'modules/dual_system.sh" add' "双系统菜单仍可执行旧 systemd-boot 显示动作"
    assert_not_contains "$menu" 'modules/dual_system.sh" remove' "双系统菜单仍可执行旧 systemd-boot 隐藏动作"
done

for gui_menu_name in software_menu game_environment_gui_menu emulator_gui_menu support_gui_menu plugin_official_gui_pages dual_system_menu steam_accelerator_gui_menu maintenance_gui_menu help_gui_menu new_machine_gui_menu advanced_tools_gui_menu memory_gui_menu; do
    gui_menu="$(function_source "$GUI_FILE" "$gui_menu_name")"
    assert_contains "$gui_menu" 'home "返回首页"' "GUI 页面缺少返回首页：$gui_menu_name"
    assert_contains "$gui_menu" 'nav-exit "退出工具箱"' "GUI 页面缺少退出工具箱：$gui_menu_name"
done

touch_source="$(function_source "$MAIN_FILE" domestic_source_preflight)"
gui_source="$(function_source "$GUI_FILE" domestic_source_gui_preflight)"
for menu in "$touch_source" "$gui_source"; do
    for detail in 'flathub-cn' 'https://mirror.sjtu.edu.cn/flathub' 'flathub-ustc' 'https://mirrors.ustc.edu.cn/flathub' 'archlinuxcn' 'https://mirrors.ustc.edu.cn/archlinuxcn/' 'GPG' 'pacman' 'locale' '只读' '恢复'; do
        assert_contains "$menu" "$detail" "国内源风险页缺少：$detail"
    done
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
