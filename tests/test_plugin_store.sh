#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq 'https://www.mhhf.com/Deck/install.sh' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'e7c504485bccbc223d8aaab5b45e7214362ece97fdb279bde336bd872aa3e4b0' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'bash "$installer"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_LSFG_URL=""' "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_FSR4_URL=""' "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_CHEATDECK_URL=""' "$PROJECT_ROOT/config/settings.example.conf"

output="$(bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg || true)"
printf '%s\n' "$output" | grep -Fq '123云盘国内分流正在整理'

echo "PASS: Decky国内源和插件分流占位检查通过"
