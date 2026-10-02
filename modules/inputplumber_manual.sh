#!/bin/bash

# 用户确认的 SteamOS 手动方案：软件包更新、固定官方包备用、启用并重载。
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
source "$PROJECT_ROOT/core/platform.sh"
source "$PROJECT_ROOT/core/logger.sh"
source "$PROJECT_ROOT/core/auth.sh"

IPU_OFFICIAL_URL=https://github.com/ShadowBlip/InputPlumber/releases/download/v0.81.0/inputplumber-x86_64.tar.gz
IPU_OFFICIAL_SHA256=bb167707964777751ad15f2da0ac99eb16a926a3997098e884f749b2e06f777b

ipu_runtime_version() {
    local output version
    output="$(/usr/bin/inputplumber --version 2>/dev/null)" || return 1
    read -r _ version _ <<< "$output"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s\n' "$version"
}

ipu_manual_plan() {
    [ "$(uname -s)" = Linux ] && require_steamos || {
        ipu_message "这项手动更新仅适用于 SteamOS。"; return 1;
    }
    [ "$(uname -m)" = x86_64 ] || { ipu_message "当前机器不适用于这个更新包。"; return 1; }
    if systemctl is-active --quiet hhd.service 2>/dev/null; then
        ipu_message "请先关闭 HHD，再更新手柄功能，避免两套控制程序冲突。"; return 1
    fi
    local service state
    for service in inputplumber.service inputplumber-suspend.service; do
        state="$(systemctl is-enabled "$service" 2>/dev/null || true)"
        case "$state" in masked*) ipu_message "手柄功能被系统禁止启动，请先检查原设置。"; return 1 ;; esac
    done
    echo "需要管理员权限，会更新并启用手柄功能及睡眠支持，手柄可能短暂断开。"
    echo "当前版本低于 0.78.0 或无法读取时，备用安装官方 0.81.0，并备份被替换文件。"
    echo "会更新官方机型配置，保留 /etc 下的自定义配置；系统更新后可能需要重新更新。"
    echo "会暂时关闭系统只读保护，结束时恢复原状态。完成后请完整关机再开机。"
}

ipu_manual_run() {
    log "InputPlumber 手动执行：$*"
    if "$@" >> "$LOG_FILE" 2>&1; then return 0; fi
    ipu_message "当前步骤失败，详细记录：$LOG_FILE"
    return 1
}

ipu_manual_update() (
    local workspace="" backup="" readonly_changed=0 changed=0 status version=""
    local active=0 enabled=0 suspend_enabled=0
    ipu_manual_cleanup() {
        local result=$?
        trap - EXIT
        if [ "$result" -ne 0 ] && [ "$changed" = 1 ]; then
            ipu_manual_run toolbox_sudo systemctl stop inputplumber.service || true
            if [ -n "$backup" ]; then
                if ! ipu_manual_run toolbox_sudo python3 "$PROJECT_ROOT/scripts/inputplumber_overlay.py" restore "$backup"; then
                    ipu_message "恢复旧文件失败，备份保留在：$backup"
                fi
                if command -v systemd-hwdb >/dev/null 2>&1; then
                    ipu_manual_run toolbox_sudo systemd-hwdb update || true
                else
                    ipu_manual_run toolbox_sudo udevadm hwdb --update || true
                fi
                ipu_manual_run toolbox_sudo udevadm control --reload-rules || true
                ipu_manual_run toolbox_sudo udevadm trigger --action=change --subsystem-match=input || true
            fi
            ipu_manual_run toolbox_sudo systemctl daemon-reload || true
            if [ "$enabled" = 1 ]; then
                ipu_manual_run toolbox_sudo systemctl enable inputplumber.service || true
            else
                ipu_manual_run toolbox_sudo systemctl disable inputplumber.service || true
            fi
            if [ "$suspend_enabled" = 1 ]; then
                ipu_manual_run toolbox_sudo systemctl enable inputplumber-suspend.service || true
            else
                ipu_manual_run toolbox_sudo systemctl disable inputplumber-suspend.service || true
            fi
            if [ "$active" = 1 ]; then
                ipu_manual_run toolbox_sudo systemctl restart inputplumber.service || true
            fi
        fi
        if [ "$readonly_changed" = 1 ] && ! toolbox_sudo steamos-readonly enable; then
            ipu_message "恢复只读保护失败，请执行 sudo steamos-readonly enable。"
            result=1
        fi
        [ -z "$workspace" ] || rm -rf -- "$workspace"
        [ "$result" = 0 ] || ipu_message "手柄功能更新未完成，请查看上方提示。"
        exit "$result"
    }
    trap ipu_manual_cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    ipu_manual_plan || exit 1
    [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ] || { ipu_message "请从掌机适配进入，阅读说明并确认更新。"; exit 1; }
    for command_name in python3 pacman vercmp systemctl udevadm steamos-readonly; do
        require_command "$command_name" || exit 1
    done
    systemctl is-active --quiet inputplumber.service && active=1
    systemctl is-enabled --quiet inputplumber.service && enabled=1
    systemctl is-enabled --quiet inputplumber-suspend.service && suspend_enabled=1
    workspace="$(mktemp -d)" || exit 1
    status="$(LC_ALL=C steamos-readonly status)" || exit 1
    case "$status" in
        enabled) readonly_changed=1; toolbox_sudo steamos-readonly disable || exit 1 ;;
        disabled) ;;
        *) ipu_message "无法确认只读保护状态，已停止。"; exit 1 ;;
    esac
    ipu_message "正在检查手柄程序更新…"
    version="$(ipu_runtime_version || true)"
    # 保留原有防部分升级检查；不执行 -Syy 后单独升级一个系统包。
    ipu_check manual || exit 1
    if [ "$IPU_CHECK_STATE" = upgrade ] && \
        { [ -z "$version" ] || [ "$(vercmp "$IPU_CANDIDATE" "$version")" -gt 0 ]; }; then
        ipu_upgrade_package || exit 1
    fi
    version="$(ipu_runtime_version || true)"
    if [ -z "$version" ] || [ "$(vercmp "$version" 0.78.0)" -lt 0 ]; then
        ipu_message "正在准备手柄功能 0.81.0…"
        load_config
        download_github_file "$IPU_OFFICIAL_URL" "$workspace/inputplumber.tar.gz" \
            "$IPU_OFFICIAL_SHA256" "InputPlumber 0.81.0" || exit 1
        python3 "$PROJECT_ROOT/scripts/inputplumber_overlay.py" verify "$workspace/inputplumber.tar.gz" || exit 1
        changed=1
        ipu_manual_run toolbox_sudo systemctl stop inputplumber.service || exit 1
        backup="$(toolbox_sudo python3 "$PROJECT_ROOT/scripts/inputplumber_overlay.py" install "$workspace/inputplumber.tar.gz")" || exit 1
        log "InputPlumber 0.81.0 备份：$backup"
        version="$(ipu_runtime_version)" || exit 1
        [ "$version" = 0.81.0 ] || { ipu_message "更新后的程序版本不符合预期。"; exit 1; }
    fi
    changed=1
    ipu_message "正在启用并重新加载手柄功能…"
    ipu_manual_run toolbox_sudo systemctl daemon-reload || exit 1
    if command -v systemd-hwdb >/dev/null 2>&1; then
        ipu_manual_run toolbox_sudo systemd-hwdb update || exit 1
    else
        ipu_manual_run toolbox_sudo udevadm hwdb --update || exit 1
    fi
    ipu_manual_run toolbox_sudo udevadm control --reload-rules || exit 1
    # 只刷新输入设备，不对网卡、磁盘等全系统设备发送 remove/add。
    ipu_manual_run toolbox_sudo udevadm trigger --action=change --subsystem-match=input || exit 1
    ipu_manual_run toolbox_sudo systemctl enable inputplumber.service || exit 1
    ipu_manual_run toolbox_sudo systemctl enable inputplumber-suspend.service || exit 1
    ipu_manual_run toolbox_sudo systemctl restart inputplumber.service || exit 1
    ipu_manual_run systemctl is-active --quiet inputplumber.service || exit 1
    version="$(ipu_runtime_version)" || exit 1
    ipu_message "更新完成，当前版本 ${version}。请保存工作，完整关机后再开机。"
)
