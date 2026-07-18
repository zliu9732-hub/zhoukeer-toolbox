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
mkdir -p "$STATE_DIR/firefox-fixture/firefox/browser/chrome/icons/default"
printf '#!/bin/sh\nexit 0\n' > "$STATE_DIR/firefox-fixture/firefox/firefox"
printf '[App]\nName=Firefox\n' > "$STATE_DIR/firefox-fixture/firefox/application.ini"
printf 'icon\n' > "$STATE_DIR/firefox-fixture/firefox/browser/chrome/icons/default/default128.png"
chmod +x "$STATE_DIR/firefox-fixture/firefox/firefox"
tar -cJf "$STATE_DIR/firefox.tar.xz" -C "$STATE_DIR/firefox-fixture" firefox

cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-m" ]; then
    printf 'x86_64\n'
else
    printf 'Linux\n'
fi
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
state="${FLATPAK_TEST_STATE:?}"
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
printf '%s\n' "$url" >> "$state/curl-urls"
case "$url" in
    *pcConfig.json)
        cat > "$output" <<'JSON'
{"Linux":{"x64DownloadUrl":{"appimage":"https://qqdl.gtimg.cn/qqfile/test/QQ_x86_64.AppImage"}}}
JSON
        ;;
    https://qqdl.gtimg.cn/qqfile/*.AppImage)
        printf '\177ELFtest-qq-appimage\n' > "$output"
        ;;
    https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage)
        printf '\177ELFtest-wechat-appimage\n' > "$output"
        ;;
    *rustdesk-1.4.9-x86_64.AppImage)
        printf '\177ELFtest-rustdesk-appimage\n' > "$output"
        ;;
    *firefox-152.0.6.tar.xz)
        cp "$state/firefox.tar.xz" "$output"
        ;;
    *summary.idx)
        case "$url" in
            *sjtu*) printf '0.100' ;;
            *) printf '0.200' ;;
        esac
        ;;
    *)
        cat > "$output" <<'REPO'
[Flatpak Repo]
Title=Flathub
Url=https://dl.flathub.org/repo/
GPGKey=test-key
REPO
        ;;
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

cat > "$BIN_DIR/xdg-mime" <<'EOF'
#!/bin/sh
printf 'xdg-mime %s\n' "$*" >> "${FLATPAK_TEST_STATE:?}/desktop-calls"
EOF

cat > "$BIN_DIR/xdg-settings" <<'EOF'
#!/bin/sh
printf 'xdg-settings %s\n' "$*" >> "${FLATPAK_TEST_STATE:?}/desktop-calls"
EOF

cat > "$BIN_DIR/update-desktop-database" <<'EOF'
#!/bin/sh
printf 'update-desktop-database %s\n' "$*" >> "${FLATPAK_TEST_STATE:?}/desktop-calls"
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
        [ "${FLATPAK_TEST_FAIL_INSTALL:-0}" != "1" ] || exit 1
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
: > "$STATE_DIR/commands"
: > "$STATE_DIR/curl-urls"
: > "$STATE_DIR/desktop-calls"

PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_WECHAT_APPIMAGE_PATH="$STATE_DIR/apps/WeChat.AppImage" \
ZHOUKEER_WECHAT_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" wechat >/dev/null

SHORTCUT="$HOME_DIR/Desktop/微信.desktop"
[ -x "$STATE_DIR/apps/WeChat.AppImage" ]
[ -x "$SHORTCUT" ]
grep -Fq "Exec=\"$STATE_DIR/apps/WeChat.AppImage\"" "$SHORTCUT"
grep -Fq 'Icon=wechat' "$SHORTCUT"
grep -Fxq 'https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage' \
    "$STATE_DIR/curl-urls"
! grep -Fq 'com.tencent.WeChat' "$STATE_DIR/commands"

# 已安装时只修复快捷方式，不应再次下载。
rm -f "$SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_WECHAT_APPIMAGE_PATH="$STATE_DIR/apps/WeChat.AppImage" \
ZHOUKEER_WECHAT_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" wechat >/dev/null

[ -x "$SHORTCUT" ]
[ "$(grep -c 'WeChatLinux_x86_64.AppImage$' "$STATE_DIR/curl-urls")" -eq 1 ]

# QQ 改用两个国内 Flathub 缓存，避免腾讯 AppImage CDN 返回 403。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" qq >/dev/null

QQ_SHORTCUT="$HOME_DIR/Desktop/QQ.desktop"
[ -x "$QQ_SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.qq.QQ' "$QQ_SHORTCUT"
grep -Fq 'Icon=com.qq.QQ' "$QQ_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.qq.QQ' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.com.qq.QQ" ]

# QQ 已安装时只修复快捷方式，不重复安装。
rm -f "$QQ_SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" qq >/dev/null
[ -x "$QQ_SHORTCUT" ]
[ "$(grep -c 'com.qq.QQ' "$STATE_DIR/commands")" -eq 1 ]

# Firefox 与 QQ 共用两个国内 Flathub 缓存，主缓存成功后不应继续切换来源。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" browser >/dev/null

FIREFOX_SHORTCUT="$HOME_DIR/Desktop/Firefox浏览器.desktop"
[ -x "$FIREFOX_SHORTCUT" ]
grep -Fq 'Name=Firefox浏览器' "$FIREFOX_SHORTCUT"
grep -Fq 'Exec=flatpak run org.mozilla.firefox' "$FIREFOX_SHORTCUT"
grep -Fq 'Icon=org.mozilla.firefox' "$FIREFOX_SHORTCUT"
grep -Fq 'Categories=Network;WebBrowser;' "$FIREFOX_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn org.mozilla.firefox' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.org.mozilla.firefox" ]
! grep -Fq 'firefox-152.0.6.tar.xz' "$STATE_DIR/curl-urls"
! grep -Fq 'flathub-ustc org.mozilla.firefox' "$STATE_DIR/commands"
! grep -Fq ' flathub org.mozilla.firefox' "$STATE_DIR/commands"

# Firefox 已安装时只修复快捷方式，不重复安装。
rm -f "$FIREFOX_SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" browser >/dev/null

[ -x "$FIREFOX_SHORTCUT" ]
[ "$(grep -c 'org.mozilla.firefox' "$STATE_DIR/commands")" -eq 1 ]

# RustDesk 使用作者 GitHub Release 的 AppImage，不依赖 Flatpak，并创建可点击的桌面图标。
if command -v sha256sum >/dev/null 2>&1; then
    RUSTDESK_TEST_SHA256="$(printf '\177ELFtest-rustdesk-appimage\n' | sha256sum | awk '{print $1}')"
else
    RUSTDESK_TEST_SHA256="$(printf '\177ELFtest-rustdesk-appimage\n' | shasum -a 256 | awk '{print $1}')"
fi
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_RUSTDESK_APPIMAGE_PATH="$STATE_DIR/apps/RustDesk.AppImage" \
ZHOUKEER_RUSTDESK_SHA256="$RUSTDESK_TEST_SHA256" \
ZHOUKEER_RUSTDESK_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" rustdesk >/dev/null

RUSTDESK_SHORTCUT="$HOME_DIR/Desktop/RustDesk.desktop"
[ -x "$STATE_DIR/apps/RustDesk.AppImage" ]
[ -x "$RUSTDESK_SHORTCUT" ]
grep -Fq "Exec=\"$STATE_DIR/apps/RustDesk.AppImage\"" "$RUSTDESK_SHORTCUT"
grep -Fq 'Icon=rustdesk' "$RUSTDESK_SHORTCUT"
grep -Fq 'https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.AppImage' \
    "$STATE_DIR/curl-urls"
! grep -Fiq 'anydesk' "$PROJECT_ROOT/modules/software.sh"

# 两个国内缓存都失败时必须停止，不能继续寻找官方源。
rm -f "$STATE_DIR/installed.com.qq.QQ"
set +e
failure_output="$(
    PATH="$BIN_DIR:$PATH" \
    HOME="$HOME_DIR" \
    FLATPAK_TEST_STATE="$STATE_DIR" \
    FLATPAK_TEST_FAIL_INSTALL=1 \
    ZHOUKEER_AUTO_CONFIRM=1 \
    bash "$PROJECT_ROOT/modules/software.sh" qq 2>&1
)"
failure_status=$?
set -e
[ "$failure_status" -ne 0 ]
printf '%s\n' "$failure_output" | grep -Fq '两个国内缓存均失败或超时'
printf '%s\n' "$failure_output" | grep -Fq '不再额外寻找Flathub官方源'
# 首轮失败后修复一次 Flatpak 环境，再对两个国内缓存各重试一次。
[ "$(printf '%s\n' "$failure_output" | grep -c '正在从 flathub-.*安装\|正在从 flathub-cn 安装')" -eq 4 ]
! grep -Fq ' flathub com.qq.QQ' "$STATE_DIR/commands"
! grep -Fq 'https://dl.flathub.org/repo/summary.idx' "$STATE_DIR/curl-urls"

echo "PASS: 微信、QQ、Firefox国内Flatpak双缓存和桌面快捷方式测试通过"
