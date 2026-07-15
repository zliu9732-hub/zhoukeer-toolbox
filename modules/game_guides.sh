#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

show_guides() {
    echo "======中文兼容攻略卡======"
    echo ""
    echo "【启动器游戏】"
    echo "Epic、战网等安装器先在 Steam 里选 PE（Proton Experimental）或 GE-Proton 10-4。"
    echo "安装完成后，在原 Steam 条目的快捷方式目标中换成真正的主 EXE，不要另建新条目。"
    echo ""
    echo "【游戏打不开】"
    echo "先完全退出 Steam 并重开，再在游戏属性 → 兼容性里切换 Proton。"
    echo "仍失败时先运行“游戏启动诊断”；不要直接删除兼容数据，以免丢失登录和设置。"
    echo ""
    echo "【手柄与启动器】"
    echo "启动器首次登录、验证码或弹窗常需要触控板操作；Steam + X 可呼出屏幕键盘。"
    echo "游戏内按键异常时，进入游戏详情页的控制器图标，优先试用社区布局。"
    echo ""
    echo "【反作弊提示】"
    echo "部分联网游戏因反作弊或厂商限制无法在 SteamOS 运行；不要反复重装系统或改动系统文件。"
    echo ""
    echo "【性能与空间】"
    echo "卡顿先降低画质或限制帧率；更新失败先确认至少保留 10GB 可用空间。"
    echo ""
    echo "这些是通用建议，工具箱不会保证每一款游戏都可运行。"
    log "已查看中文兼容攻略卡"
}

case "${1:-}" in
    show|"") show_guides ;;
    *) echo "用法: $0 [show]"; exit 1 ;;
esac
