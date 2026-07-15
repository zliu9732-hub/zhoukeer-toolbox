#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

REPORT_FILE="$HOME/Desktop/周克儿游戏启动诊断报告.txt"
STEAM_ROOT=""
PASS_COUNT=0
WARN_COUNT=0

pass() {
    echo "✓ $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
    echo "! $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

find_steam_root() {
    local candidate
    for candidate in "$HOME/.steam/steam" "$HOME/.local/share/Steam"; do
        if [ -d "$candidate/steamapps" ]; then
            STEAM_ROOT="$candidate"
            return 0
        fi
    done
    return 1
}

check_storage() {
    local free_kb
    free_kb="$(df -Pk "$STEAM_ROOT" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    if [ "${free_kb:-0}" -ge 10485760 ]; then
        pass "Steam 游戏库所在磁盘剩余空间充足"
    else
        warn "Steam 游戏库可用空间不足 10GB，游戏更新或启动可能失败"
    fi
}

check_compatibility_tools() {
    local tool_dir
    local tool_count=0
    for tool_dir in "$HOME/.steam/root/compatibilitytools.d" "$HOME/.local/share/Steam/compatibilitytools.d"; do
        if [ -d "$tool_dir" ]; then
            tool_count=$((tool_count + $(find "$tool_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)))
        fi
    done

    if [ "$tool_count" -gt 0 ]; then
        pass "检测到 $tool_count 个自定义 Proton / GE 兼容层"
    else
        warn "未检测到自定义兼容层；个别游戏可在工具箱安装 GE-Proton 后重试"
    fi
}

run_diagnosis() {
    mkdir -p "$HOME/Desktop" || exit 1
    exec > >(tee "$REPORT_FILE") 2>&1

    echo "======周克儿游戏启动诊断======"
    echo "时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo "说明：本诊断不会删除游戏、兼容数据或缓存。"

    if ! find_steam_root; then
        warn "未找到 Steam 游戏库；请先启动一次 Steam，再重新运行诊断"
        echo "体检结果：0 项正常，$WARN_COUNT 项需要留意"
        echo "报告已保存到：$REPORT_FILE"
        exit 0
    fi

    pass "已找到 Steam 游戏库：$STEAM_ROOT"
    check_storage

    if pgrep -x steam >/dev/null 2>&1 || pgrep -f 'steamwebhelper' >/dev/null 2>&1; then
        pass "Steam 当前正在运行"
    else
        warn "Steam 当前未运行；请完全退出并重新启动 Steam 后再试游戏"
    fi

    if [ -d "$STEAM_ROOT/steamapps/compatdata" ]; then
        compatdata_count="$(find "$STEAM_ROOT/steamapps/compatdata" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
        pass "检测到 $compatdata_count 份游戏兼容数据"
    else
        warn "未找到兼容数据目录；尚未运行 Proton 游戏或 Steam 库未完整初始化"
    fi

    check_compatibility_tools

    if [ -d "$STEAM_ROOT/logs" ]; then
        pass "Steam 日志目录可用：$STEAM_ROOT/logs"
    else
        warn "未找到 Steam 日志目录；启动一次 Steam 后会自动创建"
    fi

    echo "体检结果：$PASS_COUNT 项正常，$WARN_COUNT 项需要留意"
    echo "下一步：若只有个别游戏打不开，请先在 Steam 游戏属性中切换 Proton 版本；仍失败时再清理该游戏的兼容数据。"
    echo "报告已保存到：$REPORT_FILE"
    log "已执行游戏启动诊断: 正常=$PASS_COUNT 警告=$WARN_COUNT"
}

case "${1:-}" in
    diagnose|"") run_diagnosis ;;
    *) echo "用法: $0 [diagnose]"; exit 1 ;;
esac
