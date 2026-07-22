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

# rEFInd 原实现保留仅供审阅；当前不会定义或执行其中的 EFI 写入函数。
REFIND_FEATURE_DISABLED=1
# rEFInd 图形引导管理器
REFIND_VERSION="${ZHOUKEER_REFIND_VERSION:-0.14.7}"
REFIND_URL="${ZHOUKEER_REFIND_URL:-https://github.com/bobafetthotmail/refind-bin-linux/releases/download/v${REFIND_VERSION}/refind-bin-linux-${REFIND_VERSION}.zip}"
REFIND_ZIP_SHA256="${ZHOUKEER_REFIND_SHA256:-}"
REFIND_ESP_DIR="/esp/EFI/refind"
REFIND_BOOT_NUM=""


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

# 以下 rEFInd 实现已整体停用，避免暴露任何 EFI 写入函数。
if false; then
refind_esp_is_mounted() {
    mount | grep -q ' /esp '
}

refind_mount_esp() {
    refind_esp_is_mounted && return 0
    # SteamOS 的 ESP 通常在 /dev/nvme0n1p1
    local esp_dev
    esp_dev="$(blkid -L ESP 2>/dev/null || lsblk -nro NAME /dev/nvme0n1p1 2>/dev/null || true)"
    if [ -n "$esp_dev" ]; then
        toolbox_sudo mount "/dev/$esp_dev" /esp 2>/dev/null || toolbox_sudo mount /dev/nvme0n1p1 /esp 2>/dev/null || return 1
    elif [ -b /dev/nvme0n1p1 ]; then
        toolbox_sudo mount /dev/nvme0n1p1 /esp 2>/dev/null || return 1
    else
        return 1
    fi
}


refind_check_existing_entries() {
    echo "正在检测当前 EFI 引导项..."
    if ! command -v efibootmgr >/dev/null 2>&1; then
        echo "提示：缺少 efibootmgr，跳过引导项检测。"
        return 0
    fi

    local boot_entries
    boot_entries="$(toolbox_sudo efibootmgr 2>/dev/null)" || {
        echo "无法读取 EFI 引导项，跳过检测。"
        return 0
    }

    local known_patterns="SteamOS|Windows Boot Manager|UEFI|EFI|rEFInd|Linux-Firmware|Boot Manager"
    local custom_entries=""
    local entry_num entry_name

    while IFS= read -r line; do
        case "$line" in
            Boot[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]*)
                entry_name="${line#Boot[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]* }"
                entry_name="${entry_name#\* }"
                entry_num="${line:4:4}"
                # 跳过已知标准的引导项
                case "$entry_name" in
                    *SteamOS*|*Windows*Boot*|*UEFI*|*EFI*|*rEFInd*|*Linux*Firmware*|*Boot*Manager*) ;;
                    *)
                        if [ -n "$entry_name" ] && [ "${entry_num:-0000}" != "0000" ]; then
                            custom_entries="$custom_entries  Boot$entry_num - $entry_name"$'
'
                        fi
                        ;;
                esac
                ;;
        esac
    done <<< "$boot_entries"

    if [ -n "$custom_entries" ]; then
        echo ""
        echo "========================================"
        echo " 发现以下非标准引导项："
        echo "----------------------------------------"
        printf '%s' "$custom_entries"
        echo "========================================"
        echo "安装 rEFInd 后这些引导项会显示在开机菜单中。"
        echo "rEFInd 不会删除或修改它们，但引导顺序可能变化。"
        echo ""
        if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
            local answer
            read -r -p "确认继续安装请输入 YES：" answer
            [ "$answer" = "YES" ] || { echo "已取消。"; return 1; }
        fi
    else
        echo "未发现非标准引导项，系统环境正常。"
    fi
}

install_refind() {
    require_steamos || return 1
    for cmd_refind in curl unzip efibootmgr; do
        require_command "$cmd_refind" || return 1
    done

    echo "将安装 rEFInd 图形引导管理器到 EFI 分区。"
    echo "安装后开机将显示系统图标，可选择 SteamOS 或 Windows 启动。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        local answer
        read -r -p "确认安装请输入 INSTALL：" answer
        [ "$answer" = "INSTALL" ] || { echo "已取消。"; return 0; }
    fi

    toolbox_sudo true || { echo "管理员权限验证失败。"; return 1; }
    refind_check_existing_entries || return 1
    mkdir -p /esp 2>/dev/null || toolbox_sudo mkdir -p /esp
    refind_mount_esp || { echo "无法挂载 EFI 分区，请确认 Steam Deck 已开启开发者模式。"; return 1; }

    local tmp_refind
    tmp_refind="$(mktemp -d)" || return 1
    local refind_zip="$tmp_refind/refind.zip"
    local refind_extract="$tmp_refind/refind"

    echo "正在下载 rEFInd V$REFIND_VERSION..."
    local _rf_ok=0 _rf_url _rf_mirror
    for _rf_mirror in $GITHUB_MIRRORS ""; do
        if [ -n "$_rf_mirror" ]; then
            _rf_url="${_rf_mirror}${REFIND_URL}"
        else
            _rf_url="$REFIND_URL"
        fi
        if curl -fL --connect-timeout 15 --max-time 300 --retry 2 \
            -o "$refind_zip" "$_rf_url" 2>/dev/null; then
            _rf_ok=1
            break
        fi
        rm -f "$refind_zip"
    done
    if [ "$_rf_ok" -ne 1 ]; then
        rm -rf "$tmp_refind"
        echo "rEFInd 下载失败。"
        return 1
    fi

    mkdir -p "$refind_extract" || { rm -rf "$tmp_refind"; return 1; }
    unzip -q "$refind_zip" -d "$refind_extract" || { rm -rf "$tmp_refind"; return 1; }

    local refind_dir
    refind_dir="$(find "$refind_extract" -maxdepth 2 -type d -name refind -print -quit 2>/dev/null)" || true
    if [ -z "$refind_dir" ] || [ ! -f "$refind_dir/refind_x64.efi" ]; then
        rm -rf "$tmp_refind"
        echo "rEFInd 文件不完整。"
        return 1
    fi

    echo "正在安装 rEFInd 到 EFI 分区..."
    toolbox_sudo mkdir -p "$REFIND_ESP_DIR" || { rm -rf "$tmp_refind"; return 1; }
    toolbox_sudo cp -r "$refind_dir/"* "$REFIND_ESP_DIR/" || { rm -rf "$tmp_refind"; return 1; }
    toolbox_sudo cp "$refind_dir/refind_x64.efi" "$REFIND_ESP_DIR/bootx64.efi" 2>/dev/null || true

    # 生成 rEFInd 配置
    local refind_conf="$REFIND_ESP_DIR/refind.conf"
    local refind_conf_tmp
    refind_conf_tmp="$(mktemp)" || { rm -rf "$tmp_refind"; return 1; }

    cat > "$refind_conf_tmp" << REFIND_EOF
# rEFInd 配置 - 由周克儿工具箱生成
timeout 10
use_graphics_for osx,linux,windows
hideui label
showtools reboot,shutdown,firmware

menuentry "SteamOS" {
    icon /EFI/refind/icons/os_linux.png
    volume ESP
    loader /EFI/steamos/steamcl.efi
}

menuentry "Windows" {
    icon /EFI/refind/icons/os_win.png
    volume ESP
    loader /EFI/Microsoft/Boot/bootmgfw.efi
}

menuentry "重启" {
    icon /EFI/refind/icons/reboot.png
    reboot
}

menuentry "关机" {
    icon /EFI/refind/icons/shutdown.png
    shutdown
}
REFIND_EOF

    toolbox_sudo cp "$refind_conf_tmp" "$refind_conf" || { rm -rf "$tmp_refind"; return 1; }
    rm -f "$refind_conf_tmp"

    # 注册为默认引导项
    echo "正在设置 rEFInd 为默认引导管理器..."
    local refind_efi_path="\EFI\refind\refind_x64.efi"
    local bootnum
    bootnum="$(toolbox_sudo efibootmgr --create --disk /dev/nvme0n1 --part 1         --label "rEFInd" --loader "$refind_efi_path" 2>/dev/null |         sed -n 's/^Boot\([0-9]*\).*rEFInd.*/\1/p' || true)"
    if [ -n "$bootnum" ]; then
        toolbox_sudo efibootmgr --bootorder "$bootnum,0000" 2>/dev/null || true
        echo "rEFInd 已设为默认引导项 (Boot$bootnum)。"
    else
        echo "警告：无法自动注册 rEFInd，请在 BIOS 设置中手动选择 rEFInd 启动。"
    fi

    rm -rf "$tmp_refind"
    echo ""
    echo "rEFInd V$REFIND_VERSION 安装完成。"
    echo "下次开机将显示图形引导菜单，可选择 SteamOS 或 Windows。"
    log "rEFInd 图形引导管理器安装完成"
}

remove_refind() {
    require_steamos || return 1
    require_command efibootmgr || return 1

    echo "将移除 rEFInd 引导管理器。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        local answer
        read -r -p "确认卸载请输入 REMOVE：" answer
        [ "$answer" = "REMOVE" ] || { echo "已取消。"; return 0; }
    fi

    toolbox_sudo true || { echo "管理员权限验证失败。"; return 1; }

    # 删除 rEFInd efi 启动项
    local boot_entry
    for boot_entry in $(toolbox_sudo efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9]*\).*rEFInd.*//p'); do
        toolbox_sudo efibootmgr --delete-bootnum --bootnum "$boot_entry" 2>/dev/null || true
        echo "已删除引导项 Boot$boot_entry（rEFInd）。"
    done

    # 删除 rEFInd 文件
    if toolbox_sudo test -d "$REFIND_ESP_DIR"; then
        toolbox_sudo rm -rf "$REFIND_ESP_DIR" || {
            echo "rEFInd 文件删除失败，请确认 /esp 已挂载。"
            return 1
        }
        echo "已删除 rEFInd 文件。"
    fi

    echo "rEFInd 已移除。下次开机将使用默认引导管理器。"
    log "rEFInd 图形引导管理器已移除"
}
fi


if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        mount) mount_shared_drive ;;
        protect) mount_shared_drive_with_protection ;;
        unprotect) restore_shared_drive_write ;;
        add|remove)
            echo "旧 systemd-boot 菜单开关已停用，请使用工具箱中的 Clover 开机菜单。"
            exit 1
            ;;
        refind-install|refind-hide|refind-show|refind-remove)
            echo "该功能当前已停用。"
            exit 1
            ;;
        *)
            echo "用法: $0 {mount|protect|unprotect}"
            exit 1
            ;;
    esac
fi
