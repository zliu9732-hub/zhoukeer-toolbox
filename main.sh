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
    echo "1. 设备检测"
    echo "2. RustDesk远程工具"
    echo "3. Steam Deck优化"
    echo "4. 网络检测"
    echo "5. 清理缓存"
    echo "6. 一键修复模式"
    echo "0. 退出"
    echo ""

    read -r -p "请选择：" num

    case "$num" in
        1)
            bash "$PROJECT_ROOT/core/detect.sh"
            ;;
        2)
            bash "$PROJECT_ROOT/modules/rustdesk.sh"
            ;;
        3)
            bash "$PROJECT_ROOT/modules/steam.sh"
            ;;
        4)
            bash "$PROJECT_ROOT/modules/network.sh"
            ;;
        5)
            bash "$PROJECT_ROOT/modules/clean.sh"
            ;;
        6)
            bash "$PROJECT_ROOT/modules/fixall.sh"
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
