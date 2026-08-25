#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/proton_cachyos.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

VERSION="proton-cachyos-11.0-20260703-slr-x86_64"
SOURCE_DIR="$TMP_ROOT/source/$VERSION"
ARCHIVE="$TMP_ROOT/$VERSION.tar.xz"
TARGET_ROOT="$TMP_ROOT/home/.steam/root/compatibilitytools.d"
BIN_DIR="$TMP_ROOT/bin"
OS_RELEASE="$TMP_ROOT/os-release"
CURL_LOG="$TMP_ROOT/curl.log"
STEAM_LOG="$TMP_ROOT/steam.log"

mkdir -p "$SOURCE_DIR" "$BIN_DIR" "$TMP_ROOT/home/.steam/root" "$TARGET_ROOT/GE-Proton11-5"
printf '%s\n' 'ID=steamos' 'PRETTY_NAME="SteamOS test"' > "$OS_RELEASE"
printf '%s\n' 'compatibility tool' > "$SOURCE_DIR/compatibilitytool.vdf"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$SOURCE_DIR/proton"
printf '%s\n' 'manifest' > "$SOURCE_DIR/toolmanifest.vdf"
chmod +x "$SOURCE_DIR/proton"
tar -cJf "$ARCHIVE" -C "$TMP_ROOT/source" "$VERSION"
ARCHIVE_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
printf '%s\n' 'keep existing GE' > "$TARGET_ROOT/GE-Proton11-5/marker.txt"
: > "$STEAM_LOG"

cat > "$BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output|-o) output="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
printf '%s\n' "$url" >> "${FAKE_CURL_LOG:?}"
cp "${FAKE_CACHYOS_ARCHIVE:?}" "$output"
SCRIPT
cat > "$BIN_DIR/steam" <<'SCRIPT'
#!/bin/bash
printf 'steam %s\n' "$*" >> "${FAKE_STEAM_LOG:?}"
SCRIPT
cat > "$BIN_DIR/pgrep" <<'SCRIPT'
#!/bin/bash
exit 1
SCRIPT
chmod +x "$BIN_DIR"/*

run_install() {
    HOME="$TMP_ROOT/home" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_CURL_LOG="$CURL_LOG" \
    FAKE_CACHYOS_ARCHIVE="$ARCHIVE" \
    FAKE_STEAM_LOG="$STEAM_LOG" \
    ZHOUKEER_OS_RELEASE_FILE="$OS_RELEASE" \
    ZHOUKEER_PROTON_CACHYOS_FILE="$VERSION.tar.xz" \
    ZHOUKEER_PROTON_CACHYOS_URL="https://github.com/CachyOS/proton-cachyos/releases/download/test/$VERSION.tar.xz" \
    ZHOUKEER_PROTON_CACHYOS_SHA256="$ARCHIVE_SHA" \
    ZHOUKEER_TEST_MODE=1 \
        bash "$MODULE" install
}

run_install > "$TMP_ROOT/install.output"
test -x "$TARGET_ROOT/$VERSION/proton" || {
    echo "FAIL: Proton-CachyOS 未安装到 compatibilitytools.d" >&2
    exit 1
}
test -f "$TARGET_ROOT/GE-Proton11-5/marker.txt" || {
    echo "FAIL: Proton-CachyOS 安装误删了现有 GE-Proton" >&2
    exit 1
}
grep -Fq "$VERSION 安装完成" "$TMP_ROOT/install.output"
grep -Fq 'Steam 已重新启动' "$TMP_ROOT/install.output"
grep -Fq '/CachyOS/proton-cachyos/releases/download/' "$CURL_LOG"

curl_count="$(wc -l < "$CURL_LOG" | tr -d ' ')"
steam_count="$(wc -l < "$STEAM_LOG" | tr -d ' ')"
run_install > "$TMP_ROOT/reinstall.output"
grep -Fq '[已安装]' "$TMP_ROOT/reinstall.output"
[ "$(wc -l < "$CURL_LOG" | tr -d ' ')" = "$curl_count" ] || {
    echo "FAIL: 已安装 Proton-CachyOS 时仍重复下载" >&2
    exit 1
}
[ "$(wc -l < "$STEAM_LOG" | tr -d ' ')" = "$steam_count" ] || {
    echo "FAIL: 已安装 Proton-CachyOS 时仍重启 Steam" >&2
    exit 1
}

mkdir -p "$TMP_ROOT/bad/proton-cachyos-11.0-test-slr-x86_64_v3"
printf '%s\n' bad > "$TMP_ROOT/bad/proton-cachyos-11.0-test-slr-x86_64_v3/proton"
tar -cJf "$TMP_ROOT/bad.tar.xz" -C "$TMP_ROOT/bad" .
if (source "$MODULE"; validate_proton_cachyos_archive "$TMP_ROOT/bad.tar.xz") \
    > "$TMP_ROOT/bad.output" 2>&1; then
    echo "FAIL: Proton-CachyOS 接受了 x86_64_v3 包" >&2
    exit 1
fi
grep -Fq '意外顶层目录' "$TMP_ROOT/bad.output"

grep -Fq 'zhoukeer-toolbox-mirror-9' "$MODULE" || {
    echo "FAIL: Proton-CachyOS 未使用独立 mirror-9" >&2
    exit 1
}
grep -Fq 'require_supported_gaming_os' "$MODULE" || {
    echo "FAIL: Proton-CachyOS 缺少 SteamOS/Bazzite 平台隔离" >&2
    exit 1
}

echo "PASS: Proton-CachyOS 平台隔离、校验、原子安装与幂等测试通过"
