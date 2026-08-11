#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/console_accelerators.sh"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
CALLS_FILE="$TMP_ROOT/xdg-open.calls"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
EOF
cat > "$BIN_DIR/xdg-open" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >> "${CONSOLE_ACCELERATOR_TEST_CALLS:?}"
EOF
chmod +x "$BIN_DIR/uname" "$BIN_DIR/xdg-open"

bash -n "$MODULE" || fail "主机加速器模块语法检查失败"

for provider in qiyou xunyou uu; do
    output="$(
        PATH="$BIN_DIR:/usr/bin:/bin" \
        CONSOLE_ACCELERATOR_TEST_CALLS="$CALLS_FILE" \
        bash "$MODULE" "$provider"
    )" || fail "$provider 官方入口打开失败"
    printf '%s\n' "$output" | grep -Fq '没有可直接安装到 SteamOS 的官方 Linux 客户端' || \
        fail "$provider 缺少平台限制说明"
    printf '%s\n' "$output" | grep -Fq '不会下载 Windows 安装包' || \
        fail "$provider 缺少安全说明"
done

grep -Fqx 'https://www.qiyou.cn/main/ljb-overview' "$CALLS_FILE" || \
    fail "奇游没有打开官方主机加速页面"
grep -Fqx 'https://www.xunyou.com/zt/zhuji/index.html' "$CALLS_FILE" || \
    fail "迅游没有打开官方主机加速页面"
grep -Fqx 'https://uu.163.com/console/' "$CALLS_FILE" || \
    fail "UU没有打开官方主机加速页面"

if PATH="$BIN_DIR:/usr/bin:/bin" CONSOLE_ACCELERATOR_TEST_CALLS="$CALLS_FILE" \
    bash "$MODULE" unknown >/dev/null 2>&1; then
    fail "未知主机加速器动作不应成功"
fi

if rg -n 'curl|wget|sudo|pkexec|\.exe|wine' "$MODULE" >/dev/null 2>&1; then
    fail "主机加速器官方入口不应下载程序、提权或调用 Wine"
fi

echo "PASS: 奇游、迅游、UU 仅打开官方主机加速配置入口"
