#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/source_status.sh"

NETWORK_DETAILS=0
NETWORK_COLLECT_FILE=""
NETWORK_TMP_DIR=""
NETWORK_OK=0
NETWORK_FAIL=0
NETWORK_WARN=0
NETWORK_REMOTE_OK=0
NETWORK_LOCAL_READY=0

network_cleanup() {
    [ -z "$NETWORK_TMP_DIR" ] || rm -rf -- "$NETWORK_TMP_DIR"
}

network_record_line() {
    local line="$1"
    [ -z "$NETWORK_COLLECT_FILE" ] || printf '%s\n' "$line" >> "$NETWORK_COLLECT_FILE"
    [ "$NETWORK_DETAILS" -eq 0 ] || printf '%s\n' "$line"
}

network_result() {
    local id="$1" state="$2" label="$3" detail="$4"
    source_status_record "$id" "$state" "$detail" >/dev/null 2>&1 || true
    case "$state" in
        ok)
            NETWORK_OK=$((NETWORK_OK + 1))
            case "$id" in steam|gitee|github|flathub-cn|flathub-ustc|flathub-official|update-gitee|update-github|update-domain) NETWORK_REMOTE_OK=$((NETWORK_REMOTE_OK + 1)) ;; esac
            network_record_line "[正常] ${label}：$detail"
            ;;
        fail) NETWORK_FAIL=$((NETWORK_FAIL + 1)); network_record_line "[异常] ${label}：$detail" ;;
        *) NETWORK_WARN=$((NETWORK_WARN + 1)); network_record_line "[提示] ${label}：$detail" ;;
    esac
}

network_has_default_route() {
    command -v ip >/dev/null 2>&1 || return 1
    ip route show default 2>/dev/null | grep -q '^default'
}

network_dns_works() {
    if command -v getent >/dev/null 2>&1; then
        getent hosts store.steampowered.com >/dev/null 2>&1
    elif command -v dscacheutil >/dev/null 2>&1; then
        dscacheutil -q host -a name store.steampowered.com 2>/dev/null | grep -q 'ip_address:'
    else
        return 1
    fi
}

network_probe() {
    local id="$1" label="$2" url="$3" result
    result="$NETWORK_TMP_DIR/$id"
    (
        if [ "${ZHOUKEER_NETWORK_QUIET:-0}" = "1" ]; then
            curl --fail --location --silent \
                --proto '=https' --proto-redir '=https' \
                --connect-timeout "${ZHOUKEER_NETWORK_CONNECT_TIMEOUT:-3}" \
                --max-time "${ZHOUKEER_NETWORK_MAX_TIME:-8}" \
                --range 0-0 --max-filesize 1048576 --output /dev/null "$url" 2>/dev/null
        else
            curl --fail --location --silent \
                --proto '=https' --proto-redir '=https' \
                --connect-timeout "${ZHOUKEER_NETWORK_CONNECT_TIMEOUT:-3}" \
                --max-time "${ZHOUKEER_NETWORK_MAX_TIME:-8}" \
                --range 0-0 --max-filesize 1048576 --output /dev/null "$url"
        fi
        if [ "$?" -eq 0 ]; then
            printf 'ok\t%s\t连接正常\n' "$label" > "$result"
        else
            printf 'fail\t%s\t连接超时或被拒绝\n' "$label" > "$result"
        fi
    ) &
}

network_check_time() {
    local year sync=""
    year="$(date '+%Y' 2>/dev/null || true)"
    case "$year" in ''|*[!0-9]*) network_result time fail "系统时间" "时间无法读取"; return ;; esac
    if [ "$year" -lt 2025 ] || [ "$year" -gt 2100 ]; then
        network_result time fail "系统时间" "日期明显不正确，会影响安全连接"
        return
    fi
    if command -v timedatectl >/dev/null 2>&1; then
        sync="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)"
    fi
    case "$sync" in no) network_result time skip "系统时间" "日期合理，但自动校时尚未同步" ;; *) network_result time ok "系统时间" "日期合理" ;; esac
}

network_check_proxy() {
    if [ -n "${http_proxy:-}${https_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}${all_proxy:-}" ]; then
        network_result proxy skip "代理或加速器" "检测到代理设置；未读取或显示认证信息"
    elif pgrep -f 'clash|mihomo|v2ray|xray|steamcommunity_302' >/dev/null 2>&1; then
        network_result proxy skip "代理或加速器" "检测到可能影响连接的本机加速程序"
    else
        network_result proxy ok "代理或加速器" "未发现明显冲突"
    fi
}

run_network_diagnostics() {
    local result id state label detail
    NETWORK_TMP_DIR="$(mktemp -d)" || return 1
    trap network_cleanup EXIT INT TERM
    [ -z "$NETWORK_COLLECT_FILE" ] || : > "$NETWORK_COLLECT_FILE"

    if network_has_default_route; then
        NETWORK_LOCAL_READY=1
        network_result local ok "本地网络" "已连接"
    else
        network_result local fail "本地网络" "没有可用网络连接"
    fi
    if network_dns_works; then
        network_result dns ok "名称解析" "工作正常"
    else
        network_result dns fail "名称解析" "无法找到常用网站"
    fi
    network_check_time
    if command -v ip >/dev/null 2>&1 && ip -4 route show default 2>/dev/null | grep -q '^default'; then
        network_result ipv4 ok "IPv4" "可用"
    else
        network_result ipv4 skip "IPv4" "未检测到可用线路"
    fi
    if command -v ip >/dev/null 2>&1 && ip -6 route show default 2>/dev/null | grep -q '^default'; then
        network_result ipv6 ok "IPv6" "可用"
    else
        network_result ipv6 skip "IPv6" "未启用；不影响仅使用 IPv4"
    fi
    network_check_proxy

    if command -v curl >/dev/null 2>&1; then
        network_probe steam "Steam" "https://store.steampowered.com/"
        network_probe gitee "Gitee" "https://gitee.com/"
        network_probe github "GitHub" "https://github.com/"
        network_probe flathub-cn "应用下载国内线路一" "https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo"
        network_probe flathub-ustc "应用下载国内线路二" "https://mirrors.ustc.edu.cn/flathub/flathub.flatpakrepo"
        network_probe flathub-official "应用下载官方线路" "https://dl.flathub.org/repo/flathub.flatpakrepo"
        network_probe update-gitee "工具箱更新国内线路" "https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/VERSION"
        network_probe update-github "工具箱更新备用线路" "https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/VERSION"
        network_probe update-domain "工具箱更新域名线路" "https://jktool.icu/VERSION"
        wait
        for result in "$NETWORK_TMP_DIR"/*; do
            [ -f "$result" ] || continue
            id="${result##*/}"
            IFS=$'\t' read -r state label detail < "$result"
            network_result "$id" "$state" "$label" "$detail"
        done
        if [ "$NETWORK_FAIL" -eq 0 ]; then
            network_result https ok "安全下载连接" "至少一条常用线路可正常使用"
        else
            network_result https skip "安全下载连接" "部分线路不可用，工具箱会自动尝试已有备用线路"
        fi
    else
        network_result https fail "安全下载连接" "缺少网络检查组件"
    fi

    echo ""
    if [ "$NETWORK_FAIL" -eq 0 ]; then
        echo "网络正常。"
    elif [ "$NETWORK_OK" -gt 2 ]; then
        echo "下载连接有问题，工具箱会自动尝试可用线路。"
        echo "如果操作仍失败，建议生成诊断包发给维护人员。"
    else
        echo "当前网络不可用或很不稳定。请先检查 Wi-Fi 和系统时间。"
        echo "仍无法解决时，建议生成诊断包发给维护人员。"
    fi
    [ "$NETWORK_DETAILS" -eq 0 ] || {
        echo ""
        source_status_show
    }
    log "网络诊断完成: 正常=$NETWORK_OK 异常=$NETWORK_FAIL 提示=$NETWORK_WARN"
    [ "$NETWORK_LOCAL_READY" -eq 1 ] && [ "$NETWORK_REMOTE_OK" -gt 0 ]
}

case "${1:-}" in
    "") run_network_diagnostics ;;
    --details) NETWORK_DETAILS=1; run_network_diagnostics ;;
    --collect)
        [ -n "${2:-}" ] || { echo "缺少诊断输出文件。"; exit 1; }
        NETWORK_COLLECT_FILE="$2"
        run_network_diagnostics
        ;;
    --preflight)
        NETWORK_COLLECT_FILE="${2:-}"
        run_network_diagnostics >/dev/null
        ;;
    *) echo "用法: $0 [--details|--collect 文件|--preflight [文件]]"; exit 1 ;;
esac
