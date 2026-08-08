#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1

FAIL() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/env.sh"

FIXTURE="$TMP_ROOT/fixture"
mkdir -p "$FIXTURE/v1"
printf '0123456789\n' > "$FIXTURE/full"
FULL_SHA="$(shasum -a 256 "$FIXTURE/full" | awk '{print $1}')"
FULL_SIZE="$(wc -c < "$FIXTURE/full" | tr -d ' ')"

printf '0123' > "$FIXTURE/v1/part.0001"
printf '4567' > "$FIXTURE/v1/part.0002"
printf '89\n' > "$FIXTURE/v1/part.0003"

cat > "$FIXTURE/latest.txt" <<EOF
id=test
name=测试镜像
version=v1
file=payload.bin
source_url=https://github.com/example/test/releases/download/v1/payload.bin
sha256=$FULL_SHA
size=$FULL_SIZE
chunks=3
chunk_size=4
EOF

curl() {
    local output="" url=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            --*) shift ;;
            https://*|http://*) url="$1"; shift ;;
            *) shift ;;
        esac
    done
    case "$url" in
        *'/raw/main/test/latest.txt') cp "$FIXTURE/latest.txt" "$output" ;;
        *'/raw/main/test/v1/part.0001') cp "$FIXTURE/v1/part.0001" "$output" ;;
        *'/raw/main/test/v1/part.0002') cp "$FIXTURE/v1/part.0002" "$output" ;;
        *'/raw/main/test/v1/part.0003') cp "$FIXTURE/v1/part.0003" "$output" ;;
        *) return 1 ;;
    esac
}

mirror_output="$(download_gitee_mirror_file test "$TMP_ROOT/out.bin" "$FULL_SHA" "测试镜像")"
printf '%s\n' "$mirror_output" | grep -Fq '正在下载 测试镜像' || \
    FAIL "Gitee 镜像下载提示没有使用 正在下载"
if printf '%s\n' "$mirror_output" | grep -Fq '正在安装'; then
    FAIL "Gitee 镜像下载仍显示 正在安装"
fi
cmp -s "$FIXTURE/full" "$TMP_ROOT/out.bin" || FAIL "Gitee 分块镜像重组内容不一致"

if download_gitee_mirror_file test "$TMP_ROOT/bad.bin" \
    "0000000000000000000000000000000000000000000000000000000000000000" \
    "测试镜像" >/dev/null 2>&1; then
    FAIL "错误 SHA256 仍从 Gitee 镜像下载成功"
fi
[ ! -e "$TMP_ROOT/bad.bin" ] || FAIL "错误 SHA256 留下了未校验文件"

resolve_latest_gitee_mirror test '^payload[.]bin$' "测试镜像" >/dev/null
[ "$_GITEE_MIRROR_LATEST_VERSION" = "v1" ] || FAIL "Gitee 镜像最新版本解析错误"
[ "$_GITEE_MIRROR_LATEST_SHA256" = "$FULL_SHA" ] || FAIL "Gitee 镜像最新 SHA256 解析错误"
[ "$_GITEE_MIRROR_LATEST_URL" = "https://github.com/example/test/releases/download/v1/payload.bin" ] || \
    FAIL "Gitee 镜像最新源地址未使用上游 source_url"

mirror_url="$(gitee_mirror_direct_url lsfg v0.12.5 Decky.LSFG-VK.zip)"
case "$mirror_url" in
    https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror/raw/main/lsfg/v0.12.5/Decky.LSFG-VK.zip) ;;
    *) FAIL "Gitee 直接镜像 URL 格式错误：$mirror_url" ;;
esac

mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip')"
[ "$mirror_id" = "lsfg" ] || FAIL "LSFG 镜像标识映射错误"
allycenter_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/PixelAddictUnlocked/allycenter/releases/download/v1.2.0/allycenter-v1.2.0.zip')"
[ "$allycenter_mirror_id" = "allycenter" ] || FAIL "Ally Center 镜像标识映射错误"
grep -Fq 'allycenter|Ally Center|v1.2.0|allycenter-v1.2.0.zip|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "Ally Center 缺少 Gitee 固定镜像清单"
grep -Fq '| Ally Center |' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 Ally Center"
if gitee_mirror_id_for_url \
    'https://github.com/Ren-Amamiya-pixle/DeckRecall/releases/download/v0.2.3/DeckRecall.zip' \
    >/dev/null 2>&1; then
    FAIL "DeckRecall 未提供 LICENSE，不应进入公开镜像"
fi
if gitee_mirror_id_for_url \
    'https://github.com/stenzek/duckstation/releases/download/v0.1/DuckStation.AppImage' \
    >/dev/null 2>&1; then
    FAIL "DuckStation 使用 CC BY-NC-ND，不应进入公开镜像"
fi

grep -Fq 'DeckRecall' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 DeckRecall"
grep -Fq 'CC BY-NC-ND 4.0' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 DuckStation 许可证说明"

echo "PASS: Gitee 分块镜像清单、重组、校验与授权过滤测试通过"
