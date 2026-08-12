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
MOCK_ATOMUPD_BRANCH=""
MOCK_LEGACY_BRANCH=""
atomupd-manager() {
    [ "${1:-}" = tracked-branch ] && [ -n "$MOCK_ATOMUPD_BRANCH" ] || return 1
    printf '%s\n' "$MOCK_ATOMUPD_BRANCH"
}
steamos-select-branch() {
    [ "${1:-}" = -c ] && [ -n "$MOCK_LEGACY_BRANCH" ] || return 1
    printf '%s\n' "$MOCK_LEGACY_BRANCH"
}

printf '%s\n' \
    'PRETTY_NAME="SteamOS (holo)"' \
    'VERSION_ID="3.6.20"' \
    'VERSION_CODENAME=holo' > "$TMP_ROOT/os-release-stable"
printf '%s\n' \
    'PRETTY_NAME="SteamOS (holo_preview)"' \
    'VERSION_ID="3.6.19"' \
    'VERSION_CODENAME=holo_preview' > "$TMP_ROOT/os-release-preview"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-stable" detect_steamos_channel)"
[ "$detected_channel" = "stable" ] || fail "正式版系统未检测为稳定通道"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-preview" detect_steamos_channel)"
[ "$detected_channel" = "prerelease" ] || fail "预览版系统未检测为测试通道"
MOCK_ATOMUPD_BRANCH="beta"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-stable" detect_steamos_channel)"
[ "$detected_channel" = "prerelease" ] || fail "atomupd beta 分支未检测为测试通道"
MOCK_ATOMUPD_BRANCH="main"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-stable" detect_steamos_channel)"
[ "$detected_channel" = "prerelease" ] || fail "atomupd main 分支未检测为测试通道"
auto_output="$(
    install_plugin_store() { printf 'SELECTED:%s\n' "$1"; }
    install_plugin_store_auto
)"
printf '%s\n' "$auto_output" | grep -Fq 'SELECTED:prerelease' || \
    fail "自动安装未把 atomupd main 分支传给测试版安装流程"
MOCK_ATOMUPD_BRANCH="rel"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-preview" detect_steamos_channel)"
[ "$detected_channel" = "stable" ] || fail "atomupd rel 分支未优先检测为稳定通道"
auto_output="$(
    install_plugin_store() { printf 'SELECTED:%s\n' "$1"; }
    install_plugin_store_auto
)"
printf '%s\n' "$auto_output" | grep -Fq 'SELECTED:stable' || \
    fail "自动安装未把 atomupd rel 分支传给稳定版安装流程"
MOCK_ATOMUPD_BRANCH=""
MOCK_LEGACY_BRANCH="beta"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-stable" detect_steamos_channel)"
[ "$detected_channel" = "prerelease" ] || fail "旧版 beta 分支未检测为测试通道"
MOCK_LEGACY_BRANCH="stable"
detected_channel="$(ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/os-release-preview" detect_steamos_channel)"
[ "$detected_channel" = "stable" ] || fail "旧版 stable 分支未优先检测为稳定通道"
MOCK_LEGACY_BRANCH=""

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
        printf 'sudo %s\n' "$*" >> "$CALLS"
        "$@"
    fi
}

install() {
    printf 'install %s\n' "$*" >> "$CALLS"
    command install "$@"
}

write_mock_decky_component() {
    local name="$1"
    local source_url="$2"
    local output="$3"

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
            if [[ "$source_url" == *prerelease* ]]; then
                sed -i.bak 's/LOG_LEVEL=INFO/LOG_LEVEL=DEBUG/' "$output"
            fi
            ;;
        *) return 1 ;;
    esac
}

GITEE_FAIL=0
printf '#!/bin/sh\nexit 0\n' > "$TMP_ROOT/mock-loader"
MOCK_LOADER_SHA="$(calculate_decky_sha256 "$TMP_ROOT/mock-loader")"
cat > "$TMP_ROOT/mock-release.service" <<'SERVICE'
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
cat > "$TMP_ROOT/mock-prerelease.service" <<'SERVICE'
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
Environment=LOG_LEVEL=DEBUG
[Install]
WantedBy=multi-user.target
SERVICE
MOCK_RELEASE_SERVICE_SHA="$(calculate_decky_sha256 "$TMP_ROOT/mock-release.service")"
MOCK_PRERELEASE_SERVICE_SHA="$(calculate_decky_sha256 "$TMP_ROOT/mock-prerelease.service")"
cat > "$TMP_ROOT/gitee-latest.txt" <<EOF
stable_version=v3.2.6
stable_parts=1
stable_sha256=$MOCK_LOADER_SHA
stable_part_sha256=$MOCK_LOADER_SHA
stable_service_sha256=$MOCK_RELEASE_SERVICE_SHA
prerelease_version=v3.2.8-pre1
prerelease_parts=1
prerelease_sha256=$MOCK_LOADER_SHA
prerelease_part_sha256=$MOCK_LOADER_SHA
prerelease_service_sha256=$MOCK_PRERELEASE_SERVICE_SHA
EOF

download_decky_component_with_fallback() {
    local name="$1"
    local primary_url="$2"
    local official_url="$3"
    local expected_sha256="$4"
    local output="$5"

    printf 'download %s|%s|%s|%s\n' \
        "$name" "$primary_url" "$official_url" "$expected_sha256" >> "$CALLS"
    write_mock_decky_component "$name" "$primary_url" "$output"
}

download_github_file() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"
    local name="$4"

    printf 'github %s|%s|%s\n' \
        "$name" "$url" "$expected_sha256" >> "$CALLS"
    case "$name" in
        'Decky PluginLoader分块'*) echo "正在下载 $name..." ;;
    esac
    case "$url" in
        */decky-installer-cn/latest.txt)
            [ "$GITEE_FAIL" -eq 0 ] || return 1
            cp "$TMP_ROOT/gitee-latest.txt" "$output"
            ;;
        */decky-installer-cn/PluginLoader.part.00|*/decky-installer-cn/PluginLoader-pre.part.00)
            [ "$GITEE_FAIL" -eq 0 ] || return 1
            printf '#!/bin/sh\nexit 0\n' > "$output"
            ;;
        */decky-installer-cn/plugin_loader-release.service)
            [ "$GITEE_FAIL" -eq 0 ] || return 1
            cp "$TMP_ROOT/mock-release.service" "$output"
            ;;
        */decky-installer-cn/plugin_loader-prerelease.service)
            [ "$GITEE_FAIL" -eq 0 ] || return 1
            cp "$TMP_ROOT/mock-prerelease.service" "$output"
            ;;
        *)
            write_mock_decky_component "$name" "$url" "$output"
            ;;
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
if grep -Fq '分块' "$TMP_ROOT/stable.output"; then
    fail "稳定版插件商城仍显示分块下载提示"
fi
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
grep -Fq 'github Decky PluginLoader分块00|https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/PluginLoader.part.00|' \
    "$CALLS" || fail "稳定版未优先使用 Gitee 国内镜像"
grep -Fq 'github Decky systemd服务模板|https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/plugin_loader-release.service|' \
    "$CALLS" || fail "稳定版服务模板未使用 Gitee 镜像"
if grep -Fq "download Decky PluginLoader|$DECKY_LOADER_URL|$DECKY_LOADER_OFFICIAL_URL" "$CALLS"; then
    fail "Gitee 镜像成功时稳定版仍回退到国内/官方线路"
fi
stable_stop_line="$(grep -n 'system stop plugin_loader.service' "$CALLS" | head -n 1 | cut -d: -f1)"
stable_user_stop_line="$(grep -n 'user disable --now plugin_loader.service' "$CALLS" | head -n 1 | cut -d: -f1)"
stable_install_line="$(grep -n '^install -m 0755 .*PluginLoader.new' "$CALLS" | head -n 1 | cut -d: -f1)"
[ -n "$stable_stop_line" ] && [ -n "$stable_user_stop_line" ] && \
    [ -n "$stable_install_line" ] && [ "$stable_stop_line" -lt "$stable_install_line" ] && \
    [ "$stable_user_stop_line" -lt "$stable_install_line" ] || \
    fail "稳定版未在写入新文件前停用系统级和用户级旧服务"

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
: > "$SYSTEM_ACTIVE"
: > "$USER_ACTIVE"
: > "$USER_ENABLED"
install_plugin_store prerelease > "$TMP_ROOT/prerelease.output" || \
    fail "Decky 官方测试版安装失败"
if grep -Fq '分块' "$TMP_ROOT/prerelease.output"; then
    fail "测试版插件商城仍显示分块下载提示"
fi
grep -Fxq 'v3.2.8-pre1' "$SERVICES_DIR/.loader.version" || \
    fail "测试版安装未更新版本标记"
grep -Eq '"branch"[[:space:]]*:[[:space:]]*1' "$SETTINGS_DIR/loader.json" || \
    fail "测试版安装未切换到预发布分支"
grep -Fq 'github Decky PluginLoader分块00|https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/PluginLoader-pre.part.00|' \
    "$CALLS" || fail "测试版未优先使用 Gitee 国内镜像"
grep -Fq 'github Decky systemd服务模板|https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/plugin_loader-prerelease.service|' \
    "$CALLS" || fail "测试版服务模板未使用 Gitee 镜像"
if grep -Fq "$DECKY_PRERELEASE_LOADER_URL" "$CALLS"; then
    fail "Gitee 镜像成功时测试版仍回退到官方 GitHub"
fi
if grep -Fq 'www.mhhf.com' "$CALLS"; then
    fail "测试版安装错误使用了国内源"
fi
prerelease_stop_line="$(grep -n 'system stop plugin_loader.service' "$CALLS" | head -n 1 | cut -d: -f1)"
prerelease_user_stop_line="$(grep -n 'user disable --now plugin_loader.service' "$CALLS" | head -n 1 | cut -d: -f1)"
prerelease_install_line="$(grep -n '^install -m 0755 .*PluginLoader.new' "$CALLS" | head -n 1 | cut -d: -f1)"
[ -n "$prerelease_stop_line" ] && [ -n "$prerelease_user_stop_line" ] && \
    [ -n "$prerelease_install_line" ] && \
    [ "$prerelease_stop_line" -lt "$prerelease_install_line" ] && \
    [ "$prerelease_user_stop_line" -lt "$prerelease_install_line" ] || \
    fail "测试版未在写入新文件前停用系统级和用户级旧服务"
grep -Fq 'LOG_LEVEL=DEBUG' "$UNIT_PATH" || fail "测试版未安装官方预发布服务模板"

# GitHub 与 Gitee 使用独立发布历史；自动镜像必须在 Gitee v2 当前历史上提交，
# 不能再把 GitHub main 直接推到旧仓库，否则会因 non-fast-forward 永久失败。
SYNC_WORKFLOW="$PROJECT_ROOT/.github/workflows/sync-decky-gitee.yml"
grep -Fq 'zhoukeer-toolbox-v2.git' "$SYNC_WORKFLOW" || \
    fail "Decky 自动镜像未指向当前 Gitee v2 仓库"
grep -Fq 'git clone --depth 1 --filter=blob:none --sparse' "$SYNC_WORKFLOW" || \
    fail "Decky 自动镜像未基于 Gitee 当前历史创建普通提交"
grep -Fq 'sparse-checkout set decky-installer-cn' "$SYNC_WORKFLOW" || \
    fail "Decky 自动镜像未限制为 Decky 目录"
if grep -Fq 'zhoukeer-toolbox.git"' "$SYNC_WORKFLOW" || \
   grep -Fq 'git push gitee main' "$SYNC_WORKFLOW"; then
    fail "Decky 自动镜像仍直接推送旧 Gitee 仓库或分叉历史"
fi

# Gitee 镜像不可用时，必须回退到原有国内/官方线路。
: > "$CALLS"
GITEE_FAIL=1
install_plugin_store stable >/dev/null || \
    fail "Gitee 镜像失败后稳定版未回退既有线路"
grep -Fq "download Decky PluginLoader|$DECKY_LOADER_URL|$DECKY_LOADER_OFFICIAL_URL" \
    "$CALLS" || fail "Gitee 镜像失败后稳定版未使用国内到官方的回退顺序"
: > "$CALLS"
install_plugin_store prerelease >/dev/null || \
    fail "Gitee 镜像失败后测试版未回退官方 Release"
grep -Fq "github Decky PluginLoader|$DECKY_PRERELEASE_LOADER_URL|$DECKY_PRERELEASE_LOADER_SHA256" \
    "$CALLS" || fail "Gitee 镜像失败后测试版未使用统一 GitHub Release 下载流程"
GITEE_FAIL=0

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
[ ! -e "$SERVICES_DIR/.systemd" ] || fail "卸载后仍残留 .systemd 目录"
[ ! -e "$SERVICES_DIR" ] || fail "卸载后仍残留 services 目录"
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
