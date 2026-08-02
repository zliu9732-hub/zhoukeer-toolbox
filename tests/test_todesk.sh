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
RELEASE_LOG="$TMP_ROOT/release.log"
MODULE="$MODULE" FAKE_DEB="$FAKE_DEB" FAKE_DEB_SHA="$FAKE_DEB_SHA" \
    BUILD_APPS="$BUILD_APPS" BUILT_PATH_FILE="$BUILT_PATH_FILE" \
    RELEASE_LOG="$RELEASE_LOG" bash -c '
    source "$MODULE"
    TODESK_OFFICIAL_DEB_SHA256="$FAKE_DEB_SHA"
    TODESK_OFFICIAL_DEB_MIN_BYTES=1
    APP_DIR="$BUILD_APPS"
    download_gitee_mirror_file() { return 1; }
    download_github_file() {
        printf "%s|%s|%s\n" "$1" "$3" "$4" >> "$RELEASE_LOG"
        cp -- "$FAKE_DEB" "$2"
    }
    curl() { echo "FAIL: GitHub Release 成功后仍请求官网" >&2; return 1; }
    download_todesk_package
    printf "%s\n" "$TODESK_DOWNLOADED_PACKAGE" > "$BUILT_PATH_FILE"
'
grep -Fxq "https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/v6.0.25/todesk-v4.8.6.2-amd64.deb|$FAKE_DEB_SHA|ToDesk官方安装包" "$RELEASE_LOG" || {
    echo "FAIL: ToDesk 未使用受控 GitHub Release 下载器或未传入固定 SHA256" >&2
    exit 1
}
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

FALLBACK_APPS="$TMP_ROOT/fallback-apps"
FALLBACK_LOG="$TMP_ROOT/fallback.log"
mkdir -p "$FALLBACK_APPS"
MODULE="$MODULE" FAKE_DEB="$FAKE_DEB" FAKE_DEB_SHA="$FAKE_DEB_SHA" \
    FALLBACK_APPS="$FALLBACK_APPS" FALLBACK_LOG="$FALLBACK_LOG" bash -c '
    source "$MODULE"
    TODESK_OFFICIAL_DEB_SHA256="$FAKE_DEB_SHA"
    TODESK_OFFICIAL_DEB_MIN_BYTES=1
    APP_DIR="$FALLBACK_APPS"
    download_policy_max_bytes() { printf "%s\n" 268435456; }
    download_gitee_mirror_file() { return 1; }
    download_github_file() {
        printf "%s\n" "$1" >> "$FALLBACK_LOG"
        return 1
    }
    curl() {
        local output=""
        local url=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --output) output="$2"; shift 2 ;;
                https://*) url="$1"; shift ;;
                *) shift ;;
            esac
        done
        printf "%s\n" "$url" >> "$FALLBACK_LOG"
        cp -- "$FAKE_DEB" "$output"
    }
    download_todesk_package
    test -s "$TODESK_DOWNLOADED_PACKAGE"
'
grep -Fxq 'https://dl.todesk.com/linux/todesk-v4.8.6.2-amd64.deb' "$FALLBACK_LOG" || {
    echo "FAIL: GitHub Release 下载失败后未在后台尝试官网" >&2
    exit 1
}
if grep -Eq 'xdg-open|find_verified_todesk_download|wait_for_todesk_browser_download|TODESK_BROWSER_WAIT_SECONDS' "$MODULE"; then
    echo "FAIL: ToDesk 仍依赖浏览器或用户下载目录" >&2
    exit 1
fi

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

SERVICE_LOG="$TMP_ROOT/service.log"
MODULE="$MODULE" SERVICE_LOG="$SERVICE_LOG" bash -c '
    source "$MODULE"
    toolbox_sudo() {
        printf "%s\n" "$*" >> "$SERVICE_LOG"
    }
    systemctl() {
        case "${1:-}" in
            is-enabled|is-active) return 0 ;;
            *) return 1 ;;
        esac
    }
    configure_todesk_service
'
for expected in \
    'systemctl daemon-reload' \
    'systemctl unmask todeskd.service' \
    'systemctl enable --force todeskd.service' \
    'systemctl restart todeskd.service'; do
    grep -Fxq "$expected" "$SERVICE_LOG" || {
        echo "FAIL: ToDesk 服务修复缺少命令：$expected" >&2
        exit 1
    }
done

REPAIR_LOG="$TMP_ROOT/repair.log"
MODULE="$MODULE" REPAIR_LOG="$REPAIR_LOG" ZHOUKEER_AUTO_CONFIRM=1 bash -c '
    source "$MODULE"
    detect_platform() { IS_STEAMOS=1; }
    require_command() { return 0; }
    todesk_installed_version() { printf "%s\n" "4.8.6.2-1"; }
    todesk_service_is_ready() { [ -f "$REPAIR_LOG.ready" ]; }
    configure_todesk_service() {
        printf "%s\n" service-repair >> "$REPAIR_LOG"
        : > "$REPAIR_LOG.ready"
    }
    download_todesk_package() { printf "%s\n" unexpected-download >> "$REPAIR_LOG"; return 1; }
    install_verified_todesk_package() { printf "%s\n" unexpected-install >> "$REPAIR_LOG"; return 1; }
    steamos-readonly() { [ "${1:-}" = status ] && printf "%s\n" enabled; }
    toolbox_sudo() {
        printf "%s\n" "$*" >> "$REPAIR_LOG"
        return 0
    }
    install_todesk
'
grep -Fxq 'service-repair' "$REPAIR_LOG" || {
    echo "FAIL: 已安装 ToDesk 的异常服务没有进入修复流程" >&2
    exit 1
}
if grep -Eq 'unexpected-(download|install)' "$REPAIR_LOG"; then
    echo "FAIL: ToDesk 服务修复仍重复下载或安装软件包" >&2
    exit 1
fi
grep -Fxq 'steamos-readonly disable' "$REPAIR_LOG" || {
    echo "FAIL: ToDesk 服务修复前没有临时解除只读保护" >&2
    exit 1
}
grep -Fxq 'steamos-readonly enable' "$REPAIR_LOG" || {
    echo "FAIL: ToDesk 服务修复后没有恢复只读保护" >&2
    exit 1
}

UNINSTALL_LOG="$TMP_ROOT/uninstall.log"
set +e
uninstall_output="$(
    MODULE="$MODULE" UNINSTALL_LOG="$UNINSTALL_LOG" ZHOUKEER_AUTO_CONFIRM=1 bash -c '
        source "$MODULE"
        detect_platform() { IS_STEAMOS=1; }
        todesk_is_installed() { return 0; }
        require_command() { return 0; }
        steamos-readonly() { [ "${1:-}" = status ] && printf "%s\n" enabled; }
        systemctl() {
            [ "${1:-}" = is-active ] && return 0
            return 1
        }
        toolbox_sudo() {
            printf "%s\n" "$*" >> "$UNINSTALL_LOG"
            if [ "${1:-}" = systemctl ] && [ "${2:-}" = disable ]; then
                return 1
            fi
            return 0
        }
        uninstall_todesk
    ' 2>&1
)"
uninstall_status=$?
set -e
[ "$uninstall_status" -ne 0 ] || {
    echo "FAIL: ToDesk 服务停用失败时卸载仍报告成功" >&2
    exit 1
}
printf '%s\n' "$uninstall_output" | grep -Fq '软件包尚未卸载' || {
    echo "FAIL: ToDesk 卸载没有显示服务停用失败位置" >&2
    exit 1
}
if grep -Fq 'pacman -Rns' "$UNINSTALL_LOG"; then
    echo "FAIL: ToDesk 服务停用失败后仍删除软件包" >&2
    exit 1
fi
grep -Fxq 'steamos-readonly enable' "$UNINSTALL_LOG" || {
    echo "FAIL: ToDesk 卸载失败后没有恢复只读保护" >&2
    exit 1
}

UNINSTALL_MISSING_LOG="$TMP_ROOT/uninstall-missing.log"
MODULE="$MODULE" UNINSTALL_MISSING_LOG="$UNINSTALL_MISSING_LOG" \
    ZHOUKEER_AUTO_CONFIRM=1 bash -c '
    source "$MODULE"
    detect_platform() { IS_STEAMOS=1; }
    todesk_is_installed() { return 0; }
    require_command() { return 0; }
    steamos-readonly() { [ "${1:-}" = status ] && printf "%s\n" enabled; }
    systemctl() { return 1; }
    toolbox_sudo() {
        printf "%s\n" "$*" >> "$UNINSTALL_MISSING_LOG"
        if [ "${1:-}" = systemctl ] && [ "${2:-}" = disable ]; then
            return 1
        fi
        return 0
    }
    uninstall_todesk
'
grep -Fxq 'pacman -Rns --noconfirm todesk-bin' "$UNINSTALL_MISSING_LOG" || {
    echo "FAIL: ToDesk 服务已经不存在时没有继续卸载软件包" >&2
    exit 1
}
grep -Fxq 'steamos-readonly enable' "$UNINSTALL_MISSING_LOG" || {
    echo "FAIL: ToDesk 无服务卸载后没有恢复只读保护" >&2
    exit 1
}

echo "PASS: ToDesk Release镜像、无浏览器回退、DEB转换、服务残留修复和只读恢复测试通过"
