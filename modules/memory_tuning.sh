#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

MEMORY_SWAPFILE_PATH="${ZHOUKEER_SWAPFILE_PATH:-$(dirname "$HOME")/swapfile}"
MEMORY_FALLBACK_SWAPFILE_PATH="${ZHOUKEER_MEMORY_FALLBACK_SWAPFILE_PATH:-$(dirname "$MEMORY_SWAPFILE_PATH")/.zhoukeer-swapfile}"
MEMORY_ZRAM_CONFIG="${ZHOUKEER_ZRAM_CONFIG:-/etc/systemd/zram-generator.conf.d/90-zhoukeer.conf}"
MEMORY_SYSCTL_CONFIG="${ZHOUKEER_MEMORY_SYSCTL_CONFIG:-/etc/sysctl.d/90-zhoukeer-memory.conf}"
MEMORY_SYSTEMD_DIR="${ZHOUKEER_SYSTEMD_DIR:-/etc/systemd/system}"
MEMORY_MIN_FREE_GIB="${ZHOUKEER_MEMORY_MIN_FREE_GIB:-4}"
MEMORY_SWAPFILE_WAS_IMMUTABLE=0
MEMORY_UNIT_WAS_ENABLED=0

memory_value_is_positive_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -gt 0 ] ;;
    esac
}

memory_total_kib() {
    awk '/^MemTotal:/ { print $2; exit }' "${ZHOUKEER_MEMINFO:-/proc/meminfo}"
}

recommended_swap_gib() {
    local memory_kib memory_gib

    memory_kib="$(memory_total_kib)" || return 1
    memory_value_is_positive_integer "$memory_kib" || return 1
    memory_gib=$(((memory_kib + 1048575) / 1048576))
    [ "$memory_gib" -ge 8 ] || memory_gib=8
    [ "$memory_gib" -le 16 ] || memory_gib=16
    printf '%s\n' "$memory_gib"
}

memory_file_size_bytes() {
    if stat -c '%s' -- "$1" >/dev/null 2>&1; then
        stat -c '%s' -- "$1"
    else
        stat -f '%z' -- "$1"
    fi
}

memory_swap_is_active() {
    local requested="$1"
    local requested_real candidate candidate_real

    requested_real="$(readlink -f -- "$requested" 2>/dev/null || printf '%s' "$requested")"
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        candidate_real="$(readlink -f -- "$candidate" 2>/dev/null || printf '%s' "$candidate")"
        [ "$candidate" = "$requested" ] || [ "$candidate_real" = "$requested_real" ] || continue
        return 0
    done < <(swapon --noheadings --raw --output NAME 2>/dev/null)
    return 1
}

memory_clear_immutable_attribute() {
    local path="$1"
    local attributes

    MEMORY_SWAPFILE_WAS_IMMUTABLE=0
    attributes="$(toolbox_sudo lsattr -d -- "$path" 2>/dev/null | awk 'NR == 1 { print $1 }')"
    case "$attributes" in
        *i*)
            toolbox_sudo chattr -i -- "$path" 2>/dev/null || {
                echo "现有 swap 带不可变保护且无法临时解除，未做替换。"
                return 1
            }
            MEMORY_SWAPFILE_WAS_IMMUTABLE=1
            echo "已临时解除现有 swap 的不可变保护。"
            ;;
    esac
}

memory_restore_immutable_attribute() {
    local path="$1"

    [ "$MEMORY_SWAPFILE_WAS_IMMUTABLE" -eq 1 ] || return 0
    toolbox_sudo test -e "$path" || return 0
    toolbox_sudo chattr +i -- "$path" || {
        echo "警告：原 swap 已恢复，但不可变属性未能恢复：$path"
        return 1
    }
}

memory_move_swapfile_after_forced_immutable_clear() {
    local source_path="$1"
    local backup_path="$2"

    echo "现有 swap 首次移动失败，正在再次解除不可变保护后重试..."
    toolbox_sudo chattr -i -- "$source_path" || return 1
    toolbox_sudo mv -- "$source_path" "$backup_path" || return 1

    # 首次 lsattr 读取可能在部分 SteamOS 文件系统上失败；本次通过
    # chattr -i 后才能移动，回滚时仍须恢复旧文件的不可变保护。
    MEMORY_SWAPFILE_WAS_IMMUTABLE=1
    echo "已解除现有 swap 的不可变保护并完成备份。"
}

memory_activate_fallback_swapfile() {
    local new_file="$1"
    local backup_file="${MEMORY_FALLBACK_SWAPFILE_PATH}.backup.$$"
    local fallback_was_active=0

    toolbox_sudo test ! -e "$backup_file" || return 1
    if toolbox_sudo test -e "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        if ! toolbox_sudo test -f "$MEMORY_FALLBACK_SWAPFILE_PATH" || \
            toolbox_sudo test -L "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
            echo "Renkit备用 swap 路径不是安全的普通文件，已保留原内容。"
            return 1
        fi
        if memory_swap_is_active "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
            fallback_was_active=1
            toolbox_sudo swapoff "$MEMORY_FALLBACK_SWAPFILE_PATH" || return 1
        fi
        memory_clear_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || {
            [ "$fallback_was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
            return 1
        }
        if ! toolbox_sudo mv -- "$MEMORY_FALLBACK_SWAPFILE_PATH" "$backup_file"; then
            memory_restore_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
            [ "$fallback_was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
            return 1
        fi
    fi
    if ! toolbox_sudo mv -- "$new_file" "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        toolbox_sudo test ! -e "$backup_file" || \
            toolbox_sudo mv -- "$backup_file" "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
        memory_restore_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
        [ "$fallback_was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
        return 1
    fi
    if ! toolbox_sudo swapon --priority 10 "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        toolbox_sudo rm -f -- "$MEMORY_FALLBACK_SWAPFILE_PATH"
        toolbox_sudo test ! -e "$backup_file" || \
            toolbox_sudo mv -- "$backup_file" "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
        memory_restore_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
        [ "$fallback_was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
        return 1
    fi
    toolbox_sudo rm -f -- "$backup_file" || true
    MEMORY_SWAPFILE_PATH="$MEMORY_FALLBACK_SWAPFILE_PATH"
    echo "旧 swap 受系统保护无法移动，已保留原文件并启用Renkit独立 swap：$MEMORY_SWAPFILE_PATH"
    return 0
}

memory_swapfile_is_complete() {
    local path="$1"
    local target_gib="$2"
    local expected_bytes actual_bytes swap_type

    toolbox_sudo test -f "$path" && ! toolbox_sudo test -L "$path" || return 1
    expected_bytes=$((target_gib * 1024 * 1024 * 1024))
    actual_bytes="$(memory_file_size_bytes "$path")" || return 1
    [ "$actual_bytes" -eq "$expected_bytes" ] || return 1
    swap_type="$(toolbox_sudo blkid -p -s TYPE -o value "$path" 2>/dev/null || true)"
    [ "$swap_type" = "swap" ]
}

memory_validate_paths() {
    local path

    for path in "$MEMORY_SWAPFILE_PATH" "$MEMORY_FALLBACK_SWAPFILE_PATH" "$MEMORY_ZRAM_CONFIG" \
        "$MEMORY_SYSCTL_CONFIG" "$MEMORY_SYSTEMD_DIR"; do
        case "$path" in
            /*) ;;
            *) echo "虚拟内存路径必须是绝对路径：$path"; return 1 ;;
        esac
        case "$path" in
            *[!A-Za-z0-9_./-]*)
                echo "虚拟内存路径包含不支持的字符：$path"
                return 1
                ;;
        esac
    done
    memory_value_is_positive_integer "$MEMORY_MIN_FREE_GIB" || {
        echo "虚拟内存保留空间配置无效。"
        return 1
    }
    [ "$MEMORY_SWAPFILE_PATH" != "$MEMORY_FALLBACK_SWAPFILE_PATH" ] || {
        echo "主 swap 与Renkit备用 swap 路径不能相同。"
        return 1
    }
}

memory_swap_unit_name_for_path() {
    systemd-escape --path --suffix=swap "$1"
}

memory_swap_unit_name() {
    memory_swap_unit_name_for_path "$MEMORY_SWAPFILE_PATH"
}

memory_show_status() {
    local target_gib current_swappiness

    target_gib="$(recommended_swap_gib 2>/dev/null || true)"
    echo "========== 虚拟内存状态 =========="
    echo "推荐组合：zram = 物理内存的一半，磁盘 swap = ${target_gib:-8-16}GB"
    echo "优先级：zram 100，磁盘 swap 10"
    current_swappiness="$(sysctl -n vm.swappiness 2>/dev/null || true)"
    echo "当前 swappiness：${current_swappiness:-无法读取}"
    if command -v zramctl >/dev/null 2>&1; then
        zramctl 2>/dev/null || true
    fi
    if command -v swapon >/dev/null 2>&1; then
        swapon --show 2>/dev/null || true
    fi
}

memory_confirm_optimize() {
    local answer

    echo "将设置 zram、8-16GB 磁盘 swap 和 swappiness。"
    echo "原 swap 会先安全停用并备份，失败时自动恢复。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认优化请输入 OPTIMIZE MEMORY：" answer
    [ "$answer" = "OPTIMIZE MEMORY" ]
}

memory_confirm_restore() {
    local answer

    echo "将删除Renkit创建的 zram、swappiness 和独立 swap；系统原 swap 会保留。"
    echo "撤销将在重启后完全生效。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认撤销请输入 RESTORE MEMORY：" answer
    [ "$answer" = "RESTORE MEMORY" ]
}

memory_write_config() {
    local target="$1"
    local source="$2"

    if toolbox_sudo test -e "$target" && ! toolbox_sudo test -f "$target"; then
        echo "配置路径不是普通文件，未覆盖：$target"
        return 1
    fi
    if toolbox_sudo test -f "$target" && \
       ! toolbox_sudo grep -Fq '# Managed by Zhoukeer Toolbox' "$target"; then
        echo "发现非Renkit管理的配置，未覆盖：$target"
        return 1
    fi
    toolbox_sudo install -d -m 0755 -- "$(dirname "$target")" || return 1
    toolbox_sudo install -m 0644 -- "$source" "$target"
}

memory_config_target_is_safe() {
    local target="$1"

    if toolbox_sudo test -e "$target" && ! toolbox_sudo test -f "$target"; then
        echo "配置路径不是普通文件，未覆盖：$target"
        return 1
    fi
    if toolbox_sudo test -f "$target" && \
       ! toolbox_sudo grep -Fq '# Managed by Zhoukeer Toolbox' "$target"; then
        echo "发现非Renkit管理的配置，未覆盖：$target"
        return 1
    fi
}

memory_file_is_toolbox_managed() {
    local path="$1"

    toolbox_sudo test -f "$path" &&
        ! toolbox_sudo test -L "$path" &&
        toolbox_sudo grep -Fqx '# Managed by Zhoukeer Toolbox' "$path"
}

memory_swap_unit_is_toolbox_managed() {
    local unit_path="$1"
    local swap_path="$2"

    memory_file_is_toolbox_managed "$unit_path" &&
        toolbox_sudo grep -Fqx "What=$swap_path" "$unit_path"
}

memory_remove_managed_config() {
    local path="$1"

    if ! toolbox_sudo test -e "$path" && ! toolbox_sudo test -L "$path"; then
        return 0
    fi
    if ! memory_file_is_toolbox_managed "$path"; then
        echo "发现非Renkit配置，已保留：$path"
        return 0
    fi
    toolbox_sudo rm -f -- "$path" || {
        echo "Renkit配置删除失败：$path"
        return 1
    }
}

memory_disable_managed_unit() {
    local unit_name="$1"
    local unit_state

    MEMORY_UNIT_WAS_ENABLED=0
    unit_state="$(toolbox_sudo systemctl is-enabled "$unit_name" 2>/dev/null || true)"
    case "$unit_state" in
        enabled|enabled-runtime|linked|linked-runtime|alias)
            MEMORY_UNIT_WAS_ENABLED=1
            ;;
        disabled|static|indirect|masked|not-found)
            return 0
            ;;
    esac
    if toolbox_sudo systemctl disable "$unit_name" >/dev/null 2>&1; then
        return 0
    fi
    unit_state="$(toolbox_sudo systemctl is-enabled "$unit_name" 2>/dev/null || true)"
    case "$unit_state" in
        disabled|static|indirect|masked|not-found) return 0 ;;
    esac
    echo "无法停用Renkit swap 开机配置，未继续删除：$unit_name"
    log "虚拟内存撤销失败: systemd单元无法停用 unit=$unit_name state=${unit_state:-unknown}"
    return 1
}

memory_restore_managed_unit_enablement() {
    local unit_name="$1"

    [ "$MEMORY_UNIT_WAS_ENABLED" -eq 1 ] || return 0
    toolbox_sudo systemctl enable "$unit_name" >/dev/null 2>&1 || {
        echo "警告：无法恢复 swap 开机启用状态：$unit_name"
        return 1
    }
}

memory_remove_managed_main_unit() {
    local unit_name="$1"
    local unit_path="$MEMORY_SYSTEMD_DIR/$unit_name"

    if ! toolbox_sudo test -e "$unit_path" && ! toolbox_sudo test -L "$unit_path"; then
        return 0
    fi
    if ! memory_swap_unit_is_toolbox_managed "$unit_path" "$MEMORY_SWAPFILE_PATH"; then
        echo "发现非Renkit swap 配置，已保留：$unit_path"
        return 0
    fi
    memory_disable_managed_unit "$unit_name" || return 1
    if ! toolbox_sudo rm -f -- "$unit_path"; then
        memory_restore_managed_unit_enablement "$unit_name" || true
        echo "Renkit swap 开机配置删除失败：$unit_path"
        return 1
    fi
}

memory_remove_managed_fallback_swap() {
    local unit_name="$1"
    local unit_path="$MEMORY_SYSTEMD_DIR/$unit_name"
    local fallback_was_active=0
    local swap_type

    if ! toolbox_sudo test -e "$unit_path" && ! toolbox_sudo test -L "$unit_path"; then
        return 0
    fi
    if ! memory_swap_unit_is_toolbox_managed "$unit_path" "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        echo "发现非Renkit swap 配置，已保留：$unit_path"
        return 0
    fi
    if toolbox_sudo test -e "$MEMORY_FALLBACK_SWAPFILE_PATH" || \
       toolbox_sudo test -L "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        if ! toolbox_sudo test -f "$MEMORY_FALLBACK_SWAPFILE_PATH" || \
           toolbox_sudo test -L "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
            echo "Renkit独立 swap 路径异常，已保留。"
            return 1
        fi
        swap_type="$(toolbox_sudo blkid -p -s TYPE -o value \
            "$MEMORY_FALLBACK_SWAPFILE_PATH" 2>/dev/null || true)"
        if [ "$swap_type" != "swap" ]; then
            echo "Renkit独立 swap 内容异常，已保留。"
            return 1
        fi
    fi
    memory_disable_managed_unit "$unit_name" || return 1
    if memory_swap_is_active "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        fallback_was_active=1
        if ! toolbox_sudo swapoff "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
            memory_restore_managed_unit_enablement "$unit_name" || true
            echo "Renkit独立 swap 正在使用，无法安全停用。"
            return 1
        fi
    fi
    if toolbox_sudo test -e "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
        memory_clear_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || {
            [ "$fallback_was_active" -eq 0 ] || \
                toolbox_sudo swapon --priority 10 "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
            memory_restore_managed_unit_enablement "$unit_name" || true
            echo "Renkit独立 swap 的文件保护无法解除，未删除。"
            return 1
        }
        if ! toolbox_sudo rm -f -- "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
            parent_attributes="$(toolbox_sudo lsattr -d -- \
                "$(dirname "$MEMORY_FALLBACK_SWAPFILE_PATH")" 2>/dev/null | \
                awk 'NR == 1 { print $1 }')"
            case "$parent_attributes" in
                *i*|*a*)
                    memory_restore_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
                    [ "$fallback_was_active" -eq 0 ] || \
                        toolbox_sudo swapon --priority 10 "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
                    memory_restore_managed_unit_enablement "$unit_name" || true
                    echo "Renkit独立 swap 所在目录受保护，未自动解除：$(dirname "$MEMORY_FALLBACK_SWAPFILE_PATH")"
                    return 1
                    ;;
            esac
            # lsattr 读取失败或命令不可用时，也直接尝试解除文件自身的
            # immutable 保护后再删除一次，避免撤销被 SteamOS 保护卡住。
            if toolbox_sudo chattr -i -- "$MEMORY_FALLBACK_SWAPFILE_PATH" >/dev/null 2>&1 && \
               toolbox_sudo rm -f -- "$MEMORY_FALLBACK_SWAPFILE_PATH"; then
                :
            else
                memory_restore_immutable_attribute "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
                [ "$fallback_was_active" -eq 0 ] || \
                    toolbox_sudo swapon --priority 10 "$MEMORY_FALLBACK_SWAPFILE_PATH" || true
                memory_restore_managed_unit_enablement "$unit_name" || true
                echo "Renkit独立 swap 删除失败，已尝试恢复原状态。"
                return 1
            fi
        fi
    fi
    toolbox_sudo rm -f -- "$unit_path" || {
        echo "Renkit swap 开机配置删除失败：$unit_path"
        return 1
    }
}

memory_create_swapfile() {
    local target_gib="$1"
    local swap_dir new_file backup_file free_kib required_kib was_active=0

    swap_dir="$(dirname "$MEMORY_SWAPFILE_PATH")"
    [ -d "$swap_dir" ] && [ ! -L "$swap_dir" ] || {
        echo "swap 所在目录不存在或是符号链接：$swap_dir"
        return 1
    }
    new_file="$swap_dir/.zhoukeer-swapfile.new.$$"
    backup_file="$swap_dir/.zhoukeer-swapfile.backup.$$"
    toolbox_sudo test ! -e "$new_file" || return 1
    toolbox_sudo test ! -e "$backup_file" || return 1

    free_kib="$(df -Pk "$swap_dir" | awk 'NR > 1 { value=$4 } END { print value }')"
    memory_value_is_positive_integer "$free_kib" || return 1
    required_kib=$(((target_gib + MEMORY_MIN_FREE_GIB) * 1024 * 1024))
    [ "$free_kib" -ge "$required_kib" ] || {
        echo "内部存储空间不足：创建 ${target_gib}GB swap 后至少还需保留 ${MEMORY_MIN_FREE_GIB}GB。"
        return 1
    }

    echo "正在创建 ${target_gib}GB 磁盘 swap 临时文件..."
    toolbox_sudo fallocate -l "${target_gib}G" "$new_file" || return 1
    toolbox_sudo chmod 0600 "$new_file" || {
        toolbox_sudo rm -f -- "$new_file"
        return 1
    }
    toolbox_sudo mkswap "$new_file" >/dev/null || {
        toolbox_sudo rm -f -- "$new_file"
        return 1
    }

    if memory_swap_is_active "$MEMORY_SWAPFILE_PATH"; then
        was_active=1
        toolbox_sudo swapoff "$MEMORY_SWAPFILE_PATH" || {
            toolbox_sudo rm -f -- "$new_file"
            echo "现有 swap 正在使用且无法安全停用，未做替换。"
            return 1
        }
        if memory_swap_is_active "$MEMORY_SWAPFILE_PATH"; then
            toolbox_sudo rm -f -- "$new_file"
            echo "现有 swap 停用后被系统立即重新启用，未做替换。请重启后再试。"
            return 1
        fi
    fi
    if toolbox_sudo test -e "$MEMORY_SWAPFILE_PATH"; then
        memory_clear_immutable_attribute "$MEMORY_SWAPFILE_PATH" || {
            toolbox_sudo rm -f -- "$new_file"
            [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
            return 1
        }
        if ! toolbox_sudo mv -- "$MEMORY_SWAPFILE_PATH" "$backup_file"; then
            memory_move_swapfile_after_forced_immutable_clear \
                "$MEMORY_SWAPFILE_PATH" "$backup_file" || {
                memory_restore_immutable_attribute "$MEMORY_SWAPFILE_PATH" || true
                memory_activate_fallback_swapfile "$new_file" || {
                    toolbox_sudo rm -f -- "$new_file"
                    [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
                    echo "现有 swap 无法安全移动，已保留原文件。"
                    return 1
                }
                echo "独立 swap 已安全启用，继续配置 zram、swappiness 和开机自动启用。"
                return 0
            }
        fi
    fi
    if ! toolbox_sudo mv -- "$new_file" "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo test ! -e "$backup_file" || \
            toolbox_sudo mv -- "$backup_file" "$MEMORY_SWAPFILE_PATH" || true
        memory_restore_immutable_attribute "$MEMORY_SWAPFILE_PATH" || true
        [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
        return 1
    fi
    if ! toolbox_sudo swapon --priority 10 "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo rm -f -- "$MEMORY_SWAPFILE_PATH"
        if toolbox_sudo test -e "$backup_file"; then
            toolbox_sudo mv -- "$backup_file" "$MEMORY_SWAPFILE_PATH" || true
            memory_restore_immutable_attribute "$MEMORY_SWAPFILE_PATH" || true
            [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
        fi
        echo "新 swap 无法启用，已恢复原文件。"
        return 1
    fi
    toolbox_sudo rm -f -- "$backup_file" || true
    return 0
}

memory_optimize() {
    local target_gib unit_name fallback_unit_name tmp_dir zram_file sysctl_file unit_file
    local command_name

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "虚拟内存优化仅支持真实 SteamOS 环境。"
        return 1
    fi
    [ "$(id -u)" -ne 0 ] || {
        echo "请使用 Steam Deck 桌面用户运行Renkit，不要直接以 root 运行。"
        return 1
    }
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" memory; then
        echo "虚拟内存优化已停止：准备检查未通过。"
        return 1
    fi
    memory_validate_paths || return 1
    for command_name in awk blkid df fallocate grep install mkswap readlink stat swapon swapoff \
        systemctl systemd-escape sysctl; do
        require_command "$command_name" || return 1
    done
    target_gib="$(recommended_swap_gib)" || {
        echo "无法读取物理内存大小，已停止。"
        return 1
    }
    memory_confirm_optimize || {
        echo "已取消虚拟内存优化。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，未修改虚拟内存。"
        return 1
    }

    if ! memory_swapfile_is_complete "$MEMORY_SWAPFILE_PATH" "$target_gib" && \
       memory_swapfile_is_complete "$MEMORY_FALLBACK_SWAPFILE_PATH" "$target_gib"; then
        MEMORY_SWAPFILE_PATH="$MEMORY_FALLBACK_SWAPFILE_PATH"
        echo "检测到Renkit独立 swap，继续使用：$MEMORY_SWAPFILE_PATH"
    fi
    unit_name="$(memory_swap_unit_name)" || {
        echo "无法生成磁盘 swap 的开机配置名称，当前 swap 文件保持不变。"
        return 1
    }
    fallback_unit_name="$(memory_swap_unit_name_for_path "$MEMORY_FALLBACK_SWAPFILE_PATH")" || {
        echo "无法生成Renkit独立 swap 的开机配置名称，未修改现有配置。"
        return 1
    }
    memory_config_target_is_safe "$MEMORY_ZRAM_CONFIG" || return 1
    memory_config_target_is_safe "$MEMORY_SYSCTL_CONFIG" || return 1
    memory_config_target_is_safe "$MEMORY_SYSTEMD_DIR/$unit_name" || return 1
    [ "$fallback_unit_name" = "$unit_name" ] || \
        memory_config_target_is_safe "$MEMORY_SYSTEMD_DIR/$fallback_unit_name" || return 1
    if memory_swapfile_is_complete "$MEMORY_SWAPFILE_PATH" "$target_gib"; then
        echo "[已设置] ${target_gib}GB 磁盘 swap 文件完整，无需重复创建。"
    else
        memory_create_swapfile "$target_gib" || return 1
    fi
    # 受保护的系统 swap 无法移动时，创建函数会切换到Renkit独立路径。
    # systemd 单元名必须按最终路径重新计算，不能继续使用原 swap 的名称。
    unit_name="$(memory_swap_unit_name)" || return 1

    tmp_dir="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$tmp_dir"' EXIT INT TERM
    zram_file="$tmp_dir/zram.conf"
    sysctl_file="$tmp_dir/memory.conf"
    unit_file="$tmp_dir/swap.unit"
    cat > "$zram_file" <<'EOF'
# Managed by Zhoukeer Toolbox
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
    cat > "$sysctl_file" <<'EOF'
# Managed by Zhoukeer Toolbox
vm.swappiness = 1
EOF
    cat > "$unit_file" <<EOF
# Managed by Zhoukeer Toolbox
[Unit]
Description=Zhoukeer disk swap fallback

[Swap]
What=$MEMORY_SWAPFILE_PATH
Priority=10

[Install]
WantedBy=swap.target
EOF
    memory_write_config "$MEMORY_ZRAM_CONFIG" "$zram_file" || {
        echo "zram 配置写入失败，当前 swap 文件保持不变。"
        return 1
    }
    memory_write_config "$MEMORY_SYSCTL_CONFIG" "$sysctl_file" || {
        echo "swappiness 配置写入失败，当前 swap 文件保持不变。"
        return 1
    }
    memory_write_config "$MEMORY_SYSTEMD_DIR/$unit_name" "$unit_file" || {
        echo "磁盘 swap 开机配置写入失败，当前 swap 仍保持启用。"
        return 1
    }

    toolbox_sudo sysctl -w vm.swappiness=1 >/dev/null || {
        echo "swappiness 即时设置失败，配置文件已保留供重启后应用。"
        return 1
    }
    toolbox_sudo systemctl daemon-reload || {
        echo "systemd 刷新失败，磁盘 swap 当前仍保持启用。"
        return 1
    }
    if memory_swap_is_active "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo systemctl enable "$unit_name" >/dev/null || {
            echo "磁盘 swap 当前已启用，但开机自动启用设置失败。"
            return 1
        }
    else
        toolbox_sudo systemctl enable --now "$unit_name" >/dev/null || {
            echo "磁盘 swap 开机配置已写入，但本次启用失败。"
            return 1
        }
    fi

    echo "虚拟内存最佳组合已设置：zram 优先，${target_gib}GB 磁盘 swap 兜底。"
    echo "swappiness 已立即设为 1；zram 配置将在下次重启后完全应用。"
    log "虚拟内存最佳组合已设置: zram=ram/2 swap=${target_gib}GB swappiness=1"
    rm -rf -- "$tmp_dir"
    trap - EXIT INT TERM
}

memory_restore_toolbox() {
    local main_unit_name fallback_unit_name command_name

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "虚拟内存撤销仅支持真实 SteamOS 环境。"
        return 1
    fi
    [ "$(id -u)" -ne 0 ] || {
        echo "请使用桌面用户运行Renkit，不要直接以 root 运行。"
        return 1
    }
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" memory-restore; then
        echo "虚拟内存撤销已停止：准备检查未通过。"
        return 1
    fi
    memory_validate_paths || return 1
    for command_name in blkid grep readlink swapon swapoff systemctl systemd-escape; do
        require_command "$command_name" || return 1
    done
    memory_confirm_restore || {
        echo "已取消撤销。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，未修改虚拟内存。"
        return 1
    }

    main_unit_name="$(memory_swap_unit_name_for_path "$MEMORY_SWAPFILE_PATH")" || {
        echo "无法识别系统原 swap 的开机配置名称。"
        return 1
    }
    fallback_unit_name="$(memory_swap_unit_name_for_path \
        "$MEMORY_FALLBACK_SWAPFILE_PATH")" || {
        echo "无法识别Renkit独立 swap 的开机配置名称。"
        return 1
    }
    memory_remove_managed_fallback_swap "$fallback_unit_name" || return 1
    [ "$main_unit_name" = "$fallback_unit_name" ] || \
        memory_remove_managed_main_unit "$main_unit_name" || return 1
    memory_remove_managed_config "$MEMORY_ZRAM_CONFIG" || return 1
    memory_remove_managed_config "$MEMORY_SYSCTL_CONFIG" || return 1
    toolbox_sudo systemctl daemon-reload >/dev/null 2>&1 || {
        echo "虚拟内存配置已清理，但 systemd 刷新失败，请重启后再检查。"
        log "虚拟内存撤销失败: systemd daemon-reload失败"
        return 1
    }

    echo "Renkit虚拟内存优化已撤销；系统原 swap 已保留，请重启。"
    log "Renkit虚拟内存优化已撤销，系统原 swap 已保留"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-status}" in
        status) memory_show_status ;;
        optimize) memory_optimize ;;
        restore) memory_restore_toolbox ;;
        *) echo "用法: $0 {status|optimize|restore}"; exit 1 ;;
    esac
fi
