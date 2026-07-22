#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUAL_FILE="$PROJECT_ROOT/modules/dual_system.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

for action in refind-install refind-hide refind-show refind-remove; do
    grep -Fq "$action" "$DUAL_FILE" || fail "停用兼容动作缺失：$action"
done
grep -Fq '该功能当前已停用。' "$DUAL_FILE" || fail "rEFInd 停用动作没有明确阻断"

touch_dual="$(sed -n '/^dual_system_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
gui_dual="$(sed -n '/^dual_system_menu()/,/^}/p' "$PROJECT_ROOT/core/gui.sh")"
for menu in "$touch_dual" "$gui_dual"; do
    for action in mount protect unprotect; do
        printf '%s\n' "$menu" | grep -Fq "modules/dual_system.sh\" $action" || fail "互通盘菜单动作缺失：$action"
    done
    for action in install status delete; do
        printf '%s\n' "$menu" | grep -Fq "modules/clover_boot.sh\" $action" || fail "Clover 菜单动作缺失：$action"
    done
    for action in tf-format-mount repair-drive windows-shortcut health cleanup-boot; do
        printf '%s\n' "$menu" | grep -Fq "modules/dual_system_tools.sh\" $action" || fail "双系统扩展动作缺失：$action"
    done
    for legacy_action in refind-install refind-hide refind-show refind-remove; do
        if printf '%s\n' "$menu" | grep -Fq "modules/dual_system.sh\" $legacy_action"; then
            fail "双系统菜单仍可执行旧 rEFInd 动作：$legacy_action"
        fi
    done
done

for action in add remove; do
    if bash "$DUAL_FILE" "$action" >/dev/null 2>&1; then
        fail "旧 systemd-boot 动作仍可执行：$action"
    fi
done

echo "PASS: rEFInd 和旧 systemd-boot 动作不可达，Clover 与双系统扩展菜单已接管"
