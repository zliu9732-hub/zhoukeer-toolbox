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
        printf 'remote-add %s\n' "$*" >> "$state/commands"
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
        case "${1:-}" in --user|--system) shift ;; esac
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
    uninstall)
        printf 'uninstall %s\n' "$*" >> "$state/commands"
        app_id=""
        for arg in "$@"; do
            case "$arg" in --*) ;; *) app_id="$arg" ;; esac
        done
        [ -n "$app_id" ] || exit 1
        rm -f "$state/installed.$app_id"
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
grep -Fq "Icon=$PROJECT_ROOT/assets/software/wechat.png" "$SHORTCUT"
[ "$(shasum -a 256 "$PROJECT_ROOT/assets/software/wechat.png" | awk '{print $1}')" = \
    '9381f14469bd3dcb67c842384a47ea220790c601870e71393ded1e943e46f1f4' ] || {
    echo "FAIL: 微信未使用已核验的官方图标" >&2
    exit 1
}
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
[ "$(sed -n 's/^Icon=//p' "$SHORTCUT")" = "$PROJECT_ROOT/assets/software/wechat.png" ]
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
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-cn https://mirror.sjtu.edu.cn/flathub' \
    "$STATE_DIR/commands"
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-ustc https://mirrors.ustc.edu.cn/flathub' \
    "$STATE_DIR/commands"
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

# 其余 Flatpak 菜单入口也必须先查询安装状态，已安装时不得再次调用 install。
for app_id in \
    com.google.Chrome \
    com.microsoft.Edge \
    com.github.Matoking.protontricks \
    com.usebottles.bottles \
    com.baidu.NetDisk \
    cn.xfangfang.wiliwili; do
    touch "$STATE_DIR/installed.$app_id"
done
flatpak_calls_before="$(grep -c '^install ' "$STATE_DIR/commands")"
for target in chrome edge protontricks bottles baidunetdisk willwill; do
    output="$(PATH="$BIN_DIR:$PATH" \
        HOME="$HOME_DIR" \
        FLATPAK_TEST_STATE="$STATE_DIR" \
        ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$PROJECT_ROOT/modules/software.sh" "$target")"
    printf '%s\n' "$output" | grep -Fq '[已安装]' || {
        echo "FAIL: $target 未报告已安装" >&2
        exit 1
    }
done
flatpak_calls_after="$(grep -c '^install ' "$STATE_DIR/commands")"
[ "$flatpak_calls_before" = "$flatpak_calls_after" ] || {
    echo "FAIL: 已安装 Flatpak 软件仍被重复安装" >&2
    exit 1
}

# 卸载页必须只移除选中的应用和快捷方式，不影响其他已安装软件。
mkdir -p "$HOME_DIR/Desktop"
: > "$HOME_DIR/Desktop/com.google.Chrome.desktop"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" uninstall chrome >/dev/null
[ ! -e "$STATE_DIR/installed.com.google.Chrome" ]
[ ! -e "$HOME_DIR/Desktop/com.google.Chrome.desktop" ]
[ -e "$STATE_DIR/installed.com.microsoft.Edge" ]
grep -Fq 'uninstall --user --noninteractive -y com.google.Chrome' "$STATE_DIR/commands"

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
# AnyDesk 与其他常用软件一样走用户级 Flatpak、国内缓存、已安装检测和桌面入口。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" anydesk >/dev/null
ANYDESK_SHORTCUT="$HOME_DIR/Desktop/AnyDesk.desktop"
[ -x "$ANYDESK_SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.anydesk.Anydesk' "$ANYDESK_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.anydesk.Anydesk' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.com.anydesk.Anydesk" ]

# PeaZip 复用常用软件的用户级 Flatpak 国内缓存、安装验证和桌面入口。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" peazip >/dev/null
PEAZIP_SHORTCUT="$HOME_DIR/Desktop/PeaZip.desktop"
[ -x "$PEAZIP_SHORTCUT" ]
grep -Fq 'Exec=flatpak run io.github.peazip.PeaZip' "$PEAZIP_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn io.github.peazip.PeaZip' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.io.github.peazip.PeaZip" ]

# WiliWili 复用常用软件的用户级 Flatpak 国内缓存，并加入 Steam 库。
mkdir -p "$HOME_DIR/.local/share/Steam/steamapps" \
    "$HOME_DIR/.local/share/Steam/userdata/123/config"
: > "$HOME_DIR/.local/share/Steam/userdata/123/config/shortcuts.vdf"
rm -f "$STATE_DIR/installed.cn.xfangfang.wiliwili"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_APP_DIR="$STATE_DIR/apps" \
ZHOUKEER_SKIP_STEAM_RESTART=1 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" willwill >/dev/null
WILIWILI_SHORTCUT="$HOME_DIR/Desktop/WiliWili.desktop"
[ -x "$WILIWILI_SHORTCUT" ]
grep -Fq 'Exec=flatpak run cn.xfangfang.wiliwili' "$WILIWILI_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn cn.xfangfang.wiliwili' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.cn.xfangfang.wiliwili" ]
WILIWILI_WRAPPER="$STATE_DIR/apps/game-launchers/willwill/launch-willwill.sh"
[ -x "$WILIWILI_WRAPPER" ] || {
    echo "FAIL: WiliWili 启动包装器未创建" >&2
    exit 1
}
grep -Fq 'exec flatpak run cn.xfangfang.wiliwili' "$WILIWILI_WRAPPER"
python3 - "$HOME_DIR/.local/share/Steam/userdata/123/config/shortcuts.vdf" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert "WiliWili".encode() in data
assert b"launch-willwill.sh" in data
PY

# Xbox 云游戏通过 Flathub 安装 Greenlight，并创建名称明确的桌面入口。
rm -f "$STATE_DIR/installed.io.github.unknownskl.greenlight"
mkdir -p "$HOME_DIR/.local/share/Steam/steamapps" \
    "$HOME_DIR/.local/share/Steam/userdata/123/config"
: > "$HOME_DIR/.local/share/Steam/userdata/123/config/shortcuts.vdf"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_APP_DIR="$STATE_DIR/apps" \
ZHOUKEER_SKIP_STEAM_RESTART=1 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" xbox-cloud >/dev/null
XBOX_SHORTCUT="$HOME_DIR/Desktop/Xbox 云游戏.desktop"
[ -x "$XBOX_SHORTCUT" ]
grep -Fq 'Exec=flatpak run io.github.unknownskl.greenlight' "$XBOX_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn io.github.unknownskl.greenlight' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.io.github.unknownskl.greenlight" ]
XBOX_WRAPPER="$STATE_DIR/apps/game-launchers/xbox-cloud/launch-xbox-cloud.sh"
[ -x "$XBOX_WRAPPER" ] || {
    echo "FAIL: Xbox 云游戏启动包装器未创建" >&2
    exit 1
}
python3 - "$HOME_DIR/.local/share/Steam/userdata/123/config/shortcuts.vdf" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert "Xbox 云游戏".encode() in data
assert b"launch-xbox-cloud.sh" in data
PY

# Heroic 等游戏/串流应用复用通用 Steam 入库，安装后创建包装器并写入 Steam 库。
rm -f "$STATE_DIR/installed.com.heroicgameslauncher.hgl"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_APP_DIR="$STATE_DIR/apps" \
ZHOUKEER_SKIP_STEAM_RESTART=1 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" heroic >/dev/null
HEROIC_SHORTCUT="$HOME_DIR/Desktop/Heroic.desktop"
[ -x "$HEROIC_SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.heroicgameslauncher.hgl' "$HEROIC_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.heroicgameslauncher.hgl' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.com.heroicgameslauncher.hgl" ]
HEROIC_WRAPPER="$STATE_DIR/apps/game-launchers/heroic/launch-heroic.sh"
[ -x "$HEROIC_WRAPPER" ] || {
    echo "FAIL: Heroic 启动包装器未创建" >&2
    exit 1
}
grep -Fq 'exec flatpak run com.heroicgameslauncher.hgl' "$HEROIC_WRAPPER"
python3 - "$HOME_DIR/.local/share/Steam/userdata/123/config/shortcuts.vdf" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert "Heroic 游戏启动器".encode() in data
assert b"launch-heroic.sh" in data
assert "Xbox 云游戏".encode() in data
PY

# 新音乐应用走同一套 Flatpak 国内缓存安装流程。
rm -f "$STATE_DIR/installed.com.qq.QQmusic"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" qqmusic >/dev/null
QQMUSIC_SHORTCUT="$HOME_DIR/Desktop/QQ音乐.desktop"
[ -x "$QQMUSIC_SHORTCUT" ]
grep -Fq 'Exec=flatpak run com.qq.QQmusic' "$QQMUSIC_SHORTCUT"
grep -Fq 'install --user --noninteractive -y flathub-cn com.qq.QQmusic' "$STATE_DIR/commands"
[ -f "$STATE_DIR/installed.com.qq.QQmusic" ]

# 通用卸载会移除 Steam 条目、包装器与桌面图标，不影响其他 Steam 条目。
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_APP_DIR="$STATE_DIR/apps" \
ZHOUKEER_SKIP_STEAM_RESTART=1 \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" uninstall heroic >/dev/null
[ ! -e "$STATE_DIR/installed.com.heroicgameslauncher.hgl" ]
[ ! -e "$HEROIC_WRAPPER" ]
[ ! -e "$HEROIC_SHORTCUT" ]
python3 - "$HOME_DIR/.local/share/Steam/userdata/123/config/shortcuts.vdf" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert "Heroic 游戏启动器".encode() not in data
assert "Xbox 云游戏".encode() in data
PY

PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
bash "$PROJECT_ROOT/modules/software.sh" uninstall qqmusic >/dev/null
[ ! -e "$STATE_DIR/installed.com.qq.QQmusic" ]
[ ! -e "$QQMUSIC_SHORTCUT" ]

# Flatpak 安装彻底失败时，必须提示先初始化国内源，而不是只报任务失败。
rm -f "$STATE_DIR/installed.com.baidu.NetDisk"
set +e
failed_output="$(PATH="$BIN_DIR:$PATH" \
    HOME="$HOME_DIR" \
    FLATPAK_TEST_STATE="$STATE_DIR" \
    FLATPAK_TEST_FAIL_INSTALL=1 \
    ZHOUKEER_AUTO_CONFIRM=1 \
    bash "$PROJECT_ROOT/modules/software.sh" baidunetdisk 2>&1)"
failed_status=$?
set -e
[ "$failed_status" -ne 0 ] || {
    echo "FAIL: 模拟百度网盘安装失败仍返回成功" >&2
    exit 1
}
printf '%s\n' "$failed_output" | grep -Fq '请先在Renkit【初始化国内源并检测系统组件】中初始化国内源后重试。' || {
    echo "FAIL: 百度网盘安装失败时未提示初始化国内源" >&2
    exit 1
}

# repair-shortcuts 必须补齐丢失的桌面快捷方式，且不重复下载或安装。
rm -f "$SHORTCUT" "$RUSTDESK_SHORTCUT"
touch "$STATE_DIR/installed.org.libreoffice.LibreOffice"
curl_calls_before="$(wc -l < "$STATE_DIR/curl-urls" | tr -d '[:space:]')"
flatpak_calls_before="$(wc -l < "$STATE_DIR/commands" | tr -d '[:space:]')"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_WECHAT_APPIMAGE_PATH="$STATE_DIR/apps/WeChat.AppImage" \
ZHOUKEER_WECHAT_MIN_BYTES=4 \
ZHOUKEER_RUSTDESK_APPIMAGE_PATH="$STATE_DIR/apps/RustDesk.AppImage" \
ZHOUKEER_RUSTDESK_MIN_BYTES=4 \
bash "$PROJECT_ROOT/modules/software.sh" repair-shortcuts >/dev/null
[ -x "$SHORTCUT" ]
[ -x "$RUSTDESK_SHORTCUT" ]
[ -x "$HOME_DIR/Desktop/LibreOffice.desktop" ]
[ "$(wc -l < "$STATE_DIR/curl-urls" | tr -d '[:space:]')" = "$curl_calls_before" ]
[ "$(wc -l < "$STATE_DIR/commands" | tr -d '[:space:]')" = "$flatpak_calls_before" ]

install_source="$(cat "$PROJECT_ROOT/install.sh")"
printf '%s\n' "$install_source" | grep -Fq 'repair-shortcuts' || {
    echo "FAIL: 安装器未在更新后重建桌面快捷方式" >&2
    exit 1
}
if printf '%s\n' "$install_source" | grep -Fq 'apps/rustdesk.AppImage"'; then
    echo "FAIL: 安装器仍会在更新时删除 RustDesk AppImage" >&2
    exit 1
fi

# 两个国内缓存都失败时必须停止，不能继续寻找官方源。
rm -f "$STATE_DIR/installed.com.qq.QQ"
remote_modify_before_failure="$(grep -c '^modify ' "$STATE_DIR/commands")"
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
printf '%s\n' "$failure_output" | grep -Fq '检测到下载源不可用，正在切换至国内源，请耐心等待'
# 首轮失败后修复一次 Flatpak 环境，再对两个国内缓存各重试一次。
[ "$(grep -c '^install .* com.qq.QQ$' "$STATE_DIR/commands")" -eq 5 ]
[ "$(( $(grep -c '^modify ' "$STATE_DIR/commands") - remote_modify_before_failure ))" -eq 4 ]
! grep -Fq ' flathub com.qq.QQ' "$STATE_DIR/commands"
! grep -Fq 'https://dl.flathub.org/repo/summary.idx' "$STATE_DIR/curl-urls"

# Fcitx5 中文输入法必须同时安装主程序与中文输入插件。
rm -f "$STATE_DIR/commands"
PATH="$BIN_DIR:$PATH" \
HOME="$HOME_DIR" \
FLATPAK_TEST_STATE="$STATE_DIR" \
ZHOUKEER_AUTO_CONFIRM=1 \
MODULE="$PROJECT_ROOT/modules/software.sh" \
bash -c '
    source "$MODULE"
    software_details fcitx5
    run_flatpak_install "flathub-cn"
'
grep -Fq 'install --user --noninteractive -y flathub-cn org.fcitx.Fcitx5 org.fcitx.Fcitx5.Addon.ChineseAddons' \
    "$STATE_DIR/commands" || {
    echo "FAIL: Fcitx5 安装没有同时带上中文输入插件" >&2
    exit 1
}

echo "PASS: 微信、QQ、Firefox国内Flatpak双缓存和桌面快捷方式测试通过"
