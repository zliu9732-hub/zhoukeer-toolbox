#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

HOME_DIR="$TMP_ROOT/home"
HOMEBREW_DIR="$HOME_DIR/homebrew"
SERVICES_DIR="$HOMEBREW_DIR/services"
PLUGIN_DIR="$HOMEBREW_DIR/plugins"
SETTINGS_DIR="$HOMEBREW_DIR/settings"
UNIT_PATH="$TMP_ROOT/system/plugin_loader.service"
USER_UNIT_PATH="$HOME_DIR/.config/systemd/user/plugin_loader.service"
CALLS="$TMP_ROOT/calls"
SYSTEM_ACTIVE="$TMP_ROOT/system-active"
SYSTEM_ENABLED="$TMP_ROOT/system-enabled"
USER_ACTIVE="$TMP_ROOT/user-active"
USER_ENABLED="$TMP_ROOT/user-enabled"
SYSTEM_RESTART_FAIL="$TMP_ROOT/system-restart-fail"

mkdir -p "$SERVICES_DIR" "$PLUGIN_DIR/KeepMe" "$SETTINGS_DIR" \
    "$(dirname "$UNIT_PATH")" "$(dirname "$USER_UNIT_PATH")"
printf 'plugin-data\n' > "$PLUGIN_DIR/KeepMe/data"

HOME="$HOME_DIR"
ZHOUKEER_DECKY_HOMEBREW_DIR="$HOMEBREW_DIR"
ZHOUKEER_DECKY_UNIT_PATH="$UNIT_PATH"
ZHOUKEER_TEST_MODE=1
ZHOUKEER_AUTO_CONFIRM=1
export HOME ZHOUKEER_DECKY_HOMEBREW_DIR ZHOUKEER_DECKY_UNIT_PATH
export ZHOUKEER_TEST_MODE ZHOUKEER_AUTO_CONFIRM

# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/plugin_store.sh"

detect_platform() { IS_STEAMOS=1; }
id() {
    case "${1:-}" in
        -u) printf '1000\n' ;;
        -g) printf '1000\n' ;;
        *) command id "$@" ;;
    esac
}
require_command() { return 0; }

mock_systemctl() {
    local scope="$1"
    shift
    local active_file enabled_file

    if [ "$scope" = user ]; then
        active_file="$USER_ACTIVE"
        enabled_file="$USER_ENABLED"
    else
        active_file="$SYSTEM_ACTIVE"
        enabled_file="$SYSTEM_ENABLED"
    fi
    printf '%s %s\n' "$scope" "$*" >> "$CALLS"
    case "${1:-}" in
        is-active) [ -f "$active_file" ] ;;
        is-enabled) [ -f "$enabled_file" ] ;;
        stop) rm -f -- "$active_file" ;;
        start|restart)
            if [ "$scope" = system ] && [ "${1:-}" = restart ] && \
               [ -f "$SYSTEM_RESTART_FAIL" ]; then
                return 1
            fi
            : > "$active_file"
            ;;
        enable) : > "$enabled_file" ;;
        disable)
            rm -f -- "$enabled_file"
            [ "${2:-}" != "--now" ] || rm -f -- "$active_file"
            ;;
        daemon-reload) return 0 ;;
        *) return 0 ;;
    esac
}

systemctl() {
    [ "${1:-}" = "--user" ] || return 1
    shift
    mock_systemctl user "$@"
}

toolbox_sudo() {
    if [ "${1:-}" = systemctl ]; then
        shift
        mock_systemctl system "$@"
    else
        "$@"
    fi
}

download_decky_component_with_fallback() {
    local name="$1"
    local primary_url="$2"
    local official_url="$3"
    local expected_sha256="$4"
    local output="$5"

    printf 'download %s|%s|%s|%s\n' \
        "$name" "$primary_url" "$official_url" "$expected_sha256" >> "$CALLS"
    case "$name" in
        'Decky PluginLoader') printf '#!/bin/sh\nexit 0\n' > "$output" ;;
        'Decky systemd服务模板')
            cat > "$output" <<'SERVICE'
[Unit]
Description=SteamDeck Plugin Loader
After=network.target
[Service]
Type=simple
User=root
Restart=always
ExecStart=${HOMEBREW_FOLDER}/services/PluginLoader
WorkingDirectory=${HOMEBREW_FOLDER}/services
Environment=UNPRIVILEGED_PATH=${HOMEBREW_FOLDER}
Environment=PRIVILEGED_PATH=${HOMEBREW_FOLDER}
Environment=LOG_LEVEL=INFO
[Install]
WantedBy=multi-user.target
SERVICE
            if [[ "$primary_url" == *prerelease* ]]; then
                sed -i.bak 's/LOG_LEVEL=INFO/LOG_LEVEL=DEBUG/' "$output"
            fi
            ;;
        *) return 1 ;;
    esac
}

prepare_old_testing_install() {
    printf '#!/bin/sh\nexit 0\n' > "$SERVICES_DIR/PluginLoader"
    chmod +x "$SERVICES_DIR/PluginLoader"
    printf 'PR-123\n' > "$SERVICES_DIR/.loader.version"
    printf '{"branch": 2, "keep": "yes"}\n' > "$SETTINGS_DIR/loader.json"
    printf '[Service]\n' > "$UNIT_PATH"
    printf '[Service]\n' > "$USER_UNIT_PATH"
    : > "$SYSTEM_ACTIVE"
    : > "$SYSTEM_ENABLED"
    : > "$USER_ACTIVE"
    : > "$USER_ENABLED"
}

prepare_old_testing_install
install_plugin_store stable > "$TMP_ROOT/stable.output" || \
    fail "旧测试版无法切换到稳定版"
grep -Fxq 'v3.2.6' "$SERVICES_DIR/.loader.version" || \
    fail "稳定版安装未更新版本标记"
grep -Eq '"branch"[[:space:]]*:[[:space:]]*0' "$SETTINGS_DIR/loader.json" || \
    fail "稳定版安装未切换到稳定分支"
grep -Fq '"keep": "yes"' "$SETTINGS_DIR/loader.json" || \
    fail "稳定版切换覆盖了其他 Decky 设置"
[ ! -e "$USER_UNIT_PATH" ] || fail "稳定版安装未清理旧用户服务文件"
[ -f "$PLUGIN_DIR/KeepMe/data" ] || fail "稳定版安装删除了现有插件"
grep -Fq 'user disable --now plugin_loader.service' "$CALLS" || \
    fail "稳定版安装未停用旧测试版用户服务"
grep -Fq "download Decky PluginLoader|$DECKY_LOADER_URL|$DECKY_LOADER_OFFICIAL_URL" \
    "$CALLS" || fail "稳定版未使用国内到官方的回退顺序"

# 新服务启动失败时，必须恢复稳定版文件、通道和旧用户服务状态。
: > "$SYSTEM_RESTART_FAIL"
printf '[Service]\n' > "$USER_UNIT_PATH"
: > "$USER_ACTIVE"
: > "$USER_ENABLED"
if install_plugin_store prerelease > "$TMP_ROOT/rollback.output" 2>&1; then
    fail "测试版启动失败时仍报告安装成功"
fi
grep -Fxq 'v3.2.6' "$SERVICES_DIR/.loader.version" || \
    fail "测试版启动失败后未恢复稳定版版本标记"
grep -Eq '"branch"[[:space:]]*:[[:space:]]*0' "$SETTINGS_DIR/loader.json" || \
    fail "测试版启动失败后未恢复稳定分支"
[ -f "$USER_ACTIVE" ] && [ -f "$USER_ENABLED" ] || \
    fail "测试版启动失败后未恢复旧用户服务状态"
rm -f -- "$SYSTEM_RESTART_FAIL"

: > "$CALLS"
printf '[Service]\n' > "$USER_UNIT_PATH"
install_plugin_store prerelease > "$TMP_ROOT/prerelease.output" || \
    fail "Decky 官方测试版安装失败"
grep -Fxq 'v3.2.8-pre1' "$SERVICES_DIR/.loader.version" || \
    fail "测试版安装未更新版本标记"
grep -Eq '"branch"[[:space:]]*:[[:space:]]*1' "$SETTINGS_DIR/loader.json" || \
    fail "测试版安装未切换到预发布分支"
grep -Fq "download Decky PluginLoader|$DECKY_PRERELEASE_LOADER_URL|$DECKY_PRERELEASE_LOADER_URL" \
    "$CALLS" || fail "测试版未只使用 Decky 官方 Release"
if grep -Fq 'www.mhhf.com' "$CALLS"; then
    fail "测试版安装错误使用了国内源"
fi
grep -Fq 'LOG_LEVEL=DEBUG' "$UNIT_PATH" || fail "测试版未安装官方预发布服务模板"

mkdir -p "$SERVICES_DIR/.systemd"
for service_file in plugin_loader.service plugin_loader-release.service \
    plugin_loader-prerelease.service; do
    printf '[Service]\n' > "$SERVICES_DIR/.systemd/$service_file"
done
printf '[Service]\n' > "$USER_UNIT_PATH"
: > "$SYSTEM_ACTIVE"
: > "$SYSTEM_ENABLED"
: > "$USER_ACTIVE"
: > "$USER_ENABLED"
uninstall_plugin_store > "$TMP_ROOT/uninstall.output" || \
    fail "稳定版与测试版统一卸载失败"
for removed in \
    "$SERVICES_DIR/PluginLoader" \
    "$SERVICES_DIR/.loader.version" \
    "$UNIT_PATH" \
    "$USER_UNIT_PATH" \
    "$SERVICES_DIR/.systemd/plugin_loader.service" \
    "$SERVICES_DIR/.systemd/plugin_loader-release.service" \
    "$SERVICES_DIR/.systemd/plugin_loader-prerelease.service"; do
    [ ! -e "$removed" ] || fail "卸载后仍残留：$removed"
done
[ -f "$PLUGIN_DIR/KeepMe/data" ] || fail "卸载 Decky Loader 删除了插件"
[ -f "$SETTINGS_DIR/loader.json" ] || fail "卸载 Decky Loader 删除了设置"

UNIFIDECK_SOURCE="$TMP_ROOT/unifideck-source"
UNIFIDECK_ARCHIVE="$TMP_ROOT/unifideck.zip"
UNIFIDECK_PLUGIN_ROOT="$TMP_ROOT/unifideck-plugins"
mkdir -p "$UNIFIDECK_SOURCE/Unifideck/dist" "$UNIFIDECK_PLUGIN_ROOT"
printf '{"name":"Unifideck"}\n' > "$UNIFIDECK_SOURCE/Unifideck/plugin.json"
printf 'bundle\n' > "$UNIFIDECK_SOURCE/Unifideck/dist/index.js"
(cd "$UNIFIDECK_SOURCE" && zip -qr "$UNIFIDECK_ARCHIVE" Unifideck)
download_verified_package() { cp -- "$UNIFIDECK_ARCHIVE" "$4"; }
DECKY_PLUGIN_DIR="$UNIFIDECK_PLUGIN_ROOT"
export DECKY_PLUGIN_DIR
(install_decky_zip "Unifideck" "https://example.invalid/unifideck.zip" \
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
    "Unifideck" 0) || fail "Unifideck 官方大写目录结构仍无法安装"
[ -s "$UNIFIDECK_PLUGIN_ROOT/Unifideck/dist/index.js" ] || \
    fail "Unifideck 未写入正确的大写目录"

echo "PASS: Decky 稳定/测试版切换、旧用户服务清理、统一卸载和 Unifideck 目录模拟通过"
