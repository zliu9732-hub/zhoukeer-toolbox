#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
BIN_DIR="$TMP_ROOT/bin"
mkdir -p "$BIN_DIR" "$TMP_ROOT/home"

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$BIN_DIR/ip" <<'EOF'
#!/bin/sh
case " $* " in *' -6 '*) exit 0 ;; *) echo 'default via 192.168.1.1 dev wlan0' ;; esac
EOF
cat > "$BIN_DIR/getent" <<'EOF'
#!/bin/sh
echo '1.1.1.1 store.steampowered.com'
EOF
cat > "$BIN_DIR/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${NETWORK_CURL_LOG:?}"
case "$*" in *github.com*|*raw.githubusercontent.com*) exit 22 ;; *) exit 0 ;; esac
EOF
chmod +x "$BIN_DIR"/*

output="$(HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    XDG_STATE_HOME="$TMP_ROOT/state" NETWORK_CURL_LOG="$TMP_ROOT/curl.log" \
    ZHOUKEER_NETWORK_CONNECT_TIMEOUT=1 ZHOUKEER_NETWORK_MAX_TIME=2 \
    bash "$PROJECT_ROOT/modules/network.sh")"
printf '%s\n' "$output" | grep -Fq '下载连接有问题，Renkit会自动尝试可用线路' || fail "部分失败时没有给出自动回退建议"
grep -Fq -- '--connect-timeout 1' "$TMP_ROOT/curl.log" || fail "网络检测缺少连接超时"
grep -Fq -- '--max-time 2' "$TMP_ROOT/curl.log" || fail "网络检测缺少总超时"
grep -Fq $'update-github\tfail' "$TMP_ROOT/state/zhoukeer-toolbox/source-status.tsv" || fail "未记录 GitHub 最近失败原因"
grep -Fq $'update-gitee\tok' "$TMP_ROOT/state/zhoukeer-toolbox/source-status.tsv" || fail "未记录 Gitee 最近成功时间"

echo "PASS: 网络诊断超时、并行检查、失败建议和状态记录测试通过"
