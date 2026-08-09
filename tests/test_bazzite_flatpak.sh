#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
STATE_DIR="$TMP_ROOT/state"
BAZZITE_RELEASE="$TMP_ROOT/bazzite-release"
FEDORA_RELEASE="$TMP_ROOT/fedora-release"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$BIN_DIR" "$HOME_DIR/Desktop" "$STATE_DIR"
cat > "$BAZZITE_RELEASE" <<'EOF'
ID=bazzite
ID_LIKE=fedora
VARIANT_ID=bazzite-deck
PRETTY_NAME="Bazzite"
EOF
cat > "$FEDORA_RELEASE" <<'EOF'
ID=fedora
ID_LIKE=fedora
PRETTY_NAME="Fedora Linux"
EOF

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -s) printf 'Linux\n' ;;
    -m) printf 'x86_64\n' ;;
    *) printf 'Linux\n' ;;
esac
EOF

cat > "$BIN_DIR/timeout" <<'EOF'
#!/bin/sh
[ "${1:-}" != "--foreground" ] || shift
[ "$#" -eq 0 ] || shift
exec "$@"
EOF

cat > "$BIN_DIR/locale" <<'EOF'
#!/bin/sh
printf 'C\nC.UTF-8\n'
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            shift
            output="$1"
            ;;
        https://*) url="$1" ;;
    esac
    shift
done
printf 'curl %s\n' "$url" >> "${BAZZITE_FLATPAK_STATE:?}/commands"
[ -n "$output" ] || exit 1
cat > "$output" <<'REPO'
[Flatpak Repo]
Title=Flathub
Url=https://dl.flathub.org/repo/
GPGKey=test-key
REPO
EOF

cat > "$BIN_DIR/flatpak" <<'EOF'
#!/bin/sh
state="${BAZZITE_FLATPAK_STATE:?}"
command="${1:-}"
[ "$#" -eq 0 ] || shift
scope=user
case "$command" in
    remotes)
        for arg in "$@"; do
            case "$arg" in
                --system) scope=system ;;
                --user) scope=user ;;
            esac
        done
        [ ! -f "$state/${scope}-remotes" ] || cat "$state/${scope}-remotes"
        ;;
    remote-add)
        printf 'remote-add %s\n' "$*" >> "$state/commands"
        remote=""
        scope=user
        for arg in "$@"; do
            case "$arg" in
                --system) scope=system ;;
                --user|--if-not-exists|--from|--no-gpg-verify) ;;
                --*) ;;
                *) [ -n "$remote" ] || remote="$arg" ;;
            esac
        done
        [ -n "$remote" ] || exit 1
        grep -Fxq "$remote" "$state/${scope}-remotes" 2>/dev/null || \
            printf '%s\n' "$remote" >> "$state/${scope}-remotes"
        ;;
    remote-modify)
        printf 'remote-modify %s\n' "$*" >> "$state/commands"
        ;;
    remote-delete)
        printf 'remote-delete %s\n' "$*" >> "$state/commands"
        scope=user
        remote=""
        for arg in "$@"; do
            case "$arg" in
                --system) scope=system ;;
                --user|--force) ;;
                --*) ;;
                *) remote="$arg" ;;
            esac
        done
        grep -Fxv "$remote" "$state/${scope}-remotes" > "$state/${scope}-remotes.new" || true
        mv "$state/${scope}-remotes.new" "$state/${scope}-remotes"
        ;;
    info)
        app_id=""
        for arg in "$@"; do
            case "$arg" in --*) ;; *) app_id="$arg" ;; esac
        done
        [ -n "$app_id" ] && [ -f "$state/installed.$app_id" ]
        ;;
    install)
        printf 'install %s\n' "$*" >> "$state/commands"
        app_id=""
        for arg in "$@"; do app_id="$arg"; done
        [ -n "$app_id" ] || exit 1
        touch "$state/installed.$app_id"
        ;;
    *)
        echo "unexpected flatpak command: $command" >&2
        exit 1
        ;;
esac
EOF

cat > "$BIN_DIR/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >> "${BAZZITE_FLATPAK_STATE:?}/commands"
exit 97
EOF

chmod +x "$BIN_DIR"/*
: > "$STATE_DIR/commands"
: > "$STATE_DIR/user-remotes"
printf 'flathub-cn\nflathub-ustc\n' > "$STATE_DIR/system-remotes"

COMMON_ENV=(
    PATH="$BIN_DIR:/usr/bin:/bin"
    HOME="$HOME_DIR"
    BAZZITE_FLATPAK_STATE="$STATE_DIR"
    ZHOUKEER_OS_RELEASE_FILE="$BAZZITE_RELEASE"
    ZHOUKEER_AUTO_CONFIRM=1
)

# Bazzite 默认只走官方用户级 Flathub，即使系统层残留同名国内源也不沿用。
env "${COMMON_ENV[@]}" ZHOUKEER_FLATPAK_SOURCE_MODE=official \
    bash "$PROJECT_ROOT/modules/software.sh" localsend > "$TMP_ROOT/official.out"
grep -Fq 'remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo' \
    "$STATE_DIR/commands" || fail "Bazzite 默认未添加用户级官方 Flathub"
grep -Fq 'install --user --noninteractive -y flathub org.localsend.localsend_app' \
    "$STATE_DIR/commands" || fail "Bazzite 软件安装未使用官方 Flathub"
if grep -Eq -- '--no-gpg-verify|install .*flathub-(cn|ustc)' "$STATE_DIR/commands"; then
    fail "Bazzite 默认安装意外启用了国内源或关闭 GPG"
fi
[ -x "$HOME_DIR/Desktop/LocalSend.desktop" ] || fail "Bazzite 软件快捷方式未创建"

# 另一条通用 Flatpak 安装入口同样必须服从官方源模式。
env "${COMMON_ENV[@]}" ZHOUKEER_FLATPAK_SOURCE_MODE=official \
    bash "$PROJECT_ROOT/modules/software.sh" chrome > "$TMP_ROOT/chrome.out"
grep -Fq 'install --user --noninteractive -y flathub com.google.Chrome' \
    "$STATE_DIR/commands" || fail "Chrome 安装入口未使用官方 Flathub"

# 国内源只能经明确风险提示后手动启用，并且 Bazzite 只修改用户级远程。
env "${COMMON_ENV[@]}" \
    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable > "$TMP_ROOT/domestic.out"
grep -Fq '将关闭软件包签名验证' "$TMP_ROOT/domestic.out" || fail "缺少关闭 GPG 风险提示"
grep -Fq 'flathub-cn: https://mirror.sjtu.edu.cn/flathub' "$TMP_ROOT/domestic.out" || fail "缺少上海交大源明细"
grep -Fq 'flathub-ustc: https://mirrors.ustc.edu.cn/flathub' "$TMP_ROOT/domestic.out" || fail "缺少中科大源明细"
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-cn https://mirror.sjtu.edu.cn/flathub' \
    "$STATE_DIR/commands" || fail "上海交大源没有按用户级添加"
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-ustc https://mirrors.ustc.edu.cn/flathub' \
    "$STATE_DIR/commands" || fail "中科大源没有按用户级添加"
if grep -Fq 'sudo ' "$STATE_DIR/commands"; then
    fail "Bazzite 国内源配置调用了 sudo"
fi

# 恢复只清理用户级国内源、恢复官方 GPG，不碰系统级远程。
env "${COMMON_ENV[@]}" \
    bash "$PROJECT_ROOT/modules/domestic_source.sh" restore > "$TMP_ROOT/restore.out"
grep -Fq '系统更新源保持不变' "$TMP_ROOT/restore.out" || fail "恢复提示未说明 Bazzite 系统源不变"
grep -Fq 'remote-modify --user --gpg-verify --url=https://dl.flathub.org/repo/ flathub' \
    "$STATE_DIR/commands" || fail "官方 Flathub 的 GPG 验证未恢复"
grep -Fxq 'flathub-cn' "$STATE_DIR/system-remotes" || fail "误删系统级 flathub-cn"
grep -Fxq 'flathub-ustc' "$STATE_DIR/system-remotes" || fail "误删系统级 flathub-ustc"
if grep -Eq 'remote-delete .*--system|sudo ' "$STATE_DIR/commands"; then
    fail "Bazzite 恢复流程修改了系统级源"
fi

# 普通 Fedora 不允许直接调用源切换模块。
if env "${COMMON_ENV[@]}" ZHOUKEER_OS_RELEASE_FILE="$FEDORA_RELEASE" \
    bash "$PROJECT_ROOT/modules/domestic_source.sh" enable > "$TMP_ROOT/fedora.out" 2>&1; then
    fail "普通 Fedora 被允许启用 Bazzite 国内源"
fi

grep -Fq 'ZHOUKEER_FLATPAK_SOURCE_MODE="official"' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 主程序未固定官方源模式"
grep -Fq '确认信任并启用国内源' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 菜单缺少显式确认入口"
grep -Fq '仅修改用户级 Flatpak，不改 Bazzite 系统源' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 菜单缺少修改范围说明"

echo "PASS: Bazzite 默认官方 Flathub、手动国内源与用户级隔离测试通过"
