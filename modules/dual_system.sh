#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

load_config

DUAL_BOOT_TIMEOUT="${DUAL_BOOT_TIMEOUT:-5}"
SHARED_DRIVE_LINK="${ZHOUKEER_SHARED_DRIVE_LINK:-$HOME/互通盘}"

require_steamos() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "${ZHOUKEER_ALLOW_NON_STEAMOS:-0}" != "1" ]; then
        echo "此功能仅支持真实 SteamOS 环境。"
        return 1
    fi
}

is_shared_filesystem() {
    case "$1" in
        ntfs|ntfs3|exfat) return 0 ;;
        *) return 1 ;;
    esac
}

canonical_directory() {
    (cd "$1" 2>/dev/null && pwd -P)
}

find_shared_drive_device() {
    local include_mounted="${1:-0}"
    local requested="${ZHOUKEER_SHARED_DRIVE_DEVICE:-}"
    local device
    local type
    local filesystem
    local mountpoint
    local candidate=""
    local candidate_count=0

    if [ -n "$requested" ]; then
        case "$requested" in
            /dev/*) ;;
            *)
                echo "指定的互通盘设备无效：$requested"
                return 1
                ;;
        esac
        filesystem="$(lsblk -nro FSTYPE "$requested" 2>/dev/null | head -n 1)"
        if ! is_shared_filesystem "$filesystem"; then
            echo "指定设备不是 NTFS 或 exFAT 互通盘：$requested"
            return 1
        fi
        printf '%s\n' "$requested"
        return 0
    fi

    while IFS=' ' read -r device type filesystem mountpoint; do
        [ "$type" = "part" ] || continue
        if [ "$include_mounted" != "1" ] && [ -n "$mountpoint" ]; then
            continue
        fi
        is_shared_filesystem "$filesystem" || continue
        candidate="$device"
        candidate_count=$((candidate_count + 1))
    done < <(lsblk -rpn -o NAME,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null)

    if [ "$candidate_count" -eq 0 ]; then
        echo "没有发现未挂载的 NTFS 或 exFAT 互通盘。"
        return 1
    fi
    if [ "$candidate_count" -gt 1 ]; then
        echo "发现多个可挂载分区，为避免挂错盘已停止。"
        echo "请只保留目标互通盘后重试，或设置 ZHOUKEER_SHARED_DRIVE_DEVICE 指定设备。"
        return 1
    fi
    printf '%s\n' "$candidate"
}

extract_udisks_mountpoint() {
    sed -n 's/^Mounted .* at \(.*\)\.$/\1/p' | tail -n 1
}

mount_shared_drive_device() {
    local device="$1"
    local options="${2:-}"
    local output
    local mountpoint

    if [ -n "$options" ]; then
        output="$(udisksctl mount --block-device "$device" --options "$options" 2>&1)" || {
            printf '%s\n' "$output"
            return 1
        }
    else
        output="$(udisksctl mount --block-device "$device" 2>&1)" || {
            printf '%s\n' "$output"
            return 1
        }
    fi
    mountpoint="$(printf '%s\n' "$output" | extract_udisks_mountpoint)"
    if [ -z "$mountpoint" ] || [ ! -d "$mountpoint" ]; then
        printf '%s\n' "$output"
        return 1
    fi
    printf '%s\n' "$mountpoint"
}

create_shared_drive_shortcut() {
    local mountpoint="$1"
    local existing_target

    if [ -L "$SHARED_DRIVE_LINK" ]; then
        existing_target="$(canonical_directory "$SHARED_DRIVE_LINK" || true)"
        if [ "$existing_target" = "$(canonical_directory "$mountpoint" || true)" ]; then
            return 0
        fi
        rm -f -- "$SHARED_DRIVE_LINK" || return 1
    elif [ -e "$SHARED_DRIVE_LINK" ]; then
        echo "已挂载到：$mountpoint"
        echo "未创建快捷入口，因为以下路径已被占用：$SHARED_DRIVE_LINK"
        return 0
    fi

    ln -s -- "$mountpoint" "$SHARED_DRIVE_LINK" || return 1
}

mount_shared_drive() {
    local device
    local mountpoint

    require_steamos || return 1
    for command_name in lsblk udisksctl; do
        require_command "$command_name" || return 1
    done

    device="$(find_shared_drive_device 0)" || return 1
    echo "正在挂载互通盘：$device"
    mountpoint="$(mount_shared_drive_device "$device")" || {
        echo "互通盘挂载失败。"
        return 1
    }

    create_shared_drive_shortcut "$mountpoint" || return 1
    echo "互通盘已挂载：$mountpoint"
    echo "桌面模式可通过“$SHARED_DRIVE_LINK”快速访问。"
    log "互通盘已挂载: $device -> $mountpoint"
}

shared_drive_mountpoint() {
    local device="$1"

    findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n 1
}

shared_drive_is_readonly() {
    local device="$1"
    local options

    options="$(findmnt -rn -S "$device" -o OPTIONS 2>/dev/null | head -n 1)"
    case ",$options," in
        *,ro,*) return 0 ;;
        *) return 1 ;;
    esac
}

mount_shared_drive_with_protection() {
    local device
    local mountpoint

    require_steamos || return 1
    for command_name in lsblk udisksctl findmnt; do
        require_command "$command_name" || return 1
    done

    device="$(find_shared_drive_device 1)" || return 1
    mountpoint="$(shared_drive_mountpoint "$device" || true)"
    if [ -n "$mountpoint" ] && shared_drive_is_readonly "$device"; then
        create_shared_drive_shortcut "$mountpoint" || return 1
        echo "互通盘已经处于只读保护状态：$mountpoint"
        return 0
    fi
    if [ -n "$mountpoint" ]; then
        echo "正在重新挂载互通盘为只读模式..."
        udisksctl unmount --block-device "$device" >/dev/null || {
            echo "无法卸载当前互通盘，请先关闭正在使用该盘的程序。"
            return 1
        }
    fi
    mountpoint="$(mount_shared_drive_device "$device" ro)" || {
        echo "互通盘只读保护未启用。"
        return 1
    }
    create_shared_drive_shortcut "$mountpoint" || return 1
    echo "互通盘已启用只读保护：$mountpoint"
    echo "SteamOS 下将无法写入或删除该盘文件；需要写入时请选择“恢复互通盘写入”。"
    log "互通盘只读保护已启用: $device -> $mountpoint"
}

restore_shared_drive_write() {
    local device
    local mountpoint

    require_steamos || return 1
    for command_name in lsblk udisksctl findmnt; do
        require_command "$command_name" || return 1
    done

    device="$(find_shared_drive_device 1)" || return 1
    mountpoint="$(shared_drive_mountpoint "$device" || true)"
    if [ -n "$mountpoint" ]; then
        echo "正在恢复互通盘写入..."
        udisksctl unmount --block-device "$device" >/dev/null || {
            echo "无法卸载当前互通盘，请先关闭正在使用该盘的程序。"
            return 1
        }
    fi
    mountpoint="$(mount_shared_drive_device "$device")" || {
        echo "互通盘恢复写入失败。"
        return 1
    }
    create_shared_drive_shortcut "$mountpoint" || return 1
    echo "互通盘已恢复可写状态：$mountpoint"
    log "互通盘已恢复可写: $device -> $mountpoint"
}

resolve_boot_path() {
    local configured="${ZHOUKEER_BOOT_PATH:-}"
    local candidate

    if [ -n "$configured" ]; then
        [ -d "$configured" ] || {
            echo "指定的启动分区目录不存在：$configured"
            return 1
        }
        printf '%s\n' "$configured"
        return 0
    fi

    if command -v bootctl >/dev/null 2>&1; then
        for candidate in "$(bootctl --print-boot-path 2>/dev/null || true)" \
            "$(bootctl --print-esp-path 2>/dev/null || true)"; do
            [ -d "$candidate" ] || continue
            printf '%s\n' "$candidate"
            return 0
        done
    fi

    for candidate in /esp /boot/efi /efi /boot; do
        if [ -d "$candidate/loader" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    echo "未找到 systemd-boot 的启动分区。"
    return 1
}

validate_systemd_boot() {
    local boot_path="$1"

    if [ ! -d "$boot_path/loader" ]; then
        echo "启动分区缺少 loader 目录，已停止。"
        return 1
    fi

    # SteamOS 的 bootctl 可能因当前 ESP 识别方式返回非零，但已解析到的
    # loader 目录才是本次唯一要修改的位置，不能因此误报双引导操作失败。
    if command -v bootctl >/dev/null 2>&1 && ! bootctl is-installed >/dev/null 2>&1; then
        echo "提示：bootctl 未确认当前 ESP；将只修改已找到的 loader.conf。"
    fi
}

write_loader_timeout() {
    local timeout="$1"
    local boot_path
    local loader_conf
    local temporary
    local backup

    case "$timeout" in
        ''|*[!0-9]*)
            echo "引导等待时间必须是非负整数。"
            return 1
            ;;
    esac

    require_steamos || return 1
    boot_path="$(resolve_boot_path)" || return 1
    validate_systemd_boot "$boot_path" || return 1
    loader_conf="$boot_path/loader/loader.conf"
    echo "正在修改引导菜单：$loader_conf"
    toolbox_sudo true || {
        echo "管理员权限验证失败，请检查桌面的管理员密码记录后重试。"
        return 1
    }
    temporary="$(mktemp)" || return 1
    backup="无（原配置不存在）"

    if [ -f "$loader_conf" ]; then
        backup="$loader_conf.zhoukeer-backup.$(date +%Y%m%d%H%M%S).$$"
        awk -v timeout="$timeout" '
            /^[[:space:]]*timeout([[:space:]]|$)/ {
                if (!written) {
                    print "timeout " timeout
                    written = 1
                }
                next
            }
            { print }
            END {
                if (!written) print "timeout " timeout
            }
        ' "$loader_conf" > "$temporary" || {
            rm -f -- "$temporary"
            return 1
        }
        toolbox_sudo cp -- "$loader_conf" "$backup" || {
            rm -f -- "$temporary"
            return 1
        }
    else
        printf 'timeout %s\n' "$timeout" > "$temporary"
    fi

    toolbox_sudo install -m 0644 -- "$temporary" "$loader_conf" || {
        rm -f -- "$temporary"
        echo "写入引导设置失败，原文件未被替换。"
        return 1
    }
    rm -f -- "$temporary"
    printf '%s\n' "$backup"
}

enable_dual_boot_menu() {
    local backup

    backup="$(write_loader_timeout "$DUAL_BOOT_TIMEOUT")" || return 1
    echo "双系统引导菜单已启用，启动时将等待 $DUAL_BOOT_TIMEOUT 秒。"
    echo "原配置备份：$backup"
    log "双系统引导菜单已启用: timeout=$DUAL_BOOT_TIMEOUT"
}

hide_dual_boot_menu() {
    local backup

    backup="$(write_loader_timeout 0)" || return 1
    echo "双系统引导菜单已隐藏，等待时间已设为 0 秒。"
    echo "没有删除 SteamOS、Windows 或 EFI 启动项。"
    echo "原配置备份：$backup"
    log "双系统引导菜单已隐藏: timeout=0"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        mount) mount_shared_drive ;;
        protect) mount_shared_drive_with_protection ;;
        unprotect) restore_shared_drive_write ;;
        add) enable_dual_boot_menu ;;
        remove) hide_dual_boot_menu ;;
        *)
            echo "用法: $0 {mount|protect|unprotect|add|remove}"
            exit 1
            ;;
    esac
fi
