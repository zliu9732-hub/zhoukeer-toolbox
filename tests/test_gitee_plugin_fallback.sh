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

CALLS="$TMP_ROOT/fallback.calls"
feature_plugin_is_present() { return 1; }
install_decky_zip() { printf 'github:%s\n' "$1" >> "$CALLS"; return 1; }
install_decky_zip_from_gitee_archive() { printf 'gitee:%s\n' "$1" >> "$CALLS"; return 0; }
remove_legacy_lsfg_directories() { return 0; }
log() { return 0; }

install_lsfg_zh_from_gitee 0 || fail "小黄鸭没有从 GitHub 失败切换到 Gitee"
install_fsr4_zh_from_gitee 0 || fail "FSR4 没有从 GitHub 失败切换到 Gitee"
[ "$(grep -c '^github:' "$CALLS")" -eq 2 ] || fail "两个插件没有先尝试 GitHub"
[ "$(grep -c '^gitee:' "$CALLS")" -eq 2 ] || fail "两个插件没有回退 Gitee"

echo "PASS: 小黄鸭与 FSR4 的 GitHub→Gitee 回退及归档校验通过"
