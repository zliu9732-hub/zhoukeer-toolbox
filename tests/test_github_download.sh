#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
BIN_DIR="$TEST_ROOT/bin"
CALLS_FILE="$TEST_ROOT/curl.calls"
PAYLOAD="$TEST_ROOT/payload.zip"
OUTPUT="$TEST_ROOT/output.zip"
mkdir -p "$BIN_DIR"
printf 'verified package payload\n' > "$PAYLOAD"

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/bash
output=""
write_out=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output|-o) output="$2"; shift 2 ;;
        --write-out|-w) write_out="$2"; shift 2 ;;
        --connect-timeout|--max-time|--proto|--proto-redir|--retry|--retry-delay|--speed-limit|--speed-time|--proxy)
            shift 2
            ;;
        --*) shift ;;
        *) url="$1"; shift ;;
    esac
done
if [ -n "$write_out" ]; then
    printf 'probe|%s\n' "$url" >> "${GITHUB_TEST_CALLS:?}"
    case "$url" in
        *fast.invalid*) printf '0.10' ;;
        *slow.invalid*) printf '0.80' ;;
        *) printf '0.50' ;;
    esac
    exit 0
fi
printf 'download|%s\n' "$url" >> "${GITHUB_TEST_CALLS:?}"
if [ "${GITHUB_TEST_FAIL_DOWNLOAD:-0}" = "1" ]; then
    exit 22
fi
case "$url" in
    *fast.invalid*) cp "${GITHUB_TEST_PAYLOAD:?}" "$output" ;;
    *) exit 22 ;;
esac
EOF
chmod +x "$BIN_DIR/curl"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/utils/github_download.sh"
GITHUB_MIRRORS="https://slow.invalid/{url} https://fast.invalid/{url}"
GITHUB_PROBE_CONNECT_TIMEOUT=1
GITHUB_PROBE_MAX_TIME=1
GITHUB_CONNECT_TIMEOUT=1
GITHUB_MAX_TIME=5
GITHUB_RETRIES=1
GITHUB_MIN_SPEED_BYTES=1
GITHUB_MIN_SPEED_TIME=1
export PATH="$BIN_DIR:/usr/bin:/bin"
export GITHUB_TEST_CALLS="$CALLS_FILE"
export GITHUB_TEST_PAYLOAD="$PAYLOAD"

url="https://raw.githubusercontent.com/example/project/main/archive.zip"
expected="$(shasum -a 256 "$PAYLOAD" | awk '{print $1}')"
download_github_file "$url" "$OUTPUT" "$expected" "测试包"
cmp "$PAYLOAD" "$OUTPUT" || { echo "FAIL: 下载结果不匹配" >&2; exit 1; }

first_download="$(grep '^download|' "$CALLS_FILE" | head -n 1)"
case "$first_download" in
    download\|https://fast.invalid/*) ;;
    *) echo "FAIL: 未优先使用测速最快的镜像" >&2; exit 1 ;;
esac

printf 'keep existing file\n' > "$OUTPUT"
export GITHUB_TEST_FAIL_DOWNLOAD=1
if download_github_file "$url" "$OUTPUT" "$expected" "失败测试包" >/dev/null 2>&1; then
    echo "FAIL: 所有下载源失败时仍返回成功" >&2
    exit 1
fi
grep -Fxq 'keep existing file' "$OUTPUT" || {
    echo "FAIL: 下载失败破坏了现有文件" >&2
    exit 1
}
find "$TEST_ROOT" -maxdepth 1 -name 'output.zip.part.*' | grep -q . && {
    echo "FAIL: 下载失败后遗留临时文件" >&2
    exit 1
}

echo "PASS: GitHub 镜像并行排序、校验和原子回退测试通过"
