#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$HOME/.local/share/konsole/ZhoukeerToolbox.profile"
WINDOW_SIZE="1220x740"

if ! command -v konsole >/dev/null 2>&1; then
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --error "未找到 Konsole，无法启动周克儿工具箱。"
    fi
    exit 1
fi

launch_basic() {
    exec konsole \
        --geometry "$WINDOW_SIZE" \
        --workdir "$PROJECT_ROOT" \
        -e env ZHOUKEER_LAUNCHED=1 bash "$PROJECT_ROOT/main.sh" --touch
}

# SteamOS 不同版本捆绑的 Konsole 参数不完全一致。
# 只在当前版本明确提供 --profile 时启用大字体与背景主题；
# 否则回退到已在 Steam Deck 真机运行过的基础启动参数。
if [ -f "$PROFILE_FILE" ] && \
    konsole --help 2>/dev/null | grep -q -- '--profile'; then
    konsole \
        --profile "$PROFILE_FILE" \
        --geometry "$WINDOW_SIZE" \
        --workdir "$PROJECT_ROOT" \
        -e env ZHOUKEER_LAUNCHED=1 bash "$PROJECT_ROOT/main.sh" --touch
    launch_status=$?

    if [ "$launch_status" -eq 0 ]; then
        exit 0
    fi
fi

launch_basic
