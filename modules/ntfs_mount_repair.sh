#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dual_system.sh"

ntfs_repair_run() {
    local -a statuses
    ensure_runtime_dirs
    log "游戏盘挂载修复命令: $*"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    statuses=("${PIPESTATUS[@]}")
    [ "${statuses[1]}" -eq 0 ] || return 1
    return "${statuses[0]}"
}

ntfs_repair_device_valid() {
    case "$1" in /dev/*) ;; *) return 1 ;; esac
    case "${1#/dev/}" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
    [ -b "$1" ] || return 1
    [ "$(lsblk -dnro TYPE "$1")" = part ] || return 1
    case "$(lsblk -dnro FSTYPE "$1")" in ntfs|ntfs3) ;; *) return 1 ;; esac
    # 已挂载的盘不属于此入口，避免卸载正在使用的系统或游戏库。
    ! findmnt -rn -S "$1" >/dev/null 2>&1
}

ntfs_repair_mount_target() {
    printf '/run/media/%s/Renkit-%s\n' "$(id -un)" "$1"
}

ntfs_repair_select_device() {
    local device kind filesystem selected label size description index
    local -a candidates=() descriptions=() choices=()
    if ! command -v kdialog >/dev/null 2>&1 || [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        echo "请在 SteamOS 桌面模式打开 Renkit，以点击选择需要修复的游戏盘。" >&2
        return 1
    fi
    while read -r device kind filesystem; do
        [ "$kind" = part ] || continue
        case "$filesystem" in ntfs|ntfs3) ;; *) continue ;; esac
        ntfs_repair_device_valid "$device" || continue
        label="$(lsblk -dnro LABEL "$device" | tr -d '\r\n' | tr '\t' ' ')"
        size="$(lsblk -dnro SIZE "$device" | tr -d '\r\n\t')"
        description="${label:-未命名游戏盘}｜容量：${size:-未知}｜$device"
        index=${#candidates[@]}
        candidates+=("$device")
        descriptions+=("$description")
        choices+=("$index" "$description")
    done < <(lsblk -rpn -o NAME,TYPE,FSTYPE)
    [ "${#candidates[@]}" -gt 0 ] || {
        echo "没有找到未挂载的 NTFS 分区；已挂载的盘请使用原有挂载或写入修复入口。" >&2
        return 1
    }
    selected="$(kdialog --title "修复游戏盘挂载失败" \
        --menu "请选择无法打开的游戏盘（名称｜容量｜位置）。\n请勿选择 Windows 系统盘。" \
        "${choices[@]}" --ok-label "选择此盘" --cancel-label "取消")" || {
        echo "已取消，未修改游戏盘。" >&2
        return 1
    }
    # 对话框返回值只映射到本次候选，不能直接作为设备路径或数组表达式使用。
    for ((index=0; index<${#candidates[@]}; index++)); do
        if [ "$selected" = "$index" ]; then
            device="${candidates[$index]}"
            kdialog --title "确认修复游戏盘" --warningyesno \
                "所选游戏盘：${descriptions[$index]}\n\n需要管理员权限，可能安装修复组件并临时解除系统只读保护。\n修复会修改文件系统元数据，重要数据请先备份。\n不会格式化，也不会自动重启。\n\n确认修复这个游戏盘？" \
                --yes-label "确认修复" --no-label "取消" || {
                echo "已取消，未修改游戏盘。" >&2
                return 1
            }
            ntfs_repair_device_valid "$device" || {
                echo "所选游戏盘的状态已变化，请返回重新选择。" >&2
                return 1
            }
            printf '%s\n' "$device"
            return 0
        fi
    done
    echo "未选择有效的游戏盘，已取消。" >&2
    return 1
}

ntfs_repair_install_tools() (
    local changed=0 state
    local -a packages=(ntfs-3g)
    command -v ntfsfix >/dev/null && command -v ntfs-3g >/dev/null && exit 0
    ntfs_repair_install_cleanup() {
        local status=$?
        trap - EXIT
        if [ "$changed" -eq 1 ]; then
            if ! ntfs_repair_run toolbox_sudo steamos-readonly enable; then
                echo "恢复系统只读保护失败，请执行 sudo steamos-readonly enable。" >&2
                status=1
            fi
        fi
        exit "$status"
    }
    trap ntfs_repair_install_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    require_command pacman || exit 1
    require_command steamos-readonly || exit 1
    state="$(LC_ALL=C steamos-readonly status)" || exit 1
    case "$state" in
        enabled)
            changed=1
            ntfs_repair_run toolbox_sudo steamos-readonly disable || exit 1
            ;;
        disabled) ;;
        *) echo "无法确认系统只读保护状态，已停止。"; exit 1 ;;
    esac
    # 新版拆包，旧版仍由 ntfs-3g 提供；不刷新仓库或升级整个系统。
    if pacman -Si ntfsprogs >/dev/null 2>&1; then packages+=(ntfsprogs); fi
    echo "正在准备游戏盘修复组件……"
    ntfs_repair_run toolbox_sudo pacman -S --noconfirm "${packages[@]}" || exit 1
    command -v ntfsfix >/dev/null && command -v ntfs-3g >/dev/null || {
        echo "修复组件不完整，已停止；请提供日志。"
        exit 1
    }
)

repair_ntfs_mount() (
    local device probe="" target="" uuid options child name contents
    local probe_mounted=0 target_created=0
    require_steamos || exit 1
    for name in lsblk findmnt mount umount mktemp tee; do require_command "$name" || exit 1; done
    device="$(ntfs_repair_select_device)" || exit 1
    log "用户已确认游戏盘挂载修复: $device"
    ntfs_repair_install_tools || exit 1
    ntfs_repair_device_valid "$device" || { echo "目标分区状态已变化，已停止。"; exit 1; }
    ntfs_repair_cleanup() {
        local status=$?
        trap - EXIT
        if [ "$probe_mounted" -eq 1 ]; then
            if ntfs_repair_run toolbox_sudo umount "$probe"; then probe_mounted=0; else status=1; fi
        fi
        if [ -n "$probe" ] && [ "$probe_mounted" -eq 0 ]; then rmdir -- "$probe" || true; fi
        if [ "$target_created" -eq 1 ] && ! findmnt -rn -M "$target" >/dev/null 2>&1; then
            toolbox_sudo rmdir -- "$target" || true
        fi
        [ "$status" -eq 0 ] || log "游戏盘挂载修复未完成: $device status=$status"
        exit "$status"
    }
    trap ntfs_repair_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    probe="$(mktemp -d)" || exit 1
    echo "正在只读检查所选分区……"
    ntfs_repair_run toolbox_sudo ntfs-3g -o ro,norecover "$device" "$probe" || {
        echo "无法只读检查此盘，未执行修复。请进入 Windows 对该盘运行 chkdsk /f 后完整关机。"
        exit 1
    }
    probe_mounted=1
    [ -r "$probe" ] && [ -x "$probe" ] || { echo "无法读取分区目录，未执行修复。"; exit 1; }
    # 不依赖卷标猜测，检查实际目录，大小写不敏感。
    for child in "$probe"/*; do
        name="$(basename "$child" | tr '[:upper:]' '[:lower:]')"
        if [ "$name" = windows ] && [ -d "$child" ]; then
            echo "所选分区包含 Windows 目录，已拒绝修改。"
            exit 1
        fi
    done
    ntfs_repair_run toolbox_sudo umount "$probe" || exit 1
    probe_mounted=0
    ntfs_repair_device_valid "$device" || exit 1
    echo "正在修复游戏盘……"
    ntfs_repair_run toolbox_sudo ntfsfix "$device" || {
        echo "基础修复未完成。若提示休眠，请进入 Windows 完整关机；不要强制删除休眠文件。"
        exit 1
    }
    uuid="$(lsblk -dnro UUID "$device")" || exit 1
    case "$uuid" in ''|*[!A-Za-z0-9-]*) echo "无法确认分区标识，未执行挂载。"; exit 1 ;; esac
    target="$(ntfs_repair_mount_target "$uuid")" || exit 1
    [ ! -L "$target" ] || exit 1
    if findmnt -rn -M "$target" >/dev/null 2>&1; then
        echo "目标目录已被其他挂载占用，已停止。"
        exit 1
    fi
    if [ -e "$target" ]; then
        [ -d "$target" ] || exit 1
        contents="$(ls -A -- "$target")" || exit 1
        [ -z "$contents" ] || { echo "目标目录已被占用，已停止。"; exit 1; }
    else
        toolbox_sudo mkdir -p -- "$target" || exit 1
        target_created=1
    fi
    echo "正在重新挂载游戏盘……"
    ntfs_repair_run toolbox_sudo mount -t ntfs-3g -o "uid=$(id -u),gid=$(id -g),umask=022,norecover" "$device" "$target" || exit 1
    [ "$(shared_drive_mountpoint "$device")" = "$target" ] || exit 1
    options="$(findmnt -rn -S "$device" -o OPTIONS)"
    case ",$options," in
        *,rw,*) ;;
        *) echo "游戏盘仅以只读方式打开；请进入 Windows 检查并完整关机后重试。"; exit 1 ;;
    esac
    create_shared_drive_shortcut "$target" || exit 1
    echo "游戏盘已恢复挂载：$target"
    echo "可从家目录中的“互通盘”打开。重启后如再次无法打开，可重新使用本入口。"
    log "游戏盘挂载修复完成: $device -> $target"
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then repair_ntfs_mount; fi
