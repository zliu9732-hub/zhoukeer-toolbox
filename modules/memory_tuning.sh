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
MEMORY_ZRAM_CONFIG="${ZHOUKEER_ZRAM_CONFIG:-/etc/systemd/zram-generator.conf.d/90-zhoukeer.conf}"
MEMORY_SYSCTL_CONFIG="${ZHOUKEER_MEMORY_SYSCTL_CONFIG:-/etc/sysctl.d/90-zhoukeer-memory.conf}"
MEMORY_SYSTEMD_DIR="${ZHOUKEER_SYSTEMD_DIR:-/etc/systemd/system}"
MEMORY_MIN_FREE_GIB="${ZHOUKEER_MEMORY_MIN_FREE_GIB:-4}"

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
    swapon --noheadings --raw --output NAME 2>/dev/null | grep -Fxq -- "$1"
}

memory_swapfile_is_complete() {
    local path="$1"
    local target_gib="$2"
    local expected_bytes actual_bytes

    [ -f "$path" ] && [ ! -L "$path" ] || return 1
    expected_bytes=$((target_gib * 1024 * 1024 * 1024))
    actual_bytes="$(memory_file_size_bytes "$path")" || return 1
    [ "$actual_bytes" -eq "$expected_bytes" ] || return 1
    [ "$(blkid -p -s TYPE -o value "$path" 2>/dev/null || true)" = "swap" ]
}

memory_validate_paths() {
    local path

    for path in "$MEMORY_SWAPFILE_PATH" "$MEMORY_ZRAM_CONFIG" \
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
}

memory_swap_unit_name() {
    systemd-escape --path --suffix=swap "$MEMORY_SWAPFILE_PATH"
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

    echo "将一次性优化两种虚拟内存："
    echo "1. zram：物理内存的一半，zstd 压缩，优先级 100"
    echo "2. 磁盘 swap：按内存自动取 8-16GB，优先级 10"
    echo "3. swappiness：设为 1，减少不必要的磁盘写入"
    echo "会在原 swap 正常停用后原子替换；空间不足或停用失败会停止。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认优化请输入 OPTIMIZE MEMORY：" answer
    [ "$answer" = "OPTIMIZE MEMORY" ]
}

memory_write_config() {
    local target="$1"
    local source="$2"

    if toolbox_sudo test -e "$target" && \
       ! toolbox_sudo grep -Fq '# Managed by Zhoukeer Toolbox' "$target"; then
        echo "发现非工具箱管理的配置，未覆盖：$target"
        return 1
    fi
    toolbox_sudo install -d -m 0755 -- "$(dirname "$target")" || return 1
    toolbox_sudo install -m 0644 -- "$source" "$target"
}

memory_config_target_is_safe() {
    local target="$1"

    if toolbox_sudo test -e "$target" && \
       ! toolbox_sudo grep -Fq '# Managed by Zhoukeer Toolbox' "$target"; then
        echo "发现非工具箱管理的配置，未覆盖：$target"
        return 1
    fi
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
    fi
    if toolbox_sudo test -e "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo mv -- "$MEMORY_SWAPFILE_PATH" "$backup_file" || {
            toolbox_sudo rm -f -- "$new_file"
            [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
            return 1
        }
    fi
    if ! toolbox_sudo mv -- "$new_file" "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo test ! -e "$backup_file" || \
            toolbox_sudo mv -- "$backup_file" "$MEMORY_SWAPFILE_PATH" || true
        [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
        return 1
    fi
    if ! toolbox_sudo swapon --priority 10 "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo rm -f -- "$MEMORY_SWAPFILE_PATH"
        if toolbox_sudo test -e "$backup_file"; then
            toolbox_sudo mv -- "$backup_file" "$MEMORY_SWAPFILE_PATH" || true
            [ "$was_active" -eq 0 ] || toolbox_sudo swapon "$MEMORY_SWAPFILE_PATH" || true
        fi
        echo "新 swap 无法启用，已恢复原文件。"
        return 1
    fi
    toolbox_sudo rm -f -- "$backup_file" || true
}

memory_optimize() {
    local target_gib unit_name tmp_dir zram_file sysctl_file unit_file
    local command_name

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "虚拟内存优化仅支持真实 SteamOS 环境。"
        return 1
    fi
    [ "$(id -u)" -ne 0 ] || {
        echo "请使用 Steam Deck 桌面用户运行工具箱，不要直接以 root 运行。"
        return 1
    }
    memory_validate_paths || return 1
    for command_name in awk blkid df fallocate grep install mkswap stat swapon swapoff \
        systemctl systemd-escape sysctl; do
        require_command "$command_name" || return 1
    done
    target_gib="$(recommended_swap_gib)" || {
        echo "无法读取物理内存大小，已停止。"
        return 1
    }
    unit_name="$(memory_swap_unit_name)" || return 1
    memory_confirm_optimize || {
        echo "已取消虚拟内存优化。"
        return 0
    }
    toolbox_sudo true || {
        echo "管理员权限验证失败，未修改虚拟内存。"
        return 1
    }
    memory_config_target_is_safe "$MEMORY_ZRAM_CONFIG" || return 1
    memory_config_target_is_safe "$MEMORY_SYSCTL_CONFIG" || return 1
    memory_config_target_is_safe "$MEMORY_SYSTEMD_DIR/$unit_name" || return 1

    if memory_swapfile_is_complete "$MEMORY_SWAPFILE_PATH" "$target_gib"; then
        echo "[已设置] ${target_gib}GB 磁盘 swap 文件完整，无需重复创建。"
    else
        memory_create_swapfile "$target_gib" || return 1
    fi

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
    memory_write_config "$MEMORY_ZRAM_CONFIG" "$zram_file" || return 1
    memory_write_config "$MEMORY_SYSCTL_CONFIG" "$sysctl_file" || return 1
    memory_write_config "$MEMORY_SYSTEMD_DIR/$unit_name" "$unit_file" || return 1

    toolbox_sudo sysctl -w vm.swappiness=1 >/dev/null || return 1
    toolbox_sudo systemctl daemon-reload || return 1
    if memory_swap_is_active "$MEMORY_SWAPFILE_PATH"; then
        toolbox_sudo systemctl enable "$unit_name" >/dev/null || return 1
    else
        toolbox_sudo systemctl enable --now "$unit_name" >/dev/null || return 1
    fi

    echo "虚拟内存最佳组合已设置：zram 优先，${target_gib}GB 磁盘 swap 兜底。"
    echo "swappiness 已立即设为 1；zram 配置将在下次重启后完全应用。"
    log "虚拟内存最佳组合已设置: zram=ram/2 swap=${target_gib}GB swappiness=1"
    rm -rf -- "$tmp_dir"
    trap - EXIT INT TERM
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-status}" in
        status) memory_show_status ;;
        optimize) memory_optimize ;;
        *) echo "用法: $0 {status|optimize}"; exit 1 ;;
    esac
fi
