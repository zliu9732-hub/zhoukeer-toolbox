#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform.sh"

echo "======设备检测======"

SYSTEM=$(uname)
detect_platform

echo "系统：$SYSTEM"
echo "发行版：$PLATFORM_NAME"

if [ -f /etc/os-release ]; then
    echo "Linux系统"
fi

if [[ "$SYSTEM" == "Darwin" ]]; then
    echo "Mac系统"
fi

if [ "$IS_STEAMOS" -eq 1 ]; then
    echo "SteamOS环境：是"
else
    echo "SteamOS环境：否"
fi

echo "=================="
