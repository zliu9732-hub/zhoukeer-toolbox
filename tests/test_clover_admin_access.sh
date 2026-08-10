#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
CALLS="$TMP_ROOT/calls"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/clover_boot.sh"

id() {
    [ "${1:-}" = "-u" ] && { printf '%s\n' 1000; return 0; }
    command id "$@"
}
load_toolbox_password() { return 1; }
detect_platform() { IS_STEAMOS=0; IS_BAZZITE=1; }
toolbox_sudo() {
    [ "${1:-}" = "true" ] || fail "管理员准备阶段执行了非预期命令：$*"
}
bash() {
    [ "${1:-}" = "$PROJECT_ROOT/modules/password.sh" ] || return 1
    [ "${2:-}" = "import" ] || return 1
    printf '%s\n' "password-import" >> "$CALLS"
}

clover_prepare_admin_access || fail "Bazzite 缺少密码记录时没有进入录入流程"
grep -Fxq 'password-import' "$CALLS" || fail "没有调用现有管理员密码录入模块"

echo "PASS: Bazzite Clover 会在访问受保护 EFI 前录入并验证管理员密码"
