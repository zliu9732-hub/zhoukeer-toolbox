#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/f1_screen_fix.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$TMP_ROOT/home" "$TMP_ROOT/steamos" "$TMP_ROOT/logs"
: > "$TMP_ROOT/steamos/gamescope-session"
printf 'ONEXPLAYER F1\n' > "$TMP_ROOT/product-f1"
printf 'ONEXPLAYER F1 OLED\n' > "$TMP_ROOT/product-f1-8840u"
printf 'ONEXPLAYER F1L\n' > "$TMP_ROOT/product-f1l-8840u-oled"
printf 'Other Device\n' > "$TMP_ROOT/product-other"

HOME="$TMP_ROOT/home"
ZHOUKEER_F1_PRODUCT_FILE="$TMP_ROOT/product-f1"
ZHOUKEER_F1_GAMESCOPE_SESSION="$TMP_ROOT/steamos/gamescope-session"

# shellcheck disable=SC1090
source "$MODULE"

LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
SYSTEMCTL_CALLS="$TMP_ROOT/systemctl.log"

detect_platform() { IS_STEAMOS=1; }
require_command() { return 0; }
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$SYSTEMCTL_CALLS"
    case "$*" in
        *'--user daemon-reload') return 0 ;;
        *'reboot') return 0 ;;
        *'--user show gamescope-session.service -p ExecStart --value')
            printf '%s\n' "$F1_SESSION_WRAPPER"
            return 0
            ;;
        *) return 0 ;;
    esac
}

# 7840U、8840U OLED 实机 DMI 与兼容名称必须允许，其他近似名称仍必须拒绝。
F1_PRODUCT_FILE="$TMP_ROOT/product-f1"
f1_is_target_device || fail "ONEXPLAYER F1 未被识别为目标设备"
F1_PRODUCT_FILE="$TMP_ROOT/product-f1-8840u"
f1_is_target_device || fail "ONEXPLAYER F1 OLED 未被识别为目标设备"
F1_PRODUCT_FILE="$TMP_ROOT/product-f1l-8840u-oled"
f1_is_target_device || fail "ONEXPLAYER F1L 未被识别为 8840U OLED 目标设备"
F1_PRODUCT_FILE="$TMP_ROOT/product-other"
if f1_is_target_device; then
    fail "非目标设备被识别为飞行家 F1"
fi

# 非目标设备必须拒绝安装且不创建任何文件。
F1_PRODUCT_FILE="$TMP_ROOT/product-other"
if f1_install > "$TMP_ROOT/not-f1.out" 2>&1; then
    fail "非 ONEXPLAYER F1 设备仍允许安装修复"
fi
grep -Fq '不适用' "$TMP_ROOT/not-f1.out" || fail "非目标设备缺少不适用提示"
[ ! -e "$HOME/.local/gamescope-f1" ] || fail "非目标设备创建了修复目录"
[ ! -e "$HOME/.config/systemd/user/gamescope-session.service.d" ] || \
    fail "非目标设备创建了 systemd override"

# gamescope-session 不存在时必须停止安装。
F1_PRODUCT_FILE="$TMP_ROOT/product-f1l-8840u-oled"
F1_GAMESCOPE_SESSION="$TMP_ROOT/missing-session"
if f1_install > "$TMP_ROOT/missing-session.out" 2>&1; then
    fail "gamescope-session 不存在时仍允许安装"
fi
grep -Fq '未找到' "$TMP_ROOT/missing-session.out" || \
    fail "缺少 gamescope-session 缺失提示"
[ ! -e "$HOME/.local/gamescope-f1" ] || \
    fail "gamescope-session 缺失时创建了修复目录"

F1_GAMESCOPE_SESSION="$TMP_ROOT/steamos/gamescope-session"
: > "$SYSTEMCTL_CALLS"
if ! f1_install > "$TMP_ROOT/install.out"; then
    fail "F1 安装修复失败"
fi

WRAPPER="$HOME/.local/gamescope-f1/bin/gamescope"
SESSION_WRAPPER="$HOME/.local/gamescope-f1/session-wrapper"
OVERRIDE="$HOME/.config/systemd/user/gamescope-session.service.d/override.conf"
[ -x "$WRAPPER" ] || fail "gamescope wrapper 未创建或不可执行"
[ -x "$SESSION_WRAPPER" ] || fail "session wrapper 未创建或不可执行"
[ -f "$OVERRIDE" ] || fail "systemd override 未创建"
grep -Fq '#!/bin/bash' "$WRAPPER" || fail "gamescope wrapper 缺少 shebang"
grep -Fq 'ONEXPLAYER F1' "$WRAPPER" || fail "gamescope wrapper 缺少机型判断"
grep -Fq 'ONEXPLAYER F1 OLED' "$WRAPPER" || fail "gamescope wrapper 缺少 8840U OLED 机型判断"
grep -Fq 'ONEXPLAYER F1L' "$WRAPPER" || fail "gamescope wrapper 缺少 8840U OLED 实机 DMI 判断"
grep -Fq -- '--force-orientation left' "$WRAPPER" || \
    fail "gamescope wrapper 缺少方向参数"
grep -Fq '/usr/bin/gamescope' "$WRAPPER" || fail "gamescope wrapper 路径错误"
grep -Fq 'export PATH="$HOME/.local/gamescope-f1/bin:$PATH"' "$SESSION_WRAPPER" || \
    fail "session wrapper 缺少 PATH 前置"
grep -Fq 'exec /usr/lib/steamos/gamescope-session "$@"' "$SESSION_WRAPPER" || \
    fail "session wrapper 未 exec 原启动入口"
grep -Fxq '[Service]' "$OVERRIDE" || fail "override 缺少 [Service]"
grep -Fxq 'ExecStart=' "$OVERRIDE" || fail "override 未清空原 ExecStart"
grep -Fxq 'ExecStart=%h/.local/gamescope-f1/session-wrapper' "$OVERRIDE" || \
    fail "override 未指向 session wrapper"
grep -Fq 'daemon-reload' "$SYSTEMCTL_CALLS" || fail "安装后未刷新 systemd 用户配置"
grep -Fq '完成，重启 SteamOS 后生效' "$TMP_ROOT/install.out" || \
    fail "安装成功提示不明确"
bash -n "$WRAPPER" || fail "gamescope wrapper 语法错误"
bash -n "$SESSION_WRAPPER" || fail "session wrapper 语法错误"

# 重复安装必须保持幂等，不能破坏已有文件。
F1_PRODUCT_FILE="$TMP_ROOT/product-f1"
if ! f1_install > "$TMP_ROOT/reinstall.out"; then
    fail "重复安装修复失败"
fi
[ -x "$WRAPPER" ] || fail "重复安装后 wrapper 丢失"
[ -f "$OVERRIDE" ] || fail "重复安装后 override 丢失"
grep -Fq '完成，重启 SteamOS 后生效' "$TMP_ROOT/reinstall.out" || \
    fail "重复安装缺少完成提示"

# 状态检查应能区分已安装与未安装，并验证 override 生效。
if ! f1_status > "$TMP_ROOT/status.out"; then
    fail "已安装状态检查失败"
fi
grep -Fq '已安装' "$TMP_ROOT/status.out" || fail "状态检查未识别已安装"
grep -Fq '已生效' "$TMP_ROOT/status.out" || fail "状态检查未识别 override 生效"

rm -rf "$HOME/.config/systemd/user/gamescope-session.service.d"
if ! f1_status > "$TMP_ROOT/status-missing.out"; then
    fail "未安装状态检查失败"
fi
grep -Fq '未安装' "$TMP_ROOT/status-missing.out" || fail "状态检查未识别未安装"

# 卸载应删除两个用户级位置并刷新 systemd；重复卸载必须安全。
: > "$SYSTEMCTL_CALLS"
if ! f1_uninstall > "$TMP_ROOT/uninstall.out"; then
    fail "卸载修复失败"
fi
[ ! -e "$HOME/.local/gamescope-f1" ] || fail "卸载后 gamescope-f1 目录仍存在"
[ ! -e "$HOME/.config/systemd/user/gamescope-session.service.d" ] || \
    fail "卸载后 systemd override 目录仍存在"
grep -Fq 'daemon-reload' "$SYSTEMCTL_CALLS" || fail "卸载后未刷新 systemd 用户配置"
grep -Fq '已卸载' "$TMP_ROOT/uninstall.out" || fail "卸载提示不明确"
if ! f1_uninstall > "$TMP_ROOT/uninstall-again.out"; then
    fail "重复卸载失败"
fi
grep -Fq '无需卸载' "$TMP_ROOT/uninstall-again.out" || fail "重复卸载提示不明确"

# “立即重启”只调用用户级 systemctl reboot，不使用 sudo。
: > "$SYSTEMCTL_CALLS"
if ! f1_reboot > "$TMP_ROOT/reboot.out"; then
    fail "立即重启命令失败"
fi
grep -Fq 'systemctl reboot' "$SYSTEMCTL_CALLS" || fail "立即重启未调用 systemctl reboot"

echo "PASS: 飞行家 F1 屏幕方向修复安装、状态、卸载、幂等与平台保护模拟通过"
