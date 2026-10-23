#!/bin/bash
set -euo pipefail
# Passwords and sudo are synthetic. Only tiny private record files are written.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export HOME="$TMP_ROOT/home" ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
export ZHOUKEER_PASSWORD_RECORD="$HOME/Desktop/管理员密码.txt"
mkdir -p "$HOME/Desktop"
source "$PROJECT_ROOT/modules/password.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
is_linux() { return 0; }
require_command() { return 0; }
log() { printf '%s\n' "$*" >> "$TMP_ROOT/log"; }
STATE="$TMP_ROOT/cache" CALLS="$TMP_ROOT/calls"
EXPECTED=1234
sudo() {
    case "$*" in
        -k) echo 0 > "$STATE" ;;
        '-n true') [ "$(cat "$STATE")" = 1 ] ;;
        '-S -p  -v')
            local value
            IFS= read -r value || return 1
            [ "$value" = "$EXPECTED" ] || return 1
            echo 1 > "$STATE"
            ;;
        '-n -- fixture-install')
            [ "$(cat "$STATE")" = 1 ] || return 1
            echo installed >> "$CALLS"
            ;;
        *) fail '未模拟的 sudo 命令' ;;
    esac
}
echo 0 > "$STATE"; : > "$CALLS"
prepare_startup_password </dev/null > "$TMP_ROOT/default-output" || fail '1234 仍需录入'
! grep -Fq '请输入' "$TMP_ROOT/default-output" || fail '默认密码仍提示输入'
load_toolbox_password && [ "$TOOLBOX_PASSWORD" = 1234 ] || fail '默认密码未供安装使用'
[ "$(cat "$STATE")" = 0 ] || fail '默认验证未清理缓存'
toolbox_sudo fixture-install </dev/null || fail '默认密码安装自动验证失败'
# A stale record is replaced through the original safe writer, not trusted.
EXPECTED='synthetic different password'
prepare_startup_password <<< "$EXPECTED" > "$TMP_ROOT/custom-output" || fail '现有密码录入失败'
grep -Fq '请输入当前管理员密码' "$TMP_ROOT/custom-output" || fail '非默认密码未提示'
load_toolbox_password && [ "$TOOLBOX_PASSWORD" = "$EXPECTED" ] || fail '安装记录未更新'
toolbox_sudo fixture-install </dev/null || fail '自定义密码安装重复询问'
cp "$PASSWORD_RECORD" "$TMP_ROOT/previous"
if prepare_startup_password <<< wrong > "$TMP_ROOT/wrong-output"; then fail '接受错误密码'; fi
cmp -s "$PASSWORD_RECORD" "$TMP_ROOT/previous" || fail '错误密码覆盖记录'
if prepare_startup_password </dev/null > "$TMP_ROOT/eof-output"; then fail '无输入绕过录入'; fi
cmp -s "$PASSWORD_RECORD" "$TMP_ROOT/previous" || fail '取消损坏记录'
# Returning to 1234 must repair the old custom record without reading input.
EXPECTED=1234
prepare_startup_password </dev/null > "$TMP_ROOT/reset-output" || fail '原记录阻止默认密码跳过'
toolbox_sudo fixture-install </dev/null || fail '更新记录后无法自动安装'
[ "$(grep -c installed "$CALLS")" -eq 3 ] || fail '安装调用数量错误'
[ "$(cat "$STATE")" = 0 ] || fail '安装后未清理认证缓存'
! grep -Eq '1234|synthetic different password|wrong' "$TMP_ROOT/log" || fail '密码进入日志'
for f in main.sh core/gui.sh; do
    grep -Fq 'modules/password.sh" startup' "$PROJECT_ROOT/$f" || fail '入口未接入启动判断'
done
# Startup never calls passwd or changes the established installation helper.
body="$(sed -n '/^prepare_startup_password()/,/^}/p' "$PROJECT_ROOT/modules/password.sh")"
! grep -Eq '(^|[[:space:]])passwd([[:space:]]|$)|set_system_password' <<< "$body" || fail '启动修改了系统密码'
echo 'PASS: 默认密码跳过、自定义密码录入、错误/取消保留记录和安装自动验证'
