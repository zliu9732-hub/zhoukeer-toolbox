#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq 'https://www.mhhf.com/Deck/install.sh' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'e7c504485bccbc223d8aaab5b45e7214362ece97fdb279bde336bd872aa3e4b0' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'bash "$installer"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_LSFG_SHA256="5355c6df656775fa467445c7787604bc159b8d8b97e5364bedb02a5d2e0ab677"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_FSR4_SHA256="236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_CHEATDECK_SHA256="83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'install_tree_atomically' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '请去 Steam 支持正版并安装 Lossless Scaling' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'steam://store/993090' "$PROJECT_ROOT/modules/plugin_store.sh"

output="$(bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg || true)"
printf '%s\n' "$output" | grep -Fq '仅支持真实 SteamOS 环境'

echo "PASS: Decky国内源和三个插件一键安装配置检查通过"
