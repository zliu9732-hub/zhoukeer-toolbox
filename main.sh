#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

ensure_runtime_dirs

while true; do
    print_header
    echo "⭐ 推荐"
    echo "1. 一键新机初始化"
    echo ""
    echo "📦 单项功能"
    echo "2. Steam Deck优化"
    echo "3. 插件商城"
    echo "4. 微信"
    echo "5. QQ"
    echo "6. ToDesk"
    echo "7. 网络修复与检测"
    echo "8. 系统清理"
    echo "9. 一键修复模式"
    echo "10. 系统信息"
    echo "11. 更新工具箱"
    echo "12. RustDesk远程工具"
    echo "0. 退出"
    echo ""

    read -r -p "请选择：" num

    case "$num" in
        1)
            bash "$PROJECT_ROOT/modules/new_machine.sh"
            ;;
        2)
            bash "$PROJECT_ROOT/modules/steam.sh"
            ;;
        3)
            bash "$PROJECT_ROOT/modules/plugin_store.sh"
            ;;
        4)
            bash "$PROJECT_ROOT/modules/software.sh" wechat
            ;;
        5)
            bash "$PROJECT_ROOT/modules/software.sh" qq
            ;;
        6)
            bash "$PROJECT_ROOT/modules/todesk.sh"
            ;;
        7)
            bash "$PROJECT_ROOT/modules/network.sh"
            ;;
        8)
            bash "$PROJECT_ROOT/modules/clean.sh"
            ;;
        9)
            bash "$PROJECT_ROOT/modules/fixall.sh"
            ;;
        10)
            bash "$PROJECT_ROOT/core/detect.sh"
            ;;
        11)
            bash "$PROJECT_ROOT/update.sh"
            ;;
        12)
            bash "$PROJECT_ROOT/modules/rustdesk.sh"
            ;;
        0)
            log "用户退出工具箱"
            exit 0
            ;;
        *)
            echo "输入错误"
            ;;
    esac

    echo ""
    read -r -p "回车返回主菜单"
done
