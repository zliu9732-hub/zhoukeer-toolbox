#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
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

mkdir -p "$BIN_DIR" "$HOME_DIR" "$STATE_DIR"

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
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

chmod +x "$BIN_DIR"/*
: > "$STATE_DIR/remotes"
: > "$STATE_DIR/commands"

run_enable() {
    PATH="$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        DOMESTIC_SOURCE_TEST_STATE="$STATE_DIR" \
        ZHOUKEER_FLATHUB_CN_URL="https://mirror.test.invalid/flathub" \
        ZHOUKEER_FLATHUB_CN_FALLBACK_URL="https://fallback.test.invalid/flathub" \
        bash "$PROJECT_ROOT/modules/domestic_source.sh" enable
}

output="$(run_enable)"
printf '%s\n' "$output" | grep -Fq '国内下载源配置完成：flathub-cn、flathub-ustc' || \
    fail "成功输出缺少两个国内源名称"
grep -Fxq 'flathub-cn' "$STATE_DIR/remotes" || fail "未添加国内缓存源"
grep -Fxq 'flathub-ustc' "$STATE_DIR/remotes" || fail "未添加国内备用缓存源"
grep -Fq 'remote-modify --user flathub-cn --url=https://mirror.test.invalid/flathub' \
    "$STATE_DIR/commands" || fail "国内缓存地址配置错误"
grep -Fq 'remote-modify --user flathub-ustc --url=https://fallback.test.invalid/flathub' \
    "$STATE_DIR/commands" || fail "国内备用缓存地址配置错误"
grep -Fxq 'https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo' \
    "$STATE_DIR/curl-urls" || fail "未通过假 curl 获取签名配置"
[ ! -e "$STATE_DIR/sudo-calls" ] || fail "用户级国内源配置不应调用 sudo"

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

echo "PASS: 国内双缓存源启用、幂等性、状态和无sudo测试通过"
