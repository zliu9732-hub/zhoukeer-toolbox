#!/bin/sh

set -u

# Decky Loader Gitee 镜像最新版安装器。
# 用法: install_latest.sh release|prerelease

if [ "${DECKY_INSTALLER_TEST_MODE:-0}" != "1" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
    fi
fi

CHANNEL="${1:-release}"
MIRROR_BASE="https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn"
META_URL="${MIRROR_BASE}/latest.txt"

case "$CHANNEL" in
    release|stable) CHANNEL=release ;;
    prerelease|test|testing) CHANNEL=prerelease ;;
    *)
        echo "用法: install_latest.sh release|prerelease"
        exit 1
        ;;
esac

require_command() {
    command -v "$1" >/dev/null 2>&1 || { echo "缺少命令: $1"; exit 1; }
}
require_command curl
require_command getent
require_command mktemp
require_command install
require_command systemctl
if command -v sha256sum >/dev/null 2>&1; then
    sha256_of() { sha256sum -- "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    sha256_of() { shasum -a 256 -- "$1" | awk '{print $1}'; }
else
    echo "缺少 SHA256 校验命令"
    exit 1
fi

if [ -n "${SUDO_USER:-}" ]; then
    RUN_USER="$SUDO_USER"
else
    RUN_USER="${USER:-$(id -un)}"
fi
USER_DIR="$(getent passwd "$RUN_USER" | cut -d: -f6)"
[ -n "$USER_DIR" ] || { echo "无法获取用户目录"; exit 1; }
HOMEBREW_FOLDER="${USER_DIR}/homebrew"

TMP_DIR="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$TMP_DIR"' EXIT INT TERM
META_FILE="$TMP_DIR/latest.txt"
PLUGIN_LOADER="$TMP_DIR/PluginLoader"
SERVICE_TEMPLATE="$TMP_DIR/plugin_loader.service"

echo "正在从 Gitee 获取 Decky 最新版本清单..."
curl -fSL --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 60 \
    --retry 3 --retry-delay 2 "$META_URL" --output "$META_FILE" || {
    echo "获取版本清单失败，请稍后重试。"
    exit 1
}
[ -s "$META_FILE" ] || { echo "版本清单为空。"; exit 1; }

STABLE_VERSION=""
STABLE_PARTS=""
STABLE_SHA256=""
STABLE_PART_SHA256=""
STABLE_SERVICE_SHA256=""
PRERELEASE_VERSION=""
PRERELEASE_PARTS=""
PRERELEASE_SHA256=""
PRERELEASE_PART_SHA256=""
PRERELEASE_SERVICE_SHA256=""
while IFS='=' read -r key value; do
    case "$key" in
        stable_version) STABLE_VERSION="$value" ;;
        stable_parts) STABLE_PARTS="$value" ;;
        stable_sha256) STABLE_SHA256="$value" ;;
        stable_part_sha256) STABLE_PART_SHA256="$value" ;;
        stable_service_sha256) STABLE_SERVICE_SHA256="$value" ;;
        prerelease_version) PRERELEASE_VERSION="$value" ;;
        prerelease_parts) PRERELEASE_PARTS="$value" ;;
        prerelease_sha256) PRERELEASE_SHA256="$value" ;;
        prerelease_part_sha256) PRERELEASE_PART_SHA256="$value" ;;
        prerelease_service_sha256) PRERELEASE_SERVICE_SHA256="$value" ;;
    esac
done < "$META_FILE"

if [ "$CHANNEL" = "release" ]; then
    VERSION="$STABLE_VERSION"
    PARTS="$STABLE_PARTS"
    LOADER_SHA256="$STABLE_SHA256"
    PART_SHA256="$STABLE_PART_SHA256"
    SERVICE_SHA256="$STABLE_SERVICE_SHA256"
    SERVICE_FILE="plugin_loader-release.service"
    LOADER_PREFIX="PluginLoader"
else
    VERSION="$PRERELEASE_VERSION"
    PARTS="$PRERELEASE_PARTS"
    LOADER_SHA256="$PRERELEASE_SHA256"
    PART_SHA256="$PRERELEASE_PART_SHA256"
    SERVICE_SHA256="$PRERELEASE_SERVICE_SHA256"
    SERVICE_FILE="plugin_loader-prerelease.service"
    LOADER_PREFIX="PluginLoader-pre"
fi

case "$VERSION" in
    ''|*[!-0-9A-Za-z._]*) echo "版本号格式异常。"; exit 1 ;;
esac
case "$PARTS" in
    ''|*[!0-9]*) echo "分块数量异常。"; exit 1 ;;
esac
[ "$PARTS" -ge 1 ] 2>/dev/null || { echo "分块数量异常。"; exit 1; }
for value in "$LOADER_SHA256" "$SERVICE_SHA256"; do
    case "$value" in
        [0-9a-fA-F]*) ;;
        *) echo "SHA256 格式异常。"; exit 1 ;;
    esac
    [ "${#value}" -eq 64 ] || { echo "SHA256 格式异常。"; exit 1; }
done

old_ifs="$IFS"
IFS=','
set -- $PART_SHA256
IFS="$old_ifs"
[ "$#" -eq "$PARTS" ] || { echo "分块校验值数量异常。"; exit 1; }
for entry in "$@"; do
    case "$entry" in
        [0-9a-fA-F]*) ;;
        *) echo "分块 SHA256 格式异常。"; exit 1 ;;
    esac
    [ "${#entry}" -eq 64 ] || { echo "分块 SHA256 格式异常。"; exit 1; }
done

echo "正在从 Gitee 下载 Decky Loader ${VERSION}..."
: > "$PLUGIN_LOADER"
i=0
for part_sha in "$@"; do
    part_name="$(printf '%02d' "$i")"
    part_file="$TMP_DIR/part.$part_name"
    curl -fSL --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 1200 \
        --retry 5 --retry-delay 2 --speed-limit 65536 --speed-time 60 \
        "${MIRROR_BASE}/${LOADER_PREFIX}.part.${part_name}" --output "$part_file" || {
        echo "分块 ${part_name} 下载失败。"
        exit 1
    }
    [ "$(sha256_of "$part_file")" = "$part_sha" ] || {
        echo "分块 ${part_name} SHA256 校验失败。"
        exit 1
    }
    cat "$part_file" >> "$PLUGIN_LOADER" || exit 1
    i=$((i + 1))
done
[ "$(sha256_of "$PLUGIN_LOADER")" = "$LOADER_SHA256" ] || {
    echo "PluginLoader SHA256 校验失败。"
    exit 1
}

echo "正在从 Gitee 下载 systemd 服务模板..."
curl -fSL --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 120 \
    --retry 5 --retry-delay 2 \
    "${MIRROR_BASE}/${SERVICE_FILE}" --output "$SERVICE_TEMPLATE" || {
    echo "服务模板下载失败。"
    exit 1
}
[ "$(sha256_of "$SERVICE_TEMPLATE")" = "$SERVICE_SHA256" ] || {
    echo "服务模板 SHA256 校验失败。"
    exit 1
}

if [ "${DECKY_INSTALLER_TEST_MODE:-0}" = "1" ]; then
    echo "测试模式：下载与校验完成，跳过系统安装。"
    echo "Decky Loader ${VERSION}"
    exit 0
fi

mkdir -p "$HOMEBREW_FOLDER/services" "$HOMEBREW_FOLDER/plugins"
touch "$USER_DIR/.steam/steam/.cef-enable-remote-debugging"
if [ -d "$USER_DIR/.var/app/com.valvesoftware.Steam/data/Steam/" ]; then
    touch "$USER_DIR/.var/app/com.valvesoftware.Steam/data/Steam/.cef-enable-remote-debugging"
fi
install -m 0755 "$PLUGIN_LOADER" "$HOMEBREW_FOLDER/services/PluginLoader"
printf '%s\n' "$VERSION" > "$HOMEBREW_FOLDER/services/.loader.version"
sed -e "s|\${HOMEBREW_FOLDER}|${HOMEBREW_FOLDER}|g" "$SERVICE_TEMPLATE" \
    > /etc/systemd/system/plugin_loader.service
systemctl stop plugin_loader.service 2>/dev/null || true
systemctl daemon-reload
systemctl start plugin_loader.service
systemctl enable plugin_loader.service
echo "Decky Loader ${VERSION} 安装完成。"
echo "回到游戏模式后按 ... 键打开插件商城。"
