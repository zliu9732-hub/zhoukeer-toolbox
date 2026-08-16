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

CLOVER_VERSION="5173"
CLOVER_ARCHIVE="Clover.tar.gz"
CLOVER_MIRROR_ID="clover"
CLOVER_MIRROR_VERSION="v1.0.0"
CLOVER_MIRROR_SHA256="10782cebdf1e4130c9b759435c520b4e9452b03a9b10d5f3fff7d2125e99837d"
CLOVER_BOOT_LABEL="Zhoukeer Clover"
CLOVER_LOADER_PATH='\EFI\CLOVER\CLOVERX64.efi'
CLOVER_THEME_SOURCE="$PROJECT_ROOT/assets/clover/zhoukeer-phantom"
CLOVER_CONFIG_SOURCE="$PROJECT_ROOT/assets/clover/config.plist"
CLOVER_DEVICE_DIR="$PROJECT_ROOT/assets/clover/devices"
CLOVER_DRIVER_DIR="$PROJECT_ROOT/assets/clover/drivers"
CLOVER_BOOTMANAGER_DIR="$PROJECT_ROOT/assets/clover/bootmanager"
CLOVER_BOOTMANAGER_SYSTEM_DIR="${ZHOUKEER_CLOVER_SYSTEM_DIR:-/etc/systemd/system}"
CLOVER_BOOTMANAGER_WHITELIST_DIR="${ZHOUKEER_CLOVER_WHITELIST_DIR:-/etc/atomic-update.conf.d}"
CLOVER_DMI_ROOT="${ZHOUKEER_DMI_ROOT:-/sys/class/dmi/id}"
CLOVER_ESP=""
CLOVER_ESP_SOURCE=""
CLOVER_DISK=""
CLOVER_PARTITION=""
CLOVER_ESP_FOUND=""
CLOVER_ESP_MOUNTED_BY_TOOLBOX=0
CLOVER_ESP_MOUNT_DEVICE=""
CLOVER_DEVICE_PREFIX=""
CLOVER_DEVICE_NAME=""
CLOVER_EFI_DRIVER=""
CLOVER_DEVICE_CONFIG=""
CLOVER_SCREEN_RESOLUTION=""
CLOVER_DEFAULT_OS=""
CLOVER_STEAMOS_BACKUP=""
CLOVER_STEAMOS_BOOT_NUMBERS=""

clover_path_is_dir() {
    local path="$1"

    [ -d "$path" ] || toolbox_sudo test -d "$path" >/dev/null 2>&1
}

clover_path_is_file() {
    local path="$1"

    [ -f "$path" ] || toolbox_sudo test -f "$path" >/dev/null 2>&1
}

clover_path_is_nonempty_file() {
    local path="$1"

    [ -s "$path" ] || toolbox_sudo test -s "$path" >/dev/null 2>&1
}

clover_path_exists() {
    local path="$1"

    [ -e "$path" ] || toolbox_sudo test -e "$path" >/dev/null 2>&1
}

clover_path_is_symlink() {
    local path="$1"

    [ -L "$path" ] || toolbox_sudo test -L "$path" >/dev/null 2>&1
}

clover_prepare_admin_access() {
    [ "$(id -u 2>/dev/null || echo 1)" = "0" ] && return 0

    if load_toolbox_password >/dev/null 2>&1 && \
        toolbox_sudo true >/dev/null 2>&1; then
        TOOLBOX_PASSWORD=""
        unset TOOLBOX_PASSWORD
        return 0
    fi
    TOOLBOX_PASSWORD=""
    unset TOOLBOX_PASSWORD

    detect_platform
    if [ "$IS_BAZZITE" -ne 1 ]; then
        echo "管理员权限验证失败，请先在Renkit中录入管理员密码。"
        return 1
    fi

    echo "Bazzite 的 EFI 目录仅允许管理员读取。"
    echo "请录入一次当前 Bazzite 账户密码；验证成功后再继续安装 Clover。"
    bash "$PROJECT_ROOT/modules/password.sh" import || return 1
    toolbox_sudo true >/dev/null 2>&1 || {
        echo "管理员权限验证失败，EFI 和开机顺序均未修改。"
        return 1
    }
}

clover_candidate_is_esp() {
    local candidate="$1"

    clover_path_is_dir "$candidate/EFI" || return 1
    detect_platform
    if [ "$IS_BAZZITE" -eq 1 ]; then
        clover_path_is_file "$candidate/EFI/fedora/shimx64.efi" || \
            clover_path_is_file "$candidate/EFI/CLOVER/CLOVERX64.efi"
    else
        clover_path_is_file "$candidate/EFI/steamos/steamcl.efi" || \
            clover_path_is_file "$candidate/EFI/CLOVER/CLOVERX64.efi"
    fi
}

clover_nvram_partuuid() {
    local entries needle value

    entries="$(efibootmgr -v 2>/dev/null)" || return 1
    for needle in 'cloverx64.efi' 'steamcl.efi' 'shimx64.efi'; do
        value="$(printf '%s\n' "$entries" | awk -v needle="$needle" '
            index(tolower($0), needle) && match($0, /HD\([^,]+,GPT,[^,]+/) {
                value = substr($0, RSTART, RLENGTH)
                sub(/^.*GPT,/, "", value)
                print tolower(value)
                exit
            }
        ')"
        [ -z "$value" ] || { printf '%s\n' "$value"; return 0; }
    done
    return 1
}

clover_device_from_nvram() {
    local wanted device partuuid filesystem

    wanted="$(clover_nvram_partuuid)" || return 1
    while read -r device partuuid filesystem; do
        [ -n "$device" ] && [ -n "$partuuid" ] || continue
        if [ "$(printf '%s' "$partuuid" | tr '[:upper:]' '[:lower:]')" = "$wanted" ]; then
            case "$filesystem" in
                vfat|fat|fat32|msdos) printf '%s\n' "$device"; return 0 ;;
            esac
        fi
    done < <(lsblk -rpn -o NAME,PARTUUID,FSTYPE 2>/dev/null)
    return 1
}

clover_find_mounted_esp() {
    local candidate
    local detected

    # 某些 SteamOS 安装会把同一块 FAT 分区挂载到非标准位置，或保留空的
    # /esp 挂载点。只检查已经挂载的 FAT 分区，确认其中存在 SteamOS/Bazzite/Clover
    # 启动文件后才采用，不会挂载、写入或修改任何分区。
    while IFS= read -r candidate; do
        clover_candidate_is_esp "$candidate" || continue
        CLOVER_ESP_FOUND="$candidate"
        return 0
    done < <(findmnt -rn -t vfat,fat,fat32,msdos -o TARGET 2>/dev/null || true)
    return 1
}

clover_find_unmounted_esp() {
    local device
    local filesystem
    local mountpoint
    local output

    # 当 NVRAM 记录指向空 /esp 时，继续检查其余尚未挂载的 FAT 分区。
    # 只做临时挂载和只读文件存在性确认；不创建目录、不写入 EFI。
    command -v udisksctl >/dev/null 2>&1 || return 1
    while read -r device filesystem; do
        case "$device" in
            /dev/*) ;;
            *) continue ;;
        esac
        case "$filesystem" in
            vfat|fat|fat32|msdos) ;;
            *) continue ;;
        esac
        mountpoint="$(findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n 1)"
        [ -z "$mountpoint" ] || continue

        output="$(udisksctl mount --block-device "$device" 2>&1)" || continue
        mountpoint="$(findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n 1)"
        [ -n "$mountpoint" ] || \
            mountpoint="$(printf '%s\n' "$output" | sed -n 's/^Mounted .* at \(.*\)\.$/\1/p' | tail -n 1)"
        if clover_candidate_is_esp "$mountpoint"; then
            CLOVER_ESP_FOUND="$mountpoint"
            CLOVER_ESP_MOUNTED_BY_TOOLBOX=1
            CLOVER_ESP_MOUNT_DEVICE="$device"
            return 0
        fi
        udisksctl unmount --block-device "$device" >/dev/null 2>&1 || true
    done < <(lsblk -rpn -o NAME,FSTYPE 2>/dev/null)
    return 1
}

clover_find_esp() {
    local candidate detected device mountpoint output

    CLOVER_ESP_FOUND=""

    if command -v bootctl >/dev/null 2>&1; then
        for candidate in "$(bootctl --print-esp-path 2>/dev/null || true)" \
            "$(bootctl --print-boot-path 2>/dev/null || true)"; do
            [ -d "$candidate" ] || continue
            clover_candidate_is_esp "$candidate" || continue
            CLOVER_ESP_FOUND="$candidate"
            return 0
        done
    fi

    for candidate in /esp /boot/efi /efi /boot; do
        [ -d "$candidate" ] || continue
        clover_candidate_is_esp "$candidate" || continue
        CLOVER_ESP_FOUND="$candidate"
        return 0
    done

    clover_find_mounted_esp && return 0
    clover_find_unmounted_esp && return 0

    device="$(clover_device_from_nvram || true)"
    if [ -n "$device" ]; then
        mountpoint="$(findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n 1)"
        if [ -z "$mountpoint" ]; then
            command -v udisksctl >/dev/null 2>&1 || {
                echo "已从启动项定位到 EFI 分区 ${device}，但缺少 udisksctl，无法临时挂载。" >&2
                return 1
            }
            output="$(udisksctl mount --block-device "$device" 2>&1)" || {
                printf '%s\n' "$output" >&2
                return 1
            }
            mountpoint="$(findmnt -rn -S "$device" -o TARGET 2>/dev/null | head -n 1)"
            [ -n "$mountpoint" ] || \
                mountpoint="$(printf '%s\n' "$output" | sed -n 's/^Mounted .* at \(.*\)\.$/\1/p' | tail -n 1)"
            clover_candidate_is_esp "$mountpoint" || {
                udisksctl unmount --block-device "$device" >/dev/null 2>&1 || true
                if clover_path_is_dir "$mountpoint/EFI"; then
                    echo "临时挂载的分区不含当前系统的 EFI 启动文件。" >&2
                else
                    echo "临时挂载的分区不含 EFI 目录。" >&2
                fi
                return 1
            }
            CLOVER_ESP_MOUNTED_BY_TOOLBOX=1
            CLOVER_ESP_MOUNT_DEVICE="$device"
        fi
        clover_candidate_is_esp "$mountpoint" || {
            if clover_path_is_dir "$mountpoint/EFI"; then
                echo "定位到 EFI 分区 ${device}，但其挂载位置不含当前系统启动文件：${mountpoint:-未知}。" >&2
            else
                echo "定位到 EFI 分区 ${device}，但其挂载位置不含 EFI 目录：${mountpoint:-未知}。" >&2
            fi
            return 1
        }
        CLOVER_ESP_FOUND="$mountpoint"
        return 0
    fi

    echo "未找到 Clover/SteamOS/Bazzite 启动项对应的 EFI 系统分区。" >&2
    return 1
}

clover_release_esp_mount() {
    if [ "$CLOVER_ESP_MOUNTED_BY_TOOLBOX" = "1" ] && [ -n "$CLOVER_ESP_MOUNT_DEVICE" ]; then
        udisksctl unmount --block-device "$CLOVER_ESP_MOUNT_DEVICE" >/dev/null 2>&1 || true
    fi
    CLOVER_ESP_MOUNTED_BY_TOOLBOX=0
    CLOVER_ESP_MOUNT_DEVICE=""
}

clover_resolve_esp_device() {
    local filesystem
    local parent
    local partition

    clover_find_esp || return 1
    CLOVER_ESP="$CLOVER_ESP_FOUND"
    CLOVER_ESP_SOURCE="$(findmnt -rn -T "$CLOVER_ESP" -o SOURCE 2>/dev/null | head -n 1)"
    filesystem="$(findmnt -rn -T "$CLOVER_ESP" -o FSTYPE 2>/dev/null | head -n 1)"
    case "$CLOVER_ESP_SOURCE" in
        /dev/*) ;;
        *) echo "无法确认 EFI 系统分区对应的块设备。"; return 1 ;;
    esac
    case "$filesystem" in
        vfat|fat|fat32|msdos) ;;
        *) echo "EFI 系统分区文件系统不是 FAT：${filesystem:-未知}"; return 1 ;;
    esac

    parent="$(lsblk -nro PKNAME "$CLOVER_ESP_SOURCE" 2>/dev/null | head -n 1)"
    partition="$(lsblk -nro PARTN "$CLOVER_ESP_SOURCE" 2>/dev/null | head -n 1)"
    case "$parent" in
        ''|*[!A-Za-z0-9._-]*) echo "无法安全解析 EFI 所在磁盘。"; return 1 ;;
    esac
    case "$partition" in
        ''|*[!0-9]*) echo "无法安全解析 EFI 分区编号。"; return 1 ;;
    esac

    CLOVER_DISK="/dev/$parent"
    CLOVER_PARTITION="$partition"
}

clover_windows_entry_exists() {
    local entries

    entries="$(efibootmgr -v 2>/dev/null)" || return 1
    printf '%s\n' "$entries" | grep -Fi 'Windows Boot Manager' >/dev/null && return 0
    clover_path_is_file "$CLOVER_ESP/EFI/Microsoft/Boot/bootmgfw.efi" || \
        clover_path_is_file "$CLOVER_ESP/EFI/Microsoft/bootmgfw.efi"
}

clover_boot_number() {
    efibootmgr -v 2>/dev/null | clover_boot_number_from_input
}

clover_boot_number_from_input() {
    awk -v label="$CLOVER_BOOT_LABEL" '
        index($0, label) && tolower($0) ~ /cloverx64\.efi/ {
            value = substr($1, 5, 4)
            gsub(/[^0-9A-Fa-f]/, "", value)
            if (length(value) == 4) {
                print toupper(value)
                exit
            }
        }
    '
}

clover_steamos_boot_numbers_from_input() {
    awk '
        tolower($0) ~ /steamcl\.efi/ {
            value = substr($1, 5, 4)
            gsub(/[^0-9A-Fa-f]/, "", value)
            value = toupper(value)
            if (length(value) == 4 && !seen[value]++) print value
        }
    '
}

clover_detect_device() {
    local board_name product_name

    board_name="$(cat "$CLOVER_DMI_ROOT/board_name" 2>/dev/null || true)"
    product_name="$(cat "$CLOVER_DMI_ROOT/product_name" 2>/dev/null || true)"
    CLOVER_DEVICE_PREFIX=""
    CLOVER_DEVICE_NAME=""
    CLOVER_EFI_DRIVER=""
    CLOVER_SCREEN_RESOLUTION=""

    case "$board_name:$product_name" in
        *:G1618-03|*:*GPD*WIN*3*)
            CLOVER_DEVICE_PREFIX="Bazzite-generic"
            CLOVER_DEVICE_NAME="GPD WIN 3 ${product_name}"
            # GPD WIN 3 的 UEFI GOP 常把内置横屏面板报告为 720x1280。
            # Clover 没有通用的画面旋转开关，优先请求固件的横屏 GOP 模式。
            CLOVER_SCREEN_RESOLUTION="1280x720"
            ;;
        Jupiter:*|Galileo:*)
            CLOVER_DEVICE_PREFIX="SD"
            CLOVER_DEVICE_NAME="Steam Deck ${product_name}"
            ;;
        *:83N6|*:83L3|*:83Q2|*:83Q3)
            CLOVER_DEVICE_PREFIX="Legion-Go"
            CLOVER_DEVICE_NAME="Legion GO S ${product_name}"
            ;;
        *:83E1)
            CLOVER_DEVICE_PREFIX="Legion-Go"
            CLOVER_DEVICE_NAME="Legion GO ${product_name}"
            ;;
        RC71L:*)
            CLOVER_DEVICE_PREFIX="ROG-Ally"
            CLOVER_DEVICE_NAME="Asus ROG Ally ${board_name}"
            CLOVER_EFI_DRIVER="asusrogally.efi"
            ;;
        RC72LA:*)
            CLOVER_DEVICE_PREFIX="ROG-Ally"
            CLOVER_DEVICE_NAME="Asus ROG Ally X ${board_name}"
            CLOVER_EFI_DRIVER="asusrogallyx.efi"
            ;;
        RC73XA:*)
            CLOVER_DEVICE_PREFIX="ROG-Xbox-Ally"
            CLOVER_DEVICE_NAME="Asus ROG XBOX Ally X ${board_name}"
            CLOVER_EFI_DRIVER="asusrogallyx.efi"
            ;;
        *)
            detect_platform
            if [ "$IS_BAZZITE" -eq 1 ]; then
                CLOVER_DEVICE_PREFIX="Bazzite-generic"
                CLOVER_DEVICE_NAME="Bazzite 通用设备 ${product_name:-${board_name:-未知型号}}"
                CLOVER_DEVICE_CONFIG="$CLOVER_CONFIG_SOURCE"
            else
                echo "不支持当前设备，无法安装 Clover 双系统引导。"
                return 1
            fi
            ;;
    esac
}

clover_linux_name() {
    detect_platform
    if [ "$IS_BAZZITE" -eq 1 ]; then
        printf '%s\n' "Bazzite"
    else
        printf '%s\n' "SteamOS"
    fi
}

clover_choose_default_os() {
    local answer default="${ZHOUKEER_CLOVER_DEFAULT_OS:-}" linux_name

    linux_name="$(clover_linux_name)"
    case "$default" in
        "$linux_name"|Windows) printf '%s\n' "$default"; return 0 ;;
    esac
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        printf '%s\n' "$linux_name"
        return 0
    fi
    read -r -p "Clover 默认启动项（${linux_name}/Windows）：" answer
    case "$answer" in
        Windows|windows) printf '%s\n' "Windows" ;;
        *) printf '%s\n' "$linux_name" ;;
    esac
}

clover_configure_default_loader() {
    local config="$1"
    local default_os="$2"
    local temporary="${config}.new.$$"

    awk -v default_os="$default_os" '
        BEGIN {
            slash = sprintf("%c", 92)
            if (default_os == "Bazzite") loader = slash "EFI" slash "fedora" slash "shimx64.efi"
            else if (default_os == "Windows") loader = slash "EFI" slash "Microsoft" slash "Boot" slash "bootmgfw.efi"
            else loader = slash "EFI" slash "STEAMOS" slash "STEAMCL.efi"
        }
        /<key>DefaultLoader<\/key>/ {
            print
            if ((getline next_line) <= 0) exit 2
            match(next_line, /^[[:space:]]*/)
            print substr(next_line, 1, RLENGTH) "<string>" loader "</string>"
            found++
            next
        }
        { print }
        END { if (found != 1) exit 3 }
    ' "$config" > "$temporary" || {
        rm -f -- "$temporary"
        echo "无法设置 Clover 默认启动项。" >&2
        return 1
    }
    mv -- "$temporary" "$config"
}

clover_remove_steamos_entries() {
    local config="$1"
    local temporary="${config}.entries.$$"

    awk '
        function reset_entry() {
            entry = ""
            entry_depth = 0
            drop_entry = 0
            buffering = 0
        }
        {
            lower = tolower($0)
            if (!in_entries) {
                print
                if (lower ~ /<key>[[:space:]]*entries[[:space:]]*<\/key>/) {
                    waiting_for_array = 1
                } else if (waiting_for_array && lower ~ /<array>/) {
                    in_entries = 1
                    waiting_for_array = 0
                } else if (waiting_for_array && lower !~ /^[[:space:]]*$/) {
                    waiting_for_array = 0
                }
                next
            }
            if (buffering) {
                entry = entry $0 ORS
                if (lower ~ /steamcl\.efi/) drop_entry = 1
                if (lower ~ /<dict>/) entry_depth++
                if (lower ~ /<\/dict>/) entry_depth--
                if (entry_depth == 0) {
                    if (!drop_entry) printf "%s", entry
                    reset_entry()
                }
                next
            }
            if (lower ~ /<\/array>/) {
                print
                in_entries = 0
                next
            }
            if (lower ~ /<dict>/) {
                buffering = 1
                entry_depth = 1
                drop_entry = (lower ~ /steamcl\.efi/)
                entry = $0 ORS
                next
            }
            print
        }
        END {
            if (buffering || in_entries) exit 2
        }
    ' "$config" > "$temporary" || {
        rm -f -- "$temporary"
        echo "无法移除 Clover 中的旧 SteamOS 菜单项，配置文件未修改。" >&2
        return 1
    }
    if grep -Fi 'steamcl.efi' "$temporary" >/dev/null; then
        rm -f -- "$temporary"
        echo "Clover 配置仍包含旧 SteamOS 启动器，已停止安装。" >&2
        return 1
    fi
    mv -- "$temporary" "$config"
}

clover_configure_screen_resolution() {
    local config="$1"
    local resolution="${2:-}"
    local temporary="${config}.resolution.$$"

    case "$resolution" in
        ''|[0-9]*[xX][0-9]*) ;;
        *)
            echo "Clover 屏幕分辨率格式异常：$resolution" >&2
            return 1
            ;;
    esac

    awk -v resolution="$resolution" '
        /<key>ScreenResolution<\/key>/ {
            found++
            if (found > 1) {
                error = 4
                exit
            }
            if ((getline resolution_line) <= 0) {
                error = 2
                exit
            }
            if (resolution_line !~ /^[[:space:]]*<string>[0-9]+[xX][0-9]+<\/string>[[:space:]]*$/) {
                error = 3
                exit
            }
            if (resolution != "") {
                print
                match(resolution_line, /^[[:space:]]*/)
                print substr(resolution_line, 1, RLENGTH) "<string>" resolution "</string>"
            }
            next
        }
        { print }
        END {
            if (error) exit error
            if (resolution != "" && found != 1) exit 5
        }
    ' "$config" > "$temporary" || {
        rm -f -- "$temporary"
        echo "无法配置 Clover 屏幕分辨率，配置文件格式异常。" >&2
        return 1
    }
    mv -- "$temporary" "$config"
}

clover_ensure_windows_direct_boot() {
    local boot_dir microsoft_dir old_efi backup_efi moved_efi

    boot_dir="$CLOVER_ESP/EFI/Microsoft/Boot"
    microsoft_dir="$CLOVER_ESP/EFI/Microsoft"
    old_efi="$boot_dir/bootmgfw.efi"
    backup_efi="$boot_dir/bootmgfw.efi.zhoukeer-orig"
    moved_efi="$microsoft_dir/bootmgfw.efi"

    if clover_path_is_file "$old_efi"; then
        if clover_path_is_file "$moved_efi"; then
            toolbox_sudo rm -f -- "$moved_efi" || return 1
        fi
        if clover_path_is_file "$backup_efi"; then
            toolbox_sudo rm -f -- "$backup_efi" || return 1
        fi
    else
        toolbox_sudo mkdir -p -- "$boot_dir" || return 1
        if clover_path_is_file "$backup_efi"; then
            toolbox_sudo mv -- "$backup_efi" "$old_efi" || return 1
        elif clover_path_is_file "$moved_efi"; then
            toolbox_sudo mv -- "$moved_efi" "$old_efi" || return 1
        else
            echo "未找到 Windows 启动文件，无法保留 Windows 启动项。"
            return 1
        fi
        if clover_path_is_file "$moved_efi"; then
            toolbox_sudo rm -f -- "$moved_efi" || return 1
        fi
        if clover_path_is_file "$backup_efi"; then
            toolbox_sudo rm -f -- "$backup_efi" || return 1
        fi
    fi
    echo "Windows 官方启动文件已保留，桌面切换 Windows 可继续使用。"
}

clover_restore_windows_direct_boot() {
    clover_ensure_windows_direct_boot
}

clover_install_bootmanager() {
    local source_dir="$CLOVER_BOOTMANAGER_DIR"

    [ -f "$source_dir/clover-bootmanager.sh" ] && \
        [ -f "$source_dir/clover-bootmanager.service" ] || {
        echo "Renkit缺少 Clover 开机修复服务文件。"
        return 1
    }
    toolbox_sudo install -d -m 0755 -- "$CLOVER_BOOTMANAGER_SYSTEM_DIR" || return 1
    toolbox_sudo install -m 0755 -- \
        "$source_dir/clover-bootmanager.sh" \
        "$CLOVER_BOOTMANAGER_SYSTEM_DIR/clover-bootmanager.sh" || return 1
    toolbox_sudo install -m 0644 -- \
        "$source_dir/clover-bootmanager.service" \
        "$CLOVER_BOOTMANAGER_SYSTEM_DIR/clover-bootmanager.service" || return 1
    detect_platform
    if [ "$IS_STEAMOS" -eq 1 ]; then
        [ -f "$source_dir/clover-whitelist.conf" ] || {
            echo "Renkit缺少 SteamOS Clover 更新白名单。"
            return 1
        }
        toolbox_sudo install -d -m 0755 -- "$CLOVER_BOOTMANAGER_WHITELIST_DIR" || return 1
        toolbox_sudo install -m 0644 -- \
            "$source_dir/clover-whitelist.conf" \
            "$CLOVER_BOOTMANAGER_WHITELIST_DIR/clover-whitelist.conf" || return 1
    fi
    toolbox_sudo systemctl daemon-reload || return 1
    toolbox_sudo systemctl enable --now clover-bootmanager.service || return 1
    if [ "${ZHOUKEER_CLOVER_SKIP_BOOTMANAGER_RUN:-0}" != "1" ]; then
        toolbox_sudo "$CLOVER_BOOTMANAGER_SYSTEM_DIR/clover-bootmanager.sh" || return 1
    fi
    echo "Clover 开机修复服务已启用。"
}

clover_remove_bootmanager() {
    toolbox_sudo systemctl disable --now clover-bootmanager.service >/dev/null 2>&1 || true
    toolbox_sudo rm -f -- \
        "$CLOVER_BOOTMANAGER_SYSTEM_DIR/clover-bootmanager.service" \
        "$CLOVER_BOOTMANAGER_SYSTEM_DIR/clover-bootmanager.sh" \
        "$CLOVER_BOOTMANAGER_WHITELIST_DIR/clover-whitelist.conf" || return 1
    toolbox_sudo systemctl daemon-reload || return 1
}

clover_boot_order() {
    efibootmgr 2>/dev/null | sed -n 's/^BootOrder:[[:space:]]*//p' | head -n 1
}

clover_boot_order_is_safe() {
    local order="$1"
    local item
    local old_ifs="$IFS"

    [ -n "$order" ] || return 0
    case "$order" in
        ,*|*,|*,,*|*[!0-9A-Fa-f,]*) return 1 ;;
    esac
    IFS=','
    for item in $order; do
        IFS="$old_ifs"
        [ "${#item}" -eq 4 ] || return 1
        IFS=','
    done
    IFS="$old_ifs"
}

clover_backup_path_is_safe() {
    local path="$1"
    local root="$CLOVER_ESP/EFI/zhoukeer-backups"
    local name timestamp primary suffix

    [ -n "$path" ] || return 0
    case "$path" in
        "$root"/clover-before-*) ;;
        *) return 1 ;;
    esac
    name="${path##*/}"
    timestamp="${name#clover-before-}"
    primary="${timestamp%%-*}"
    [ "${#primary}" -eq 14 ] || return 1
    case "$primary" in
        *[!0-9]*) return 1 ;;
    esac
    [ "$timestamp" = "$primary" ] && return 0
    suffix="${timestamp#*-}"
    [ -n "$suffix" ] || return 1
    case "$suffix" in
        *[!0-9]*) return 1 ;;
    esac
}

clover_steamos_backup_path_is_safe() {
    local path="$1"
    local root="$CLOVER_ESP/EFI/zhoukeer-backups"
    local name timestamp primary suffix

    [ -n "$path" ] || return 0
    case "$path" in
        "$root"/steamos-before-*) ;;
        *) return 1 ;;
    esac
    name="${path##*/}"
    timestamp="${name#steamos-before-}"
    primary="${timestamp%%-*}"
    [ "${#primary}" -eq 14 ] || return 1
    case "$primary" in
        *[!0-9]*) return 1 ;;
    esac
    [ "$timestamp" = "$primary" ] && return 0
    suffix="${timestamp#*-}"
    [ -n "$suffix" ] || return 1
    case "$suffix" in
        *[!0-9]*) return 1 ;;
    esac
}

clover_boot_number_list_is_safe() {
    local numbers="$1" number

    [ -n "$numbers" ] || return 0
    while IFS= read -r number; do
        [ "${#number}" -eq 4 ] || return 1
        case "$number" in
            *[!0-9A-Fa-f]*) return 1 ;;
        esac
    done <<< "$numbers"
}

clover_replace_boot_numbers() {
    local order="$1" old_numbers="$2" replacement="$3"
    local item old_number result="" inserted=0 old_ifs="$IFS" matched

    IFS=','
    for item in $order; do
        IFS="$old_ifs"
        matched=0
        while IFS= read -r old_number; do
            [ -n "$old_number" ] || continue
            if [ "$(printf '%s' "$item" | tr '[:lower:]' '[:upper:]')" = \
                "$(printf '%s' "$old_number" | tr '[:lower:]' '[:upper:]')" ]; then
                matched=1
                break
            fi
        done <<< "$old_numbers"
        if [ "$matched" -eq 1 ]; then
            if [ "$inserted" -eq 0 ] && [ -n "$replacement" ]; then
                result="${result:+$result,}$replacement"
                inserted=1
            fi
        else
            result="${result:+$result,}$item"
        fi
        IFS=','
    done
    IFS="$old_ifs"
    printf '%s\n' "$result"
}

clover_prepend_boot_order() {
    local boot_number="$1"
    local current="$2"
    local item
    local result="$boot_number"
    local old_ifs="$IFS"

    IFS=','
    for item in $current; do
        IFS="$old_ifs"
        [ -n "$item" ] || continue
        [ "$(printf '%s' "$item" | tr '[:lower:]' '[:upper:]')" = "$boot_number" ] || \
            result="$result,$item"
        IFS=','
    done
    IFS="$old_ifs"
    printf '%s\n' "$result"
}

clover_archive_is_safe() {
    local archive="$1"
    local entry
    local count=0
    local listing

    listing="$(tar -tzf "$archive")" || return 1
    while IFS= read -r entry; do
        count=$((count + 1))
        case "$entry" in
            /*|../*|*/../*|*/..)
                echo "Clover 压缩包包含不安全路径：$entry"
                return 1
                ;;
        esac
    done <<< "$listing"
    [ "$count" -gt 0 ] && [ "$count" -le 5000 ] || {
        echo "Clover 压缩包文件数量异常：$count"
        return 1
    }
    if tar -tvzf "$archive" | awk '$1 ~ /^l/ { found=1 } END { exit found ? 0 : 1 }'; then
        echo "Clover 压缩包包含符号链接，已拒绝解压。"
        return 1
    fi
    grep -Fx 'Clover/clover/cloverx64.efi' <<< "$listing" >/dev/null || {
        echo "Clover 压缩包缺少 CLOVERX64.efi。"
        return 1
    }
    grep -Eq '^Clover/custom/[A-Za-z0-9-]+-config\.plist$' <<< "$listing" >/dev/null || {
        echo "Clover 压缩包缺少设备配置文件。"
        return 1
    }
}

clover_prepare_staging() {
    local archive="$1"
    local work_dir="$2"
    local extracted="$work_dir/extracted"
    local staged="$work_dir/CLOVER"
    local source_clover="$extracted/Clover/clover"
    local loader_source loader_temporary

    clover_archive_is_safe "$archive" || return 1
    mkdir -p "$extracted" "$staged/themes" || return 1
    tar -xzf "$archive" -C "$extracted" || return 1

    [ -s "$source_clover/cloverx64.efi" ] || {
        echo "解压后缺少可用的 CLOVERX64.efi。" >&2
        return 1
    }
    [ -f "${CLOVER_DEVICE_CONFIG:-$CLOVER_CONFIG_SOURCE}" ] || {
        echo "Renkit缺少 Clover 配置文件：${CLOVER_DEVICE_CONFIG:-$CLOVER_CONFIG_SOURCE}" >&2
        return 1
    }
    [ -f "$CLOVER_THEME_SOURCE/background.png" ] || {
        echo "Renkit缺少 Clover 主题背景：$CLOVER_THEME_SOURCE/background.png" >&2
        return 1
    }
    [ -f "$CLOVER_THEME_SOURCE/theme.plist" ] || {
        echo "Renkit缺少 Clover 主题配置：$CLOVER_THEME_SOURCE/theme.plist" >&2
        return 1
    }

    cp -R -- "$source_clover/." "$staged/" || return 1
    [ -f "$staged/cloverx64.efi" ] || {
        echo "解压后缺少 cloverx64.efi。" >&2
        return 1
    }
    # FAT32 不区分文件名大小写。不能同时保留 cloverx64.efi 和 CLOVERX64.efi，
    # 否则从 Linux 临时目录复制到 EFI 时会因目标文件已存在而失败。
    loader_source="$staged/cloverx64.efi"
    loader_temporary="$staged/.cloverx64.efi.renkit.$$"
    mv -- "$loader_source" "$loader_temporary" || return 1
    mv -- "$loader_temporary" "$staged/CLOVERX64.efi" || return 1
    cp -- "${CLOVER_DEVICE_CONFIG:-$CLOVER_CONFIG_SOURCE}" "$staged/config.plist" || return 1
    clover_configure_default_loader "$staged/config.plist" "${CLOVER_DEFAULT_OS:-SteamOS}" || return 1
    if [ "${CLOVER_DEFAULT_OS:-SteamOS}" = "Bazzite" ]; then
        clover_remove_steamos_entries "$staged/config.plist" || return 1
    fi
    clover_configure_screen_resolution "$staged/config.plist" \
        "${CLOVER_SCREEN_RESOLUTION:-}" || return 1
    mkdir -p "$staged/themes/zhoukeer-phantom" || return 1
    cp -R -- "$CLOVER_THEME_SOURCE/." "$staged/themes/zhoukeer-phantom/" || return 1
    if [ -n "$CLOVER_EFI_DRIVER" ]; then
        [ -f "$CLOVER_DRIVER_DIR/$CLOVER_EFI_DRIVER" ] || {
            echo "Renkit缺少设备 Clover 驱动：$CLOVER_EFI_DRIVER" >&2
            return 1
        }
        mkdir -p "$staged/drivers/uefi" || return 1
        cp -- "$CLOVER_DRIVER_DIR/$CLOVER_EFI_DRIVER" \
            "$staged/drivers/uefi/$CLOVER_EFI_DRIVER" || return 1
    fi
    find "$staged" -type d -exec chmod 0755 {} + || return 1
    find "$staged" -type f -exec chmod 0644 {} + || return 1
    printf '%s\n' "$staged"
}

clover_marker_value() {
    local marker="$1"
    local key="$2"

    if [ -r "$marker" ]; then
        sed -n "s/^${key}=//p" "$marker" | head -n 1
    else
        toolbox_sudo sed -n "s/^${key}=//p" "$marker" 2>/dev/null | head -n 1
    fi
}

clover_write_marker() {
    local staged="$1"
    local original_backup="$2"
    local original_order="$3"

    cat > "$staged/.zhoukeer-managed" <<EOF
VERSION=$CLOVER_VERSION
ORIGINAL_BACKUP=$original_backup
ORIGINAL_BOOT_ORDER=$original_order
EOF
    chmod 0644 "$staged/.zhoukeer-managed"
}

clover_append_steamos_marker() {
    local marker="$1" backup="$2" numbers="$3" temporary

    temporary="$(mktemp)" || return 1
    if clover_path_is_file "$marker"; then
        toolbox_sudo cat -- "$marker" > "$temporary" || {
            rm -f -- "$temporary"
            return 1
        }
    fi
    {
        printf 'STEAMOS_BACKUP=%s\n' "$backup"
        printf 'STEAMOS_BOOT_NUMBERS=%s\n' "$(printf '%s\n' "$numbers" | awk '
            NF { value = value (value ? "," : "") $0 }
            END { print value }
        ')"
    } >> "$temporary"
    toolbox_sudo cp -- "$temporary" "$marker" || {
        rm -f -- "$temporary"
        return 1
    }
    rm -f -- "$temporary"
}

clover_cleanup_legacy_steamos() {
    local old_dir backup_root backup timestamp numbers number delete_count=0 number_count
    local deleted_numbers="" marker

    detect_platform
    [ "$IS_BAZZITE" -eq 1 ] || return 0
    clover_path_is_file "$CLOVER_ESP/EFI/fedora/shimx64.efi" || {
        echo "未确认 Bazzite EFI 启动文件，拒绝清理旧 SteamOS 引导。" >&2
        return 1
    }
    old_dir="$CLOVER_ESP/EFI/steamos"
    numbers="$(toolbox_sudo efibootmgr -v 2>/dev/null | clover_steamos_boot_numbers_from_input)"
    if ! clover_path_is_dir "$old_dir" && [ -z "$numbers" ]; then
        return 0
    fi
    clover_boot_number_list_is_safe "$numbers" || {
        echo "旧 SteamOS NVRAM 启动项格式异常，拒绝清理。" >&2
        return 1
    }
    number_count="$(printf '%s\n' "$numbers" | awk 'NF { count++ } END { print count + 0 }')"
    [ "$number_count" -le 8 ] || {
        echo "旧 SteamOS NVRAM 启动项数量异常，拒绝清理。" >&2
        return 1
    }

    backup_root="$CLOVER_ESP/EFI/zhoukeer-backups"
    clover_path_is_symlink "$backup_root" && {
        echo "EFI 备份目录是符号链接，拒绝清理旧 SteamOS 引导。" >&2
        return 1
    }
    clover_path_is_symlink "$old_dir" && {
        echo "旧 SteamOS EFI 目录是符号链接，拒绝清理。" >&2
        return 1
    }
    timestamp="$(date +%Y%m%d%H%M%S)-$$"
    backup="$backup_root/steamos-before-$timestamp"
    toolbox_sudo mkdir -p -- "$backup_root" || return 1
    if clover_path_is_dir "$old_dir"; then
        clover_path_exists "$backup" && {
            echo "旧 SteamOS 备份目标已存在，拒绝覆盖。" >&2
            return 1
        }
        toolbox_sudo mv -- "$old_dir" "$backup" || {
            echo "备份旧 SteamOS EFI 目录失败，未删除启动项。" >&2
            return 1
        }
    else
        backup=""
    fi

    while IFS= read -r number; do
        [ -n "$number" ] || continue
        delete_count=$((delete_count + 1))
        if ! toolbox_sudo efibootmgr --delete-bootnum --bootnum "$number"; then
            [ -z "$backup" ] || toolbox_sudo mv -- "$backup" "$old_dir" >/dev/null 2>&1 || true
            if [ -n "$deleted_numbers" ] && clover_path_is_file "$old_dir/steamcl.efi"; then
                toolbox_sudo efibootmgr --create --disk "$CLOVER_DISK" \
                    --part "$CLOVER_PARTITION" --label "SteamOS" \
                    --loader '\EFI\steamos\steamcl.efi' >/dev/null 2>&1 || true
            fi
            echo "清理旧 SteamOS NVRAM 启动项失败，已尝试恢复启动文件。" >&2
            return 1
        fi
        deleted_numbers="${deleted_numbers}${deleted_numbers:+$'\n'}$number"
    done <<< "$numbers"

    marker="$CLOVER_ESP/EFI/CLOVER/.zhoukeer-managed"
    if ! clover_append_steamos_marker "$marker" "$backup" "$numbers"; then
        [ -z "$backup" ] || toolbox_sudo mv -- "$backup" "$old_dir" >/dev/null 2>&1 || true
        if [ -n "$numbers" ] && clover_path_is_file "$old_dir/steamcl.efi"; then
            toolbox_sudo efibootmgr --create --disk "$CLOVER_DISK" \
                --part "$CLOVER_PARTITION" --label "SteamOS" \
                --loader '\EFI\steamos\steamcl.efi' >/dev/null 2>&1 || true
        fi
        echo "记录旧 SteamOS 备份失败，已尝试恢复。" >&2
        return 1
    fi
    CLOVER_STEAMOS_BACKUP="$backup"
    CLOVER_STEAMOS_BOOT_NUMBERS="$numbers"
    echo "已清理旧 SteamOS 引导；启动文件备份：${backup:-无残留目录}"
    log "旧SteamOS引导已清理: backup=${backup:-none} boot_numbers=$(printf '%s\n' "$numbers" | awk '
        NF { value = value (value ? "," : "") $0 }
        END { print value }
    ')"
}

clover_show_install_risk() {
    echo "================================================"
    echo " Clover 开机选择菜单"
    echo "================================================"
    echo "版本：Clover ${CLOVER_VERSION}（Gitee 分块镜像）"
    echo "设备：${CLOVER_DEVICE_NAME:-Steam Deck/掌机}"
    if [ -n "${CLOVER_SCREEN_RESOLUTION:-}" ]; then
        echo "主题：自定义怪盗；分辨率：${CLOVER_SCREEN_RESOLUTION}（设备专用横屏）"
    else
        echo "主题：自定义怪盗；分辨率：UEFI 自动识别"
    fi
    echo "EFI 分区：$CLOVER_ESP ($CLOVER_ESP_SOURCE)"
    echo "目标：$CLOVER_ESP/EFI/CLOVER"
    echo "NVRAM：新增 ${CLOVER_BOOT_LABEL}，并放到现有 BootOrder 首位"
    echo ""
    echo "不会覆盖 EFI/BOOT/BOOTX64.EFI；会保留 Windows 官方启动文件和启动项。"
    detect_platform
    if [ "$IS_BAZZITE" -eq 1 ]; then
        echo "Bazzite 安装时若检测到旧 SteamOS 引导，会先备份再自动清理，不删除任何系统分区。"
    fi
    echo "安装完成后会启用 Clover 开机修复服务。"
    echo "已有 CLOVER 目录和原 BootOrder 会先备份；恢复入口可撤销本次安装。"
    echo "若掌机按键在 Clover 中不可用，请连接 USB 键盘；倒计时后进入默认系统。"
}

clover_confirm_install() {
    local answer

    clover_show_install_risk
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit界面确认，开始安装 Clover。"
        return 0
    fi
    read -r -p "确认写入 EFI 并修改开机顺序请输入 CLOVER：" answer
    [ "$answer" = "CLOVER" ]
}

clover_confirm_restore() {
    local answer

    if [ "${ZHOUKEER_CLOVER_DELETE:-0}" = "1" ]; then
        echo "将删除Renkit创建的 Clover 双系统引导，并恢复安装前的 BootOrder。"
    else
        echo "将移除Renkit创建的 Clover 启动项，并恢复安装前的 BootOrder。"
    fi
    echo "如果安装前已有 CLOVER 目录，也会从备份恢复。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认恢复原开机方式请输入 RESTORE：" answer
    [ "$answer" = "RESTORE" ]
}

clover_delete() {
    ZHOUKEER_CLOVER_DELETE=1 clover_restore
}

clover_install() {
    local work_dir archive staged target backup_root timestamp
    local existing_backup original_backup original_order current_order new_order staging_log
    local temporary_target boot_number new_boot_entry=0 create_output available_kb
    local inherited_steamos_backup inherited_steamos_numbers final_order

    echo "正在检查 Clover 安装环境…"
    require_supported_gaming_os || return 1
    clover_detect_device || return 1
    for command_name in curl tar findmnt lsblk efibootmgr awk sed df sudo; do
        require_command "$command_name" || return 1
    done
    [ -f "$CLOVER_THEME_SOURCE/background.png" ] || {
        echo "Clover 怪盗主题资源缺失，请更新Renkit后重试。"
        return 1
    }
    clover_prepare_admin_access || return 1
    clover_resolve_esp_device || {
        echo "无法定位可用 EFI 系统分区，EFI 和开机顺序均未修改。"
        return 1
    }
    clover_windows_entry_exists || {
        echo "未检测到 Windows Boot Manager，已停止安装 Clover。"
        return 1
    }
    available_kb="$(toolbox_sudo df -Pk "$CLOVER_ESP" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    case "$available_kb" in
        ''|*[!0-9]*) echo "无法确认 EFI 系统分区剩余空间。"; return 1 ;;
    esac
    [ "$available_kb" -ge 20480 ] || {
        echo "EFI 系统分区剩余空间不足 20 MB，已停止安装 Clover。"
        return 1
    }
    default_os="$(clover_choose_default_os)" || return 1
    CLOVER_DEFAULT_OS="$default_os"
    if [ "$CLOVER_DEVICE_PREFIX" = "Bazzite-generic" ]; then
        CLOVER_DEVICE_CONFIG="$CLOVER_CONFIG_SOURCE"
    elif [ "$default_os" = "Windows" ]; then
        CLOVER_DEVICE_CONFIG="$CLOVER_DEVICE_DIR/${CLOVER_DEVICE_PREFIX}-win-config.plist"
    else
        CLOVER_DEVICE_CONFIG="$CLOVER_DEVICE_DIR/${CLOVER_DEVICE_PREFIX}-config.plist"
    fi
    [ -f "$CLOVER_DEVICE_CONFIG" ] || {
        echo "Renkit缺少设备 Clover 配置文件：$CLOVER_DEVICE_CONFIG"
        return 1
    }
    clover_confirm_install || {
        echo "已取消 Clover 安装，EFI 和开机顺序未修改。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，EFI 未修改。"
        return 1
    }

    work_dir="$(mktemp -d)" || {
        echo "无法创建 Clover 临时工作目录，EFI 未修改。"
        return 1
    }
    archive="$work_dir/$CLOVER_ARCHIVE"
    if ! download_gitee_mirror_file "$CLOVER_MIRROR_ID" "$archive" \
        "$CLOVER_MIRROR_SHA256" "Clover 资源"; then
        rm -rf -- "$work_dir"
        return 1
    fi
    staging_log="$work_dir/staging.log"
    if ! clover_prepare_staging "$archive" "$work_dir" \
        >/dev/null 2>"$staging_log"; then
        [ ! -s "$staging_log" ] || cat -- "$staging_log"
        rm -rf -- "$work_dir"
        echo "Clover 安装文件准备失败，EFI 未修改。"
        return 1
    fi
    staged="$work_dir/CLOVER"

    target="$CLOVER_ESP/EFI/CLOVER"
    backup_root="$CLOVER_ESP/EFI/zhoukeer-backups"
    timestamp="$(date +%Y%m%d%H%M%S)-$$"
    existing_backup="$backup_root/clover-before-$timestamp"
    temporary_target="$CLOVER_ESP/EFI/.CLOVER.zhoukeer-new.$$"
    current_order="$(clover_boot_order)"
    [ -n "$current_order" ] && clover_boot_order_is_safe "$current_order" || {
        rm -rf -- "$work_dir"
        echo "无法安全读取固件 BootOrder，EFI 未修改。"
        return 1
    }
    original_order="$current_order"
    original_backup=""
    inherited_steamos_backup=""
    inherited_steamos_numbers=""

    if clover_path_is_file "$target/.zhoukeer-managed"; then
        original_order="$(clover_marker_value "$target/.zhoukeer-managed" ORIGINAL_BOOT_ORDER)"
        original_backup="$(clover_marker_value "$target/.zhoukeer-managed" ORIGINAL_BACKUP)"
        inherited_steamos_backup="$(clover_marker_value "$target/.zhoukeer-managed" STEAMOS_BACKUP)"
        inherited_steamos_numbers="$(clover_marker_value "$target/.zhoukeer-managed" STEAMOS_BOOT_NUMBERS | tr ',' '\n')"
        clover_boot_order_is_safe "$original_order" && \
            clover_backup_path_is_safe "$original_backup" && \
            clover_steamos_backup_path_is_safe "$inherited_steamos_backup" && \
            clover_boot_number_list_is_safe "$inherited_steamos_numbers" || {
            rm -rf -- "$work_dir"
            echo "现有 Clover 管理标记格式异常，EFI 未修改。"
            return 1
        }
        if [ -n "$original_backup" ] && \
            { ! clover_path_is_dir "$original_backup" || clover_path_is_symlink "$original_backup"; }; then
            rm -rf -- "$work_dir"
            echo "现有 Clover 原始备份不存在或不是安全目录，EFI 未修改。"
            return 1
        fi
    elif clover_path_exists "$target"; then
        original_backup="$existing_backup"
    fi
    if clover_path_exists "$existing_backup"; then
        rm -rf -- "$work_dir"
        echo "Clover 备份目标已存在，EFI 未修改，请稍后重试。"
        return 1
    fi
    clover_write_marker "$staged" "$original_backup" "$original_order" || {
        rm -rf -- "$work_dir"
        return 1
    }
    if [ -n "$inherited_steamos_backup" ] || [ -n "$inherited_steamos_numbers" ]; then
        {
            printf 'STEAMOS_BACKUP=%s\n' "$inherited_steamos_backup"
            printf 'STEAMOS_BOOT_NUMBERS=%s\n' "$(printf '%s\n' "$inherited_steamos_numbers" | awk '
                NF { value = value (value ? "," : "") $0 }
                END { print value }
            ')"
        } >> "$staged/.zhoukeer-managed"
    fi

    toolbox_sudo mkdir -p -- "$CLOVER_ESP/EFI" "$backup_root" || {
        rm -rf -- "$work_dir"
        return 1
    }
    # EFI 通常是 FAT32，不支持 Linux 所有权、权限和时间戳。不能使用 cp -a，
    # 否则 GNU cp 会在文件内容已复制后因 chown/chmod 失败而整体返回失败。
    toolbox_sudo cp -R -- "$staged" "$temporary_target" || {
        toolbox_sudo rm -rf -- "$temporary_target" >/dev/null 2>&1 || true
        rm -rf -- "$work_dir"
        echo "复制 Clover 到 EFI 失败，原启动文件未修改。"
        return 1
    }
    if clover_path_exists "$target"; then
        toolbox_sudo mv -- "$target" "$existing_backup" || {
            toolbox_sudo rm -rf -- "$temporary_target" >/dev/null 2>&1 || true
            rm -rf -- "$work_dir"
            echo "备份现有 Clover 失败，已停止安装。"
            return 1
        }
    fi
    if ! toolbox_sudo mv -- "$temporary_target" "$target"; then
        if clover_path_exists "$existing_backup"; then
            toolbox_sudo mv -- "$existing_backup" "$target" || true
        fi
        rm -rf -- "$work_dir"
        echo "启用新 Clover 文件失败，已尝试恢复原目录。"
        return 1
    fi

    boot_number="$(clover_boot_number)"
    if [ -z "$boot_number" ]; then
        if ! create_output="$(toolbox_sudo efibootmgr --create --disk "$CLOVER_DISK" \
            --part "$CLOVER_PARTITION" --label "$CLOVER_BOOT_LABEL" \
            --loader "$CLOVER_LOADER_PATH")"; then
            toolbox_sudo mv -- "$target" "$temporary_target" || true
            if clover_path_exists "$existing_backup"; then
                toolbox_sudo mv -- "$existing_backup" "$target" || true
            fi
            rm -rf -- "$work_dir"
            echo "创建 Clover NVRAM 启动项失败，已尝试恢复原目录。"
            return 1
        fi
        new_boot_entry=1
        printf '%s\n' "$create_output"
        boot_number="$(printf '%s\n' "$create_output" | clover_boot_number_from_input)"
        [ -n "$boot_number" ] || \
            boot_number="$(toolbox_sudo efibootmgr -v 2>/dev/null | clover_boot_number_from_input)"
    fi
    if [ -z "$boot_number" ]; then
        echo "无法确认 Clover NVRAM 启动项编号，正在回滚。"
        toolbox_sudo mv -- "$target" "$temporary_target" || true
        if clover_path_exists "$existing_backup"; then
            toolbox_sudo mv -- "$existing_backup" "$target" || true
        fi
        rm -rf -- "$work_dir"
        return 1
    fi

    new_order="$(clover_prepend_boot_order "$boot_number" "$current_order")"
    if ! toolbox_sudo efibootmgr --bootorder "$new_order"; then
        [ "$new_boot_entry" -eq 0 ] || toolbox_sudo efibootmgr --delete-bootnum --bootnum "$boot_number" || true
        toolbox_sudo mv -- "$target" "$temporary_target" || true
        if clover_path_exists "$existing_backup"; then
            toolbox_sudo mv -- "$existing_backup" "$target" || true
        fi
        [ -z "$current_order" ] || toolbox_sudo efibootmgr --bootorder "$current_order" || true
        rm -rf -- "$work_dir"
        echo "设置 Clover 开机顺序失败，已尝试恢复原状态。"
        return 1
    fi

    if ! clover_ensure_windows_direct_boot; then
        echo "Clover 已安装，但 Windows 启动文件修复失败，请重新运行修复。"
        rm -rf -- "$work_dir"
        return 1
    fi
    if ! clover_install_bootmanager; then
        echo "Clover 已安装，但开机修复服务安装失败，请重新运行修复。"
        rm -rf -- "$work_dir"
        return 1
    fi

    if [ -z "$inherited_steamos_backup" ] && [ -z "$inherited_steamos_numbers" ]; then
        if ! clover_cleanup_legacy_steamos; then
            echo "Clover 已安装，但旧 SteamOS 引导清理失败；请重新运行安装/修复。"
            rm -rf -- "$work_dir"
            return 1
        fi
    else
        CLOVER_STEAMOS_BACKUP="$inherited_steamos_backup"
        CLOVER_STEAMOS_BOOT_NUMBERS="$inherited_steamos_numbers"
    fi

    rm -rf -- "$work_dir"
    final_order="$(clover_boot_order)"
    echo "Clover $CLOVER_VERSION 已安装，自定义怪盗开机主题已启用。"
    echo "默认启动项：${default_os}；开机将显示 $(clover_linux_name) 和 Windows。"
    echo "原 BootOrder：${original_order:-未读取到}"
    echo "当前 BootOrder：${final_order:-$new_order}"
    [ -z "$original_backup" ] || echo "原 Clover 备份：$original_backup"
    [ -z "$CLOVER_STEAMOS_BACKUP" ] || echo "旧 SteamOS 引导备份：$CLOVER_STEAMOS_BACKUP"
    log "Clover安装完成: version=$CLOVER_VERSION esp=$CLOVER_ESP boot=$boot_number"
}

clover_restore() {
    local target marker original_backup original_order backup_root removed_path
    local boot_number timestamp delete_count=0 steamos_backup steamos_numbers
    local restored_steamos_number restored_order create_output

    require_supported_gaming_os || return 1
    for command_name in findmnt lsblk efibootmgr awk sed sudo; do
        require_command "$command_name" || return 1
    done
    clover_prepare_admin_access || return 1
    clover_resolve_esp_device || return 1
    target="$CLOVER_ESP/EFI/CLOVER"
    marker="$target/.zhoukeer-managed"
    clover_path_is_file "$marker" || {
        echo "未发现由Renkit管理的 Clover，未执行恢复。"
        return 1
    }
    clover_confirm_restore || {
        echo "已取消恢复，开机方式未修改。"
        return 0
    }
    original_backup="$(clover_marker_value "$marker" ORIGINAL_BACKUP)"
    original_order="$(clover_marker_value "$marker" ORIGINAL_BOOT_ORDER)"
    steamos_backup="$(clover_marker_value "$marker" STEAMOS_BACKUP)"
    steamos_numbers="$(clover_marker_value "$marker" STEAMOS_BOOT_NUMBERS | tr ',' '\n')"
    clover_backup_path_is_safe "$original_backup" || {
        echo "Clover 备份路径标记异常，已拒绝恢复。"
        return 1
    }
    clover_boot_order_is_safe "$original_order" || {
        echo "Clover BootOrder 标记异常，已拒绝恢复。"
        return 1
    }
    clover_steamos_backup_path_is_safe "$steamos_backup" && \
        clover_boot_number_list_is_safe "$steamos_numbers" || {
        echo "旧 SteamOS 备份标记异常，已拒绝恢复。"
        return 1
    }
    if [ -n "$original_backup" ] && \
        { ! clover_path_is_dir "$original_backup" || clover_path_is_symlink "$original_backup"; }; then
        echo "原 Clover 备份不存在或不是安全目录，已拒绝恢复。"
        return 1
    fi
    toolbox_sudo true || return 1

    restored_order="$original_order"
    if [ -n "$steamos_backup" ]; then
        clover_path_is_dir "$steamos_backup" || {
            echo "旧 SteamOS 启动文件备份不存在，已拒绝恢复原引导。"
            return 1
        }
        clover_path_exists "$CLOVER_ESP/EFI/steamos" && {
            echo "EFI/steamos 已存在，拒绝覆盖恢复。"
            return 1
        }
        toolbox_sudo mv -- "$steamos_backup" "$CLOVER_ESP/EFI/steamos" || return 1
    fi
    if [ -n "$steamos_numbers" ] && \
        clover_path_is_file "$CLOVER_ESP/EFI/steamos/steamcl.efi"; then
        restored_steamos_number="$(toolbox_sudo efibootmgr -v 2>/dev/null | \
            clover_steamos_boot_numbers_from_input | head -n 1)"
        if [ -z "$restored_steamos_number" ]; then
            create_output="$(toolbox_sudo efibootmgr --create --disk "$CLOVER_DISK" \
                --part "$CLOVER_PARTITION" --label "SteamOS" \
                --loader '\EFI\steamos\steamcl.efi')" || return 1
            restored_steamos_number="$(printf '%s\n' "$create_output" | \
                clover_steamos_boot_numbers_from_input)"
            [ -n "$restored_steamos_number" ] || \
                restored_steamos_number="$(toolbox_sudo efibootmgr -v 2>/dev/null | \
                    clover_steamos_boot_numbers_from_input | head -n 1)"
        fi
        [ -n "$restored_steamos_number" ] || {
            echo "恢复旧 SteamOS NVRAM 启动项失败。"
            return 1
        }
        restored_order="$(clover_replace_boot_numbers "$original_order" \
            "$steamos_numbers" "$restored_steamos_number")"
    fi

    if [ -n "$restored_order" ] && ! toolbox_sudo efibootmgr --bootorder "$restored_order"; then
        echo "恢复原 BootOrder 失败；Clover 文件暂时保留。"
        return 1
    fi
    while boot_number="$(toolbox_sudo efibootmgr -v 2>/dev/null | clover_boot_number_from_input)" && \
        [ -n "$boot_number" ]; do
        delete_count=$((delete_count + 1))
        [ "$delete_count" -le 8 ] || {
            echo "Clover NVRAM 启动项数量异常，已停止恢复。"
            return 1
        }
        toolbox_sudo efibootmgr --delete-bootnum --bootnum "$boot_number" || {
            echo "删除 Clover NVRAM 启动项失败，已停止恢复。"
            return 1
        }
    done

    backup_root="$CLOVER_ESP/EFI/zhoukeer-backups"
    timestamp="$(date +%Y%m%d%H%M%S)"
    removed_path="$backup_root/clover-removed-$timestamp"
    toolbox_sudo mkdir -p -- "$backup_root" || return 1
    toolbox_sudo mv -- "$target" "$removed_path" || return 1
    if [ -n "$original_backup" ] && clover_path_is_dir "$original_backup"; then
        if ! toolbox_sudo mv -- "$original_backup" "$target"; then
            toolbox_sudo mv -- "$removed_path" "$target" || true
            echo "恢复原 Clover 目录失败，已尝试放回Renkit版本。"
            return 1
        fi
        echo "已恢复安装前的 Clover 目录：$target"
    else
        echo "Renkit安装的 Clover 已移出启动目录，备份保存在：$removed_path"
    fi
    clover_restore_windows_direct_boot || {
        echo "警告：Windows 直启文件恢复失败，请检查 EFI/Microsoft 目录。"
    }
    clover_remove_bootmanager || {
        echo "警告：Clover 开机修复服务未能完全移除，请手动检查 systemd。"
        return 1
    }
    echo "原开机顺序已恢复：${restored_order:-由固件自动整理}"
    log "Clover已恢复: esp=$CLOVER_ESP"
}

clover_status() {
    local target boot_number

    require_supported_gaming_os || return 1
    for command_name in findmnt lsblk efibootmgr awk sed sudo; do
        require_command "$command_name" || return 1
    done
    clover_prepare_admin_access || return 1
    clover_resolve_esp_device || return 1
    target="$CLOVER_ESP/EFI/CLOVER"
    boot_number="$(clover_boot_number)"
    if clover_path_is_file "$target/.zhoukeer-managed" && \
        clover_path_is_nonempty_file "$target/CLOVERX64.efi"; then
        echo "Clover：已由Renkit安装"
        echo "版本：$(clover_marker_value "$target/.zhoukeer-managed" VERSION)"
        echo "EFI：$target"
        echo "NVRAM：${boot_number:-未检测到启动项}"
        [ -n "$boot_number" ]
        return
    fi
    echo "Clover：未由Renkit安装"
    [ -z "$boot_number" ] || echo "检测到非完整状态的 NVRAM 启动项：$boot_number"
    return 1
}

clover_apply_renkit_background() {
    local target

    require_supported_gaming_os || return 1
    for command_name in findmnt lsblk sudo; do
        require_command "$command_name" || return 1
    done
    clover_prepare_admin_access || return 1
    clover_find_esp || return 1
    CLOVER_ESP="$CLOVER_ESP_FOUND"
    target="$CLOVER_ESP/EFI/CLOVER/themes/Apocalypse/background.png"
    [ -f "$CLOVER_THEME_SOURCE/background.png" ] || {
        echo "Renkit缺少 Clover 主题背景：$CLOVER_THEME_SOURCE/background.png" >&2
        return 1
    }
    toolbox_sudo mkdir -p -- "$(dirname "$target")" || return 1
    toolbox_sudo cp -- "$CLOVER_THEME_SOURCE/background.png" "$target" || return 1
    echo "Renkit 开机背景已应用到 Clover Apocalypse 主题：$target"
    log "Renkit开机背景已应用: $target"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    trap clover_release_esp_mount EXIT
    case "${1:-status}" in
        install) clover_install ;;
        restore) clover_restore ;;
        delete) clover_delete ;;
        status) clover_status ;;
        apply-background) clover_apply_renkit_background ;;
        *) echo "用法: $0 {install|restore|delete|status|apply-background}"; exit 1 ;;
    esac
fi
