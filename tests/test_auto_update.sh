#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

BIN_DIR="$TMP_ROOT/bin"
INSTALL_DIR="$TMP_ROOT/install"
RELEASE_DIR="$TMP_ROOT/release"
REMOTE_DIR="$TMP_ROOT/remote"
STATE_DIR="$TMP_ROOT/state"
CURL_LOG="$STATE_DIR/curl.log"
mkdir -p \
    "$BIN_DIR" "$INSTALL_DIR" "$RELEASE_DIR" "$REMOTE_DIR/dist" \
    "$STATE_DIR" "$TMP_ROOT/home"

cp "$PROJECT_ROOT/update.sh" "$INSTALL_DIR/update.sh"
grep -Fq 'VERSION_CONNECT_TIMEOUT="${ZHOUKEER_VERSION_CONNECT_TIMEOUT:-8}"' "$INSTALL_DIR/update.sh"
grep -Fq 'VERSION_MAX_TIME="${ZHOUKEER_VERSION_MAX_TIME:-30}"' "$INSTALL_DIR/update.sh"
grep -Fq -- '--retry 3' "$INSTALL_DIR/update.sh"
printf '%s\n' '4.0.0' > "$INSTALL_DIR/VERSION"

cat > "$RELEASE_DIR/install.sh" <<'SCRIPT'
#!/bin/bash
set -u
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/VERSION" \
    "$ZHOUKEER_INSTALL_DIR/VERSION"
SCRIPT
chmod +x "$RELEASE_DIR/install.sh"
printf '%s\n' '4.1.0' > "$RELEASE_DIR/VERSION"
tar -czf "$REMOTE_DIR/dist/zhoukeer-toolbox.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/zhoukeer-toolbox.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'zhoukeer-toolbox.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
printf '%s\n' '4.1.0' > "$REMOTE_DIR/VERSION"

cat > "$BIN_DIR/uname" <<'SCRIPT'
#!/bin/bash
printf '%s\n' Linux
SCRIPT

cat > "$BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        --output=*) output="${1#*=}"; shift ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
printf '%s\n' "$url" >> "$FAKE_CURL_LOG"
clean_url="${url%%\?*}"
case "$clean_url" in
    */dist/zhoukeer-toolbox.tar.gz) source="$FAKE_REMOTE_DIR/dist/zhoukeer-toolbox.tar.gz" ;;
    */dist/SHA256SUMS) source="$FAKE_REMOTE_DIR/dist/SHA256SUMS" ;;
    */VERSION) source="$FAKE_REMOTE_DIR/VERSION" ;;
    *) exit 22 ;;
esac
cp "$source" "$output"
SCRIPT
chmod +x "$BIN_DIR/uname" "$BIN_DIR/curl"

run_update() {
    HOME="$TMP_ROOT/home" \
    XDG_STATE_HOME="$TMP_ROOT/xdg-state" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_REMOTE_DIR="$REMOTE_DIR" \
    FAKE_CURL_LOG="$CURL_LOG" \
    ZHOUKEER_GITEE_RAW_BASE="https://test.invalid/repo" \
        bash "$INSTALL_DIR/update.sh" --startup
}

: > "$CURL_LOG"
run_update >/dev/null
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: 启动检测发现新版本后没有自动更新"
    exit 1
fi
grep -Fq '/dist/zhoukeer-toolbox.tar.gz' "$CURL_LOG"
grep -Fq '/dist/SHA256SUMS' "$CURL_LOG"
grep -Fq 'zhoukeer_cb=' "$CURL_LOG"

: > "$CURL_LOG"
run_update > "$STATE_DIR/latest.output"
grep -Fq '当前已是最新版本' "$STATE_DIR/latest.output"
if grep -Fq '/dist/zhoukeer-toolbox.tar.gz' "$CURL_LOG"; then
    echo "FAIL: 版本相同时仍下载了更新包"
    exit 1
fi

LOCK_DIR="$TMP_ROOT/xdg-state/zhoukeer-toolbox/auto-update.lock"
mkdir -p "$LOCK_DIR"
printf '%s\n' "$$" > "$LOCK_DIR/pid"
: > "$CURL_LOG"
run_update > "$STATE_DIR/locked.output"
grep -Fq '已有自动更新任务正在运行' "$STATE_DIR/locked.output"
if [ -s "$CURL_LOG" ]; then
    echo "FAIL: 已有自动更新任务时仍发起了网络检测"
    exit 1
fi
rm -rf -- "$LOCK_DIR"

printf '%s\n' '4.2.0' > "$REMOTE_DIR/VERSION"
if run_update > "$STATE_DIR/mismatch.output" 2>&1; then
    echo "FAIL: 更新包版本与检测版本不一致时仍执行了更新"
    exit 1
fi
grep -Fq '更新包版本与检测结果不一致' "$STATE_DIR/mismatch.output"
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: 错包检测后破坏了现有版本"
    exit 1
fi
printf '%s\n' '4.1.0' > "$REMOTE_DIR/VERSION"

# 校验和正确也不能解压包含路径逃逸链接的更新包。
printf '%s\n' '4.2.0' > "$RELEASE_DIR/VERSION"
ln -s ../../outside "$RELEASE_DIR/unsafe-link"
tar -czf "$REMOTE_DIR/dist/zhoukeer-toolbox.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/zhoukeer-toolbox.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'zhoukeer-toolbox.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
printf '%s\n' '4.2.0' > "$REMOTE_DIR/VERSION"
if run_update > "$STATE_DIR/unsafe-archive.output" 2>&1; then
    echo "FAIL: 包含路径逃逸链接的更新包仍被执行"
    exit 1
fi
grep -Fq '更新包包含不安全的链接' "$STATE_DIR/unsafe-archive.output"
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: 危险更新包破坏了现有版本"
    exit 1
fi
rm -f -- "$RELEASE_DIR/unsafe-link"

FAKE_APP="$TMP_ROOT/fake-app"
mkdir -p "$FAKE_APP"
cp "$PROJECT_ROOT/launch.sh" "$FAKE_APP/launch.sh"
touch "$FAKE_APP/.zhoukeer-installed"
cat > "$FAKE_APP/update.sh" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" > "$FAKE_STARTUP_CALL"
[ -z "${FAKE_UPDATE_CWD:-}" ] || printf '%s\n' "$PWD" > "$FAKE_UPDATE_CWD"
exit "${FAKE_UPDATE_STATUS:-0}"
SCRIPT
cat > "$FAKE_APP/main.sh" <<'SCRIPT'
#!/bin/bash
touch "$FAKE_MAIN_CALLED"
[ -z "${FAKE_MAIN_CWD:-}" ] || printf '%s\n' "$PWD" > "$FAKE_MAIN_CWD"
SCRIPT
chmod +x "$FAKE_APP/launch.sh" "$FAKE_APP/update.sh" "$FAKE_APP/main.sh"

FAKE_STARTUP_CALL="$STATE_DIR/startup.call" \
FAKE_MAIN_CALLED="$STATE_DIR/main.called" \
FAKE_UPDATE_CWD="$STATE_DIR/update.cwd" \
FAKE_MAIN_CWD="$STATE_DIR/main.cwd" \
FAKE_UPDATE_STATUS=9 \
HOME="$TMP_ROOT/home" \
ZHOUKEER_LAUNCH_LOG="$STATE_DIR/launcher.log" \
PATH="$BIN_DIR:/usr/bin:/bin" \
    bash "$FAKE_APP/launch.sh" --run-main >/dev/null
grep -Fxq -- '--startup' "$STATE_DIR/startup.call"
test -f "$STATE_DIR/main.called" || {
    echo "FAIL: 自动更新失败后没有继续启动当前版本"
    exit 1
}
grep -Fq '继续当前版本' "$STATE_DIR/launcher.log"
[ "$(cat "$STATE_DIR/update.cwd")" = "$TMP_ROOT/home" ] || {
    echo "FAIL: 启动更新前没有离开可能被替换的安装目录"
    exit 1
}
[ "$(cat "$STATE_DIR/main.cwd")" = "$FAKE_APP" ] || {
    echo "FAIL: 更新后没有进入当前安装目录再启动主程序"
    exit 1
}

echo "PASS: 启动检测、自动更新、版本跳过和失败回退测试通过"
