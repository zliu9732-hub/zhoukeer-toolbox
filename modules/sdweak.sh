#!/bin/bash
set -u
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
source "$PROJECT_ROOT/core/platform.sh"
source "$PROJECT_ROOT/core/auth.sh"
source "$PROJECT_ROOT/core/logger.sh"

SDWEAK_DMI=/sys/class/dmi/id
SDWEAK_URL=https://github.com/Taskerer/SDWEAK/releases/download/v2.1.0/SDWEAK.zip
SDWEAK_SHA256=5e91ca94577e3a999b6a8ea1a3e849bb168fedcc5b12b3cc41a00ca355d00d9e
sdweak_message() { echo "$*"; log "SDWEAK：$*"; }

sdweak_check() {
    local vendor product board version
    [ "$(uname -s)" = Linux ] && require_steamos || return 1
    [ "$(uname -m)" = x86_64 ] || return 1
    vendor="$(cat "$SDWEAK_DMI/sys_vendor" 2>/dev/null)" || return 1
    product="$(cat "$SDWEAK_DMI/product_name" 2>/dev/null)" || return 1
    board="$(cat "$SDWEAK_DMI/board_name" 2>/dev/null)" || return 1
    [ "$vendor" = Valve ] && { [ "$product:$board" = Jupiter:Jupiter ] || [ "$product:$board" = Galileo:Galileo ]; } || {
        sdweak_message "警告：仅 Steam Deck LCD / OLED 可用，其他掌机一律禁止安装。"; return 1;
    }
    [ "$(platform_os_release_value ID)" = steamos ] || return 1
    version="$(platform_os_release_value VERSION_ID)" || return 1
    case "$version" in 3.8|3.8.*) ;; *) sdweak_message "当前 SDWEAK 仅支持 SteamOS 3.8，已停止。"; return 1 ;; esac
    [ "$(id -u)" != 0 ] || { sdweak_message "请用桌面普通用户打开 Renkit。"; return 1; }
    if [ -e "$HOME/.cryo_utilities" ] || [ -e "$HOME/.local/share/cryo_utilities" ]; then
        sdweak_message "请先卸载 CryoUtilities，再安装 SDWEAK。"; return 1
    fi
}

sdweak_plan() {
    sdweak_check || return 1
    echo "可提升游戏性能、减少卡顿，效果因游戏而异。"
    echo "警告：仅 Steam Deck LCD / OLED 可用，其他掌机一律禁止安装。"
    echo "仅支持 SteamOS 3.8；请先卸载 CryoUtilities。"
    echo "需要管理员权限，会修改系统、内存和启动设置，可能影响稳定性。"
    echo "会关闭部分处理器安全保护；可选屏幕提速仅限 LCD，可能影响显示稳定性。"
    echo "不会关闭软件签名检查，不替换实验性游戏显示组件。"
    echo "中途失败可能已修改部分设置；完成后需手动重启，请先保存工作。"
    echo "作者：Taskerer / @noncatt；许可证：MIT。"
}

sdweak_execute() {
    local directory="$1" action="$2"
    (cd "$directory" && bash "$action.sh")
}

sdweak_install() (
    local workspace="" readonly_changed=0 readonly_state result install_started=0
    sdweak_cleanup() {
        result=$?
        trap - EXIT
        if [ "$readonly_changed" = 1 ] && ! toolbox_sudo steamos-readonly enable; then
            sdweak_message "恢复只读保护失败，请执行 sudo steamos-readonly enable。"
            result=1
        fi
        [ -z "$workspace" ] || rm -rf -- "$workspace"
        if [ "$result" != 0 ] && [ "$install_started" = 1 ]; then
            sdweak_message "SDWEAK 安装未完成，可能已有部分设置改变。记录：$HOME/SDWEAK-install.log"
        elif [ "$result" != 0 ]; then
            log "SDWEAK 尚未进入安装，退出码：$result"
        fi
        exit "$result"
    }
    trap sdweak_cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    sdweak_plan || exit 1
    [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ] || { sdweak_message "请在 Renkit 中阅读警告并确认安装。"; exit 1; }
    for command_name in python3 bash steamos-readonly; do require_command "$command_name" || exit 1; done
    workspace="$(mktemp -d)" || exit 1
    load_config
    sdweak_message "正在准备 SDWEAK…"
    GITEE_MIRROR_MIN_SPEED_BYTES=1024 GITEE_MIRROR_MIN_SPEED_TIME=90 \
        GITHUB_MIN_SPEED_BYTES=1024 GITHUB_MIN_SPEED_TIME=90 \
        download_with_gitee_mirror_fallback sdweak "$SDWEAK_URL" "$SDWEAK_SHA256" \
        "$workspace/SDWEAK.zip" SDWEAK || {
            sdweak_message "SDWEAK 下载未完成，尚未开始安装。详细记录：$LOG_FILE"
            exit 1
        }
    python3 "$PROJECT_ROOT/scripts/prepare_sdweak.py" "$workspace/SDWEAK.zip" "$workspace/package" || exit 1
    # 再次检查，确保下载期间机型或系统信息没有变化。
    sdweak_check || exit 1
    readonly_state="$(LC_ALL=C steamos-readonly status)" || exit 1
    case "$readonly_state" in
        enabled) readonly_changed=1 ;;
        disabled) ;;
        *) sdweak_message "无法确认系统保护状态，已停止。"; exit 1 ;;
    esac
    toolbox_sudo true || exit 1
    sdweak_message "正在安装 SDWEAK，请按中文提示选择可选功能…"
    install_started=1
    sdweak_execute "$workspace/package/SDWEAK" install || exit 1
    sdweak_message "SDWEAK 安装完成，请保存工作后手动重启。"
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        plan|check) sdweak_plan ;;
        install) sdweak_install ;;
        *) echo "用法：$0 {plan|check|install}"; exit 1 ;;
    esac
fi
