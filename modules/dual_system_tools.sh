#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dual_system.sh"

TF_CARD_LINK="${ZHOUKEER_TF_CARD_LINK:-$HOME/双系统TF卡}"
TF_CARD_LABEL="${ZHOUKEER_TF_CARD_LABEL:-TFcard}"
WINDOWS_SWITCH_DIR="${ZHOUKEER_WINDOWS_SWITCH_DIR:-$HOME/.local/share/zhoukeer-toolbox}"
WINDOWS_SWITCH_LAUNCHER="$WINDOWS_SWITCH_DIR/windows-next.sh"
WINDOWS_LEGACY_SWITCH_LAUNCHER="$WINDOWS_SWITCH_DIR/windows/windows-next.sh"
WINDOWS_SWITCH_DESKTOP="${ZHOUKEER_WINDOWS_SWITCH_DESKTOP:-$HOME/Desktop/一键切换Windows.desktop}"
WINDOWS_SWITCH_ICON="${ZHOUKEER_WINDOWS_SWITCH_ICON:-$PROJECT_ROOT/assets/windows-switch.png}"

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
            echo "指定的 TF 卡设备路径不安全：$requested" >&2
            return 1
        }
        type="$(lsblk -dnro TYPE "$requested" 2>/dev/null | head -n 1)"
        [ "$type" = "disk" ] || {
            echo "指定目标不是整张磁盘：$requested" >&2
            return 1
        }
        if device_is_system_disk "$requested"; then
            echo "指定目标属于当前系统盘，已拒绝操作：$requested" >&2
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
        echo "没有检测到可安全识别的 TF 卡或可移动磁盘。" >&2
        return 1
    fi
    if [ "$count" -gt 1 ]; then
        echo "检测到多个可移动磁盘，为避免格式化错误设备已停止。" >&2
        echo "请只保留目标 TF 卡后重试。" >&2
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

    echo "正在检查 TF 卡和管理员权限…"
    require_steamos || return 1
    for command_name in lsblk findmnt udisksctl wipefs parted partprobe udevadm mkfs.ntfs; do
        require_command "$command_name" || return 1
    done
    device="$(find_tf_card_device)" || return 1
    tf_card_confirm_format "$device" || {
        echo "已取消 TF 卡初始化，磁盘未修改。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，TF 卡未修改。"
        return 1
    }
    unmount_device_partitions "$device" || return 1

    toolbox_sudo wipefs --all --force "$device" || {
        echo "清理 TF 卡分区签名失败。"
        return 1
    }
    toolbox_sudo parted --script "$device" mklabel gpt mkpart primary exfat 1MiB 100% || {
        echo "创建 TF 卡分区失败。"
        return 1
    }
    toolbox_sudo partprobe "$device" || {
        echo "系统未能刷新 TF 卡分区表。"
        return 1
    }
    toolbox_sudo udevadm settle || {
        echo "等待 TF 卡新分区识别超时。"
        return 1
    }
    partition="$(lsblk -lnrpo NAME,TYPE "$device" 2>/dev/null | awk '$2 == "part" { print $1 }' | head -n 1)"
    simple_device_path_is_safe "$partition" || {
        echo "无法安全确认新建的 TF 卡分区。"
        return 1
    }
    toolbox_sudo mkfs.ntfs -f -L "$TF_CARD_LABEL" "$partition" || {
        echo "格式化 TF 卡为 NTFS 失败。"
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
    create_tf_card_shortcut "$mountpoint" || {
        echo "TF 卡已挂载，但创建桌面快捷入口失败。"
        return 1
    }
    echo "TF 卡已格式化为 NTFS 并挂载：$mountpoint"
    echo "SteamOS 与 Windows 均可读写；快捷入口：$TF_CARD_LINK"
    log "双系统TF卡已初始化: $device -> $partition -> $mountpoint"
}

clean_invalid_steam_symlinks() {
    local steamapp_dir downloading_dir shadercache_dir

    for steamapp_dir in \
        "$HOME/.steam/steam/steamapps" \
        "$HOME/.local/share/Steam/steamapps"; do
        downloading_dir="$steamapp_dir/downloading"
        shadercache_dir="$steamapp_dir/shadercache"
        [ -L "$downloading_dir" ] && [ ! -d "$(readlink -f "$downloading_dir")" ] && {
            rm -f -- "$downloading_dir"
            echo "已清理失效的 Steam 下载缓存软链接：$downloading_dir"
        }
        [ -L "$shadercache_dir" ] && [ ! -d "$(readlink -f "$shadercache_dir")" ] && {
            rm -f -- "$shadercache_dir"
            echo "已清理失效的 Steam 着色器缓存软链接：$shadercache_dir"
        }
    done
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
    clean_invalid_steam_symlinks
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

retire_windows_switch_shortcuts() {
    local path

    for path in "$WINDOWS_SWITCH_LAUNCHER" "$WINDOWS_LEGACY_SWITCH_LAUNCHER" "$WINDOWS_SWITCH_DESKTOP"; do
        case "$path" in
            "$HOME"/*) ;;
            *)
                echo "旧 Windows 切换入口路径异常，未删除：$path"
                continue
                ;;
        esac
        [ ! -e "$path" ] && [ ! -L "$path" ] || rm -f -- "$path"
    done
    echo "一键切换 Windows 功能已移除；未设置任何 EFI 启动项。"
    echo "旧的Renkit Windows 桌面入口已清理。"
    log "已停用并清理Windows一次性切换入口"
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
        *Zhoukeer\ Clover*) echo "Renkit Clover（可完整恢复/删除）" ;;
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

repair_boot_confirm() {
    local answer

    echo "将补齐缺失的引导项，并在需要时恢复 BootOrder。"
    echo "修复期间不要关机、重启或拔电。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认修复请输入 REPAIR：" answer
    [ "$answer" = "REPAIR" ]
}

switch_windows_confirm() {
    local boot_number="$1"
    local answer

    echo "将设置 BootNext=${boot_number}，并在确认后立即重启进入 Windows。"
    echo "请先保存所有工作；重启后不会自动返回 SteamOS 菜单。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认重启进入 Windows 请输入 WINDOWS：" answer
    [ "$answer" = "WINDOWS" ]
}

resolve_esp_repair_device() {
    local esp="$1"
    local device disk partition

    device="$(findmnt -rn -T "$esp" -o SOURCE 2>/dev/null | head -n 1)"
    case "$device" in
        /dev/*) ;;
        *) echo "无法确认 EFI 分区设备：${device:-未知}"; return 1 ;;
    esac
    disk="$(lsblk -nro PKNAME "$device" 2>/dev/null | head -n 1)"
    partition="$(lsblk -nro PARTN "$device" 2>/dev/null | head -n 1)"
    case "$disk" in
        /dev/*) ;;
        *) disk="/dev/$disk" ;;
    esac
    case "$disk" in
        /dev/*)
            case "${disk#/dev/}" in
                ''|*[!A-Za-z0-9._-]*) echo "无法确认 EFI 所在磁盘。"; return 1 ;;
            esac
            ;;
        *) echo "无法确认 EFI 所在磁盘。"; return 1 ;;
    esac
    case "$partition" in
        ''|*[!0-9]*) echo "无法确认 EFI 分区编号。"; return 1 ;;
    esac
    printf '%s %s\n' "$disk" "$partition"
}

boot_entry_has() {
    local entries="$1"
    local pattern="$2"

    printf '%s\n' "$entries" | LC_ALL=C grep -Ei -- "$pattern" >/dev/null
}

boot_order_current() {
    efibootmgr 2>/dev/null | sed -n 's/^BootOrder:[[:space:]]*//p' | head -n 1
}

boot_order_is_safe() {
    local order="$1"
    local token

    case "$order" in
        ''|*[!0-9A-Fa-f,]*) return 1 ;;
    esac
    IFS=',' read -r -a tokens <<< "$order"
    for token in "${tokens[@]}"; do
        case "$token" in
            [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
            *) return 1 ;;
        esac
    done
}

prepend_boot_order() {
    local boot_number="$1"
    local order="$2"
    local result="$boot_number"
    local token

    IFS=',' read -r -a tokens <<< "$order"
    for token in "${tokens[@]}"; do
        [ -n "$token" ] || continue
        [ "$token" = "$boot_number" ] || result="$result,$token"
    done
    printf '%s\n' "$result"
}

create_boot_entry() {
    local label="$1"
    local loader="$2"
    local disk="$3"
    local partition="$4"
    local output boot_number

    output="$(toolbox_sudo efibootmgr --create --disk "$disk" --part "$partition" \
        --label "$label" --loader "$loader" 2>&1)" || {
        printf '%s\n' "$output"
        echo "创建引导项失败：$label"
        return 1
    }
    printf '%s\n' "$output"
    boot_number="$(printf '%s\n' "$output" | \
        sed -n 's/^Boot\([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\)\*.*/\1/p' | \
        tail -n 1 | tr '[:lower:]' '[:upper:]')"
    if [ -z "$boot_number" ]; then
        boot_number="$(efibootmgr -v 2>/dev/null | awk -v label="$label" '
            toupper($0) ~ toupper(label) {
                line = $0
                sub(/^Boot/, "", line)
                sub(/\*.*/, "", line)
                print toupper(line)
                exit
            }
        ')"
    fi
    case "$boot_number" in
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
        *) echo "无法确认新引导项编号：$label"; return 1 ;;
    esac
    printf '%s\n' "$boot_number"
}

repair_dual_boot() {
    local entries esp device disk_partition disk partition missing_count=0
    local entry label loader boot_number clover_boot current_order new_order
    local backup_file timestamp output
    local -a repair_entries=()

    require_steamos || return 1
    for command_name in efibootmgr lsblk findmnt find sed awk tr grep; do
        require_command "$command_name" || return 1
    done
    entries="$(efibootmgr -v 2>/dev/null)" || {
        echo "无法读取 UEFI NVRAM 启动项，引导修复已停止。"
        return 1
    }
    esp="$(find_boot_esp_for_health || true)"
    if [ -z "$esp" ]; then
        echo "未找到已挂载的 EFI 系统分区，无法修复引导项。"
        return 1
    fi
    device="$(findmnt -rn -T "$esp" -o SOURCE 2>/dev/null | head -n 1)"
    disk_partition="$(resolve_esp_repair_device "$esp")" || return 1
    disk="${disk_partition%% *}"
    partition="${disk_partition##* }"

    if [ -f "$esp/EFI/Microsoft/Boot/bootmgfw.efi" ] && \
        ! boot_entry_has "$entries" 'Windows Boot Manager'; then
        repair_entries+=("Windows Boot Manager|\EFI\Microsoft\Boot\bootmgfw.efi")
        missing_count=$((missing_count + 1))
    fi
    if [ -f "$esp/EFI/steamos/steamcl.efi" ] && \
        ! boot_entry_has "$entries" 'steamcl\.efi'; then
        repair_entries+=("SteamOS|\EFI\steamos\steamcl.efi")
        missing_count=$((missing_count + 1))
    fi
    if [ -f "$esp/EFI/CLOVER/CLOVERX64.efi" ] && \
        ! boot_entry_has "$entries" 'cloverx64\.efi|Zhoukeer Clover'; then
        repair_entries+=("Zhoukeer Clover|\EFI\CLOVER\CLOVERX64.efi")
        missing_count=$((missing_count + 1))
    fi

    clover_boot="$(printf '%s\n' "$entries" | awk '
        /Clover/ {
            line = $0
            sub(/^Boot/, "", line)
            sub(/\*.*/, "", line)
            print toupper(line)
            exit
        }
    ')"

    if [ "$missing_count" -eq 0 ] && [ -z "$clover_boot" ]; then
        echo "未发现缺失的 SteamOS、Windows 或 Clover 引导项，无需修复。"
        return 0
    fi

    if [ "$missing_count" -gt 0 ]; then
        echo "将创建缺失的引导项："
        for entry in "${repair_entries[@]}"; do
            echo "  ${entry%%|*}"
        done
    fi
    if [ -n "$clover_boot" ]; then
        echo "将把 Zhoukeer Clover（Boot${clover_boot}）放到 BootOrder 首位。"
    fi
    repair_boot_confirm || {
        echo "已取消引导修复。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，引导项未修改。"
        return 1
    }
    ensure_runtime_dirs
    timestamp="$(date +%Y%m%d%H%M%S)-$$"
    backup_file="$LOG_DIR/boot-entries-before-repair-$timestamp.txt"
    printf '%s\n' "$entries" > "$backup_file" || return 1
    chmod 0600 "$backup_file" || return 1

    if [ "$missing_count" -gt 0 ]; then
        for entry in "${repair_entries[@]}"; do
            label="${entry%%|*}"
            loader="${entry#*|}"
            output="$(create_boot_entry "$label" "$loader" "$disk" "$partition")" || return 1
            printf '%s\n' "$output"
        done
    fi

    entries="$(efibootmgr -v 2>/dev/null)" || {
        echo "引导项已创建，但无法重新读取 NVRAM 清单。"
        return 1
    }
    clover_boot="$(printf '%s\n' "$entries" | awk '
        /Clover/ {
            line = $0
            sub(/^Boot/, "", line)
            sub(/\*.*/, "", line)
            print toupper(line)
            exit
        }
    ')"
    if [ -n "$clover_boot" ]; then
        current_order="$(boot_order_current)"
        boot_order_is_safe "$current_order" || {
            echo "无法安全读取 BootOrder，未调整启动顺序。"
            return 1
        }
        new_order="$(prepend_boot_order "$clover_boot" "$current_order")"
        toolbox_sudo efibootmgr --bootorder "$new_order" || {
            echo "设置 BootOrder 失败。"
            return 1
        }
        echo "BootOrder 已更新：$new_order"
    fi
    echo "双系统引导修复完成。"
    echo "修复前 NVRAM 清单备份：$backup_file"
    log "双系统引导修复完成: missing=$missing_count clover=$clover_boot"
}

switch_to_windows() {
    local entries line boot_number backup_file timestamp output

    require_steamos || return 1
    require_command efibootmgr || return 1
    entries="$(efibootmgr -v 2>/dev/null)" || {
        echo "无法读取 UEFI NVRAM 启动项，无法一键切换。"
        return 1
    }
    line="$(printf '%s\n' "$entries" | awk '/Windows Boot Manager/ { print; exit }')"
    if [ -z "$line" ]; then
        echo "未找到 Windows Boot Manager，无法一键切换。"
        return 1
    fi
    boot_number="$(printf '%s\n' "$line" | \
        sed -n 's/^Boot\([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\).*/\1/p' | \
        head -n 1 | tr '[:lower:]' '[:upper:]')"
    case "$boot_number" in
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
        *) echo "无法识别 Windows 启动编号。"; return 1 ;;
    esac
    switch_windows_confirm "$boot_number" || {
        echo "已取消 Windows 一键切换。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，未设置 BootNext。"
        return 1
    }
    ensure_runtime_dirs
    timestamp="$(date +%Y%m%d%H%M%S)-$$"
    backup_file="$LOG_DIR/boot-next-before-$timestamp.txt"
    printf '%s\n' "$entries" > "$backup_file" || return 1
    chmod 0600 "$backup_file" || return 1
    output="$(toolbox_sudo efibootmgr --bootnext "$boot_number" 2>&1)" || {
        printf '%s\n' "$output"
        echo "设置下次启动进入 Windows 失败。"
        return 1
    }
    printf '%s\n' "$output"
    echo "已设置 BootNext=${boot_number}，正在重启进入 Windows。"
    echo "启动清单备份：$backup_file"
    log "Windows一键切换: BootNext=$boot_number"
    if command -v systemctl >/dev/null 2>&1; then
        toolbox_sudo systemctl reboot
    else
        toolbox_sudo reboot
    fi
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
        repair-boot) repair_dual_boot ;;
        switch-to-windows) switch_to_windows ;;
        windows-shortcut|windows-next) retire_windows_switch_shortcuts ;;
        health) dual_boot_health_check ;;
        cleanup-boot) cleanup_third_party_boot_entry ;;
        *)
            echo "用法: $0 {tf-format-mount|repair-drive|repair-boot|switch-to-windows|health|cleanup-boot}"
            exit 1
            ;;
    esac
fi
