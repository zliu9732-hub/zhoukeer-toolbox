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

cat > "$BIN_DIR/steam" <<'SCRIPT'
#!/bin/sh
printf 'steam %s\n' "$*" >> "${FAKE_STEAM_LOG:?}"
exit 0
SCRIPT

cat > "$BIN_DIR/pgrep" <<'SCRIPT'
#!/bin/sh
[ "${1:-}" = "-x" ] || exit 1
[ -f "${FAKE_STEAM_RUNNING:-/nonexistent}" ] || exit 1
printf '12345\n'
exit 0
SCRIPT
chmod +x "$BIN_DIR"/*

mkdir -p "$TARGET_ROOT/GE-Proton8-1"
printf '%s\n' 'compatibility tool' > "$TARGET_ROOT/GE-Proton8-1/compatibilitytool.vdf"
printf '%s\n' '#!/bin/bash' > "$TARGET_ROOT/GE-Proton8-1/proton"
printf '%s\n' 'manifest' > "$TARGET_ROOT/GE-Proton8-1/toolmanifest.vdf"
mkdir -p "$TARGET_ROOT/GE-Proton10-1" "$TARGET_ROOT/GE-Proton-custom"
printf '%s\n' 'newer version' > "$TARGET_ROOT/GE-Proton10-1/marker.txt"
printf '%s\n' 'custom tool' > "$TARGET_ROOT/GE-Proton-custom/marker.txt"

run_install() {
    HOME="$HOME_DIR" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_CURL_LOG="$CURL_LOG" \
    FAKE_GE_ARCHIVE="$ARCHIVE" \
    FAKE_STEAM_LOG="$TMP_ROOT/steam.log" \
    FAKE_STEAM_RUNNING="${FAKE_STEAM_RUNNING:-$TMP_ROOT/steam-running}" \
    ZHOUKEER_GE_PROTON_URL="https://download.example/GE-Proton9-99.tar.gz" \
    ZHOUKEER_GE_PROTON_VERSION="GE-Proton9-99" \
    ZHOUKEER_GE_PROTON_SHA256="$1" \
    ZHOUKEER_TEST_MODE=1 \
        bash "$MODULE" install
}

printf 'running\n' > "$TMP_ROOT/steam-running"
run_install "$ARCHIVE_SHA" > "$TMP_ROOT/install.output"
test -x "$TARGET_ROOT/GE-Proton9-99/proton" || {
    echo "FAIL: GE-Proton没有安装到Steam compatibilitytools.d目录"
    exit 1
}
grep -Fq '正在重启 Steam' "$TMP_ROOT/install.output"
grep -Fq 'Steam 已重新启动' "$TMP_ROOT/install.output"
grep -Fq 'steam -shutdown' "$TMP_ROOT/steam.log"
if grep -Fq '请完全退出并重新启动Steam' "$TMP_ROOT/install.output"; then
    echo "FAIL: 安装后仍要求用户手动重启 Steam" >&2
    exit 1
fi
grep -Fq 'https://download.example/GE-Proton9-99.tar.gz' "$CURL_LOG"
test -d "$TARGET_ROOT/GE-Proton8-1" || {
    echo "FAIL: 安装最新版本后旧版 GE-Proton 被删除"
    exit 1
}
test -f "$TARGET_ROOT/GE-Proton10-1/marker.txt" || {
    echo "FAIL: 安装旧版本时误删了版本号更高的 GE-Proton"
    exit 1
}
test -f "$TARGET_ROOT/GE-Proton-custom/marker.txt" || {
    echo "FAIL: 安装 GE-Proton 时误删了自定义兼容层"
    exit 1
}
if grep -Fq '已清理' "$TMP_ROOT/install.output"; then
    echo "FAIL: 安装最新版本仍会清理旧版 GE-Proton"
    exit 1
fi

# 修改器常用兼容层：固定四个版本、自有镜像和校验值必须写死在模块中。
grep -Fq 'install-trainer' "$MODULE" || {
    echo "FAIL: ge_proton.sh 缺少 install-trainer 子命令"
    exit 1
}
grep -Fq 'install-trainer-one' "$MODULE" || {
    echo "FAIL: ge_proton.sh 缺少单版本修改器兼容层子命令"
    exit 1
}
grep -Fq 'mktemp -d "${compatibility_dir}/.ge-proton-tmp.XXXXXX"' "$MODULE" || {
    echo "FAIL: GE-Proton 临时目录没有放在兼容层所在磁盘" >&2
    exit 1
}
grep -Fq 'GE_PROTON_TRAINER_ITEMS' "$MODULE" || {
    echo "FAIL: 模块缺少修改器常用兼容层清单"
    exit 1
}
for sha in \
    'ffbd03b40a5c8dafba53e45bd6551c132512ad6fcba9120e25f0d510d0cd0485' \
    'b37160b27ab36e0068f73ab09ac0c936323cf934c6f36edb171cd642bd7ce18a' \
    'bbd3108ba8dcf173dd2a60ef4eb1b8d07e0fb3c9a1061b5b9310c5355c151937' \
    '29a42ff004e9e5c79e22fa9a0595490284167d4a2e7cabbe570b1f9c2f3295c0'; do
    grep -Fq "$sha" "$MODULE" || {
        echo "FAIL: 修改器常用兼容层缺少校验值 $sha"
        exit 1
    }
done
if grep -Fq 'cleanup_older_ge_proton_versions' "$MODULE"; then
    echo "FAIL: 模块仍包含删除旧版 GE-Proton 的逻辑"
    exit 1
fi

printf '%s\n' 'old-install' > "$TARGET_ROOT/GE-Proton9-99/old-version.txt"
curl_calls_before="$(wc -l < "$CURL_LOG" | tr -d '[:space:]')"
steam_calls_before="$(wc -l < "$TMP_ROOT/steam.log" | tr -d '[:space:]')"
second_output="$(run_install "$ARCHIVE_SHA")"
curl_calls_after="$(wc -l < "$CURL_LOG" | tr -d '[:space:]')"
printf '%s\n' "$second_output" | grep -Fq '[已安装]' || {
    echo "FAIL: 同版本 GE-Proton 未报告已安装"
    exit 1
}
test -e "$TARGET_ROOT/GE-Proton9-99/old-version.txt" || {
    echo "FAIL: 已安装 GE-Proton 被重复覆盖"
    exit 1
}
[ "$curl_calls_before" = "$curl_calls_after" ] || {
    echo "FAIL: 已安装 GE-Proton 仍被重复下载"
    exit 1
}
[ "$steam_calls_before" = "$(wc -l < "$TMP_ROOT/steam.log" | tr -d '[:space:]')" ] || {
    echo "FAIL: 已安装 GE-Proton 时仍重启 Steam"
    exit 1
}

printf '%s\n' 'keep-me' > "$TARGET_ROOT/GE-Proton9-99/existing.txt"
rm -f "$TARGET_ROOT/GE-Proton9-99/toolmanifest.vdf"
if run_install '0000000000000000000000000000000000000000000000000000000000000000' \
    > "$TMP_ROOT/bad-sha.output" 2>&1; then
    echo "FAIL: SHA256错误时仍安装成功"
    exit 1
fi
test -f "$TARGET_ROOT/GE-Proton9-99/existing.txt" || {
    echo "FAIL: SHA256错误破坏了已有GE-Proton"
    exit 1
}
grep -Fq '下载失败' "$TMP_ROOT/bad-sha.output"

if find "$TARGET_ROOT" -maxdepth 1 -name '.GE-Proton9-99.*' | grep -q .; then
    echo "FAIL: 安装后遗留暂存或备份目录"
    exit 1
fi

# 修改器常用兼容层全部已安装时，只跳过并提示，不重新下载。
for version in GE-Proton7-55 GE-Proton8-25 GE-Proton9-27 GE-Proton10-29; do
    mkdir -p "$TARGET_ROOT/$version"
    printf '%s\n' 'compatibility tool' > "$TARGET_ROOT/$version/compatibilitytool.vdf"
    printf '%s\n' '#!/bin/bash' > "$TARGET_ROOT/$version/proton"
    printf '%s\n' 'manifest' > "$TARGET_ROOT/$version/toolmanifest.vdf"
    chmod +x "$TARGET_ROOT/$version/proton"
done
: > "$CURL_LOG"
rm -f "$TMP_ROOT/steam-running"
: > "$TMP_ROOT/steam.log"
trainer_output="$(
    HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" \
    FAKE_CURL_LOG="$CURL_LOG" FAKE_GE_ARCHIVE="$ARCHIVE" \
    FAKE_STEAM_LOG="$TMP_ROOT/steam.log" \
    FAKE_STEAM_RUNNING="$TMP_ROOT/steam-running" \
        bash "$MODULE" install-trainer
)"
[ ! -s "$CURL_LOG" ] || {
    echo "FAIL: 修改器常用兼容层已安装时仍触发下载"
    exit 1
}
[ ! -s "$TMP_ROOT/steam.log" ] || {
    echo "FAIL: 修改器常用兼容层已安装时仍重启 Steam"
    exit 1
}
printf '%s\n' "$trainer_output" | grep -Fq '修改器所需常用兼容层安装完成' || {
    echo "FAIL: 修改器常用兼容层缺少完成提示"
    exit 1
}

# 单版本入口只允许四个固定版本，并且只把所选镜像交给既有安全安装函数。
SINGLE_LOG="$TMP_ROOT/single-trainer.log"
(
    source "$MODULE"
    resolve_compatibilitytools_dir() { printf "%s\n" "$TARGET_ROOT"; }
    ge_proton_is_installed() { return 1; }
    install_ge_proton_package() {
        printf "%s|%s|%s|%s|%s|%s\n" \
            "$1" "$2" "$3" "$4" "$GE_PROTON_VERSION" "$GE_PROTON_SHA256" > "$SINGLE_LOG"
    }
    restart_steam_after_ge_proton() { printf "%s\n" restart >> "$SINGLE_LOG"; }
    install_single_trainer_ge_proton 9-27
)
grep -Fq 'ge-proton-trainer-9-27|zhoukeer-toolbox-mirror-6|mirror|' "$SINGLE_LOG" || {
    echo "FAIL: 单独安装 9-27 没有使用对应固定 Gitee 镜像"
    exit 1
}
grep -Fq '|GE-Proton9-27|bbd3108ba8dcf173dd2a60ef4eb1b8d07e0fb3c9a1061b5b9310c5355c151937' "$SINGLE_LOG" || {
    echo "FAIL: 单独安装 9-27 没有使用固定版本和 SHA256"
    exit 1
}
grep -Fxq 'restart' "$SINGLE_LOG" || {
    echo "FAIL: 单版本安装成功后没有重启 Steam"
    exit 1
}
if (
    source "$MODULE"
    resolve_compatibilitytools_dir() { printf "%s\n" "$TARGET_ROOT"; }
    install_single_trainer_ge_proton 11-99
) >/dev/null 2>&1; then
    echo "FAIL: 单版本入口接受了白名单外版本"
    exit 1
fi

# 安装前必须清理 /tmp 与兼容层目录里的旧 GE-Proton 缓存。
TMP_BASE="$TMP_ROOT/tmp-base"
mkdir -p "$TMP_BASE/tmp.ge-old" \
    "$TARGET_ROOT/.GE-Proton9-99.new.123" \
    "$TARGET_ROOT/.GE-Proton9-99.backup.123" \
    "$TARGET_ROOT/.ge-proton-tmp.abc"
: > "$TMP_BASE/tmp.ge-old/ge-proton.tar.gz"
MODULE="$MODULE" TARGET_ROOT="$TARGET_ROOT" \
    ZHOUKEER_GE_PROTON_TMP_BASE="$TMP_BASE" bash -c '
    source "$MODULE"
    cleanup_stale_ge_proton_temp "$TARGET_ROOT"
'
[ ! -e "$TMP_BASE/tmp.ge-old" ] || {
    echo "FAIL: /tmp 里的旧 GE-Proton 缓存没有被清理" >&2
    exit 1
}
[ ! -e "$TARGET_ROOT/.GE-Proton9-99.new.123" ] || {
    echo "FAIL: GE-Proton 新版本暂存目录没有被清理" >&2
    exit 1
}
[ ! -e "$TARGET_ROOT/.GE-Proton9-99.backup.123" ] || {
    echo "FAIL: GE-Proton 备份目录没有被清理" >&2
    exit 1
}
[ ! -e "$TARGET_ROOT/.ge-proton-tmp.abc" ] || {
    echo "FAIL: GE-Proton 临时解压目录没有被清理" >&2
    exit 1
}

echo "PASS: GE-Proton目录解析、校验、原子安装、多版本共存和修改器兼容层测试通过"
