#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/memory_tuning.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

ZHOUKEER_SWAPFILE_PATH="$TMP_ROOT/swapfile"
ZHOUKEER_MEMORY_FALLBACK_SWAPFILE_PATH="$TMP_ROOT/.zhoukeer-swapfile"
ZHOUKEER_ZRAM_CONFIG="$TMP_ROOT/etc/zram.conf"
ZHOUKEER_MEMORY_SYSCTL_CONFIG="$TMP_ROOT/etc/memory.conf"
ZHOUKEER_SYSTEMD_DIR="$TMP_ROOT/systemd"
ZHOUKEER_AUTO_CONFIRM=1
ZHOUKEER_TEST_MODE=1

# shellcheck disable=SC1090
source "$MODULE"

SYSTEMCTL_LOG="$TMP_ROOT/systemctl.log"
SWAP_LOG="$TMP_ROOT/swap.log"
FALLBACK_ACTIVE=1
SWAPOFF_FAIL=0
SYSTEMCTL_DISABLE_FAIL=0
FALLBACK_UNIT_STATE=enabled
MAIN_UNIT_STATE=enabled

detect_platform() { IS_STEAMOS=1; }
id() { [ "${1:-}" = "-u" ] && printf '1000\n'; }
require_command() { return 0; }
memory_swap_unit_name_for_path() {
    case "$1" in
        "$MEMORY_SWAPFILE_PATH") printf 'main.swap\n' ;;
        "$MEMORY_FALLBACK_SWAPFILE_PATH") printf 'fallback.swap\n' ;;
        *) return 1 ;;
    esac
}
memory_swap_is_active() {
    [ "$1" = "$MEMORY_FALLBACK_SWAPFILE_PATH" ] && [ "$FALLBACK_ACTIVE" -eq 1 ]
}
toolbox_sudo() {
    case "${1:-}" in
        true) return 0 ;;
        blkid) printf 'swap\n' ;;
        systemctl)
            printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
            case "${2:-}" in
                is-enabled)
                    case "${3:-}" in
                        fallback.swap) printf '%s\n' "$FALLBACK_UNIT_STATE"; [ "$FALLBACK_UNIT_STATE" = enabled ] ;;
                        main.swap) printf '%s\n' "$MAIN_UNIT_STATE"; [ "$MAIN_UNIT_STATE" = enabled ] ;;
                        *) return 1 ;;
                    esac
                    ;;
                disable)
                    [ "$SYSTEMCTL_DISABLE_FAIL" -eq 0 ] || return 1
                    case "${3:-}" in
                        fallback.swap) FALLBACK_UNIT_STATE=disabled ;;
                        main.swap) MAIN_UNIT_STATE=disabled ;;
                    esac
                    ;;
                enable)
                    case "${3:-}" in
                        fallback.swap) FALLBACK_UNIT_STATE=enabled ;;
                        main.swap) MAIN_UNIT_STATE=enabled ;;
                    esac
                    ;;
            esac
            ;;
        swapoff)
            printf '%s\n' "$*" >> "$SWAP_LOG"
            [ "$SWAPOFF_FAIL" -eq 0 ] || return 1
            FALLBACK_ACTIVE=0
            ;;
        swapon)
            printf '%s\n' "$*" >> "$SWAP_LOG"
            FALLBACK_ACTIVE=1
            ;;
        *) "$@" ;;
    esac
}

prepare_managed_files() {
    FALLBACK_UNIT_STATE=enabled
    MAIN_UNIT_STATE=enabled
    mkdir -p "$ZHOUKEER_SYSTEMD_DIR" "$(dirname "$ZHOUKEER_ZRAM_CONFIG")"
    printf 'system original\n' > "$MEMORY_SWAPFILE_PATH"
    printf 'toolbox fallback\n' > "$MEMORY_FALLBACK_SWAPFILE_PATH"
    cat > "$ZHOUKEER_SYSTEMD_DIR/main.swap" <<EOF
# Managed by Zhoukeer Toolbox
[Swap]
What=$MEMORY_SWAPFILE_PATH
Priority=10
EOF
    cat > "$ZHOUKEER_SYSTEMD_DIR/fallback.swap" <<EOF
# Managed by Zhoukeer Toolbox
[Swap]
What=$MEMORY_FALLBACK_SWAPFILE_PATH
Priority=10
EOF
    printf '# Managed by Zhoukeer Toolbox\n[zram0]\n' > "$ZHOUKEER_ZRAM_CONFIG"
    printf '# Managed by Zhoukeer Toolbox\nvm.swappiness = 1\n' > "$ZHOUKEER_MEMORY_SYSCTL_CONFIG"
}

prepare_managed_files
memory_restore_toolbox > "$TMP_ROOT/restore.output" || fail "撤销Renkit虚拟内存优化失败"
[ -f "$MEMORY_SWAPFILE_PATH" ] || fail "系统原 swap 被删除"
[ "$(cat "$MEMORY_SWAPFILE_PATH")" = 'system original' ] || fail "系统原 swap 被修改"
[ ! -e "$MEMORY_FALLBACK_SWAPFILE_PATH" ] || fail "Renkit独立 swap 未删除"
[ ! -e "$ZHOUKEER_SYSTEMD_DIR/main.swap" ] || fail "主 swap Renkit单元未删除"
[ ! -e "$ZHOUKEER_SYSTEMD_DIR/fallback.swap" ] || fail "独立 swap Renkit单元未删除"
[ ! -e "$ZHOUKEER_ZRAM_CONFIG" ] || fail "Renkit zram 配置未删除"
[ ! -e "$ZHOUKEER_MEMORY_SYSCTL_CONFIG" ] || fail "Renkit swappiness 配置未删除"
grep -Fq 'swapoff' "$SWAP_LOG" || fail "运行中的Renkit独立 swap 未停用"
! grep -Fq "$MEMORY_SWAPFILE_PATH" "$SWAP_LOG" || fail "系统原 swap 被停用"
grep -Fq 'disable fallback.swap' "$SYSTEMCTL_LOG" || fail "独立 swap 单元未禁用"
grep -Fq 'disable main.swap' "$SYSTEMCTL_LOG" || fail "主 swap Renkit单元未禁用"
grep -Fq 'daemon-reload' "$SYSTEMCTL_LOG" || fail "删除单元后未刷新 systemd"
grep -Fq '系统原 swap 已保留' "$TMP_ROOT/restore.output" || fail "撤销成功提示不明确"

# 重复撤销应保持成功，不能触碰系统原 swap。
FALLBACK_ACTIVE=0
memory_restore_toolbox > "$TMP_ROOT/restore-again.output" || fail "重复撤销未保持幂等"
[ -f "$MEMORY_SWAPFILE_PATH" ] || fail "重复撤销删除了系统原 swap"

# 没有Renkit标记时必须保留同名配置和文件。
printf 'user fallback\n' > "$MEMORY_FALLBACK_SWAPFILE_PATH"
cat > "$ZHOUKEER_SYSTEMD_DIR/fallback.swap" <<EOF
[Swap]
What=$MEMORY_FALLBACK_SWAPFILE_PATH
EOF
memory_restore_toolbox > "$TMP_ROOT/non-managed.output" || fail "保留非Renkit配置时不应失败"
[ -f "$MEMORY_FALLBACK_SWAPFILE_PATH" ] || fail "非Renkit独立 swap 被删除"
[ -f "$ZHOUKEER_SYSTEMD_DIR/fallback.swap" ] || fail "非Renkit swap 单元被删除"
grep -Fq '已保留' "$TMP_ROOT/non-managed.output" || fail "非Renkit配置缺少保留提示"

# swapoff 失败时必须保留文件和单元，并恢复开机启用状态。
rm -f "$MEMORY_FALLBACK_SWAPFILE_PATH" "$ZHOUKEER_SYSTEMD_DIR/fallback.swap"
prepare_managed_files
FALLBACK_ACTIVE=1
SWAPOFF_FAIL=1
if memory_restore_toolbox > "$TMP_ROOT/swapoff-fail.output" 2>&1; then
    fail "独立 swap 停用失败时仍报告撤销成功"
fi
[ -f "$MEMORY_FALLBACK_SWAPFILE_PATH" ] || fail "停用失败后删除了独立 swap"
[ -f "$ZHOUKEER_SYSTEMD_DIR/fallback.swap" ] || fail "停用失败后删除了独立 swap 单元"
grep -Fq 'enable fallback.swap' "$SYSTEMCTL_LOG" || fail "停用失败后未恢复单元启用状态"

# 已经 disabled 的Renkit单元无需重复 disable，仍应完成安全撤销。
SWAPOFF_FAIL=0
SYSTEMCTL_DISABLE_FAIL=1
prepare_managed_files
FALLBACK_UNIT_STATE=disabled
MAIN_UNIT_STATE=disabled
FALLBACK_ACTIVE=1
memory_restore_toolbox > "$TMP_ROOT/already-disabled.output" || \
    fail "已停用的Renkit单元导致撤销失败"
[ ! -e "$MEMORY_FALLBACK_SWAPFILE_PATH" ] || fail "已停用场景未删除Renkit独立 swap"
[ -f "$MEMORY_SWAPFILE_PATH" ] || fail "已停用场景删除了系统原 swap"

# 单元仍启用且 systemctl disable 真正失败时，必须显示原因并保留全部文件。
prepare_managed_files
FALLBACK_ACTIVE=1
SYSTEMCTL_DISABLE_FAIL=1
if memory_restore_toolbox > "$TMP_ROOT/disable-fail.output" 2>&1; then
    fail "开机单元停用失败时仍报告撤销成功"
fi
[ -f "$MEMORY_FALLBACK_SWAPFILE_PATH" ] || fail "停用单元失败后删除了独立 swap"
[ -f "$ZHOUKEER_SYSTEMD_DIR/fallback.swap" ] || fail "停用单元失败后删除了独立 swap 单元"
grep -Fq '无法停用Renkit swap 开机配置' "$TMP_ROOT/disable-fail.output" || \
    fail "开机单元停用失败仍没有明确提示"

echo "PASS: Renkit虚拟内存撤销、原 swap 保留、幂等与失败回滚模拟通过"
