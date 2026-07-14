#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/plugin_store.sh"
TMP_ROOT="$(mktemp -d)"
HOME_DIR="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
SOURCE_DIR="$TMP_ROOT/source/Lossless Scaling"
ARCHIVE="$TMP_ROOT/legal-local-backup.tar.gz"
STATE_DIR="$TMP_ROOT/state"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p \
    "$HOME_DIR/.local/share/Steam/steamapps/common" \
    "$BIN_DIR" \
    "$SOURCE_DIR" \
    "$STATE_DIR"
printf 'local user backup fixture\n' > "$SOURCE_DIR/LosslessScaling.exe"
tar -czf "$ARCHIVE" -C "$TMP_ROOT/source" "Lossless Scaling"

cat > "$BIN_DIR/xdg-open" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${LOSSLESS_TEST_STATE:?}/xdg-open.calls"
EOF
chmod +x "$BIN_DIR/xdg-open"

output="$(
    PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" \
        HOME="$HOME_DIR" \
        LOSSLESS_TEST_STATE="$STATE_DIR" \
        bash "$MODULE" lsfg-import "$ARCHIVE"
)" || fail "合法本地备份导入失败"

TARGET="$HOME_DIR/.local/share/Steam/steamapps/common/Lossless Scaling"
[ -f "$TARGET/LosslessScaling.exe" ] || fail "备份没有导入 Steam common 目录"
attempt=0
while [ ! -f "$STATE_DIR/xdg-open.calls" ] && [ "$attempt" -lt 20 ]; do
    sleep 0.1
    attempt=$((attempt + 1))
done
grep -Fq 'steam://install/993090' "$STATE_DIR/xdg-open.calls" || \
    fail "导入后没有交给 Steam 验证授权和文件"
printf '%s\n' "$output" | grep -Fq '由 Steam 检查正版授权' || \
    fail "导入完成后缺少正版授权提示"

# 已有目录必须保持原样，不能被第二个压缩包覆盖。
printf 'keep existing\n' > "$TARGET/customer-file.txt"
printf 'replacement\n' > "$SOURCE_DIR/LosslessScaling.exe"
tar -czf "$ARCHIVE" -C "$TMP_ROOT/source" "Lossless Scaling"
second_output="$(
    PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" \
        HOME="$HOME_DIR" \
        LOSSLESS_TEST_STATE="$STATE_DIR" \
        bash "$MODULE" lsfg-import "$ARCHIVE"
)" || fail "已有目录处理不应报错"
[ "$(cat "$TARGET/LosslessScaling.exe")" = 'local user backup fixture' ] || \
    fail "已有 Steam 文件被覆盖"
[ "$(cat "$TARGET/customer-file.txt")" = 'keep existing' ] || \
    fail "已有用户文件被覆盖"
printf '%s\n' "$second_output" | grep -Fq '未覆盖任何文件' || \
    fail "已有目录时缺少不覆盖提示"

if grep -Eq '123clouddisk.*Lossless|Lossless[^[:space:]]*\.rar.*https?://' "$MODULE"; then
    fail "模块中不应包含付费软件本体下载源"
fi

echo "PASS: Lossless Scaling本地合法备份导入与不覆盖测试通过"
