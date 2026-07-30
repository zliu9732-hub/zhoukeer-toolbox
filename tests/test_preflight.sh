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
grep -Fq '准备检查通过' "$TMP_ROOT/ok.output" || fail "正常条件没有通过预检"
grep -Fq '网络=此操作不需要联网，未检查' "$TMP_ROOT/preflight-ok.txt" || fail "虚拟内存预检仍错误要求联网"

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
