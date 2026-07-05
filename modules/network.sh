#!/bin/bash

echo "网络检测中..."

ping -c 1 8.8.8.8 >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "网络正常"
else
    echo "网络异常"
fi

read -p "回车返回"
bash main.sh
