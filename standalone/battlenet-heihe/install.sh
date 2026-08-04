#!/bin/bash

# 战网启动器与黑盒工坊独立安装工具
# 用法: bash install.sh [battlenet|heihe]

set -u

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 数据目录默认与工具箱共用，方便复用已下载的战网/黑盒环境；也可用环境变量覆盖。
if [ -d "$HOME/.local/share/zhoukeer-toolbox/apps" ]; then
    : "${ZHOUKEER_APP_DIR:=$HOME/.local/share/zhoukeer-toolbox/apps}"
else
    : "${ZHOUKEER_APP_DIR:=$HOME/.local/share/zhoukeer-battlenet-heihe}"
fi
export ZHOUKEER_APP_DIR

if [ -f "$TOOL_DIR/modules/game_launchers.sh" ]; then
    # shellcheck disable=SC1091
    source "$TOOL_DIR/modules/game_launchers.sh"
elif [ -f "$TOOL_DIR/../../modules/game_launchers.sh" ]; then
    # 在工具箱仓库内直接运行时使用仓库模块。
    # shellcheck disable=SC1091
    source "$TOOL_DIR/../../modules/game_launchers.sh"
else
    echo "缺少核心模块 modules/game_launchers.sh，工具不完整。"
    exit 1
fi

detect_platform
if [ "$IS_STEAMOS" -ne 1 ]; then
    echo "此工具仅支持 SteamOS/Steam Deck，已停止执行。"
    exit 1
fi

require_command curl || exit 1
require_command bsdtar || exit 1
require_command python3 || exit 1

# 独立工具不附带 Decky 即时封面模块；封面已直接写入 Steam 库目录，Steam 重启后生效。
apply_launcher_decky_artwork() {
    echo "$LAUNCHER_NAME Steam 库封面已写入，Steam 重启后生效。"
}

tool_version=""
if [ -r "$TOOL_DIR/VERSION" ]; then
    tool_version="$(tr -d '\r\n' < "$TOOL_DIR/VERSION")"
fi

confirm_install() {
    local target="$1"
    local description
    case "$target" in
        battlenet) description="联网下载战网预装客户端，校验后写入 Steam 库并绑定 Proton 10.0-4，同时创建桌面入口" ;;
        heihe) description="联网下载黑盒工坊预装客户端，校验后解压到战网环境并写入 Steam 库（需要先安装战网启动器）" ;;
        *) return 1 ;;
    esac
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    printf '将%s。是否继续？[y/N] ' "$description"
    read -r answer || return 1
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) echo "已取消。"; return 1 ;;
    esac
}

run_target() {
    local target="$1"
    local label
    case "$target" in
        battlenet) label="战网启动器" ;;
        heihe) label="黑盒工坊" ;;
        *) echo "不支持的目标：$target"; return 1 ;;
    esac
    confirm_install "$target" || return 1
    echo "正在启动 $label 安装..."
    if ! install_launcher "$target"; then
        echo "$label 安装未完成，请查看上方提示后重试。"
        return 1
    fi
    return 0
}

usage() {
    echo "用法: bash install.sh [battlenet|heihe]"
    echo "不带参数时显示菜单。"
}

main() {
    case "${1:-}" in
        battlenet|heihe)
            run_target "$1"
            return $?
            ;;
        --help|-h)
            usage
            return 0
            ;;
        '')
            ;;
        *)
            usage
            return 1
            ;;
    esac

    echo "战网 + 黑盒工坊 独立安装工具${tool_version:+（V$tool_version）}"
    echo "仅支持 SteamOS；工具会联网下载并校验预装客户端。"
    echo ""
    echo "1. 战网启动器"
    echo "2. 黑盒工坊（需先安装战网启动器）"
    echo "3. 退出"
    while :; do
        printf '请输入数字 [1-3]：'
        read -r choice || break
        case "$choice" in
            1) run_target battlenet ;;
            2) run_target heihe ;;
            3) echo "已退出。"; break ;;
            *) echo "无效选择，请输入 1、2 或 3。" ;;
        esac
    done
}

main "$@"
