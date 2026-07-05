#!/bin/bash

echo "一键修复模式"

echo "1. DNS刷新"
sudo dscacheutil -flushcache 2>/dev/null

echo "2. Steam缓存清理"
rm -rf ~/.steam/steam/steamapps/downloading/* 2>/dev/null

echo "完成"

read -p "回车返回"
bash main.sh
