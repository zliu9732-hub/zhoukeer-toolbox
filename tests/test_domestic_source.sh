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
state="${DOMESTIC_SOURCE_TEST_STATE:?}"
printf 'steamos-readonly %s\n' "$*" >> "$state/commands"
case "${1:-}" in
    status) printf 'enabled\n' ;;
    disable|enable) exit 0 ;;
    *) exit 99 ;;
esac
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
        remotes_file="$state/remotes"
        case " $* " in *' --system '*) remotes_file="$state/system-remotes" ;; esac
        case " $* " in
            *' --show-details '*)
                while IFS= read -r remote; do
                    [ -n "$remote" ] && printf '%s\thttps://example.invalid/%s\n' "$remote" "$remote"
                done < "$remotes_file"
                ;;
            *)
                [ ! -f "$remotes_file" ] || cat "$remotes_file"
                ;;
        esac
        ;;
    remote-add)
        [ "${DOMESTIC_SOURCE_FAIL_REMOTE_ADD:-0}" != "1" ] || exit 1
        case " $* " in
            *' --from '*) ;;
            *' --no-gpg-verify '*) ;;
            *) echo "remote-add missing verified mode" >&2; exit 1 ;;
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
        remotes_file="$state/remotes"
        case " $* " in *' --system '*) remotes_file="$state/system-remotes" ;; esac
        remote=""
        for arg in "$@"; do remote="$arg"; done
        printf 'remote-delete %s\n' "$*" >> "$state/commands"
        awk -v remove="$remote" '$0 != remove' "$remotes_file" > "$remotes_file.new"
        mv "$remotes_file.new" "$remotes_file"
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

cat > "$BIN_DIR/pacman" <<'EOF'
#!/bin/sh
state="${DOMESTIC_SOURCE_TEST_STATE:?}"
case "${1:-}" in
    -Q)
        shift
        for package_name in "$@"; do
            [ -f "$state/installed.$package_name" ] || exit 1
        done
        exit 0
        ;;
    -Qu)
        found_upgrade=0
        for upgrade_file in "$state"/upgrade.*; do
            [ -e "$upgrade_file" ] || continue
            package_name="${upgrade_file##*.}"
            printf '%s test-version\n' "$package_name"
            found_upgrade=1
        done
        [ "$found_upgrade" -eq 1 ] || exit 1
        exit 0
        ;;
    -Syyu)
        printf 'pacman %s\n' "$*" >> "$state/commands"
        exit 0
        ;;
esac
printf 'pacman %s\n' "$*" >> "$state/commands"
case " $* " in
    *' archlinuxcn-keyring '*)
        [ "${DOMESTIC_SOURCE_FAIL_PACMAN_INSTALL:-0}" != "1" ] || exit 1
        touch "$state/installed.archlinuxcn-keyring"
        ;;
esac
case " $* " in
    *' git '*|*' flatpak '*)
        [ "${DOMESTIC_SOURCE_FAIL_PACMAN_INSTALL:-0}" != "1" ] || exit 1
        touch "$state/installed.git"
        touch "$state/installed.flatpak"
        ;;
esac
case " $* " in
    *' archlinux-keyring '*)
        [ "${DOMESTIC_SOURCE_FAIL_PACMAN_INSTALL:-0}" != "1" ] || exit 1
        touch "$state/installed.archlinux-keyring"
        ;;
esac
exit 0
EOF

cat > "$BIN_DIR/pacman-key" <<'EOF'
#!/bin/sh
printf 'pacman-key %s\n' "$*" >> "${DOMESTIC_SOURCE_TEST_STATE:?}/commands"
[ "${DOMESTIC_SOURCE_FAIL_PACMAN_KEY:-0}" != "1" ]
EOF

chmod +x "$BIN_DIR"/* "$STEAMOS_BIN_DIR"/*
: > "$STATE_DIR/remotes"
: > "$STATE_DIR/system-remotes"
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
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-cn https://mirror.test.invalid/flathub' \
    "$STATE_DIR/commands" || fail "上海交大用户级远程没有直接使用已确认的国内地址"
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-ustc https://fallback.test.invalid/flathub' \
    "$STATE_DIR/commands" || fail "中科大用户级远程没有直接使用已确认的国内地址"
[ ! -e "$STATE_DIR/sudo-calls" ] || fail "用户级国内源配置不应调用 sudo"
grep -Fq -- '--appstream' "$PROJECT_ROOT/modules/domestic_source.sh" && \
    fail "国内源模块不应包含 AppStream 强制刷新"
grep -Fq 'verify_domestic_flatpak_remote' "$PROJECT_ROOT/modules/domestic_source.sh" && \
    fail "国内源模块不应保留应用索引验证"
for command_text in 'packages_installed_without_known_upgrades' 'archlinuxcn_keyring_ready' 'configure_archlinuxcn_with_fallback' 'pacman-key --init' 'pacman-key --populate archlinux' 'pacman-key --populate holo' 'pacman -Syyu --noconfirm' 'pacman -S --needed --noconfirm git flatpak' 'pacman -S --noconfirm archlinux-keyring' 'pacman -S --noconfirm archlinuxcn-keyring' 'pacman -Sy --needed --noconfirm archlinuxcn-keyring' 'pacman-key --populate archlinuxcn' 'locale-gen' 'steamos-readonly disable' 'steamos-readonly enable'; do
    grep -Fq "$command_text" "$PROJECT_ROOT/modules/domestic_source.sh" || \
        fail "完整国内源初始化缺少：$command_text"
done
(
    PATH="$BIN_DIR:$PATH"
    HOME="$HOME_DIR"
    DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR"
    export PATH HOME DOMESTIC_SOURCE_TEST_STATE
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/modules/domestic_source.sh"

    touch "$STATE_DIR/installed.archlinuxcn-keyring"
    archlinuxcn_keyring_ready || fail "已安装 archlinuxcn 密钥环未被识别"

    touch "$STATE_DIR/upgrade.archlinuxcn-keyring"
    if archlinuxcn_keyring_ready; then
        fail "archlinuxcn-keyring 存在待更新版本时仍被识别为可用"
    fi
    rm -f "$STATE_DIR/upgrade.archlinuxcn-keyring"

    rm -f "$STATE_DIR/installed.archlinuxcn-keyring"
    if archlinuxcn_keyring_ready; then
        fail "缺少 archlinuxcn-keyring 时仍被识别为可用"
    fi
)
for repo_url in \
    'https://mirror.sjtu.edu.cn/archlinux-cn/\$arch' \
    'https://mirrors.ustc.edu.cn/archlinuxcn/\$arch' \
    'https://repo.archlinuxcn.org/\$arch'; do
    grep -Fq "$repo_url" "$PROJECT_ROOT/modules/domestic_source.sh" || \
        fail "缺少 archlinuxcn 镜像回退：$repo_url"
done
grep -Fq '更新必要系统组件并优化国内软件源' "$PROJECT_ROOT/modules/new_machine.sh" || \
    fail "新机初始化没有运行国内源与系统组件检测"
grep -Fq 'modules/domestic_source.sh" enable' "$PROJECT_ROOT/modules/new_machine.sh" || \
    fail "新机初始化跳过系统更新时没有继续配置用户级 Flatpak 国内源"

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
    for repo_line in \
        'Server = https://mirror.sjtu.edu.cn/archlinux-cn/$arch' \
        'Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch' \
        'Server = https://repo.archlinuxcn.org/$arch'; do
        grep -Fq "$repo_line" "$SYSTEM_DIR/pacman.conf" || \
            fail "archlinuxcn 仓库回退地址错误：$repo_line"
    done

    configure_archlinuxcn_with_fallback "$SYSTEM_DIR/pacman.conf"
    grep -Fq 'pacman-key --populate archlinuxcn' "$STATE_DIR/commands" || \
        fail "已有可用 archlinuxcn 密钥环时未加载密钥"

    rm -f "$STATE_DIR/installed.archlinuxcn-keyring"
    configure_archlinuxcn_with_fallback "$SYSTEM_DIR/pacman.conf"
    grep -Fq 'pacman -Sy --needed --noconfirm archlinuxcn-keyring' "$STATE_DIR/commands" || \
        fail "缺少密钥环时未执行 archlinuxcn 安装"
    grep -Fq '[archlinuxcn]' "$SYSTEM_DIR/pacman.conf" || \
        fail "密钥环安装成功后未保留 archlinuxcn 配置"

    rm -f "$STATE_DIR/installed.archlinuxcn-keyring"
    DOMESTIC_SOURCE_FAIL_PACMAN_INSTALL=1
    export DOMESTIC_SOURCE_FAIL_PACMAN_INSTALL
    failure_output="$(configure_archlinuxcn_with_fallback "$SYSTEM_DIR/pacman.conf")"
    printf '%s\n' "$failure_output" | grep -Fq '将继续配置 Flatpak 国内缓存' || \
        fail "archlinuxcn 安装失败时未说明继续配置 Flatpak"
    ! grep -Fq '[archlinuxcn]' "$SYSTEM_DIR/pacman.conf" || \
        fail "archlinuxcn 安装失败后仍保留Renkit仓库配置"
    unset DOMESTIC_SOURCE_FAIL_PACMAN_INSTALL

    configure_chinese_locales "$SYSTEM_DIR/locale.gen"
    [ "$(grep -c '^en_US.UTF-8 UTF-8$' "$SYSTEM_DIR/locale.gen")" -eq 1 ] || \
        fail "英文 locale 未幂等启用"
    [ "$(grep -c '^zh_CN.UTF-8 UTF-8$' "$SYSTEM_DIR/locale.gen")" -eq 1 ] || \
        fail "中文 locale 未幂等启用"
    grep -Fxq 'locale-gen' "$STATE_DIR/commands" || fail "未运行 locale-gen"

    remove_managed_archlinuxcn_repo "$SYSTEM_DIR/pacman.conf"
    ! grep -Fq '[archlinuxcn]' "$SYSTEM_DIR/pacman.conf" || \
        fail "恢复后仍保留Renkit管理的 archlinuxcn"
)

# 完整初始化流程：密钥环初始化/填充 → 完整 pacman -Syyu → 重装两个
# keyring → 复查 -Syyu → locale；全程只操作临时目录与模拟命令。
FLOW_STATE="$TMP_ROOT/flow-state"
FLOW_DIR="$TMP_ROOT/flow-system"
mkdir -p "$FLOW_STATE" "$FLOW_DIR"
: > "$FLOW_STATE/commands"
cat > "$FLOW_DIR/pacman.conf" <<'EOF'
[options]
Architecture = auto
EOF
cat > "$FLOW_DIR/locale.gen" <<'EOF'
#en_US.UTF-8 UTF-8
#zh_CN.UTF-8 UTF-8
EOF
(
    PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH"
    HOME="$HOME_DIR"
    DOMESTIC_SOURCE_TEST_STATE="$FLOW_STATE"
    export PATH HOME DOMESTIC_SOURCE_TEST_STATE
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/modules/domestic_source.sh"
    toolbox_sudo() { "$@"; }

    prepare_system_packages "$FLOW_DIR/pacman.conf" "$FLOW_DIR/locale.gen" || \
        fail "完整系统更新流程未成功完成"
    grep -Fxq 'steamos-readonly disable' "$FLOW_STATE/commands" || \
        fail "完整流程未临时关闭只读保护"
    grep -Fxq 'pacman-key --init' "$FLOW_STATE/commands" || \
        fail "完整流程未初始化 pacman 密钥环"
    grep -Fxq 'pacman-key --populate archlinux' "$FLOW_STATE/commands" || \
        fail "完整流程未填充 Arch Linux 系统密钥"
    grep -Fxq 'pacman-key --populate holo' "$FLOW_STATE/commands" || \
        fail "完整流程未填充 SteamOS（holo）系统密钥"
    grep -Fq 'pacman-key --populate archlinuxcn' "$FLOW_STATE/commands" || \
        fail "完整流程未填充 archlinuxcn 密钥"
    [ "$(grep -c '^pacman -Syyu --noconfirm$' "$FLOW_STATE/commands")" -eq 2 ] || \
        fail "完整流程未执行两次 pacman -Syyu"
    grep -Fxq 'pacman -S --needed --noconfirm git flatpak' "$FLOW_STATE/commands" || \
        fail "完整流程未补齐 git 与 Flatpak"
    grep -Fxq 'pacman -S --noconfirm archlinux-keyring' "$FLOW_STATE/commands" || \
        fail "完整流程未重装 archlinux-keyring"
    grep -Fxq 'pacman -S --noconfirm archlinuxcn-keyring' "$FLOW_STATE/commands" || \
        fail "完整流程未重装 archlinuxcn-keyring"
    grep -Fxq 'locale-gen' "$FLOW_STATE/commands" || \
        fail "完整流程未生成 locale"
    grep -Fxq 'steamos-readonly enable' "$FLOW_STATE/commands" || \
        fail "完整流程未恢复只读保护"
    grep -Fq '[archlinuxcn]' "$FLOW_DIR/pacman.conf" || \
        fail "完整流程未保留 archlinuxcn 配置"
)

# 兼容旧版本遗留的系统级国内远程：沿用现有 flathub-cn，不能重复添加同名用户远程。
LEGACY_STATE="$TMP_ROOT/legacy-state"
mkdir -p "$LEGACY_STATE"
: > "$LEGACY_STATE/remotes"
: > "$LEGACY_STATE/commands"
printf '%s\n' flathub-cn > "$LEGACY_STATE/system-remotes"
(
    PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH"
    HOME="$HOME_DIR"
    DOMESTIC_SOURCE_TEST_STATE="$LEGACY_STATE"
    ZHOUKEER_AUTO_CONFIRM=1
    ZHOUKEER_FLATHUB_CN_URL="https://mirror.test.invalid/flathub"
    ZHOUKEER_FLATHUB_CN_FALLBACK_URL="https://fallback.test.invalid/flathub"
    export PATH HOME DOMESTIC_SOURCE_TEST_STATE ZHOUKEER_AUTO_CONFIRM
    export ZHOUKEER_FLATHUB_CN_URL ZHOUKEER_FLATHUB_CN_FALLBACK_URL
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/modules/software.sh"
    toolbox_sudo() { "$@"; }
    ensure_flatpak_remotes
)
grep -Fq 'remote-modify --system flathub-cn --url=https://mirror.test.invalid/flathub' \
    "$LEGACY_STATE/commands" || fail "没有沿用旧版系统级上海交大远程"
if grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-cn ' \
    "$LEGACY_STATE/commands"; then
    fail "系统级上海交大远程存在时仍重复添加用户级同名远程"
fi
grep -Fxq flathub-ustc "$LEGACY_STATE/remotes" || fail "没有补充缺少的用户级中科大远程"

# 国内缓存属于可选加速项：添加失败但已有官方源时应跳过并返回成功。
SKIP_STATE="$TMP_ROOT/skip-state"
mkdir -p "$SKIP_STATE"
printf '%s\n' flathub > "$SKIP_STATE/remotes"
: > "$SKIP_STATE/system-remotes"
: > "$SKIP_STATE/commands"
skip_output="$(
    PATH="$STEAMOS_BIN_DIR:$BIN_DIR:$PATH" \
    HOME="$HOME_DIR" \
    DOMESTIC_SOURCE_TEST_STATE="$SKIP_STATE" \
    DOMESTIC_SOURCE_FAIL_REMOTE_ADD=1 \
    ZHOUKEER_AUTO_CONFIRM=1 \
    ZHOUKEER_TEST_MODE=1 \
        bash "$PROJECT_ROOT/modules/domestic_source.sh" enable
)"
printf '%s\n' "$skip_output" | grep -Fq '本次已跳过，继续使用现有软件源' || \
    fail "国内缓存不可用但已有软件源时没有按可选项跳过"
if printf '%s\n' "$skip_output" | grep -Fq '失败'; then
    fail "可选国内缓存跳过时仍向用户显示失败"
fi

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
printf '%s\n' "$restore_output" | grep -Fq '已恢复 Flathub 官方源并启用 GPG 验证，同时移除Renkit管理的 archlinuxcn 配置' || \
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
