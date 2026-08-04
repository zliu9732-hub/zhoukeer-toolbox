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

PAYLOAD_FILE="$TMP_ROOT/payload.json"
python3 - "$PAYLOAD_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump({
        "tab": "SharedJSContext",
        "run_async": True,
        "code": '(async function(){const m="zhoukeer-test-marker";return m+":ok";})()',
    }, handle)
PY

response="$(python3 "$PROJECT_ROOT/scripts/decky_ws_call.py" \
    --token "test-token" \
    --payload-file "$PAYLOAD_FILE" \
    --base-url "http://127.0.0.1:$WS_PORT" \
    --timeout 5)"
printf '%s\n' "$response" | grep -Fq 'zhoukeer-test-marker:ok' || \
    FAIL "Decky WebSocket 调用未返回 marker"

if python3 "$PROJECT_ROOT/scripts/decky_ws_call.py" \
    --token "" \
    --payload-file "$PAYLOAD_FILE" \
    --base-url "http://127.0.0.1:$WS_PORT" >/dev/null 2>&1; then
    FAIL "空 token 不应被接受"
fi

echo "PASS: Decky WebSocket execute_in_tab 调用测试通过"
