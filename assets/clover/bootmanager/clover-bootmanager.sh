#!/bin/bash

set -euo pipefail

OS_RELEASE_FILE="${ZHOUKEER_OS_RELEASE_FILE:-/etc/os-release}"
STATUS_FILE="${ZHOUKEER_CLOVER_STATUS_FILE:-/run/renkit/clover-boot-status.txt}"
ESP_OVERRIDE="${ZHOUKEER_CLOVER_ESP:-}"
CLOVER_LABEL="Zhoukeer Clover"
CLOVER_LOADER='\EFI\CLOVER\CLOVERX64.efi'
ESP=""
ESP_SOURCE=""
ESP_DISK=""
ESP_PARTITION=""
OS_ID=""
OS_LABEL=""
OS_LOADER=""
OS_LOADER_NEEDLE=""

log_line() {
    printf '%s\n' "$*" >> "$STATUS_FILE"
}

fail() {
    log_line "失败：$*"
    printf '%s\n' "$*" >&2
    exit 1
}

os_release_value() {
    local key="$1"

    [ -r "$OS_RELEASE_FILE" ] || return 1
    awk -F= -v wanted="$key" '
        $1 == wanted {
            value = substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) {
                value = substr(value, 2, length(value) - 2)
            }
            print value
            exit
        }
    ' "$OS_RELEASE_FILE"
}

detect_supported_os() {
    local id variant

    id="$(os_release_value ID 2>/dev/null || true)"
    variant="$(os_release_value VARIANT_ID 2>/dev/null || true)"
    case "$id:$variant" in
        bazzite:*|*:bazzite*)
            OS_ID="bazzite"
            OS_LABEL="Bazzite"
            OS_LOADER='\EFI\fedora\shimx64.efi'
            OS_LOADER_NEEDLE="shimx64.efi"
            ;;
        steamos:*)
            OS_ID="steamos"
            OS_LABEL="SteamOS"
            OS_LOADER='\EFI\steamos\steamcl.efi'
            OS_LOADER_NEEDLE="steamcl.efi"
            ;;
        *) fail "此开机修复服务仅支持 SteamOS 或 Bazzite。" ;;
    esac
}

esp_has_os_loader() {
    local candidate="$1"

    case "$OS_ID" in
        bazzite) [ -f "$candidate/EFI/fedora/shimx64.efi" ] ;;
        steamos) [ -f "$candidate/EFI/steamos/steamcl.efi" ] ;;
        *) return 1 ;;
    esac
}

resolve_esp() {
    local candidate

    if [ -n "$ESP_OVERRIDE" ]; then
        esp_has_os_loader "$ESP_OVERRIDE" || fail "指定目录不是当前系统的 EFI 分区：$ESP_OVERRIDE"
        ESP="$ESP_OVERRIDE"
    else
        for candidate in /boot/efi /esp /efi /boot; do
            [ -d "$candidate/EFI" ] || continue
            if esp_has_os_loader "$candidate"; then
                ESP="$candidate"
                break
            fi
        done
        if [ -z "$ESP" ]; then
            while IFS= read -r candidate; do
                [ -d "$candidate/EFI" ] || continue
                if esp_has_os_loader "$candidate"; then
                    ESP="$candidate"
                    break
                fi
            done < <(findmnt -rn -t vfat,fat,fat32,msdos -o TARGET 2>/dev/null || true)
        fi
    fi
    [ -n "$ESP" ] || fail "未找到包含 ${OS_LABEL} 启动文件的 EFI 分区。"
}

resolve_esp_device() {
    local filesystem parent partition

    ESP_SOURCE="$(findmnt -rn -T "$ESP" -o SOURCE 2>/dev/null | head -n 1)"
    filesystem="$(findmnt -rn -T "$ESP" -o FSTYPE 2>/dev/null | head -n 1)"
    case "$ESP_SOURCE" in
        /dev/*) ;;
        *) fail "无法确认 EFI 分区对应的块设备。" ;;
    esac
    case "$filesystem" in
        vfat|fat|fat32|msdos) ;;
        *) fail "EFI 分区不是 FAT 文件系统。" ;;
    esac
    parent="$(lsblk -nro PKNAME "$ESP_SOURCE" 2>/dev/null | head -n 1)"
    partition="$(lsblk -nro PARTN "$ESP_SOURCE" 2>/dev/null | head -n 1)"
    case "$parent" in
        ''|*[!A-Za-z0-9._-]*) fail "无法安全解析 EFI 所在磁盘。" ;;
    esac
    case "$partition" in
        ''|*[!0-9]*) fail "无法安全解析 EFI 分区编号。" ;;
    esac
    ESP_DISK="/dev/$parent"
    ESP_PARTITION="$partition"
}

boot_number_by_loader() {
    local needle="$1"

    efibootmgr -v 2>/dev/null | awk -v needle="$needle" '
        index(tolower($0), tolower(needle)) {
            value = substr($1, 5, 4)
            gsub(/[^0-9A-Fa-f]/, "", value)
            if (length(value) == 4) {
                print toupper(value)
                exit
            }
        }
    '
}

ensure_boot_entry() {
    local label="$1" loader="$2" needle="$3" number

    number="$(boot_number_by_loader "$needle")"
    if [ -z "$number" ]; then
        efibootmgr --create --disk "$ESP_DISK" --part "$ESP_PARTITION" \
            --label "$label" --loader "$loader" >/dev/null || \
            fail "无法创建 ${label} UEFI 启动项。"
        number="$(boot_number_by_loader "$needle")"
    fi
    [ -n "$number" ] || fail "创建后仍无法读取 ${label} UEFI 启动项。"
    printf '%s\n' "$number"
}

disable_windows_direct_boot() {
    local standard backup moved

    standard="$ESP/EFI/Microsoft/Boot/bootmgfw.efi"
    backup="$standard.zhoukeer-orig"
    moved="$ESP/EFI/Microsoft/bootmgfw.efi"
    if [ -f "$standard" ]; then
        mkdir -p -- "$ESP/EFI/Microsoft"
        [ -f "$backup" ] || cp -- "$standard" "$backup" || \
            fail "无法备份 Windows 启动文件。"
        mv -- "$standard" "$moved" || fail "无法禁用 Windows 直启。"
    elif [ ! -f "$moved" ]; then
        fail "未找到 Windows 启动文件，未修改开机顺序。"
    fi
}

current_boot_order() {
    efibootmgr 2>/dev/null | sed -n 's/^BootOrder:[[:space:]]*//p' | head -n 1
}

prepend_clover_to_boot_order() {
    local clover_number="$1" current item upper new_order old_ifs

    current="$(current_boot_order)"
    case "$current" in
        '' ) ;;
        ,*|*,|*,,*|*[!0-9A-Fa-f,]*) fail "当前 BootOrder 格式异常，未修改启动顺序。" ;;
    esac
    new_order="$clover_number"
    old_ifs="$IFS"
    IFS=','
    for item in $current; do
        IFS="$old_ifs"
        [ "${#item}" -eq 4 ] || fail "当前 BootOrder 项长度异常，未修改启动顺序。"
        upper="$(printf '%s' "$item" | tr '[:lower:]' '[:upper:]')"
        if [ "$upper" != "$clover_number" ]; then
            case ",$new_order," in
                *",$upper,"*) ;;
                *) new_order="$new_order,$upper" ;;
            esac
        fi
        IFS=','
    done
    IFS="$old_ifs"
    efibootmgr --bootorder "$new_order" >/dev/null || fail "无法更新 BootOrder。"
    printf '%s\n' "$new_order"
}

main() {
    local clover_number os_number new_order status_dir

    case "$STATUS_FILE" in
        /*) ;;
        *) printf '%s\n' "Clover 状态日志路径必须是绝对路径。" >&2; exit 1 ;;
    esac
    status_dir="${STATUS_FILE%/*}"
    mkdir -p -- "$status_dir" || exit 1
    [ ! -L "$STATUS_FILE" ] || {
        printf '%s\n' "Clover 状态日志不能是符号链接。" >&2
        exit 1
    }
    : > "$STATUS_FILE" || exit 1
    chmod 0644 "$STATUS_FILE" || exit 1
    for command_name in awk cp efibootmgr findmnt lsblk mkdir mv sed tr; do
        command -v "$command_name" >/dev/null 2>&1 || fail "缺少命令：$command_name"
    done
    detect_supported_os
    log_line "Clover 开机修复开始：系统 ${OS_LABEL}"
    resolve_esp
    resolve_esp_device
    [ -f "$ESP/EFI/CLOVER/CLOVERX64.efi" ] || fail "Clover EFI 文件不存在。"

    clover_number="$(ensure_boot_entry "$CLOVER_LABEL" "$CLOVER_LOADER" 'cloverx64.efi')"
    os_number="$(ensure_boot_entry "$OS_LABEL" "$OS_LOADER" "$OS_LOADER_NEEDLE")"
    new_order="$(prepend_clover_to_boot_order "$clover_number")"
    disable_windows_direct_boot

    log_line "EFI 分区：${ESP_SOURCE}，挂载点：${ESP}"
    log_line "Clover 启动项：${clover_number}；${OS_LABEL} 启动项：${os_number}"
    log_line "当前 BootOrder：${new_order}"
    log_line "Clover 开机修复完成。"
}

main "$@"
