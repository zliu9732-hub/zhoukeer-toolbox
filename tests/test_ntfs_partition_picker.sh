#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
# 只模拟枚举与对话框，不访问设备、不提权、不弹出真实窗口。
source "$PROJECT_ROOT/modules/ntfs_mount_repair.sh"
export DISPLAY=:renkit-test
SELECTED=1
MENU_CANCEL=0 CONFIRM_CANCEL=0 EMPTY=0 SINGLE=0 CHANGED=0 UNNAMED=0
fail() { echo "FAIL: $*" >&2; exit 1; }
toolbox_sudo() { fail '选择或取消阶段不应执行管理员操作'; }
lsblk() {
    case "$*" in
        '-rpn -o NAME,TYPE,FSTYPE')
            [ "$EMPTY" = 0 ] || return 0
            printf '/dev/mock-a1 part ntfs\n'
            [ "$SINGLE" = 0 ] || return 0
            printf '/dev/mock-a2 part ntfs\n/dev/mock-mounted part ntfs\n/dev/mock-linux part ext4\n'
            ;;
        '-dnro LABEL /dev/mock-a1') printf 'Game\n' ;;
        '-dnro LABEL /dev/mock-a2')
            if [ "$UNNAMED" = 1 ]; then printf '\n'; else printf '另一块游戏盘\n'; fi
            ;;
        '-dnro SIZE /dev/mock-a1') printf '260G\n' ;;
        '-dnro SIZE /dev/mock-a2') printf '512G\n' ;;
        *) fail "未模拟的磁盘查询：$*" ;;
    esac
}
ntfs_repair_device_valid() {
    [ ! -e "$TMP_ROOT/changed" ] || return 1
    case "$1" in /dev/mock-a1|/dev/mock-a2) return 0 ;; *) return 1 ;; esac
}
kdialog() {
    case "$*" in
        *--menu*)
            printf '%s\n' "$@" > "$TMP_ROOT/menu"
            [ "$MENU_CANCEL" = 0 ] || return 1
            printf '%s\n' "$SELECTED"
            ;;
        *--warningyesno*)
            printf '%s\n' "$@" > "$TMP_ROOT/confirm"
            [ "$CHANGED" = 0 ] || : > "$TMP_ROOT/changed"
            [ "$CONFIRM_CANCEL" = 0 ]
            ;;
        *) fail "未模拟的对话框：$*" ;;
    esac
}
reset_case() {
    rm -f "$TMP_ROOT/menu" "$TMP_ROOT/confirm" "$TMP_ROOT/changed"
    SELECTED=1 MENU_CANCEL=0 CONFIRM_CANCEL=0 EMPTY=0 SINGLE=0 CHANGED=0 UNNAMED=0
}
reset_case
device="$(ntfs_repair_select_device </dev/null)" || fail '点击分区失败'
[ "$device" = /dev/mock-a2 ] || fail '点击第二块盘却返回其他设备'
grep -Fq 'Game' "$TMP_ROOT/menu" || fail '列表没有显示盘名'
grep -Fq '512G' "$TMP_ROOT/menu" || fail '列表没有显示容量'
if grep -Eq 'mock-mounted|mock-linux' "$TMP_ROOT/menu"; then fail '列入已挂载或非 NTFS 设备'; fi
for expected in '另一块游戏盘' '512G' '/dev/mock-a2' '管理员权限' '文件系统元数据' '确认修复'; do
    grep -Fq "$expected" "$TMP_ROOT/confirm" || fail "确认页缺少所选盘或风险：$expected"
done
reset_case
UNNAMED=1
[ "$(ntfs_repair_select_device </dev/null)" = /dev/mock-a2 ] || fail '未命名盘无法选择'
grep -Fq '未命名游戏盘' "$TMP_ROOT/menu" || fail '空卷标显示为空白'
reset_case
SINGLE=1 SELECTED=0
[ "$(ntfs_repair_select_device </dev/null)" = /dev/mock-a1 ] || fail '单盘点选失败'
[ -f "$TMP_ROOT/menu" ] && [ -f "$TMP_ROOT/confirm" ] || fail '单盘未经点击就自动选中'
reset_case
MENU_CANCEL=1
if ntfs_repair_select_device </dev/null > "$TMP_ROOT/result" 2>/dev/null; then fail '关闭列表仍返回设备'; fi
[ ! -s "$TMP_ROOT/result" ] && [ ! -e "$TMP_ROOT/confirm" ] || fail '取消后仍继续确认'
reset_case
CONFIRM_CANCEL=1
if ntfs_repair_select_device </dev/null > "$TMP_ROOT/result" 2>/dev/null; then fail '拒绝确认仍返回设备'; fi
[ ! -s "$TMP_ROOT/result" ] || fail '拒绝确认仍允许操作设备'
for invalid in '' -1 999 '1+0' 'candidates[0]'; do
    reset_case
    SELECTED="$invalid"
    if ntfs_repair_select_device </dev/null >/dev/null 2>&1; then fail '接受了非法对话框结果'; fi
    [ ! -e "$TMP_ROOT/confirm" ] || fail '非法选择进入修复确认'
done
reset_case
CHANGED=1
if ntfs_repair_select_device </dev/null >/dev/null 2>&1; then fail '确认期间盘状态变化仍继续'; fi
reset_case
EMPTY=1
if ntfs_repair_select_device </dev/null >/dev/null 2>&1; then fail '没有候选仍返回成功'; fi
[ ! -e "$TMP_ROOT/menu" ] || fail '空列表仍弹出选择'
reset_case
DISPLAY= WAYLAND_DISPLAY=
if ntfs_repair_select_device </dev/null >/dev/null 2>&1; then fail '无桌面环境却要求手动输入'; fi
[ ! -e "$TMP_ROOT/menu" ] || fail '无桌面仍启动对话框'
if grep -Eq '/dev/tty|read -r answer' "$PROJECT_ROOT/modules/ntfs_mount_repair.sh"; then
    fail '分区选择仍要求手工输入'
fi
echo 'PASS: 游戏盘点选、盘名容量、二次确认、取消、非法结果与状态变化模拟通过'
