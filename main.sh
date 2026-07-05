#!/bin/bash

source core/ui.sh

clear
logo

echo "1. 系统信息"
echo "2. 安全清理"
echo "3. Steam Deck优化"
echo "4. 网络检测"
echo "5. 一键修复模式（重点卖点）"
echo "0. 退出"

echo ""
read -p "选择: " opt

case $opt in
  1) bash modules/sysinfo.sh ;;
  2) bash modules/clean.sh ;;
  3) bash modules/steam.sh ;;
  4) bash modules/network.sh ;;
  5) bash modules/fixall.sh ;;
  0) exit ;;
esac
