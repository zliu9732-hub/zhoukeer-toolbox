#!/bin/bash

set -u

# 只更新软件包管理器已管理、且当前正在使用的 InputPlumber。
# 设备描述和按键映射由各机型的独立模块维护。
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

IPU_MANAGER=""
IPU_INSTALLED=""
IPU_CANDIDATE=""
IPU_CHECK_STATE=""

ipu_message() {
    echo "InputPlumber：$*"
    log "InputPlumber：$*"
}

ipu_service_in_use() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl is-active --quiet inputplumber.service 2>/dev/null ||
        systemctl is-enabled --quiet inputplumber.service 2>/dev/null
}

ipu_detect_package() {
    IPU_MANAGER=""
    IPU_INSTALLED=""
    if command -v pacman >/dev/null 2>&1 && pacman -Q inputplumber >/dev/null 2>&1; then
        IPU_MANAGER="pacman"
        IPU_INSTALLED="$(pacman -Q inputplumber 2>/dev/null | awk 'NR==1 {print $2}')"
    elif command -v dpkg-query >/dev/null 2>&1 &&
        [ "$(dpkg-query -W -f='${Status}' inputplumber 2>/dev/null)" = 'install ok installed' ]; then
        IPU_MANAGER="apt"
        IPU_INSTALLED="$(dpkg-query -W -f='${Version}' inputplumber 2>/dev/null)"
    elif command -v rpm >/dev/null 2>&1 && rpm -q inputplumber >/dev/null 2>&1 &&
        command -v dnf >/dev/null 2>&1; then
        IPU_MANAGER="dnf"
        IPU_INSTALLED="$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' inputplumber 2>/dev/null)"
    fi
    [ -n "$IPU_MANAGER" ] && [ -n "$IPU_INSTALLED" ]
}

ipu_check() {
    local available pending line name found=0
    IPU_CHECK_STATE="skip"
    if [ "$(uname -s 2>/dev/null)" != Linux ]; then
        ipu_message "当前不是 Linux，跳过。"
        return 0
    fi
    detect_platform
    if [ "${IS_CHIMERAOS:-0}" -eq 1 ]; then
        ipu_message "ChimeraOS 的系统组件由系统维护，跳过独立升级。"
        return 0
    fi
    if command -v rpm-ostree >/dev/null 2>&1; then
        ipu_message "当前系统由 rpm-ostree 管理，跳过独立软件包升级。"
        return 0
    fi
    if ! ipu_service_in_use; then
        ipu_message "服务未启用且未运行，跳过。"
        return 0
    fi
    if ! ipu_detect_package; then
        ipu_message "未发现受支持的软件包管理器所安装的 InputPlumber，跳过。"
        return 0
    fi
    case "$IPU_MANAGER" in
        pacman)
            command -v vercmp >/dev/null 2>&1 || { ipu_message "缺少 vercmp，无法安全比较版本。"; return 1; }
            available="$(pacman -Si inputplumber 2>/dev/null | awk '$1 == "Version" {print $3; exit}')"
            [ -n "$available" ] || { ipu_message "当前软件源没有 InputPlumber 包，跳过。"; return 0; }
            if [ "$(vercmp "$available" "$IPU_INSTALLED")" -le 0 ]; then
                IPU_CHECK_STATE="current"
                ipu_message "已是当前软件源最新版本（${IPU_INSTALLED}）。"
                return 0
            fi
            # Arch/SteamOS 不可进行部分升级；其他待更新包存在时留给完整系统更新。
            pending="$(pacman -Qu 2>/dev/null)" || { ipu_message "无法核对系统待更新包，跳过。"; return 1; }
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                name="${line%% *}"
                if [ "$name" != inputplumber ]; then
                    ipu_message "另有系统包待更新；为避免 pacman 部分升级，已跳过。请先完成系统更新。"
                    return 0
                fi
                found=1
            done <<< "$pending"
            if [ "$found" -ne 1 ]; then
                ipu_message "软件源与待更新列表不一致，跳过。"
                return 0
            fi
            ;;
        apt)
            command -v apt-cache >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1 || return 1
            available="$(apt-cache policy inputplumber 2>/dev/null | awk '/^[[:space:]]*Candidate:/ {print $2; exit}')"
            [ -n "$available" ] && [ "$available" != '(none)' ] || { ipu_message "软件源没有可安装版本，跳过。"; return 0; }
            if ! dpkg --compare-versions "$available" gt "$IPU_INSTALLED"; then
                IPU_CHECK_STATE="current"
                ipu_message "已是当前软件源最新版本（${IPU_INSTALLED}）。"
                return 0
            fi
            ;;
        dnf)
            available="$(dnf -q repoquery --upgrades --latest-limit 1 --qf '%{version}-%{release}' inputplumber 2>/dev/null | head -1)"
            if [ -z "$available" ]; then
                IPU_CHECK_STATE="current"
                ipu_message "当前软件源没有更高版本（已安装 ${IPU_INSTALLED}）。"
                return 0
            fi
            ;;
    esac
    IPU_CANDIDATE="$available"
    IPU_CHECK_STATE="upgrade"
    ipu_message "已安装 ${IPU_INSTALLED}；当前软件源可升级至 ${IPU_CANDIDATE}（${IPU_MANAGER}）。"
}

ipu_journal_summary() {
    if command -v journalctl >/dev/null 2>&1; then
        echo "InputPlumber 最近服务日志："
        journalctl -u inputplumber.service -n 20 --no-pager --output=short 2>&1 || true
    fi
}

ipu_upgrade_package() {
    local readonly_status="" readonly_changed=0 result=0
    if [ "$IPU_MANAGER" = pacman ] && command -v steamos-readonly >/dev/null 2>&1; then
        readonly_status="$(steamos-readonly status 2>/dev/null || true)"
        case "$readonly_status" in
            *enabled*)
                toolbox_sudo steamos-readonly disable || return 1
                readonly_changed=1
                ;;
            *disabled*) ;;
            *) ipu_message "无法确认系统只读保护状态，未更新。"; return 1 ;;
        esac
    fi
    case "$IPU_MANAGER" in
        pacman) toolbox_sudo pacman -S --needed --noconfirm inputplumber || result=1 ;;
        apt) toolbox_sudo apt-get install --only-upgrade -y inputplumber || result=1 ;;
        dnf) toolbox_sudo dnf upgrade -y inputplumber || result=1 ;;
        *) result=1 ;;
    esac
    if [ "$readonly_changed" -eq 1 ] && ! toolbox_sudo steamos-readonly enable; then
        ipu_message "警告：恢复系统只读保护失败，请立即检查 steamos-readonly 状态。"
        result=1
    fi
    return "$result"
}

ipu_update() {
    local result=0 after=""
    ipu_check || return 1
    [ "$IPU_CHECK_STATE" = upgrade ] || return 0
    # 自动更新只在已启用的服务上执行，且从不安装此前没有安装的包。
    ipu_message "通过系统软件源升级；不会写入设备 YAML 或下载独立二进制。"
    if ! ipu_upgrade_package; then
        ipu_message "软件包升级失败；其他 RenKit 功能可继续使用。"
        return 1
    fi
    if ! toolbox_sudo systemctl restart inputplumber.service; then
        ipu_message "软件包已升级，但 inputplumber.service 重启失败。"
        result=1
    elif ! systemctl is-active --quiet inputplumber.service; then
        ipu_message "软件包已升级，但 inputplumber.service 未处于运行状态。"
        result=1
    fi
    if [ "$result" -ne 0 ]; then
        ipu_journal_summary
        return 1
    fi
    if ipu_detect_package; then after="$IPU_INSTALLED"; fi
    ipu_message "升级完成（${after:-版本待确认}），服务运行正常。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        update|auto) ipu_update ;;
        plan|check) ipu_check ;;
        *) echo "用法: $0 {update|auto|check|plan}"; exit 1 ;;
    esac
fi
