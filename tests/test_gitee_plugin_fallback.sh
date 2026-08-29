#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/plugin_store.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$MODULE"

mkdir -p "$TMP_ROOT/plugin/TestPlugin/dist" \
    "$TMP_ROOT/repository/zhoukeer-toolbox-v5.1.1/dist"
printf '{"name":"TestPlugin"}\n' > "$TMP_ROOT/plugin/TestPlugin/plugin.json"
printf 'test plugin\n' > "$TMP_ROOT/plugin/TestPlugin/dist/index.js"
(cd "$TMP_ROOT/plugin" && zip -qry "$TMP_ROOT/plugin.zip" TestPlugin)
cp "$TMP_ROOT/plugin.zip" \
    "$TMP_ROOT/repository/zhoukeer-toolbox-v5.1.1/dist/plugin.zip"
(cd "$TMP_ROOT/repository" && zip -qry "$TMP_ROOT/repository.zip" zhoukeer-toolbox-v5.1.1)

plugin_sha="$(shasum -a 256 "$TMP_ROOT/plugin.zip" | awk '{print $1}')"
extract_gitee_plugin_archive \
    "$TMP_ROOT/repository.zip" \
    "zhoukeer-toolbox-v5.1.1/dist/plugin.zip" \
    "$TMP_ROOT/extracted.zip" \
    "$plugin_sha" || fail "无法从安全的 Gitee 仓库归档提取插件包"
cmp -s "$TMP_ROOT/plugin.zip" "$TMP_ROOT/extracted.zip" || fail "提取的插件包内容不一致"

if extract_gitee_plugin_archive "$TMP_ROOT/repository.zip" \
    "../plugin.zip" "$TMP_ROOT/unsafe.zip" "$plugin_sha"; then
    fail "Gitee 归档接受了路径穿越成员"
fi
if extract_gitee_plugin_archive "$TMP_ROOT/repository.zip" \
    "zhoukeer-toolbox-v5.1.1/dist/plugin.zip" "$TMP_ROOT/bad.zip" "bad-hash"; then
    fail "Gitee 插件包错误校验值仍被接受"
fi

# install_decky_zip_from_mirror 必须静默下载器自身的 Gitee 提示，
# 只保留通用的安装结果，避免安装输出出现“通过 Gitee 下载”等描述。
PLUGIN_ROOT="$TMP_ROOT/plugins"
mkdir -p "$PLUGIN_ROOT"
(
    DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
    export DECKY_PLUGIN_DIR
    download_gitee_mirror_file() {
        cp -- "$TMP_ROOT/plugin.zip" "$2"
        echo "TestPlugin 通过 Gitee 镜像下载完成。"
        return 0
    }
    install_output="$(install_decky_zip_from_mirror \
        "TestPlugin" "test" "$plugin_sha" "TestPlugin")"
    if printf '%s\n' "$install_output" | grep -Fqi 'gitee'; then
        fail "安装输出仍显示 Gitee 下载描述"
    fi
    [ -f "$PLUGIN_ROOT/TestPlugin/plugin.json" ] || \
        fail "静默下载后插件未安装"
)

CALLS="$TMP_ROOT/strict-gitee.calls"
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; }
calculate_decky_sha256() {
    case "$1" in
        *'/Decky LSFG-VK/dist/index.js') printf '%s\n' "$LSFG_ZH_INDEX_SHA256" ;;
        *'/Decky-Framegen/dist/index.js') printf '%s\n' "$FSR4_ZH_INDEX_SHA256" ;;
        *'/third_party/decky-simpledeckytdp-zh-v1.0.6/dist/index.js') \
            printf '%s\n' "$SIMPLEDECKYTDP_ZH_INDEX_SHA256" ;;
        *'/SimpleDeckyTDP/dist/index.js') printf '%s\n' "$SIMPLEDECKYTDP_ZH_INDEX_SHA256" ;;
        *) return 1 ;;
    esac
}
install_decky_zip_from_mirror() {
    printf 'gitee:%s\n' "$1" >> "$CALLS"
    [ "${GITEE_RESULT:-1}" = "0" ] || return 1
    if [ "$2" = "simpledeckytdp" ]; then
        mkdir -p "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/bin" \
            "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/dist"
        printf '{"name":"SimpleDeckyTDP"}\n' > \
            "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/plugin.json"
        printf '{"version":"1.0.6"}\n' > \
            "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/package.json"
        printf 'official frontend\n' > \
            "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/dist/index.js"
        printf 'runtime\n' > "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/bin/ryzenadj"
        printf 'runtime library\n' > "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/bin/libryzenadj.so"
        printf 'runtime license\n' > "$DECKY_PLUGIN_DIR/SimpleDeckyTDP/bin/LICENSE-ryzenadj"
    fi
    return 0
}
remove_legacy_lsfg_directories() { return 0; }
log() { return 0; }

mkdir -p "$PLUGIN_ROOT/Decky LSFG-VK/dist" "$PLUGIN_ROOT/Decky-Framegen/dist"
DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
export DECKY_PLUGIN_DIR
printf '{"version":"0.12.8"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/package.json"
printf '{"version":"0.17"}\n' > "$PLUGIN_ROOT/Decky-Framegen/package.json"
printf 'bundle\n' > "$PLUGIN_ROOT/Decky LSFG-VK/dist/index.js"
printf 'bundle\n' > "$PLUGIN_ROOT/Decky-Framegen/dist/index.js"
printf '{"name":"Decky LSFG-VK"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/plugin.json"
printf '{"name":"Decky-Framegen"}\n' > "$PLUGIN_ROOT/Decky-Framegen/plugin.json"

GITEE_RESULT=0
: > "$CALLS"
install_lsfg_zh_from_gitee 0 || fail "小黄鸭没有从 Gitee 分块镜像安装"
install_fsr4_zh_from_gitee 0 || fail "FSR4 没有从 Gitee 分块镜像安装"
install_simpledeckytdp_zh_from_gitee 0 || \
    fail "SimpleDeckyTDP 没有从 Gitee 镜像安装并叠加汉化"
grep -Fq 'gitee:小黄鸭（LSFG-VK）' "$CALLS" || fail "小黄鸭未使用专用镜像"
grep -Fq 'gitee:FSR4（Decky Framegen）' "$CALLS" || fail "FSR4 未使用专用镜像"
grep -Fq 'gitee:SimpleDeckyTDP' "$CALLS" || fail "SimpleDeckyTDP 未使用专用镜像"
grep -Fq '"version": "1.0.6"' \
    "$PLUGIN_ROOT/SimpleDeckyTDP/package.json" || \
    fail "SimpleDeckyTDP Gitee 安装后未叠加 v1.0.6 汉化组件"
grep -Fq '"name": "掌机功耗控制"' \
    "$PLUGIN_ROOT/SimpleDeckyTDP/plugin.json" || \
    fail "SimpleDeckyTDP Gitee 安装后未写入中文插件身份"

printf '{"name":"小黄鸭"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/plugin.json"
printf '{"name":"Decky-Framegen（FSR4）"}\n' > "$PLUGIN_ROOT/Decky-Framegen/plugin.json"
: > "$CALLS"
install_lsfg_zh_from_gitee 0 || fail "新小黄鸭名称未被识别为当前版本"
install_fsr4_zh_from_gitee 0 || fail "新 FSR4 名称未被识别为当前版本"
[ ! -s "$CALLS" ] || fail "正确外显名仍触发了重复下载"

GITEE_RESULT=1
printf '{"name":"Decky LSFG-VK"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/plugin.json"
printf '{"name":"Decky-Framegen"}\n' > "$PLUGIN_ROOT/Decky-Framegen/plugin.json"
: > "$CALLS"
if install_lsfg_zh_from_gitee 0; then
    fail "小黄鸭镜像失败后错误返回成功"
fi
if install_fsr4_zh_from_gitee 0; then
    fail "FSR4 镜像失败后错误返回成功"
fi
[ "$(grep -c '^gitee:' "$CALLS")" -eq 2 ] || fail "镜像失败时没有各尝试一次"
if grep -Eq 'github|overlay' "$CALLS"; then
    fail "镜像失败后仍回退 GitHub 或本地覆盖层"
fi

echo "PASS: 小黄鸭、FSR4 与 SimpleDeckyTDP 的 Gitee 镜像路径和失败状态正确"
