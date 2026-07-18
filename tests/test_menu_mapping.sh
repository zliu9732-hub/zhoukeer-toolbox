#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$(sed -n '/^system_settings_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"

for expected in \
    'right:7-8:init-sources' \
    'right:12-13:accelerator' \
    'right:15-16:set-password' \
    'right:17-18:change-password' \
    'right:19-20:info' \
    'init-sources) run_action "初始化软件源"' \
    'accelerator) steam_accelerator_touch_menu' \
    'set-password) confirm_and_run "设置系统密码"' \
    'change-password) confirm_and_run "修改系统密码"'; do
    printf '%s\n' "$MENU" | grep -Fq -- "$expected" || { echo "FAIL: 菜单映射缺失 $expected" >&2; exit 1; }
done

echo "PASS: 系统设置菜单标签与动作映射一致"
