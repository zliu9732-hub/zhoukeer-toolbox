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

# QQ 使用腾讯官网动态配置和国内 CDN，不经过 Flatpak。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_APP_DIR="$STATE_DIR/apps" \
ZHOUKEER_QQ_APPIMAGE_PATH="$STATE_DIR/apps/QQ.AppImage" \
ZHOUKEER_QQ_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" qq >/dev/null

QQ_SHORTCUT="$HOME_DIR/Desktop/QQ.desktop"
[ -x "$STATE_DIR/apps/QQ.AppImage" ]
[ -x "$QQ_SHORTCUT" ]
grep -Fq "Exec=\"$STATE_DIR/apps/QQ.AppImage\"" "$QQ_SHORTCUT"
grep -Fq 'Icon=qq' "$QQ_SHORTCUT"
grep -Fxq 'https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json' \
    "$STATE_DIR/curl-urls"
grep -Fxq 'https://qqdl.gtimg.cn/qqfile/test/QQ_x86_64.AppImage' \
    "$STATE_DIR/curl-urls"
! grep -Fq 'com.qq.QQ' "$STATE_DIR/commands"

# QQ 已安装时只修复快捷方式，不重复下载。
rm -f "$QQ_SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_QQ_APPIMAGE_PATH="$STATE_DIR/apps/QQ.AppImage" \
ZHOUKEER_QQ_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" qq >/dev/null
[ -x "$QQ_SHORTCUT" ]
[ "$(grep -c 'QQ_x86_64.AppImage$' "$STATE_DIR/curl-urls")" -eq 1 ]

# Firefox 使用完整压缩包，不经过 Flatpak。
touch "$HOME_DIR/Desktop/Chrome浏览器.desktop" \
    "$HOME_DIR/Desktop/Chromium浏览器.desktop"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_FIREFOX_INSTALL_DIR="$STATE_DIR/apps/firefox" \
ZHOUKEER_FIREFOX_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" browser >/dev/null

FIREFOX_SHORTCUT="$HOME_DIR/Desktop/Firefox浏览器.desktop"
FIREFOX_APPLICATION="$HOME_DIR/.local/share/applications/zhoukeer-firefox.desktop"
[ -x "$STATE_DIR/apps/firefox/firefox" ]
[ -x "$FIREFOX_SHORTCUT" ]
[ -x "$FIREFOX_APPLICATION" ]
[ ! -e "$HOME_DIR/Desktop/Chrome浏览器.desktop" ]
[ ! -e "$HOME_DIR/Desktop/Chromium浏览器.desktop" ]
grep -Fq 'Name=Firefox浏览器' "$FIREFOX_SHORTCUT"
grep -Fq "Exec=\"$STATE_DIR/apps/firefox/firefox\" %u" "$FIREFOX_SHORTCUT"
grep -Fq "Icon=$STATE_DIR/apps/firefox/browser/chrome/icons/default/default128.png" \
    "$FIREFOX_SHORTCUT"
grep -Fq 'Categories=Network;WebBrowser;' "$FIREFOX_SHORTCUT"
grep -Fq 'MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;' \
    "$FIREFOX_APPLICATION"
grep -Fxq 'xdg-mime default zhoukeer-firefox.desktop text/html' "$STATE_DIR/desktop-calls"
grep -Fxq 'xdg-mime default zhoukeer-firefox.desktop x-scheme-handler/http' \
    "$STATE_DIR/desktop-calls"
grep -Fxq 'xdg-mime default zhoukeer-firefox.desktop x-scheme-handler/https' \
    "$STATE_DIR/desktop-calls"
grep -Fxq 'xdg-settings set default-web-browser zhoukeer-firefox.desktop' \
    "$STATE_DIR/desktop-calls"
grep -Fq '1846467258.cdn.123clouddisk.com/1846467258/工具箱/firefox-152.0.6.tar.xz' \
    "$STATE_DIR/curl-urls"
! grep -Fq 'org.chromium.Chromium' "$STATE_DIR/commands"

# Firefox 已安装时只修复快捷方式，不重复下载。
rm -f "$FIREFOX_SHORTCUT"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_FIREFOX_INSTALL_DIR="$STATE_DIR/apps/firefox" \
ZHOUKEER_FIREFOX_MIN_BYTES=4 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" browser >/dev/null

[ -x "$FIREFOX_SHORTCUT" ]
[ "$(grep -c 'firefox-152.0.6.tar.xz$' "$STATE_DIR/curl-urls")" -eq 1 ]

# 远程协助：RustDesk 与 AnyDesk 都必须使用用户级 Flatpak，并创建可点击的桌面图标。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" rustdesk >/dev/null

RUSTDESK_SHORTCUT="$HOME_DIR/Desktop/RustDesk.desktop"
[ -x "$RUSTDESK_SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.rustdesk.RustDesk' "$RUSTDESK_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.rustdesk.RustDesk' \
    "$STATE_DIR/commands"
grep -Fq 'modify --user flathub-cn --url=https://mirror.sjtu.edu.cn/flathub' \
    "$STATE_DIR/commands"
grep -Fq 'modify --user flathub-ustc --url=https://mirrors.ustc.edu.cn/flathub' \
    "$STATE_DIR/commands"

PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" anydesk >/dev/null

ANYDESK_SHORTCUT="$HOME_DIR/Desktop/AnyDesk.desktop"
[ -x "$ANYDESK_SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.anydesk.Anydesk' "$ANYDESK_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.anydesk.Anydesk' \
    "$STATE_DIR/commands"

# 两个国内缓存都失败时必须停止，不能继续寻找官方源。
rm -f "$STATE_DIR/installed.com.rustdesk.RustDesk"
set +e
failure_output="$(
    PATH="$BIN_DIR:$PATH" \
    HOME="$HOME_DIR" \
    FLATPAK_TEST_STATE="$STATE_DIR" \
    FLATPAK_TEST_FAIL_INSTALL=1 \
    ZHOUKEER_AUTO_CONFIRM=1 \
    bash "$PROJECT_ROOT/modules/software.sh" rustdesk 2>&1
)"
failure_status=$?
set -e
[ "$failure_status" -ne 0 ]
printf '%s\n' "$failure_output" | grep -Fq '两个国内缓存均失败或超时'
printf '%s\n' "$failure_output" | grep -Fq '不再连接Flathub官方源'
[ "$(printf '%s\n' "$failure_output" | grep -c '正在从 flathub-.*安装\|正在从 flathub-cn 安装')" -eq 2 ]
! grep -Fq ' flathub com.rustdesk.RustDesk' "$STATE_DIR/commands"
! grep -Fq 'https://dl.flathub.org/repo/summary.idx' "$STATE_DIR/curl-urls"

echo "PASS: 微信、QQ、Firefox完整包、国内Flatpak双缓存和桌面快捷方式测试通过"
