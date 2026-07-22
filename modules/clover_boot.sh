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
CLOVER_REPOSITORY="CloverHackyColor/CloverBootloader"
CLOVER_ARCHIVE="CloverV2-${CLOVER_VERSION}.zip"
CLOVER_ARCHIVE_SHA256="f92b0a6abff6290a4cd2f3f269369428edcddd90f5ea7b25d8dc5f35160ad03a"
CLOVER_BOOT_LABEL="Zhoukeer Clover"
CLOVER_LOADER_PATH='\EFI\CLOVER\CLOVERX64.efi'
CLOVER_THEME_SOURCE="$PROJECT_ROOT/assets/clover/zhoukeer-phantom"
CLOVER_CONFIG_SOURCE="$PROJECT_ROOT/assets/clover/config.plist"
CLOVER_ESP=""
CLOVER_ESP_SOURCE=""
CLOVER_DISK=""
CLOVER_PARTITION=""

clover_find_esp() {
    local candidate
    local detected

    if command -v bootctl >/dev/null 2>&1; then
        for candidate in "$(bootctl --print-esp-path 2>/dev/null || true)" \
            "$(bootctl --print-boot-path 2>/dev/null || true)"; do
            [ -d "$candidate" ] || continue
            detected="$(find "$candidate/EFI" -maxdepth 3 -type f -iname steamcl.efi -print -quit 2>/dev/null || true)"
            [ -n "$detected" ] || continue
            printf '%s\n' "$candidate"
            return 0
        done
    fi

    for candidate in /esp /boot/efi /efi /boot; do
        [ -d "$candidate" ] || continue
        detected="$(find "$candidate/EFI" -maxdepth 3 -type f -iname steamcl.efi -print -quit 2>/dev/null || true)"
        [ -n "$detected" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done

    echo "未找到包含 SteamOS 启动文件的 EFI 系统分区。" >&2
    return 1
}

clover_resolve_esp_device() {
    local filesystem
    local parent
    local partition

    CLOVER_ESP="$(clover_find_esp)" || return 1
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
    efibootmgr -v 2>/dev/null | grep -Fqi 'Windows Boot Manager'
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

    while IFS= read -r entry; do
        count=$((count + 1))
        case "$entry" in
            /*|../*|*/../*|*/..)
                echo "Clover 压缩包包含不安全路径：$entry"
                return 1
                ;;
        esac
    done < <(unzip -Z1 "$archive")
    [ "$count" -gt 0 ] && [ "$count" -le 5000 ] || {
        echo "Clover 压缩包文件数量异常：$count"
        return 1
    }
    if zipinfo -l "$archive" | awk '$1 ~ /^l/ { found=1 } END { exit found ? 0 : 1 }'; then
        echo "Clover 压缩包包含符号链接，已拒绝解压。"
        return 1
    fi
    unzip -Z1 "$archive" | grep -Fxq 'CloverV2/EFI/CLOVER/CLOVERX64.efi' || {
        echo "Clover 压缩包缺少 CLOVERX64.efi。"
        return 1
    }
    unzip -Z1 "$archive" | grep -Fxq 'CloverV2/themespkg/Glass/theme.plist' || {
        echo "Clover 压缩包缺少基础主题资源。"
        return 1
    }
}

clover_prepare_staging() {
    local archive="$1"
    local work_dir="$2"
    local extracted="$work_dir/extracted"
    local staged="$work_dir/CLOVER"

    clover_archive_is_safe "$archive" || return 1
    mkdir -p "$extracted" "$staged/themes" || return 1
    unzip -q "$archive" \
        'CloverV2/EFI/CLOVER/CLOVERX64.efi' \
        'CloverV2/themespkg/Glass/*' \
        -d "$extracted" || return 1

    [ -s "$extracted/CloverV2/EFI/CLOVER/CLOVERX64.efi" ] || return 1
    [ -f "$CLOVER_CONFIG_SOURCE" ] || return 1
    [ -f "$CLOVER_THEME_SOURCE/background.png" ] || return 1
    [ -f "$CLOVER_THEME_SOURCE/theme.plist" ] || return 1

    cp -- "$extracted/CloverV2/EFI/CLOVER/CLOVERX64.efi" "$staged/CLOVERX64.efi" || return 1
    cp -- "$CLOVER_CONFIG_SOURCE" "$staged/config.plist" || return 1
    cp -R -- "$extracted/CloverV2/themespkg/Glass" "$staged/themes/zhoukeer-phantom" || return 1
    cp -- "$CLOVER_THEME_SOURCE/background.png" \
        "$staged/themes/zhoukeer-phantom/background.png" || return 1
    cp -- "$CLOVER_THEME_SOURCE/theme.plist" \
        "$staged/themes/zhoukeer-phantom/theme.plist" || return 1
    find "$staged" -type d -exec chmod 0755 {} + || return 1
    find "$staged" -type f -exec chmod 0644 {} + || return 1
    printf '%s\n' "$staged"
}

clover_marker_value() {
    local marker="$1"
    local key="$2"

    sed -n "s/^${key}=//p" "$marker" | head -n 1
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

clover_show_install_risk() {
    echo "================================================"
    echo " Clover 开机选择菜单"
    echo "================================================"
    echo "版本：Clover $CLOVER_VERSION（官方 GitHub Release）"
    echo "主题：自定义怪盗与 Steam Deck，分辨率 1280×800"
    echo "EFI 分区：$CLOVER_ESP ($CLOVER_ESP_SOURCE)"
    echo "目标：$CLOVER_ESP/EFI/CLOVER"
    echo "NVRAM：新增 $CLOVER_BOOT_LABEL，并放到现有 BootOrder 首位"
    echo ""
    echo "不会覆盖 EFI/BOOT/BOOTX64.EFI，不会修改 Windows bootmgfw.efi。"
    echo "已有 CLOVER 目录和原 BootOrder 会先备份；恢复入口可撤销本次安装。"
    echo "若掌机按键在 Clover 中不可用，请连接 USB 键盘；8 秒后默认进入 SteamOS。"
}

clover_confirm_install() {
    local answer

    clover_show_install_risk
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过工具箱界面确认，开始安装 Clover。"
        return 0
    fi
    read -r -p "确认写入 EFI 并修改开机顺序请输入 CLOVER：" answer
    [ "$answer" = "CLOVER" ]
}

clover_confirm_restore() {
    local answer

    echo "将移除工具箱创建的 Clover 启动项，并恢复安装前的 BootOrder。"
    echo "如果安装前已有 CLOVER 目录，也会从备份恢复。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认恢复原开机方式请输入 RESTORE：" answer
    [ "$answer" = "RESTORE" ]
}

clover_install() {
    local work_dir archive staged target backup_root timestamp
    local existing_backup original_backup original_order current_order new_order
    local temporary_target boot_number new_boot_entry=0 create_output available_kb

    require_steamos || return 1
    for command_name in curl unzip zipinfo findmnt lsblk efibootmgr awk sed df; do
        require_command "$command_name" || return 1
    done
    [ -f "$CLOVER_THEME_SOURCE/background.png" ] || {
        echo "Clover 怪盗主题资源缺失，请更新工具箱后重试。"
        return 1
    }
    clover_resolve_esp_device || return 1
    clover_windows_entry_exists || {
        echo "未检测到 Windows Boot Manager，已停止安装 Clover。"
        return 1
    }
    available_kb="$(df -Pk "$CLOVER_ESP" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    case "$available_kb" in
        ''|*[!0-9]*) echo "无法确认 EFI 系统分区剩余空间。"; return 1 ;;
    esac
    [ "$available_kb" -ge 20480 ] || {
        echo "EFI 系统分区剩余空间不足 20 MB，已停止安装 Clover。"
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

    work_dir="$(mktemp -d)" || return 1
    archive="$work_dir/$CLOVER_ARCHIVE"
    if ! download_github_release "$CLOVER_REPOSITORY" "$CLOVER_VERSION" \
        "$CLOVER_ARCHIVE" "$archive" "$CLOVER_ARCHIVE_SHA256" "Clover $CLOVER_VERSION"; then
        rm -rf -- "$work_dir"
        return 1
    fi
    staged="$(clover_prepare_staging "$archive" "$work_dir")" || {
        rm -rf -- "$work_dir"
        echo "Clover 安装文件准备失败，EFI 未修改。"
        return 1
    }

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

    if [ -f "$target/.zhoukeer-managed" ]; then
        original_order="$(clover_marker_value "$target/.zhoukeer-managed" ORIGINAL_BOOT_ORDER)"
        original_backup="$(clover_marker_value "$target/.zhoukeer-managed" ORIGINAL_BACKUP)"
        clover_boot_order_is_safe "$original_order" && \
            clover_backup_path_is_safe "$original_backup" || {
            rm -rf -- "$work_dir"
            echo "现有 Clover 管理标记格式异常，EFI 未修改。"
            return 1
        }
        if [ -n "$original_backup" ] && { [ ! -d "$original_backup" ] || [ -L "$original_backup" ]; }; then
            rm -rf -- "$work_dir"
            echo "现有 Clover 原始备份不存在或不是安全目录，EFI 未修改。"
            return 1
        fi
    elif [ -e "$target" ]; then
        original_backup="$existing_backup"
    fi
    [ ! -e "$existing_backup" ] || {
        rm -rf -- "$work_dir"
        echo "Clover 备份目标已存在，EFI 未修改，请稍后重试。"
        return 1
    }
    clover_write_marker "$staged" "$original_backup" "$original_order" || {
        rm -rf -- "$work_dir"
        return 1
    }

    toolbox_sudo mkdir -p -- "$CLOVER_ESP/EFI" "$backup_root" || {
        rm -rf -- "$work_dir"
        return 1
    }
    toolbox_sudo cp -a -- "$staged" "$temporary_target" || {
        toolbox_sudo rm -rf -- "$temporary_target" >/dev/null 2>&1 || true
        rm -rf -- "$work_dir"
        echo "复制 Clover 到 EFI 失败，原启动文件未修改。"
        return 1
    }
    if [ -e "$target" ]; then
        toolbox_sudo mv -- "$target" "$existing_backup" || {
            toolbox_sudo rm -rf -- "$temporary_target" >/dev/null 2>&1 || true
            rm -rf -- "$work_dir"
            echo "备份现有 Clover 失败，已停止安装。"
            return 1
        }
    fi
    if ! toolbox_sudo mv -- "$temporary_target" "$target"; then
        [ ! -e "$existing_backup" ] || toolbox_sudo mv -- "$existing_backup" "$target" || true
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
            [ ! -e "$existing_backup" ] || toolbox_sudo mv -- "$existing_backup" "$target" || true
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
        [ ! -e "$existing_backup" ] || toolbox_sudo mv -- "$existing_backup" "$target" || true
        rm -rf -- "$work_dir"
        return 1
    fi

    new_order="$(clover_prepend_boot_order "$boot_number" "$current_order")"
    if ! toolbox_sudo efibootmgr --bootorder "$new_order"; then
        [ "$new_boot_entry" -eq 0 ] || toolbox_sudo efibootmgr --delete-bootnum --bootnum "$boot_number" || true
        toolbox_sudo mv -- "$target" "$temporary_target" || true
        [ ! -e "$existing_backup" ] || toolbox_sudo mv -- "$existing_backup" "$target" || true
        [ -z "$current_order" ] || toolbox_sudo efibootmgr --bootorder "$current_order" || true
        rm -rf -- "$work_dir"
        echo "设置 Clover 开机顺序失败，已尝试恢复原状态。"
        return 1
    fi

    rm -rf -- "$work_dir"
    echo "Clover $CLOVER_VERSION 已安装，自定义怪盗开机主题已启用。"
    echo "开机将显示 SteamOS 和 Windows；8 秒无操作时默认进入 SteamOS。"
    echo "原 BootOrder：${original_order:-未读取到}"
    echo "当前 BootOrder：$new_order"
    [ -z "$original_backup" ] || echo "原 Clover 备份：$original_backup"
    log "Clover安装完成: version=$CLOVER_VERSION esp=$CLOVER_ESP boot=$boot_number"
}

clover_restore() {
    local target marker original_backup original_order backup_root removed_path
    local boot_number timestamp delete_count=0

    require_steamos || return 1
    for command_name in findmnt lsblk efibootmgr awk sed; do
        require_command "$command_name" || return 1
    done
    clover_resolve_esp_device || return 1
    target="$CLOVER_ESP/EFI/CLOVER"
    marker="$target/.zhoukeer-managed"
    [ -f "$marker" ] || {
        echo "未发现由工具箱管理的 Clover，未执行恢复。"
        return 1
    }
    clover_confirm_restore || {
        echo "已取消恢复，开机方式未修改。"
        return 0
    }
    original_backup="$(clover_marker_value "$marker" ORIGINAL_BACKUP)"
    original_order="$(clover_marker_value "$marker" ORIGINAL_BOOT_ORDER)"
    clover_backup_path_is_safe "$original_backup" || {
        echo "Clover 备份路径标记异常，已拒绝恢复。"
        return 1
    }
    clover_boot_order_is_safe "$original_order" || {
        echo "Clover BootOrder 标记异常，已拒绝恢复。"
        return 1
    }
    if [ -n "$original_backup" ] && { [ ! -d "$original_backup" ] || [ -L "$original_backup" ]; }; then
        echo "原 Clover 备份不存在或不是安全目录，已拒绝恢复。"
        return 1
    fi
    toolbox_sudo true || return 1

    if [ -n "$original_order" ] && ! toolbox_sudo efibootmgr --bootorder "$original_order"; then
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
    if [ -n "$original_backup" ] && [ -d "$original_backup" ]; then
        if ! toolbox_sudo mv -- "$original_backup" "$target"; then
            toolbox_sudo mv -- "$removed_path" "$target" || true
            echo "恢复原 Clover 目录失败，已尝试放回工具箱版本。"
            return 1
        fi
        echo "已恢复安装前的 Clover 目录：$target"
    else
        echo "工具箱安装的 Clover 已移出启动目录，备份保存在：$removed_path"
    fi
    echo "原开机顺序已恢复：${original_order:-由固件自动整理}"
    log "Clover已恢复: esp=$CLOVER_ESP"
}

clover_status() {
    local target boot_number

    require_steamos || return 1
    for command_name in findmnt lsblk efibootmgr awk sed; do
        require_command "$command_name" || return 1
    done
    clover_resolve_esp_device || return 1
    target="$CLOVER_ESP/EFI/CLOVER"
    boot_number="$(clover_boot_number)"
    if [ -f "$target/.zhoukeer-managed" ] && [ -s "$target/CLOVERX64.efi" ]; then
        echo "Clover：已由工具箱安装"
        echo "版本：$(clover_marker_value "$target/.zhoukeer-managed" VERSION)"
        echo "EFI：$target"
        echo "NVRAM：${boot_number:-未检测到启动项}"
        [ -n "$boot_number" ]
        return
    fi
    echo "Clover：未由工具箱安装"
    [ -z "$boot_number" ] || echo "检测到非完整状态的 NVRAM 启动项：$boot_number"
    return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-status}" in
        install) clover_install ;;
        restore) clover_restore ;;
        status) clover_status ;;
        *) echo "用法: $0 {install|restore|status}"; exit 1 ;;
    esac
fi
