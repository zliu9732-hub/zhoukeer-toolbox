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

MEMINFO="$TMP_ROOT/meminfo"
printf 'MemTotal:       16384000 kB\n' > "$MEMINFO"
ZHOUKEER_MEMINFO="$MEMINFO"
ZHOUKEER_SWAPFILE_PATH="$TMP_ROOT/swapfile"
ZHOUKEER_ZRAM_CONFIG="$TMP_ROOT/etc/zram.conf"
ZHOUKEER_MEMORY_SYSCTL_CONFIG="$TMP_ROOT/etc/memory.conf"
ZHOUKEER_SYSTEMD_DIR="$TMP_ROOT/systemd"
ZHOUKEER_AUTO_CONFIRM=1

# shellcheck disable=SC1090
source "$MODULE"

[ "$(recommended_swap_gib)" = "16" ] || fail "16GB Steam Deck 未推荐 16GB 磁盘 swap"
printf 'MemTotal:       4194304 kB\n' > "$MEMINFO"
[ "$(recommended_swap_gib)" = "8" ] || fail "小内存设备未使用 8GB 下限"
printf 'MemTotal:       33554432 kB\n' > "$MEMINFO"
[ "$(recommended_swap_gib)" = "16" ] || fail "大内存设备未使用 16GB 上限"
printf 'MemTotal:       16384000 kB\n' > "$MEMINFO"

CREATED="$TMP_ROOT/created"
ACTIVE="$TMP_ROOT/active"
SYSTEMCTL_LOG="$TMP_ROOT/systemctl.log"
detect_platform() { IS_STEAMOS=1; }
id() { [ "${1:-}" = "-u" ] && printf '1000\n'; }
require_command() { return 0; }
memory_config_target_is_safe() { return 0; }
memory_swap_unit_name() { printf 'test-swap.swap\n'; }
memory_swapfile_is_complete() { return 1; }
memory_create_swapfile() {
    printf '%s\n' "$1" > "$CREATED"
    : > "$ACTIVE"
}
memory_swap_is_active() { [ -f "$ACTIVE" ]; }
memory_write_config() {
    mkdir -p "$(dirname "$1")"
    cp "$2" "$1"
}
toolbox_sudo() {
    case "${1:-}" in
        true) return 0 ;;
        sysctl) return 0 ;;
        systemctl) printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"; return 0 ;;
        *) "$@" ;;
    esac
}

memory_optimize > "$TMP_ROOT/output"
[ "$(cat "$CREATED")" = "16" ] || fail "一键优化未同时创建推荐磁盘 swap"
grep -Fq 'zram-size = ram / 2' "$ZHOUKEER_ZRAM_CONFIG" || fail "zram 未设置为内存一半"
grep -Fq 'swap-priority = 100' "$ZHOUKEER_ZRAM_CONFIG" || fail "zram 优先级错误"
grep -Fq 'vm.swappiness = 1' "$ZHOUKEER_MEMORY_SYSCTL_CONFIG" || fail "swappiness 配置错误"
grep -Fq 'Priority=10' "$ZHOUKEER_SYSTEMD_DIR/test-swap.swap" || fail "磁盘 swap 优先级错误"
grep -Fq 'enable test-swap.swap' "$SYSTEMCTL_LOG" || fail "磁盘 swap 未设置开机启用"
grep -Fq '最佳组合已设置' "$TMP_ROOT/output" || fail "优化完成提示缺失"

# SteamOS 的旧 swap 可能带 immutable 属性；替换前应临时解除并能在回滚时恢复。
FAKE_BIN="$TMP_ROOT/bin"
ATTR_LOG="$TMP_ROOT/attr.log"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/lsattr" <<'SCRIPT'
#!/bin/bash
printf '%s %s\n' '----i--------' "${@: -1}"
SCRIPT
cat > "$FAKE_BIN/chattr" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >> "${ATTR_LOG:?}"
SCRIPT
chmod +x "$FAKE_BIN/lsattr" "$FAKE_BIN/chattr"
export ATTR_LOG
PATH="$FAKE_BIN:$PATH"
memory_clear_immutable_attribute "$ZHOUKEER_SWAPFILE_PATH" || fail "未解除旧 swap 的不可变属性"
[ "$MEMORY_SWAPFILE_WAS_IMMUTABLE" -eq 1 ] || fail "未记录旧 swap 的不可变状态"
toolbox_sudo() {
    case "${1:-}" in
        test) return 0 ;;
        *) "$@" ;;
    esac
}
memory_restore_immutable_attribute "$ZHOUKEER_SWAPFILE_PATH" || fail "未恢复旧 swap 的不可变属性"
grep -Fq -- '-i --' "$ATTR_LOG" || fail "没有执行 chattr -i"
grep -Fq -- '+i --' "$ATTR_LOG" || fail "没有执行 chattr +i"

echo "PASS: zram 与磁盘 swap 一键推荐值、配置和后台启用模拟通过"
