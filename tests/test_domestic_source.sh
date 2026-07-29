#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
STEAMOS_BIN_DIR="$TMP_ROOT/steamos-bin"
HOME_DIR="$TMP_ROOT/home"
STATE_DIR="$TMP_ROOT/state"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$BIN_DIR" "$STEAMOS_BIN_DIR" "$HOME_DIR" "$STATE_DIR"

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
EOF

cat > "$STEAMOS_BIN_DIR/steamos-readonly" <<'EOF'
#!/bin/sh
exit 99
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
state="${DOMESTIC_SOURCE_TEST_STATE:?}"
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            shift
            output="$1"
            ;;
        https://*)
            url="$1"
            ;;
    esac
    shift
done
printf '%s\n' "$url" >> "$state/curl-urls"
cat > "$output" <<'REPO'
[Flatpak Repo]
Title=Flathub
Url=https://dl.flathub.org/repo/
GPGKey=test-key
REPO
EOF

cat > "$BIN_DIR/flatpak" <<'EOF'
#!/bin/sh
state="${DOMESTIC_SOURCE_TEST_STATE:?}"
command="${1:-}"
[ "$#" -eq 0 ] || shift
case "$command" in
    remotes)
        case " $* " in
            *' --show-details '*)
                while IFS= read -r remote; do
                    [ -n "$remote" ] && printf '%s\thttps://example.invalid/%s\n' "$remote" "$remote"
                done < "$state/remotes"
                ;;
            *)
                [ ! -f "$state/remotes" ] || cat "$state/remotes"
                ;;
        esac
        ;;
    remote-add)
        case " $* " in
            *' --from '*) ;;
            *) echo "local flatpakrepo missing --from" >&2; exit 1 ;;
        esac
        remote=""
        for arg in "$@"; do
            case "$arg" in
                --*) ;;
                *) remote="$arg"; break ;;
            esac
        done
        printf 'remote-add %s\n' "$*" >> "$state/commands"
        printf '%s\n' "$remote" >> "$state/remotes"
        ;;
    remote-modify)
        printf 'remote-modify %s\n' "$*" >> "$state/commands"
        ;;
    remote-delete)
        remote=""
        for arg in "$@"; do remote="$arg"; done
        printf 'remote-delete %s\n' "$*" >> "$state/commands"
        awk -v remove="$remote" '$0 != remove' "$state/remotes" > "$state/remotes.new"
        mv "$state/remotes.new" "$state/remotes"
        ;;
    remote-ls)
        printf 'remote-ls %s\n' "$*" >> "$state/commands"
        printf 'org.mozilla.firefox\n'
        ;;
    update)
        printf 'update %s\n' "$*" >> "$state/commands"
        ;;
    *)
        echo "unexpected flatpak command: $command" >&2
        exit 1
        ;;
esac
EOF

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${DOMESTIC_SOURCE_TEST_STATE:?}/sudo-calls"
exit 97
EOF

cat > "$BIN_DIR/timeout" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        --foreground|--preserve-status) shift ;;
        [0-9]*) shift ;;
        *) exec "$@" ;;
    esac
done
exit 0
EOF

cat > "$BIN_DIR/install" <<'EOF'
#!/bin/sh
while [ "$#" -gt 2 ]; do shift; done
cp "$1" "$2"
EOF

cat > "$BIN_DIR/locale-gen" <<'EOF'
#!/bin/sh
printf 'locale-gen\n' >> "${DOMESTIC_SOURCE_TEST_STATE:?}/commands"
EOF

chmod +x "$BIN_DIR"/* "$STEAMOS_BIN_DIR"/*
: > "$STATE_DIR/remotes"
: > "$STATE_DIR/commands"

run_enable() {
    PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR" \
        ZHOUKEER_AUTO_CONFIRM=1 \
        ZHOUKEER_TEST_MODE=1 \
        ZHOUKEER_FLATHUB_CN_URL="https://mirror.test.invalid/flathub" \
        ZHOUKEER_FLATHUB_CN_FALLBACK_URL="https://fallback.test.invalid/flathub" \
        bash "$PROJECT_ROOT/modules/domestic_source.sh" enable
}

run_restore() {
    PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR" \
        ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/domestic_source.sh" restore
}

if PATH="$BIN_DIR:$PATH" HOME="$HOME_DIR" DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR" \
    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable </dev/null >/dev/null 2>&1; then
    fail "非 SteamOS Linux 不应允许配置国内源"
fi
if PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH" HOME="$HOME_DIR" DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR" \
    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable </dev/null >/dev/null 2>&1; then
    fail "直接调用国内源且未明确确认时不应继续"
fi
[ ! -s "$STATE_DIR/commands" ] || fail "平台或确认检查失败后仍修改了 Flatpak 源"

output="$(run_enable)"
printf '%s\n' "$output" | grep -Fq '国内下载源配置完成：flathub-cn、flathub-ustc' || \
    fail "成功输出缺少两个国内源名称"
if grep -Eq '^(update|remote-ls) ' "$STATE_DIR/commands"; then
    fail "国内源配置不应刷新或验证 Discover 应用索引"
fi
grep -Fxq 'flathub-cn' "$STATE_DIR/remotes" || fail "未添加国内缓存源"
grep -Fxq 'flathub-ustc' "$STATE_DIR/remotes" || fail "未添加国内备用缓存源"
grep -Fq 'remote-modify --user flathub-cn --url=https://mirror.test.invalid/flathub' \
    "$STATE_DIR/commands" || fail "国内缓存地址配置错误"
grep -Fq 'remote-modify --user flathub-ustc --url=https://fallback.test.invalid/flathub' \
    "$STATE_DIR/commands" || fail "国内备用缓存地址配置错误"
grep -Fq 'remote-add --user --if-not-exists --from flathub-cn ' \
    "$STATE_DIR/commands" || fail "上海交大配置文件未按 flatpakrepo 解析"
grep -Fq 'remote-add --user --if-not-exists --from flathub-ustc ' \
    "$STATE_DIR/commands" || fail "中科大配置文件未按 flatpakrepo 解析"
grep -Fxq 'https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo' \
    "$STATE_DIR/curl-urls" || fail "未通过假 curl 获取签名配置"
[ ! -e "$STATE_DIR/sudo-calls" ] || fail "用户级国内源配置不应调用 sudo"
grep -Fq -- '--appstream' "$PROJECT_ROOT/modules/domestic_source.sh" && \
    fail "国内源模块不应包含 AppStream 强制刷新"
grep -Fq 'verify_domestic_flatpak_remote' "$PROJECT_ROOT/modules/domestic_source.sh" && \
    fail "国内源模块不应保留应用索引验证"
for command_text in 'pacman-key --init' 'pacman-key --populate archlinux' 'pacman -Syu --needed --noconfirm git flatpak' 'pacman -S --needed --noconfirm archlinux-keyring' 'pacman -Syu --needed --noconfirm archlinuxcn-keyring' 'pacman-key --populate archlinuxcn' 'locale-gen' 'steamos-readonly disable' 'steamos-readonly enable'; do
    grep -Fq "$command_text" "$PROJECT_ROOT/modules/domestic_source.sh" || \
        fail "完整国内源初始化缺少：$command_text"
done
grep -Fq 'https://mirrors.ustc.edu.cn/archlinuxcn/\$arch' \
    "$PROJECT_ROOT/modules/domestic_source.sh" || fail "缺少中科大 archlinuxcn 仓库"
grep -Fq '初始化国内源并更新系统组件' "$PROJECT_ROOT/modules/new_machine.sh" || \
    fail "新机初始化没有完整运行国内源与系统组件初始化"

# 配置文件测试只操作临时目录，toolbox_sudo 被替换为直接调用假 install/locale-gen。
SYSTEM_DIR="$TMP_ROOT/system"
mkdir -p "$SYSTEM_DIR"
cat > "$SYSTEM_DIR/pacman.conf" <<'EOF'
[options]
Architecture = auto
EOF
cat > "$SYSTEM_DIR/locale.gen" <<'EOF'
#en_US.UTF-8 UTF-8
#zh_CN.UTF-8 UTF-8
EOF
(
    PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH"
    HOME="$HOME_DIR"
    DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR"
    export PATH HOME DOMESTIC_SOURCE_TEST_STATE
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/modules/domestic_source.sh"
    toolbox_sudo() { "$@"; }

    write_managed_archlinuxcn_repo "$SYSTEM_DIR/pacman.conf"
    write_managed_archlinuxcn_repo "$SYSTEM_DIR/pacman.conf"
    [ "$(grep -c '^\[archlinuxcn\]$' "$SYSTEM_DIR/pacman.conf")" -eq 1 ] || \
        fail "重复执行后 archlinuxcn 仓库不唯一"
    grep -Fq 'Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch' \
        "$SYSTEM_DIR/pacman.conf" || fail "archlinuxcn 仓库地址错误"

    configure_chinese_locales "$SYSTEM_DIR/locale.gen"
    [ "$(grep -c '^en_US.UTF-8 UTF-8$' "$SYSTEM_DIR/locale.gen")" -eq 1 ] || \
        fail "英文 locale 未幂等启用"
    [ "$(grep -c '^zh_CN.UTF-8 UTF-8$' "$SYSTEM_DIR/locale.gen")" -eq 1 ] || \
        fail "中文 locale 未幂等启用"
    grep -Fxq 'locale-gen' "$STATE_DIR/commands" || fail "未运行 locale-gen"

    remove_managed_archlinuxcn_repo "$SYSTEM_DIR/pacman.conf"
    ! grep -Fq '[archlinuxcn]' "$SYSTEM_DIR/pacman.conf" || \
        fail "恢复后仍保留工具箱管理的 archlinuxcn"
)

# 重复启用只更新镜像地址，不应重复添加两个远程源。
run_enable >/dev/null
[ "$(grep -c '^remote-add .* flathub-cn ' "$STATE_DIR/commands")" -eq 1 ] || \
    fail "重复启用时再次添加了国内源"
[ "$(grep -c '^remote-add .* flathub-ustc ' "$STATE_DIR/commands")" -eq 1 ] || \
    fail "重复启用时再次添加了国内备用源"

status_output="$(
    PATH="$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR" \
        bash "$PROJECT_ROOT/modules/domestic_source.sh" status
)"
printf '%s\n' "$status_output" | grep -Fq 'flathub-cn' || fail "状态输出缺少国内源"
printf '%s\n' "$status_output" | grep -Fq 'flathub-ustc' || fail "状态输出缺少国内备用源"

restore_output="$(run_restore)"
printf '%s\n' "$restore_output" | grep -Fq '已恢复 Flathub 官方源并启用 GPG 验证，同时移除工具箱管理的 archlinuxcn 配置' || \
    fail "恢复官方源缺少成功提示"
grep -Fxq 'flathub' "$STATE_DIR/remotes" || fail "恢复时未添加官方 Flathub"
if grep -Eq '^flathub-(cn|ustc)$' "$STATE_DIR/remotes"; then
    fail "恢复后仍保留国内缓存源"
fi
grep -Fq 'remote-modify --user --gpg-verify --url=https://dl.flathub.org/repo/ flathub' \
    "$STATE_DIR/commands" || fail "恢复官方源时没有重新启用 GPG 验证"
grep -Fxq 'https://dl.flathub.org/repo/flathub.flatpakrepo' \
    "$STATE_DIR/curl-urls" || fail "恢复官方源时未获取官方签名配置"

echo "PASS: archlinuxcn、locale、国内双缓存、恢复官方源、幂等性、状态和无sudo测试通过"
