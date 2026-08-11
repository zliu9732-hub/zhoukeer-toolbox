#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"

QIYOU_CONSOLE_URL="https://www.qiyou.cn/main/ljb-overview"
XUNYOU_CONSOLE_URL="https://www.xunyou.com/zt/zhuji/index.html"
UU_CONSOLE_URL="https://uu.163.com/console/"

show_console_accelerator_notice() {
    local provider="$1"

    echo "$provider 当前没有可直接安装到 SteamOS 的官方 Linux 客户端。"
    echo "将打开官方主机加速页面，请按页面提示使用手机 App、路由器插件或加速盒。"
    echo "不会下载 Windows 安装包，也不会修改 SteamOS 的 DNS、证书或网络配置。"
}

open_console_accelerator_page() {
    local provider="${1:-}"
    local provider_name
    local official_url

    case "$provider" in
        qiyou)
            provider_name="奇游主机加速"
            official_url="$QIYOU_CONSOLE_URL"
            ;;
        xunyou)
            provider_name="迅游主机加速"
            official_url="$XUNYOU_CONSOLE_URL"
            ;;
        uu)
            provider_name="网易UU主机加速"
            official_url="$UU_CONSOLE_URL"
            ;;
        *)
            echo "用法: $0 {qiyou|xunyou|uu}"
            return 1
            ;;
    esac

    is_linux || {
        echo "$provider_name 官方配置页仅在 Linux / SteamOS 上从Renkit打开。"
        return 1
    }
    command -v xdg-open >/dev/null 2>&1 || {
        echo "未找到系统浏览器启动工具 xdg-open。"
        echo "请手动访问：$official_url"
        return 1
    }

    show_console_accelerator_notice "$provider_name"
    if ! xdg-open "$official_url" >/dev/null 2>&1; then
        echo "无法打开系统浏览器，请手动访问：$official_url"
        return 1
    fi
    echo "已打开 $provider_name 官方页面。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    open_console_accelerator_page "${1:-}"
fi
