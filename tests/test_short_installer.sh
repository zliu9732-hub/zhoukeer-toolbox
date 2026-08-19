#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

BIN_DIR="$TMP_ROOT/bin"
CURL_LOG="$TMP_ROOT/curl.log"
EXEC_LOG="$TMP_ROOT/exec.log"
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
set -u
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
printf '%s\n' "$url" >> "$FAKE_CURL_LOG"
case "$url" in
    "$FAKE_GITEE_URL")
        [ "${FAKE_GITEE_MODE:-fail}" = success ] || exit 22
        ;;
    "$FAKE_GITHUB_URL")
        if [ "${FAKE_GITHUB_MODE:-html}" = html ]; then
            printf '%s\n' '<!doctype html><title>错误页面</title>' > "$output"
            exit 0
        fi
        ;;
    "$FAKE_DOMAIN_URL") ;;
    *) exit 22 ;;
esac
cat > "$output" <<'BOOTSTRAP'
#!/bin/bash
printf '%s\n' "$*" > "$FAKE_EXEC_LOG"
BOOTSTRAP
SCRIPT
chmod +x "$BIN_DIR/curl"

run_entry() {
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_CURL_LOG="$CURL_LOG" \
    FAKE_EXEC_LOG="$EXEC_LOG" \
    FAKE_GITEE_URL="https://gitee.test/bootstrap.sh" \
    FAKE_GITHUB_URL="https://github.test/bootstrap.sh" \
    FAKE_DOMAIN_URL="https://domain.test/bootstrap.sh" \
    ZHOUKEER_GITEE_BOOTSTRAP_URL="https://gitee.test/bootstrap.sh" \
    ZHOUKEER_GITHUB_BOOTSTRAP_URL="https://github.test/bootstrap.sh" \
    ZHOUKEER_DOMAIN_BOOTSTRAP_URL="https://domain.test/bootstrap.sh" \
        bash "$PROJECT_ROOT/i" --dry-run
}

: > "$CURL_LOG"
FAKE_GITEE_MODE=success FAKE_GITHUB_MODE=valid run_entry
grep -Fxq 'https://gitee.test/bootstrap.sh' "$CURL_LOG"
[ "$(wc -l < "$CURL_LOG" | tr -d ' ')" = 1 ] || {
    echo "FAIL: Gitee 有效时短入口仍请求了备用源" >&2
    exit 1
}
grep -Fxq -- '--dry-run' "$EXEC_LOG"

: > "$CURL_LOG"
: > "$EXEC_LOG"
FAKE_GITEE_MODE=fail FAKE_GITHUB_MODE=html run_entry
expected_urls="$(cat <<'URLS'
https://gitee.test/bootstrap.sh
https://github.test/bootstrap.sh
https://domain.test/bootstrap.sh
URLS
)"
[ "$(cat "$CURL_LOG")" = "$expected_urls" ] || {
    echo "FAIL: 短入口没有按 Gitee、GitHub、域名顺序安全回退" >&2
    exit 1
}
grep -Fxq -- '--dry-run' "$EXEC_LOG" || {
    echo "FAIL: GitHub HTML 响应后没有通过域名安装器继续" >&2
    exit 1
}

grep -Fq 'https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/bootstrap.sh' \
    "$PROJECT_ROOT/i" || {
    echo "FAIL: 短入口没有默认 GitHub Raw 备用源" >&2
    exit 1
}
grep -Fq 'https://jktool.icu/bootstrap.sh' "$PROJECT_ROOT/i" || {
    echo "FAIL: 短入口没有默认域名自身备用源" >&2
    exit 1
}

echo "PASS: jktool.icu 短安装入口逐源校验与安全回退测试通过"
