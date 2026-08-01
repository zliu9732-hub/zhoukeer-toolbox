#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/todesk.sh"
TMP_ROOT="$(mktemp -d)"
CACHE_DIR="$TMP_ROOT/pacman-cache"
CERT_FILE="$TMP_ROOT/ca-certificates.crt"
LOG_FILE="$TMP_ROOT/pacman.log"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

mkdir -p "$CACHE_DIR"
: > "$CACHE_DIR/ca-certificates-2026.1-1-any.pkg.tar.zst"
: > "$CACHE_DIR/ca-certificates-utils-2026.1-1-any.pkg.tar.zst"

MODULE="$MODULE" CACHE_DIR="$CACHE_DIR" CERT_FILE="$CERT_FILE" TEST_TODESK_LOG="$LOG_FILE" bash -c '
    source "$MODULE"
    TODESK_CA_BUNDLE_PATHS="$CERT_FILE"
    TODESK_PACMAN_CACHE_DIR="$CACHE_DIR"
    toolbox_sudo() {
        printf "%s\n" "$*" >> "$TEST_TODESK_LOG"
        if [ "$1" = pacman ] && [ "$2" = -U ]; then
            printf "%s\\n" test-certificate > "$CERT_FILE"
        fi
        "$@"
    }
    pacman() { return 0; }
    ensure_todesk_ca_certificates
'

grep -Fq 'pacman -U --noconfirm --needed' "$LOG_FILE" || {
    echo "FAIL: 缺失证书时没有仅使用本机 pacman 缓存恢复" >&2
    exit 1
}
[ -s "$CERT_FILE" ] || {
    echo "FAIL: 证书恢复后没有重新检查证书文件" >&2
    exit 1
}

rm -f -- "$CERT_FILE"
rm -f -- "$CACHE_DIR"/*
set +e
missing_output="$(
    MODULE="$MODULE" CACHE_DIR="$CACHE_DIR" CERT_FILE="$CERT_FILE" bash -c '
        source "$MODULE"
        TODESK_CA_BUNDLE_PATHS="$CERT_FILE"
        TODESK_PACMAN_CACHE_DIR="$CACHE_DIR"
        ensure_todesk_ca_certificates
    ' 2>&1
)"
missing_status=$?
set -e
[ "$missing_status" -ne 0 ] || {
    echo "FAIL: 没有本机证书缓存时仍继续 ToDesk 安装" >&2
    exit 1
}
printf '%s\n' "$missing_output" | grep -Fq '不会关闭 HTTPS 或签名验证' || {
    echo "FAIL: 缺失证书时没有说明安全停止原因" >&2
    exit 1
}

PAYLOAD_ROOT="$TMP_ROOT/payload"
CONTROL_ROOT="$TMP_ROOT/control"
DEB_ROOT="$TMP_ROOT/deb-root"
FAKE_DEB="$TMP_ROOT/todesk-v4.8.6.2-amd64.deb"
BUILD_APPS="$TMP_ROOT/apps"
mkdir -p \
    "$PAYLOAD_ROOT/opt/todesk/bin" \
    "$PAYLOAD_ROOT/opt/todesk/res" \
    "$PAYLOAD_ROOT/etc/systemd/system" \
    "$PAYLOAD_ROOT/usr/local/bin" \
    "$PAYLOAD_ROOT/usr/share/applications" \
    "$PAYLOAD_ROOT/usr/share/icons/hicolor/128x128/apps" \
    "$CONTROL_ROOT" "$DEB_ROOT" "$BUILD_APPS"
for binary in ToDesk ToDesk_Service ToDesk_Session; do
    printf '#!/bin/sh\nexit 0\n' > "$PAYLOAD_ROOT/opt/todesk/bin/$binary"
    chmod +x "$PAYLOAD_ROOT/opt/todesk/bin/$binary"
done
printf '#!/bin/sh\n/opt/todesk/bin/ToDesk &\n' > "$PAYLOAD_ROOT/usr/local/bin/todesk"
chmod +x "$PAYLOAD_ROOT/usr/local/bin/todesk"
printf '%s\n' \
    '[Unit]' \
    'Description=ToDesk Daemon Service' \
    '[Service]' \
    'ExecStart=/opt/todesk/bin/ToDesk_Service' \
    'User=root' \
    '[Install]' \
    'WantedBy=multi-user.target' > "$PAYLOAD_ROOT/etc/systemd/system/todeskd.service"
printf '%s\n' \
    '[Desktop Entry]' \
    'Name=ToDesk' \
    'Exec=env LIBVA_DRIVER_NAME=iHD /opt/todesk/bin/ToDesk' \
    'Type=Application' > "$PAYLOAD_ROOT/usr/share/applications/todesk.desktop"
printf 'icon\n' > "$PAYLOAD_ROOT/usr/share/icons/hicolor/128x128/apps/todesk.png"
printf '%s\n' \
    'Package: ToDesk' \
    'Version: 4.8.6.2' \
    'Architecture: amd64' \
    'Depends: libgtk-3-0' > "$CONTROL_ROOT/control"
(cd "$PAYLOAD_ROOT" && bsdtar -a -cf "$DEB_ROOT/data.tar.zst" .)
(cd "$CONTROL_ROOT" && bsdtar -a -cf "$DEB_ROOT/control.tar.zst" .)
printf '2.0\n' > "$DEB_ROOT/debian-binary"
(cd "$DEB_ROOT" && ar -rcS "$FAKE_DEB" debian-binary control.tar.zst data.tar.zst)
FAKE_DEB_SHA="$(shasum -a 256 "$FAKE_DEB" | awk '{print $1}')"

BUILT_PATH_FILE="$TMP_ROOT/built-path"
MODULE="$MODULE" FAKE_DEB="$FAKE_DEB" FAKE_DEB_SHA="$FAKE_DEB_SHA" \
    BUILD_APPS="$BUILD_APPS" BUILT_PATH_FILE="$BUILT_PATH_FILE" bash -c '
    source "$MODULE"
    TODESK_OFFICIAL_DEB_URL="https://example.invalid/todesk-v4.8.6.2-amd64.deb"
    TODESK_OFFICIAL_DEB_SHA256="$FAKE_DEB_SHA"
    TODESK_OFFICIAL_DEB_MIN_BYTES=1
    APP_DIR="$BUILD_APPS"
    download_policy_url_allowed() { return 0; }
    download_policy_max_bytes() { printf "%s\n" 268435456; }
    curl() {
        local output=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --output) output="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        cp -- "$FAKE_DEB" "$output"
    }
    download_todesk_package
    printf "%s\n" "$TODESK_DOWNLOADED_PACKAGE" > "$BUILT_PATH_FILE"
'
BUILT_PACKAGE="$(cat "$BUILT_PATH_FILE")"
[ -s "$BUILT_PACKAGE" ] || {
    echo "FAIL: 未从官方 DEB 生成本地 pacman 软件包" >&2
    exit 1
}
PKGINFO="$(bsdtar -xOf "$BUILT_PACKAGE" .PKGINFO)"
printf '%s\n' "$PKGINFO" | grep -Fxq 'pkgver = 4.8.6.2-1' || {
    echo "FAIL: 本地 ToDesk 软件包版本不正确" >&2
    exit 1
}
if printf '%s\n' "$PKGINFO" | grep -Fq 'libappindicator'; then
    echo "FAIL: 本地 ToDesk 软件包仍依赖已失效的 libappindicator" >&2
    exit 1
fi
bsdtar -tf "$BUILT_PACKAGE" | grep -Fxq 'usr/lib/systemd/system/todeskd.service' || {
    echo "FAIL: ToDesk 服务未转换到 Arch systemd 目录" >&2
    exit 1
}
bsdtar -tf "$BUILT_PACKAGE" | grep -Fxq 'usr/bin/todesk' || {
    echo "FAIL: ToDesk 启动命令未转换到 /usr/bin" >&2
    exit 1
}
bsdtar -tvf "$BUILT_PACKAGE" | grep -Eq '^drwxr-xr-x .* opt/todesk/config/$' || {
    echo "FAIL: ToDesk 配置目录缺失或权限不安全" >&2
    exit 1
}
if bsdtar -tf "$BUILT_PACKAGE" | grep -Eq '^(\.INSTALL|etc/systemd|usr/local/)'; then
    echo "FAIL: 本地包包含官方维护脚本或不合适的 Debian 路径" >&2
    exit 1
fi

BROWSER_HOME="$TMP_ROOT/browser-home"
BROWSER_APPS="$TMP_ROOT/browser-apps"
BROWSER_LOG="$TMP_ROOT/browser.log"
mkdir -p "$BROWSER_HOME" "$BROWSER_APPS"
MODULE="$MODULE" FAKE_DEB="$FAKE_DEB" FAKE_DEB_SHA="$FAKE_DEB_SHA" \
    BROWSER_HOME="$BROWSER_HOME" BROWSER_APPS="$BROWSER_APPS" \
    BROWSER_LOG="$BROWSER_LOG" HOME="$BROWSER_HOME" bash -c '
    source "$MODULE"
    TODESK_OFFICIAL_DEB_URL="https://example.invalid/todesk-v4.8.6.2-amd64.deb"
    TODESK_OFFICIAL_DEB_SHA256="$FAKE_DEB_SHA"
    TODESK_OFFICIAL_DEB_MIN_BYTES=1
    TODESK_BROWSER_WAIT_SECONDS=2
    APP_DIR="$BROWSER_APPS"
    download_policy_url_allowed() { return 0; }
    download_policy_max_bytes() { printf "%s\n" 268435456; }
    curl() {
        local output=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --output) output="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        printf "<!doctype html>\n" > "$output"
    }
    xdg-open() {
        printf "%s\n" "$1" >> "$BROWSER_LOG"
        mkdir -p "$HOME/Downloads"
        cp -- "$FAKE_DEB" "$HOME/Downloads/$TODESK_OFFICIAL_DEB_NAME"
    }
    download_todesk_package
    test -s "$TODESK_DOWNLOADED_PACKAGE"
'
[ "$(wc -l < "$BROWSER_LOG")" -eq 1 ] || {
    echo "FAIL: 官网验证页没有触发一次浏览器下载兜底" >&2
    exit 1
}

PACKAGE_FILE="$TMP_ROOT/todesk-bin.pkg.tar.zst"
: > "$PACKAGE_FILE"
INSTALL_LOG="$TMP_ROOT/install.log"
set +e
install_output="$(
    MODULE="$MODULE" PACKAGE_FILE="$PACKAGE_FILE" INSTALL_LOG="$INSTALL_LOG" bash -c '
    source "$MODULE"
    toolbox_sudo() {
        printf "%s\n" "$*" >> "$INSTALL_LOG"
        return 1
    }
    install_verified_todesk_package "$PACKAGE_FILE"
' 2>&1
)"
install_status=$?
set -e
[ "$install_status" -ne 0 ] || {
    echo "FAIL: pacman 失败时 ToDesk 安装仍报告成功" >&2
    exit 1
}
[ "$(wc -l < "$INSTALL_LOG")" -eq 1 ] || {
    echo "FAIL: 本地 pacman 错误仍被无意义重复执行" >&2
    exit 1
}
if printf '%s\n' "$install_output" | grep -Fq '网络或软件源错误'; then
    echo "FAIL: 本地 pacman 错误仍被误报为网络问题" >&2
    exit 1
fi

echo "PASS: ToDesk 官方DEB校验、本地安全转换、证书预检和单次安装测试通过"
