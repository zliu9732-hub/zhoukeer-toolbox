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

PACKAGE_FILE="$TMP_ROOT/todesk-bin.pkg.tar.zst"
: > "$PACKAGE_FILE"
RETRY_LOG="$TMP_ROOT/retry.log"
MODULE="$MODULE" PACKAGE_FILE="$PACKAGE_FILE" RETRY_LOG="$RETRY_LOG" bash -c '
    source "$MODULE"
    TODESK_RETRIES=3
    TODESK_INSTALL_RETRY_DELAY=0
    toolbox_sudo() {
        count=0
        [ ! -f "$RETRY_LOG" ] || count="$(wc -l < "$RETRY_LOG")"
        printf "%s\n" "$*" >> "$RETRY_LOG"
        [ "$count" -ge 2 ]
    }
    install_verified_todesk_package "$PACKAGE_FILE"
'
[ "$(wc -l < "$RETRY_LOG")" -eq 3 ] || {
    echo "FAIL: ToDesk 临时下载错误没有按有限次数重试" >&2
    exit 1
}

echo "PASS: ToDesk 证书预检、本机缓存恢复和有限重试测试通过"
