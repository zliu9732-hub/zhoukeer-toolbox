#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
CALLS="$TEST_ROOT/calls"
: > "$CALLS"
export ZHOUKEER_TEST_MODE=1
# 只 source 函数并覆盖所有系统命令；绝不执行真实安装、联网或服务操作。
# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/inputplumber_update.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
log() { :; }
MOCK_ACTIVE=1
MOCK_ENABLED=1
MOCK_INSTALLED=1
MOCK_VERSION=0.70.0-1
MOCK_AVAILABLE=0.79.2-1
MOCK_PENDING='inputplumber 0.70.0-1 -> 0.79.2-1'
MOCK_INSTALL_FAIL=0
MOCK_RESTART_FAIL=0
MOCK_READONLY=enabled
uname() { [ "$1" = -s ] && echo Linux; }
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$CALLS"
    case "$1" in
        is-active) [ "$MOCK_ACTIVE" -eq 1 ] ;;
        is-enabled) [ "$MOCK_ENABLED" -eq 1 ] ;;
        restart) [ "$MOCK_RESTART_FAIL" -eq 0 ] && MOCK_ACTIVE=1 ;;
    esac
}
pacman() {
    printf 'pacman %s\n' "$*" >> "$CALLS"
    case "$1" in
        -Q) [ "$MOCK_INSTALLED" -eq 1 ] && echo "inputplumber $MOCK_VERSION" ;;
        -Si) printf 'Name : inputplumber\nVersion : %s\n' "$MOCK_AVAILABLE" ;;
        -Qu) printf '%s\n' "$MOCK_PENDING" ;;
        -S) [ "$MOCK_INSTALL_FAIL" -eq 0 ] && MOCK_VERSION="$MOCK_AVAILABLE" ;;
    esac
}
vercmp() {
    if [ "$1" = "$2" ]; then echo 0
    elif [ "$1" = "$MOCK_AVAILABLE" ]; then echo 1
    else echo -1; fi
}
steamos-readonly() {
    printf 'steamos-readonly %s\n' "$*" >> "$CALLS"
    case "$1" in
        status) echo "$MOCK_READONLY" ;;
        disable) MOCK_READONLY=disabled ;;
        enable) MOCK_READONLY=enabled ;;
    esac
}
toolbox_sudo() { printf 'sudo %s\n' "$*" >> "$CALLS"; "$@"; }
journalctl() { echo '模拟服务错误'; }
command() {
    if [ "$1" = -v ]; then
        case "$2" in
            pacman|vercmp|systemctl|steamos-readonly|journalctl) return 0 ;;
            dpkg-query|rpm|dnf) return 1 ;;
        esac
    fi
    builtin command "$@"
}

MOCK_ACTIVE=0 MOCK_ENABLED=0
ipu_update > "$TEST_ROOT/skip" || fail '停用服务应跳过'
! grep -Fq 'pacman -S --' "$CALLS" || fail '停用服务却安装了包'
MOCK_ACTIVE=1 MOCK_ENABLED=1
MOCK_INSTALLED=0
ipu_update > "$TEST_ROOT/absent" || fail '未安装应跳过'
! grep -Fq 'pacman -S --' "$CALLS" || fail '未安装却安装了包'
MOCK_INSTALLED=1
MOCK_AVAILABLE="$MOCK_VERSION"
ipu_update > "$TEST_ROOT/current" || fail '最新版本检查失败'
! grep -Fq 'pacman -S --' "$CALLS" || fail '最新版本却被更新'
MOCK_AVAILABLE=0.79.2-1
MOCK_PENDING='inputplumber 0.70.0-1 -> 0.79.2-1
linux 1 -> 2'
ipu_update > "$TEST_ROOT/partial" || fail '其他包待更新应安全跳过'
! grep -Fq 'pacman -S --' "$CALLS" || fail '发生了 pacman 部分升级'
MOCK_PENDING='inputplumber 0.70.0-1 -> 0.79.2-1'
ipu_update > "$TEST_ROOT/success" || fail '模拟升级失败'
grep -Fq 'pacman -S --needed --noconfirm inputplumber' "$CALLS" || fail '未调用软件包管理器'
grep -Fq 'systemctl restart inputplumber.service' "$CALLS" || fail '未重启服务'
[ "$MOCK_READONLY" = enabled ] || fail '只读保护未恢复'
MOCK_AVAILABLE=0.80.0-1
MOCK_PENDING='inputplumber 0.79.2-1 -> 0.80.0-1'
MOCK_INSTALL_FAIL=1
if ipu_update > "$TEST_ROOT/install-fail"; then fail '包更新失败被报告为成功'; fi
[ "$MOCK_READONLY" = enabled ] || fail '失败后只读保护未恢复'
MOCK_INSTALL_FAIL=0 MOCK_RESTART_FAIL=1
if ipu_update > "$TEST_ROOT/restart-fail"; then fail '服务失败被报告为成功'; fi
grep -Fq '模拟服务错误' "$TEST_ROOT/restart-fail" || fail '缺少 journal 摘要'
if rg -n 'DMI|ONEXPLAYER|OXP|APEX|\.yaml|github.com|tar -x' "$PROJECT_ROOT/modules/inputplumber_update.sh" | rg -v '不会写入设备 YAML'; then
    fail '更新模块包含机型限制、配置写入或独立下载路径'
fi
echo 'PASS: InputPlumber 通用软件包更新、跳过与故障模拟'
