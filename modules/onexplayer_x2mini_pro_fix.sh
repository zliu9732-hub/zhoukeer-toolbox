#!/bin/bash

# ONEXPLAYER X2 Mini Pro（DMI：ONEXPLAYER X2Mini PRO）的三点菜单修复。
# 这不是 InputPlumber 升级：此机型需要额外的 DMI 设备描述、按键能力映射，
# 并让 steamos-manager 将虚拟设备目标切换为 deck-uhid。

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/download_policy.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/utils/github_download.sh"

OXPX2_REPOSITORY="dahui/onexplayer-x2-mini-pro-cachyos"
OXPX2_COMMIT="a0b76a16471174ded80913a681357f43bfb17fa4"
OXPX2_PRODUCT_FILE="${ZHOUKEER_OXPX2_PRODUCT_FILE:-/sys/class/dmi/id/product_name}"
OXPX2_VENDOR_FILE="${ZHOUKEER_OXPX2_VENDOR_FILE:-/sys/class/dmi/id/sys_vendor}"
OXPX2_ROOT="${ZHOUKEER_OXPX2_ROOT:-/}"
OXPX2_STATE_FILE="${ZHOUKEER_OXPX2_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox/onexplayer-x2mini-pro-button-fix.state}"
OXPX2_SERVICE="inputplumber.service"
OXPX2_READONLY_CHANGED=0
OXPX2_MUTATED=0
OXPX2_INSTALL_OK=0

oxpx2_root_path() {
    printf '%s/%s\n' "${OXPX2_ROOT%/}" "${1#/}"
}

OXPX2_DEVICE_TARGET="$(oxpx2_root_path etc/inputplumber/devices.d/50-onexplayer_x2_mini.yaml)"
OXPX2_MAP_TARGET="$(oxpx2_root_path etc/inputplumber/capability_maps.d/onexplayer_x2mini.yaml)"
OXPX2_MANAGER_TARGET="$(oxpx2_root_path usr/share/steamos-manager/devices/onexplayer-x2-mini.toml)"
OXPX2_TARGETS=("$OXPX2_DEVICE_TARGET" "$OXPX2_MAP_TARGET" "$OXPX2_MANAGER_TARGET")
OXPX2_NAMES=("设备描述" "按键映射" "SteamOS 设备目标")
OXPX2_MIRROR_IDS=("oxpx2-device" "oxpx2-map" "oxpx2-manager")
OXPX2_PATHS=(
    "etc/inputplumber/devices.d/50-onexplayer_x2_mini.yaml"
    "etc/inputplumber/capability_maps.d/onexplayer_x2mini.yaml"
    "usr/share/steamos-manager/devices/onexplayer-x2-mini.toml"
)
OXPX2_SHA256=(
    "833fdf2079011652a9cd6991eadff4655589dac1f6293ff53ab43fc35d0ff704"
    "333d2dddd354fcb2ec2207745340c5d098dc8d173e76d8de02bf0648049f5079"
    "67f1136c12c103855a34c498fc3438693da7a9043d045e7147323377ed4e831a"
)

oxpx2_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$1" | awk '{print $1}'
    else
        return 1
    fi
}

oxpx2_require_environment() {
    local command_name product vendor

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "X2 Mini Pro 三点菜单修复仅支持 SteamOS，已停止执行。"
        return 1
    fi
    if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
        echo "请使用 SteamOS 桌面用户运行 Renkit，不要直接以 root 运行。"
        return 1
    fi
    [ -r "$OXPX2_PRODUCT_FILE" ] && [ -r "$OXPX2_VENDOR_FILE" ] || {
        echo "无法读取掌机 DMI 型号或厂商，已停止执行。"
        return 1
    }
    product="$(tr -d '\r\n' < "$OXPX2_PRODUCT_FILE" 2>/dev/null)" || return 1
    vendor="$(tr -d '\r\n' < "$OXPX2_VENDOR_FILE" 2>/dev/null)" || return 1
    if [ "$product" != "ONEXPLAYER X2Mini PRO" ] || [ "$vendor" != "ONE-NETBOOK" ]; then
        echo "检测到 DMI：${product:-未知} / ${vendor:-未知}"
        echo "本修复仅适用于 ONEXPLAYER X2Mini PRO（ONE-NETBOOK），已停止执行。"
        return 1
    fi
    if [ ! -d "$OXPX2_ROOT" ] || [ -L "$OXPX2_ROOT" ]; then
        echo "系统安装根目录不是安全的普通目录，已停止执行。"
        return 1
    fi
    for command_name in awk cmp cp grep install mktemp mv rm sha256sum shasum stat systemctl steamos-readonly tr; do
        command -v "$command_name" >/dev/null 2>&1 || {
            if [ "$command_name" = "sha256sum" ] && command -v shasum >/dev/null 2>&1; then continue; fi
            if [ "$command_name" = "shasum" ] && command -v sha256sum >/dev/null 2>&1; then continue; fi
            echo "缺少必要组件：$command_name，未做任何修改。"
            return 1
        }
    done
    systemctl show "$OXPX2_SERVICE" -p LoadState --value 2>/dev/null | grep -Fxq loaded || {
        echo "未找到可用的 ${OXPX2_SERVICE}，未做任何修改。"
        return 1
    }
    declare -F download_github_file >/dev/null 2>&1 || {
        echo "Renkit GitHub 下载器不可用，未做任何修改。"
        return 1
    }
}

oxpx2_hhd_is_active() {
    pgrep -x hhd >/dev/null 2>&1 && return 0
    systemctl is-active --quiet hhd.service >/dev/null 2>&1 && return 0
    systemctl --user is-active --quiet hhd.service >/dev/null 2>&1 && return 0
    return 1
}

oxpx2_require_no_hhd() {
    if oxpx2_hhd_is_active; then
        echo "检测到 HHD 正在运行。HHD 与 InputPlumber 不能同时用于本修复，已停止操作。"
        echo "Renkit 不会自动停止或卸载 HHD；请先自行停用 HHD 后再试。"
        return 1
    fi
}

oxpx2_target_is_safe() {
    local target="$1" parent
    parent="$(dirname "$target")" || return 1
    [ -d "$parent" ] && [ ! -L "$parent" ] || return 1
    [ ! -L "$target" ] || return 1
    return 0
}

oxpx2_prepare_target_dirs() {
    local target parent
    for target in "${OXPX2_TARGETS[@]}"; do
        parent="$(dirname "$target")" || return 1
        if [ -e "$parent" ] || [ -L "$parent" ]; then
            [ -d "$parent" ] && [ ! -L "$parent" ] || {
                echo "目标目录不是安全的普通目录：$parent"
                return 1
            }
        else
            toolbox_sudo install -d -m 0755 -- "$parent" || return 1
        fi
        oxpx2_target_is_safe "$target" || {
            echo "目标文件或目录包含符号链接，已停止：$target"
            return 1
        }
    done
}

oxpx2_source_url() {
    printf 'https://raw.githubusercontent.com/%s/%s/%s\n' "$OXPX2_REPOSITORY" "$OXPX2_COMMIT" "$1"
}

oxpx2_download_sources() {
    local work_dir="$1" index url output
    for index in 0 1 2; do
        url="$(oxpx2_source_url "${OXPX2_PATHS[$index]}")"
        output="$work_dir/$index"
        download_with_gitee_mirror_fallback "${OXPX2_MIRROR_IDS[$index]}" \
            "$url" "${OXPX2_SHA256[$index]}" "$output" \
            "X2 Mini Pro ${OXPX2_NAMES[$index]}" || return 1
        [ -f "$output" ] && [ ! -L "$output" ] || return 1
    done
    grep -Fq 'product_name: ONEXPLAYER X2Mini PRO' "$work_dir/0" && \
        grep -Fq 'name: oxpx2m' "$work_dir/1" && \
        grep -Fq 'QuickAccess' "$work_dir/1" && \
        grep -Fq 'product_name = "ONEXPLAYER X2Mini PRO"' "$work_dir/2" && \
        grep -Fq 'target_devices = ["deck-uhid", "keyboard", "mouse"]' "$work_dir/2" || {
        echo "下载的 X2 Mini Pro 配置内容不符合预期，已停止。"
        return 1
    }
}

oxpx2_backup_path() { printf '%s.renkit-backup\n' "$1"; }

oxpx2_state_value() {
    awk -F= -v wanted="$1" '$1 == wanted { print substr($0, index($0, "=") + 1); exit }' "$OXPX2_STATE_FILE"
}

oxpx2_state_is_valid() {
    local index
    [ -f "$OXPX2_STATE_FILE" ] && [ ! -L "$OXPX2_STATE_FILE" ] || return 1
    grep -Fxq 'version=1' "$OXPX2_STATE_FILE" || return 1
    grep -Fxq 'product_name=ONEXPLAYER X2Mini PRO' "$OXPX2_STATE_FILE" || return 1
    grep -Eq '^was_enabled=[01]$' "$OXPX2_STATE_FILE" || return 1
    grep -Eq '^was_active=[01]$' "$OXPX2_STATE_FILE" || return 1
    for index in 0 1 2; do
        grep -Eq "^target_${index}_existed=[01]$" "$OXPX2_STATE_FILE" || return 1
        grep -Eq "^target_${index}_original_sha=(none|[0-9a-f]{64})$" "$OXPX2_STATE_FILE" || return 1
        grep -Eq "^target_${index}_managed_sha=[0-9a-f]{64}$" "$OXPX2_STATE_FILE" || return 1
    done
}

oxpx2_write_state() {
    local existed=("$@") index target sha state_dir tmp enabled active original
    state_dir="$(dirname "$OXPX2_STATE_FILE")" || return 1
    [ ! -L "$state_dir" ] || return 1
    mkdir -p -- "$state_dir" || return 1
    umask 077
    tmp="$(mktemp "$state_dir/.onexplayer-x2mini.XXXXXX")" || return 1
    enabled=0; active=0
    systemctl is-enabled --quiet "$OXPX2_SERVICE" >/dev/null 2>&1 && enabled=1
    systemctl is-active --quiet "$OXPX2_SERVICE" >/dev/null 2>&1 && active=1
    {
        printf 'version=1\nproduct_name=ONEXPLAYER X2Mini PRO\nwas_enabled=%s\nwas_active=%s\n' "$enabled" "$active"
        for index in 0 1 2; do
            target="${OXPX2_TARGETS[$index]}"
            if [ "${existed[$index]}" = "1" ]; then original="$(oxpx2_sha256 "$(oxpx2_backup_path "$target")")"; else original=none; fi
            sha="${OXPX2_SHA256[$index]}"
            printf 'target_%s_existed=%s\ntarget_%s_original_sha=%s\ntarget_%s_managed_sha=%s\n' "$index" "${existed[$index]}" "$index" "$original" "$index" "$sha"
        done
    } > "$tmp" && mv -f -- "$tmp" "$OXPX2_STATE_FILE" || { rm -f -- "$tmp"; return 1; }
}

oxpx2_backup_targets() {
    local -a existed=(0 0 0)
    local index target backup sha
    for index in 0 1 2; do
        target="${OXPX2_TARGETS[$index]}"; backup="$(oxpx2_backup_path "$target")"
        [ ! -e "$backup" ] && [ ! -L "$backup" ] || { echo "检测到未处理的 Renkit 备份，已停止：$backup"; return 1; }
        if [ -e "$target" ]; then
            [ -f "$target" ] && [ ! -L "$target" ] || { echo "目标不是安全的普通文件：$target"; return 1; }
        fi
    done
    for index in 0 1 2; do
        target="${OXPX2_TARGETS[$index]}"; backup="$(oxpx2_backup_path "$target")"
        if [ -e "$target" ]; then
            toolbox_sudo cp -p -- "$target" "$backup" || return 1
            sha="$(oxpx2_sha256 "$backup")" || return 1
            [ -n "$sha" ] || return 1
            existed[$index]=1
        fi
    done
    oxpx2_write_state "${existed[@]}" || return 1
}

oxpx2_restore_readonly() {
    if [ "$OXPX2_READONLY_CHANGED" = "1" ]; then
        toolbox_sudo steamos-readonly enable || {
            echo "警告：SteamOS 只读保护恢复失败，请立即执行：sudo steamos-readonly enable"
            return 1
        }
        OXPX2_READONLY_CHANGED=0
    fi
}

oxpx2_prepare_readonly() {
    case "$(steamos-readonly status 2>/dev/null || true)" in
        *enabled*) toolbox_sudo steamos-readonly disable || return 1; OXPX2_READONLY_CHANGED=1 ;;
        *disabled*) ;;
        *) echo "无法确认 SteamOS 只读保护状态，未写入系统。"; return 1 ;;
    esac
}

oxpx2_install_one() {
    local source="$1" target="$2" temp
    temp="${target}.renkit-new-$$"
    [ ! -e "$temp" ] && [ ! -L "$temp" ] || return 1
    toolbox_sudo install -m 0644 -- "$source" "$temp" && toolbox_sudo mv -f -- "$temp" "$target"
}

oxpx2_restore_files() {
    local index target backup existed current_sha original_sha
    oxpx2_state_is_valid || return 1
    for index in 0 1 2; do
        target="${OXPX2_TARGETS[$index]}"; existed="$(oxpx2_state_value "target_${index}_existed")"
        original_sha="$(oxpx2_state_value "target_${index}_original_sha")"
        if [ "$existed" = 1 ]; then
            backup="$(oxpx2_backup_path "$target")"
            [ -f "$backup" ] && [ ! -L "$backup" ] && [ "$(oxpx2_sha256 "$backup")" = "$original_sha" ] || return 1
            toolbox_sudo cp -p -- "$backup" "$target" || return 1
        else
            toolbox_sudo rm -f -- "$target" || return 1
        fi
    done
}

oxpx2_verify_managed_files() {
    local index target
    for index in 0 1 2; do
        target="${OXPX2_TARGETS[$index]}"
        [ -f "$target" ] && [ ! -L "$target" ] && [ "$(oxpx2_sha256 "$target")" = "${OXPX2_SHA256[$index]}" ] || return 1
    done
}

oxpx2_restore_service_state() {
    local enabled active
    enabled="$(oxpx2_state_value was_enabled)"; active="$(oxpx2_state_value was_active)"
    if [ "$enabled" = 1 ]; then toolbox_sudo systemctl enable "$OXPX2_SERVICE"; else toolbox_sudo systemctl disable "$OXPX2_SERVICE"; fi || return 1
    if [ "$active" = 1 ]; then toolbox_sudo systemctl restart "$OXPX2_SERVICE"; else toolbox_sudo systemctl stop "$OXPX2_SERVICE"; fi
}

oxpx2_apply_services() {
    toolbox_sudo systemctl daemon-reload || return 1
    toolbox_sudo systemctl enable --now "$OXPX2_SERVICE" >/dev/null || return 1
    toolbox_sudo systemctl restart "$OXPX2_SERVICE" >/dev/null || return 1
    toolbox_sudo systemctl restart steamos-manager.service >/dev/null 2>&1 || true
    systemctl --user restart steamos-manager.service >/dev/null 2>&1 || true
}

oxpx2_cleanup_failed_install() {
    if [ "$OXPX2_MUTATED" = 1 ]; then oxpx2_restore_files >/dev/null 2>&1 || echo "警告：安装失败后无法自动还原全部配置，请使用恢复入口处理。"; fi
    oxpx2_restore_service_state >/dev/null 2>&1 || echo "警告：安装失败后无法恢复 InputPlumber 原服务状态。"
    oxpx2_restore_readonly || true
}

oxpx2_cleanup_records() {
    local target
    rm -f -- "$OXPX2_STATE_FILE" || return 1
    for target in "${OXPX2_TARGETS[@]}"; do
        toolbox_sudo rm -f -- "$(oxpx2_backup_path "$target")" || return 1
    done
}

oxpx2_plan_install() {
    oxpx2_require_environment || return 1
    echo "即将修复 ONEXPLAYER X2 Mini Pro 的三点菜单："
    echo "  - 下载并固定校验 3 份经实机验证的 InputPlumber / steamos-manager 配置"
    echo "  - 写入 /etc/inputplumber/devices.d、/etc/inputplumber/capability_maps.d"
    echo "  - 写入 /usr/share/steamos-manager/devices，临时关闭并恢复 SteamOS 只读保护"
    echo "  - 原有同名文件会备份；可从“恢复特殊按键修复”撤销"
    echo "不会更新 InputPlumber，不会安装 HHD，不会修改 EFI、磁盘或 Windows 引导。"
}

oxpx2_confirm() {
    local answer
    oxpx2_plan_install || return 1
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ]; then return 0; fi
    printf '确认修复 X2 Mini Pro 三点菜单？输入 YES 继续：'
    IFS= read -r answer || return 1
    [ "$answer" = YES ] || { echo "已取消，未做任何修改。"; return 1; }
}

oxpx2_install() {
    local work_dir index
    oxpx2_require_environment || return 1
    oxpx2_require_no_hhd || return 1
    oxpx2_confirm || return 1
    work_dir="$(mktemp -d)" || return 1
    if ! oxpx2_download_sources "$work_dir" || ! oxpx2_prepare_target_dirs || ! oxpx2_backup_targets; then rm -rf -- "$work_dir"; return 1; fi
    if ! oxpx2_prepare_readonly; then oxpx2_cleanup_records || true; rm -rf -- "$work_dir"; return 1; fi
    for index in 0 1 2; do
        oxpx2_install_one "$work_dir/$index" "${OXPX2_TARGETS[$index]}" || { oxpx2_cleanup_failed_install; rm -rf -- "$work_dir"; return 1; }
        OXPX2_MUTATED=1
    done
    if ! oxpx2_verify_managed_files || ! oxpx2_apply_services || oxpx2_hhd_is_active; then
        echo "配置或服务验证失败，正在还原修改。"
        oxpx2_cleanup_failed_install; rm -rf -- "$work_dir"; return 1
    fi
    oxpx2_restore_readonly || { rm -rf -- "$work_dir"; return 1; }
    OXPX2_INSTALL_OK=1
    rm -rf -- "$work_dir"
    log "ONEXPLAYER X2 Mini Pro 三点菜单修复已安装"
    echo "X2 Mini Pro 按键配置已安装。重启 SteamOS 后短按机身 ONEXPLAYER/OXP 标志键，即可打开三点（QAM）菜单。"
}

oxpx2_status() {
    local result=0
    oxpx2_require_environment || return 1
    if oxpx2_state_is_valid; then echo "Renkit 恢复记录：有效。"; else echo "Renkit 恢复记录：不存在或异常。"; result=1; fi
    if oxpx2_verify_managed_files; then echo "X2 Mini Pro 三份配置：正确。"; else echo "X2 Mini Pro 配置：缺失或已变化。"; result=1; fi
    if systemctl is-active --quiet "$OXPX2_SERVICE"; then echo "InputPlumber 服务：active。"; else echo "InputPlumber 服务：不是 active。"; result=1; fi
    inputplumber devices list 2>/dev/null || true
    return "$result"
}

oxpx2_restore() {
    local index target current_sha managed_sha cleanup_result=0
    oxpx2_require_environment || return 1
    oxpx2_state_is_valid || { echo "恢复记录不存在或异常，已停止以免误删文件。"; return 1; }
    for index in 0 1 2; do
        target="${OXPX2_TARGETS[$index]}"; managed_sha="$(oxpx2_state_value "target_${index}_managed_sha")"
        [ -f "$target" ] && [ ! -L "$target" ] || { echo "目标文件缺失或不安全，已停止恢复：$target"; return 1; }
        current_sha="$(oxpx2_sha256 "$target")" || return 1
        [ "$current_sha" = "$managed_sha" ] || { echo "配置已被用户或系统更新修改，Renkit 不会覆盖：$target"; return 1; }
    done
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != 1 ]; then
        printf '确认还原 X2 Mini Pro 修复前配置？输入 YES 继续：'; IFS= read -r answer || return 1; [ "$answer" = YES ] || return 1
    fi
    oxpx2_prepare_readonly || return 1
    oxpx2_restore_files || { oxpx2_restore_readonly; return 1; }
    if ! oxpx2_restore_service_state; then
        oxpx2_cleanup_records || true
        oxpx2_restore_readonly || true
        echo "配置已还原，但 InputPlumber 原服务状态恢复失败；请从系统菜单重启 SteamOS。"
        return 1
    fi
    oxpx2_cleanup_records || cleanup_result=1
    oxpx2_restore_readonly || return 1
    if [ "$cleanup_result" = 1 ]; then
        echo "配置已还原，但 Renkit 备份清理失败；请勿重复恢复，重启 SteamOS 后再检查。"
        return 1
    fi
    echo "X2 Mini Pro 三点菜单修复已恢复原状。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) oxpx2_install ;;
        status) oxpx2_status ;;
        restore) oxpx2_restore ;;
        plan-install) oxpx2_plan_install ;;
        *) echo "用法: $0 {install|status|restore|plan-install}"; exit 1 ;;
    esac
fi
