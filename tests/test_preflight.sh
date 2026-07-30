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
path=""
for arg in "$@"; do path="$arg"; done
available="${PREFLIGHT_TEST_AVAILABLE:?}"
device="/dev/test"
mountpoint="/home"
if [ "${PREFLIGHT_TEST_SPLIT_SPACE:-0}" = "1" ] && [ "$path" = "${ZHOUKEER_PREFLIGHT_ROOT_PATH:-/}" ]; then
    available="${PREFLIGHT_TEST_ROOT_AVAILABLE:?}"
    device="/dev/root-test"
    mountpoint="/"
fi
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf '%s 10000000 1 %s 1%% %s\n' "$device" "$available" "$mountpoint"
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

printf '0\n' > "$POWER_ROOT/BAT0/capacity"
if PREFLIGHT_TEST_AVAILABLE=5000000 HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_TEST_MODE=1 ZHOUKEER_PREFLIGHT_SKIP_NETWORK=1 \
    ZHOUKEER_POWER_SUPPLY_ROOT="$POWER_ROOT" ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/preflight-empty-battery.txt" \
    bash "$PROJECT_ROOT/modules/preflight.sh" decky >/dev/null 2>&1; then
    fail "电量为 0% 时预检仍成功"
fi

printf '50\n' > "$POWER_ROOT/BAT0/capacity"
if PREFLIGHT_TEST_AVAILABLE=5000000 PREFLIGHT_TEST_ROOT_AVAILABLE=100 PREFLIGHT_TEST_SPLIT_SPACE=1 \
    HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_TEST_MODE=1 ZHOUKEER_PREFLIGHT_SKIP_NETWORK=1 \
    ZHOUKEER_POWER_SUPPLY_ROOT="$POWER_ROOT" ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/preflight-root-space.txt" \
    bash "$PROJECT_ROOT/modules/preflight.sh" system-update >/dev/null 2>&1; then
    fail "HOME 空间充足但系统分区不足时预检仍成功"
fi
grep -Fq '用户存储空间=正常' "$TMP_ROOT/preflight-root-space.txt" || fail "未检查 HOME 空间"
grep -Fq '系统空间=不足' "$TMP_ROOT/preflight-root-space.txt" || fail "未检查系统分区空间"

PREFLIGHT_TEST_AVAILABLE=5000000 HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_TEST_MODE=1 ZHOUKEER_PREFLIGHT_SKIP_NETWORK=1 \
    ZHOUKEER_POWER_SUPPLY_ROOT="$POWER_ROOT" ZHOUKEER_PREFLIGHT_DETAIL_FILE="$TMP_ROOT/preflight-deduplicate.txt" \
    bash "$PROJECT_ROOT/modules/preflight.sh" system-update >/dev/null
grep -Fq '系统空间=与用户存储位于同一文件系统，未重复检查' "$TMP_ROOT/preflight-deduplicate.txt" || \
    fail "同一文件系统没有去重空间检查"

echo "PASS: 高风险预检双分区空间、去重、0%电量和安全退出测试通过"
