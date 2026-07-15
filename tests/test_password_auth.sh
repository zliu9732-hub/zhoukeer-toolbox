#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
STATE_DIR="$TMP_ROOT/state"
PASSWORD_FILE="$HOME_DIR/Desktop/管理员密码.txt"
PASSWORD_TEST_UID="$(id -u)"
export PASSWORD_TEST_UID

grep -Fxq '管理员密码.txt' "$PROJECT_ROOT/.gitignore" || {
    echo "FAIL: .gitignore 未排除管理员密码.txt" >&2
    exit 1
}

SET_PASSWORD='fake password 123!'
CHANGED_PASSWORD='changed password 456!'

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

file_mode() {
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

assert_password_record() {
    local expected="$1"

    [ -f "$PASSWORD_FILE" ] || fail "桌面密码记录不存在"
    [ "$(file_mode "$PASSWORD_FILE")" = "600" ] || \
        fail "密码记录权限不是 600"
    [ "$(grep -c '^密码：' "$PASSWORD_FILE")" -eq 1 ] || \
        fail "密码记录必须且只能有一个“密码：”字段"
    grep -Fxq "密码：$expected" "$PASSWORD_FILE" || \
        fail "密码记录没有保存预期明文"
}

assert_output_hides_password() {
    local output="$1"
    local password="$2"

    if printf '%s\n' "$output" | grep -Fq -- "$password"; then
        fail "命令输出泄露了测试密码"
    fi
}

mkdir -p "$BIN_DIR" "$HOME_DIR/Desktop" "$STATE_DIR"

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
EOF

cat > "$BIN_DIR/id" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-un" ]; then
    printf 'deck\n'
elif [ "${1:-}" = "-u" ]; then
    printf '%s\n' "${PASSWORD_TEST_UID:?}"
else
    printf '%s\n' "${PASSWORD_TEST_UID:?}"
fi
EOF

cat > "$BIN_DIR/date" <<'EOF'
#!/bin/sh
printf '2026-07-14 12:34:56\n'
EOF

cat > "$BIN_DIR/xdg-open" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${PASSWORD_TEST_STATE:?}/xdg-open-calls"
EOF

cat > "$BIN_DIR/passwd" <<'EOF'
#!/bin/sh
state="${PASSWORD_TEST_STATE:?}"
printf 'CALL %s\n' "$*" >> "$state/passwd-calls"
# 设置流程中的系统 passwd 是交互步骤；测试中直接模拟成功，
# 把调用脚本的 stdin 留给后续明文记录提示。
exit 0
EOF

cat > "$BIN_DIR/chpasswd" <<'EOF'
#!/bin/sh
# 真实 chpasswd 只能由 fake sudo 分支模拟，这个文件只用于 require_command。
exit 99
EOF

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/sh
state="${PASSWORD_TEST_STATE:?}"
use_stdin=0
noninteractive=0
validate_only=0
invalidate=0

{
    printf 'CALL\n'
    for original_arg in "$@"; do
        printf 'ARG=<%s>\n' "$original_arg"
    done
} >> "$state/sudo-calls"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -S) use_stdin=1; shift ;;
        -n) noninteractive=1; shift ;;
        -k) invalidate=1; shift ;;
        -v) validate_only=1; shift ;;
        -p)
            shift
            [ "$#" -eq 0 ] || shift
            ;;
        --)
            shift
            break
            ;;
        -*) shift ;;
        *) break ;;
    esac
done

if [ "$invalidate" -eq 1 ]; then
    rm -f -- "$state/sudo-cache"
fi

if [ "$use_stdin" -eq 1 ]; then
    supplied_password=""
    IFS= read -r supplied_password || true
    printf 'STDIN=<%s>\n' "$supplied_password" >> "$state/sudo-stdin"
    if [ "$supplied_password" != "${FAKE_SUDO_PASSWORD:-}" ] && \
        [ "$supplied_password" != "${FAKE_SUDO_PASSWORD_ALT:-}" ]; then
        exit 1
    fi
    : > "$state/sudo-cache"
elif [ "$#" -gt 0 ] && [ ! -f "$state/sudo-cache" ]; then
    exit 1
fi

if [ "$validate_only" -eq 1 ]; then
    exit 0
fi

if [ "$#" -gt 0 ]; then
    for command_arg in "$@"; do
        printf 'COMMAND_ARG=<%s>\n' "$command_arg" >> "$state/sudo-commands"
    done
    if [ "$1" = "chpasswd" ]; then
        cat > "$state/chpasswd-stdin"
    fi
fi
EOF

chmod +x "$BIN_DIR"/*

run_password_module() {
    local action="$1"
    local accepted_password="$2"
    local alternate_password="${3:-}"

    PATH="$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        USER=root \
        PASSWORD_TEST_UID="$PASSWORD_TEST_UID" \
        FAIL_PASSWORD_MV="${FAIL_PASSWORD_MV:-0}" \
        PASSWORD_TEST_STATE="$STATE_DIR" \
        FAKE_SUDO_PASSWORD="$accepted_password" \
        FAKE_SUDO_PASSWORD_ALT="$alternate_password" \
        bash "$PROJECT_ROOT/modules/password.sh" "$action"
}

# 设置密码：假的系统 passwd 先成功，脚本再读取一行并以 600 权限记录。
set_output="$(printf '%s\n' "$SET_PASSWORD" | \
    run_password_module set "$SET_PASSWORD")"
assert_password_record "$SET_PASSWORD"
assert_output_hides_password "$set_output" "$SET_PASSWORD"
grep -Fq 'CALL' "$STATE_DIR/passwd-calls" || fail "设置密码时未调用 passwd"
grep -Fxq "STDIN=<$SET_PASSWORD>" "$STATE_DIR/sudo-stdin" || \
    fail "设置后没有用新密码做假的 sudo 验证"

# 修改密码：旧密码来自记录并自动用于 sudo 验证，新密码由 stdin 输入两次。
rm -f -- "$STATE_DIR/chpasswd-stdin" "$STATE_DIR/sudo-cache"
change_output="$(printf '%s\n%s\n' "$CHANGED_PASSWORD" "$CHANGED_PASSWORD" | \
    run_password_module change "$SET_PASSWORD" "$CHANGED_PASSWORD")"
assert_password_record "$CHANGED_PASSWORD"
assert_output_hides_password "$change_output" "$SET_PASSWORD"
assert_output_hides_password "$change_output" "$CHANGED_PASSWORD"
grep -Fxq "STDIN=<$SET_PASSWORD>" "$STATE_DIR/sudo-stdin" || \
    fail "修改密码时没有从记录读取旧密码用于假的 sudo 验证"
[ "$(cat "$STATE_DIR/chpasswd-stdin")" = "deck:$CHANGED_PASSWORD" ] || \
    fail "修改密码时没有把当前用户和新密码交给假的 chpasswd"

# auth.sh 读取严格的“密码：...”字段，并在执行管理命令前自动交给 fake sudo。
rm -f -- "$STATE_DIR/sudo-cache" "$STATE_DIR/sudo-commands" "$STATE_DIR/sudo-stdin"
auth_output="$(
    PATH="$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        PASSWORD_TEST_STATE="$STATE_DIR" \
        FAKE_SUDO_PASSWORD="$CHANGED_PASSWORD" \
        EXPECTED_PASSWORD="$CHANGED_PASSWORD" \
        PROJECT_ROOT="$PROJECT_ROOT" \
        bash -c '
            set -euo pipefail
            # shellcheck disable=SC1090
            source "$PROJECT_ROOT/core/auth.sh"
            load_toolbox_password
            [ "$TOOLBOX_PASSWORD" = "$EXPECTED_PASSWORD" ]
            validate_toolbox_password_value "$TOOLBOX_PASSWORD"
            rm -f -- "$PASSWORD_TEST_STATE/sudo-cache"
            toolbox_sudo fake-admin-command "argument with spaces" "*.literal"
        '
)"
assert_output_hides_password "$auth_output" "$CHANGED_PASSWORD"
grep -Fxq "STDIN=<$CHANGED_PASSWORD>" "$STATE_DIR/sudo-stdin" || \
    fail "auth.sh 没有把记录密码交给 fake sudo"
grep -Fxq 'COMMAND_ARG=<fake-admin-command>' "$STATE_DIR/sudo-commands" || \
    fail "toolbox_sudo 没有执行目标管理命令"
grep -Fxq 'COMMAND_ARG=<argument with spaces>' "$STATE_DIR/sudo-commands" || \
    fail "toolbox_sudo 没有保留含空格参数"
grep -Fxq 'COMMAND_ARG=<*.literal>' "$STATE_DIR/sudo-commands" || \
    fail "toolbox_sudo 错误展开了通配符参数"
[ ! -e "$STATE_DIR/sudo-cache" ] || fail "toolbox_sudo 完成后没有清除 sudo 缓存"

assert_auth_rejects_record() {
    local label="$1"
    local uid_override="${2:-$PASSWORD_TEST_UID}"

    if PATH="$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        PASSWORD_TEST_UID="$uid_override" \
        PROJECT_ROOT="$PROJECT_ROOT" \
        bash -c 'source "$PROJECT_ROOT/core/auth.sh"; load_toolbox_password' \
        >/dev/null 2>&1; then
        fail "$label"
    fi
}

# 明文记录必须保持严格元数据：当前UID、600、单硬链、普通非链接文件、
# 不超过4096字节且只能有一个非空“密码：”字段。
VALID_RECORD="$TMP_ROOT/valid-password-record"
cp -p "$PASSWORD_FILE" "$VALID_RECORD"

chmod 644 "$PASSWORD_FILE"
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" PASSWORD_TEST_UID="$PASSWORD_TEST_UID" \
    PROJECT_ROOT="$PROJECT_ROOT" bash -c '
        source "$PROJECT_ROOT/core/auth.sh"
        load_toolbox_password
        [ "$TOOLBOX_PASSWORD" = "changed password 456!" ]
    ' >/dev/null 2>&1 || fail "auth.sh 未自动兼容修复旧版644密码记录"
[ "$(file_mode "$PASSWORD_FILE")" = "600" ] || fail "旧版密码记录没有自动收紧为600"

printf '\n密码：duplicate\n' >> "$PASSWORD_FILE"
assert_auth_rejects_record "auth.sh 接受了多个密码字段"
cp -p "$VALID_RECORD" "$PASSWORD_FILE"

dd if=/dev/zero bs=5000 count=1 >> "$PASSWORD_FILE" 2>/dev/null
assert_auth_rejects_record "auth.sh 接受了超过4096字节的密码记录"
cp -p "$VALID_RECORD" "$PASSWORD_FILE"

HARDLINK="$TMP_ROOT/password-hardlink"
ln "$PASSWORD_FILE" "$HARDLINK"
assert_auth_rejects_record "auth.sh 接受了多硬链接密码记录"
rm -f -- "$HARDLINK"

REAL_RECORD="$TMP_ROOT/password-real"
mv "$PASSWORD_FILE" "$REAL_RECORD"
ln -s "$REAL_RECORD" "$PASSWORD_FILE"
assert_auth_rejects_record "auth.sh 接受了符号链接密码记录"
rm -f -- "$PASSWORD_FILE"
mv "$REAL_RECORD" "$PASSWORD_FILE"

FOREIGN_UID=$((PASSWORD_TEST_UID + 1))
assert_auth_rejects_record "auth.sh 接受了非当前UID拥有的密码记录" "$FOREIGN_UID"

# 兼容旧版使用半角冒号和Windows换行的密码字段。
sed 's/^密码：/密码:/' "$PASSWORD_FILE" | sed 's/$/\r/' > "$TMP_ROOT/legacy-record"
chmod 600 "$TMP_ROOT/legacy-record"
mv "$TMP_ROOT/legacy-record" "$PASSWORD_FILE"
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" PASSWORD_TEST_UID="$PASSWORD_TEST_UID" \
    PROJECT_ROOT="$PROJECT_ROOT" bash -c '
        source "$PROJECT_ROOT/core/auth.sh"
        load_toolbox_password
        [ "$TOOLBOX_PASSWORD" = "changed password 456!" ]
    ' >/dev/null 2>&1 || fail "auth.sh 未兼容半角冒号或CRLF旧记录"
cp -p "$VALID_RECORD" "$PASSWORD_FILE"

# USER 环境变量即使伪装成 root，也必须以 id -un 的真实结果 deck 为准。
grep -Fxq "用户：deck" "$PASSWORD_FILE" || fail "密码记录错误信任了 USER 环境变量"

# 目标若已是目录，必须拒绝且不能把临时文件移动到目录里面。
mv "$PASSWORD_FILE" "$VALID_RECORD.current"
mkdir "$PASSWORD_FILE"
if printf '%s\n' "$CHANGED_PASSWORD" | \
    run_password_module set "$CHANGED_PASSWORD" >/dev/null 2>&1; then
    fail "密码记录目标为目录时仍报告成功"
fi
[ -d "$PASSWORD_FILE" ] || fail "异常目录目标被覆盖"
if find "$PASSWORD_FILE" -mindepth 1 -print | grep -q .; then
    fail "临时密码文件被错误移动进目录目标"
fi
rmdir "$PASSWORD_FILE"
mv "$VALID_RECORD.current" "$PASSWORD_FILE"

# 模拟最终原子替换失败：系统密码已改变后，旧明文记录必须被清除，
# 不能继续自动输入已经失效的旧密码。
cat > "$BIN_DIR/mv" <<'EOF'
#!/bin/sh
if [ "${FAIL_PASSWORD_MV:-0}" = "1" ]; then
    exit 88
fi
exec /bin/mv "$@"
EOF
chmod +x "$BIN_DIR/mv"
if printf '%s\n' "$CHANGED_PASSWORD" | \
    FAIL_PASSWORD_MV=1 run_password_module set "$CHANGED_PASSWORD" \
    >/dev/null 2>&1; then
    fail "密码记录替换失败时仍报告成功"
fi
[ ! -e "$PASSWORD_FILE" ] || fail "密码改变但记录写入失败后仍保留旧明文"
cp -p "$VALID_RECORD" "$PASSWORD_FILE"

# 密码管理入口拒绝 root；不能依赖可伪造的 USER 变量来判断身份。
rm -f -- "$STATE_DIR/passwd-calls"
if printf '%s\n' "$SET_PASSWORD" | \
    PASSWORD_TEST_UID=0 run_password_module set "$SET_PASSWORD" \
    >/dev/null 2>&1; then
    fail "密码模块允许 root 身份运行"
fi
[ ! -e "$STATE_DIR/passwd-calls" ] || fail "拒绝 root 前仍调用了 passwd"

# 显式验证错误密码必须失败。
rm -f -- "$STATE_DIR/sudo-cache"
if PATH="$BIN_DIR:$PATH" \
    HOME="$HOME_DIR" \
    PASSWORD_TEST_STATE="$STATE_DIR" \
    FAKE_SUDO_PASSWORD="$CHANGED_PASSWORD" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    bash -c 'source "$PROJECT_ROOT/core/auth.sh"; validate_toolbox_password_value wrong-password' \
    >/dev/null 2>&1; then
    fail "validate_toolbox_password_value 接受了错误密码"
fi

# 没有密码记录时 fake sudo 会拒绝交互，管理命令不得被当作成功执行。
mv "$PASSWORD_FILE" "$PASSWORD_FILE.saved"
rm -f -- "$STATE_DIR/sudo-cache" "$STATE_DIR/sudo-commands"
if PATH="$BIN_DIR:$PATH" \
    HOME="$HOME_DIR" \
    PASSWORD_TEST_STATE="$STATE_DIR" \
    FAKE_SUDO_PASSWORD="$CHANGED_PASSWORD" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    bash -c 'source "$PROJECT_ROOT/core/auth.sh"; toolbox_sudo must-not-run' \
    >/dev/null 2>&1; then
    fail "缺少密码记录时 toolbox_sudo 仍报告成功"
fi
if [ -f "$STATE_DIR/sudo-commands" ] && \
    grep -Fq 'COMMAND_ARG=<must-not-run>' "$STATE_DIR/sudo-commands"; then
    fail "缺少密码记录时仍执行了管理命令"
fi
mv "$PASSWORD_FILE.saved" "$PASSWORD_FILE"

# 首次没有记录时，可在明确输入并验证现有管理员密码后自动生成记录。
rm -f "$PASSWORD_FILE" "$STATE_DIR/sudo-cache"
PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" PASSWORD_TEST_STATE="$STATE_DIR" \
    FAKE_SUDO_PASSWORD="$CHANGED_PASSWORD" PROJECT_ROOT="$PROJECT_ROOT" \
    bash -c '
        source "$PROJECT_ROOT/core/auth.sh"
        printf "%s\n" "$FAKE_SUDO_PASSWORD" | {
            IFS= read -r supplied
            authenticate_toolbox_password_value "$supplied"
            write_captured_toolbox_password "$supplied"
        }
    ' >/dev/null 2>&1 || fail "无法根据现有管理员密码生成桌面记录"
assert_password_record "$CHANGED_PASSWORD"

# 三个需要 sudo 的入口必须统一经过 auth helper，避免旁路明文自动验证。
for consumer in \
    "$PROJECT_ROOT/modules/plugin_store.sh" \
    "$PROJECT_ROOT/modules/todesk.sh" \
    "$PROJECT_ROOT/modules/steam_accelerator.sh"; do
    grep -Fq 'core/auth.sh' "$consumer" || fail "$(basename "$consumer") 未加载 auth helper"
    if grep -Eq '^[[:space:]]*(if[[:space:]]+)?(![[:space:]]+)?sudo[[:space:]]' "$consumer"; then
        fail "$(basename "$consumer") 仍直接调用 sudo"
    fi
    grep -Fq 'toolbox_sudo' "$consumer" || fail "$(basename "$consumer") 未使用 toolbox_sudo"
done

echo "PASS: 密码明文记录、修改自动输入和sudo自动验证测试通过"
