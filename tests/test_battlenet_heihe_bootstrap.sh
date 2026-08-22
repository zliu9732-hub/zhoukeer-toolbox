#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

BIN_DIR="$TMP_ROOT/bin"
FAKE_BASE="https://gitee.test/repo/raw/main"
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output|-o) output="$2"; shift 2 ;;
        --output=*) output="${1#*=}"; shift ;;
        --connect-timeout|--max-time|--retry|--retry-delay) shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
clean_url="${url%%\?*}"
case "$clean_url" in
    "$FAKE_BASE/dist/zhoukeer-battlenet-heihe-"*.tar.gz.sha256)
        cp "$PROJECT_ROOT/dist/$(basename "$clean_url")" "$output" ;;
    "$FAKE_BASE/dist/zhoukeer-battlenet-heihe-"*.tar.gz)
        if [ "${FAKE_BAD_PACKAGE:-0}" = "1" ]; then
            printf 'not a real package\n' > "$output"
        else
            cp "$PROJECT_ROOT/dist/$(basename "$clean_url")" "$output"
        fi
        ;;
    *)
        exit 22
        ;;
esac
SCRIPT
chmod +x "$BIN_DIR/curl"

run_bootstrap() {
    PROJECT_ROOT="$PROJECT_ROOT" FAKE_BASE="$FAKE_BASE" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_STANDALONE_BASE="$FAKE_BASE" \
    ZHOUKEER_STANDALONE_DIR="$TMP_ROOT/tool" \
    HOME="$TMP_ROOT/home" \
        bash "$PROJECT_ROOT/standalone/battlenet-heihe/bootstrap.sh" "$@"
}

if run_bootstrap > "$TMP_ROOT/run.out" 2>&1; then
    echo "FAIL: macOS 上一行引导没有拒绝执行" >&2
    exit 1
fi
grep -Fq '仅支持 SteamOS' "$TMP_ROOT/run.out" || {
    echo "FAIL: 一行引导没有把平台提示透传出来" >&2
    exit 1
}
grep -Fq 'V2.0.1' "$TMP_ROOT/run.out" || {
    echo "FAIL: 独立工具没有与 Renkit 主版本解耦" >&2
    exit 1
}
[ -x "$TMP_ROOT/tool/install.sh" ] || {
    echo "FAIL: 一行引导没有解压出 install.sh" >&2
    exit 1
}
grep -Fq '校验' "$TMP_ROOT/run.out" || {
    echo "FAIL: 一行引导没有显示完整性校验步骤" >&2
    exit 1
}

if FAKE_BAD_PACKAGE=1 run_bootstrap > "$TMP_ROOT/bad.out" 2>&1; then
    echo "FAIL: 坏包仍被一行引导接受" >&2
    exit 1
fi
grep -Fq 'SHA256 校验失败' "$TMP_ROOT/bad.out" || {
    echo "FAIL: 坏包没有提示 SHA256 校验失败" >&2
    exit 1
}

echo "PASS: 战网+黑盒工坊一行引导下载、校验、解压和平台保护测试通过"
