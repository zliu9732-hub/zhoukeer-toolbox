#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/onexplayer_button_fix.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

HOME="$TMP_ROOT/home"
XDG_STATE_HOME="$TMP_ROOT/state"
ZHOUKEER_OXP_PRODUCT_FILE="$TMP_ROOT/product-name"
ZHOUKEER_OXP_CONFIG_DIR="$TMP_ROOT/etc/inputplumber/devices.d"
ZHOUKEER_OXP_STATE_ROOT="$XDG_STATE_HOME/zhoukeer-toolbox"
ZHOUKEER_OXP_F1L_SOURCE_CONFIG="$TMP_ROOT/usr/share/inputplumber/devices/50-onexplayer_onexfly.yaml"
ZHOUKEER_OXP_X1PRO_SOURCE_CONFIG="$TMP_ROOT/usr/share/inputplumber/devices/50-onexplayer_x1.yaml"
ZHOUKEER_AUTO_CONFIRM=1
ZHOUKEER_REBOOT_CHOICE=later

mkdir -p -- "$HOME" "$(dirname "$ZHOUKEER_OXP_F1L_SOURCE_CONFIG")" "$TMP_ROOT/logs"

write_source_fixtures() {
    printf '%s\n' \
        'version: 1' \
        'matches:' \
        '  - dmi_data:' \
        '      product_name: ONEXPLAYER F1' \
        '    mapping: first' \
        '  - dmi_data:' \
        '      product_name: ONEXPLAYER F1' \
        '    mapping: second' > "$ZHOUKEER_OXP_F1L_SOURCE_CONFIG"
    printf '%s\n' \
        'version: 1' \
        'matches:' \
        '  - dmi_data:' \
        '      product_name: ONEXPLAYER X1 A' \
        '    mapping: first' \
        '  - dmi_data:' \
        '      product_name: ONEXPLAYER X1 A' \
        '    mapping: second' > "$ZHOUKEER_OXP_X1PRO_SOURCE_CONFIG"
}

write_source_fixtures
printf 'ONEXPLAYER F1L\n' > "$ZHOUKEER_OXP_PRODUCT_FILE"

# shellcheck disable=SC1090
source "$MODULE"

LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
SYSTEMCTL_CALLS="$TMP_ROOT/systemctl.calls"
MOCK_STEAMOS=1
MOCK_UID=1000
MOCK_USERNAME=deck
MOCK_LOAD_STATE=loaded
MOCK_ENABLED=0
MOCK_ACTIVE=0
MOCK_FAIL_ENABLE=0
MOCK_ENABLE_NO_EFFECT=0
MOCK_FAIL_RESTART=0
MOCK_HHD_PROCESS=0
MOCK_HHD_SYSTEM=0
MOCK_HHD_USER=0
MOCK_REBOOT=0
MOCK_MISSING_COMMAND=""

detect_platform() { IS_STEAMOS="$MOCK_STEAMOS"; }
id() {
    case "${1:-}" in
        -u) printf '%s\n' "$MOCK_UID" ;;
        -un) printf '%s\n' "$MOCK_USERNAME" ;;
        *) command id "$@" ;;
    esac
}
require_command() {
    if [ "$1" = "$MOCK_MISSING_COMMAND" ]; then
        echo "缺少命令: $1"
        return 1
    fi
}
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
pgrep() { [ "$MOCK_HHD_PROCESS" -eq 1 ]; }
systemctl() {
    local original="$*" user_mode=0 command_name unit
    printf '%s\n' "$original" >> "$SYSTEMCTL_CALLS"
    if [ "${1:-}" = "--user" ]; then
        user_mode=1
        shift
    fi
    command_name="${1:-}"
    shift || true
    unit="${!#:-}"
    case "$command_name" in
        show)
            printf '%s\n' "$MOCK_LOAD_STATE"
            ;;
        is-enabled)
            [ "$unit" = "inputplumber.service" ] && [ "$MOCK_ENABLED" -eq 1 ]
            ;;
        is-active)
            case "$unit" in
                inputplumber.service) [ "$MOCK_ACTIVE" -eq 1 ] ;;
                hhd.service)
                    if [ "$user_mode" -eq 1 ]; then
                        [ "$MOCK_HHD_USER" -eq 1 ]
                    else
                        [ "$MOCK_HHD_SYSTEM" -eq 1 ]
                    fi
                    ;;
                hhd@*.service) [ "$MOCK_HHD_SYSTEM" -eq 1 ] ;;
                *) return 1 ;;
            esac
            ;;
        enable)
            [ "$MOCK_FAIL_ENABLE" -eq 0 ] || return 1
            if [ "$MOCK_ENABLE_NO_EFFECT" -eq 0 ]; then
                MOCK_ENABLED=1
                case " $original " in *' --now '*) MOCK_ACTIVE=1 ;; esac
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
        reboot)
            MOCK_REBOOT=1
            ;;
        *) return 1 ;;
    esac
}
toolbox_sudo() { "$@"; }

use_f1l() { printf 'ONEXPLAYER F1L\n' > "$OXP_PRODUCT_FILE"; }
use_x1pro() { printf 'ONEXPLAYER X1Pro\n' > "$OXP_PRODUCT_FILE"; }

reset_fixture() {
    rm -rf -- "$OXP_CONFIG_DIR" "$OXP_STATE_ROOT"
    mkdir -p -- "$(dirname "$ZHOUKEER_OXP_F1L_SOURCE_CONFIG")"
    write_source_fixtures
    : > "$SYSTEMCTL_CALLS"
    MOCK_STEAMOS=1
    MOCK_UID=1000
    MOCK_LOAD_STATE=loaded
    MOCK_ENABLED=0
    MOCK_ACTIVE=0
    MOCK_FAIL_ENABLE=0
    MOCK_ENABLE_NO_EFFECT=0
    MOCK_FAIL_RESTART=0
    MOCK_HHD_PROCESS=0
    MOCK_HHD_SYSTEM=0
    MOCK_HHD_USER=0
    MOCK_REBOOT=0
    MOCK_MISSING_COMMAND=""
    ZHOUKEER_REBOOT_CHOICE=later
    use_f1l
}

file_mode() {
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

# 平台、用户和精确 DMI 白名单必须先于任何写入操作生效。
reset_fixture
MOCK_STEAMOS=0
if oxp_install > "$TMP_ROOT/not-steamos.out" 2>&1; then
    fail "非 SteamOS 仍允许执行特殊按键修复"
fi
[ ! -e "$OXP_CONFIG_DIR" ] || fail "非 SteamOS 创建了配置目录"

reset_fixture
MOCK_UID=0
if oxp_install > "$TMP_ROOT/root.out" 2>&1; then
    fail "root 用户仍允许直接执行特殊按键修复"
fi
[ ! -e "$OXP_CONFIG_DIR" ] || fail "root 拒绝路径创建了配置目录"

reset_fixture
printf 'ONEXPLAYER X1 Pro\n' > "$OXP_PRODUCT_FILE"
if oxp_install > "$TMP_ROOT/unsupported.out" 2>&1; then
    fail "近似但未验证的 DMI 仍被接受"
fi
grep -Fq '当前机型尚未实机验证，已停止操作' "$TMP_ROOT/unsupported.out" || \
    fail "不支持型号缺少指定提示"
[ ! -s "$SYSTEMCTL_CALLS" ] || fail "不支持型号触发了 systemctl"

# HHD 运行时不得启用 InputPlumber，也不得擅自停止 HHD。
reset_fixture
MOCK_HHD_PROCESS=1
if oxp_install > "$TMP_ROOT/hhd.out" 2>&1; then
    fail "HHD 运行时仍允许安装 InputPlumber 修复"
fi
grep -Fq 'HHD 正在运行' "$TMP_ROOT/hhd.out" || fail "HHD 冲突提示不明确"
if grep -Fq 'enable --now inputplumber.service' "$SYSTEMCTL_CALLS"; then
    fail "HHD 冲突后仍启用了 InputPlumber"
fi
if grep -Eq 'stop .*hhd|disable .*hhd' "$SYSTEMCTL_CALLS"; then
    fail "Renkit 擅自停止或禁用了 HHD"
fi

# 缺少命令、服务或对应源配置时必须失败且不写目标。
reset_fixture
MOCK_MISSING_COMMAND=inputplumber
if oxp_install > "$TMP_ROOT/missing-command.out" 2>&1; then
    fail "缺少 inputplumber 时仍继续安装"
fi
grep -Fq '缺少必要组件' "$TMP_ROOT/missing-command.out" || fail "缺少组件提示不明确"

reset_fixture
MOCK_LOAD_STATE=not-found
if oxp_install > "$TMP_ROOT/missing-service.out" 2>&1; then
    fail "InputPlumber 服务缺失时仍继续安装"
fi
grep -Fq '未找到可用的 inputplumber.service' "$TMP_ROOT/missing-service.out" || fail "服务缺失提示不明确"

reset_fixture
use_x1pro
mv "$ZHOUKEER_OXP_X1PRO_SOURCE_CONFIG" "$TMP_ROOT/x1-source-away"
if oxp_install > "$TMP_ROOT/missing-source.out" 2>&1; then
    fail "X1 Pro 系统源配置缺失时仍继续安装"
fi
grep -Fq '50-onexplayer_x1.yaml' "$TMP_ROOT/missing-source.out" || fail "X1 Pro 源配置缺失提示不明确"

# F1L：只替换第一处，验证系统源不变、服务状态、幂等和恢复。
reset_fixture
f1_source_before="$(cksum "$ZHOUKEER_OXP_F1L_SOURCE_CONFIG")"
if ! oxp_install > "$TMP_ROOT/f1-install.out"; then
    fail "F1L 特殊按键修复安装失败"
fi
F1_TARGET="$OXP_TARGET_CONFIG"
F1_STATE="$OXP_STATE_FILE"
[ "$OXP_PRODUCT_NAME" = 'ONEXPLAYER F1L' ] || fail "F1L DMI 选择错误"
[ "$F1_TARGET" = "$OXP_CONFIG_DIR/50-onexplayer_f1l.yaml" ] || fail "F1L 目标路径错误"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1L[[:space:]]*$' "$F1_TARGET")" -eq 1 ] || \
    fail "F1L 目标 DMI 不是恰好一处"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1[[:space:]]*$' "$F1_TARGET")" -eq 1 ] || \
    fail "F1L 没有只替换第一处源 DMI"
[ "$f1_source_before" = "$(cksum "$ZHOUKEER_OXP_F1L_SOURCE_CONFIG")" ] || fail "F1L 系统源配置被修改"
grep -Fxq 'version=2' "$F1_STATE" || fail "F1L 状态记录版本错误"
grep -Fxq 'product_name=ONEXPLAYER F1L' "$F1_STATE" || fail "F1L 状态未记录精确 DMI"
grep -Fxq 'target_existed=0' "$F1_STATE" || fail "F1L 首次安装错误记录了原文件"
grep -Fq 'enable --now inputplumber.service' "$SYSTEMCTL_CALLS" || fail "F1L 未启用并启动 InputPlumber"
grep -Fxq 'restart inputplumber.service' "$SYSTEMCTL_CALLS" || fail "F1L 未重启 InputPlumber"
grep -Fq '检测到机型：飞行家 F1L 8840U' "$TMP_ROOT/f1-install.out" || fail "F1L 未显示检测机型"
grep -Fq '已选择稍后重启' "$TMP_ROOT/f1-install.out" || fail "F1L 未提供稍后重启结果"
for mapping in '橙色键短按为 Steam/Guide' 'Turbo 键为右侧快捷菜单' '键盘键呼出虚拟键盘' '橙色键长按为第二快捷菜单'; do
    grep -Fq "$mapping" "$TMP_ROOT/f1-install.out" || fail "F1L 完成提示缺少映射：$mapping"
done

oxp_plan_install > "$TMP_ROOT/f1-plan.out" || fail "F1L 安装预览失败"
grep -Fq "写入自定义配置：$F1_TARGET" "$TMP_ROOT/f1-plan.out" || fail "F1L 安装预览缺少目标路径"
oxp_plan_restore > "$TMP_ROOT/f1-restore-plan.out" || fail "F1L 恢复预览失败"
grep -Fq '删除 Renkit 创建的文件' "$TMP_ROOT/f1-restore-plan.out" || fail "F1L 恢复预览缺少删除范围"

f1_target_before="$(cksum "$F1_TARGET")"
f1_state_before="$(cksum "$F1_STATE")"
: > "$SYSTEMCTL_CALLS"
oxp_install > "$TMP_ROOT/f1-reinstall.out" || fail "F1L 重复安装失败"
[ "$f1_target_before" = "$(cksum "$F1_TARGET")" ] || fail "F1L 重复安装改写了正确配置"
[ "$f1_state_before" = "$(cksum "$F1_STATE")" ] || fail "F1L 重复安装覆盖了初始状态"
grep -Fq '不重复写入' "$TMP_ROOT/f1-reinstall.out" || fail "F1L 重复安装缺少幂等提示"

oxp_status > "$TMP_ROOT/f1-status.out" || fail "F1L 正确状态检查失败"
grep -Fq '系统源配置：未被修改' "$TMP_ROOT/f1-status.out" || fail "F1L 状态未验证系统源"
grep -Fq 'HHD 冲突状态：未运行' "$TMP_ROOT/f1-status.out" || fail "F1L 状态未验证 HHD"

: > "$SYSTEMCTL_CALLS"
oxp_restore > "$TMP_ROOT/f1-restore.out" || fail "F1L 恢复失败"
[ ! -e "$F1_TARGET" ] || fail "F1L 恢复后 Renkit 配置仍存在"
[ ! -e "$F1_STATE" ] || fail "F1L 恢复后状态记录仍存在"
[ "$MOCK_ENABLED" -eq 0 ] && [ "$MOCK_ACTIVE" -eq 0 ] || fail "F1L 未恢复服务原状态"
grep -Fxq 'disable inputplumber.service' "$SYSTEMCTL_CALLS" || fail "F1L 恢复未禁用由本功能启用的服务"
grep -Fxq 'stop inputplumber.service' "$SYSTEMCTL_CALLS" || fail "F1L 恢复未停止由本功能启动的服务"

# X1 Pro：使用独立源和目标，只替换第一处 ONEXPLAYER X1 A。
reset_fixture
use_x1pro
x1_source_before="$(cksum "$ZHOUKEER_OXP_X1PRO_SOURCE_CONFIG")"
oxp_install > "$TMP_ROOT/x1-install.out" || fail "X1 Pro 特殊按键修复安装失败"
X1_TARGET="$OXP_TARGET_CONFIG"
X1_STATE="$OXP_STATE_FILE"
[ "$OXP_PRODUCT_NAME" = 'ONEXPLAYER X1Pro' ] || fail "X1 Pro DMI 选择错误"
[ "$X1_TARGET" = "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml" ] || fail "X1 Pro 目标路径错误"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER X1Pro[[:space:]]*$' "$X1_TARGET")" -eq 1 ] || \
    fail "X1 Pro 目标 DMI 不是恰好一处"
[ "$(grep -Ec '^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER X1 A[[:space:]]*$' "$X1_TARGET")" -eq 1 ] || \
    fail "X1 Pro 没有只替换第一处源 DMI"
[ "$x1_source_before" = "$(cksum "$ZHOUKEER_OXP_X1PRO_SOURCE_CONFIG")" ] || fail "X1 Pro 系统源配置被修改"
grep -Fxq 'product_name=ONEXPLAYER X1Pro' "$X1_STATE" || fail "X1 Pro 状态未记录精确 DMI"
grep -Fq '检测到机型：游侠 X1 Pro AMD' "$TMP_ROOT/x1-install.out" || fail "X1 Pro 未显示检测机型"
oxp_restore > "$TMP_ROOT/x1-restore.out" || fail "X1 Pro 恢复失败"
[ ! -e "$X1_TARGET" ] && [ ! -e "$X1_STATE" ] || fail "X1 Pro 恢复未清理 Renkit 文件"

# 原目标存在时必须备份，恢复后内容、权限和服务原状态均还原。
reset_fixture
use_x1pro
mkdir -p -- "$OXP_CONFIG_DIR"
ORIGINAL_TARGET="$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml"
printf '%s\n' 'user-owned: true' 'custom-value: keep-me' > "$ORIGINAL_TARGET"
chmod 0600 "$ORIGINAL_TARGET"
original_checksum="$(cksum < "$ORIGINAL_TARGET")"
original_mode="$(file_mode "$ORIGINAL_TARGET")"
MOCK_ENABLED=1
MOCK_ACTIVE=1
oxp_install > "$TMP_ROOT/backup-install.out" || fail "带原文件的 X1 Pro 安装失败"
BACKUP_FILE="${ORIGINAL_TARGET}.renkit-backup"
STATE_FILE="$OXP_STATE_FILE"
[ -f "$BACKUP_FILE" ] && [ ! -L "$BACKUP_FILE" ] || fail "原目标文件未安全备份"
[ "$original_checksum" = "$(cksum < "$BACKUP_FILE")" ] || fail "原目标备份内容不一致"
grep -Fxq 'target_existed=1' "$STATE_FILE" || fail "状态未记录原目标存在"
backup_checksum="$(cksum < "$BACKUP_FILE")"
oxp_install > "$TMP_ROOT/backup-reinstall.out" || fail "带备份的重复安装失败"
[ "$backup_checksum" = "$(cksum < "$BACKUP_FILE")" ] || fail "重复安装覆盖了原文件备份"
oxp_restore > "$TMP_ROOT/backup-restore.out" || fail "原文件恢复失败"
[ "$original_checksum" = "$(cksum < "$ORIGINAL_TARGET")" ] || fail "原目标内容未原样还原"
[ "$original_mode" = "$(file_mode "$ORIGINAL_TARGET")" ] || fail "原目标权限未还原"
[ ! -e "$BACKUP_FILE" ] && [ ! -e "$STATE_FILE" ] || fail "恢复后备份或状态记录未清理"
[ "$MOCK_ENABLED" -eq 1 ] && [ "$MOCK_ACTIVE" -eq 1 ] || fail "原本运行的 InputPlumber 状态未恢复"

# 没有 Renkit 所有权记录时，恢复功能不得删除同名用户文件。
reset_fixture
use_x1pro
mkdir -p -- "$OXP_CONFIG_DIR"
printf 'user-owned: true\n' > "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml"
if oxp_restore > "$TMP_ROOT/unowned-restore.out" 2>&1; then
    fail "恢复功能删除了没有 Renkit 所有权记录的文件"
fi
[ -f "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml" ] || fail "无所有权记录文件被误删"
grep -Fq '不会删除' "$TMP_ROOT/unowned-restore.out" || fail "无所有权记录缺少拒绝提示"

# 管理中的目标被其他程序修改后，恢复不得覆盖或删除。
reset_fixture
oxp_install > "$TMP_ROOT/tamper-install.out" || fail "篡改场景安装失败"
TAMPER_TARGET="$OXP_TARGET_CONFIG"
printf 'changed-by-user: true\n' > "$TAMPER_TARGET"
if oxp_restore > "$TMP_ROOT/tamper-restore.out" 2>&1; then
    fail "恢复覆盖了安装后被修改的目标文件"
fi
grep -Fq '不是 Renkit 创建的内容' "$TMP_ROOT/tamper-restore.out" || fail "目标篡改缺少拒绝提示"
grep -Fq 'changed-by-user: true' "$TAMPER_TARGET" || fail "目标篡改内容被破坏"

# HHD 在需要恢复 InputPlumber 原运行状态时必须阻止恢复且不改文件。
reset_fixture
MOCK_ENABLED=1
MOCK_ACTIVE=1
oxp_install > "$TMP_ROOT/hhd-restore-install.out" || fail "HHD 恢复场景安装失败"
HHD_TARGET="$OXP_TARGET_CONFIG"
hhd_target_before="$(cksum "$HHD_TARGET")"
MOCK_HHD_SYSTEM=1
if oxp_restore > "$TMP_ROOT/hhd-restore.out" 2>&1; then
    fail "HHD 运行时仍恢复并启动了 InputPlumber"
fi
[ "$hhd_target_before" = "$(cksum "$HHD_TARGET")" ] || fail "HHD 冲突时修改了配置"
grep -Fq '未修改任何文件' "$TMP_ROOT/hhd-restore.out" || fail "HHD 恢复冲突提示不明确"

# systemctl 失败必须返回非零并回滚新建文件；原文件场景也必须还原备份。
reset_fixture
MOCK_FAIL_ENABLE=1
if oxp_install > "$TMP_ROOT/enable-failed.out" 2>&1; then
    fail "systemctl enable 失败后安装仍返回成功"
fi
[ ! -e "$OXP_CONFIG_DIR/50-onexplayer_f1l.yaml" ] || fail "enable 失败后未删除 Renkit 配置"
[ ! -e "$OXP_STATE_ROOT/f1l-button-fix.state" ] || fail "enable 失败后未清理状态"
grep -Fq '启用或启动失败' "$TMP_ROOT/enable-failed.out" || fail "enable 失败原因不明确"

reset_fixture
use_x1pro
mkdir -p -- "$OXP_CONFIG_DIR"
printf 'original-before-failure\n' > "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml"
failure_original="$(cksum "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml")"
MOCK_FAIL_RESTART=1
if oxp_install > "$TMP_ROOT/restart-failed.out" 2>&1; then
    fail "systemctl restart 失败后安装仍返回成功"
fi
[ "$failure_original" = "$(cksum "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml")" ] || \
    fail "restart 失败后未还原原文件"
[ ! -e "$OXP_CONFIG_DIR/50-onexplayer_x1pro.yaml.renkit-backup" ] || fail "restart 失败后遗留备份"
[ ! -e "$OXP_STATE_ROOT/x1pro-button-fix.state" ] || fail "restart 失败后遗留状态"

# 兼容 2.1.7 的 F1L 两行恢复记录，并提供立即/稍后重启选择。
reset_fixture
mkdir -p -- "$OXP_CONFIG_DIR" "$OXP_STATE_ROOT"
awk 'BEGIN { done=0 } {
    if (!done && $0 ~ /^[[:space:]]*product_name:[[:space:]]*ONEXPLAYER F1[[:space:]]*$/) {
        sub(/product_name:[[:space:]]*ONEXPLAYER F1[[:space:]]*$/, "product_name: ONEXPLAYER F1L"); done=1
    }
    print
}' "$ZHOUKEER_OXP_F1L_SOURCE_CONFIG" > "$OXP_CONFIG_DIR/50-onexplayer_f1l.yaml"
printf 'was_enabled=0\nwas_active=0\n' > "$OXP_STATE_ROOT/f1l-button-fix.state"
oxp_install > "$TMP_ROOT/legacy-install.out" || fail "2.1.7 F1L 状态升级失败"
grep -Fxq 'version=2' "$OXP_STATE_ROOT/f1l-button-fix.state" || fail "旧 F1L 状态未升级"
grep -Fq '2.1.7' "$TMP_ROOT/legacy-install.out" || fail "旧 F1L 状态升级缺少提示"

: > "$SYSTEMCTL_CALLS"
ZHOUKEER_REBOOT_CHOICE=now
oxp_offer_reboot > "$TMP_ROOT/reboot-now.out" || fail "立即重启选择失败"
grep -Fxq 'reboot' "$SYSTEMCTL_CALLS" || fail "立即重启选择未调用 systemctl reboot"
[ "$MOCK_REBOOT" -eq 1 ] || fail "立即重启模拟状态未更新"

grep -Fq 'ONEXPLAYER F1L：SteamOS 3.10、InputPlumber 0.77.4' "$MODULE" || fail "模块缺少 F1L 实机验证说明"
grep -Fq 'ONEXPLAYER X1Pro：InputPlumber 0.77.7' "$MODULE" || fail "模块缺少 X1 Pro 实机验证说明"
for forbidden in 'steamos-readonly disable' 'efibootmgr' 'HHD 安装'; do
    if grep -Fq "$forbidden" "$MODULE"; then
        fail "模块包含禁止操作：$forbidden"
    fi
done
if rg -n '(^|[[:space:]])(eval|bash -c|sh -c)([[:space:]]|$)' "$MODULE" >/dev/null; then
    fail "特殊按键修复包含禁止的动态命令执行"
fi

echo "PASS: 壹号掌机 F1L/X1Pro 精确识别、唯一替换、HHD 冲突、备份恢复、幂等、回滚与重启选择模拟通过"
