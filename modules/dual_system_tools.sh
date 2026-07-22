#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dual_system.sh"

TF_CARD_LINK="${ZHOUKEER_TF_CARD_LINK:-$HOME/双系统TF卡}"
WINDOWS_SWITCH_DIR="${ZHOUKEER_WINDOWS_SWITCH_DIR:-$HOME/.local/share/zhoukeer-toolbox}"
WINDOWS_SWITCH_LAUNCHER="$WINDOWS_SWITCH_DIR/windows-next.sh"
WINDOWS_SWITCH_DESKTOP="${ZHOUKEER_WINDOWS_SWITCH_DESKTOP:-$HOME/Desktop/一键切换Windows.desktop}"

simple_device_path_is_safe() {
    local device="$1"
    local name

    case "$device" in
        /dev/*) ;;
        *) return 1 ;;
    esac
    name="${device#/dev/}"
    case "$name" in
        ''|*[!A-Za-z0-9._-]*) return 1 ;;
    esac
}

device_is_system_disk() {
    local device="$1"
    local root_source root_parent

    root_source="$(findmnt -rn -o SOURCE / 2>/dev/null | head -n 1)"
    [ -n "$root_source" ] || return 0
    root_parent="$(lsblk -nro PKNAME "$root_source" 2>/dev/null | head -n 1)"
    [ "$device" != "$root_source" ] || return 0
    [ -z "$root_parent" ] || [ "$device" != "/dev/$root_parent" ] || return 0
    return 1
}

find_tf_card_device() {
    local requested="${ZHOUKEER_TF_CARD_DEVICE:-}"
    local device type removable transport
    local candidate="" count=0

    if [ -n "$requested" ]; then
        simple_device_path_is_safe "$requested" || {
            echo "指定的 TF 卡设备路径不安全：$requested"
            return 1
        }
        type="$(lsblk -dnro TYPE "$requested" 2>/dev/null | head -n 1)"
        [ "$type" = "disk" ] || {
            echo "指定目标不是整张磁盘：$requested"
            return 1
        }
        if device_is_system_disk "$requested"; then
            echo "指定目标属于当前系统盘，已拒绝操作：$requested"
            return 1
        fi
        printf '%s\n' "$requested"
        return 0
    fi

    while read -r device type removable transport; do
        [ "$type" = "disk" ] || continue
        if [ "$removable" != "1" ] && [ "$transport" != "mmc" ]; then
            continue
        fi
        simple_device_path_is_safe "$device" || continue
        device_is_system_disk "$device" && continue
        candidate="$device"
        count=$((count + 1))
    done < <(lsblk -dnrpo NAME,TYPE,RM,TRAN 2>/dev/null)

    if [ "$count" -eq 0 ]; then
        echo "没有检测到可安全识别的 TF 卡或可移动磁盘。"
        return 1
    fi
    if [ "$count" -gt 1 ]; then
        echo "检测到多个可移动磁盘，为避免格式化错误设备已停止。"
        echo "请只保留目标 TF 卡后重试。"
        return 1
    fi
    printf '%s\n' "$candidate"
}

tf_card_confirm_format() {
    local device="$1"
    local answer size model

    size="$(lsblk -dnro SIZE "$device" 2>/dev/null | head -n 1)"
    model="$(lsblk -dnro MODEL "$device" 2>/dev/null | head -n 1)"
    echo "================================================"
    echo " 初始化并挂载双系统 TF 卡"
    echo "================================================"
    echo "目标设备：$device"
    echo "容量：${size:-未知}"
    echo "型号：${model:-未知}"
    echo "警告：将删除目标设备上的全部分区和文件，并重新格式化为 exFAT。"
    echo "SteamOS、Windows 和 EFI 所在系统盘已自动排除，但仍请核对设备名称。"
    read -r -p "确认清空请输入 FORMAT ${device}：" answer
    [ "$answer" = "FORMAT $device" ]
}

unmount_device_partitions() {
    local device="$1"
    local partition mountpoint

    while read -r partition; do
        [ -n "$partition" ] || continue
        mountpoint="$(findmnt -rn -S "$partition" -o TARGET 2>/dev/null | head -n 1)"
        [ -n "$mountpoint" ] || continue
        udisksctl unmount --block-device "$partition" >/dev/null || {
            echo "无法卸载 ${partition}，请关闭正在使用 TF 卡的程序。"
            return 1
        }
    done < <(lsblk -lnrpo NAME,TYPE "$device" 2>/dev/null | awk '$2 == "part" { print $1 }')
}

create_tf_card_shortcut() {
    local mountpoint="$1"

    if [ -L "$TF_CARD_LINK" ]; then
        rm -f -- "$TF_CARD_LINK" || return 1
    elif [ -e "$TF_CARD_LINK" ]; then
        echo "TF 卡已挂载到：$mountpoint"
        echo "快捷入口路径已被占用：$TF_CARD_LINK"
        return 0
    fi
    ln -s -- "$mountpoint" "$TF_CARD_LINK"
}

format_and_mount_tf_card() {
    local device partition output mountpoint

    require_steamos || return 1
    for command_name in lsblk findmnt udisksctl wipefs parted partprobe udevadm mkfs.exfat; do
        require_command "$command_name" || return 1
    done
    device="$(find_tf_card_device)" || return 1
    tf_card_confirm_format "$device" || {
        echo "已取消 TF 卡初始化，磁盘未修改。"
        return 0
    }
    toolbox_sudo true || return 1
    unmount_device_partitions "$device" || return 1

    toolbox_sudo wipefs --all --force "$device" || {
        echo "清理 TF 卡分区签名失败。"
        return 1
    }
    toolbox_sudo parted --script "$device" mklabel gpt mkpart primary exfat 1MiB 100% || {
        echo "创建 TF 卡分区失败。"
        return 1
    }
    toolbox_sudo partprobe "$device" || return 1
    toolbox_sudo udevadm settle || return 1
    partition="$(lsblk -lnrpo NAME,TYPE "$device" 2>/dev/null | awk '$2 == "part" { print $1 }' | head -n 1)"
    simple_device_path_is_safe "$partition" || {
        echo "无法安全确认新建的 TF 卡分区。"
        return 1
    }
    toolbox_sudo mkfs.exfat -n ZHOUKEER_TF "$partition" || {
        echo "格式化 TF 卡为 exFAT 失败。"
        return 1
    }
    output="$(udisksctl mount --block-device "$partition" 2>&1)" || {
        printf '%s\n' "$output"
        return 1
    }
    mountpoint="$(printf '%s\n' "$output" | extract_udisks_mountpoint)"
    [ -d "$mountpoint" ] || {
        echo "TF 卡已格式化，但没有确认挂载位置。"
        return 1
    }
    create_tf_card_shortcut "$mountpoint" || return 1
    echo "TF 卡已格式化为 exFAT 并挂载：$mountpoint"
    echo "SteamOS 与 Windows 均可读写；快捷入口：$TF_CARD_LINK"
    log "双系统TF卡已初始化: $device -> $partition -> $mountpoint"
}

repair_drive_confirm() {
    local device="$1"
    local filesystem="$2"
    local answer

    echo "将卸载并修复 ${device}（${filesystem}）。"
    echo "NTFS 使用 ntfsfix 做基础修复；严重错误仍需进入 Windows 运行 chkdsk。"
    echo "修复期间不要拔出磁盘或强制关机。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认修复请输入 REPAIR ${device}：" answer
    [ "$answer" = "REPAIR $device" ]
}

repair_shared_drive() {
    local device filesystem mountpoint repair_command output

    require_steamos || return 1
    for command_name in lsblk findmnt udisksctl; do
        require_command "$command_name" || return 1
    done
    device="$(find_shared_drive_device 1)" || return 1
    filesystem="$(lsblk -nro FSTYPE "$device" 2>/dev/null | head -n 1)"
    case "$filesystem" in
        ntfs|ntfs3) repair_command="ntfsfix" ;;
        exfat) repair_command="fsck.exfat" ;;
        *) echo "不支持修复该文件系统：${filesystem:-未知}"; return 1 ;;
    esac
    require_command "$repair_command" || return 1
    repair_drive_confirm "$device" "$filesystem" || {
        echo "已取消磁盘修复。"
        return 0
    }
    toolbox_sudo true || return 1
    mountpoint="$(shared_drive_mountpoint "$device" || true)"
    if [ -n "$mountpoint" ]; then
        udisksctl unmount --block-device "$device" >/dev/null || {
            echo "无法卸载互通盘，请关闭正在使用该盘的程序。"
            return 1
        }
    fi
    if [ "$repair_command" = "ntfsfix" ]; then
        output="$(toolbox_sudo ntfsfix "$device" 2>&1)" || {
            printf '%s\n' "$output"
            echo "NTFS 基础修复失败，请进入 Windows 运行 chkdsk /f。"
            return 1
        }
    else
        output="$(toolbox_sudo fsck.exfat -p "$device" 2>&1)" || {
            printf '%s\n' "$output"
            echo "exFAT 自动修复失败，未继续写入。"
            return 1
        }
    fi
    printf '%s\n' "$output"
    mountpoint="$(mount_shared_drive_device "$device")" || {
        echo "磁盘已完成修复，但重新挂载失败。"
        return 1
    }
    create_shared_drive_shortcut "$mountpoint" || return 1
    echo "互通盘基础修复完成并已重新挂载：$mountpoint"
    log "双系统互通盘修复完成: $device filesystem=$filesystem"
}

windows_boot_number() {
    efibootmgr -v 2>/dev/null | awk '
        /Windows Boot Manager/ {
            value = substr($1, 5, 4)
            gsub(/[^0-9A-Fa-f]/, "", value)
            if (length(value) == 4) {
                count++
                result = toupper(value)
            }
        }
        END { if (count == 1) print result }
    '
}

confirm_windows_reboot() {
    local answer

    echo "将把 Windows Boot Manager 设为仅下一次启动目标，然后立即重启。"
    echo "之后再次重启仍会回到 Clover/SteamOS 的正常启动顺序。"
    read -r -p "确认切换请输入 WINDOWS：" answer
    [ "$answer" = "WINDOWS" ]
}

boot_windows_once() {
    local boot_number

    require_steamos || return 1
    for command_name in efibootmgr systemctl awk; do
        require_command "$command_name" || return 1
    done
    boot_number="$(windows_boot_number)"
    [ -n "$boot_number" ] || {
        echo "没有找到唯一的 Windows Boot Manager，未设置下次启动。"
        return 1
    }
    confirm_windows_reboot || {
        echo "已取消切换 Windows。"
        return 0
    }
    toolbox_sudo efibootmgr --bootnext "$boot_number" || {
        echo "设置 Windows 为下一次启动目标失败。"
        return 1
    }
    log "已设置下一次启动Windows: Boot$boot_number"
    echo "下一次启动目标已设置为 Windows，正在重启。"
    toolbox_sudo systemctl reboot || {
        echo "自动重启失败；下次手动重启仍会进入 Windows。"
        return 1
    }
}

desktop_exec_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

create_windows_switch_shortcut() {
    local escaped_launcher quoted_module temp_launcher temp_desktop

    require_steamos || return 1
    require_command efibootmgr || return 1
    [ -n "$(windows_boot_number)" ] || {
        echo "没有找到唯一的 Windows Boot Manager，未创建快捷方式。"
        return 1
    }
    mkdir -p "$WINDOWS_SWITCH_DIR" "$(dirname "$WINDOWS_SWITCH_DESKTOP")" || return 1
    temp_launcher="$(mktemp "$WINDOWS_SWITCH_DIR/.windows-next.XXXXXX")" || return 1
    temp_desktop="$(mktemp "$(dirname "$WINDOWS_SWITCH_DESKTOP")/.windows-next.XXXXXX")" || {
        rm -f -- "$temp_launcher"
        return 1
    }
    printf -v quoted_module '%q' "$PROJECT_ROOT/modules/dual_system_tools.sh"
    cat > "$temp_launcher" <<EOF
#!/bin/bash
exec /usr/bin/env bash $quoted_module windows-next
EOF
    chmod 0755 "$temp_launcher" || return 1
    escaped_launcher="$(desktop_exec_escape "$WINDOWS_SWITCH_LAUNCHER")"
    cat > "$temp_desktop" <<EOF
[Desktop Entry]
Type=Application
Name=一键切换 Windows
Comment=仅将下一次启动切换到 Windows
Exec=konsole --hold -e "$escaped_launcher"
Icon=$PROJECT_ROOT/assets/icon.png
Terminal=false
Categories=System;
EOF
    chmod 0755 "$temp_desktop" || return 1
    mv -- "$temp_launcher" "$WINDOWS_SWITCH_LAUNCHER" || return 1
    mv -- "$temp_desktop" "$WINDOWS_SWITCH_DESKTOP" || return 1
    echo "已创建桌面快捷方式：$WINDOWS_SWITCH_DESKTOP"
    echo "点击后仍需输入 WINDOWS 确认，不会永久改变默认启动顺序。"
    log "Windows一次性切换快捷方式已创建: $WINDOWS_SWITCH_DESKTOP"
}

find_boot_esp_for_health() {
    local candidate

    if command -v bootctl >/dev/null 2>&1; then
        for candidate in "$(bootctl --print-esp-path 2>/dev/null || true)" \
            "$(bootctl --print-boot-path 2>/dev/null || true)"; do
            [ -d "$candidate/EFI" ] && { printf '%s\n' "$candidate"; return 0; }
        done
    fi
    for candidate in /esp /boot/efi /efi /boot; do
        [ -d "$candidate/EFI" ] && { printf '%s\n' "$candidate"; return 0; }
    done
    return 1
}

classify_boot_entry() {
    local line="$1"

    case "$line" in
        *Windows\ Boot\ Manager*) echo "Windows（受保护）" ;;
        *SteamOS*|*steamcl.efi*) echo "SteamOS（受保护）" ;;
        *systemd*|*systemd-boot*|*Linux\ Boot\ Manager*) echo "systemd-boot（仅检查）" ;;
        *Zhoukeer\ Clover*) echo "工具箱 Clover（可完整恢复/删除）" ;;
        *Clover*) echo "其他 Clover（可清理 NVRAM）" ;;
        *rEFInd*|*refind*) echo "rEFInd（可清理 NVRAM）" ;;
        *OpenCore*|*OPENCORE*|*opencore*) echo "OpenCore（可清理 NVRAM）" ;;
        *GRUB*|*grub*) echo "GRUB（可清理 NVRAM）" ;;
        *) echo "其他/固件启动项（仅检查）" ;;
    esac
}

dual_boot_health_check() {
    local entries line esp free_kb device filesystem mountpoint readonly

    require_steamos || return 1
    for command_name in efibootmgr lsblk findmnt awk df; do
        require_command "$command_name" || return 1
    done
    entries="$(efibootmgr -v 2>/dev/null)" || {
        echo "无法读取 UEFI NVRAM 启动项。"
        return 1
    }
    echo "================================================"
    echo " 双系统健康检查（只读）"
    echo "================================================"
    while IFS= read -r line; do
        case "$line" in
            Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]*)
                printf '%s｜%s\n' "${line%%HD(*}" "$(classify_boot_entry "$line")"
                ;;
        esac
    done <<< "$entries"

    esp="$(find_boot_esp_for_health || true)"
    if [ -n "$esp" ]; then
        free_kb="$(df -Pk "$esp" 2>/dev/null | awk 'NR == 2 { print $4 }')"
        case "$free_kb" in
            ''|*[!0-9]*) free_kb=0 ;;
        esac
        echo "EFI：${esp}｜剩余 $(( free_kb / 1024 )) MB"
        [ ! -d "$esp/EFI/CLOVER" ] || echo "文件：检测到 EFI/CLOVER"
        [ ! -d "$esp/EFI/refind" ] || echo "文件：检测到 EFI/refind"
        [ ! -d "$esp/EFI/OC" ] || echo "文件：检测到 EFI/OC（OpenCore）"
        [ ! -d "$esp/EFI/systemd" ] || echo "文件：检测到 EFI/systemd"
    else
        echo "EFI：未找到已挂载的 EFI 系统分区"
    fi

    echo "磁盘："
    while read -r device filesystem mountpoint readonly; do
        is_shared_filesystem "$filesystem" || continue
        echo "  ${device}｜${filesystem}｜${mountpoint:-未挂载}｜只读=${readonly:-未知}"
    done < <(lsblk -rpn -o NAME,FSTYPE,MOUNTPOINT,RO 2>/dev/null)
    echo "提示：Windows 快速启动或休眠可能导致 NTFS 在 SteamOS 下只读。"
    log "双系统健康检查已完成"
}

boot_entry_line() {
    local boot_number="$1"

    efibootmgr -v 2>/dev/null | awk -v number="$boot_number" '
        toupper(substr($1, 1, 8)) == "BOOT" toupper(number) { print; exit }
    '
}

cleanup_third_party_boot_entry() {
    local entries line boot_number answer backup_file timestamp

    require_steamos || return 1
    for command_name in efibootmgr awk; do
        require_command "$command_name" || return 1
    done
    entries="$(efibootmgr -v 2>/dev/null)" || return 1
    echo "可清理的第三方 NVRAM 启动项（只删除条目，保留 EFI 文件）："
    printf '%s\n' "$entries" | awk '
        /rEFInd|refind|OpenCore|OPENCORE|opencore|GRUB|grub|Clover/ && !/Zhoukeer Clover/ { print }
    '
    boot_number="${ZHOUKEER_BOOT_ENTRY:-}"
    if [ -z "$boot_number" ]; then
        read -r -p "输入要清理的四位 Boot 编号：" boot_number
    fi
    case "$boot_number" in
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
        *) echo "Boot 编号格式无效。"; return 1 ;;
    esac
    boot_number="$(printf '%s' "$boot_number" | tr '[:lower:]' '[:upper:]')"
    line="$(boot_entry_line "$boot_number")"
    [ -n "$line" ] || { echo "没有找到 Boot${boot_number}。"; return 1; }
    case "$line" in
        *Windows\ Boot\ Manager*|*SteamOS*|*steamcl.efi*|*systemd*|*Linux\ Boot\ Manager*|*Zhoukeer\ Clover*)
            echo "该启动项受保护，请使用对应的专用恢复功能。"
            return 1
            ;;
        *rEFInd*|*refind*|*OpenCore*|*OPENCORE*|*opencore*|*GRUB*|*grub*|*Clover*) ;;
        *) echo "该启动项无法安全分类，已拒绝删除。"; return 1 ;;
    esac
    echo "将删除 NVRAM 条目：$line"
    echo "EFI 文件会保留，可用于人工恢复。"
    read -r -p "确认删除请输入 DELETE BOOT${boot_number}：" answer
    [ "$answer" = "DELETE BOOT$boot_number" ] || {
        echo "已取消清理。"
        return 0
    }
    toolbox_sudo true || return 1
    ensure_runtime_dirs
    timestamp="$(date +%Y%m%d%H%M%S)-$$"
    backup_file="$LOG_DIR/boot-entries-before-delete-$timestamp.txt"
    printf '%s\n' "$entries" > "$backup_file" || return 1
    chmod 0600 "$backup_file" || return 1
    toolbox_sudo efibootmgr --delete-bootnum --bootnum "$boot_number" || {
        echo "删除 Boot${boot_number} 失败。"
        return 1
    }
    echo "已删除第三方 NVRAM 启动项 Boot${boot_number}。"
    echo "删除前清单：$backup_file"
    log "第三方NVRAM启动项已删除: Boot$boot_number"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-health}" in
        tf-format-mount) format_and_mount_tf_card ;;
        repair-drive) repair_shared_drive ;;
        windows-shortcut) create_windows_switch_shortcut ;;
        windows-next) boot_windows_once ;;
        health) dual_boot_health_check ;;
        cleanup-boot) cleanup_third_party_boot_entry ;;
        *)
            echo "用法: $0 {tf-format-mount|repair-drive|windows-shortcut|windows-next|health|cleanup-boot}"
            exit 1
            ;;
    esac
fi
