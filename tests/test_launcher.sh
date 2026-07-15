#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
CALL_LOG="$TMP_ROOT/konsole-call.log"
mkdir -p "$BIN_DIR" "$HOME_DIR/.local/share/konsole"
touch "$HOME_DIR/.local/share/konsole/ZhoukeerToolbox.profile"

cat > "$BIN_DIR/konsole" <<'SCRIPT'
#!/bin/bash
if [ "${1:-}" = "--help" ]; then
    printf '%s\n' "${FAKE_KONSOLE_HELP:-}"
    exit 0
fi
printf '%s\n' "$*" >> "$FAKE_KONSOLE_CALL_LOG"
exit 0
SCRIPT
chmod +x "$BIN_DIR/konsole"

run_launcher() {
    : > "$CALL_LOG"
    HOME="$HOME_DIR" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_KONSOLE_CALL_LOG="$CALL_LOG" \
    FAKE_KONSOLE_HELP="$1" \
        bash "$PROJECT_ROOT/launch.sh"
}

run_launcher $'--profile\n--workdir'
if grep -Fq -- '--geometry' "$CALL_LOG"; then
    echo "FAIL: 不支持 --geometry 时仍传入了该参数"
    exit 1
fi
grep -Fq -- '--profile' "$CALL_LOG"
grep -Fq -- '--workdir' "$CALL_LOG"

run_launcher $'--profile\n--workdir\n--geometry'
grep -Fq -- '--geometry 1220x740' "$CALL_LOG"

run_launcher $'--profile\n--workdir\n--fullscreen'
grep -Fq -- '--fullscreen' "$CALL_LOG"
if grep -Fq -- '--geometry' "$CALL_LOG"; then
    echo "FAIL: 仅支持 --fullscreen 时错误传入了 --geometry"
    exit 1
fi

echo "PASS: Konsole窗口参数兼容与回退测试通过"
