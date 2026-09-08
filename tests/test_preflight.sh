#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
BIN_DIR="$TMP_ROOT/bin"
POWER_ROOT="$TMP_ROOT/power"
mkdir -p "$BIN_DIR" "$POWER_ROOT/BAT0" "$TMP_ROOT/home"

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$BIN_DIR/df" <<'EOF'
#!/bin/sh
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf '/dev/test 10000000 1 %s 1%% /\n' "${PREFLIGHT_TEST_AVAILABLE:?}"
EOF
cat > "$BIN_DIR/steamos-readonly" <<'EOF'
#!/bin/sh
echo enabled
EOF
chmod +x "$BIN_DIR"/*
printf '50\n' > "$POWER_ROOT/BAT0/capacity"

PREFLIGHT_TEST_AVAILABLE=5000000 HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_TEST_MODE=1 ZHOUKEER_PREFLIGHT_SKIP_NETWORK=1 \
    ZHOUKEER_POWER_SUPPLY_ROOT="$POWER_ROOT" ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/preflight-ok.txt" \
    bash "$PROJECT_ROOT/modules/preflight.sh" memory > "$TMP_ROOT/ok.output"
grep -Fq '检查通过，正在继续' "$TMP_ROOT/ok.output" || fail "正常条件没有通过预检"
if grep -Fq '详细信息' "$TMP_ROOT/ok.output"; then
    fail "预检成功仍向普通用户显示日志路径"
fi
grep -Fq '网络=此操作不需要联网，未检查' "$TMP_ROOT/preflight-ok.txt" || fail "虚拟内存预检仍错误要求联网"

# ChimeraOS 只允许复用 Decky 插件下载的预检；不能因此放开系统级预检。
chimera_decky_output="$(
    PROJECT_ROOT="$PROJECT_ROOT" HOME="$TMP_ROOT/home" \
        ZHOUKEER_TEST_MODE=0 ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/chimera-decky.txt" \
        bash -c '
            source "$PROJECT_ROOT/modules/preflight.sh"
            detect_platform() { IS_STEAMOS=0; IS_BAZZITE=0; IS_CHIMERAOS=1; }
            preflight_available_kib() { printf "%s\\n" 5000000; }
            preflight_network_ok() { return 0; }
            preflight_readonly_status() { return 2; }
            preflight_power_ok() { return 0; }
            run_preflight decky
        '
)"
printf '%s\n' "$chimera_decky_output" | grep -Fq '检查通过，正在继续' || \
    fail "ChimeraOS 的 Decky 预检仍被错误拦截"
if PROJECT_ROOT="$PROJECT_ROOT" HOME="$TMP_ROOT/home" ZHOUKEER_TEST_MODE=0 \
    bash -c '
        source "$PROJECT_ROOT/modules/preflight.sh"
        detect_platform() { IS_STEAMOS=0; IS_BAZZITE=0; IS_CHIMERAOS=1; }
        run_preflight memory
    ' >/dev/null 2>&1; then
    fail "ChimeraOS 的系统级预检被错误放行"
fi

if PREFLIGHT_TEST_AVAILABLE=100 HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_TEST_MODE=1 ZHOUKEER_PREFLIGHT_SKIP_NETWORK=1 \
    ZHOUKEER_POWER_SUPPLY_ROOT="$POWER_ROOT" ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/preflight-fail.txt" \
    bash "$PROJECT_ROOT/modules/preflight.sh" memory > "$TMP_ROOT/fail.output" 2>&1; then
    fail "空间不足时预检仍成功"
fi
grep -Fq '没有执行任何系统修改' "$TMP_ROOT/fail.output" || fail "预检失败缺少安全退出说明"

printf '10\n' > "$POWER_ROOT/BAT0/capacity"
if PREFLIGHT_TEST_AVAILABLE=5000000 HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_TEST_MODE=1 ZHOUKEER_PREFLIGHT_SKIP_NETWORK=1 \
    ZHOUKEER_POWER_SUPPLY_ROOT="$POWER_ROOT" ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/preflight-power.txt" \
    bash "$PROJECT_ROOT/modules/preflight.sh" decky >/dev/null 2>&1; then
    fail "低电量时预检仍成功"
fi

echo "PASS: 高风险预检成功、空间失败、低电量和安全退出测试通过"
