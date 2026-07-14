#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/safety.sh"

echo "安全清理模式"

echo "1. 清理Steam下载残留"
echo "2. 清理Steam着色器缓存"
echo "3. 清理Linux用户缓存"
echo "0. 返回"
echo ""

read -r -p "选择: " c

case "$c" in
    1)
        safe_remove_contents "$HOME/.steam/steam/steamapps/downloading" "Steam下载残留"
        ;;
    2)
        safe_remove_contents "$HOME/.steam/steam/steamapps/shadercache" "Steam着色器缓存"
        ;;
    3)
        safe_remove_contents "$HOME/.cache" "Linux用户缓存"
        ;;
    0)
        exit 0
        ;;
    *)
        echo "输入错误"
        ;;
esac

echo "完成"
