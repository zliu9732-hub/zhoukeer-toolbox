#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
HOME_DIR="$TMP_ROOT/home"
OUT_DIR="$TMP_ROOT/out"
BIN_DIR="$TMP_ROOT/bin"
mkdir -p "$HOME_DIR/Desktop" "$OUT_DIR" "$BIN_DIR"

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$TMP_ROOT/sensitive.txt" <<EOF
user=deck home=$HOME_DIR
IPv4=192.168.31.88 gateway=10.0.0.1
IPv6=fe80::1234:abcd MAC=AA:BB:CC:DD:EE:FF
password=hunter2
Token=abc123
Cookie=session-value
proxy_url=https://name:secret@proxy.example:7890
远程协助临时码：998877
EOF

HOME="$HOME_DIR" USER=deck bash "$PROJECT_ROOT/modules/diagnostics.sh" redact \
    "$TMP_ROOT/sensitive.txt" "$TMP_ROOT/redacted.txt"
for secret in deck "$HOME_DIR" 192.168.31.88 10.0.0.1 fe80::1234:abcd AA:BB:CC:DD:EE:FF hunter2 abc123 session-value secret 998877; do
    ! grep -Fq "$secret" "$TMP_ROOT/redacted.txt" || fail "脱敏后仍包含：$secret"
done
grep -Fq '[HOME]' "$TMP_ROOT/redacted.txt" || fail "HOME 未替换为安全标记"
grep -Fq '[IP已隐藏]' "$TMP_ROOT/redacted.txt" || fail "IP 未脱敏"

cat > "$BIN_DIR/ip" <<'EOF'
#!/bin/sh
echo 'default via 192.168.1.1 dev wlan0'
EOF
cat > "$BIN_DIR/getent" <<'EOF'
#!/bin/sh
echo '1.1.1.1 store.steampowered.com'
EOF
cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
echo called >> "${DIAGNOSTIC_CURL_LOG:?}"
exit 0
EOF
cat > "$BIN_DIR/flatpak" <<'EOF'
#!/bin/sh
echo 'flathub-cn https://mirror.sjtu.edu.cn/flathub false'
EOF
cat > "$BIN_DIR/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$BIN_DIR"/*
printf '管理员密码=do-not-package\nerror token=log-secret from 192.168.1.20\n' > "$HOME_DIR/Desktop/管理员密码.txt"
mkdir -p "$TMP_ROOT/logs"
printf 'error token=log-secret from 192.168.1.20\n' > "$TMP_ROOT/logs/toolbox.log"

bundle_output="$(
    HOME="$HOME_DIR" USER=deck PATH="$BIN_DIR:/usr/bin:/bin" \
    XDG_STATE_HOME="$TMP_ROOT/state" ZHOUKEER_DIAGNOSTIC_OUTPUT_DIR="$OUT_DIR" DIAGNOSTIC_CURL_LOG="$TMP_ROOT/curl.log" \
    bash "$PROJECT_ROOT/modules/diagnostics.sh" bundle
)"
archive="$(printf '%s\n' "$bundle_output" | sed -n 's/^保存位置：//p')"
[ -f "$archive" ] || fail "诊断包未生成"
[ ! -e "$TMP_ROOT/curl.log" ] || fail "生成诊断包时发起了网络请求"
[ "$(stat -f '%Lp' "$archive" 2>/dev/null || stat -c '%a' "$archive")" = "600" ] || fail "诊断包权限不是 600"
listing="$(tar -tzf "$archive")"
for name in 基础信息.txt 网络检查摘要.txt 下载与更新状态.txt 最近错误摘要.txt 请先阅读.txt; do
    printf '%s\n' "$listing" | grep -Fq "$name" || fail "诊断包缺少 $name"
done
! printf '%s\n' "$listing" | grep -Eqi '管理员密码|password|token|cookie' || fail "诊断包包含敏感文件名"
mkdir -p "$TMP_ROOT/extract"
tar -xzf "$archive" -C "$TMP_ROOT/extract"
if grep -R -E 'do-not-package|log-secret|192\.168\.1\.20' "$TMP_ROOT/extract"; then
    fail "诊断包内容仍包含敏感信息"
fi

echo "PASS: 诊断包脱敏、本地生成、权限和敏感文件排除测试通过"
