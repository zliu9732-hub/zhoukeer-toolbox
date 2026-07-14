#!/bin/bash

echo "======设备检测======"

SYSTEM=$(uname)

echo "系统：$SYSTEM"

if [ -f /etc/os-release ]; then
    echo "Linux系统"
fi

if [[ "$SYSTEM" == "Darwin" ]]; then
    echo "Mac系统"
fi

echo "=================="
