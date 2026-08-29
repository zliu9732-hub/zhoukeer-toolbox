#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

F1L_PRODUCT_NAME="ONEXPLAYER F1L"
F1L_PRODUCT_FILE="${ZHOUKEER_F1L_PRODUCT_FILE:-/sys/class/dmi/id/product_name}"
F1L_SOURCE_CONFIG="${ZHOUKEER_F1L_SOURCE_CONFIG:-/usr/share/inputplumber/devices/50-onexplayer_onexfly.yaml}"
F1L_CONFIG_DIR="${ZHOUKEER_F1L_CONFIG_DIR:-/etc/inputplumber/devices.d}"
F1L_TARGET_CONFIG="${ZHOUKEER_F1L_TARGET_CONFIG:-$F1L_CONFIG_DIR/50-onexplayer_f1l.yaml}"
F1L_STATE_FILE="${ZHOUKEER_F1L_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox/f1l-button-fix.state}"
F1L_SERVICE="inputplumber.service"

f1l_require_steamos_user() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "飞行家 F1/F1L 按键修复仅支持 SteamOS，已停止执行。"
        return 1
    fi
    if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
        echo "请使用 SteamOS 桌面用户运行Renkit，不要直接以 root 运行。"
        return 1
    fi
}

f1l_require_target_device() {
    local product=""

    f1l_require_steamos_user || return 1
    if [ ! -r "$F1L_PRODUCT_FILE" ]; then
        echo "无法读取设备型号：$F1L_PRODUCT_FILE"
        return 1
    fi
    product="$(tr -d '\r\n' < "$F1L_PRODUCT_FILE" 2>/dev/null)" || return 1
    if [ "$product" != "$F1L_PRODUCT_NAME" ]; then
        echo "当前设备型号为“${product:-未知}”，不是 ${F1L_PRODUCT_NAME}，本按键修复不适用。"
        return 1
    fi
}

f1l_require_dependencies() {
    local command_name load_state

    for command_name in inputplumber systemctl sudo awk cmp grep install mktemp tr wc; do
        require_command "$command_name" || {
            echo "飞行家 F1L 按键修复缺少必要组件，未做任何修改。"
            return 1
        }
    done
    load_state="$(systemctl show "$F1L_SERVICE" -p LoadState --value 2>/dev/null)" || {
        echo "无法检查 ${F1L_SERVICE}，请确认 InputPlumber 的 systemd 服务可用。"
        return 1
    }
    if [ "$load_state" != "loaded" ]; then
        echo "未找到可用的 ${F1L_SERVICE}（LoadState=${load_state:-未知}），未做任何修改。"
        return 1
    fi
    if [ ! -f "$F1L_SOURCE_CONFIG" ] || [ ! -r "$F1L_SOURCE_CONFIG" ]; then
        echo "未找到可读的 InputPlumber 系统配置：$F1L_SOURCE_CONFIG"
        return 1
    fi
    if [ -e "$F1L_CONFIG_DIR" ] || [ -L "$F1L_CONFIG_DIR" ]; then
        if [ ! -d "$F1L_CONFIG_DIR" ] || [ -L "$F1L_CONFIG_DIR" ]; then
            echo "InputPlumber 自定义配置目录不是安全的普通目录：$F1L_CONFIG_DIR"
            return 1
        fi
    fi
}

f1l_build_expected_config() {
    local output="$1"

    awk '
        BEGIN { replaced = 0 }
        {
            if (!replaced && $0 ~ /^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1[[:space:]]*$/) {
                sub(/product_name:[[:space:]]*ONEXPLAYER F1[[:space:]]*$/, "product_name: ONEXPLAYER F1L")
                replaced = 1
            }
            print
        }
        END { if (!replaced) exit 42 }
    ' "$F1L_SOURCE_CONFIG" > "$output" || {
        echo "系统配置中未找到“product_name: ONEXPLAYER F1”，无法安全生成 F1L 配置。"
        return 1
    }
}

f1l_config_has_one_target() {
    local file="$1" count

    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    count="$(awk '$0 ~ /^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1L[[:space:]]*$/ { count++ } END { print count + 0 }' "$file" 2>/dev/null)" || return 1
    [ "$count" = "1" ]
}

f1l_target_matches_expected() {
    local expected="$1"

    [ -f "$F1L_TARGET_CONFIG" ] && [ ! -L "$F1L_TARGET_CONFIG" ] || return 1
    f1l_config_has_one_target "$F1L_TARGET_CONFIG" || return 1
    cmp -s -- "$expected" "$F1L_TARGET_CONFIG"
}

f1l_state_is_valid() {
    local file="${1:-$F1L_STATE_FILE}" lines

    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    lines="$(wc -l < "$file" | tr -d ' ')" || return 1
    [ "$lines" = "2" ] || return 1
    grep -Eq '^was_enabled=[01]$' "$file" || return 1
    grep -Eq '^was_active=[01]$' "$file" || return 1
}

f1l_state_value() {
    local key="$1"

    f1l_state_is_valid "$F1L_STATE_FILE" || return 1
    awk -F= -v wanted="$key" '$1 == wanted { print $2; exit }' "$F1L_STATE_FILE"
}

f1l_write_initial_state() {
    local state_dir tmp_file was_enabled=0 was_active=0

    if [ -e "$F1L_STATE_FILE" ] || [ -L "$F1L_STATE_FILE" ]; then
        if f1l_state_is_valid "$F1L_STATE_FILE"; then
            return 0
        fi
        echo "检测到异常的 F1L 修复状态记录，已停止以免误改服务状态：$F1L_STATE_FILE"
        return 1
    fi

    systemctl is-enabled --quiet "$F1L_SERVICE" >/dev/null 2>&1 && was_enabled=1
    systemctl is-active --quiet "$F1L_SERVICE" >/dev/null 2>&1 && was_active=1
    state_dir="$(dirname "$F1L_STATE_FILE")" || return 1
    if [ -L "$state_dir" ]; then
        echo "F1L 修复状态目录不能是符号链接：$state_dir"
        return 1
    fi
    mkdir -p -- "$state_dir" || {
        echo "无法创建 F1L 修复状态目录：$state_dir"
        return 1
    }
    umask 077
    tmp_file="$(mktemp "$state_dir/.f1l-button-fix.XXXXXX")" || return 1
    if ! printf 'was_enabled=%s\nwas_active=%s\n' "$was_enabled" "$was_active" > "$tmp_file" ||
       ! mv -f -- "$tmp_file" "$F1L_STATE_FILE"; then
        rm -f -- "$tmp_file"
        echo "无法记录 InputPlumber 修改前状态，未继续安装。"
        return 1
    fi
}

f1l_confirm_install() {
    local answer

    echo "将进行以下修改："
    echo "  1. 读取系统配置：$F1L_SOURCE_CONFIG"
    echo "  2. 创建自定义配置：$F1L_TARGET_CONFIG"
    echo "  3. 仅将第一次出现的 ONEXPLAYER F1 型号改为 ONEXPLAYER F1L"
    echo "  4. 启用、启动并重启 ${F1L_SERVICE}"
    echo "不会安装 HHD，不会修改 /usr/share/inputplumber，也不会替换 InputPlumber。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit界面确认，继续执行。"
        return 0
    fi
    printf '确认安装飞行家 F1L 按键修复？输入 YES 继续：'
    IFS= read -r answer || return 1
    [ "$answer" = "YES" ] || {
        echo "已取消，未做任何修改。"
        return 1
    }
}

f1l_confirm_restore() {
    local answer

    echo "恢复原状将删除：$F1L_TARGET_CONFIG"
    echo "并按安装前记录恢复 ${F1L_SERVICE} 的启用与运行状态。"
    echo "不会删除或修改 /usr/share/inputplumber 下的系统文件。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit界面确认，继续执行。"
        return 0
    fi
    printf '确认恢复飞行家 F1L 按键修改？输入 YES 继续：'
    IFS= read -r answer || return 1
    [ "$answer" = "YES" ] || {
        echo "已取消，未做任何修改。"
        return 1
    }
}

f1l_restore_recorded_service_state() {
    local was_enabled was_active

    f1l_state_is_valid "$F1L_STATE_FILE" || return 2
    was_enabled="$(f1l_state_value was_enabled)" || return 1
    was_active="$(f1l_state_value was_active)" || return 1

    if [ "$was_enabled" = "1" ]; then
        toolbox_sudo systemctl enable "$F1L_SERVICE" >/dev/null || {
            echo "InputPlumber 原开机启动状态恢复失败。"
            return 1
        }
    else
        toolbox_sudo systemctl disable "$F1L_SERVICE" >/dev/null || {
            echo "InputPlumber 开机启动状态恢复失败。"
            return 1
        }
    fi
    if [ "$was_active" = "1" ]; then
        toolbox_sudo systemctl restart "$F1L_SERVICE" >/dev/null || {
            echo "InputPlumber 重启失败，配置已删除但服务尚未重新加载。"
            return 1
        }
    else
        toolbox_sudo systemctl stop "$F1L_SERVICE" >/dev/null || {
            echo "InputPlumber 停止失败。"
            return 1
        }
    fi
}

f1l_rollback_install() {
    local remove_config="$1" remove_state="$2"

    echo "正在回滚本次未完成的按键修复..."
    if [ "$remove_config" = "1" ]; then
        toolbox_sudo rm -f -- "$F1L_TARGET_CONFIG" >/dev/null 2>&1 || true
    fi
    f1l_restore_recorded_service_state >/dev/null 2>&1 || true
    if [ "$remove_state" = "1" ]; then
        rm -f -- "$F1L_STATE_FILE"
    fi
}

f1l_install() {
    local tmp_dir expected config_installed_now=0 state_created_now=0

    f1l_require_target_device || return 1
    f1l_require_dependencies || return 1
    tmp_dir="$(mktemp -d)" || {
        echo "无法创建临时目录，未做任何修改。"
        return 1
    }
    expected="$tmp_dir/50-onexplayer_f1l.yaml"
    if ! f1l_build_expected_config "$expected" || ! f1l_config_has_one_target "$expected"; then
        rm -rf -- "$tmp_dir"
        return 1
    fi

    if [ -e "$F1L_TARGET_CONFIG" ] || [ -L "$F1L_TARGET_CONFIG" ]; then
        if ! f1l_target_matches_expected "$expected"; then
            echo "目标位置已有不同内容或不安全文件，已拒绝覆盖：$F1L_TARGET_CONFIG"
            rm -rf -- "$tmp_dir"
            return 1
        fi
    fi
    f1l_confirm_install || {
        rm -rf -- "$tmp_dir"
        return 1
    }

    if [ ! -e "$F1L_STATE_FILE" ] && [ ! -L "$F1L_STATE_FILE" ]; then
        state_created_now=1
    fi
    f1l_write_initial_state || {
        rm -rf -- "$tmp_dir"
        return 1
    }
    if [ ! -e "$F1L_TARGET_CONFIG" ] && [ ! -L "$F1L_TARGET_CONFIG" ]; then
        toolbox_sudo install -d -m 0755 -- "$F1L_CONFIG_DIR" || {
            echo "创建 InputPlumber 自定义配置目录失败。"
            f1l_rollback_install 0 "$state_created_now"
            rm -rf -- "$tmp_dir"
            return 1
        }
        toolbox_sudo install -m 0644 -- "$expected" "$F1L_TARGET_CONFIG" || {
            echo "写入 F1L 自定义按键配置失败。"
            f1l_rollback_install 1 "$state_created_now"
            rm -rf -- "$tmp_dir"
            return 1
        }
        config_installed_now=1
    else
        echo "F1L 自定义配置已是正确内容，不重复写入。"
    fi

    if ! toolbox_sudo systemctl enable --now "$F1L_SERVICE" >/dev/null; then
        echo "InputPlumber 启用或启动失败，安装已停止。"
        f1l_rollback_install "$config_installed_now" "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! toolbox_sudo systemctl restart "$F1L_SERVICE" >/dev/null; then
        echo "InputPlumber 重启失败，安装已停止。"
        f1l_rollback_install "$config_installed_now" "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! systemctl is-active --quiet "$F1L_SERVICE"; then
        echo "InputPlumber 服务未达到 active 状态，安装验证失败。"
        f1l_rollback_install "$config_installed_now" "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! systemctl is-enabled --quiet "$F1L_SERVICE"; then
        echo "InputPlumber 服务未设置为开机启动，安装验证失败。"
        f1l_rollback_install "$config_installed_now" "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi
    if ! f1l_target_matches_expected "$expected"; then
        echo "F1L 自定义配置内容验证失败，安装已停止。"
        f1l_rollback_install "$config_installed_now" "$state_created_now"
        rm -rf -- "$tmp_dir"
        return 1
    fi

    rm -rf -- "$tmp_dir"
    log "飞行家 F1L SteamOS 按键修复已安装并验证"
    echo "飞行家 F1L SteamOS 按键修复已完成，InputPlumber 状态为 active。"
    echo "请重启机器后验证："
    echo "  - 橙色键短按：Steam/Guide（西瓜）键"
    echo "  - Turbo 键：右侧快捷菜单"
    echo "  - 键盘键：呼出虚拟键盘"
    echo "  - 橙色键长按：第二快捷菜单"
}

f1l_status() {
    local tmp_dir expected result=0

    f1l_require_target_device || return 1
    f1l_require_dependencies || return 1
    tmp_dir="$(mktemp -d)" || return 1
    expected="$tmp_dir/50-onexplayer_f1l.yaml"
    f1l_build_expected_config "$expected" || {
        rm -rf -- "$tmp_dir"
        return 1
    }

    if f1l_target_matches_expected "$expected"; then
        echo "F1L 自定义配置：正确，且 product_name: ONEXPLAYER F1L 仅出现一次。"
    else
        echo "F1L 自定义配置：缺失、内容不一致或存在重复型号。"
        result=1
    fi
    if systemctl is-active --quiet "$F1L_SERVICE"; then
        echo "InputPlumber 服务：active。"
    else
        echo "InputPlumber 服务：不是 active。"
        result=1
    fi
    if systemctl is-enabled --quiet "$F1L_SERVICE"; then
        echo "InputPlumber 开机启动：已启用。"
    else
        echo "InputPlumber 开机启动：未启用。"
        result=1
    fi
    if [ -e "$F1L_STATE_FILE" ] || [ -L "$F1L_STATE_FILE" ]; then
        if f1l_state_is_valid "$F1L_STATE_FILE"; then
            echo "恢复记录：有效。"
        else
            echo "恢复记录：异常，请勿直接修改该文件。"
            result=1
        fi
    else
        echo "恢复记录：不存在。"
        result=1
    fi

    rm -rf -- "$tmp_dir"
    log "已检查飞行家 F1L 按键修复状态: result=$result"
    return "$result"
}

f1l_restore() {
    local state_present=0 was_enabled="" was_active=""

    f1l_require_steamos_user || return 1
    require_command systemctl || return 1
    require_command sudo || return 1
    if [ ! -e "$F1L_TARGET_CONFIG" ] && [ ! -L "$F1L_TARGET_CONFIG" ] &&
       [ ! -e "$F1L_STATE_FILE" ] && [ ! -L "$F1L_STATE_FILE" ]; then
        echo "未安装飞行家 F1L 按键修复，无需恢复。"
        return 0
    fi
    if [ -e "$F1L_STATE_FILE" ] || [ -L "$F1L_STATE_FILE" ]; then
        f1l_state_is_valid "$F1L_STATE_FILE" || {
            echo "F1L 修复状态记录异常，已停止以免误改 InputPlumber 服务。"
            return 1
        }
        state_present=1
        was_enabled="$(f1l_state_value was_enabled)" || return 1
        was_active="$(f1l_state_value was_active)" || return 1
    fi
    if [ -e "$F1L_TARGET_CONFIG" ] || [ -L "$F1L_TARGET_CONFIG" ]; then
        if ! f1l_config_has_one_target "$F1L_TARGET_CONFIG"; then
            echo "F1L 自定义配置不是本功能可安全恢复的普通文件，已拒绝删除：$F1L_TARGET_CONFIG"
            return 1
        fi
    fi
    f1l_confirm_restore || return 1

    if ! toolbox_sudo rm -f -- "$F1L_TARGET_CONFIG"; then
        echo "删除 F1L 自定义配置失败，未继续修改服务。"
        return 1
    fi
    if [ "$state_present" = "1" ]; then
        f1l_restore_recorded_service_state || return 1
        if [ "$was_enabled" = "0" ] && systemctl is-enabled --quiet "$F1L_SERVICE"; then
            echo "InputPlumber 仍处于开机启用状态，恢复验证失败。"
            return 1
        fi
        if [ "$was_enabled" = "1" ] && ! systemctl is-enabled --quiet "$F1L_SERVICE"; then
            echo "InputPlumber 原开机启动状态未恢复，恢复验证失败。"
            return 1
        fi
        if [ "$was_active" = "0" ] && systemctl is-active --quiet "$F1L_SERVICE"; then
            echo "InputPlumber 仍在运行，恢复验证失败。"
            return 1
        fi
        if [ "$was_active" = "1" ] && ! systemctl is-active --quiet "$F1L_SERVICE"; then
            echo "InputPlumber 原运行状态未恢复，恢复验证失败。"
            return 1
        fi
        rm -f -- "$F1L_STATE_FILE" || {
            echo "配置和服务已恢复，但删除恢复记录失败：$F1L_STATE_FILE"
            return 1
        }
    else
        echo "未找到由Renkit记录的服务原状态，因此保留 InputPlumber 当前启用/运行状态。"
        if systemctl is-active --quiet "$F1L_SERVICE"; then
            toolbox_sudo systemctl restart "$F1L_SERVICE" >/dev/null || {
                echo "自定义配置已删除，但 InputPlumber 重新加载失败。"
                return 1
            }
        fi
    fi
    if [ -e "$F1L_TARGET_CONFIG" ] || [ -L "$F1L_TARGET_CONFIG" ]; then
        echo "F1L 自定义配置仍然存在，恢复验证失败。"
        return 1
    fi

    log "飞行家 F1L SteamOS 按键修复已恢复原状"
    echo "飞行家 F1L 按键修复已恢复原状；请重启机器完成恢复。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) f1l_install ;;
        status) f1l_status ;;
        restore) f1l_restore ;;
        *) echo "用法: $0 {install|status|restore}"; exit 1 ;;
    esac
fi
