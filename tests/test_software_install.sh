#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
STATE_DIR="$TMP_ROOT/state"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$HOME_DIR" "$STATE_DIR"

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
output=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--output" ]; then
        shift
        output="$1"
    fi
    shift
done
cat > "$output" <<'REPO'
[Flatpak Repo]
Title=Flathub
Url=https://dl.flathub.org/repo/
GPGKey=test-key
REPO
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

cat > "$BIN_DIR/flatpak" <<'EOF'
#!/bin/sh
state="${FLATPAK_TEST_STATE:?}"
command="$1"
shift
case "$command" in
    remotes)
        [ ! -f "$state/remotes" ] || cat "$state/remotes"
        ;;
    remote-add)
        remote=""
        for arg in "$@"; do
            case "$arg" in
                --*) ;;
                *) remote="$arg"; break ;;
            esac
        done
        printf '%s\n' "$remote" >> "$state/remotes"
        ;;
    remote-modify)
        printf 'modify %s\n' "$*" >> "$state/commands"
        ;;
    info)
        [ -f "$state/installed.$1" ]
        ;;
    install)
        printf 'install %s\n' "$*" >> "$state/commands"
        app_id=""
        for arg in "$@"; do
            app_id="$arg"
        done
        touch "$state/installed.$app_id"
        ;;
    *)
        echo "unexpected flatpak command: $command" >&2
        exit 1
        ;;
esac
EOF

chmod +x "$BIN_DIR"/*

PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" wechat >/dev/null

SHORTCUT="$HOME_DIR/Desktop/微信.desktop"
[ -x "$SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.tencent.WeChat' "$SHORTCUT"
grep -Fq 'Icon=com.tencent.WeChat' "$SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.tencent.WeChat' \
    "$STATE_DIR/commands"

# 已安装时只修复快捷方式，不应再次下载。
rm -f "$SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" wechat >/dev/null

[ -x "$SHORTCUT" ]
[ "$(grep -c '^install ' "$STATE_DIR/commands")" -eq 1 ]

# Chrome 必须使用正确的 Flatpak 应用 ID，并创建独立桌面快捷方式。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" browser >/dev/null

CHROME_SHORTCUT="$HOME_DIR/Desktop/Chrome浏览器.desktop"
[ -x "$CHROME_SHORTCUT" ]
grep -Fq 'Name=Google Chrome浏览器' "$CHROME_SHORTCUT"
grep -Fq 'Exec=flatpak run com.google.Chrome' "$CHROME_SHORTCUT"
grep -Fq 'Icon=com.google.Chrome' "$CHROME_SHORTCUT"
grep -Fq 'Categories=Network;WebBrowser;' "$CHROME_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.google.Chrome' \
    "$STATE_DIR/commands"

# Chrome 已安装时同样只修复快捷方式，不重复安装。
rm -f "$CHROME_SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" browser >/dev/null

[ -x "$CHROME_SHORTCUT" ]
[ "$(grep -c 'com.google.Chrome$' "$STATE_DIR/commands")" -eq 1 ]

echo "PASS: 国内Flatpak源、微信和Chrome桌面快捷方式测试通过"
