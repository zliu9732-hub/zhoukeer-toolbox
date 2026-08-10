#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq '周克儿工具箱.desktop' "$PROJECT_ROOT/install.sh" || {
    echo "FAIL: install.sh 未清理旧版桌面入口" >&2
    exit 1
}
grep -Fq '周克儿工具箱.desktop' "$PROJECT_ROOT/uninstall.sh" || {
    echo "FAIL: uninstall.sh 未清理旧版桌面入口" >&2
    exit 1
}

echo "PASS: 安装与卸载都会清理旧版桌面入口"
