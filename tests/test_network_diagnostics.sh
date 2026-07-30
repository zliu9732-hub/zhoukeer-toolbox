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
[ "${NETWORK_DNS_BLOCK:-0}" != "1" ] || { sleep 5; exit 1; }
echo '1.1.1.1 store.steampowered.com'
EOF
cat > "$BIN_DIR/timeout" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${NETWORK_TIMEOUT_LOG:?}"
[ "${1:-}" != "--foreground" ] || shift
seconds="${1:-1}"
[ "$#" -eq 0 ] || shift
"$@" & child=$!
(
    sleep "$seconds"
    kill -TERM "$child" >/dev/null 2>&1 || true
) & guard=$!
wait "$child"
status=$?
kill -TERM "$guard" >/dev/null 2>&1 || true
wait "$guard" >/dev/null 2>&1 || true
exit "$status"
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
    XDG_STATE_HOME="$TMP_ROOT/state" NETWORK_CURL_LOG="$TMP_ROOT/curl.log" NETWORK_TIMEOUT_LOG="$TMP_ROOT/timeout.log" \
    ZHOUKEER_NETWORK_CONNECT_TIMEOUT=1 ZHOUKEER_NETWORK_MAX_TIME=2 ZHOUKEER_NETWORK_DNS_TIMEOUT=1 \
    bash "$PROJECT_ROOT/modules/network.sh")"
printf '%s\n' "$output" | grep -Fq '下载连接有问题，工具箱会自动尝试可用线路' || fail "部分失败时没有给出自动回退建议"
grep -Fq -- '--connect-timeout 1' "$TMP_ROOT/curl.log" || fail "网络检测缺少连接超时"
grep -Fq -- '--max-time 2' "$TMP_ROOT/curl.log" || fail "网络检测缺少总超时"
grep -Fq '1 getent hosts store.steampowered.com' "$TMP_ROOT/timeout.log" || fail "DNS 检测缺少独立超时"
grep -Fq $'update-github\tfail' "$TMP_ROOT/state/zhoukeer-toolbox/source-status.tsv" || fail "未记录 GitHub 最近失败原因"
grep -Fq $'update-gitee\tok' "$TMP_ROOT/state/zhoukeer-toolbox/source-status.tsv" || fail "未记录 Gitee 最近成功时间"

# 状态从失败转为成功时，空的最近成功列不能令失败时间和原因错位。
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/source_status.sh"
SOURCE_STATUS_DIR="$TMP_ROOT/state/zhoukeer-toolbox"
SOURCE_STATUS_FILE="$SOURCE_STATUS_DIR/source-status.tsv"
failure_time="$(awk -F '\t' '$1 == "update-github" { print $5 }' "$SOURCE_STATUS_FILE")"
failure_reason="$(awk -F '\t' '$1 == "update-github" { print $6 }' "$SOURCE_STATUS_FILE")"
source_status_record update-github ok "连接恢复" >/dev/null
[ "$(awk -F '\t' '$1 == "update-github" { print $5 }' "$SOURCE_STATUS_FILE")" = "$failure_time" ] || \
    fail "失败转成功后最近失败时间错位"
[ "$(awk -F '\t' '$1 == "update-github" { print $6 }' "$SOURCE_STATUS_FILE")" = "$failure_reason" ] || \
    fail "失败转成功后最近失败原因丢失"

# 模拟解析命令卡住；网络检查必须由 DNS 专用 timeout 终止并记录失败。
HOME="$TMP_ROOT/home" PATH="$BIN_DIR:/usr/bin:/bin" \
    XDG_STATE_HOME="$TMP_ROOT/state-timeout" NETWORK_CURL_LOG="$TMP_ROOT/curl-timeout.log" \
    NETWORK_TIMEOUT_LOG="$TMP_ROOT/timeout-block.log" NETWORK_DNS_BLOCK=1 \
    ZHOUKEER_NETWORK_CONNECT_TIMEOUT=1 ZHOUKEER_NETWORK_MAX_TIME=2 ZHOUKEER_NETWORK_DNS_TIMEOUT=1 \
    bash "$PROJECT_ROOT/modules/network.sh" >/dev/null
grep -Fq $'dns\tfail' "$TMP_ROOT/state-timeout/zhoukeer-toolbox/source-status.tsv" || \
    fail "DNS 超时未记录失败"

echo "PASS: 网络诊断超时、DNS限时、并行检查和状态空列解析测试通过"
