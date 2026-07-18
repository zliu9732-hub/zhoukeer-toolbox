#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/steam_accelerator.sh"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
APP_ROOT="$TMP_ROOT/apps"
STATE_DIR="$TMP_ROOT/state"
FIXTURE="$TMP_ROOT/steamcommunity302.fixture"
PROC_ROOT="$TMP_ROOT/proc"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_no_staging_leftovers() {
    if find "$APP_ROOT" -maxdepth 1 -name '.steamcommunity302-*' -print | grep -q .; then
        fail "安装结束后仍有 staging 或备份目录"
    fi
}

mkdir -p "$BIN_DIR" "$HOME_DIR" "$APP_ROOT" "$STATE_DIR"
printf 'offline steamcommunity302 archive fixture\n' > "$FIXTURE"

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -m) printf 'x86_64\n' ;;
    *) printf 'Linux\n' ;;
esac
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
output=""
printf '%s\n' "$*" >> "${STEAM302_TEST_STATE:?}/curl.calls"
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--output" ]; then
        shift
        output="${1:-}"
    fi
    shift
done
[ -n "$output" ] || exit 91
cp "${STEAM302_TEST_ARCHIVE_SOURCE:?}" "$output"
EOF

cat > "$BIN_DIR/md5sum" <<'EOF'
#!/bin/sh
printf 'md5\n' >> "${STEAM302_TEST_STATE:?}/hash.calls"
case "${HASH_MODE:-ok}" in
    bad_md5) hash="00000000000000000000000000000000" ;;
    *) hash="4b9994102b2256ca5fdf2e806a2c7035" ;;
esac
printf '%s  %s\n' "$hash" "$1"
EOF

cat > "$BIN_DIR/sha256sum" <<'EOF'
#!/bin/sh
printf 'sha256\n' >> "${STEAM302_TEST_STATE:?}/hash.calls"
case "${HASH_MODE:-ok}" in
    bad_sha256) hash="0000000000000000000000000000000000000000000000000000000000000000" ;;
    *) hash="5e006f015c807679ef800a87fa7b788562901ad04d7899ade2648f82b4c4a11f" ;;
esac
printf '%s  %s\n' "$hash" "$1"
EOF

cat > "$BIN_DIR/tar" <<'EOF'
#!/bin/sh
operation="${1:-}"
shift || true
printf '%s\n' "$operation $*" >> "${STEAM302_TEST_STATE:?}/tar.calls"

case "$operation" in
    -tzf)
        if [ "${TAR_MODE:-ok}" = "bad_layout" ]; then
            printf '../outside\n'
            exit 0
        fi
        cat <<'LIST'
./Steamcommunity_302/
./Steamcommunity_302/Steamcommunity_302
./Steamcommunity_302/steamcommunity_302.cli
./Steamcommunity_302/steamcommunity_302.caddy
./Steamcommunity_302/S302_rules.ini
./Steamcommunity_302/run_\350\277\220\350\241\214.sh
./Steamcommunity_302/.launcher/
./Steamcommunity_302/.launcher/launcher_\345\220\257\345\212\250\345\231\250.sh
./Steamcommunity_302/.launcher/setup_desktop_\347\224\237\346\210\220\346\241\214\351\235\242\345\277\253\346\215\267\346\226\271\345\274\217.sh
./Steamcommunity_302/.launcher/302_icon.ico
LIST
        ;;
    -tvzf)
        cat <<'LIST'
drwxr-xr-x user/group 0 Jan 1 00:00 ./Steamcommunity_302/
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/Steamcommunity_302
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/steamcommunity_302.cli
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/steamcommunity_302.caddy
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/S302_rules.ini
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/run_运行.sh
drwxr-xr-x user/group 0 Jan 1 00:00 ./Steamcommunity_302/.launcher/
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/.launcher/launcher_启动器.sh
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/.launcher/setup_desktop_生成桌面快捷方式.sh
-rw-r--r-- user/group 1 Jan 1 00:00 ./Steamcommunity_302/.launcher/302_icon.ico
LIST
        ;;
    -xzf)
        [ "${TAR_MODE:-ok}" != "fail_extract" ] || exit 92
        archive="${1:-}"
        shift || true
        [ -f "$archive" ] || exit 93
        [ "${1:-}" = "-C" ] || exit 94
        destination="${2:-}"
        package="$destination/Steamcommunity_302"
        mkdir -p "$package/.launcher"
        cat > "$package/run_运行.sh" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
        printf '%s\n' "${FAKE_PACKAGE_CONTENT:-fresh}" > "$package/Steamcommunity_302"
        cat > "$package/steamcommunity_302.cli" <<'SCRIPT'
#!/bin/sh
while [ ! -f S302.exit ]; do sleep 0.1; done
SCRIPT
        printf 'caddy\n' > "$package/steamcommunity_302.caddy"
        cat > "$package/S302_rules.ini" <<'INI'
[Rules]
enabled = all

[github]
INI
        cat > "$package/.launcher/launcher_启动器.sh" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
        cat > "$package/.launcher/setup_desktop_生成桌面快捷方式.sh" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
        printf 'icon\n' > "$package/.launcher/302_icon.ico"
        ;;
    *)
        echo "unexpected tar operation: $operation" >&2
        exit 95
        ;;
esac
EOF

cat > "$BIN_DIR/systemctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${STEAM302_TEST_STATE:?}/systemctl.calls"
case "${1:-}" in
    is-active) [ -f "$STEAM302_TEST_STATE/service-active" ] ;;
    is-enabled) [ -f "$STEAM302_TEST_STATE/service-enabled" ] ;;
    cat) [ -f "$STEAM302_TEST_STATE/service-unit" ] ;;
    start)
        [ -f "$STEAM302_TEST_STATE/service-unit" ] || exit 96
        touch "$STEAM302_TEST_STATE/service-active"
        ;;
    *) exit 96 ;;
esac
EOF

for forbidden_command in sudo pacman steamos-readonly; do
    cat > "$BIN_DIR/$forbidden_command" <<'EOF'
#!/bin/sh
printf '%s %s\n' "$(basename "$0")" "$*" >> "${STEAM302_TEST_STATE:?}/forbidden.calls"
exit 97
EOF
done

chmod +x "$BIN_DIR"/*

run_module() {
    env \
        PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" \
        HOME="$HOME_DIR" \
        ZHOUKEER_APP_DIR="$APP_ROOT" \
        ZHOUKEER_AUTO_CONFIRM=1 \
        STEAM302_TEST_STATE="$STATE_DIR" \
        STEAM302_TEST_ARCHIVE_SOURCE="$FIXTURE" \
        HASH_MODE="${HASH_MODE:-ok}" \
        TAR_MODE="${TAR_MODE:-ok}" \
        FAKE_PACKAGE_CONTENT="${FAKE_PACKAGE_CONTENT:-fresh}" \
        bash "$MODULE" "$@"
}

run_start_service() {
    env \
        PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" \
        HOME="$HOME_DIR" \
        ZHOUKEER_APP_DIR="$APP_ROOT" \
        ZHOUKEER_AUTO_CONFIRM=1 \
        STEAM302_TEST_STATE="$STATE_DIR" \
        MODULE="$MODULE" \
        bash -c 'source "$MODULE"; toolbox_sudo() { "$@"; }; start_steam302_service'
}

bash -n "$MODULE" || fail "模块语法检查失败"
grep -Fq 'V14.0.02.tar.gz' "$MODULE" || fail "缺少固定官方版本地址"
grep -Fq '4b9994102b2256ca5fdf2e806a2c7035' "$MODULE" || fail "缺少官方 MD5"
grep -Fq '5e006f015c807679ef800a87fa7b788562901ad04d7899ade2648f82b4c4a11f' \
    "$MODULE" || fail "缺少固定 SHA256"
grep -Fq 'ensure_steam302_for_download()' "$MODULE" || fail "缺少 Steamcommunity 302 工具函数"
grep -Fq '未检测到 Steam + GitHub 加速' "$MODULE" || fail "未加速时缺少醒目提示"

fallback_output="$(MODULE="$MODULE" bash -c '
    source "$MODULE"
    steam302_download_acceleration_is_ready() { return 1; }
    steam302_service_is_active() { return 1; }
    steam302_cli_is_running() { return 1; }
    steam302_is_installed() { return 1; }
    install_steam302() { return 1; }
    ensure_steam302_for_download
' 2>&1)" || fail "自动加速失败后不应阻断插件安装"
printf '%s\n' "$fallback_output" | grep -Fq '未检测到 Steam + GitHub 加速' || \
    fail "未加速时没有醒目提示"
printf '%s\n' "$fallback_output" | grep -Fq '勾选 Steam 和 GitHub' || \
    fail "未加速时没有说明 Steam302 配置方法"

ready_output="$(MODULE="$MODULE" bash -c '
    source "$MODULE"
    steam302_download_acceleration_is_ready() { return 0; }
    ensure_steam302_for_download
')" || fail "加速状态检测不应阻断下载"
printf '%s\n' "$ready_output" | grep -Fq '已检测到 Steamcommunity 302' || \
    fail "已开启加速时没有正确提示"

launch_function="$(sed -n '/^launch_steam302()/,/^}/p' "$MODULE")"
printf '%s\n' "$launch_function" | grep -Fq 'toolbox_sudo /usr/bin/env -i' || \
    fail "Steamcommunity 302 root进程没有使用最小化环境"
printf '%s\n' "$launch_function" | grep -Fq 'HOME="/root"' || \
    fail "Steamcommunity 302 root进程没有隔离HOME"
printf '%s\n' "$launch_function" | grep -Fq 'USER="root"' || \
    fail "Steamcommunity 302 root进程没有固定USER"
if printf '%s\n' "$launch_function" | grep -Eq 'toolbox_sudo[[:space:]]+-E'; then
    fail "Steamcommunity 302仍把调用者完整环境传给root进程"
fi

# 模拟旧版已移入备份后收到中断：EXIT 清理必须恢复旧版，而不是删备份。
SIGNAL_ROOT="$TMP_ROOT/signal-restore"
mkdir -p \
    "$SIGNAL_ROOT/apps/.backup/steamcommunity302" \
    "$SIGNAL_ROOT/apps/.stage" \
    "$SIGNAL_ROOT/apps/steamcommunity302"
printf 'old-version\n' > "$SIGNAL_ROOT/apps/.backup/steamcommunity302/version.txt"
printf 'partial-new\n' > "$SIGNAL_ROOT/apps/steamcommunity302/version.txt"
PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOME="$HOME_DIR" \
    ZHOUKEER_APP_DIR="$SIGNAL_ROOT/apps" \
    MODULE="$MODULE" \
    SIGNAL_ROOT="$SIGNAL_ROOT" \
    bash -c '
        source "$MODULE"
        STEAM302_INSTALL_DIR="$SIGNAL_ROOT/apps/steamcommunity302"
        STEAM302_STAGE_DIR="$SIGNAL_ROOT/apps/.stage"
        STEAM302_BACKUP_DIR="$SIGNAL_ROOT/apps/.backup"
        STEAM302_SWAP_FINISHED=0
        steam302_install_cleanup
    '
[ "$(cat "$SIGNAL_ROOT/apps/steamcommunity302/version.txt")" = 'old-version' ] || \
    fail "中断清理没有恢复旧版本"
[ ! -e "$SIGNAL_ROOT/apps/.backup" ] || fail "恢复后仍残留备份目录"

install_output="$(run_module install)" || fail "离线模拟安装失败"
TARGET="$APP_ROOT/steamcommunity302"
SHORTCUT="$HOME_DIR/Desktop/Steamcommunity 302.desktop"

[ -x "$TARGET/run_运行.sh" ] || fail "run_运行.sh 未安装或不可执行"
[ -x "$TARGET/Steamcommunity_302" ] || fail "主程序未安装或不可执行"
[ "$(sed -n '1p' "$TARGET/.zhoukeer-version")" = "14.0.02" ] || \
    fail "版本标记错误"
[ -x "$SHORTCUT" ] || fail "桌面快捷方式未创建"
grep -Fq "Exec=/usr/bin/env bash \"$PROJECT_ROOT/modules/steam_accelerator.sh\" launch" \
    "$SHORTCUT" || fail "桌面快捷方式没有通过工具箱自动密码入口启动"
printf '%s\n' "$install_output" | grep -Fq 'Steam + GitHub 内置加速规则' || \
    fail "安装完成后缺少内置规则提示"
[ -f "$TARGET/S302.ini" ] || fail "没有生成内置配置"
grep -Fq 'enabled = Steam_store,Steam_store_unlock' "$TARGET/S302.ini" || \
    fail "内置配置没有启用 Steam 规则"
grep -Fq ',github' "$TARGET/S302.ini" || fail "内置配置没有启用 GitHub 规则"

# 官方 CLI 以 root 身份运行，普通用户不能依赖 kill -0 判断它是否存活。
# 模拟 /proc 中存在 root 进程，并确保陈旧 PID 不会匹配到其他程序。
mkdir -p "$PROC_ROOT/4242"
printf './steamcommunity_302.cli\0' > "$PROC_ROOT/4242/cmdline"
printf '4242\n' > "$TARGET/.zhoukeer-cli.pid"
env PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME_DIR" \
    ZHOUKEER_APP_DIR="$APP_ROOT" ZHOUKEER_PROC_ROOT="$PROC_ROOT" MODULE="$MODULE" \
    bash -c 'source "$MODULE"; steam302_cli_is_running' || \
    fail "无法通过 /proc 识别 root 身份的官方 CLI"
printf '/usr/bin/unrelated-process\0' > "$PROC_ROOT/4242/cmdline"
if env PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME_DIR" \
    ZHOUKEER_APP_DIR="$APP_ROOT" ZHOUKEER_PROC_ROOT="$PROC_ROOT" MODULE="$MODULE" \
    bash -c 'source "$MODULE"; steam302_cli_is_running'; then
    fail "陈旧 PID 错误匹配到无关进程"
fi
rm -f "$TARGET/.zhoukeer-cli.pid"

grep -Fq -- '--connect-timeout 15' "$STATE_DIR/curl.calls" || \
    fail "curl 缺少连接超时"
grep -Fq -- '--max-time 1200' "$STATE_DIR/curl.calls" || \
    fail "curl 缺少总超时"
grep -Fq -- '--retry 3' "$STATE_DIR/curl.calls" || fail "curl 缺少重试"
grep -Fq -- '--retry-all-errors' "$STATE_DIR/curl.calls" || \
    fail "curl 未覆盖瞬时网络错误重试"
grep -Fq 'https://www.dogfight360.com/blog/wp-content/uploads/2026/02/steamcommunity_302_Linux_AMD64_V14.0.02.tar.gz' \
    "$STATE_DIR/curl.calls" || fail "未使用固定官方 URL"
[ "$(grep -c '^md5$' "$STATE_DIR/hash.calls")" -eq 1 ] || fail "没有执行 MD5 校验"
[ "$(grep -c '^sha256$' "$STATE_DIR/hash.calls")" -eq 1 ] || fail "没有执行 SHA256 校验"
[ ! -e "$STATE_DIR/systemctl.calls" ] || fail "安装过程自行调用了 systemctl"
[ ! -e "$STATE_DIR/forbidden.calls" ] || fail "安装过程调用了禁止的系统命令"
assert_no_staging_leftovers

status_output="$(run_module status)" || fail "已安装状态检查返回失败"
printf '%s\n' "$status_output" | grep -Fq 'Steamcommunity 302：已安装' || \
    fail "状态未报告已安装"
printf '%s\n' "$status_output" | grep -Fq '版本：14.0.02' || \
    fail "状态未报告版本"

# 一键启动直接拉起官方 CLI，不要求客户先打开 GUI 或创建 systemd 服务。
start_output="$(run_start_service)" || fail "一键启动内置加速失败"
printf '%s\n' "$start_output" | grep -Fq 'GitHub + Steam 加速已开启' || \
    fail "一键启动没有报告内置加速成功"
[ -f "$TARGET/.zhoukeer-cli.pid" ] || fail "一键启动没有写入 CLI PID"
stop_output="$(
    env PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$HOME_DIR" \
        ZHOUKEER_APP_DIR="$APP_ROOT" STEAM302_TEST_STATE="$STATE_DIR" \
        MODULE="$MODULE" bash -c 'source "$MODULE"; toolbox_sudo() { "$@"; }; stop_steam302_service'
)" || fail "一键停止内置加速失败"
printf '%s\n' "$stop_output" | grep -Fq '内置加速已停止' || fail "停止内置加速没有报告成功"
[ ! -f "$TARGET/.zhoukeer-cli.pid" ] || fail "停止后仍残留 CLI PID"
if [ -e "$STATE_DIR/systemctl.calls" ] && grep -Fq 'start steamcommunity302.service' "$STATE_DIR/systemctl.calls"; then
    fail "内置加速不应调用 systemctl start"
fi

# SHA256 失败时，下载和 staging 都不能破坏已有版本。
printf '13.0.00\n' > "$TARGET/.zhoukeer-version"
printf 'preserve-on-hash-failure\n' > "$TARGET/old-version.txt"
if HASH_MODE=bad_sha256 run_module install > "$STATE_DIR/bad-sha.output" 2>&1; then
    fail "SHA256 错误时安装仍成功"
fi
[ -f "$TARGET/old-version.txt" ] || fail "SHA256 错误破坏了旧版本"
[ "$(sed -n '1p' "$TARGET/.zhoukeer-version")" = "13.0.00" ] || \
    fail "SHA256 错误替换了旧版本标记"
grep -Fq 'SHA256 校验失败' "$STATE_DIR/bad-sha.output" || \
    fail "SHA256 错误提示不明确"
assert_no_staging_leftovers

# MD5 同样必须独立通过。
if HASH_MODE=bad_md5 run_module install > "$STATE_DIR/bad-md5.output" 2>&1; then
    fail "MD5 错误时安装仍成功"
fi
[ -f "$TARGET/old-version.txt" ] || fail "MD5 错误破坏了旧版本"
grep -Fq 'MD5 校验失败' "$STATE_DIR/bad-md5.output" || fail "MD5 错误提示不明确"
assert_no_staging_leftovers

# 解压失败时同样保留旧版本。
if TAR_MODE=fail_extract run_module install > "$STATE_DIR/bad-tar.output" 2>&1; then
    fail "解压错误时安装仍成功"
fi
[ -f "$TARGET/old-version.txt" ] || fail "解压错误破坏了旧版本"
grep -Fq '解压失败' "$STATE_DIR/bad-tar.output" || fail "解压错误提示不明确"
assert_no_staging_leftovers

# 正常更新采用 staging 后替换，旧文件不会混入新版。
FAKE_PACKAGE_CONTENT=updated run_module install > "$STATE_DIR/update.output" || \
    fail "模拟更新失败"
[ ! -e "$TARGET/old-version.txt" ] || fail "更新后混入旧版本残留文件"
[ "$(sed -n '1p' "$TARGET/Steamcommunity_302")" = "updated" ] || \
    fail "新版程序没有替换到稳定目录"
assert_no_staging_leftovers

# 没有明确输入 UNINSTALL 时不得删除任何文件。
if printf 'NO\n' | env \
    PATH="$BIN_DIR:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOME="$HOME_DIR" \
    ZHOUKEER_APP_DIR="$APP_ROOT" \
    STEAM302_TEST_STATE="$STATE_DIR" \
    STEAM302_TEST_ARCHIVE_SOURCE="$FIXTURE" \
    bash "$MODULE" uninstall > "$STATE_DIR/cancel-uninstall.output" 2>&1; then
    :
else
    fail "取消卸载不应返回失败"
fi
[ -d "$TARGET" ] || fail "未确认卸载时删除了程序"
grep -Fq '已取消' "$STATE_DIR/cancel-uninstall.output" || fail "取消卸载提示缺失"

# 运行中的系统服务必须阻止卸载。
touch "$STATE_DIR/service-active"
if run_module uninstall > "$STATE_DIR/active-uninstall.output" 2>&1; then
    fail "后台服务运行时仍允许卸载"
fi
[ -d "$TARGET" ] || fail "后台服务运行时删除了程序"
grep -Fq '正在运行' "$STATE_DIR/active-uninstall.output" || \
    fail "运行中拒绝卸载的提示不明确"
grep -Fq '官方程序' "$STATE_DIR/active-uninstall.output" || \
    fail "拒绝卸载时没有引导用户停止官方服务"

# 即使当前没运行，只要仍启用开机启动也不能留下损坏的 systemd unit。
rm -f "$STATE_DIR/service-active"
touch "$STATE_DIR/service-enabled"
if run_module uninstall > "$STATE_DIR/enabled-uninstall.output" 2>&1; then
    fail "服务仍设为开机启动时允许卸载"
fi
[ -d "$TARGET" ] || fail "服务仍启用时删除了程序"
grep -Fq '仍设为开机启动' "$STATE_DIR/enabled-uninstall.output" || \
    fail "开机启用状态的拒绝提示不明确"

rm -f "$STATE_DIR/service-enabled"
run_module uninstall > "$STATE_DIR/uninstall.output" || fail "安全卸载失败"
[ ! -e "$TARGET" ] || fail "卸载后程序目录仍存在"
[ ! -e "$SHORTCUT" ] || fail "卸载后桌面快捷方式仍存在"
[ ! -e "$STATE_DIR/forbidden.calls" ] || fail "卸载过程调用了禁止的系统命令"

if run_module status > "$STATE_DIR/not-installed.output" 2>&1; then
    fail "未安装状态应返回非零"
fi
grep -Fq 'Steamcommunity 302：未安装' "$STATE_DIR/not-installed.output" || \
    fail "状态未报告未安装"

echo "PASS: Steamcommunity 302 离线安装、双校验、原子替换和安全卸载测试通过"
