#!/bin/bash

clear

source core/detect.sh
source core/logger.sh

echo "================================"
echo "      🧰 周克儿工具箱 v2.0"
echo "================================"

echo ""
echo "1. 设备检测"
echo "2. RustDesk远程工具"
echo "3. Steam Deck优化"
echo "4. 网络检测"
echo "5. 清理缓存"
echo "0. 退出"
echo ""

read -p "请选择：" num


case $num in

1)
bash core/detect.sh
;;

2)
bash modules/rustdesk.sh
;;

3)
bash modules/steam.sh
;;

4)
bash modules/network.sh
;;

5)
bash modules/clean.sh
;;

0)
exit
;;

*)
echo "输入错误"
;;

esac
