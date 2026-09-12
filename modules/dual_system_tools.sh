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
    local library="$1"
    local filesystem="$2"
    local answer

    echo "目标 Steam 库：${library}（${filesystem}）"
    echo "将安全退出 Steam，备份原 compatdata，并清理该库的下载临时残留。"
    echo "不会删除 steamapps/common，也不会对整个游戏盘执行 chown 或 chmod。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认修复请输入 REPAIR：" answer
    [ "$answer" = "REPAIR" ]
}

append_steam_repair_library() {
    local candidate="$1"
    local output_file="$2"
    local canonical filesystem mountpoint
    local media_root="${ZHOUKEER_MEDIA_ROOT:-/run/media/deck}"

    [ -d "$candidate/steamapps" ] || return 0
    [ ! -L "$candidate/steamapps" ] || return 0
    canonical="$(canonical_directory "$candidate" || true)"
    [ -n "$canonical" ] || return 0
    case "$canonical" in
        /*) ;;
        *) return 0 ;;
    esac
    case "$canonical" in *$'\n'*|*$'\t'*) return 0 ;; esac
    grep -Fqx -- "$canonical" "$output_file" 2>/dev/null && return 0

    filesystem="$(findmnt -rn -T "$canonical" -o FSTYPE 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')"
    mountpoint="$(findmnt -rn -T "$canonical" -o TARGET 2>/dev/null | head -n 1)"
    [ -n "$mountpoint" ] && [ "$mountpoint" != "/" ] || return 0
    case "$filesystem" in
        ntfs|ntfs3|exfat) ;;
        *)
            case "$canonical" in
                "$media_root"/*) ;;
                *) return 0 ;;
            esac
            ;;
    esac
    printf '%s\n' "$canonical" >> "$output_file"
}

discover_steam_repair_libraries() {
    local output_file="$1"
    local media_root="${ZHOUKEER_MEDIA_ROOT:-/run/media/deck}"
    local steam_root vdf candidate
    local -a roots=()

    : > "$output_file" || return 1
    for steam_root in \
        "$HOME/.local/share/Steam" \
        "$HOME/.steam/steam" \
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
        [ -d "$steam_root/steamapps" ] && roots+=("$steam_root")
    done
    for steam_root in "${roots[@]}"; do
        vdf="$steam_root/steamapps/libraryfolders.vdf"
        [ -r "$vdf" ] && [ ! -L "$vdf" ] || continue
        while IFS= read -r candidate; do
            candidate="${candidate//\\\\/\\}"
            case "$candidate" in
                /*) append_steam_repair_library "$candidate" "$output_file" ;;
            esac
        done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
    done
    if [ -d "$media_root" ]; then
        for candidate in "$media_root"/*; do
            [ -e "$candidate" ] || continue
            append_steam_repair_library "$candidate" "$output_file"
        done
    fi
}

choose_steam_repair_library() {
    local libraries_file="$1"
    local requested="${ZHOUKEER_STEAM_LIBRARY:-}"
    local count index selected answer candidate
    local -a menu_args=()

    if [ -n "$requested" ]; then
        append_steam_repair_library "$requested" "$libraries_file"
        count="$(wc -l < "$libraries_file" | tr -d '[:space:]')"
        [ "$count" = "1" ] || {
            echo "指定的 Steam 库无效、未挂载或不是互通游戏盘：$requested" >&2
            return 1
        }
        sed -n '1p' "$libraries_file"
        return 0
    fi

    discover_steam_repair_libraries "$libraries_file" || return 1
    count="$(wc -l < "$libraries_file" | tr -d '[:space:]')"
    case "$count" in
        ''|*[!0-9]*) count=0 ;;
    esac
    [ "$count" -gt 0 ] || {
        echo "未找到已挂载的外置/NTFS Steam 库。请先在 Steam 中添加游戏盘后重试。" >&2
        return 1
    }
    if [ "$count" -eq 1 ]; then
        sed -n '1p' "$libraries_file"
        return 0
    fi

    if command -v kdialog >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        index=0
        while IFS= read -r candidate; do
            index=$((index + 1))
            menu_args+=("$index" "$candidate")
        done < "$libraries_file"
        selected="$(kdialog --title "修复 Steam 磁盘写入错误" \
            --menu "检测到多个游戏盘，请选择需要修复的 Steam 库。" \
            "${menu_args[@]}" 2>/dev/null || true)"
        case "$selected" in ''|*[!0-9]*) return 1 ;; esac
        [ "$selected" -ge 1 ] && [ "$selected" -le "$count" ] || return 1
        sed -n "${selected}p" "$libraries_file"
        return 0
    fi

    echo "检测到多个游戏盘，请选择需要修复的 Steam 库：" >&2
    index=0
    while IFS= read -r candidate; do
        index=$((index + 1))
        printf '  %s. %s\n' "$index" "$candidate" >&2
    done < "$libraries_file"
    [ -r /dev/tty ] || {
        echo "当前界面无法读取选择，已停止修复。" >&2
        return 1
    }
    read -r -p "请输入编号 [1-$count]：" answer </dev/tty
    case "$answer" in ''|*[!0-9]*) return 1 ;; esac
    [ "$answer" -ge 1 ] && [ "$answer" -le "$count" ] || return 1
    sed -n "${answer}p" "$libraries_file"
}

steam_repair_mount_info() {
    local library="$1"
    local field="$2"

    findmnt -rn -T "$library" -o "$field" 2>/dev/null | head -n 1
}

steam_repair_windows_instructions() {
    local library="$1"

    echo "目标游戏盘当前只读或无法写入，Renkit 未修改任何库文件：$library"
    echo "请进入 Windows 后按以下步骤处理："
    echo "  1. 使用管理员 CMD 执行：powercfg -h off"
    echo "  2. 对对应 Game 分区执行：chkdsk X: /f（将 X: 替换为实际盘符）"
    echo "  3. Windows 完全关机后，再进入 SteamOS 重试。"
}

steam_library_write_test() {
    local library="$1"
    local test_file="$library/.renkit-write-test-$$"

    case "$test_file" in
        "$library"/.renkit-write-test-[0-9]*) ;;
        *) return 1 ;;
    esac
    touch -- "$test_file" 2>/dev/null || return 1
    rm -f -- "$test_file" 2>/dev/null || {
        echo "写入测试文件已创建，但无法删除：$test_file" >&2
        return 1
    }
}

steam_repair_is_running() {
    command -v pgrep >/dev/null 2>&1 && pgrep -u "$(id -u)" -x steam >/dev/null 2>&1
}

stop_steam_for_disk_repair() {
    local steam_bin attempt

    [ "${ZHOUKEER_SKIP_STEAM_RESTART:-0}" = "1" ] && return 0
    steam_repair_is_running || return 0
    if command -v steam >/dev/null 2>&1; then
        steam_bin="$(command -v steam)"
    elif [ -x "$HOME/.steam/steam/steam.sh" ]; then
        steam_bin="$HOME/.steam/steam/steam.sh"
    else
        echo "Steam 正在运行，但找不到安全退出命令。请完全退出 Steam 后重试。" >&2
        return 1
    fi
    echo "正在安全退出 Steam…"
    "$steam_bin" -shutdown >/dev/null 2>&1 || true
    for attempt in $(seq 1 20); do
        steam_repair_is_running || return 0
        sleep 1
    done
    echo "Steam 未能在 20 秒内退出。请确认游戏和 Steam 已完全关闭后重试。" >&2
    return 1
}

steam_compatdata_stable_id() {
    local library="$1"
    local source uuid safe_uuid digest

    source="$(steam_repair_mount_info "$library" SOURCE)"
    uuid="$(steam_repair_mount_info "$library" UUID)"
    if [ -z "$uuid" ] && [ -n "$source" ] && command -v lsblk >/dev/null 2>&1; then
        uuid="$(lsblk -dnro UUID "$source" 2>/dev/null | head -n 1)"
    fi
    require_command sha256sum || return 1
    digest="$(printf '%s' "$library" | sha256sum | awk '{print substr($1,1,20)}')"
    case "$digest" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
        *) echo "无法为 Steam 库生成安全的 compatdata 标识。" >&2; return 1 ;;
    esac
    safe_uuid="$(printf '%s' "$uuid" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9._-')"
    if [ -n "$safe_uuid" ]; then
        printf 'uuid-%s-path-%s\n' "$safe_uuid" "$digest"
    else
        printf 'path-%s\n' "$digest"
    fi
}

prepare_linux_compatdata_target() {
    local library="$1"
    local base="${ZHOUKEER_COMPATDATA_ROOT:-$HOME/.local/share/Steam/renkit-compatdata}"
    local home_filesystem ancestor_filesystem target_filesystem stable_id target ancestor

    case "$base" in
        "$HOME"/*) ;;
        *) echo "Linux compatdata 目录不在当前用户主目录内：$base" >&2; return 1 ;;
    esac
    case "/${base#/}/" in
        */../*|*/./*|*$'\n'*|*$'\t'*)
            echo "Linux compatdata 目录包含不安全的路径片段：$base" >&2
            return 1
            ;;
    esac
    home_filesystem="$(steam_repair_mount_info "$HOME" FSTYPE | tr '[:upper:]' '[:lower:]')"
    [ -n "$home_filesystem" ] || {
        echo "无法确认用户主目录所在文件系统。" >&2
        return 1
    }
    is_shared_filesystem "$home_filesystem" && {
        echo "用户主目录位于 ${home_filesystem}，无法建立 Linux compatdata。" >&2
        return 1
    }
    stable_id="$(steam_compatdata_stable_id "$library")" || return 1
    target="$base/$stable_id"
    case "$target" in "$base"/uuid-*|"$base"/path-*) ;; *) return 1 ;; esac
    ancestor="$base"
    while [ ! -e "$ancestor" ] && [ "$ancestor" != "$HOME" ]; do
        ancestor="$(dirname "$ancestor")"
    done
    [ -d "$ancestor" ] || {
        echo "无法确认 Linux compatdata 的上级目录：$ancestor" >&2
        return 1
    }
    ancestor_filesystem="$(steam_repair_mount_info "$ancestor" FSTYPE | tr '[:upper:]' '[:lower:]')"
    [ -n "$ancestor_filesystem" ] && ! is_shared_filesystem "$ancestor_filesystem" || {
        echo "compatdata 上级目录不在 Linux 文件系统：$ancestor" >&2
        return 1
    }
    [ ! -L "$base" ] || {
        echo "Linux compatdata 根目录不能是符号链接：$base" >&2
        return 1
    }
    mkdir -p -- "$target" || return 1
    [ -d "$target" ] && [ ! -L "$target" ] || {
        echo "Linux compatdata 目标目录异常：$target" >&2
        return 1
    }
    target_filesystem="$(steam_repair_mount_info "$target" FSTYPE | tr '[:upper:]' '[:lower:]')"
    [ -n "$target_filesystem" ] && ! is_shared_filesystem "$target_filesystem" || {
        echo "compatdata 目标不在 Linux 文件系统：$target" >&2
        return 1
    }
    printf '%s\n' "$target"
}

next_compatdata_backup_path() {
    local compatdata="$1"
    local timestamp candidate suffix=0

    timestamp="$(date +%Y%m%d-%H%M%S)"
    candidate="${compatdata}.backup-${timestamp}"
    while [ -e "$candidate" ] || [ -L "$candidate" ]; do
        suffix=$((suffix + 1))
        candidate="${compatdata}.backup-${timestamp}-${suffix}"
    done
    printf '%s\n' "$candidate"
}

link_library_compatdata() {
    local library="$1"
    local target="$2"
    local steamapps="$library/steamapps"
    local compatdata="$steamapps/compatdata"
    local current backup=""

    [ -d "$steamapps" ] && [ ! -L "$steamapps" ] || {
        echo "Steam 库目录异常：$steamapps" >&2
        return 1
    }
    if [ -L "$compatdata" ]; then
        current="$(readlink -f "$compatdata" 2>/dev/null || true)"
        if [ "$current" = "$(canonical_directory "$target" || true)" ]; then
            return 0
        fi
        backup="$(next_compatdata_backup_path "$compatdata")"
        mv -- "$compatdata" "$backup" || return 1
        echo "已备份原 compatdata 链接：$backup"
    elif [ -e "$compatdata" ]; then
        backup="$(next_compatdata_backup_path "$compatdata")"
        mv -- "$compatdata" "$backup" || return 1
        echo "已备份原 compatdata：$backup"
    fi
    if ! ln -s -- "$target" "$compatdata"; then
        [ -z "$backup" ] || mv -- "$backup" "$compatdata" 2>/dev/null || true
        echo "创建 compatdata 符号链接失败，原路径已尽量恢复。" >&2
        return 1
    fi
}

steam_cache_path_has_mounts() {
    local cache_dir="$1"
    local mounted

    while IFS= read -r mounted; do
        case "$mounted" in
            "$cache_dir"|"$cache_dir"/*) return 0 ;;
        esac
    done < <(findmnt -rn -o TARGET 2>/dev/null)
    return 1
}

clear_steam_repair_cache() {
    local library="$1"
    local name cache_dir steamapps="$library/steamapps"
    local lock_file

    [ -d "$steamapps" ] && [ ! -L "$steamapps" ] || return 1
    for name in downloading temp; do
        cache_dir="$steamapps/$name"
        case "$cache_dir" in
            "$library"/steamapps/downloading|"$library"/steamapps/temp) ;;
            *) echo "缓存路径安全检查失败：$cache_dir" >&2; return 1 ;;
        esac
        if [ -d "$cache_dir" ] && steam_cache_path_has_mounts "$cache_dir"; then
            echo "缓存目录内包含独立挂载点，已拒绝清理：$cache_dir" >&2
            return 1
        fi
        if [ -L "$cache_dir" ]; then
            rm -f -- "$cache_dir" || return 1
        elif [ -e "$cache_dir" ]; then
            [ -d "$cache_dir" ] || {
                echo "缓存路径不是目录：$cache_dir" >&2
                return 1
            }
            rm -rf -- "$cache_dir" || return 1
        fi
        mkdir -p -- "$cache_dir" || return 1
    done
    while IFS= read -r -d '' lock_file; do
        case "$lock_file" in "$steamapps"/*) rm -f -- "$lock_file" || return 1 ;; *) return 1 ;; esac
    done < <(find "$steamapps" -maxdepth 1 -type f \( -name '.lock' -o -name '*.lock' \) -print0 2>/dev/null)
}

verify_steam_disk_repair() {
    local library="$1"
    local target="$2"
    local compatdata="$library/steamapps/compatdata"
    local actual expected

    steam_library_write_test "$library" || {
        echo "修复后的实际写入测试失败。" >&2
        return 1
    }
    [ -L "$compatdata" ] || {
        echo "compatdata 不是符号链接：$compatdata" >&2
        return 1
    }
    actual="$(readlink -f "$compatdata" 2>/dev/null || true)"
    expected="$(canonical_directory "$target" || true)"
    [ -n "$actual" ] && [ "$actual" = "$expected" ] || {
        echo "compatdata 链接目标验证失败：${actual:-无效}" >&2
        return 1
    }
}

repair_shared_drive() {
    local libraries_file library filesystem mountpoint options compat_target

    require_steamos || return 1
    for command_name in findmnt touch rm mv ln readlink find sed awk tr wc date mkdir mktemp grep head seq; do
        require_command "$command_name" || return 1
    done
    libraries_file="$(mktemp "${TMPDIR:-/tmp}/renkit-steam-libraries.XXXXXX")" || {
        echo "[失败步骤：识别 Steam 库] 无法创建临时候选清单。" >&2
        return 1
    }
    library="$(choose_steam_repair_library "$libraries_file")" || {
        rm -f -- "$libraries_file"
        echo "[失败步骤：识别 Steam 库] 未选择可修复的游戏盘。" >&2
        return 1
    }
    rm -f -- "$libraries_file"
    [ -d "$library/steamapps" ] && [ ! -L "$library/steamapps" ] || {
        echo "[失败步骤：检查路径] Steam 库路径异常：$library" >&2
        return 1
    }
    mountpoint="$(steam_repair_mount_info "$library" TARGET)"
    filesystem="$(steam_repair_mount_info "$library" FSTYPE | tr '[:upper:]' '[:lower:]')"
    options="$(steam_repair_mount_info "$library" OPTIONS)"
    [ -n "$mountpoint" ] && [ -n "$filesystem" ] || {
        echo "[失败步骤：检查挂载] 目标游戏盘不存在或尚未挂载：$library" >&2
        return 1
    }
    case ",$options," in
        *,ro,*) steam_repair_windows_instructions "$library"; return 1 ;;
    esac
    if ! steam_library_write_test "$library"; then
        steam_repair_windows_instructions "$library"
        return 1
    fi
    repair_drive_confirm "$library" "$filesystem" || {
        echo "已取消修复，Steam 库未修改。"
        return 0
    }
    stop_steam_for_disk_repair || {
        echo "[失败步骤：关闭 Steam] 未修改 compatdata 或下载缓存。" >&2
        return 1
    }
    compat_target="$(prepare_linux_compatdata_target "$library")" || {
        echo "[失败步骤：建立独立 compatdata] 未修改原 compatdata。" >&2
        return 1
    }
    link_library_compatdata "$library" "$compat_target" || {
        echo "[失败步骤：链接 compatdata] 修复已停止。" >&2
        return 1
    }
    clear_steam_repair_cache "$library" || {
        echo "[失败步骤：清理下载残留] 请检查该 Steam 库权限。" >&2
        return 1
    }
    verify_steam_disk_repair "$library" "$compat_target" || {
        echo "[失败步骤：完成后验证] 未显示修复成功。" >&2
        return 1
    }

    echo "Steam 磁盘写入错误修复完成：$library"
    echo "独立 compatdata：$compat_target"
    echo "未删除 steamapps/common 或任何已安装游戏。"
    case "$filesystem" in
        ntfs|ntfs3)
            echo "Windows 请保持快速启动和休眠关闭：管理员 CMD 执行 powercfg -h off"
            ;;
    esac
    echo "若 Steam 中出现两个同名库，请保留能够正常下载的库条目，并移除旧的失效库条目；不要删除游戏文件。"
    log "Steam磁盘写入错误修复完成: library=$library filesystem=$filesystem compatdata=$compat_target"
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

desktop_exec_quote() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

create_windows_switch_shortcut() {
    local module_path launcher_exec icon_value desktop_dir

    require_steamos || return 1
    module_path="$PROJECT_ROOT/modules/dual_system_tools.sh"
    [ -f "$module_path" ] || {
        echo "找不到 Windows 切换组件：$module_path"
        return 1
    }
    case "$WINDOWS_SWITCH_DIR" in
        "$HOME"/*) ;;
        *) echo "Windows 切换脚本目录不安全：$WINDOWS_SWITCH_DIR"; return 1 ;;
    esac
    case "$WINDOWS_SWITCH_DESKTOP" in
        "$HOME"/*) ;;
        *) echo "Windows 桌面快捷方式路径不安全：$WINDOWS_SWITCH_DESKTOP"; return 1 ;;
    esac

    desktop_dir="$(dirname "$WINDOWS_SWITCH_DESKTOP")"
    mkdir -p -- "$WINDOWS_SWITCH_DIR" "$desktop_dir" || return 1
    chmod 0700 "$WINDOWS_SWITCH_DIR" || return 1

    umask 077
    {
        printf '%s\n' '#!/bin/bash'
        printf '%s\n' 'set -euo pipefail'
        printf 'exec bash %q switch-to-windows\n' "$module_path"
    } > "$WINDOWS_SWITCH_LAUNCHER" || return 1
    chmod 0700 "$WINDOWS_SWITCH_LAUNCHER" || return 1

    launcher_exec="$(desktop_exec_quote "$WINDOWS_SWITCH_LAUNCHER")"
    if [ -s "$WINDOWS_SWITCH_ICON" ]; then
        icon_value="$WINDOWS_SWITCH_ICON"
    else
        icon_value="system-reboot"
    fi
    {
        printf '%s\n' '[Desktop Entry]'
        printf '%s\n' 'Type=Application'
        printf '%s\n' 'Name=切换至 Windows'
        printf '%s\n' 'Comment=双击后立即重启进入 Windows'
        printf 'Exec=%s\n' "$launcher_exec"
        printf 'Icon=%s\n' "$icon_value"
        printf '%s\n' 'Terminal=true'
        printf '%s\n' 'StartupNotify=false'
        printf '%s\n' 'Categories=System;'
    } > "$WINDOWS_SWITCH_DESKTOP" || return 1
    chmod 0755 "$WINDOWS_SWITCH_DESKTOP" || return 1
    umask 022
    if command -v gio >/dev/null 2>&1; then
        gio set "$WINDOWS_SWITCH_DESKTOP" metadata::trusted true >/dev/null 2>&1 || true
    fi

    echo "已创建桌面快捷方式：$WINDOWS_SWITCH_DESKTOP"
    echo "本次操作没有设置 BootNext，也没有重启。"
    echo "以后双击该图标，立即切换并重启进入 Windows。"
    log "已创建Windows切换桌面快捷方式"
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

    toolbox_sudo efibootmgr -v 2>/dev/null | awk -v number="$boot_number" '
        toupper(substr($1, 1, 8)) == "BOOT" toupper(number) { print; exit }
    '
}

windows_loader_path_in_esp() {
    local esp="$1"
    local candidate

    for candidate in \
        "$esp/EFI/Microsoft/Boot/bootmgfw.efi" \
        "$esp/efi/Microsoft/Boot/bootmgfw.efi" \
        "$esp/EFI/Microsoft/boot/bootmgfw.efi" \
        "$esp/efi/Microsoft/boot/bootmgfw.efi"; do
        [ -f "$candidate" ] || \
            toolbox_sudo test -f "$candidate" >/dev/null 2>&1 || continue
        printf '%s\n' '\EFI\Microsoft\Boot\bootmgfw.efi'
        return 0
    done
    return 1
}

boot_entry_has_windows_loader() {
    local entries="$1"

    printf '%s\n' "$entries" | awk '
        /^Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/ {
            lower = tolower($0)
            if (index(lower, "windows boot manager") ||
                index(lower, "microsoft\\boot\\bootmgfw.efi")) {
                found = 1
                exit
            }
        }
        END { exit(found ? 0 : 1) }
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
    toolbox_sudo efibootmgr 2>/dev/null | sed -n 's/^BootOrder:[[:space:]]*//p' | head -n 1
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
        boot_number="$(toolbox_sudo efibootmgr -v 2>/dev/null | awk -v label="$label" '
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
    local entry label loader boot_number clover_boot current_order new_order windows_loader
    local backup_file timestamp output
    local -a repair_entries=()

    require_steamos || return 1
    for command_name in efibootmgr lsblk findmnt find sed awk tr grep; do
        require_command "$command_name" || return 1
    done
    entries="$(toolbox_sudo efibootmgr -v 2>/dev/null)" || {
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

    toolbox_sudo true || {
        echo "管理员权限验证失败，引导项未修改。"
        return 1
    }
    windows_loader="$(windows_loader_path_in_esp "$esp" || true)"
    if [ -n "$windows_loader" ] && ! boot_entry_has_windows_loader "$entries"; then
        repair_entries+=("Windows Boot Manager|$windows_loader")
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

    entries="$(toolbox_sudo efibootmgr -v 2>/dev/null)" || {
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
    entries="$(toolbox_sudo efibootmgr -v 2>/dev/null)" || {
        echo "无法读取 UEFI NVRAM 启动项，无法一键切换。"
        return 1
    }
    line="$(printf '%s\n' "$entries" | awk '
        /^Boot[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/ {
            lower = tolower($0)
            if (index(lower, "windows boot manager") ||
                index(lower, "microsoft\\boot\\bootmgfw.efi")) {
                print
                exit
            }
        }
    ')"
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
    echo "Windows 启动项：${line##* } (Boot${boot_number})"
    echo "将设置 BootNext=${boot_number}，随后立即重启进入 Windows。"
    echo "请先保存所有工作；重启后不会自动返回 SteamOS 菜单。"
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
        windows-shortcut) create_windows_switch_shortcut ;;
        health) dual_boot_health_check ;;
        cleanup-boot) cleanup_third_party_boot_entry ;;
        *)
            echo "用法: $0 {tf-format-mount|repair-drive|repair-boot|windows-shortcut|switch-to-windows|health|cleanup-boot}"
            exit 1
            ;;
    esac
fi
