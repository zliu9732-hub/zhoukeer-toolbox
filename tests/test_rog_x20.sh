#!/bin/bash
set -euo pipefail
# No actual OS/system calls: functions below simulate device checks and actions.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
source "$PROJECT_ROOT/modules/rog_x20_fix.sh"
LOG_FILE="$TMP_ROOT/log" EVENTS="$TMP_ROOT/events"
fail() { echo "FAIL: $*" >&2; exit 1; }
MOCK_FAIL='' MOCK_GATE=1 MOCK_OS=Linux MOCK_UID=1000
uname() { echo "$MOCK_OS"; }
id() { echo "$MOCK_UID"; }
require_steamos() { [ "$MOCK_GATE" = 1 ]; }
rog_x20_verify() { echo verify >> "$EVENTS"; }
log() { :; }
python3() {
    [ "${@: -1}" = plan ] || fail '非只读查询'
    echo plan >> "$EVENTS"
    [ "$MOCK_FAIL" != plan ]
}
toolbox_sudo() {
    [ "$1" = python3 ] || fail '未模拟的管理员动作'
    local action="${@: -1}"
    case "$action" in check|install|uninstall|status) ;; *) fail '未知安装动作' ;; esac
    echo "$action" >> "$EVENTS"
    [ "$MOCK_FAIL" != "$action" ]
}
bash() {
    [ "$*" = "$PROJECT_ROOT/modules/plugin_store.sh ensure-store" ] || fail '商城被强制重装'
    echo store >> "$EVENTS"
    [ "$MOCK_FAIL" != store ]
}
export ZHOUKEER_AUTO_CONFIRM=1
: > "$EVENTS"
rog_x20_install > "$TMP_ROOT/output" || fail '修复未成功'
[ "$(tail -n 3 "$EVENTS")" = $'check\nstore\ninstall' ] || fail '商城或修复先于兼容性检查'
grep -Fq '手动重启' "$TMP_ROOT/output" || fail '没有手动重启提示'
for stage in plan check store install; do
    : > "$EVENTS";MOCK_FAIL="$stage"
    if rog_x20_install > "$TMP_ROOT/error"; then fail "$stage 失败被吞掉"; fi
    ! grep -Fq '修复已部署' "$TMP_ROOT/error" || fail '失败后仍显示完成'
    case "$stage" in plan|check) ! grep -Eq '^(store|install)$' "$EVENTS" || fail '检查失败仍改动系统' ;; esac
done
MOCK_FAIL=''
for state in consent os device root; do
    : > "$EVENTS";MOCK_GATE=1 MOCK_OS=Linux MOCK_UID=1000 ZHOUKEER_AUTO_CONFIRM=1
    case "$state" in consent) ZHOUKEER_AUTO_CONFIRM=0 ;; os) MOCK_OS=Darwin ;; device) MOCK_GATE=0 ;; root) MOCK_UID=0 ;; esac
    if rog_x20_install >/dev/null; then fail "$state 未拦截"; fi
    ! grep -Eq '^(check|store|install)$' "$EVENTS" || fail '限制或确认未通过仍执行'
done
MOCK_GATE=1 MOCK_OS=Linux MOCK_UID=1000 ZHOUKEER_AUTO_CONFIRM=1
: > "$EVENTS"
rog_x20_restore >/dev/null || fail '撤销入口错误'
grep -Fxq uninstall "$EVENTS" || fail '未调用原备份恢复'
if ZHOUKEER_AUTO_CONFIRM=0 rog_x20_restore >/dev/null; then fail '撤销无需确认'; fi
echo 'PASS: checks before store/install, existing auth routing, consent, device gate and failure propagation'
