#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUAL_FILE="$PROJECT_ROOT/modules/dual_system.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for file in "$PROJECT_ROOT/main.sh" "$PROJECT_ROOT/core/gui.sh" "$PROJECT_ROOT/README.md"; do
    if grep -Eiq 'refind' "$file"; then
        fail "可见菜单或说明仍出现 rEFInd：$file"
    fi
done

for action in refind-install refind-hide refind-show refind-remove; do
    grep -Fq "$action" "$DUAL_FILE" || fail "停用兼容动作缺失：$action"
done
grep -Fq '该功能当前已停用。' "$DUAL_FILE" || fail "rEFInd 停用动作没有明确阻断"

touch_dual="$(sed -n '/^dual_system_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
gui_dual="$(sed -n '/^dual_system_menu()/,/^}/p' "$PROJECT_ROOT/core/gui.sh")"
for menu in "$touch_dual" "$gui_dual"; do
    for action in mount protect unprotect add remove; do
        printf '%s\n' "$menu" | grep -Fq "modules/dual_system.sh\" $action" || fail "双系统菜单动作缺失：$action"
    done
    if printf '%s\n' "$menu" | grep -Eiq 'refind'; then
        fail "双系统菜单仍可到达 rEFInd"
    fi
done

echo "PASS: rEFInd 在静态菜单和说明中不可达"
