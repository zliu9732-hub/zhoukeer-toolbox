#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
WS_PID=""
trap 'rm -rf -- "$TMP_ROOT"; [ -n "$WS_PID" ] && kill "$WS_PID" 2>/dev/null || true' EXIT

FAIL() {
    echo "FAIL: $*" >&2
    exit 1
}

PORT_FILE="$TMP_ROOT/ws-port"
python3 "$PROJECT_ROOT/tests/mock_decky_ws_server.py" "$PORT_FILE" &
WS_PID=$!
for _ in $(seq 1 50); do
    [ -s "$PORT_FILE" ] && break
    sleep 0.1
done
[ -s "$PORT_FILE" ] || FAIL "mock Decky WebSocket 服务未启动"
WS_PORT="$(tr -d '\r\n' < "$PORT_FILE")"

output="$(python3 "$PROJECT_ROOT/scripts/decky_probe.py" \
    --token "test-token" \
    --appids "3041426322,2638177698" \
    --base-url "http://127.0.0.1:$WS_PORT" \
    --timeout 5)"
found_tab="$(printf '%s\n' "$output" | awk -F '\t' '$2=="true" {print $1; exit}')"
[ "$found_tab" = "Steam" ] || FAIL "probe 未在 Steam tab 找到快捷方式"

echo "PASS: Decky tab 探测测试通过"
