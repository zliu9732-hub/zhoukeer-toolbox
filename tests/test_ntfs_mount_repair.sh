#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
# 所有提权、安装、磁盘、平台检查均为函数桩，只操作此临时目录。
source "$PROJECT_ROOT/modules/ntfs_mount_repair.sh"
LOG_FILE="$TMP_ROOT/log"
CALLS="$TMP_ROOT/calls"
SHARED_DRIVE_LINK="$TMP_ROOT/互通盘"
TARGET="$TMP_ROOT/mount"
FAIL_AT=none
WINDOWS=0
READONLY=0
CANCEL=0
require_steamos() { return 0; }
ensure_runtime_dirs() { :; }
require_command() { return 0; }
ntfs_repair_select_device() { [ "$CANCEL" = 0 ] && printf '/dev/mock-game\n'; }
ntfs_repair_device_valid() { [ "$1" = /dev/mock-game ]; }
ntfs_repair_mount_target() { printf '%s\n' "$TARGET"; }
lsblk() { [ "$*" = '-dnro UUID /dev/mock-game' ] && printf 'ABC-123\n'; }
findmnt() {
    [ -f "$TMP_ROOT/mounted" ] || return 1
    case "$*" in
        *'-o OPTIONS'*) if [ "$READONLY" = 1 ]; then echo ro; else echo rw; fi ;;
        *) printf '%s\n' "$TARGET" ;;
    esac
}
ntfsfix() { :; }
ntfs-3g() { :; }
steamos-readonly() { printf '%s\n' "${ORIGINAL_STATE:-enabled}"; }
pacman() {
    [ "${1:-}" != -Si ] || [ "${CATALOG_SPLIT:-1}" = 1 ]
}
toolbox_sudo() {
    printf '%s\n' "$*" >> "$CALLS"
    case "$1" in
        ntfs-3g)
            [ "$FAIL_AT" != probe ] || return 1
            printf '%s\n' "$5" > "$TMP_ROOT/probe"
            if [ "$WINDOWS" = 1 ]; then mkdir "$5/wInDoWs"; fi
            ;;
        umount)
            [ "$FAIL_AT" != unmount ] || return 1
            if [ -d "$2/wInDoWs" ]; then rmdir "$2/wInDoWs"; fi
            ;;
        ntfsfix) [ "$FAIL_AT" != repair ] ;;
        mount)
            [ "$FAIL_AT" != mount ] || return 1
            : > "$TMP_ROOT/mounted"
            ;;
        mkdir) [ "$4" = "$TARGET" ] && mkdir -p "$TARGET" ;;
        rmdir) [ "$3" = "$TARGET" ] && rmdir "$TARGET" ;;
        steamos-readonly)
            [ "$FAIL_AT" != relock ] || [ "$2" != enable ]
            ;;
        pacman)
            [ "$FAIL_AT" != install ] || return 1
            : > "$TMP_ROOT/installed"
            ;;
        *) echo "unexpected administrator command: $*" >&2; return 1 ;;
    esac
}
reset_case() {
    rm -f "$TMP_ROOT/mounted" "$TMP_ROOT/probe" "$TMP_ROOT/installed" "$CALLS" "$SHARED_DRIVE_LINK"
    [ ! -d "$TARGET" ] || rmdir "$TARGET"
    FAIL_AT=none WINDOWS=0 READONLY=0 CANCEL=0
}
fail() { echo "FAIL: $*" >&2; exit 1; }
reset_case
repair_ntfs_mount > "$TMP_ROOT/result" || fail '正常修复失败'
[ -L "$SHARED_DRIVE_LINK" ] || fail '未创建访问入口'
grep -Fq 'mount -t ntfs-3g -o' "$CALLS" || fail '未使用已验证的驱动'
grep -Fq 'norecover /dev/mock-game' "$CALLS" || fail '未禁止强行恢复挂载'
grep -Fq '挂载修复完成' "$LOG_FILE" || fail '缺少成功日志'
for stage in probe unmount repair mount; do
    reset_case
    FAIL_AT="$stage"
    if repair_ntfs_mount > "$TMP_ROOT/result" 2>&1; then fail "$stage 失败仍返回成功"; fi
    case "$stage" in
        probe|unmount) if grep -q '^ntfsfix ' "$CALLS"; then fail '检查未通过却修改分区'; fi ;;
        repair) if grep -q '^mount ' "$CALLS"; then fail '修复失败仍尝试挂载'; fi ;;
    esac
    if grep -q '游戏盘已恢复挂载' "$TMP_ROOT/result"; then fail '失败却报告完成'; fi
    if [ -f "$TMP_ROOT/probe" ]; then rmdir "$(cat "$TMP_ROOT/probe")" 2>/dev/null || true; fi
done
# 清理失败场景的模拟只读检查目录（不是实际挂载）。
if [ -f "$TMP_ROOT/probe" ]; then rmdir "$(cat "$TMP_ROOT/probe")" 2>/dev/null || true; fi
reset_case
WINDOWS=1
if repair_ntfs_mount > "$TMP_ROOT/result"; then fail '未拒绝 Windows 分区'; fi
if grep -q '^ntfsfix ' "$CALLS"; then fail '修改了 Windows 系统分区'; fi
reset_case
READONLY=1
if repair_ntfs_mount > "$TMP_ROOT/result"; then fail '只读挂载误报可写修复完成'; fi
reset_case
CANCEL=1
if repair_ntfs_mount > "$TMP_ROOT/result"; then fail '取消后仍继续'; fi
[ ! -e "$CALLS" ] || fail '取消后执行了管理员操作'

# 模拟缺少工具以及新版拆包；不执行真实 command/pacman/sudo。
command() {
    if [ "${1:-}" = -v ]; then
        case "${2:-}" in ntfsfix|ntfs-3g) [ -f "$TMP_ROOT/installed" ]; return ;; esac
    fi
    builtin command "$@"
}
reset_case
ntfs_repair_install_tools > "$TMP_ROOT/result" || fail '拆包后的组件安装失败'
grep -Fq 'pacman -S --noconfirm ntfs-3g ntfsprogs' "$CALLS" || fail '缺少 ntfsprogs'
[ "$(tail -n 1 "$CALLS")" = 'steamos-readonly enable' ] || fail '安装后未恢复保护'
reset_case
FAIL_AT=install
if ntfs_repair_install_tools > "$TMP_ROOT/result"; then fail '安装失败仍成功'; fi
[ "$(tail -n 1 "$CALLS")" = 'steamos-readonly enable' ] || fail '安装失败未恢复保护'
reset_case
FAIL_AT=relock
if ntfs_repair_install_tools > "$TMP_ROOT/result" 2>&1; then fail '恢复保护失败仍成功'; fi
reset_case
ORIGINAL_STATE=disabled
ntfs_repair_install_tools > "$TMP_ROOT/result" || fail '原先可写状态安装失败'
if grep -q '^steamos-readonly ' "$CALLS"; then fail '改变了原本可写的系统状态'; fi
reset_case
ORIGINAL_STATE=enabled
CATALOG_SPLIT=0
ntfs_repair_install_tools > "$TMP_ROOT/result" || fail '未拆包的旧仓库安装失败'
grep -Fxq 'pacman -S --noconfirm ntfs-3g' "$CALLS" || fail '旧仓库尝试安装不存在的拆分包'
echo 'PASS: 游戏盘挂载修复、驱动切换、Windows 保护、失败退出与组件安装恢复模拟通过'
