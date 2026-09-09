#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
PLUGIN_ROOT="$TMP_ROOT/plugins"
FIXTURE_ROOT="$TMP_ROOT/fixture"
FIXTURE="$TMP_ROOT/PowerControl.zip"
CALLS="$TMP_ROOT/calls"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$PLUGIN_ROOT" "$FIXTURE_ROOT/PowerControl/dist"
cat > "$FIXTURE_ROOT/PowerControl/plugin.json" <<'EOF'
{"name":"PowerControl","author":"yxx, honjow","flags":["root"]}
EOF
cat > "$FIXTURE_ROOT/PowerControl/package.json" <<'EOF'
{"name":"power_control","version":"3.15.1","license":"BSD-3-Clause"}
EOF
printf '%s\n' 'frontend' > "$FIXTURE_ROOT/PowerControl/dist/index.js"
printf '%s\n' 'backend' > "$FIXTURE_ROOT/PowerControl/main.py"
(
    cd "$FIXTURE_ROOT"
    zip -qr "$FIXTURE" PowerControl
)

# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/plugin_store.sh"

detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
require_existing_chimera_plugin_environment() { return 0; }
download_verified_package() {
    [ "${GITEE_MIRROR_REPO:-}" = "zhoukeer-toolbox-mirror-3" ] || \
        fail "PowerControl 未使用原有掌机插件国内下载仓库"
    [ "$1" = "PowerControl v3.15.1" ] || fail "PowerControl 下载名称错误：$1"
    [ "$2" = "https://github.com/mengmeet/PowerControl/releases/download/v3.15.1/PowerControl.zip" ] || \
        fail "PowerControl 下载地址错误：$2"
    [ "$3" = "9c14eddbec7657a23e73eaf811bd8344198159d48303481cf70ebb7c1c1ebd7c" ] || \
        fail "PowerControl SHA256 错误：$3"
    cp -- "$FIXTURE" "$4"
}
reload_decky_plugins() {
    printf '%s\n' reload >> "$CALLS"
}
log() { :; }

DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
ZHOUKEER_TEST_MODE=1
install_configured_plugin powercontrol >/dev/null || fail "PowerControl 模拟安装失败"
[ -f "$PLUGIN_ROOT/PowerControl/plugin.json" ] || fail "PowerControl 插件清单未安装"
[ -s "$PLUGIN_ROOT/PowerControl/dist/index.js" ] || fail "PowerControl 前端未安装"
[ "$(decky_plugin_version "$PLUGIN_ROOT/PowerControl")" = "3.15.1" ] || \
    fail "PowerControl 安装版本不正确"
grep -Fxq reload "$CALLS" || fail "PowerControl 安装后未请求 Decky 重载"

download_verified_package() {
    fail "PowerControl 同版重复执行仍触发下载"
}
repeat_output="$(install_configured_plugin powercontrol)" || fail "PowerControl 重复执行失败"
printf '%s\n' "$repeat_output" | grep -Fq '[已安装] PowerControl v3.15.1 官方原包已存在' || \
    fail "PowerControl 重复执行未进入幂等路径"
[ "$(grep -Fxc reload "$CALLS")" = "1" ] || fail "PowerControl 同版重复执行仍重载 Decky"

download_policy_url_allowed \
    'https://github.com/mengmeet/PowerControl/releases/download/v3.15.1/PowerControl.zip' || \
    fail "PowerControl 作者 Release 未进入下载白名单"
[ "$(gitee_mirror_id_for_url \
    'https://github.com/mengmeet/PowerControl/releases/download/v3.15.1/PowerControl.zip')" = \
    "powercontrol" ] || fail "PowerControl 未路由到国内分块镜像"

for menu_file in "$PROJECT_ROOT/main.sh" "$PROJECT_ROOT/core/gui.sh" "$PROJECT_ROOT/main-bazzite.sh"; do
    powercontrol_lines="$(grep -i 'powercontrol' "$menu_file" || true)"
    grep -Fq 'Gitee' <<< "$powercontrol_lines" && \
        fail "PowerControl 菜单描述不应显示 Gitee：$menu_file"
    grep -Fq '分块' <<< "$powercontrol_lines" && \
        fail "PowerControl 菜单描述不应显示分块下载：$menu_file"
done

echo "PASS: PowerControl 固定版本、SHA256、原子安装、幂等和镜像回退模拟测试通过"
