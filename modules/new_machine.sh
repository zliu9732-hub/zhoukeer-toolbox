#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
NEW_MACHINE_REPORT_FILE=""
NEW_MACHINE_DMI_ROOT="${ZHOUKEER_DMI_ROOT:-/sys/class/dmi/id}"
NEW_MACHINE_BATTLENET="${ZHOUKEER_NEW_MACHINE_BATTLENET:-0}"
NEW_MACHINE_UBISOFT="${ZHOUKEER_NEW_MACHINE_UBISOFT:-0}"
NEW_MACHINE_HEIHE="${ZHOUKEER_NEW_MACHINE_HEIHE:-0}"

new_machine_flag_is_valid() {
    case "$1" in 0|1) return 0 ;; *) return 1 ;; esac
}

normalize_optional_launchers() {
    local flag_name flag_value

    for flag_name in NEW_MACHINE_BATTLENET NEW_MACHINE_UBISOFT NEW_MACHINE_HEIHE; do
        flag_value="${!flag_name}"
        new_machine_flag_is_valid "$flag_value" || {
            echo "新机初始化选项无效：$flag_name=$flag_value"
            return 1
        }
    done
    if [ "$NEW_MACHINE_HEIHE" = "1" ] && [ "$NEW_MACHINE_BATTLENET" != "1" ]; then
        NEW_MACHINE_BATTLENET=1
        echo "黑盒工坊依赖战网环境，已自动同时选择战网启动器。"
    fi
}

select_optional_launchers() {
    local selection token

    normalize_optional_launchers || return 1
    if [ "${ZHOUKEER_NEW_MACHINE_OPTIONS_SET:-0}" = "1" ]; then
        return 0
    fi

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ] && command -v kdialog >/dev/null 2>&1; then
        selection="$(kdialog --checklist \
            "Epic 与 FreeDeck 默认安装。请选择需要额外安装的平台；黑盒工坊会自动同时选择战网。" \
            battlenet "战网启动器" off \
            ubisoft "Ubisoft Connect（Uplay）" off \
            heihe "黑盒工坊" off 2>/dev/null)" || return 1
        selection="${selection//\"/}"
        for token in $selection; do
            case "$token" in
                battlenet) NEW_MACHINE_BATTLENET=1 ;;
                ubisoft) NEW_MACHINE_UBISOFT=1 ;;
                heihe) NEW_MACHINE_HEIHE=1 ;;
            esac
        done
        normalize_optional_launchers
        return $?
    fi
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    echo ""
    echo "可选第三方平台（Epic 已默认安装）："
    echo "1. 战网启动器"
    echo "2. Ubisoft Connect（Uplay）"
    echo "3. 黑盒工坊（会自动加装战网）"
    read -r -p "输入要加装的编号，可多选（如 1,3）；直接回车表示不加装：" selection
    selection="${selection//,/ }"
    selection="${selection//，/ }"
    for token in $selection; do
        case "$token" in
            1) NEW_MACHINE_BATTLENET=1 ;;
            2) NEW_MACHINE_UBISOFT=1 ;;
            3) NEW_MACHINE_HEIHE=1 ;;
            *)
                echo "无法识别的可选平台编号：$token"
                return 1
                ;;
        esac
    done
    normalize_optional_launchers
}

optional_launcher_summary() {
    local summary=""

    [ "$NEW_MACHINE_BATTLENET" != "1" ] || summary="战网"
    if [ "$NEW_MACHINE_UBISOFT" = "1" ]; then
        [ -z "$summary" ] || summary="$summary、"
        summary="${summary}Ubisoft Connect"
    fi
    if [ "$NEW_MACHINE_HEIHE" = "1" ]; then
        [ -z "$summary" ] || summary="$summary、"
        summary="${summary}黑盒工坊"
    fi
    printf '%s\n' "${summary:-无}"
}

show_initialization_plan() {
    echo "⭐ Renkit 新机一键初始化"
    echo ""
    echo "默认处理："
    echo "【01】检查 SteamOS、网络、电源、空间和系统保护状态"
    echo "【02-03】更新必要组件并初始化国内软件源"
    echo "【04】安装 Fcitx5 中文输入法和中文插件"
    echo "【05-06】安装微信、QQ、Firefox并创建桌面图标"
    echo "【07】安装 Decky Loader、FreeDeck、七款常用插件和精选官方插件"
    echo "【08】识别机器型号，仅应用匹配且低风险的插件配置"
    echo "【09】安装修改器常用兼容层：GE-Proton 7-55、8-25、9-27、10-29"
    echo "【10】按物理内存设置 zram、8-16GB swap 和 swappiness"
    echo "【11-12】安装 Steamcommunity 302，后台运行并设置开机自启"
    echo "【13-14】清理未完成下载，并复查网络、系统和游戏启动环境"
    echo "【15-16】检查 Renkit 安装、桌面入口和联网版本检测"
    echo "【17-18】生成桌面交付说明、执行报告和后续咨询指引"
    echo "【第三方平台】Epic 默认安装；可选：$(optional_launcher_summary)"
    echo ""
    echo "不会自动清理着色器、游戏、存档、兼容数据或整个用户缓存。"
    echo "初始化时部分步骤会临时关闭 SteamOS 只读保护，完成后由对应模块恢复。"
    echo "各安装器会先保留旧版本或临时配置备份，单项失败不会阻断后续项目。"
    echo "Decky 使用前须开启“CEF 远程调试”。"
}

confirm_initialization() {
    local answer

    show_initialization_plan
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo ""
        echo "已通过图形界面确认，开始初始化。"
        return 0
    fi
    echo ""
    read -r -p "确认开始请输入 INIT：" answer
    [ "$answer" = "INIT" ]
}

new_machine_report_begin() {
    local stamp

    mkdir -p "$HOME/Desktop" || return 1
    stamp="$(date '+%Y%m%d-%H%M%S')"
    NEW_MACHINE_REPORT_FILE="$HOME/Desktop/Renkit新机初始化报告-$stamp.txt"
    {
        echo "======Renkit新机初始化报告======"
        echo "开始时间：$(date '+%Y-%m-%d %H:%M:%S')"
        echo "Renkit版本：$TOOLBOX_VERSION"
        echo "默认平台：Epic"
        echo "可选平台：$(optional_launcher_summary)"
        echo ""
    } > "$NEW_MACHINE_REPORT_FILE" || return 1
    chmod 0600 "$NEW_MACHINE_REPORT_FILE" || return 1
}

new_machine_report_result() {
    local state="$1" label="$2"

    [ -n "$NEW_MACHINE_REPORT_FILE" ] || return 0
    printf '[%s] %s\n' "$state" "$label" >> "$NEW_MACHINE_REPORT_FILE" || true
}

run_step() {
    local label="$1"
    shift

    echo ""
    echo "========== $label =========="
    if "$@"; then
        echo "[完成] $label"
        new_machine_report_result "完成" "$label"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[失败] $label（继续处理后续项目）"
        new_machine_report_result "失败" "$label"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

skip_step() {
    echo "[跳过] $1：$2"
    new_machine_report_result "跳过" "$1：$2"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

basic_steamdeck_check() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "未检测到SteamOS。完整新机初始化仅支持 SteamOS。"
        return 1
    fi
    echo "已检测到SteamOS：$PLATFORM_NAME"
    echo "不会自动清理着色器、游戏、存档或兼容数据。"
}

run_new_machine_preflight() {
    bash "$PROJECT_ROOT/modules/preflight.sh" new-machine
}

check_toolbox_installation() {
    local desktop_file="$HOME/Desktop/Renkit.desktop"
    local application_file="$HOME/.local/share/applications/zhoukeer-toolbox.desktop"
    local required_file

    for required_file in VERSION update.sh main.sh modules/new_machine.sh; do
        [ -f "$PROJECT_ROOT/$required_file" ] || {
            echo "Renkit安装不完整，缺少：$required_file"
            return 1
        }
    done
    if [ ! -f "$desktop_file" ] || [ ! -f "$application_file" ]; then
        echo "Renkit快捷方式缺失，请重新运行安装命令。"
        return 1
    fi
    chmod +x "$desktop_file" "$application_file"
    echo "Renkit程序、自动更新脚本、桌面和应用菜单入口正常。"
}

check_network() {
    ZHOUKEER_NETWORK_QUIET=1 bash "$PROJECT_ROOT/modules/network.sh" --preflight
}

read_machine_identity() {
    local vendor product board

    vendor="$(cat "$NEW_MACHINE_DMI_ROOT/sys_vendor" 2>/dev/null || true)"
    product="$(cat "$NEW_MACHINE_DMI_ROOT/product_name" 2>/dev/null || true)"
    board="$(cat "$NEW_MACHINE_DMI_ROOT/board_name" 2>/dev/null || true)"
    printf '%s %s %s\n' "$vendor" "$product" "$board" | tr '[:upper:]' '[:lower:]'
}

apply_machine_profile() {
    local identity

    identity="$(read_machine_identity)"
    echo "机器识别：${identity:-未提供 DMI 型号}"
    case "$identity" in
        *steam*deck*|*jupiter*|*galileo*)
            echo "已选择 Steam Deck 通用配置；精选插件和内存参数由各模块按当前系统处理。"
            ;;
        *rog*ally*)
            echo "检测到 ROG Ally 系列，正在安装匹配的 Ally 控制中心。"
            env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" allycenter
            ;;
        *legion*go\ 2*|*legion*go*s*)
            echo "检测到 Legion Go 2 / Go S；高风险风扇和不匹配控制插件不会自动安装。"
            ;;
        *legion*go*)
            echo "检测到初代 Legion Go，正在安装匹配的控制中心。"
            env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" legiongo-remapper
            ;;
        *gpd*win*)
            echo "检测到 GPD Win 系列，正在安装匹配的 GPD 控制中心。"
            env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/plugin_store.sh" gpd-control
            ;;
        *)
            echo "型号无法安全匹配，已保留通用配置，不自动安装硬件控制插件。"
            ;;
    esac
}

install_optional_launchers() {
    if [ "$NEW_MACHINE_BATTLENET" = "1" ]; then
        run_step "【可选】战网启动器" env ZHOUKEER_AUTO_CONFIRM=1 \
            bash "$PROJECT_ROOT/modules/game_launchers.sh" battlenet
    else
        skip_step "【可选】战网启动器" "未选择"
    fi
    if [ "$NEW_MACHINE_UBISOFT" = "1" ]; then
        run_step "【可选】Ubisoft Connect（Uplay）" env ZHOUKEER_AUTO_CONFIRM=1 \
            bash "$PROJECT_ROOT/modules/game_launchers.sh" ubisoft
    else
        skip_step "【可选】Ubisoft Connect（Uplay）" "未选择"
    fi
    if [ "$NEW_MACHINE_HEIHE" = "1" ]; then
        run_step "【可选】黑盒工坊" env ZHOUKEER_AUTO_CONFIRM=1 \
            bash "$PROJECT_ROOT/modules/game_launchers.sh" heihe
    else
        skip_step "【可选】黑盒工坊" "未选择"
    fi
}

write_customer_handover_guide() {
    local guide_file="$HOME/Desktop/Renkit新机交付与使用说明.txt"
    local temporary_file="$guide_file.new.$$"

    mkdir -p "$HOME/Desktop" || return 1
    if [ -L "$guide_file" ] || { [ -e "$guide_file" ] && [ ! -f "$guide_file" ]; }; then
        echo "交付说明目标路径不是安全的普通文件，已停止写入。"
        return 1
    fi
    if [ -f "$guide_file" ] && ! grep -Fqx '# Renkit managed handover guide' "$guide_file"; then
        guide_file="$HOME/Desktop/Renkit新机交付与使用说明-新版.txt"
        temporary_file="$guide_file.new.$$"
    fi
    cat > "$temporary_file" <<EOF
# Renkit managed handover guide
======Steam Deck 新机交付与使用说明======

1. Renkit：桌面双击 Renkit；启动时会自动检测更新，也可在“检查与维护”中手动检查更新。
2. Decky / FreeDeck：返回游戏模式，按右下角“…”键，再打开插头图标；插件不显示时请完全退出并重开 Steam。
3. 修改器兼容层：已安装 GE-Proton 7-55、8-25、9-27、10-29；在游戏属性 → 兼容性中按游戏选择。
4. Epic：已按默认清单安装并加入 Steam 库；首次登录、验证码可用触控板，Steam + X 呼出键盘。
5. 中文输入：桌面模式使用 Fcitx5；首次使用请在系统托盘确认输入法已启动。
6. Steam 加速：Steamcommunity 302 已设置后台运行和开机自启；规则或证书未就绪时，在Renkit中打开一次官方配置界面。
7. 虚拟内存：zram、磁盘 swap 和 swappiness 已按机器内存设置，重启后完全生效。
8. 遇到问题：先运行“网络检查”“游戏启动诊断”；需要咨询时生成“Renkit诊断包”并发给安装服务人员。

本次执行报告：${NEW_MACHINE_REPORT_FILE:-未生成}
Renkit版本：$TOOLBOX_VERSION
生成时间：$(date '+%Y-%m-%d %H:%M:%S')
EOF
    chmod 0600 "$temporary_file" || { rm -f -- "$temporary_file"; return 1; }
    mv -f -- "$temporary_file" "$guide_file" || return 1
    echo "交付说明已保存到：$guide_file"
}

finish_new_machine_report() {
    [ -n "$NEW_MACHINE_REPORT_FILE" ] || return 0
    {
        echo ""
        echo "结束时间：$(date '+%Y-%m-%d %H:%M:%S')"
        echo "完成：$PASS_COUNT"
        echo "失败：$FAIL_COUNT"
        echo "跳过：$SKIP_COUNT"
        echo "说明：单项失败不回滚其他已完成项目；按失败项目在Renkit中单独重试。"
    } >> "$NEW_MACHINE_REPORT_FILE"
}

run_new_machine_initialization() {
    PASS_COUNT=0
    FAIL_COUNT=0
    SKIP_COUNT=0

    select_optional_launchers || return 1
    if ! confirm_initialization; then
        echo "已取消新机初始化。"
        return 0
    fi

    if ! basic_steamdeck_check; then
        echo "新机初始化已停止：未通过 SteamOS 平台检查。"
        return 1
    fi
    if ! run_new_machine_preflight; then
        echo "新机初始化已停止：准备检查未通过。"
        return 1
    fi
    new_machine_report_begin || {
        echo "无法创建桌面执行报告，新机初始化已停止。"
        return 1
    }
    PASS_COUNT=$((PASS_COUNT + 1))
    new_machine_report_result "完成" "【01】SteamOS、电源、空间、网络和系统保护预检"

    run_step "【01】网络线路复查" check_network
    run_step "【02-03】更新必要系统组件并优化国内软件源" \
        env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/domestic_source.sh" init
    run_step "【04】Fcitx5 中文输入法" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" fcitx5
    run_step "【05】微信" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" wechat
    run_step "【05】QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" qq
    run_step "【05】Firefox 浏览器" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" browser
    run_step "【07】Decky 插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/plugin_store.sh" store-auto
    run_step "【07】FreeDeck 稳定版" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/plugin_store.sh" freedeck
    run_step "【07】Decky 精选官方插件" env ZHOUKEER_AUTO_CONFIRM=1 \
        DECKY_BUNDLE_INCLUDE_CUSTOM=0 bash "$PROJECT_ROOT/modules/decky_bundle.sh" install
    run_step "【07】七款常用插件（含主题美化汉化）" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/plugin_store.sh" features
    run_step "【08】按机器型号应用安全配置" apply_machine_profile
    run_step "【09】修改器常用 GE-Proton 兼容层" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/ge_proton.sh" install-trainer
    run_step "【第三方平台】Epic Games 启动器（默认）" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/game_launchers.sh" epic
    install_optional_launchers
    run_step "【10】zram、Swap 和虚拟内存优化" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/memory_tuning.sh" optimize
    run_step "【11-12】Steamcommunity 302 后台加速与开机自启" \
        env ZHOUKEER_AUTO_CONFIRM=1 bash "$PROJECT_ROOT/modules/steam_accelerator.sh" install
    run_step "【13】清理 Steam 未完成下载残留" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/clean.sh" download-cache
    skip_step "【13】着色器、存档和整个用户缓存" "为避免新机首次启动变慢或误删，默认不清理"
    run_step "【06】修复全部已安装软件桌面图标" \
        bash "$PROJECT_ROOT/modules/software.sh" repair-shortcuts
    run_step "【14】系统健康复查" bash "$PROJECT_ROOT/core/detect.sh" --health
    run_step "【14】游戏启动环境复查" bash "$PROJECT_ROOT/modules/game_diagnose.sh" diagnose
    run_step "【15】Renkit 程序与快捷方式检查" check_toolbox_installation
    run_step "【16】Renkit 联网版本检测" bash "$PROJECT_ROOT/update.sh" --check-only
    run_step "【17-18】生成交付说明和后续咨询指引" write_customer_handover_guide

    finish_new_machine_report
    echo ""
    echo "================================"
    echo "新机一键初始化结束"
    echo "完成：$PASS_COUNT"
    echo "失败：$FAIL_COUNT"
    echo "跳过：$SKIP_COUNT"
    echo "执行报告：$NEW_MACHINE_REPORT_FILE"
    echo "================================"
    log "新机初始化结束: 完成=$PASS_COUNT 失败=$FAIL_COUNT 跳过=$SKIP_COUNT"

    [ "$FAIL_COUNT" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-run}" in
        run) run_new_machine_initialization ;;
        plan)
            select_optional_launchers || exit 1
            show_initialization_plan
            ;;
        *) echo "用法: $0 [run|plan]"; exit 1 ;;
    esac
fi
