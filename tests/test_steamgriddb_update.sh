#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/renkit-steamgriddb-test.XXXXXX")"
TEST_GUARD_LOG="$TMP_ROOT/blocked-commands.log"
export TEST_GUARD_LOG

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

cleanup() {
    local result=$?
    if [ -s "$TEST_GUARD_LOG" ]; then
        printf 'FAIL: 测试触发了被禁止的网络或系统命令\n' >&2
        cat "$TEST_GUARD_LOG" >&2
        result=1
    fi
    /bin/rm -rf -- "$TMP_ROOT"
    exit "$result"
}
trap cleanup EXIT

assert_equal() {
    [ "$1" = "$2" ] || fail "$3（预期 $2，实际 $1）"
}

assert_test_path() {
    case "$1" in
        "$TMP_ROOT"/*) ;;
        *) fail "模拟安装器尝试写入临时目录之外" ;;
    esac
}

# 测试仅允许读取源码及在本次 mktemp 目录中写 fixture。
# PATH 使用本地文件工具白名单；网络、提权和系统管理命令均写日志后失败。
mkdir -p "$TMP_ROOT/bin"
for safe_command in dirname mkdir cp mv rm sed head cmp diff cat; do
    safe_command_path="$(command -v "$safe_command")"
    ln -s "$safe_command_path" "$TMP_ROOT/bin/$safe_command"
done
cat > "$TMP_ROOT/command-guard" <<'GUARD'
#!/bin/bash
printf '%s\n' "${0##*/}" >> "$TEST_GUARD_LOG"
printf 'FAIL: 测试禁止执行 %s\n' "${0##*/}" >&2
exit 97
GUARD
chmod +x "$TMP_ROOT/command-guard"
for blocked_command in curl wget git sudo doas pkexec systemctl service \
    flatpak pacman steamos-readonly mount umount dd parted fdisk sgdisk \
    mkfs mkfs.ext4 efibootmgr reboot shutdown xdg-open xdg-user-dir \
    steamcommunity_302.cli; do
    ln -s "$TMP_ROOT/command-guard" "$TMP_ROOT/bin/$blocked_command"
done
export PATH="$TMP_ROOT/bin"

# 保持 HOME 不变，把配置、日志、应用及密码记录全部指向临时 fixture。
export ZHOUKEER_TEST_MODE=1
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
export ZHOUKEER_PASSWORD_RECORD="$TMP_ROOT/password-record-unused"
export ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release"
export DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
unset ZHOUKEER_ENV_LOADED GITHUB_DOWNLOAD_LOADED ZHOUKEER_GITEE_DOWNLOAD_LOADED
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
CONFIG_FILE="$TMP_ROOT/settings.conf"
CONFIG_EXAMPLE_FILE="$TMP_ROOT/settings.example.conf"
LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
: > "$CONFIG_FILE"
printf 'ID=steamos\nPRETTY_NAME="SteamOS fixture"\n' > "$ZHOUKEER_OS_RELEASE_FILE"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/plugin_store.sh"

detect_platform() {
    IS_STEAMOS=1
    IS_BAZZITE=0
    IS_CHIMERAOS=0
    PLATFORM_FAMILY=steamos
}

toolbox_sudo() {
    printf 'toolbox_sudo\n' >> "$TEST_GUARD_LOG"
    return 97
}

download_verified_package() {
    printf 'download_verified_package\n' >> "$TEST_GUARD_LOG"
    return 97
}

reload_decky_plugins() {
    printf 'reload_decky_plugins\n' >> "$TEST_GUARD_LOG"
    return 97
}

EXPECTED_DIRECTORY="decky-steamgriddb"
EXPECTED_VERSION="1.8.1"
EXPECTED_SHA256="e84f5b1f111af8862b06218479491fbf61036e1bfd9f16f93f9901e9b9ebc5e0"
EXPECTED_URL="https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/$EXPECTED_SHA256.zip"
assert_equal "$STEAMGRIDDB_OFFICIAL_DIRECTORY" "$EXPECTED_DIRECTORY" "SteamGridDB 官方目录不匹配"
assert_equal "$STEAMGRIDDB_OFFICIAL_VERSION" "$EXPECTED_VERSION" "SteamGridDB 固定版本未更新"
assert_equal "$DECKY_STEAMGRIDDB_URL" "$EXPECTED_URL" "SteamGridDB 固定官方包地址不匹配"
assert_equal "$DECKY_STEAMGRIDDB_SHA256" "$EXPECTED_SHA256" "SteamGridDB 固定 SHA256 不匹配"

write_plugin_fixture() {
    local plugin_dir="$1" name="$2" version="$3" marker="$4"
    assert_test_path "$plugin_dir"
    mkdir -p "$plugin_dir/dist"
    printf '{"api_version":1,"name":"%s","author":"SteamGridDB"}\n' "$name" \
        > "$plugin_dir/plugin.json"
    printf '{"name":"decky-steamgriddb","version":"%s"}\n' "$version" \
        > "$plugin_dir/package.json"
    printf '// %s frontend fixture\n' "$marker" > "$plugin_dir/dist/index.js"
    printf '# %s backend fixture\n' "$marker" > "$plugin_dir/main.py"
}

INSTALL_CALLS="$TMP_ROOT/install-calls.log"
INSTALL_MOCK_FAIL=0
INSTALL_CALL_COUNT=0

# 仅替换安装器：保留 resolve、身份检查和版本检查的真实产品逻辑。
# 成功时写完整新插件树；失败时直接返回，不接触旧插件 fixture。
install_decky_zip() {
    local staged_dir="$TMP_ROOT/staged-plugin"
    local plugin_dir="$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY"
    [ "$#" -eq 5 ] || fail "SteamGridDB 安装器参数数量错误"
    INSTALL_CALL_COUNT=$((INSTALL_CALL_COUNT + 1))
    printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" >> "$INSTALL_CALLS"
    [ "$INSTALL_MOCK_FAIL" -eq 0 ] || return 1
    assert_test_path "$DECKY_PLUGIN_DIR"
    assert_test_path "$staged_dir"
    write_plugin_fixture "$staged_dir" SteamGridDB "$EXPECTED_VERSION" official-new
    rm -rf -- "$plugin_dir"
    mv -- "$staged_dir" "$plugin_dir"
    PLUGIN_INSTALL_CHANGED=1
}

reset_case() {
    local case_name="$1"
    export DECKY_PLUGIN_DIR="$TMP_ROOT/$case_name/plugins"
    mkdir -p "$DECKY_PLUGIN_DIR"
    CASE_OUTPUT="$TMP_ROOT/$case_name/output.log"
    INSTALL_CALL_COUNT=0
    INSTALL_MOCK_FAIL=0
    PLUGIN_INSTALL_CHANGED=0
    : > "$INSTALL_CALLS"
}

assert_official_install_call() {
    assert_equal "$INSTALL_CALL_COUNT" 1 "SteamGridDB 应只安装一次"
    printf '%s|%s|%s|%s|0\n' "游戏封面更换（SteamGridDB）" \
        "$EXPECTED_URL" "$EXPECTED_SHA256" "$EXPECTED_DIRECTORY" \
        > "$TMP_ROOT/expected-install-call.log"
    cmp -s "$INSTALL_CALLS" "$TMP_ROOT/expected-install-call.log" || \
        fail "SteamGridDB 未传递固定官方包地址、SHA256、目录或强制替换参数 0"
}

assert_complete_official_fixture() {
    local plugin_dir="$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY"
    feature_plugin_is_current "$DECKY_PLUGIN_DIR" "$EXPECTED_DIRECTORY" \
        "$EXPECTED_VERSION" SteamGridDB || fail "安装结果未恢复官方身份及版本"
    [ -s "$plugin_dir/main.py" ] || fail "模拟安装结果缺少完整后端"
    printf '// official-new frontend fixture\n' > "$TMP_ROOT/expected-index.js"
    printf '# official-new backend fixture\n' > "$TMP_ROOT/expected-main.py"
    cmp -s "$plugin_dir/dist/index.js" "$TMP_ROOT/expected-index.js" || \
        fail "模拟安装结果未替换前端"
    cmp -s "$plugin_dir/main.py" "$TMP_ROOT/expected-main.py" || \
        fail "模拟安装结果未替换后端"
    [ ! -e "$plugin_dir/legacy-only.txt" ] || fail "完整插件替换后仍残留旧文件"
    assert_equal "$PLUGIN_INSTALL_CHANGED" 1 "成功安装未标记插件变化"
}

reset_case upgrade
write_plugin_fixture "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" SteamGridDB 1.7.1 old-official
printf 'old file\n' > "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY/legacy-only.txt"
if ! resolve_plugin_latest steamgriddb > "$CASE_OUTPUT"; then
    fail "旧官方 SteamGridDB 1.7.1 升级失败"
fi
assert_official_install_call
assert_complete_official_fixture

reset_case current
write_plugin_fixture "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" SteamGridDB "$EXPECTED_VERSION" current-official
cp -R "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" "$TMP_ROOT/current-before"
PLUGIN_INSTALL_CHANGED=1
if ! resolve_plugin_latest steamgriddb > "$CASE_OUTPUT"; then
    fail "当前完整官方 SteamGridDB 检查失败"
fi
assert_equal "$INSTALL_CALL_COUNT" 0 "当前官方版本不应重复下载或安装"
[ ! -s "$INSTALL_CALLS" ] || fail "当前官方版本触发了模拟安装器"
assert_equal "$PLUGIN_INSTALL_CHANGED" 0 "跳过当前官方版本未清除变化标记"
diff -r "$TMP_ROOT/current-before" "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" >/dev/null || \
    fail "跳过当前官方版本时修改了插件文件"

reset_case localized
write_plugin_fixture "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" 游戏封面更换 "$EXPECTED_VERSION" old-localized
printf 'old localized file\n' > "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY/legacy-only.txt"
if ! resolve_plugin_latest steamgriddb > "$CASE_OUTPUT"; then
    fail "旧中文名称 SteamGridDB 修复失败"
fi
assert_official_install_call
assert_complete_official_fixture

reset_case install-failure
write_plugin_fixture "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" SteamGridDB 1.7.1 preserve-old
printf 'preserve old file\n' > "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY/legacy-only.txt"
cp -R "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" "$TMP_ROOT/failure-before"
INSTALL_MOCK_FAIL=1
if resolve_plugin_latest steamgriddb > "$CASE_OUTPUT"; then
    fail "SteamGridDB 安装失败却返回成功"
fi
assert_official_install_call
assert_equal "$PLUGIN_INSTALL_CHANGED" 0 "安装失败仍标记插件变化"
diff -r "$TMP_ROOT/failure-before" "$DECKY_PLUGIN_DIR/$EXPECTED_DIRECTORY" >/dev/null || \
    fail "安装失败时修改了旧插件 fixture"

[ ! -s "$TEST_GUARD_LOG" ] || fail "测试触发了真实网络或系统动作"
printf 'PASS: SteamGridDB 1.8.1 升级、官方身份、幂等跳过和失败保留检查通过（仅临时 fixture）\n'
