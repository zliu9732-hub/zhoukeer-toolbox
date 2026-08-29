#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/f1l_button_fix.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

HOME="$TMP_ROOT/home"
XDG_STATE_HOME="$TMP_ROOT/state"
ZHOUKEER_F1L_PRODUCT_FILE="$TMP_ROOT/product-name"
ZHOUKEER_F1L_SOURCE_CONFIG="$TMP_ROOT/usr/share/inputplumber/devices/50-onexplayer_onexfly.yaml"
ZHOUKEER_F1L_CONFIG_DIR="$TMP_ROOT/etc/inputplumber/devices.d"
ZHOUKEER_F1L_TARGET_CONFIG="$ZHOUKEER_F1L_CONFIG_DIR/50-onexplayer_f1l.yaml"
ZHOUKEER_F1L_STATE_FILE="$XDG_STATE_HOME/zhoukeer-toolbox/f1l-button-fix.state"
ZHOUKEER_AUTO_CONFIRM=1

mkdir -p -- "$HOME" "$(dirname "$ZHOUKEER_F1L_SOURCE_CONFIG")" "$TMP_ROOT/logs"
printf '%s\n' \
    'version: 1' \
    'matches:' \
    '  - dmi_data:' \
    '      product_name: ONEXPLAYER F1' \
    '    mapping: first' \
    '  - dmi_data:' \
    '      product_name: ONEXPLAYER F1' \
    '    mapping: second' > "$ZHOUKEER_F1L_SOURCE_CONFIG"
printf 'ONEXPLAYER F1L\n' > "$ZHOUKEER_F1L_PRODUCT_FILE"

# shellcheck disable=SC1090
source "$MODULE"

LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
SYSTEMCTL_CALLS="$TMP_ROOT/systemctl.calls"
MOCK_STEAMOS=1
MOCK_UID=1000
MOCK_LOAD_STATE=loaded
MOCK_ENABLED=0
MOCK_ACTIVE=0
MOCK_FAIL_ENABLE=0
MOCK_ENABLE_NO_EFFECT=0
MOCK_FAIL_RESTART=0
MOCK_MISSING_COMMAND=""

detect_platform() { IS_STEAMOS="$MOCK_STEAMOS"; }
id() {
    if [ "${1:-}" = "-u" ]; then
        printf '%s\n' "$MOCK_UID"
    else
        command id "$@"
    fi
}
require_command() {
    if [ "$1" = "$MOCK_MISSING_COMMAND" ]; then
        echo "缺少命令: $1"
        return 1
    fi
}
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
systemctl() {
    printf '%s\n' "$*" >> "$SYSTEMCTL_CALLS"
    case "${1:-}" in
        show)
            printf '%s\n' "$MOCK_LOAD_STATE"
            ;;
        is-enabled)
            [ "$MOCK_ENABLED" -eq 1 ]
            ;;
        is-active)
            [ "$MOCK_ACTIVE" -eq 1 ]
            ;;
        enable)
            [ "$MOCK_FAIL_ENABLE" -eq 0 ] || return 1
            if [ "$MOCK_ENABLE_NO_EFFECT" -eq 0 ]; then
                MOCK_ENABLED=1
                case " $* " in *' --now '*) MOCK_ACTIVE=1 ;; esac
            fi
            ;;
        restart)
            [ "$MOCK_FAIL_RESTART" -eq 0 ] || return 1
            MOCK_ACTIVE=1
            ;;
        disable)
            MOCK_ENABLED=0
            ;;
        stop)
            MOCK_ACTIVE=0
            ;;
        *) return 1 ;;
    esac
}
toolbox_sudo() { "$@"; }

reset_fixture() {
    rm -rf -- "$F1L_CONFIG_DIR" "$XDG_STATE_HOME"
    : > "$SYSTEMCTL_CALLS"
    MOCK_STEAMOS=1
    MOCK_UID=1000
    MOCK_LOAD_STATE=loaded
    MOCK_ENABLED=0
    MOCK_ACTIVE=0
    MOCK_FAIL_ENABLE=0
    MOCK_ENABLE_NO_EFFECT=0
    MOCK_FAIL_RESTART=0
    MOCK_MISSING_COMMAND=""
    F1L_SOURCE_CONFIG="$ZHOUKEER_F1L_SOURCE_CONFIG"
    printf 'ONEXPLAYER F1L\n' > "$F1L_PRODUCT_FILE"
}

# macOS/非 SteamOS、root 和非目标型号必须在任何系统操作前停止。
reset_fixture
MOCK_STEAMOS=0
if f1l_install > "$TMP_ROOT/not-steamos.out" 2>&1; then
    fail "非 SteamOS 仍允许执行 F1L 按键修复"
fi
[ ! -s "$SYSTEMCTL_CALLS" ] || fail "非 SteamOS 触发了 systemctl"
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "非 SteamOS 写入了配置"

reset_fixture
MOCK_UID=0
if f1l_install > "$TMP_ROOT/root.out" 2>&1; then
    fail "root 用户仍允许直接执行 F1L 按键修复"
fi
[ ! -s "$SYSTEMCTL_CALLS" ] || fail "root 拒绝路径触发了 systemctl"

reset_fixture
printf 'Other Device\n' > "$F1L_PRODUCT_FILE"
if f1l_install > "$TMP_ROOT/not-f1l.out" 2>&1; then
    fail "非 ONEXPLAYER F1L 仍允许执行按键修复"
fi
grep -Fq '本按键修复不适用' "$TMP_ROOT/not-f1l.out" || fail "非目标型号缺少不适用提示"
[ ! -s "$SYSTEMCTL_CALLS" ] || fail "非目标型号触发了 systemctl"

# 缺少命令、服务或官方源配置时必须失败且不写入目标配置。
reset_fixture
MOCK_MISSING_COMMAND=inputplumber
if f1l_install > "$TMP_ROOT/missing-command.out" 2>&1; then
    fail "缺少 inputplumber 时仍继续安装"
fi
grep -Fq '缺少必要组件' "$TMP_ROOT/missing-command.out" || fail "缺少组件提示不明确"
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "缺少组件时写入了配置"

reset_fixture
MOCK_MISSING_COMMAND=sudo
if f1l_install > "$TMP_ROOT/missing-sudo.out" 2>&1; then
    fail "缺少 sudo 时仍继续安装"
fi
grep -Fq '缺少必要组件' "$TMP_ROOT/missing-sudo.out" || fail "缺少 sudo 提示不明确"
[ ! -e "$F1L_STATE_FILE" ] || fail "缺少 sudo 时提前写入了状态记录"

reset_fixture
MOCK_LOAD_STATE=not-found
if f1l_install > "$TMP_ROOT/missing-service.out" 2>&1; then
    fail "InputPlumber 服务缺失时仍继续安装"
fi
grep -Fq '未找到可用的 inputplumber.service' "$TMP_ROOT/missing-service.out" || fail "服务缺失提示不明确"
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "服务缺失时写入了配置"

reset_fixture
F1L_SOURCE_CONFIG="$TMP_ROOT/missing-source.yaml"
if f1l_install > "$TMP_ROOT/missing-source.out" 2>&1; then
    fail "系统自带配置缺失时仍继续安装"
fi
grep -Fq '未找到可读的 InputPlumber 系统配置' "$TMP_ROOT/missing-source.out" || fail "源配置缺失提示不明确"
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "源配置缺失时写入了配置"

reset_fixture
BAD_SOURCE="$TMP_ROOT/bad-source.yaml"
printf '%s\n' 'product_name: ONEXPLAYER F1 Pro' > "$BAD_SOURCE"
F1L_SOURCE_CONFIG="$BAD_SOURCE"
if f1l_install > "$TMP_ROOT/bad-source.out" 2>&1; then
    fail "源配置没有精确 F1 型号时仍继续安装"
fi
grep -Fq '无法安全生成 F1L 配置' "$TMP_ROOT/bad-source.out" || fail "源配置不匹配提示不明确"
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "源配置不匹配时写入了配置"

reset_fixture
mkdir -p -- "$(dirname "$F1L_CONFIG_DIR")"
ln -s "$TMP_ROOT" "$F1L_CONFIG_DIR"
if f1l_install > "$TMP_ROOT/unsafe-dir.out" 2>&1; then
    fail "自定义配置目录为符号链接时仍继续安装"
fi
grep -Fq '不是安全的普通目录' "$TMP_ROOT/unsafe-dir.out" || fail "不安全配置目录缺少拒绝提示"

# 安装只替换第一处型号，启用并重启服务，同时保存安装前状态。
reset_fixture
if ! f1l_install > "$TMP_ROOT/install.out"; then
    fail "F1L 按键修复安装失败"
fi
[ -f "$F1L_TARGET_CONFIG" ] && [ ! -L "$F1L_TARGET_CONFIG" ] || fail "F1L 自定义配置未创建为普通文件"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1L[[:space:]]*$' "$F1L_TARGET_CONFIG")" -eq 1 ] || \
    fail "F1L 型号不是恰好一处"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1[[:space:]]*$' "$F1L_TARGET_CONFIG")" -eq 1 ] || \
    fail "安装没有只替换源配置的第一处 F1 型号"
grep -Fq 'enable --now inputplumber.service' "$SYSTEMCTL_CALLS" || fail "安装未启用并启动 InputPlumber"
grep -Fxq 'restart inputplumber.service' "$SYSTEMCTL_CALLS" || fail "安装未重启 InputPlumber"
grep -Fxq 'was_enabled=0' "$F1L_STATE_FILE" || fail "未记录服务原启用状态"
grep -Fxq 'was_active=0' "$F1L_STATE_FILE" || fail "未记录服务原运行状态"
grep -Fq 'InputPlumber 状态为 active' "$TMP_ROOT/install.out" || fail "完成提示缺少服务验证结果"
for mapping in '橙色键短按：Steam/Guide' 'Turbo 键：右侧快捷菜单' '键盘键：呼出虚拟键盘' '橙色键长按：第二快捷菜单'; do
    grep -Fq "$mapping" "$TMP_ROOT/install.out" || fail "完成提示缺少预期映射：$mapping"
done

# 重复运行不能重写配置、重复型号或覆盖初始服务状态。
before_checksum="$(cksum "$F1L_TARGET_CONFIG")"
: > "$SYSTEMCTL_CALLS"
if ! f1l_install > "$TMP_ROOT/reinstall.out"; then
    fail "重复安装 F1L 按键修复失败"
fi
[ "$before_checksum" = "$(cksum "$F1L_TARGET_CONFIG")" ] || fail "重复安装改写了正确配置"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1L[[:space:]]*$' "$F1L_TARGET_CONFIG")" -eq 1 ] || \
    fail "重复安装产生了重复型号"
grep -Fq '不重复写入' "$TMP_ROOT/reinstall.out" || fail "重复安装缺少幂等提示"
grep -Fxq 'was_enabled=0' "$F1L_STATE_FILE" || fail "重复安装覆盖了初始服务状态"

if ! f1l_status > "$TMP_ROOT/status.out"; then
    fail "正确安装后的状态检查失败"
fi
grep -Fq '仅出现一次' "$TMP_ROOT/status.out" || fail "状态未验证唯一型号"
grep -Fq 'InputPlumber 服务：active' "$TMP_ROOT/status.out" || fail "状态未验证服务 active"
grep -Fq '开机启动：已启用' "$TMP_ROOT/status.out" || fail "状态未验证开机启动"

# 恢复会删除自定义配置，并仅撤销本功能造成的服务启用与启动。
: > "$SYSTEMCTL_CALLS"
if ! f1l_restore > "$TMP_ROOT/restore.out"; then
    fail "F1L 按键修复恢复失败"
fi
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "恢复后 F1L 自定义配置仍存在"
[ ! -e "$F1L_STATE_FILE" ] || fail "恢复后服务状态记录仍存在"
[ "$MOCK_ENABLED" -eq 0 ] || fail "恢复后未禁用由本功能启用的服务"
[ "$MOCK_ACTIVE" -eq 0 ] || fail "恢复后未停止由本功能启动的服务"
grep -Fxq 'disable inputplumber.service' "$SYSTEMCTL_CALLS" || fail "恢复未禁用 InputPlumber"
grep -Fxq 'stop inputplumber.service' "$SYSTEMCTL_CALLS" || fail "恢复未停止 InputPlumber"
grep -Fq '请重启机器完成恢复' "$TMP_ROOT/restore.out" || fail "恢复提示缺少重启说明"
if ! f1l_restore > "$TMP_ROOT/restore-again.out"; then
    fail "重复恢复失败"
fi
grep -Fq '无需恢复' "$TMP_ROOT/restore-again.out" || fail "重复恢复缺少幂等提示"

# 如果 InputPlumber 原本已启用且运行，恢复不得将它停用。
reset_fixture
MOCK_ENABLED=1
MOCK_ACTIVE=1
f1l_install > "$TMP_ROOT/preexisting-install.out" || fail "原服务已运行时安装失败"
f1l_restore > "$TMP_ROOT/preexisting-restore.out" || fail "原服务已运行时恢复失败"
[ "$MOCK_ENABLED" -eq 1 ] || fail "恢复错误禁用了原本已启用的服务"
[ "$MOCK_ACTIVE" -eq 1 ] || fail "恢复错误停止了原本已运行的服务"
grep -Fxq 'enable inputplumber.service' "$SYSTEMCTL_CALLS" || fail "恢复未明确还原原开机启用状态"

# 任一步失败都必须停止后续流程并回滚本次创建的文件和服务状态。
reset_fixture
MOCK_FAIL_ENABLE=1
if f1l_install > "$TMP_ROOT/enable-failed.out" 2>&1; then
    fail "systemctl enable 失败后安装仍返回成功"
fi
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "enable 失败后未回滚自定义配置"
[ ! -e "$F1L_STATE_FILE" ] || fail "enable 失败后未回滚状态记录"
grep -Fq '启用或启动失败' "$TMP_ROOT/enable-failed.out" || fail "enable 失败原因不明确"
if grep -Fxq 'restart inputplumber.service' "$SYSTEMCTL_CALLS"; then
    fail "enable 失败后仍继续执行安装重启步骤"
fi

reset_fixture
MOCK_FAIL_RESTART=1
if f1l_install > "$TMP_ROOT/restart-failed.out" 2>&1; then
    fail "systemctl restart 失败后安装仍返回成功"
fi
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "restart 失败后未回滚自定义配置"
[ ! -e "$F1L_STATE_FILE" ] || fail "restart 失败后未回滚状态记录"
grep -Fq 'InputPlumber 重启失败' "$TMP_ROOT/restart-failed.out" || fail "restart 失败原因不明确"

reset_fixture
MOCK_ENABLE_NO_EFFECT=1
if f1l_install > "$TMP_ROOT/not-enabled.out" 2>&1; then
    fail "服务未真正设为开机启动时安装仍返回成功"
fi
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "开机启动验证失败后未回滚自定义配置"
[ ! -e "$F1L_STATE_FILE" ] || fail "开机启动验证失败后未回滚状态记录"
grep -Fq '未设置为开机启动' "$TMP_ROOT/not-enabled.out" || fail "开机启动验证失败原因不明确"

# 不覆盖不同内容、符号链接或异常状态记录。
reset_fixture
mkdir -p -- "$F1L_CONFIG_DIR"
ln -s "$F1L_SOURCE_CONFIG" "$F1L_TARGET_CONFIG"
if f1l_install > "$TMP_ROOT/symlink.out" 2>&1; then
    fail "目标为符号链接时仍继续安装"
fi
[ -L "$F1L_TARGET_CONFIG" ] || fail "拒绝路径错误修改了符号链接"
grep -Fq '已拒绝覆盖' "$TMP_ROOT/symlink.out" || fail "不安全目标缺少拒绝提示"

reset_fixture
mkdir -p -- "$(dirname "$F1L_STATE_FILE")"
printf 'unexpected=1\n' > "$F1L_STATE_FILE"
if f1l_install > "$TMP_ROOT/bad-state.out" 2>&1; then
    fail "异常状态记录存在时仍继续安装"
fi
[ ! -e "$F1L_TARGET_CONFIG" ] || fail "异常状态记录存在时写入了配置"
grep -Fq '异常的 F1L 修复状态记录' "$TMP_ROOT/bad-state.out" || fail "异常状态记录缺少拒绝提示"

reset_fixture
mkdir -p -- "$F1L_CONFIG_DIR"
printf 'user-owned: true\n' > "$F1L_TARGET_CONFIG"
if f1l_restore > "$TMP_ROOT/unsafe-restore.out" 2>&1; then
    fail "恢复功能删除了无法识别的目标文件"
fi
[ -f "$F1L_TARGET_CONFIG" ] || fail "恢复功能误删了无法识别的目标文件"
grep -Fq '已拒绝删除' "$TMP_ROOT/unsafe-restore.out" || fail "危险恢复缺少拒绝提示"

grep -Fq '不会安装 HHD' "$MODULE" || fail "模块缺少 HHD 冲突说明"
if rg -n '(^|[[:space:]])(eval|bash -c|sh -c)([[:space:]]|$)' "$MODULE" >/dev/null; then
    fail "F1L 按键修复包含禁止的动态命令执行"
fi

echo "PASS: 飞行家 F1L 按键修复机型保护、依赖检查、唯一替换、服务验证、幂等、回滚与恢复模拟通过"
