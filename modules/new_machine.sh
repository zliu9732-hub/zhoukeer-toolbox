#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

show_initialization_plan() {
    echo "⭐ 新机初始化"
    echo ""
    echo "即将处理："
    echo "✓ Steam Deck基础检查"
    echo "✓ 插件商城（Decky Loader）"
    echo "✓ 微信"
    echo "✓ QQ"
    echo "✓ ToDesk"
    echo "✓ 常用兼容层管理器（ProtonUp-Qt）"
    echo "✓ 工具箱快捷方式检查"
    echo "✓ 网络检测"
    echo ""
    echo "国内源替换和系统权限重置风险较高，当前版本不会自动执行。"
    echo "ToDesk和Decky安装过程中仍可能要求输入Steam Deck管理员密码。"
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

run_step() {
    local label="$1"
    shift

    echo ""
    echo "========== $label =========="
    if "$@"; then
        echo "[完成] $label"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "[失败] $label（继续处理后续项目）"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

skip_step() {
    echo "[跳过] $1：$2"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

basic_steamdeck_check() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "未检测到SteamOS。"
        return 1
    fi
    echo "已检测到SteamOS：$PLATFORM_NAME"
    echo "不会在新机初始化中自动清理下载缓存或着色器缓存。"
}

check_toolbox_shortcuts() {
    local desktop_file="$HOME/Desktop/周克儿工具箱.desktop"
    local application_file="$HOME/.local/share/applications/zhoukeer-toolbox.desktop"

    if [ ! -f "$desktop_file" ] || [ ! -f "$application_file" ]; then
        echo "工具箱快捷方式缺失，请重新运行安装命令。"
        return 1
    fi
    chmod +x "$desktop_file" "$application_file"
    echo "工具箱桌面和应用菜单快捷方式正常。"
}

check_network() {
    require_command curl || return 1
    if curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 10 \
        --max-time 20 \
        --output /dev/null \
        https://gitee.com; then
        echo "Gitee网络连接正常。"
        return 0
    fi
    echo "无法连接Gitee，请检查Wi-Fi、DNS或代理设置。"
    return 1
}

run_new_machine_initialization() {
    if ! confirm_initialization; then
        echo "已取消新机初始化。"
        return 0
    fi

    run_step "Steam Deck基础检查" basic_steamdeck_check
    run_step "网络检测" check_network
    skip_step "国内源优化" "尚未配置经过验证且可恢复的国内镜像方案"
    run_step "插件商城" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/plugin_store.sh"
    run_step "微信" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" wechat
    run_step "QQ" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" qq
    run_step "ToDesk" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/todesk.sh" --install
    run_step "常用兼容层管理器" env ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" protonup
    skip_step "权限修复" "未发现具体故障时不应批量重置用户或系统权限"
    run_step "创建快捷方式" check_toolbox_shortcuts

    echo ""
    echo "================================"
    echo "新机初始化结束"
    echo "完成：$PASS_COUNT"
    echo "失败：$FAIL_COUNT"
    echo "跳过：$SKIP_COUNT"
    echo "================================"
    log "新机初始化结束: 完成=$PASS_COUNT 失败=$FAIL_COUNT 跳过=$SKIP_COUNT"

    [ "$FAIL_COUNT" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_new_machine_initialization
fi
