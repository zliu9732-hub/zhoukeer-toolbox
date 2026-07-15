#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/ge_proton.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

HOME_DIR="$TMP_ROOT/home"
BIN_DIR="$TMP_ROOT/bin"
SOURCE_DIR="$TMP_ROOT/source/GE-Proton9-99"
ARCHIVE="$TMP_ROOT/GE-Proton9-99.tar.gz"
TARGET_ROOT="$HOME_DIR/.steam/root/compatibilitytools.d"
CURL_LOG="$TMP_ROOT/curl.log"
mkdir -p "$BIN_DIR" "$SOURCE_DIR" "$HOME_DIR/.steam/root"

printf '%s\n' 'compatibility tool' > "$SOURCE_DIR/compatibilitytool.vdf"
printf '%s\n' '#!/bin/bash' > "$SOURCE_DIR/proton"
printf '%s\n' 'manifest' > "$SOURCE_DIR/toolmanifest.vdf"
chmod +x "$SOURCE_DIR/proton"
tar -czf "$ARCHIVE" -C "$TMP_ROOT/source" GE-Proton9-99
ARCHIVE_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"

cat > "$BIN_DIR/curl" <<'SCRIPT'
#!/bin/bash
output=""
url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
printf '%s\n' "$url" >> "$FAKE_CURL_LOG"
cp "$FAKE_GE_ARCHIVE" "$output"
SCRIPT
chmod +x "$BIN_DIR/curl"

mkdir -p "$TARGET_ROOT/GE-Proton8-1"
printf '%s\n' 'keep older version' > "$TARGET_ROOT/GE-Proton8-1/marker.txt"

run_install() {
    HOME="$HOME_DIR" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_CURL_LOG="$CURL_LOG" \
    FAKE_GE_ARCHIVE="$ARCHIVE" \
    ZHOUKEER_GE_PROTON_URL="https://download.example/GE-Proton9-99.tar.gz" \
    ZHOUKEER_GE_PROTON_VERSION="GE-Proton9-99" \
    ZHOUKEER_GE_PROTON_SHA256="$1" \
        bash "$MODULE" install
}

run_install "$ARCHIVE_SHA" > "$TMP_ROOT/install.output"
test -x "$TARGET_ROOT/GE-Proton9-99/proton" || {
    echo "FAIL: GE-Proton没有安装到Steam compatibilitytools.d目录"
    exit 1
}
grep -Fq '请完全退出并重新启动Steam' "$TMP_ROOT/install.output"
grep -Fxq 'https://download.example/GE-Proton9-99.tar.gz' "$CURL_LOG"
test -f "$TARGET_ROOT/GE-Proton8-1/marker.txt" || {
    echo "FAIL: 安装新版本时删除了其他GE-Proton版本"
    exit 1
}

printf '%s\n' 'old-install' > "$TARGET_ROOT/GE-Proton9-99/old-version.txt"
run_install "$ARCHIVE_SHA" >/dev/null
test ! -e "$TARGET_ROOT/GE-Proton9-99/old-version.txt" || {
    echo "FAIL: 同版本重装混入了旧文件"
    exit 1
}

printf '%s\n' 'keep-me' > "$TARGET_ROOT/GE-Proton9-99/existing.txt"
if run_install '0000000000000000000000000000000000000000000000000000000000000000' \
    > "$TMP_ROOT/bad-sha.output" 2>&1; then
    echo "FAIL: SHA256错误时仍安装成功"
    exit 1
fi
test -f "$TARGET_ROOT/GE-Proton9-99/existing.txt" || {
    echo "FAIL: SHA256错误破坏了已有GE-Proton"
    exit 1
}
grep -Fq 'SHA256校验失败' "$TMP_ROOT/bad-sha.output"

if find "$TARGET_ROOT" -maxdepth 1 -name '.GE-Proton9-99.*' | grep -q .; then
    echo "FAIL: 安装后遗留暂存或备份目录"
    exit 1
fi

echo "PASS: GE-Proton目录解析、校验和原子安装测试通过"
