#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/onexplayer_x2mini_pro_fix.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export HOME="$TMP_ROOT/home"
export XDG_STATE_HOME="$TMP_ROOT/state"
export ZHOUKEER_AUTO_CONFIRM=1
export ZHOUKEER_OXPX2_PRODUCT_FILE="$TMP_ROOT/product-name"
export ZHOUKEER_OXPX2_VENDOR_FILE="$TMP_ROOT/vendor-name"
export ZHOUKEER_OXPX2_ROOT="$TMP_ROOT/root"
export ZHOUKEER_OXPX2_STATE_FILE="$TMP_ROOT/state/x2.state"
mkdir -p -- "$HOME" "$ZHOUKEER_OXPX2_ROOT" "$TMP_ROOT/fixtures"
printf 'ONEXPLAYER X2Mini PRO\n' > "$ZHOUKEER_OXPX2_PRODUCT_FILE"
printf 'ONE-NETBOOK\n' > "$ZHOUKEER_OXPX2_VENDOR_FILE"

# shellcheck disable=SC1090
source "$MODULE"

printf 'matches:\n  - dmi_data:\n      product_name: ONEXPLAYER X2Mini PRO\n' > "$TMP_ROOT/fixtures/device"
printf 'name: oxpx2m\nQuickAccess: {}\n' > "$TMP_ROOT/fixtures/map"
printf 'product_name = "ONEXPLAYER X2Mini PRO"\n[inputplumber]\ntarget_devices = ["deck-uhid", "keyboard", "mouse"]\n' > "$TMP_ROOT/fixtures/manager"
# 测试把固定上游哈希替换为本地模拟包哈希，网络下载仍通过受控下载器模拟。
OXPX2_SHA256[0]="$(sha256sum "$TMP_ROOT/fixtures/device" | awk '{print $1}')"
OXPX2_SHA256[1]="$(sha256sum "$TMP_ROOT/fixtures/map" | awk '{print $1}')"
OXPX2_SHA256[2]="$(sha256sum "$TMP_ROOT/fixtures/manager" | awk '{print $1}')"

CALLS="$TMP_ROOT/calls"
MOCK_STEAMOS=1
MOCK_UID=1000
MOCK_HHD=0
MOCK_ENABLED=0
MOCK_ACTIVE=0
MOCK_READONLY=enabled
MOCK_DOWNLOAD_FAIL=0
: > "$CALLS"

detect_platform() { IS_STEAMOS="$MOCK_STEAMOS"; }
id() { case "${1:-}" in -u) printf '%s\n' "$MOCK_UID" ;; *) command id "$@" ;; esac; }
pgrep() { [ "$MOCK_HHD" = 1 ]; }
log() { :; }
systemctl() {
    local original="$*" command_name unit
    printf 'systemctl %s\n' "$original" >> "$CALLS"
    if [ "${1:-}" = --user ]; then
        shift
        case "${1:-}:${!#:-}" in
            is-active:hhd.service) return 1 ;;
            *) return 0 ;;
        esac
    fi
    command_name="${1:-}"; shift || true; unit="${!#:-}"
    case "$command_name" in
        show) printf 'loaded\n' ;;
        is-active)
            case "$unit" in "$OXPX2_SERVICE") [ "$MOCK_ACTIVE" = 1 ] ;; hhd.service) return 1 ;; *) return 1 ;; esac ;;
        is-enabled) [ "$unit" = "$OXPX2_SERVICE" ] && [ "$MOCK_ENABLED" = 1 ] ;;
        enable) MOCK_ENABLED=1; case " $original " in *' --now '*) MOCK_ACTIVE=1 ;; esac ;;
        disable) MOCK_ENABLED=0 ;;
        restart) [ "$unit" = "$OXPX2_SERVICE" ] && MOCK_ACTIVE=1 ;;
        stop) MOCK_ACTIVE=0 ;;
        daemon-reload) return 0 ;;
        *) return 1 ;;
    esac
}
steamos-readonly() {
    printf 'readonly %s\n' "$*" >> "$CALLS"
    case "${1:-}" in status) printf '%s\n' "$MOCK_READONLY" ;; disable) MOCK_READONLY=disabled ;; enable) MOCK_READONLY=enabled ;; *) return 1 ;; esac
}
toolbox_sudo() { printf 'sudo %s\n' "$*" >> "$CALLS"; "$@"; }
download_with_gitee_mirror_fallback() {
    local mirror_id="$1" output="$4" expected="$3" name="$5" source
    printf 'download %s %s\n' "$mirror_id" "$2" >> "$CALLS"
    [ "$MOCK_DOWNLOAD_FAIL" = 0 ] || return 1
    case "$name" in
        *设备描述*) source="$TMP_ROOT/fixtures/device" ;;
        *按键映射*) source="$TMP_ROOT/fixtures/map" ;;
        *设备目标*) source="$TMP_ROOT/fixtures/manager" ;;
        *) return 1 ;;
    esac
    [ "$(sha256sum "$source" | awk '{print $1}')" = "$expected" ] || return 1
    cp -- "$source" "$output"
}

reset_fixture() {
    rm -rf -- "$ZHOUKEER_OXPX2_ROOT" "$XDG_STATE_HOME"
    mkdir -p -- "$ZHOUKEER_OXPX2_ROOT"
    printf 'ONEXPLAYER X2Mini PRO\n' > "$ZHOUKEER_OXPX2_PRODUCT_FILE"
    printf 'ONE-NETBOOK\n' > "$ZHOUKEER_OXPX2_VENDOR_FILE"
    : > "$CALLS"
    MOCK_STEAMOS=1; MOCK_UID=1000; MOCK_HHD=0; MOCK_ENABLED=0; MOCK_ACTIVE=0; MOCK_READONLY=enabled; MOCK_DOWNLOAD_FAIL=0
    OXPX2_READONLY_CHANGED=0; OXPX2_MUTATED=0
}

# 精确 DMI 和 HHD 检查必须发生在下载、只读保护和写入前。
reset_fixture
printf 'ONEXPLAYER X2 Mini PRO\n' > "$ZHOUKEER_OXPX2_PRODUCT_FILE"
if oxpx2_install > "$TMP_ROOT/not-exact.out" 2>&1; then fail "近似 DMI 仍允许安装"; fi
[ ! -s "$CALLS" ] || fail "不支持 DMI 触发了系统动作"

reset_fixture
MOCK_HHD=1
if oxpx2_install > "$TMP_ROOT/hhd.out" 2>&1; then fail "HHD 运行时仍允许安装"; fi
grep -Fq 'HHD 正在运行' "$TMP_ROOT/hhd.out" || fail "HHD 冲突提示缺失"
if grep -Eq 'download|readonly disable|sudo install' "$CALLS"; then fail "HHD 冲突后仍修改系统"; fi

# 下载失败必须早于只读保护和配置写入。
reset_fixture
MOCK_DOWNLOAD_FAIL=1
if oxpx2_install > "$TMP_ROOT/download-fail.out" 2>&1; then fail "下载失败仍返回成功"; fi
grep -Fq 'download ' "$CALLS" || fail "未走受控下载器"
if grep -Eq 'readonly disable|sudo install|sudo mv' "$CALLS"; then fail "下载失败后写入系统"; fi

# 安装应写入全部三项、恢复只读保护、启动 InputPlumber；恢复应还原空状态。
reset_fixture
oxpx2_install > "$TMP_ROOT/install.out" || fail "X2 Mini Pro 模拟安装失败"
oxpx2_verify_managed_files || fail "安装后配置哈希不一致"
[ -f "$OXPX2_STATE_FILE" ] || fail "安装后缺少恢复记录"
[ "$MOCK_READONLY" = enabled ] || fail "安装后未恢复只读保护"
[ "$MOCK_ENABLED" = 1 ] && [ "$MOCK_ACTIVE" = 1 ] || fail "安装后 InputPlumber 未启动"
grep -Fxq 'readonly disable' "$CALLS" || fail "未临时关闭只读保护"
grep -Fxq 'readonly enable' "$CALLS" || fail "未恢复只读保护"
grep -Fq 'systemctl enable --now inputplumber.service' "$CALLS" || fail "未启用 InputPlumber"
oxpx2_restore > "$TMP_ROOT/restore.out" || fail "X2 Mini Pro 模拟恢复失败"
[ ! -e "$OXPX2_STATE_FILE" ] || fail "恢复后状态记录未删除"
for target in "${OXPX2_TARGETS[@]}"; do [ ! -e "$target" ] || fail "恢复后仍保留 Renkit 创建文件：$target"; done

if grep -Eq '(^|[[:space:]])(eval|bash -c|sh -c)([[:space:]]|$)' "$MODULE"; then fail "模块包含禁止的动态命令执行"; fi
grep -Fq 'ONEXPLAYER X2Mini PRO' "$MODULE" || fail "模块缺少精确 DMI 限制"
grep -Fq 'deck-uhid' "$MODULE" || fail "模块缺少 SteamOS 虚拟设备目标校验"
grep -Fq 'steamos-readonly enable' "$MODULE" || fail "模块缺少只读保护恢复"
for mirror_id in oxpx2-device oxpx2-map oxpx2-manager; do
    grep -Fq "$mirror_id" "$MODULE" || fail "模块缺少国内镜像：$mirror_id"
done

echo "PASS: X2 Mini Pro 三点菜单修复的 DMI/HHD 限制、固定配置校验、只读保护恢复与撤销模拟通过"
