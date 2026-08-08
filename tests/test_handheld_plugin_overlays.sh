#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/plugin_store.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

check_overlay() {
    local relative_dir="$1"
    local expected_name="$2"
    local expected_sha256="$3"
    local attribution="$4"
    local root="$PROJECT_ROOT/$relative_dir"
    local actual_name actual_sha256

    for file in plugin.json package.json LICENSE dist/index.js; do
        [ -s "$root/$file" ] || fail "$relative_dir 缺少 $file"
    done
    actual_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$root/plugin.json" | head -n 1)"
    [ "$actual_name" = "$expected_name" ] || fail "$relative_dir 中文名称不一致"
    actual_sha256="$(shasum -a 256 "$root/dist/index.js" | awk '{print $1}')"
    [ "$actual_sha256" = "$expected_sha256" ] || fail "$relative_dir 前端 SHA256 不一致"
    grep -Fq "$expected_name" "$root/dist/index.js" || fail "$relative_dir 前端缺少中文插件名"
    if [ "$attribution" = "1" ]; then
        grep -Fq 'Ren-Amamiya-pixie' "$root/dist/index.js" || fail "$relative_dir 前端缺少汉化署名"
    fi
}

check_overlay third_party/huesync-cn-v3.9.0 "通用掌机 RGB" \
    8af434b51c39f054b94ff71a39798569dc58b0fff36c74a5282edcb89e7bd0c5 0
check_overlay third_party/legion-go-remapper-zh-v0.3.0 "Legion Go 控制中心" \
    a0c7beebc4d3628b965a71b25471d6ec559ffc9bbcf5834ab591ccc72bb53e8d 1
check_overlay third_party/gpd-control-zh-v0.0.2 "GPD 控制中心" \
    ec4dd1253bae3b4c7c0f9f1beca2593322e1ee5db3de6ffe8240d3ea1b46f3ef 1
check_overlay third_party/lego-vibe-control-zh-v1.5.0 "Legion Go 震动控制" \
    8e4ccca1f97d55269c4833dcdccb061560db2e390e52ca6e584bb3ff16c56e63 1
check_overlay third_party/lego2-fan-control-zh-v0.260430 "Legion Go 2 风扇控制" \
    497cc90b588627634b699dda70e6aab06239acbe07cb2f9bf4f9478e88b66c22 1

# 用假的官方后端验证覆盖过程只替换前端和清单，后端字节保持不变且重复执行幂等。
PLUGIN_ROOT="$TMP_ROOT/plugins"
mkdir -p "$PLUGIN_ROOT/HueSync/dist"
printf '%s\n' '# official backend fixture' > "$PLUGIN_ROOT/HueSync/main.py"
printf '%s\n' '{"name":"HueSync"}' > "$PLUGIN_ROOT/HueSync/plugin.json"
printf '%s\n' '{"version":"3.9.0"}' > "$PLUGIN_ROOT/HueSync/package.json"
printf '%s\n' 'official frontend fixture' > "$PLUGIN_ROOT/HueSync/dist/index.js"
backend_before="$(shasum -a 256 "$PLUGIN_ROOT/HueSync/main.py" | awk '{print $1}')"

overlay_output="$({
    DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
    ZHOUKEER_TEST_MODE=1
    source "$MODULE"
    reload_decky_plugins() { echo 'TEST_RELOAD'; }
    install_handheld_frontend_overlay "HueSync" "3.9.0" "通用掌机 RGB" \
        "$PROJECT_ROOT/third_party/huesync-cn-v3.9.0" \
        "8af434b51c39f054b94ff71a39798569dc58b0fff36c74a5282edcb89e7bd0c5" \
        "原作者：honjow；许可证：BSD 3-Clause。" 0
})"
printf '%s\n' "$overlay_output" | grep -Fq 'TEST_RELOAD' || fail "覆盖完成后未刷新 Decky"
[ "$(shasum -a 256 "$PLUGIN_ROOT/HueSync/main.py" | awk '{print $1}')" = "$backend_before" ] || \
    fail "覆盖过程改动了官方后端"
grep -Fq '"name": "通用掌机 RGB"' "$PLUGIN_ROOT/HueSync/plugin.json" || \
    fail "覆盖后插件清单不是中文名称"

repeat_output="$({
    DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
    ZHOUKEER_TEST_MODE=1
    source "$MODULE"
    reload_decky_plugins() { fail '幂等检测不应刷新 Decky'; }
    install_handheld_frontend_overlay "HueSync" "3.9.0" "通用掌机 RGB" \
        "$PROJECT_ROOT/third_party/huesync-cn-v3.9.0" \
        "8af434b51c39f054b94ff71a39798569dc58b0fff36c74a5282edcb89e7bd0c5" \
        "原作者：honjow；许可证：BSD 3-Clause。" 0
})"
printf '%s\n' "$repeat_output" | grep -Fq '[已安装]' || fail "重复执行未幂等跳过"

# 检查两种归档分支均使用固定 SHA256，并在官方包安装后才叠加前端。
dispatch_output="$({
    DECKY_PLUGIN_DIR="$TMP_ROOT/dispatch"
    ZHOUKEER_TEST_MODE=1
    source "$MODULE"
    detect_platform() { IS_STEAMOS=1; }
    handheld_overlay_is_current() { return 1; }
    install_decky_zip() { echo "ZIP:$2:$3:$4:$5"; }
    install_decky_tar_gz() { echo "TAR:$2:$3:$4:$5"; }
    install_handheld_frontend_overlay() { echo "OVERLAY:$1:$2:$3"; }
    ensure_handheld_overlay_current zip ZipDir 1.0 中文ZIP https://example.invalid/a.zip abc \
        /overlay def 作者 1
    ensure_handheld_overlay_current tar.gz TarDir 2.0 中文TAR https://example.invalid/a.tar.gz ghi \
        /overlay jkl 作者 1
})"
printf '%s\n' "$dispatch_output" | grep -Fq 'ZIP:https://example.invalid/a.zip:abc:ZipDir:0' || \
    fail "ZIP 安装分支参数错误"
printf '%s\n' "$dispatch_output" | grep -Fq 'TAR:https://example.invalid/a.tar.gz:ghi:TarDir:0' || \
    fail "tar.gz 安装分支参数错误"
[ "$(printf '%s\n' "$dispatch_output" | grep -c '^OVERLAY:')" -eq 2 ] || \
    fail "官方包安装后未叠加两个前端"

for relative_dir in huesync-cn-v3.9.0 legion-go-remapper-zh-v0.3.0 \
    gpd-control-zh-v0.0.2 lego-vibe-control-zh-v1.5.0 lego2-fan-control-zh-v0.260430; do
    grep -Fq "copy_handheld_frontend_overlay third_party/$relative_dir" "$PROJECT_ROOT/install.sh" || \
        fail "安装器白名单遗漏 $relative_dir"
    grep -Fq "third_party/$relative_dir/dist/index.js" "$PROJECT_ROOT/scripts/package_release.sh" || \
        fail "发布包校验遗漏 $relative_dir"
done

echo "PASS: 掌机插件中文前端、官方后端保留、ZIP/tar.gz 分支及发布白名单检查通过"
