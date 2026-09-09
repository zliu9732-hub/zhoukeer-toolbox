#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/inputplumber_update.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

INSTALL_ROOT="$TEST_ROOT/root"
PAYLOAD_ROOT="$TEST_ROOT/payload/inputplumber"
FIXTURE_ARCHIVE="$TEST_ROOT/inputplumber-x86_64.tar.gz"
CALLS="$TEST_ROOT/calls"
LOG_FILE="$TEST_ROOT/toolbox.log"
PRODUCT_FILE="$TEST_ROOT/product-name"
VENDOR_FILE="$TEST_ROOT/sys-vendor"

mkdir -p -- \
    "$INSTALL_ROOT/usr/bin" \
    "$INSTALL_ROOT/usr/share/inputplumber/devices" \
    "$PAYLOAD_ROOT/usr/bin" \
    "$PAYLOAD_ROOT/usr/lib/systemd/system" \
    "$PAYLOAD_ROOT/usr/lib/udev/hwdb.d" \
    "$PAYLOAD_ROOT/usr/lib/udev/rules.d" \
    "$PAYLOAD_ROOT/usr/share/dbus-1/system.d" \
    "$PAYLOAD_ROOT/usr/share/polkit-1/actions" \
    "$PAYLOAD_ROOT/usr/share/polkit-1/rules.d" \
    "$PAYLOAD_ROOT/usr/share/inputplumber/devices" \
    "$PAYLOAD_ROOT/usr/share/inputplumber/capability_maps" \
    "$TEST_ROOT/home" "$TEST_ROOT/state"

printf '#!/bin/sh\nprintf "inputplumber 0.70.0\\n"\n' > "$INSTALL_ROOT/usr/bin/inputplumber"
chmod +x "$INSTALL_ROOT/usr/bin/inputplumber"
printf 'old-profile\n' > "$INSTALL_ROOT/usr/share/inputplumber/devices/old.yaml"

printf '#!/bin/sh\nprintf "inputplumber 0.79.2\\n"\n' > "$PAYLOAD_ROOT/usr/bin/inputplumber"
chmod +x "$PAYLOAD_ROOT/usr/bin/inputplumber"
printf '[Service]\nExecStart=/usr/bin/inputplumber\n' > "$PAYLOAD_ROOT/usr/lib/systemd/system/inputplumber.service"
printf 'fixture\n' > "$PAYLOAD_ROOT/usr/lib/udev/hwdb.d/59-inputplumber.hwdb"
printf 'fixture\n' > "$PAYLOAD_ROOT/usr/lib/udev/rules.d/90-inputplumber-autostart.rules"
printf 'fixture\n' > "$PAYLOAD_ROOT/usr/share/dbus-1/system.d/org.shadowblip.InputPlumber.conf"
printf 'fixture\n' > "$PAYLOAD_ROOT/usr/share/polkit-1/actions/org.shadowblip.InputPlumber.policy"
printf 'fixture\n' > "$PAYLOAD_ROOT/usr/share/polkit-1/rules.d/org.shadowblip.InputPlumber.rules"
for file in 50-onexplayer_mini_pro.yaml 50-onexplayer_2.yaml; do
    printf 'version: 1\n' > "$PAYLOAD_ROOT/usr/share/inputplumber/devices/$file"
done
for file in onexplayer_type3.yaml onexplayer_type4.yaml; do
    printf 'version: 1\n' > "$PAYLOAD_ROOT/usr/share/inputplumber/capability_maps/$file"
done
tar -czf "$FIXTURE_ARCHIVE" -C "$TEST_ROOT/payload" inputplumber
FIXTURE_SHA256="$(sha256sum "$FIXTURE_ARCHIVE" | awk '{print $1}')"

printf 'ONEXPLAYER 2 PRO ARP23P\n' > "$PRODUCT_FILE"
printf 'ONE-NETBOOK TECHNOLOGY CO., LTD.\n' > "$VENDOR_FILE"
: > "$CALLS"
: > "$LOG_FILE"

export HOME="$TEST_ROOT/home"
export XDG_STATE_HOME="$TEST_ROOT/state"
export ZHOUKEER_TEST_MODE=1
export ZHOUKEER_AUTO_CONFIRM=1
export ZHOUKEER_INPUTPLUMBER_PRODUCT_FILE="$PRODUCT_FILE"
export ZHOUKEER_INPUTPLUMBER_VENDOR_FILE="$VENDOR_FILE"
export ZHOUKEER_INPUTPLUMBER_INSTALL_ROOT="$INSTALL_ROOT"
export ZHOUKEER_INPUTPLUMBER_STATE_DIR="$TEST_ROOT/state/inputplumber-update"
export ZHOUKEER_INPUTPLUMBER_URL="https://github.com/ShadowBlip/InputPlumber/releases/download/v0.79.2/inputplumber-x86_64.tar.gz"
export ZHOUKEER_INPUTPLUMBER_SHA256="$FIXTURE_SHA256"

# shellcheck disable=SC1090
source "$MODULE"

# core/env.sh 会设置项目运行日志路径；模拟测试必须继续使用自己的临时文件。
LOG_FILE="$TEST_ROOT/toolbox.log"

MOCK_STEAMOS=1
MOCK_UID=1000
MOCK_GID=1000
MOCK_ENABLED=1
MOCK_ACTIVE=1
MOCK_READONLY=enabled
MOCK_DOWNLOAD_FAIL=0
MOCK_RESTART_FAIL=0
MOCK_DATE=20260909-120001

detect_platform() { IS_STEAMOS="$MOCK_STEAMOS"; }
id() {
    case "${1:-}" in
        -u) printf '%s\n' "$MOCK_UID" ;;
        -g) printf '%s\n' "$MOCK_GID" ;;
        *) command id "$@" ;;
    esac
}
uname() {
    case "${1:-}" in
        -m) printf '%s\n' 'x86_64' ;;
        *) command uname "$@" ;;
    esac
}
date() {
    case "${1:-}" in
        '+%Y%m%d-%H%M%S') printf '%s\n' "$MOCK_DATE" ;;
        *) command date "$@" ;;
    esac
}
require_command() { return 0; }
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
download_github_file() {
    local output="$2" expected="$3" actual
    printf 'download %s\n' "$1" >> "$CALLS"
    [ "$MOCK_DOWNLOAD_FAIL" -eq 0 ] || return 1
    actual="$(sha256sum "$FIXTURE_ARCHIVE" | awk '{print $1}')"
    [ "$actual" = "$expected" ] || return 1
    cp -- "$FIXTURE_ARCHIVE" "$output"
}
steamos-readonly() {
    printf 'steamos-readonly %s\n' "$*" >> "$CALLS"
    case "${1:-}" in
        status) printf '%s\n' "$MOCK_READONLY" ;;
        disable) MOCK_READONLY=disabled ;;
        enable) MOCK_READONLY=enabled ;;
        *) return 1 ;;
    esac
}
systemctl() {
    local original="$*" command_name unit
    printf 'systemctl %s\n' "$original" >> "$CALLS"
    command_name="${1:-}"
    shift || true
    unit="${!#:-}"
    case "$command_name" in
        is-enabled) [ "$unit" = inputplumber.service ] && [ "$MOCK_ENABLED" -eq 1 ] ;;
        is-active) [ "$unit" = inputplumber.service ] && [ "$MOCK_ACTIVE" -eq 1 ] ;;
        stop) MOCK_ACTIVE=0 ;;
        disable) MOCK_ENABLED=0 ;;
        enable)
            MOCK_ENABLED=1
            case " $original " in *' --now '*) MOCK_ACTIVE=1 ;; esac
            ;;
        restart)
            [ "$MOCK_RESTART_FAIL" -eq 0 ] || return 1
            MOCK_ACTIVE=1
            ;;
        daemon-reload) return 0 ;;
        *) return 1 ;;
    esac
}
udevadm() { printf 'udevadm %s\n' "$*" >> "$CALLS"; }
systemd-hwdb() { printf 'systemd-hwdb %s\n' "$*" >> "$CALLS"; }
chown() { printf 'chown %s\n' "$*" >> "$CALLS"; }
toolbox_sudo() {
    printf 'sudo %s\n' "$*" >> "$CALLS"
    "$@"
}

# 非 SteamOS、root 和非壹号掌机必须在下载及系统修改前拒绝。
MOCK_STEAMOS=0
if ipu_update > "$TEST_ROOT/not-steamos.out" 2>&1; then
    fail "非 SteamOS 仍允许更新 InputPlumber"
fi
[ ! -s "$CALLS" ] || fail "非 SteamOS 拒绝后仍调用了下载或系统命令"

MOCK_STEAMOS=1
MOCK_UID=0
if ipu_update > "$TEST_ROOT/root.out" 2>&1; then
    fail "root 用户仍允许直接更新 InputPlumber"
fi
[ ! -s "$CALLS" ] || fail "root 拒绝后仍调用了下载或系统命令"

MOCK_UID=1000
printf 'Steam Deck\n' > "$PRODUCT_FILE"
if ipu_update > "$TEST_ROOT/not-onexplayer.out" 2>&1; then
    fail "非壹号掌机仍允许更新 InputPlumber"
fi
[ ! -s "$CALLS" ] || fail "非壹号掌机拒绝后仍调用了下载或系统命令"

# 成功流程：固定包下载、备份、写入、服务恢复和只读保护均需完成。
printf 'ONEXPLAYER 2 PRO ARP23P\n' > "$PRODUCT_FILE"
ipu_update > "$TEST_ROOT/update.out" || fail "InputPlumber 模拟更新失败"
grep -Fq 'InputPlumber 已更新并验证为 0.79.2' "$TEST_ROOT/update.out" || fail "完成提示缺少目标版本"
[ "$("$INSTALL_ROOT/usr/bin/inputplumber" --version)" = 'inputplumber 0.79.2' ] || fail "目标二进制版本不正确"
[ -f "$INSTALL_ROOT/usr/share/inputplumber/devices/50-onexplayer_mini_pro.yaml" ] || fail "缺少 Mini Pro 配置"
[ -f "$INSTALL_ROOT/usr/share/inputplumber/devices/50-onexplayer_2.yaml" ] || fail "缺少 2 Pro 配置"
grep -Fxq 'steamos-readonly disable' "$CALLS" || fail "未临时关闭只读保护"
grep -Fxq 'steamos-readonly enable' "$CALLS" || fail "未恢复只读保护"
grep -Fq 'systemctl enable --now inputplumber.service' "$CALLS" || fail "未启用并启动 InputPlumber"
grep -Fxq 'systemctl restart inputplumber.service' "$CALLS" || fail "未重启 InputPlumber"
grep -Fxq 'udevadm control --reload-rules' "$CALLS" || fail "未重新加载 udev 规则"
[ "$MOCK_READONLY" = enabled ] || fail "成功后只读保护状态未恢复"
[ "$MOCK_ENABLED" -eq 1 ] && [ "$MOCK_ACTIVE" -eq 1 ] || fail "成功后服务状态异常"
BACKUP_FILE="$ZHOUKEER_INPUTPLUMBER_STATE_DIR/inputplumber-before-0.79.2-$MOCK_DATE.tar.gz"
[ -f "$BACKUP_FILE" ] || fail "没有保存旧版备份"
tar -tzf "$BACKUP_FILE" | grep -Fq 'usr/bin/inputplumber' || fail "旧版备份缺少二进制"

# 下载失败必须发生在只读保护和系统服务改动之前。
: > "$CALLS"
MOCK_DOWNLOAD_FAIL=1
MOCK_DATE=20260909-120002
if ipu_update > "$TEST_ROOT/download-fail.out" 2>&1; then
    fail "下载失败后仍返回成功"
fi
grep -Fq 'download https://github.com/ShadowBlip/InputPlumber/' "$CALLS" || fail "未调用受控 GitHub 下载"
if grep -Eq 'steamos-readonly (disable|enable)|systemctl (stop|enable|restart)' "$CALLS"; then
    fail "下载失败后修改了只读保护或服务"
fi

# 写入后的服务验证失败也必须恢复只读保护并保留备份。
: > "$CALLS"
MOCK_DOWNLOAD_FAIL=0
MOCK_RESTART_FAIL=1
MOCK_READONLY=enabled
MOCK_ENABLED=1
MOCK_ACTIVE=1
MOCK_DATE=20260909-120003
if ipu_update > "$TEST_ROOT/restart-fail.out" 2>&1; then
    fail "服务重启失败后仍返回成功"
fi
grep -Fxq 'steamos-readonly enable' "$CALLS" || fail "服务失败后未恢复只读保护"
grep -Fq '旧版备份保留在' "$TEST_ROOT/restart-fail.out" || fail "失败后未提示保留备份"
[ -f "$ZHOUKEER_INPUTPLUMBER_STATE_DIR/inputplumber-before-0.79.2-$MOCK_DATE.tar.gz" ] || \
    fail "服务失败后旧版备份丢失"

for required in \
    'INPUTPLUMBER_UPDATE_VERSION="0.79.2"' \
    'INPUTPLUMBER_UPDATE_SHA256="dc8a859b55047c1a78c99dfaa296c55eebfbf798057f519543fbc7f6215cf953"' \
    'download_github_file' \
    'steamos-readonly disable' \
    'steamos-readonly enable' \
    '50-onexplayer_mini_pro.yaml' \
    '50-onexplayer_2.yaml'; do
    grep -Fq "$required" "$MODULE" || fail "模块缺少安全更新要素：$required"
done
if grep -Eq '(^|[[:space:]])(eval|bash -c|sh -c)([[:space:]]|$)' "$MODULE"; then
    fail "InputPlumber 更新包含禁止的动态命令执行"
fi

echo "PASS: InputPlumber 固定包校验、壹号掌机限制、备份、只读保护恢复与服务失败安全退出模拟通过"
