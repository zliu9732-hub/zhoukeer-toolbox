#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

RUSTDESK="$APP_DIR/rustdesk.AppImage"

load_config

echo "================================"
echo " 周克儿工具箱 - RustDesk安装"
echo "================================"


install_rustdesk(){

    if ! require_command curl; then
        log "RustDesk安装失败: 缺少curl"
        return 1
    fi

    if [ -z "${RUSTDESK_DOWNLOAD:-}" ]; then
        echo "未配置 RustDesk 下载地址。"
        echo "请在 config/settings.conf 中设置 RUSTDESK_DOWNLOAD。"
        log "RustDesk安装失败: RUSTDESK_DOWNLOAD为空"
        return 1
    fi

    mkdir -p "$APP_DIR"

    echo "[1/3] 下载 RustDesk..."

    if ! curl -fL "$RUSTDESK_DOWNLOAD" -o "$RUSTDESK"; then
        echo "下载失败"
        rm -f "$RUSTDESK"
        log "RustDesk下载失败"
        return 1
    fi

    echo "[2/3] 添加执行权限"

    if ! chmod +x "$RUSTDESK"; then
        echo "添加执行权限失败"
        log "RustDesk添加执行权限失败"
        return 1
    fi


    echo "[3/3] 安装完成"

    echo ""
    echo "位置:"
    echo "$RUSTDESK"
    log "RustDesk安装完成: $RUSTDESK"

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
    echo "${RUSTDESK_API:-未配置}"

    echo ""
    echo "Key:"
    if [ -n "${RUSTDESK_KEY:-}" ]; then
        echo "已配置"
    else
        echo "未配置"
    fi

}


echo "1. 安装 RustDesk"
echo "2. 查看服务器配置"
echo "0. 返回"

read -r -p "选择:" c


case $c in

1)
install_rustdesk
;;

2)
config_rustdesk
;;

0)
exit 0
;;

*)
echo "错误"
;;

esac
