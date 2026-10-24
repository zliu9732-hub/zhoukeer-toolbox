#!/bin/bash
set -u
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
source "$PROJECT_ROOT/core/platform.sh"
source "$PROJECT_ROOT/core/auth.sh"
source "$PROJECT_ROOT/core/logger.sh"

ROG_X20_SOURCE="$PROJECT_ROOT/third_party/rc74xa-offline-20261024"

rog_x20_verify() {
    require_command python3 || return 1
    python3 -I -B "$PROJECT_ROOT/scripts/verify_rog_x20_package.py" "$ROG_X20_SOURCE"
}

rog_x20_plan() {
    [ "$(uname -s)" = Linux ] && require_steamos || {
        echo "此修复仅适用于 ROG 20 周年 RC74XA 的 SteamOS。"; return 1;
    }
    rog_x20_verify || return 1
    python3 -I -B "$ROG_X20_SOURCE/installer.py" plan || return 1
    echo "修复声音、右侧快捷菜单，以及唤醒后的声音和按键异常。"
    echo "仅 RC74XA，SteamOS 3.9.3，BIOS .301/.303，指定 7.2.7 内核。"
    echo "不包含振动、HDR、亮度和完整手柄识别修复。"
    echo "需要管理员权限，会修改当前系统的启动与声音设置，并安装 X20 Fixes 插件。"
    echo "缺少插件商城时会先安装；已有商城沿用原安装流程，其他插件保留。"
    echo "包含实验性内核组件，可能影响启动或声音稳定性；失败会尝试恢复备份。"
    echo "系统或 BIOS 更新前请先撤销本修复；完成后手动重启，请先保存工作。"
    echo "作者：hungarianhc、ovenham；保留原许可证。"
}

rog_x20_run() {
    local step="$1"; shift
    echo "$step"
    log "ROG 20 周年修复：$step"
    if "$@" >> "$LOG_FILE" 2>&1; then return 0; fi
    echo "此步骤未完成，详细记录：$LOG_FILE"
    return 1
}

rog_x20_install() {
    rog_x20_plan || return 1
    [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ] || {
        echo "请先从 Renkit 阅读风险说明并确认。"; return 1;
    }
    [ "$(id -u)" != 0 ] || { echo "请使用普通桌面用户打开 Renkit。"; return 1; }
    rog_x20_run "正在检查修复所需条件…" toolbox_sudo python3 -I -B "$ROG_X20_SOURCE/installer.py" check || return 1
    rog_x20_run "正在准备插件商城…" bash "$PROJECT_ROOT/modules/plugin_store.sh" ensure-store || return 1
    rog_x20_run "正在修复声音、快捷菜单与唤醒功能，请勿关机…" \
        toolbox_sudo python3 -I -B "$ROG_X20_SOURCE/installer.py" install || {
        echo "修复未完成，可能已有部分改动；请保留备份并查看记录。"; return 1;
    }
    echo "ROG 20 周年修复已部署，请保存工作后手动重启。"
    echo "重启后在游戏模式检查声音、右侧快捷菜单和休眠唤醒。"
}

rog_x20_restore() {
    [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ] || { echo "请先确认撤销修复。"; return 1; }
    [ "$(uname -s)" = Linux ] && require_steamos || return 1
    rog_x20_verify || return 1
    rog_x20_run "正在恢复修复前的文件，请勿关机…" toolbox_sudo python3 -I -B "$ROG_X20_SOURCE/installer.py" uninstall || return 1
    echo "已撤销本修复，请手动重启。插件商城与其他插件保留。"
}

rog_x20_status() {
    [ "$(uname -s)" = Linux ] && require_steamos || return 1
    rog_x20_verify || return 1
    toolbox_sudo python3 -I -B "$ROG_X20_SOURCE/installer.py" status
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-plan}" in
        plan) rog_x20_plan ;;
        install) rog_x20_install ;;
        status) rog_x20_status ;;
        restore) rog_x20_restore ;;
        *) echo "用法：$0 {plan|install|status|restore}"; exit 1 ;;
    esac
fi
