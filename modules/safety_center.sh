#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

show_safety_guide() {
    echo "======新手安全说明======"
    echo "绿色：体检、诊断、攻略和日志只读取信息，不修改系统。"
    echo "黄色：软件、插件和兼容层安装会写入当前用户目录，可在对应软件内卸载。"
    echo "红色：系统密码、ToDesk、Steam 加速器和双系统设置会改动系统或启动配置。"
    echo "红色操作都会保留确认页面；看不懂时直接返回，不要连续点击。"
    echo "工具箱不会在后台自动清理游戏、兼容数据或系统文件。"
    log "已查看新手安全说明"
}

export_records() {
    local report_file="$HOME/Desktop/周克儿工具箱操作记录.txt"

    mkdir -p "$HOME/Desktop" || return 1
    {
        echo "======周克儿工具箱操作记录======"
        echo "导出时间：$(date '+%Y-%m-%d %H:%M:%S')"
        echo "说明：记录用于排查，不会包含系统密码。"
        echo ""
        if [ -s "$LOG_FILE" ]; then
            tail -n 80 "$LOG_FILE"
        else
            echo "暂无操作记录。"
        fi
    } | tee "$report_file"

    echo "操作记录已保存到：$report_file"
    log "已导出操作记录"
}

case "${1:-}" in
    guide) show_safety_guide ;;
    records) export_records ;;
    *) echo "用法: $0 [guide|records]"; exit 1 ;;
esac
