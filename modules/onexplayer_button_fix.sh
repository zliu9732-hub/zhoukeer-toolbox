#!/bin/bash

set -u

# 实机验证基线：
# - ONEXPLAYER F1L：SteamOS 3.10、InputPlumber 0.77.4，特殊按键修复成功。
# - ONEXPLAYER X1Pro：InputPlumber 0.77.7，特殊按键修复成功。
# 两台设备修复后均可由 SteamOS 识别 Steam/Guide、快捷菜单和虚拟键盘相关按键。

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

OXP_PRODUCT_FILE="${ZHOUKEER_OXP_PRODUCT_FILE:-${ZHOUKEER_F1L_PRODUCT_FILE:-/sys/class/dmi/id/product_name}}"
OXP_CONFIG_DIR="${ZHOUKEER_OXP_CONFIG_DIR:-${ZHOUKEER_F1L_CONFIG_DIR:-/etc/inputplumber/devices.d}}"
OXP_STATE_ROOT="${ZHOUKEER_OXP_STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox}"
OXP_SERVICE="inputplumber.service"

OXP_PRODUCT_NAME=""
OXP_DEVICE_KEY=""
OXP_DEVICE_LABEL=""
OXP_SOURCE_CONFIG=""
OXP_TARGET_CONFIG=""
OXP_SOURCE_DMI=""
OXP_STATE_FILE=""
OXP_BACKUP_FILE=""

OXP_STATE_TARGET_EXISTED=""
OXP_STATE_WAS_ENABLED=""
OXP_STATE_WAS_ACTIVE=""
OXP_STATE_SOURCE_SHA=""
OXP_STATE_MANAGED_SHA=""
OXP_STATE_ORIGINAL_SHA=""

oxp_require_steamos_user() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "壹号掌机 SteamOS 特殊按键修复仅支持 SteamOS，已停止执行。"
        return 1
    fi
    if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
        echo "请使用 SteamOS 桌面用户运行Renkit，不要直接以 root 运行。"
        return 1
    fi
}

oxp_select_device() {
    local product=""

    oxp_require_steamos_user || return 1
    if [ ! -r "$OXP_PRODUCT_FILE" ]; then
        echo "无法读取设备型号：$OXP_PRODUCT_FILE"
        return 1
    fi
    product="$(tr -d '\r\n' < "$OXP_PRODUCT_FILE" 2>/dev/null)" || {
        echo "读取设备型号失败：$OXP_PRODUCT_FILE"
        return 1
    }

    case "$product" in
        "ONEXPLAYER F1L")
            OXP_PRODUCT_NAME="$product"
            OXP_DEVICE_KEY="f1l"
            OXP_DEVICE_LABEL="飞行家 F1L 8840U"
            OXP_SOURCE_CONFIG="${ZHOUKEER_OXP_F1L_SOURCE_CONFIG:-${ZHOUKEER_F1L_SOURCE_CONFIG:-/usr/share/inputplumber/devices/50-onexplayer_onexfly.yaml}}"
            OXP_TARGET_CONFIG="${ZHOUKEER_OXP_F1L_TARGET_CONFIG:-${ZHOUKEER_F1L_TARGET_CONFIG:-$OXP_CONFIG_DIR/50-onexplayer_f1l.yaml}}"
            OXP_SOURCE_DMI="ONEXPLAYER F1"
            OXP_STATE_FILE="${ZHOUKEER_OXP_F1L_STATE_FILE:-${ZHOUKEER_F1L_STATE_FILE:-$OXP_STATE_ROOT/f1l-button-fix.state}}"
            ;;
        "ONEXPLAYER X1Pro")
            OXP_PRODUCT_NAME="$product"
            OXP_DEVICE_KEY="x1pro"
            OXP_DEVICE_LABEL="游侠 X1 Pro AMD"
            OXP_SOURCE_CONFIG="${ZHOUKEER_OXP_X1PRO_SOURCE_CONFIG:-/usr/share/inputplumber/devices/50-onexplayer_x1.yaml}"
            OXP_TARGET_CONFIG="${ZHOUKEER_OXP_X1PRO_TARGET_CONFIG:-$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml}"
            OXP_SOURCE_DMI="ONEXPLAYER X1 A"
            OXP_STATE_FILE="${ZHOUKEER_OXP_X1PRO_STATE_FILE:-$OXP_STATE_ROOT/x1pro-button-fix.state}"
            ;;
        *)
            echo "检测到 DMI：${product:-未知}"
            echo "当前机型尚未实机验证，已停止操作"
            return 1
            ;;
    esac
    OXP_BACKUP_FILE="${OXP_TARGET_CONFIG}.renkit-backup"
    echo "检测到机型：${OXP_DEVICE_LABEL}（DMI：${OXP_PRODUCT_NAME}）"
}

oxp_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$1" | awk '{print $1}'
    else
        return 1
    fi
}

oxp_require_hash_command() {
    if command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; then
        return 0
    fi
    echo "缺少 SHA256 校验命令，未做任何修改。"
    return 1
}

oxp_hhd_is_active() {
    local username=""

    pgrep -x hhd >/dev/null 2>&1 && return 0
    systemctl is-active --quiet hhd.service >/dev/null 2>&1 && return 0
    systemctl --user is-active --quiet hhd.service >/dev/null 2>&1 && return 0
    username="$(id -un 2>/dev/null || true)"
    if [ -n "$username" ] && systemctl is-active --quiet "hhd@${username}.service" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

oxp_require_no_hhd_conflict() {
    if oxp_hhd_is_active; then
        echo "检测到 HHD 正在运行。HHD 与 InputPlumber 不能同时用于本按键修复，已停止操作。"
        echo "Renkit 不会自动停止或卸载 HHD；请先自行停用 HHD 后再试。"
        return 1
    fi
}

oxp_require_install_dependencies() {
    local command_name load_state

    for command_name in inputplumber systemctl sudo awk cmp grep install mktemp tr wc cp pgrep; do
        require_command "$command_name" || {
            echo "壹号掌机特殊按键修复缺少必要组件，未做任何修改。"
            return 1
        }
    done
    oxp_require_hash_command || return 1
    load_state="$(systemctl show "$OXP_SERVICE" -p LoadState --value 2>/dev/null)" || {
        echo "无法检查 ${OXP_SERVICE}，请确认 InputPlumber 的 systemd 服务可用。"
        return 1
    }
    if [ "$load_state" != "loaded" ]; then
        echo "未找到可用的 ${OXP_SERVICE}（LoadState=${load_state:-未知}），未做任何修改。"
        return 1
    fi
    if [ ! -f "$OXP_SOURCE_CONFIG" ] || [ ! -r "$OXP_SOURCE_CONFIG" ]; then
        echo "未找到可读的 InputPlumber 系统配置：$OXP_SOURCE_CONFIG"
        return 1
    fi
    if [ -e "$OXP_CONFIG_DIR" ] || [ -L "$OXP_CONFIG_DIR" ]; then
        if [ ! -d "$OXP_CONFIG_DIR" ] || [ -L "$OXP_CONFIG_DIR" ]; then
            echo "InputPlumber 自定义配置目录不是安全的普通目录：$OXP_CONFIG_DIR"
            return 1
        fi
    fi
    oxp_require_no_hhd_conflict
}

oxp_require_restore_dependencies() {
    local command_name load_state

    for command_name in systemctl sudo awk grep tr wc cp pgrep; do
        require_command "$command_name" || return 1
    done
    oxp_require_hash_command || return 1
    load_state="$(systemctl show "$OXP_SERVICE" -p LoadState --value 2>/dev/null)" || {
        echo "无法检查 ${OXP_SERVICE}，请确认 InputPlumber 的 systemd 服务可用。"
        return 1
    }
    if [ "$load_state" != "loaded" ]; then
        echo "未找到可用的 ${OXP_SERVICE}（LoadState=${load_state:-未知}）。"
        return 1
    fi
}

oxp_build_expected_config() {
    local output="$1"

    awk -v source_dmi="$OXP_SOURCE_DMI" -v target_dmi="$OXP_PRODUCT_NAME" '
        BEGIN { replaced = 0 }
        {
            if (!replaced && $0 ~ "^[[:space:]]*product_name:[[:space:]]*" source_dmi "[[:space:]]*$") {
                sub("product_name:[[:space:]]*" source_dmi "[[:space:]]*$", "product_name: " target_dmi)
                replaced = 1
            }
            print
        }
        END { if (!replaced) exit 42 }
    ' "$OXP_SOURCE_CONFIG" > "$output" || {
        echo "系统配置中未找到“product_name: ${OXP_SOURCE_DMI}”，无法安全生成 ${OXP_PRODUCT_NAME} 配置。"
        return 1
    }
}

oxp_config_has_one_target_dmi() {
    local file="$1" count

    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    count="$(awk -v target_dmi="$OXP_PRODUCT_NAME" '
        $0 ~ "^[[:space:]]*product_name:[[:space:]]*" target_dmi "[[:space:]]*$" { count++ }
        END { print count + 0 }
    ' "$file" 2>/dev/null)" || return 1
    [ "$count" = "1" ]
}

oxp_state_is_valid() {
    local file="${1:-$OXP_STATE_FILE}" lines

    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    lines="$(wc -l < "$file" | tr -d ' ')" || return 1
    [ "$lines" = "8" ] || return 1
    grep -Fxq 'version=2' "$file" || return 1
    grep -Fxq "product_name=$OXP_PRODUCT_NAME" "$file" || return 1
    grep -Eq '^target_existed=[01]$' "$file" || return 1
    grep -Eq '^was_enabled=[01]$' "$file" || return 1
    grep -Eq '^was_active=[01]$' "$file" || return 1
    grep -Eq '^source_sha256=[0-9a-f]{64}$' "$file" || return 1
    grep -Eq '^managed_sha256=[0-9a-f]{64}$' "$file" || return 1
    grep -Eq '^original_sha256=(none|[0-9a-f]{64})$' "$file" || return 1
}

oxp_legacy_f1l_state_is_valid() {
    local lines

    [ "$OXP_DEVICE_KEY" = "f1l" ] || return 1
    [ -f "$OXP_STATE_FILE" ] && [ ! -L "$OXP_STATE_FILE" ] || return 1
    lines="$(wc -l < "$OXP_STATE_FILE" | tr -d ' ')" || return 1
    [ "$lines" = "2" ] || return 1
    grep -Eq '^was_enabled=[01]$' "$OXP_STATE_FILE" || return 1
    grep -Eq '^was_active=[01]$' "$OXP_STATE_FILE" || return 1
}

oxp_state_value() {
    local key="$1" file="${2:-$OXP_STATE_FILE}"

    awk -F= -v wanted="$key" '$1 == wanted { print substr($0, index($0, "=") + 1); exit }' "$file"
}

oxp_load_state_values() {
    oxp_state_is_valid "$OXP_STATE_FILE" || return 1
    OXP_STATE_TARGET_EXISTED="$(oxp_state_value target_existed)" || return 1
    OXP_STATE_WAS_ENABLED="$(oxp_state_value was_enabled)" || return 1
    OXP_STATE_WAS_ACTIVE="$(oxp_state_value was_active)" || return 1
    OXP_STATE_SOURCE_SHA="$(oxp_state_value source_sha256)" || return 1
    OXP_STATE_MANAGED_SHA="$(oxp_state_value managed_sha256)" || return 1
    OXP_STATE_ORIGINAL_SHA="$(oxp_state_value original_sha256)" || return 1
}

oxp_load_legacy_state_values() {
    oxp_legacy_f1l_state_is_valid || return 1
    OXP_STATE_TARGET_EXISTED=0
    OXP_STATE_WAS_ENABLED="$(oxp_state_value was_enabled)" || return 1
    OXP_STATE_WAS_ACTIVE="$(oxp_state_value was_active)" || return 1
    OXP_STATE_SOURCE_SHA=""
    OXP_STATE_MANAGED_SHA=""
    OXP_STATE_ORIGINAL_SHA=none
}

oxp_write_state() {
    local target_existed="$1" was_enabled="$2" was_active="$3"
    local source_sha="$4" managed_sha="$5" original_sha="$6" replace_existing="${7:-0}"
    local state_dir tmp_file

    state_dir="$(dirname "$OXP_STATE_FILE")" || return 1
    if [ -L "$state_dir" ]; then
        echo "修复状态目录不能是符号链接：$state_dir"
        return 1
    fi
    mkdir -p -- "$state_dir" || {
        echo "无法创建修复状态目录：$state_dir"
        return 1
    }
    if [ "$replace_existing" != "1" ] && { [ -e "$OXP_STATE_FILE" ] || [ -L "$OXP_STATE_FILE" ]; }; then
        echo "修复状态记录已存在，已拒绝覆盖：$OXP_STATE_FILE"
        return 1
    fi
    umask 077
    tmp_file="$(mktemp "$state_dir/.onexplayer-button-fix.XXXXXX")" || return 1
    if ! printf 'version=2\nproduct_name=%s\ntarget_existed=%s\nwas_enabled=%s\nwas_active=%s\nsource_sha256=%s\nmanaged_sha256=%s\noriginal_sha256=%s\n' \
        "$OXP_PRODUCT_NAME" "$target_existed" "$was_enabled" "$was_active" \
        "$source_sha" "$managed_sha" "$original_sha" > "$tmp_file" ||
       ! mv -f -- "$tmp_file" "$OXP_STATE_FILE"; then
        rm -f -- "$tmp_file"
        echo "无法记录 InputPlumber 修改前状态，未继续安装。"
        return 1
    fi
}

oxp_backup_original_target() {
    local original_sha="$1" backup_sha

    if [ -e "$OXP_BACKUP_FILE" ] || [ -L "$OXP_BACKUP_FILE" ]; then
        echo "检测到未处理的 Renkit 备份，已停止以免覆盖：$OXP_BACKUP_FILE"
        return 1
    fi
    toolbox_sudo cp -p -- "$OXP_TARGET_CONFIG" "$OXP_BACKUP_FILE" || {
        echo "备份原有自定义配置失败：$OXP_TARGET_CONFIG"
        return 1
    }
    if [ ! -f "$OXP_BACKUP_FILE" ] || [ -L "$OXP_BACKUP_FILE" ]; then
        echo "原有配置备份不是安全的普通文件，已停止。"
        return 1
    fi
    backup_sha="$(oxp_sha256 "$OXP_BACKUP_FILE")" || return 1
    if [ "$backup_sha" != "$original_sha" ]; then
        echo "原有配置备份校验失败，已停止。"
        return 1
    fi
}

oxp_validate_saved_backup() {
    local backup_sha

    if [ "$OXP_STATE_TARGET_EXISTED" = "1" ]; then
        [ -f "$OXP_BACKUP_FILE" ] && [ ! -L "$OXP_BACKUP_FILE" ] || return 1
        backup_sha="$(oxp_sha256 "$OXP_BACKUP_FILE")" || return 1
        [ "$backup_sha" = "$OXP_STATE_ORIGINAL_SHA" ]
    else
        [ ! -e "$OXP_BACKUP_FILE" ] && [ ! -L "$OXP_BACKUP_FILE" ]
    fi
}

oxp_target_matches_managed_state() {
    local target_sha

    [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] || return 1
    oxp_config_has_one_target_dmi "$OXP_TARGET_CONFIG" || return 1
    target_sha="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || return 1
    [ "$target_sha" = "$OXP_STATE_MANAGED_SHA" ]
}

oxp_print_install_plan() {
    echo "即将执行“壹号掌机 SteamOS 特殊按键修复”："
    echo "  - 检测机型：${OXP_DEVICE_LABEL}（${OXP_PRODUCT_NAME}）"
    echo "  - 读取系统配置：$OXP_SOURCE_CONFIG"
    echo "  - 写入自定义配置：$OXP_TARGET_CONFIG"
    echo "  - 只把第一处 ${OXP_SOURCE_DMI} 替换为 ${OXP_PRODUCT_NAME}"
    echo "  - 启用、启动并重启 ${OXP_SERVICE}，随后验证配置与服务"
    echo "  - 如果目标文件原本存在，将先校验并备份，恢复时原样还原"
    echo "不会安装 HHD，不会关闭 SteamOS 只读保护，不会修改系统源配置、EFI 或 Windows 引导。"
}

oxp_confirm_install() {
    local answer

    oxp_print_install_plan
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit测试/界面确认，继续执行。"
        return 0
    fi
    printf '确认执行该机型按键修复？输入 YES 继续：'
    IFS= read -r answer || return 1
    [ "$answer" = "YES" ] || {
        echo "已取消，未做任何修改。"
        return 1
    }
}

oxp_print_restore_plan() {
    echo "即将恢复“${OXP_DEVICE_LABEL}”按键修复："
    if [ "$OXP_STATE_TARGET_EXISTED" = "1" ]; then
        echo "  - 用 Renkit 备份还原原有文件：$OXP_TARGET_CONFIG"
    else
        echo "  - 删除 Renkit 创建的文件：$OXP_TARGET_CONFIG"
    fi
    echo "  - 恢复 InputPlumber 修复前的启用与运行状态"
    echo "  - 原服务此前运行时会重启；此前未运行时会保持停止"
}

oxp_confirm_restore() {
    local answer

    oxp_print_restore_plan
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit测试/界面确认，继续执行。"
        return 0
    fi
    printf '确认恢复原状？输入 YES 继续：'
    IFS= read -r answer || return 1
    [ "$answer" = "YES" ] || {
        echo "已取消，未做任何修改。"
        return 1
    }
}

oxp_restore_service_from_state() {
    if [ "$OXP_STATE_WAS_ENABLED" = "1" ]; then
        toolbox_sudo systemctl enable "$OXP_SERVICE" >/dev/null || {
            echo "InputPlumber 原开机启动状态恢复失败。"
            return 1
        }
    else
        toolbox_sudo systemctl disable "$OXP_SERVICE" >/dev/null || {
            echo "InputPlumber 开机启动状态恢复失败。"
            return 1
        }
    fi

    if [ "$OXP_STATE_WAS_ACTIVE" = "1" ]; then
        if oxp_hhd_is_active; then
            toolbox_sudo systemctl stop "$OXP_SERVICE" >/dev/null 2>&1 || true
            echo "HHD 正在运行，无法安全恢复 InputPlumber 原运行状态；已保持 InputPlumber 停止。"
            return 1
        fi
        toolbox_sudo systemctl restart "$OXP_SERVICE" >/dev/null || {
            echo "InputPlumber 原运行状态恢复失败。"
            return 1
        }
    else
        toolbox_sudo systemctl stop "$OXP_SERVICE" >/dev/null || {
            echo "InputPlumber 停止失败。"
            return 1
        }
    fi
}

oxp_verify_restored_service_state() {
    if [ "$OXP_STATE_WAS_ENABLED" = "0" ] && systemctl is-enabled --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 仍处于开机启用状态，恢复验证失败。"
        return 1
    fi
    if [ "$OXP_STATE_WAS_ENABLED" = "1" ] && ! systemctl is-enabled --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 原开机启动状态未恢复，恢复验证失败。"
        return 1
    fi
    if [ "$OXP_STATE_WAS_ACTIVE" = "0" ] && systemctl is-active --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 仍在运行，恢复验证失败。"
        return 1
    fi
    if [ "$OXP_STATE_WAS_ACTIVE" = "1" ] && ! systemctl is-active --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 原运行状态未恢复，恢复验证失败。"
        return 1
    fi
}

oxp_restore_original_config() {
    local mode="${1:-normal}" current_sha=""

    if [ "$OXP_STATE_TARGET_EXISTED" = "1" ]; then
        oxp_validate_saved_backup || {
            echo "原有配置备份缺失或校验失败，已停止恢复。"
            return 1
        }
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] || {
                echo "目标配置不是安全的普通文件，已停止恢复：$OXP_TARGET_CONFIG"
                return 1
            }
            current_sha="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || return 1
            if [ "$mode" != "rollback" ] && [ "$current_sha" != "$OXP_STATE_MANAGED_SHA" ] && \
               [ "$current_sha" != "$OXP_STATE_ORIGINAL_SHA" ]; then
                echo "目标配置已被其他程序修改，Renkit 不会覆盖：$OXP_TARGET_CONFIG"
                return 1
            fi
        fi
        toolbox_sudo cp -p -- "$OXP_BACKUP_FILE" "$OXP_TARGET_CONFIG" || {
            echo "还原原有自定义配置失败：$OXP_TARGET_CONFIG"
            return 1
        }
        current_sha="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || return 1
        [ "$current_sha" = "$OXP_STATE_ORIGINAL_SHA" ] || {
            echo "原有自定义配置还原校验失败。"
            return 1
        }
    else
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] || {
                echo "目标配置不是安全的普通文件，已拒绝删除：$OXP_TARGET_CONFIG"
                return 1
            }
            current_sha="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || return 1
            if [ "$mode" != "rollback" ] && [ "$current_sha" != "$OXP_STATE_MANAGED_SHA" ]; then
                echo "目标配置不是 Renkit 创建的内容，已拒绝删除：$OXP_TARGET_CONFIG"
                return 1
            fi
            toolbox_sudo rm -f -- "$OXP_TARGET_CONFIG" || {
                echo "删除 Renkit 自定义配置失败：$OXP_TARGET_CONFIG"
                return 1
            }
        fi
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            echo "Renkit 自定义配置仍然存在，恢复验证失败。"
            return 1
        fi
    fi
}

oxp_cleanup_restore_records() {
    if [ -e "$OXP_BACKUP_FILE" ] || [ -L "$OXP_BACKUP_FILE" ]; then
        toolbox_sudo rm -f -- "$OXP_BACKUP_FILE" || {
            echo "配置已恢复，但删除 Renkit 备份失败：$OXP_BACKUP_FILE"
            return 1
        }
    fi
    rm -f -- "$OXP_STATE_FILE" || {
        echo "配置和服务已恢复，但删除恢复记录失败：$OXP_STATE_FILE"
        return 1
    }
}

oxp_rollback_install() {
    local state_created_now="$1" rollback_ok=1

    echo "正在回滚本次未完成的特殊按键修复..."
    if [ "$state_created_now" = "1" ]; then
        oxp_restore_original_config rollback || rollback_ok=0
    fi
    oxp_restore_service_from_state || rollback_ok=0
    if [ "$state_created_now" = "1" ] && [ "$rollback_ok" = "1" ]; then
        oxp_cleanup_restore_records || rollback_ok=0
    fi
    if [ "$rollback_ok" != "1" ]; then
        echo "自动回滚未完全完成，已保留状态记录和备份，请勿手动删除。"
    fi
}

oxp_offer_reboot() {
    local choice="${ZHOUKEER_REBOOT_CHOICE:-}"

    echo "必须重启机器后，SteamOS 才能完整重新识别特殊按键。"
    if [ -z "$choice" ]; then
        printf '请选择：输入 1 立即重启，输入 2 稍后重启：'
        IFS= read -r choice || choice=2
    fi
    case "$choice" in
        1|reboot|now)
            echo "即将立即重启 SteamOS，请先确认工作已保存。"
            toolbox_sudo systemctl reboot || {
                echo "立即重启失败，请稍后从系统菜单手动重启。"
                return 1
            }
            ;;
        *)
            echo "已选择稍后重启；请在使用特殊按键前手动重启机器。"
            ;;
    esac
}

oxp_plan_install() {
    oxp_select_device || return 1
    oxp_print_install_plan
}

oxp_plan_restore() {
    oxp_select_device || return 1
    if oxp_state_is_valid "$OXP_STATE_FILE"; then
        oxp_load_state_values || return 1
    elif oxp_legacy_f1l_state_is_valid; then
        oxp_load_legacy_state_values || return 1
    elif [ ! -e "$OXP_STATE_FILE" ] && [ ! -L "$OXP_STATE_FILE" ] && \
         [ ! -e "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ]; then
        echo "未安装该机型的 Renkit 特殊按键修复，无需恢复。"
        return 1
    else
        echo "特殊按键修复状态记录不存在或异常，无法安全预览恢复操作。"
        return 1
    fi
    oxp_print_restore_plan
}

oxp_install() {
    local tmp_dir expected source_before source_after managed_sha original_sha=none
    local target_existed=0 was_enabled=0 was_active=0 state_created_now=0
    local state_kind=none current_target_sha=""

    oxp_select_device || return 1
    oxp_require_install_dependencies || return 1
    tmp_dir="$(mktemp -d)" || {
        echo "无法创建临时目录，未做任何修改。"
        return 1
    }
    expected="$tmp_dir/expected.yaml"
    source_before="$(oxp_sha256 "$OXP_SOURCE_CONFIG")" || {
        echo "无法校验系统源配置：$OXP_SOURCE_CONFIG"
        rm -rf -- "$tmp_dir"
        return 1
    }
    if ! oxp_build_expected_config "$expected" || ! oxp_config_has_one_target_dmi "$expected"; then
        rm -rf -- "$tmp_dir"
        return 1
    fi
    managed_sha="$(oxp_sha256 "$expected")" || { rm -rf -- "$tmp_dir"; return 1; }

    if [ -e "$OXP_STATE_FILE" ] || [ -L "$OXP_STATE_FILE" ]; then
        if oxp_state_is_valid "$OXP_STATE_FILE"; then
            oxp_load_state_values || { rm -rf -- "$tmp_dir"; return 1; }
            state_kind=managed
            if ! oxp_target_matches_managed_state || ! oxp_validate_saved_backup; then
                echo "Renkit 管理的配置、备份或状态记录不一致，已停止以免覆盖现有内容。"
                rm -rf -- "$tmp_dir"
                return 1
            fi
            if [ "$source_before" != "$OXP_STATE_SOURCE_SHA" ] || [ "$managed_sha" != "$OXP_STATE_MANAGED_SHA" ]; then
                echo "InputPlumber 系统源配置已变化，Renkit 不会自动覆盖现有修复；请先恢复原状后重新执行。"
                rm -rf -- "$tmp_dir"
                return 1
            fi
        elif oxp_legacy_f1l_state_is_valid; then
            oxp_load_legacy_state_values || { rm -rf -- "$tmp_dir"; return 1; }
            state_kind=legacy
            [ ! -e "$OXP_BACKUP_FILE" ] && [ ! -L "$OXP_BACKUP_FILE" ] || {
                echo "旧版状态旁存在异常备份，已停止。"
                rm -rf -- "$tmp_dir"
                return 1
            }
            [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] || {
                echo "旧版 F1L 修复文件缺失或不安全，已停止。"
                rm -rf -- "$tmp_dir"
                return 1
            }
            current_target_sha="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || { rm -rf -- "$tmp_dir"; return 1; }
            [ "$current_target_sha" = "$managed_sha" ] || {
                echo "旧版 F1L 修复文件已变化，已停止以免覆盖。"
                rm -rf -- "$tmp_dir"
                return 1
            }
        else
            echo "检测到异常的特殊按键修复状态记录，已停止：$OXP_STATE_FILE"
            rm -rf -- "$tmp_dir"
            return 1
        fi
    else
        if [ -e "$OXP_BACKUP_FILE" ] || [ -L "$OXP_BACKUP_FILE" ]; then
            echo "检测到没有状态记录的 Renkit 备份，已停止：$OXP_BACKUP_FILE"
            rm -rf -- "$tmp_dir"
            return 1
        fi
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] || {
                echo "目标位置不是安全的普通文件，已停止：$OXP_TARGET_CONFIG"
                rm -rf -- "$tmp_dir"
                return 1
            }
            target_existed=1
            original_sha="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || { rm -rf -- "$tmp_dir"; return 1; }
        fi
    fi

    oxp_confirm_install || { rm -rf -- "$tmp_dir"; return 1; }

    if [ "$state_kind" = "none" ]; then
        systemctl is-enabled --quiet "$OXP_SERVICE" >/dev/null 2>&1 && was_enabled=1
        systemctl is-active --quiet "$OXP_SERVICE" >/dev/null 2>&1 && was_active=1
        toolbox_sudo install -d -m 0755 -- "$OXP_CONFIG_DIR" || {
            echo "创建 InputPlumber 自定义配置目录失败。"
            rm -rf -- "$tmp_dir"
            return 1
        }
        if [ "$target_existed" = "1" ]; then
            oxp_backup_original_target "$original_sha" || { rm -rf -- "$tmp_dir"; return 1; }
        fi
        if ! oxp_write_state "$target_existed" "$was_enabled" "$was_active" \
            "$source_before" "$managed_sha" "$original_sha"; then
            if [ "$target_existed" = "1" ]; then
                toolbox_sudo rm -f -- "$OXP_BACKUP_FILE" >/dev/null 2>&1 || true
            fi
            rm -rf -- "$tmp_dir"
            return 1
        fi
        oxp_load_state_values || { rm -rf -- "$tmp_dir"; return 1; }
        state_created_now=1
    elif [ "$state_kind" = "legacy" ]; then
        if ! oxp_write_state 0 "$OXP_STATE_WAS_ENABLED" "$OXP_STATE_WAS_ACTIVE" \
            "$source_before" "$managed_sha" none 1; then
            rm -rf -- "$tmp_dir"
            return 1
        fi
        oxp_load_state_values || { rm -rf -- "$tmp_dir"; return 1; }
        state_created_now=1
        echo "已把 Renkit 2.1.7 的 F1L 恢复记录升级为可校验格式。"
    fi

    if oxp_target_matches_managed_state; then
        echo "${OXP_DEVICE_LABEL} 自定义配置已是 Renkit 管理的正确内容，不重复写入。"
    else
        toolbox_sudo install -m 0644 -- "$expected" "$OXP_TARGET_CONFIG" || {
            echo "写入 ${OXP_DEVICE_LABEL} 自定义按键配置失败。"
            oxp_rollback_install "$state_created_now"
            rm -rf -- "$tmp_dir"
            return 1
        }
    fi

    if ! toolbox_sudo systemctl enable --now "$OXP_SERVICE" >/dev/null; then
        echo "InputPlumber 启用或启动失败，安装已停止。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! toolbox_sudo systemctl restart "$OXP_SERVICE" >/dev/null; then
        echo "InputPlumber 重启失败，安装已停止。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! systemctl is-active --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 服务未达到 active 状态，安装验证失败。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! systemctl is-enabled --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 服务未设置为开机启动，安装验证失败。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! oxp_target_matches_managed_state; then
        echo "自定义配置文件、目标 DMI 或内容校验失败，安装已停止。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    source_after="$(oxp_sha256 "$OXP_SOURCE_CONFIG")" || source_after=""
    if [ "$source_after" != "$source_before" ]; then
        echo "InputPlumber 系统源配置在执行期间发生变化，安装验证失败。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if oxp_hhd_is_active; then
        echo "安装期间检测到 HHD 开始运行，为避免冲突，安装已停止。"
        oxp_rollback_install "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi

    rm -rf -- "$tmp_dir"
    log "壹号掌机特殊按键修复已安装并验证: model=$OXP_PRODUCT_NAME"
    echo "${OXP_DEVICE_LABEL} 特殊按键修复已完成，InputPlumber 状态为 active。"
    echo "修复后 Steam/Guide 菜单、快捷菜单和虚拟键盘相关特殊按键可被 SteamOS 识别。"
    if [ "$OXP_DEVICE_KEY" = "f1l" ]; then
        echo "预期映射：橙色键短按为 Steam/Guide，Turbo 键为右侧快捷菜单，键盘键呼出虚拟键盘，橙色键长按为第二快捷菜单。"
    fi
    oxp_offer_reboot
}

oxp_status() {
    local result=0 current_source_sha

    oxp_select_device || return 1
    oxp_require_restore_dependencies || return 1

    if oxp_state_is_valid "$OXP_STATE_FILE"; then
        oxp_load_state_values || return 1
        echo "Renkit 恢复记录：有效。"
        if oxp_target_matches_managed_state; then
            echo "自定义配置：正确，且 product_name: ${OXP_PRODUCT_NAME} 仅出现一次。"
        else
            echo "自定义配置：缺失、已变化或目标 DMI 不唯一。"
            result=1
        fi
        if ! oxp_validate_saved_backup; then
            echo "原文件备份状态：异常。"
            result=1
        elif [ "$OXP_STATE_TARGET_EXISTED" = "1" ]; then
            echo "原文件备份状态：有效，恢复时会原样还原。"
        else
            echo "原文件备份状态：修复前没有目标文件。"
        fi
        if [ -f "$OXP_SOURCE_CONFIG" ] && [ -r "$OXP_SOURCE_CONFIG" ]; then
            current_source_sha="$(oxp_sha256 "$OXP_SOURCE_CONFIG")" || current_source_sha=""
            if [ "$current_source_sha" = "$OXP_STATE_SOURCE_SHA" ]; then
                echo "系统源配置：未被修改。"
            else
                echo "系统源配置：与修复时校验值不同。"
                result=1
            fi
        else
            echo "系统源配置：当前不可读取。"
            result=1
        fi
    elif oxp_legacy_f1l_state_is_valid; then
        oxp_load_legacy_state_values || return 1
        if [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] && \
           oxp_config_has_one_target_dmi "$OXP_TARGET_CONFIG"; then
            echo "Renkit 恢复记录：检测到 2.1.7 旧格式；再次安装可自动升级。"
        else
            echo "Renkit 恢复记录：旧格式，但修复文件缺失或异常。"
            result=1
        fi
    else
        echo "Renkit 恢复记录：不存在或异常。"
        result=1
    fi

    if systemctl is-active --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 服务：active。"
    else
        echo "InputPlumber 服务：不是 active。"
        result=1
    fi
    if systemctl is-enabled --quiet "$OXP_SERVICE"; then
        echo "InputPlumber 开机启动：已启用。"
    else
        echo "InputPlumber 开机启动：未启用。"
        result=1
    fi
    if oxp_hhd_is_active; then
        echo "HHD 冲突状态：正在运行，不能与本修复同时使用。"
        result=1
    else
        echo "HHD 冲突状态：未运行。"
    fi

    log "已检查壹号掌机特殊按键修复状态: model=$OXP_PRODUCT_NAME result=$result"
    return "$result"
}

oxp_restore() {
    local legacy=0

    oxp_select_device || return 1
    oxp_require_restore_dependencies || return 1

    if [ ! -e "$OXP_STATE_FILE" ] && [ ! -L "$OXP_STATE_FILE" ]; then
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            echo "目标文件没有 Renkit 所有权记录，恢复功能不会删除：$OXP_TARGET_CONFIG"
            return 1
        fi
        echo "未安装该机型的 Renkit 特殊按键修复，无需恢复。"
        return 0
    fi

    if oxp_state_is_valid "$OXP_STATE_FILE"; then
        oxp_load_state_values || return 1
        oxp_validate_saved_backup || {
            echo "恢复记录对应的原文件备份缺失或异常，已停止。"
            return 1
        }
    elif oxp_legacy_f1l_state_is_valid; then
        oxp_load_legacy_state_values || return 1
        legacy=1
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            [ -f "$OXP_TARGET_CONFIG" ] && [ ! -L "$OXP_TARGET_CONFIG" ] && \
                oxp_config_has_one_target_dmi "$OXP_TARGET_CONFIG" || {
                echo "旧版 F1L 修复文件不是可安全删除的 Renkit 配置，已停止。"
                return 1
            }
            OXP_STATE_MANAGED_SHA="$(oxp_sha256 "$OXP_TARGET_CONFIG")" || return 1
        else
            OXP_STATE_MANAGED_SHA="0000000000000000000000000000000000000000000000000000000000000000"
        fi
    else
        echo "特殊按键修复状态记录异常，已停止以免误删文件：$OXP_STATE_FILE"
        return 1
    fi

    if [ "$OXP_STATE_WAS_ACTIVE" = "1" ] && oxp_hhd_is_active; then
        echo "HHD 正在运行，无法把 InputPlumber 恢复为原运行状态；已停止，未修改任何文件。"
        return 1
    fi
    oxp_confirm_restore || return 1

    if [ "$legacy" = "1" ]; then
        if [ -e "$OXP_TARGET_CONFIG" ] || [ -L "$OXP_TARGET_CONFIG" ]; then
            toolbox_sudo rm -f -- "$OXP_TARGET_CONFIG" || {
                echo "删除旧版 Renkit F1L 配置失败。"
                return 1
            }
        fi
    else
        oxp_restore_original_config normal || return 1
    fi
    oxp_restore_service_from_state || return 1
    oxp_verify_restored_service_state || return 1
    oxp_cleanup_restore_records || return 1

    log "壹号掌机特殊按键修复已恢复原状: model=$OXP_PRODUCT_NAME"
    echo "${OXP_DEVICE_LABEL} 特殊按键修复已恢复原状。"
    oxp_offer_reboot
}

oxp_reboot() {
    oxp_require_steamos_user || return 1
    require_command systemctl || return 1
    require_command sudo || return 1
    echo "将立即重启 SteamOS，请先保存所有工作。"
    toolbox_sudo systemctl reboot || {
        echo "无法立即重启，请稍后从系统菜单手动重启。"
        return 1
    }
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) oxp_install ;;
        status) oxp_status ;;
        restore) oxp_restore ;;
        reboot) oxp_reboot ;;
        plan-install) oxp_plan_install ;;
        plan-restore) oxp_plan_restore ;;
        *) echo "用法: $0 {install|status|restore|reboot|plan-install|plan-restore}"; exit 1 ;;
    esac
fi
