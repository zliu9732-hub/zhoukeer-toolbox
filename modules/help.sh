#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELP_PAGE="$PROJECT_ROOT/help.html"

if [ ! -f "$HELP_PAGE" ]; then
    echo "未找到Renkit帮助页面：$HELP_PAGE"
    exit 1
fi

if ! command -v xdg-open >/dev/null 2>&1; then
    echo "未找到网页打开工具 xdg-open。"
    echo "请在浏览器中访问：https://link3.cc/renamamiya"
    exit 1
fi

xdg-open "$HELP_PAGE" >/dev/null 2>&1 &
echo "已打开Renkit帮助页面。"
