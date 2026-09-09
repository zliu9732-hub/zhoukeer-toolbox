#!/bin/bash

set -u

# InputPlumber 官方固定版本。更新版本时必须同步更新 SHA256 和测试。
INPUTPLUMBER_UPDATE_VERSION="0.79.2"
INPUTPLUMBER_UPDATE_ARCHIVE="inputplumber-x86_64.tar.gz"
INPUTPLUMBER_UPDATE_SHA256="dc8a859b55047c1a78c99dfaa296c55eebfbf798057f519543fbc7f6215cf953"
INPUTPLUMBER_UPDATE_URL="https://github.com/ShadowBlip/InputPlumber/releases/download/v${INPUTPLUMBER_UPDATE_VERSION}/${INPUTPLUMBER_UPDATE_ARCHIVE}"

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

INPUTPLUMBER_UPDATE_PRODUCT_FILE="${ZHOUKEER_INPUTPLUMBER_PRODUCT_FILE:-/sys/class/dmi/id/product_name}"
INPUTPLUMBER_UPDATE_VENDOR_FILE="${ZHOUKEER_INPUTPLUMBER_VENDOR_FILE:-/sys/class/dmi/id/sys_vendor}"
INPUTPLUMBER_UPDATE_STATE_DIR="${ZHOUKEER_INPUTPLUMBER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox/inputplumber-update}"
INPUTPLUMBER_UPDATE_INSTALL_ROOT="/"
if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ]; then
    INPUTPLUMBER_UPDATE_URL="${ZHOUKEER_INPUTPLUMBER_URL:-$INPUTPLUMBER_UPDATE_URL}"
    INPUTPLUMBER_UPDATE_SHA256="${ZHOUKEER_INPUTPLUMBER_SHA256:-$INPUTPLUMBER_UPDATE_SHA256}"
    INPUTPLUMBER_UPDATE_INSTALL_ROOT="${ZHOUKEER_INPUTPLUMBER_INSTALL_ROOT:-/}"
fi

INPUTPLUMBER_UPDATE_PRODUCT=""
INPUTPLUMBER_UPDATE_VENDOR=""
INPUTPLUMBER_UPDATE_BACKUP=""
INPUTPLUMBER_UPDATE_WAS_ACTIVE=0
INPUTPLUMBER_UPDATE_WAS_ENABLED=0
INPUTPLUMBER_UPDATE_READONLY_CHANGED=0

ipu_root_path() {
    printf '%s/%s\n' "${INPUTPLUMBER_UPDATE_INSTALL_ROOT%/}" "${1#/}"
}

ipu_current_version() {
    local binary

    binary="$(ipu_root_path usr/bin/inputplumber)"
    if [ -x "$binary" ]; then
        "$binary" --version 2>/dev/null || printf '%s\n' "未知"
    elif command -v inputplumber >/dev/null 2>&1; then
        inputplumber --version 2>/dev/null || printf '%s\n' "未知"
    else
        printf '%s\n' "未安装"
    fi
}

ipu_require_environment() {
    local command_name architecture

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "InputPlumber 更新仅支持 SteamOS，已停止执行。"
        return 1
    fi
    if [ "$(id -u 2>/dev/null)" -eq 0 ]; then
        echo "请使用 SteamOS 桌面用户运行Renkit，不要直接以 root 运行。"
        return 1
    fi
    architecture="$(uname -m 2>/dev/null || true)"
    if [ "$architecture" != "x86_64" ]; then
        echo "当前架构不是 x86_64（检测到：${architecture:-未知}），已停止执行。"
        return 1
    fi
    if [ ! -r "$INPUTPLUMBER_UPDATE_PRODUCT_FILE" ] || \
       [ ! -r "$INPUTPLUMBER_UPDATE_VENDOR_FILE" ]; then
        echo "无法读取掌机 DMI 型号或厂商，已停止执行。"
        return 1
    fi
    INPUTPLUMBER_UPDATE_PRODUCT="$(tr -d '\r\n' < "$INPUTPLUMBER_UPDATE_PRODUCT_FILE" 2>/dev/null)" || return 1
    INPUTPLUMBER_UPDATE_VENDOR="$(tr -d '\r\n' < "$INPUTPLUMBER_UPDATE_VENDOR_FILE" 2>/dev/null)" || return 1
    case "$INPUTPLUMBER_UPDATE_PRODUCT" in
        ONEXPLAYER*|ONEXFLY*) ;;
        *)
            echo "检测到型号：${INPUTPLUMBER_UPDATE_PRODUCT:-未知}"
            echo "此入口只允许壹号掌机使用，已停止执行。"
            return 1
            ;;
    esac
    case "$INPUTPLUMBER_UPDATE_VENDOR" in
        ONE-NETBOOK*) ;;
        *)
            echo "检测到厂商：${INPUTPLUMBER_UPDATE_VENDOR:-未知}"
            echo "DMI 厂商不是 ONE-NETBOOK，已停止执行。"
            return 1
            ;;
    esac
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
       [ "$INPUTPLUMBER_UPDATE_INSTALL_ROOT" != "/" ]; then
        echo "系统安装根目录异常，已停止执行。"
        return 1
    fi
    if [ ! -d "$INPUTPLUMBER_UPDATE_INSTALL_ROOT" ] || \
       [ -L "$INPUTPLUMBER_UPDATE_INSTALL_ROOT" ]; then
        echo "系统安装根目录不是安全的普通目录，已停止执行。"
        return 1
    fi
    for command_name in curl tar awk grep sort uniq mktemp tr uname systemctl steamos-readonly udevadm; do
        require_command "$command_name" || {
            echo "更新 InputPlumber 缺少必要组件，未做任何修改。"
            return 1
        }
    done
    if ! command -v sha256sum >/dev/null 2>&1 && \
       ! command -v shasum >/dev/null 2>&1; then
        echo "缺少 SHA256 校验工具，未做任何修改。"
        return 1
    fi
    declare -F download_github_file >/dev/null 2>&1 || {
        echo "Renkit GitHub 下载器不可用，未做任何修改。"
        return 1
    }
}

ipu_print_plan() {
    ipu_require_environment || return 1
    echo "即将更新壹号掌机的 InputPlumber："
    echo "  - 机型：$INPUTPLUMBER_UPDATE_PRODUCT"
    echo "  - 当前版本：$(ipu_current_version)"
    echo "  - 目标版本：inputplumber ${INPUTPLUMBER_UPDATE_VERSION}"
    echo "  - 来源：ShadowBlip/InputPlumber 官方固定 Release"
    echo "  - 校验：SHA256 ${INPUTPLUMBER_UPDATE_SHA256}"
    echo "  - 写入范围：SteamOS /usr 下的 InputPlumber 二进制、配置、服务、udev 与 DBus/Polkit 文件"
    echo "  - 更新前会保存旧版备份；系统大版本更新可能覆盖本次手动更新"
    echo "更新时会暂停 InputPlumber，并临时关闭 SteamOS 只读保护；结束时恢复原只读状态。"
    echo "不会修改 EFI、磁盘、Windows 引导、HHD 或 /etc/inputplumber/devices.d 自定义配置。"
}

ipu_confirm_update() {
    local answer

    ipu_print_plan || return 1
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "已通过Renkit界面确认，继续执行。"
        return 0
    fi
    printf '确认更新 InputPlumber？输入 UPDATE 继续：'
    IFS= read -r answer || return 1
    [ "$answer" = "UPDATE" ] || {
        echo "已取消，未做任何修改。"
        return 1
    }
}

ipu_validate_archive() {
    local archive="$1" work_dir="$2" manifest listing staged_binary version_output

    manifest="$work_dir/archive.list"
    listing="$work_dir/archive.verbose"
    tar -tzf "$archive" > "$manifest" 2>/dev/null || {
        echo "InputPlumber 压缩包无法读取，已停止。"
        return 1
    }
    [ "$(wc -l < "$manifest" | tr -d ' ')" -le 2000 ] || {
        echo "InputPlumber 压缩包文件数量异常，已停止。"
        return 1
    }
    if awk '
        $0 != "inputplumber/" && index($0, "inputplumber/usr/") != 1 { bad=1 }
        $0 ~ /(^|\/)\.\.($|\/)/ || $0 ~ /^\// { bad=1 }
        END { exit bad ? 0 : 1 }
    ' "$manifest"; then
        echo "InputPlumber 压缩包包含越界路径，已停止。"
        return 1
    fi
    if sort "$manifest" | uniq -d | grep -q .; then
        echo "InputPlumber 压缩包包含重复路径，已停止。"
        return 1
    fi
    tar -tvzf "$archive" > "$listing" 2>/dev/null || return 1
    if awk 'substr($1,1,1) != "-" && substr($1,1,1) != "d" { bad=1 } END { exit bad ? 0 : 1 }' "$listing"; then
        echo "InputPlumber 压缩包包含符号链接或特殊文件，已停止。"
        return 1
    fi
    for required_path in \
        inputplumber/usr/bin/inputplumber \
        inputplumber/usr/lib/systemd/system/inputplumber.service \
        inputplumber/usr/share/inputplumber/devices/50-onexplayer_mini_pro.yaml \
        inputplumber/usr/share/inputplumber/devices/50-onexplayer_2.yaml \
        inputplumber/usr/share/inputplumber/capability_maps/onexplayer_type3.yaml \
        inputplumber/usr/share/inputplumber/capability_maps/onexplayer_type4.yaml; do
        grep -Fxq "$required_path" "$manifest" || {
            echo "InputPlumber 压缩包缺少壹号掌机支持文件：$required_path"
            return 1
        }
    done
    mkdir -p -- "$work_dir/stage" || return 1
    tar --no-same-owner --no-overwrite-dir -xzf "$archive" \
        --strip-components=1 -C "$work_dir/stage" || return 1
    staged_binary="$work_dir/stage/usr/bin/inputplumber"
    [ -x "$staged_binary" ] || {
        echo "InputPlumber 压缩包中的程序不可执行，已停止。"
        return 1
    }
    version_output="$("$staged_binary" --version 2>/dev/null || true)"
    case "$version_output" in
        "inputplumber ${INPUTPLUMBER_UPDATE_VERSION}"*) ;;
        *)
            echo "InputPlumber 包内版本不符（检测到：${version_output:-未知}），已停止。"
            return 1
            ;;
    esac
}

ipu_backup_existing() {
    local work_dir="$1" list_file timestamp relative_path full_path uid gid

    if [ -e "$INPUTPLUMBER_UPDATE_STATE_DIR" ] || [ -L "$INPUTPLUMBER_UPDATE_STATE_DIR" ]; then
        if [ ! -d "$INPUTPLUMBER_UPDATE_STATE_DIR" ] || [ -L "$INPUTPLUMBER_UPDATE_STATE_DIR" ]; then
            echo "InputPlumber 备份目录不安全：$INPUTPLUMBER_UPDATE_STATE_DIR"
            return 1
        fi
    else
        mkdir -p -- "$INPUTPLUMBER_UPDATE_STATE_DIR" || return 1
        chmod 0700 "$INPUTPLUMBER_UPDATE_STATE_DIR" || return 1
    fi
    timestamp="$(date '+%Y%m%d-%H%M%S')" || return 1
    INPUTPLUMBER_UPDATE_BACKUP="$INPUTPLUMBER_UPDATE_STATE_DIR/inputplumber-before-${INPUTPLUMBER_UPDATE_VERSION}-${timestamp}.tar.gz"
    [ ! -e "$INPUTPLUMBER_UPDATE_BACKUP" ] && [ ! -L "$INPUTPLUMBER_UPDATE_BACKUP" ] || {
        echo "InputPlumber 备份文件已存在，已停止：$INPUTPLUMBER_UPDATE_BACKUP"
        return 1
    }
    list_file="$work_dir/backup.list"
    : > "$list_file" || return 1
    for relative_path in \
        usr/bin/inputplumber \
        usr/share/inputplumber \
        usr/lib/systemd/system/inputplumber.service \
        usr/lib/systemd/system/inputplumber-suspend.service \
        usr/lib/udev/hwdb.d/59-inputplumber.hwdb \
        usr/lib/udev/hwdb.d/60-inputplumber-autostart.hwdb \
        usr/lib/udev/rules.d/60-inputplumber-uaccess.rules \
        usr/lib/udev/rules.d/90-inputplumber-autostart.rules \
        usr/lib/udev/rules.d/99-inputplumber-device-setup.rules \
        usr/share/dbus-1/system.d/org.shadowblip.InputPlumber.conf \
        usr/share/polkit-1/actions/org.shadowblip.InputPlumber.policy \
        usr/share/polkit-1/rules.d/org.shadowblip.InputPlumber.rules; do
        full_path="$(ipu_root_path "$relative_path")"
        if [ -e "$full_path" ] && [ ! -L "$full_path" ]; then
            printf '%s\n' "$relative_path" >> "$list_file" || return 1
        fi
    done
    [ -s "$list_file" ] || {
        echo "没有找到可备份的现有 InputPlumber 文件，已停止更新。"
        return 1
    }
    toolbox_sudo tar -czf "$INPUTPLUMBER_UPDATE_BACKUP" \
        -C "$INPUTPLUMBER_UPDATE_INSTALL_ROOT" -T "$list_file" || {
        echo "备份现有 InputPlumber 失败，未开始更新。"
        return 1
    }
    uid="$(id -u)" || return 1
    gid="$(id -g)" || return 1
    toolbox_sudo chown "$uid:$gid" "$INPUTPLUMBER_UPDATE_BACKUP" || return 1
    [ -f "$INPUTPLUMBER_UPDATE_BACKUP" ] && [ ! -L "$INPUTPLUMBER_UPDATE_BACKUP" ] && \
        tar -tzf "$INPUTPLUMBER_UPDATE_BACKUP" >/dev/null 2>&1 || {
            echo "InputPlumber 备份校验失败，未开始更新。"
            return 1
        }
    echo "旧版备份已保存：$INPUTPLUMBER_UPDATE_BACKUP"
}

ipu_capture_service_state() {
    INPUTPLUMBER_UPDATE_WAS_ENABLED=0
    INPUTPLUMBER_UPDATE_WAS_ACTIVE=0
    systemctl is-enabled --quiet inputplumber.service >/dev/null 2>&1 && INPUTPLUMBER_UPDATE_WAS_ENABLED=1
    systemctl is-active --quiet inputplumber.service >/dev/null 2>&1 && INPUTPLUMBER_UPDATE_WAS_ACTIVE=1
}

ipu_restore_service_after_failure() {
    if [ "$INPUTPLUMBER_UPDATE_WAS_ENABLED" = "1" ]; then
        toolbox_sudo systemctl enable inputplumber.service >/dev/null 2>&1 || true
    else
        toolbox_sudo systemctl disable inputplumber.service >/dev/null 2>&1 || true
    fi
    if [ "$INPUTPLUMBER_UPDATE_WAS_ACTIVE" = "1" ]; then
        toolbox_sudo systemctl restart inputplumber.service >/dev/null 2>&1 || true
    else
        toolbox_sudo systemctl stop inputplumber.service >/dev/null 2>&1 || true
    fi
}

ipu_prepare_readonly() {
    local readonly_status

    readonly_status="$(steamos-readonly status 2>/dev/null || true)"
    case "$readonly_status" in
        *enabled*)
            toolbox_sudo steamos-readonly disable || {
                echo "无法临时关闭 SteamOS 只读保护，未写入系统。"
                return 1
            }
            INPUTPLUMBER_UPDATE_READONLY_CHANGED=1
            ;;
        *disabled*) INPUTPLUMBER_UPDATE_READONLY_CHANGED=0 ;;
        *)
            echo "无法确认 SteamOS 只读保护状态，未写入系统。"
            return 1
            ;;
    esac
}

ipu_restore_readonly() {
    if [ "$INPUTPLUMBER_UPDATE_READONLY_CHANGED" = "1" ]; then
        if ! toolbox_sudo steamos-readonly enable; then
            echo "警告：SteamOS 只读保护恢复失败，请立即执行：sudo steamos-readonly enable"
            return 1
        fi
        INPUTPLUMBER_UPDATE_READONLY_CHANGED=0
    fi
}

ipu_apply_update() {
    local archive="$1" result=0 installed_version binary owner

    ipu_capture_service_state
    ipu_prepare_readonly || return 1

    toolbox_sudo systemctl stop inputplumber.service >/dev/null || result=1
    if [ "$result" = "0" ]; then
        toolbox_sudo tar --no-same-owner --no-overwrite-dir -xzf "$archive" \
            --strip-components=1 -C "$INPUTPLUMBER_UPDATE_INSTALL_ROOT" || result=1
    fi
    if [ "$result" = "0" ]; then
        toolbox_sudo systemctl daemon-reload || result=1
    fi
    if [ "$result" = "0" ]; then
        if command -v systemd-hwdb >/dev/null 2>&1; then
            toolbox_sudo systemd-hwdb update || result=1
        else
            toolbox_sudo udevadm hwdb --update || result=1
        fi
    fi
    if [ "$result" = "0" ]; then
        toolbox_sudo udevadm control --reload-rules || result=1
    fi
    if [ "$result" = "0" ]; then
        toolbox_sudo systemctl enable --now inputplumber.service >/dev/null || result=1
    fi
    if [ "$result" = "0" ]; then
        toolbox_sudo systemctl restart inputplumber.service >/dev/null || result=1
    fi

    binary="$(ipu_root_path usr/bin/inputplumber)"
    if [ "$result" = "0" ]; then
        installed_version="$("$binary" --version 2>/dev/null || true)"
        case "$installed_version" in
            "inputplumber ${INPUTPLUMBER_UPDATE_VERSION}"*) ;;
            *) result=1 ;;
        esac
    fi
    if [ "$result" = "0" ] && [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        owner="$(stat -c '%u' "$binary" 2>/dev/null || true)"
        [ "$owner" = "0" ] || result=1
    fi
    if [ "$result" = "0" ]; then
        systemctl is-active --quiet inputplumber.service || result=1
        systemctl is-enabled --quiet inputplumber.service || result=1
    fi

    if [ "$result" != "0" ]; then
        echo "InputPlumber 更新或验证失败，正在恢复原服务状态。"
        ipu_restore_service_after_failure
    fi
    if ! ipu_restore_readonly; then
        result=1
    fi
    if [ "$result" != "0" ]; then
        echo "旧版备份保留在：$INPUTPLUMBER_UPDATE_BACKUP"
        echo "请勿删除该备份；可据此人工恢复旧文件。"
        return 1
    fi
}

ipu_update() {
    local work_dir archive

    ipu_confirm_update || return 1
    work_dir="$(mktemp -d)" || return 1
    archive="$work_dir/$INPUTPLUMBER_UPDATE_ARCHIVE"

    if ! download_github_file "$INPUTPLUMBER_UPDATE_URL" "$archive" \
        "$INPUTPLUMBER_UPDATE_SHA256" "InputPlumber ${INPUTPLUMBER_UPDATE_VERSION}"; then
        rm -rf -- "$work_dir"
        return 1
    fi
    if ! ipu_validate_archive "$archive" "$work_dir"; then
        rm -rf -- "$work_dir"
        return 1
    fi
    if ! ipu_backup_existing "$work_dir"; then
        rm -rf -- "$work_dir"
        return 1
    fi
    if ! ipu_apply_update "$archive"; then
        rm -rf -- "$work_dir"
        log "InputPlumber 更新失败: model=$INPUTPLUMBER_UPDATE_PRODUCT target=$INPUTPLUMBER_UPDATE_VERSION backup=$INPUTPLUMBER_UPDATE_BACKUP"
        return 1
    fi
    rm -rf -- "$work_dir"
    log "InputPlumber 更新完成: model=$INPUTPLUMBER_UPDATE_PRODUCT version=$INPUTPLUMBER_UPDATE_VERSION backup=$INPUTPLUMBER_UPDATE_BACKUP"
    echo "InputPlumber 已更新并验证为 ${INPUTPLUMBER_UPDATE_VERSION}，服务状态为 active。"
    echo "请重启 SteamOS 后测试 Steam/Guide、三个点快捷菜单和虚拟键盘按键。"
    echo "旧版备份：$INPUTPLUMBER_UPDATE_BACKUP"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        update) ipu_update ;;
        plan) ipu_print_plan ;;
        *) echo "用法: $0 {update|plan}"; exit 1 ;;
    esac
fi
