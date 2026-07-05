#!/bin/bash

echo "安全清理模式"

echo "清理缓存文件..."
rm -rf ~/Library/Caches/* 2>/dev/null

echo "清理Steam下载残留..."
rm -rf ~/.steam/steam/steamapps/downloading/* 2>/dev/null

echo "完成"
read -p "回车返回"
bash main.sh
