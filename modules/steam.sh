#!/bin/bash

echo "Steam Deck / 游戏优化"

echo "1. 清理下载缓存"
echo "2. 性能模式提示"
echo "3. 返回"

read -p "选择: " c

if [ "$c" = "1" ]; then
    rm -rf ~/.steam/steam/steamapps/downloading/* 2>/dev/null
    echo "缓存已清理"
fi

if [ "$c" = "2" ]; then
    echo "建议：性能模式 = 15W / 关闭后台"
fi

read -p "回车返回"
bash main.sh
