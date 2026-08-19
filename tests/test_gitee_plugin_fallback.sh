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
calculate_decky_sha256() { return 1; }
feature_plugin_is_current() { return 1; }
feature_plugin_is_present() { return 1; }
install_decky_zip_from_mirror() { printf 'gitee:%s\n' "$1" >> "$CALLS"; return "${GITEE_RESULT:-1}"; }
remove_legacy_lsfg_directories() { return 0; }
log() { return 0; }

GITEE_RESULT=0
: > "$CALLS"
install_lsfg_zh_from_gitee 0 || fail "小黄鸭没有从 Gitee 分块镜像安装"
install_fsr4_zh_from_gitee 0 || fail "FSR4 没有从 Gitee 分块镜像安装"
grep -Fq 'gitee:小黄鸭（LSFG-VK）' "$CALLS" || fail "小黄鸭未使用专用镜像"
grep -Fq 'gitee:FSR4（Decky Framegen）' "$CALLS" || fail "FSR4 未使用专用镜像"

GITEE_RESULT=1
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

echo "PASS: 小黄鸭与 FSR4 仅使用 Gitee 分块镜像且失败返回非零"
