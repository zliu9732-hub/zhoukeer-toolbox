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
    "$BIN_DIR" "$INSTALL_DIR/core" "$RELEASE_DIR" "$REMOTE_DIR/dist" \
    "$STATE_DIR" "$TMP_ROOT/home"

cp "$PROJECT_ROOT/update.sh" "$INSTALL_DIR/update.sh"
cp "$PROJECT_ROOT/core/download_policy.sh" "$INSTALL_DIR/core/download_policy.sh"
cp "$PROJECT_ROOT/core/source_status.sh" "$INSTALL_DIR/core/source_status.sh"
grep -Fq 'VERSION_CONNECT_TIMEOUT="${ZHOUKEER_VERSION_CONNECT_TIMEOUT:-8}"' "$INSTALL_DIR/update.sh"
grep -Fq 'VERSION_MAX_TIME="${ZHOUKEER_VERSION_MAX_TIME:-30}"' "$INSTALL_DIR/update.sh"
grep -Fq -- '--retry "$VERSION_RETRIES"' "$INSTALL_DIR/update.sh"
grep -Fq 'VERSION_CONNECT_TIMEOUT="${ZHOUKEER_STARTUP_VERSION_CONNECT_TIMEOUT:-4}"' "$INSTALL_DIR/update.sh"
grep -Fq 'VERSION_MAX_TIME="${ZHOUKEER_STARTUP_VERSION_MAX_TIME:-10}"' "$INSTALL_DIR/update.sh"
grep -Fq 'VERSION_RETRIES="${ZHOUKEER_STARTUP_VERSION_RETRIES:-1}"' "$INSTALL_DIR/update.sh"
grep -Fq 'ZHOUKEER_STARTUP_VERSION_DEADLINE:-15' "$INSTALL_DIR/update.sh"
printf '%s\n' '4.0.0' > "$INSTALL_DIR/VERSION"

cat > "$RELEASE_DIR/install.sh" <<'SCRIPT'
#!/bin/bash
set -u
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/VERSION" \
    "$ZHOUKEER_INSTALL_DIR/VERSION"
SCRIPT
chmod +x "$RELEASE_DIR/install.sh"
printf '%s\n' '4.1.0' > "$RELEASE_DIR/VERSION"
printf 'AppleDouble metadata\n' > "$RELEASE_DIR/._install.sh"
tar -czf "$REMOTE_DIR/dist/renkit.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/renkit.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'renkit.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
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
if [ "${FAKE_GITEE_PACKAGE_FAIL:-0}" = "1" ] && \
    [ "$clean_url" = "${FAKE_GITEE_RAW_BASE:?}/dist/renkit.tar.gz" ]; then
    exit 22
fi
if [ "${FAKE_DOMAIN_VERSION_STALE:-0}" = "1" ] && \
    [ "$clean_url" = "${FAKE_DOMAIN_RAW_BASE:?}/VERSION" ]; then
    printf '%s\n' '4.0.0' > "$output"
    exit 0
fi
if [ "${FAKE_VERSION_SOURCES_FAIL:-0}" = "1" ] && \
    [ "$clean_url" != "${FAKE_DOMAIN_RAW_BASE:?}/VERSION" ]; then
    case "$clean_url" in
        */VERSION) exit 22 ;;
    esac
fi
case "$clean_url" in
    */dist/renkit.tar.gz) source="$FAKE_REMOTE_DIR/dist/renkit.tar.gz" ;;
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
    ZHOUKEER_DOMAIN_RAW_BASE="https://domain.test/repo" \
    ZHOUKEER_TEST_MODE=1 \
    FAKE_GITEE_RAW_BASE="https://test.invalid/repo" \
    FAKE_DOMAIN_RAW_BASE="https://domain.test/repo" \
        bash "$INSTALL_DIR/update.sh" --startup
}

run_check_only() {
    HOME="$TMP_ROOT/home" \
    XDG_STATE_HOME="$TMP_ROOT/xdg-state" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_REMOTE_DIR="$REMOTE_DIR" \
    FAKE_CURL_LOG="$CURL_LOG" \
    ZHOUKEER_GITEE_RAW_BASE="https://test.invalid/repo" \
    ZHOUKEER_DOMAIN_RAW_BASE="https://domain.test/repo" \
    ZHOUKEER_TEST_MODE=1 \
    FAKE_GITEE_RAW_BASE="https://test.invalid/repo" \
    FAKE_DOMAIN_RAW_BASE="https://domain.test/repo" \
        bash "$INSTALL_DIR/update.sh" --check-only
}

# 工具箱里的“检测更新”只能比较版本，不能顺带下载或安装更新包。
: > "$CURL_LOG"
run_check_only > "$STATE_DIR/check-only.output"
grep -Fq '发现 Renkit 新版本：V4.1.0（当前 V4.0.0）' "$STATE_DIR/check-only.output" || {
    echo "FAIL: 仅检测模式没有显示真实的新旧版本" >&2
    exit 1
}
if grep -Fq '/dist/renkit.tar.gz' "$CURL_LOG"; then
    echo "FAIL: 仅检测模式仍下载了更新包" >&2
    exit 1
fi
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.0.0' ]; then
    echo "FAIL: 仅检测模式修改了本地版本" >&2
    exit 1
fi

: > "$CURL_LOG"
run_update >/dev/null
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: 启动检测发现新版本后没有自动更新"
    exit 1
fi
grep -Fq '/dist/renkit.tar.gz' "$CURL_LOG"
grep -Fq '/dist/SHA256SUMS' "$CURL_LOG"
grep -Fq 'zhoukeer_cb=' "$CURL_LOG"

# 1.3.10 已经公开发布，必须保留这批用户到 1.4.0 的完整更新链。
printf '%s\n' '1.3.10' > "$INSTALL_DIR/VERSION"
printf '%s\n' '1.4.0' > "$RELEASE_DIR/VERSION"
printf '%s\n' '1.4.0' > "$REMOTE_DIR/VERSION"
tar -czf "$REMOTE_DIR/dist/renkit.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/renkit.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'renkit.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
: > "$CURL_LOG"
run_update >/dev/null
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '1.4.0' ]; then
    echo "FAIL: Renkit 1.3.10 没有正常升级到 1.4.0"
    exit 1
fi
grep -Fq '/dist/renkit.tar.gz' "$CURL_LOG"
grep -Fq '/dist/SHA256SUMS' "$CURL_LOG"

# 1.4.0 发布后的补丁版也必须保持同一条更新链；1.3.10 用户即使没有
# 先启动 1.4.0，也会由最高版本选择逻辑直接拿到当前 1.9.0。
printf '%s\n' '1.3.10' > "$INSTALL_DIR/VERSION"
printf '%s\n' '1.9.0' > "$RELEASE_DIR/VERSION"
printf '%s\n' '1.9.0' > "$REMOTE_DIR/VERSION"
tar -czf "$REMOTE_DIR/dist/renkit.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/renkit.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'renkit.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
run_update >/dev/null
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '1.9.0' ]; then
    echo "FAIL: Renkit 1.3.10 没有直接升级到当前 1.9.0"
    exit 1
fi

# 恢复后续测试使用的通用版本夹具。
printf '%s\n' '4.0.0' > "$INSTALL_DIR/VERSION"
printf '%s\n' '4.1.0' > "$RELEASE_DIR/VERSION"
printf '%s\n' '4.1.0' > "$REMOTE_DIR/VERSION"
tar -czf "$REMOTE_DIR/dist/renkit.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/renkit.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'renkit.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"

# Gitee 的大文件可能被原始下载接口拒绝。版本检测仍来自 Gitee 时，更新包
# 必须先回退到域名源，而不是跳过域名源直接请求可能受限的 GitHub Raw。
printf '%s\n' '4.0.0' > "$INSTALL_DIR/VERSION"
: > "$CURL_LOG"
FAKE_GITEE_PACKAGE_FAIL=1 run_update >/dev/null
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: Gitee更新包失败后没有通过域名源完成更新"
    exit 1
fi
grep -Fq 'https://domain.test/repo/dist/renkit.tar.gz' "$CURL_LOG" || {
    echo "FAIL: Gitee更新包失败后没有尝试域名源"
    exit 1
}

run_update > "$STATE_DIR/progress.output"
grep -Fq 'Renkit已是最新版本' "$STATE_DIR/progress.output"
if grep -Eq '\[[0-9]+/[0-9]+\]' "$STATE_DIR/progress.output"; then
    echo "FAIL: 自动更新仍显示拆分的下载和安装步骤" >&2
    exit 1
fi
grep -Fq '正在更新Renkit...' "$PROJECT_ROOT/update.sh" || {
    echo "FAIL: 自动更新没有使用合并进度提示" >&2
    exit 1
}
if grep -Fq '[1/2]' "$PROJECT_ROOT/update.sh" || grep -Fq '[2/2]' "$PROJECT_ROOT/update.sh"; then
    echo "FAIL: 自动更新脚本仍保留拆分进度提示" >&2
    exit 1
fi
if grep -Fq 'SHA256校验通过' "$PROJECT_ROOT/update.sh" || grep -Fq 'SHA256校验通过' "$PROJECT_ROOT/bootstrap.sh"; then
    echo "FAIL: Renkit更新或安装仍回显正常校验细节" >&2
    exit 1
fi
grep -Fq 'for attempt in 1 2' "$PROJECT_ROOT/update.sh" || {
    echo "FAIL: 更新包 SHA256 校验失败后没有重试" >&2
    exit 1
}
grep -Fq -- "-name '._*' -exec rm -f -- {} +" "$PROJECT_ROOT/update.sh" || {
    echo "FAIL: 自动更新不会清理 AppleDouble 元数据文件" >&2
    exit 1
}
grep -Fq -- "-name '._*' -exec rm -f -- {} +" "$PROJECT_ROOT/bootstrap.sh" || {
    echo "FAIL: 首次安装不会清理 AppleDouble 元数据文件" >&2
    exit 1
}
grep -Fq 'MAX_GITEE_RAW_PACKAGE_BYTES=9437184' "$PROJECT_ROOT/scripts/package_release.sh" || {
    echo "FAIL: 发布包没有限制在 Gitee Raw 安全体积内" >&2
    exit 1
}
grep -Fq 'if [ "$patch" -gt 9 ]' "$PROJECT_ROOT/scripts/package_release.sh" || {
    echo "FAIL: 发布脚本没有拒绝两位数补丁版本" >&2
    exit 1
}
grep -Fq '其下一正式版本必须是 `1.4.0`' "$PROJECT_ROOT/AGENTS.md" || {
    echo "FAIL: 长期开发规则没有固定 1.3.10 到 1.4.0 的兼容升级要求" >&2
    exit 1
}
grep -Fq 'assets/background.png' "$PROJECT_ROOT/scripts/package_release.sh" || {
    echo "FAIL: 发布包仍可能包含未压缩背景图" >&2
    exit 1
}
startup_update_source="$(sed -n '/^run_startup_update()/,/^}/p' "$PROJECT_ROOT/launch.sh")"
if printf '%s\n' "$startup_update_source" | grep -Fq 'tee -a "$LAUNCH_LOG"'; then
    echo "FAIL: 启动时自动更新仍会把详细输出回显到终端" >&2
    exit 1
fi
run_main_source="$(sed -n '/^run_main()/,/^}/p' "$PROJECT_ROOT/launch.sh")"
printf '%s\n' "$run_main_source" | grep -Fq 'Renkit启动中，请耐心等待' || {
    echo "FAIL: 启动更新前没有显示Renkit启动提示" >&2
    exit 1
}
printf '%s\n' "$run_main_source" | grep -Fq '若启动较慢，Renkit可能正在更新，请耐心等待' || {
    echo "FAIL: 启动更新前没有说明启动缓慢可能正在更新" >&2
    exit 1
}
startup_prompt_line="$(printf '%s\n' "$run_main_source" | grep -n 'Renkit启动中，请耐心等待' | head -n 1 | cut -d: -f1)"
startup_update_line="$(printf '%s\n' "$run_main_source" | grep -n 'run_startup_update' | head -n 1 | cut -d: -f1)"
if [ -z "$startup_prompt_line" ] || [ -z "$startup_update_line" ] || \
    [ "$startup_prompt_line" -ge "$startup_update_line" ]; then
    echo "FAIL: Renkit启动提示没有在自动更新前显示" >&2
    exit 1
fi

: > "$CURL_LOG"
run_update > "$STATE_DIR/latest.output"
grep -Fq 'Renkit已是最新版本' "$STATE_DIR/latest.output"
if grep -Fq '/dist/renkit.tar.gz' "$CURL_LOG"; then
    echo "FAIL: 版本相同时仍下载了更新包"
    exit 1
fi

# 域名源版本落后时，必须取国内镜像/GitHub 的最高版本，不能因域名旧版本误判“已是最新”。
printf '%s\n' '4.0.0' > "$INSTALL_DIR/VERSION"
: > "$CURL_LOG"
FAKE_DOMAIN_VERSION_STALE=1 run_update > "$STATE_DIR/stale-domain.output"
grep -Fq 'https://domain.test/repo/VERSION' "$CURL_LOG" || {
    echo "FAIL: 域名源版本未被检测" >&2
    exit 1
}
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: 域名源版本落后时未按最高版本更新" >&2
    exit 1
fi

# 只有域名源可达且版本不高于本地时，不能把域名旧版本当作“已是最新”。
: > "$CURL_LOG"
if FAKE_VERSION_SOURCES_FAIL=1 FAKE_DOMAIN_VERSION_STALE=1 run_update \
    > "$STATE_DIR/domain-only-stale.output" 2>&1; then
    echo "FAIL: 只有域名源且版本未更新时仍成功退出" >&2
    exit 1
fi
grep -Fq '自动更新检测暂时不可用' "$STATE_DIR/domain-only-stale.output" || {
    echo "FAIL: 只有域名源且版本未更新时没有提示检测不可用" >&2
    exit 1
}
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '4.1.0' ]; then
    echo "FAIL: 域名源旧版本误触发了更新" >&2
    exit 1
fi
if grep -Fq '/dist/renkit.tar.gz' "$CURL_LOG"; then
    echo "FAIL: 只有域名源且版本未更新时仍下载了更新包" >&2
    exit 1
fi

# 旧版周克儿工具箱只有域名源可达时，也要允许升级到 Renkit 1.0。
printf '%s\n' '1.6.4' > "$INSTALL_DIR/VERSION"
printf '%s\n' '周克儿工具箱' > "$INSTALL_DIR/core/env.sh"
printf '%s\n' '1.0' > "$RELEASE_DIR/VERSION"
printf '%s\n' '1.0' > "$REMOTE_DIR/VERSION"
tar -czf "$REMOTE_DIR/dist/renkit.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/renkit.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'renkit.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
: > "$CURL_LOG"
FAKE_VERSION_SOURCES_FAIL=1 run_update > "$STATE_DIR/migration.output" 2>&1 || {
    echo "FAIL: 旧版工具箱域名源未允许升级到 Renkit 1.0" >&2
    exit 1
}
grep -Fq 'Renkit已是最新版本' "$STATE_DIR/migration.output" && {
    echo "FAIL: 旧版工具箱被误判为已是最新版本" >&2
    exit 1
}
if [ "$(tr -d '\r\n' < "$INSTALL_DIR/VERSION")" != '1.0' ]; then
    echo "FAIL: 旧版工具箱没有升级到 Renkit 1.0" >&2
    exit 1
fi
grep -Fq '/dist/renkit.tar.gz' "$CURL_LOG" || {
    echo "FAIL: 旧版工具箱迁移没有下载 Renkit 1.0 更新包" >&2
    exit 1
}
printf '%s\n' '4.1.0' > "$INSTALL_DIR/VERSION"
printf '%s\n' '4.1.0' > "$REMOTE_DIR/VERSION"
rm -f -- "$INSTALL_DIR/core/env.sh"

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
tar -czf "$REMOTE_DIR/dist/renkit.tar.gz" -C "$RELEASE_DIR" .
PACKAGE_SHA="$(shasum -a 256 "$REMOTE_DIR/dist/renkit.tar.gz" | awk '{print $1}')"
printf '%s  %s\n' "$PACKAGE_SHA" 'renkit.tar.gz' > "$REMOTE_DIR/dist/SHA256SUMS"
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
