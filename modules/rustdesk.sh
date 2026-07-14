#!/bin/bash

source config/settings.conf

APP_DIR="$HOME/zhoukeer-toolbox/apps"
RUSTDESK="$APP_DIR/rustdesk.AppImage"


echo "================================"
echo " 周克儿工具箱 - RustDesk安装"
echo "================================"


install_rustdesk(){

    mkdir -p "$APP_DIR"

    echo "[1/3] 下载 RustDesk..."

    curl -L "$RUSTDESK_DOWNLOAD" -o "$RUSTDESK"


    if [ $? -ne 0 ]; then
        echo "下载失败"
        return
    fi


    echo "[2/3] 添加执行权限"

    chmod +x "$RUSTDESK"


    echo "[3/3] 安装完成"

    echo ""
    echo "位置:"
    echo "$RUSTDESK"

}


config_rustdesk(){

    echo ""
    echo "RustDesk服务器配置"
    echo ""

    echo "ID服务器:"
    echo "$RUSTDESK_ID_SERVER"

    echo ""

    echo "中继服务器:"
    echo "$RUSTDESK_RELAY_SERVER"

    echo ""

    echo "API:"
    echo "$RUSTDESK_API"

}


echo "1. 安装 RustDesk"
echo "2. 查看服务器配置"
echo "0. 返回"

read -p "选择:" c


case $c in

1)
install_rustdesk
;;

2)
config_rustdesk
;;

0)
bash main.sh
;;

*)
echo "错误"
;;

esac

