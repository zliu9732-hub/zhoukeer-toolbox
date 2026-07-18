#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for action in refind-install refind-hide refind-show refind-remove; do
    output="$(bash "$PROJECT_ROOT/modules/dual_system.sh" "$action" 2>&1 || true)"
    [ "$output" = "该功能当前已停用。" ] || { echo "FAIL: $action 未明确停用" >&2; exit 1; }
done

for action in firefox-pacman firefox-sjtu system-setup; do
    output="$(bash "$PROJECT_ROOT/modules/software.sh" "$action" 2>&1 || true)"
    printf '%s\n' "$output" | grep -Fq '该旧版系统级功能已停用' || { echo "FAIL: $action 未被阻断" >&2; exit 1; }
done

if rg -qi 'refind' "$PROJECT_ROOT/main.sh" "$PROJECT_ROOT/core/gui.sh" "$PROJECT_ROOT/README.md"; then
    echo "FAIL: 可见菜单或说明仍出现 rEFInd" >&2
    exit 1
fi

echo "PASS: rEFInd 与遗留系统级入口均不可从正常 CLI 访问"
