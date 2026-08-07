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
ZHOUKEER_TEST_MODE=1

# shellcheck disable=SC1090
source "$MODULE"

# SteamOS 的 swap 通常是 root:root 0600。普通用户无法用 blkid 读取时，
# 完整性检测必须通过已有管理员权限识别，避免重复创建和替换正常 swap。
ROOT_SWAP="$TMP_ROOT/root-swapfile"
: > "$ROOT_SWAP"
memory_file_size_bytes() { printf '%s\n' $((16 * 1024 * 1024 * 1024)); }
blkid() { return 1; }
toolbox_sudo() {
    case "${1:-}" in
        blkid) printf 'swap\n' ;;
        *) "$@" ;;
    esac
}
memory_swapfile_is_complete "$ROOT_SWAP" 16 || \
    fail "root:root 0600 swap 未通过管理员权限完成完整性检测"

[ "$(recommended_swap_gib)" = "16" ] || fail "16GB Steam Deck 未推荐 16GB 磁盘 swap"
printf 'MemTotal:       4194304 kB\n' > "$MEMINFO"
[ "$(recommended_swap_gib)" = "8" ] || fail "小内存设备未使用 8GB 下限"
printf 'MemTotal:       33554432 kB\n' > "$MEMINFO"
[ "$(recommended_swap_gib)" = "16" ] || fail "大内存设备未使用 16GB 上限"
printf 'MemTotal:       16384000 kB\n' > "$MEMINFO"

DIRECTORY_TARGET="$TMP_ROOT/not-a-unit-file"
mkdir -p "$DIRECTORY_TARGET"
toolbox_sudo() { "$@"; }
if memory_config_target_is_safe "$DIRECTORY_TARGET" > "$TMP_ROOT/directory-target-output"; then
    fail "目录被错误地当成了可写配置文件"
fi
grep -Fq '配置路径不是普通文件' "$TMP_ROOT/directory-target-output" || \
    fail "目录配置的安全错误提示缺失"

# 系统原 swap 在两次移动尝试后仍受保护时，创建流程必须把已成功启用的
# Renkit独立 swap 视为成功降级，不能把前一次 mv 失败带回主菜单。
(
    PROTECTED_MAIN="$TMP_ROOT/protected-swapfile"
    PROTECTED_FALLBACK="$TMP_ROOT/protected-fallback-swapfile"
    printf 'protected swap\n' > "$PROTECTED_MAIN"
    MEMORY_SWAPFILE_PATH="$PROTECTED_MAIN"
    MEMORY_FALLBACK_SWAPFILE_PATH="$PROTECTED_FALLBACK"
    MEMORY_MIN_FREE_GIB=1
    memory_swap_is_active() { return 1; }
    memory_clear_immutable_attribute() { return 0; }
    memory_move_swapfile_after_forced_immutable_clear() { return 1; }
    df() { printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 99999999 1 99999998 1%% /\n'; }
    toolbox_sudo() {
        case "${1:-}" in
            fallocate) : > "${@: -1}" ;;
            mkswap|chmod) return 0 ;;
            mv)
                if [ "${2:-}" = "--" ] && [ "${3:-}" = "$PROTECTED_MAIN" ]; then
                    return 1
                fi
                shift
                command mv "$@"
                ;;
            swapon) return 0 ;;
            *) "$@" ;;
        esac
    }
    if ! memory_create_swapfile 8 > "$TMP_ROOT/protected-fallback.output"; then
        fail "系统原 swap 受保护时，成功启用独立 swap 后仍返回失败"
    fi
    [ "$MEMORY_SWAPFILE_PATH" = "$PROTECTED_FALLBACK" ] || \
        fail "成功降级后没有切换到Renkit独立 swap 路径"
    grep -Fq '独立 swap 已安全启用，继续配置' "$TMP_ROOT/protected-fallback.output" || \
        fail "成功降级后没有说明将继续完成其余配置"
)

CREATED="$TMP_ROOT/created"
ACTIVE="$TMP_ROOT/active"
SYSTEMCTL_LOG="$TMP_ROOT/systemctl.log"
detect_platform() { IS_STEAMOS=1; }
id() { [ "${1:-}" = "-u" ] && printf '1000\n'; }
require_command() { return 0; }
SAFE_TARGETS="$TMP_ROOT/safe-targets"
memory_config_target_is_safe() {
    printf '%s\n' "$1" >> "$SAFE_TARGETS"
    [ "$1" != "$ZHOUKEER_SYSTEMD_DIR/" ] || return 1
    return 0
}
memory_swap_unit_name() { printf 'test-swap.swap\n'; }
memory_swap_unit_name_for_path() { printf 'fallback-test-swap.swap\n'; }
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
grep -Fxq "$ZHOUKEER_SYSTEMD_DIR/test-swap.swap" "$SAFE_TARGETS" || \
    fail "swap systemd 单元路径未在安全检查前生成"
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

# 部分 SteamOS 文件系统上 lsattr 读取可能失效；首次移动失败后应只对旧
# swap 再尝试 chattr -i，并在成功备份时记录需要在回滚时恢复保护。
RETRY_SOURCE="$TMP_ROOT/retry-swapfile"
RETRY_BACKUP="$TMP_ROOT/retry-swapfile.backup"
printf 'old swap\n' > "$RETRY_SOURCE"
MEMORY_SWAPFILE_WAS_IMMUTABLE=0
memory_move_swapfile_after_forced_immutable_clear "$RETRY_SOURCE" "$RETRY_BACKUP" || \
    fail "不可变保护回退移动失败"
[ ! -e "$RETRY_SOURCE" ] || fail "旧 swap 未移动到备份位置"
[ -f "$RETRY_BACKUP" ] || fail "旧 swap 备份缺失"
[ "$MEMORY_SWAPFILE_WAS_IMMUTABLE" -eq 1 ] || fail "回退移动未记录不可变保护"

# 系统 swap 无法移动且Renkit备用路径残留旧文件时，应先原子备份旧备用
# 文件，再启用新文件；失败不能覆盖或丢失旧内容。
FALLBACK_NEW="$TMP_ROOT/fallback-new"
MEMORY_FALLBACK_SWAPFILE_PATH="$TMP_ROOT/.zhoukeer-swapfile"
printf 'new swap\n' > "$FALLBACK_NEW"
printf 'stale fallback\n' > "$MEMORY_FALLBACK_SWAPFILE_PATH"
FALLBACK_SWAP_LOG="$TMP_ROOT/fallback-swap.log"
memory_swap_is_active() { return 1; }
memory_clear_immutable_attribute() { MEMORY_SWAPFILE_WAS_IMMUTABLE=0; return 0; }
toolbox_sudo() {
    case "${1:-}" in
        swapon) printf '%s\n' "$*" >> "$FALLBACK_SWAP_LOG"; return 0 ;;
        *) "$@" ;;
    esac
}
memory_activate_fallback_swapfile "$FALLBACK_NEW" || fail "残留备用 swap 存在时未能安全替换"
[ "$(cat "$MEMORY_FALLBACK_SWAPFILE_PATH")" = 'new swap' ] || fail "新备用 swap 未原子替换到目标路径"
[ ! -e "${MEMORY_FALLBACK_SWAPFILE_PATH}.backup.$$" ] || fail "成功后仍残留备用 swap 临时备份"
grep -Fq 'swapon --priority 10' "$FALLBACK_SWAP_LOG" || fail "新备用 swap 未启用"

echo "PASS: zram 与磁盘 swap 一键推荐值、配置和后台启用模拟通过"
