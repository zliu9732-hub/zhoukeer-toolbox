#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/safety.sh"

echo "Steam Deck / 游戏优化"

echo "1. 清理下载缓存"
echo "2. 性能模式提示"
echo "3. 清理着色器缓存"
echo "0. 返回"

read -r -p "选择: " c

case "$c" in
    1)
        safe_remove_contents "$HOME/.steam/steam/steamapps/downloading" "Steam下载缓存"
        ;;
    2)
        echo "建议：性能模式 = 15W / 关闭后台"
        echo "提示：实际性能档位请在 Steam Deck 快捷菜单中手动调整。"
        log "显示Steam Deck性能模式建议"
        ;;
    3)
        safe_remove_contents "$HOME/.steam/steam/steamapps/shadercache" "Steam着色器缓存"
        ;;
    0)
        exit 0
        ;;
    *)
        echo "输入错误"
        ;;
esac
