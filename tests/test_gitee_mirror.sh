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

[ "$(gitee_mirror_manifest_repo ge-proton)" = "zhoukeer-toolbox-mirror-8" ] || \
    FAIL "GE-Proton 最新清单未迁移到 mirror-8"
[ "$(gitee_mirror_manifest_repo test)" = "zhoukeer-toolbox-mirror" ] || \
    FAIL "其他镜像清单仓库被 GE-Proton 专用路由影响"

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

mirror_url="$(gitee_mirror_direct_url lsfg v0.12.8 Decky.LSFG-VK.zip)"
case "$mirror_url" in
    https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror/raw/main/lsfg/v0.12.8/Decky.LSFG-VK.zip) ;;
    *) FAIL "Gitee 直接镜像 URL 格式错误：$mirror_url" ;;
esac

mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.8/Decky.LSFG-VK.zip')"
[ "$mirror_id" = "lsfg" ] || FAIL "LSFG 镜像标识映射错误"
mako_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/eugeniosegala/MAKO/releases/download/plugin-v2.1.0/MAKO-Decky-v2.1.0.zip')"
[ "$mako_mirror_id" = "lsfg-mako" ] || FAIL "MAKO LSFG 镜像标识映射错误"
grep -Fq 'sync_plugin lsfg-mako' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "MAKO LSFG 缺少 Gitee 分块镜像同步入口"
grep -Fq 'zhoukeer-toolbox-mirror-3' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "MAKO LSFG 同步未使用 mirror-3"
grep -Fq 'zhoukeer-toolbox-mirror-8' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 同步未使用专用 mirror-8"
grep -Fq -- '--only-ge-proton' \
    "$PROJECT_ROOT/.github/workflows/sync-ge-proton-gitee.yml" || \
    FAIL "GE-Proton 专用定时同步工作流缺失"
grep -Fq 'GE_PUSH_BATCH_SIZE=4' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 专用镜像未按小批次推送"
grep -Fq 'push_main_with_retry' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 专用镜像推送缺少超时重试"
grep -Fq 'git -C "$repo" add -- ge-proton/latest.txt' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 清单没有在全部分块后单独发布"
grep -Fq "'^MAKO-Decky-v[0-9.]+[.]zip$'" \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "MAKO LSFG 同步未跟随上游最新正式插件包"
grep -Fq 'mirror_mako_latest()' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
    FAIL "MAKO LSFG 手动镜像流程未复用最新 Release 解析"
for mapping in \
    'https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3.zip|steamgriddb' \
    'https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350.zip|cssloader' \
    'https://github.com/panyiwei-home/Friendeck/releases/download/0.7.7/Friendeck.v.0.7.7.zip|friendeck' \
    'https://github.com/jinzhongjia/decky-music/releases/download/v1.0.2/Decky.Music.full.zip|deckymusic' \
    'https://github.com/HMCL-dev/HMCL/releases/download/v3.16.3/HMCL-3.16.3.jar|hmcl' \
    'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12%2B8/OpenJDK21U-jre_x64_linux_hotspot_21.0.12_8.tar.gz|temurin21-jre'; do
    mapping_url="${mapping%%|*}"
    mapping_id="${mapping##*|}"
    [ "$(gitee_mirror_id_for_url "$mapping_url")" = "$mapping_id" ] || \
        FAIL "$mapping_id 镜像标识映射错误"
    grep -Fq "$mapping_id|" "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
        FAIL "$mapping_id 缺少 Gitee 固定镜像清单"
done
grep -Fq 'deckymusic|Decky Music 完整包|v1.0.2|Decky.Music.full.zip|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
    FAIL "Decky Music v1.0.2 完整包缺少 Gitee 固定分块清单"
grep -Fq "'^Decky[.]Music[.]full[.]zip$'" \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "Decky Music 同步入口未固定完整包资产"
grep -Fq 'DECKY_DECKYMUSIC_MIRROR_REPO="zhoukeer-toolbox-mirror-4"' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || \
    FAIL "Decky Music 未迁移到 mirror-4"
allycenter_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/PixelAddictUnlocked/allycenter/releases/download/v1.2.0/allycenter-v1.2.0.zip')"
[ "$allycenter_mirror_id" = "allycenter" ] || FAIL "Ally Center 镜像标识映射错误"
grep -Fq 'allycenter|Ally Center|v1.2.0|allycenter-v1.2.0.zip|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "Ally Center 缺少 Gitee 固定镜像清单"
grep -Fq '| Ally Center |' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 Ally Center"
if gitee_mirror_id_for_url \
    'https://github.com/Ren-Amamiya-pixle/DeckRecall/releases/download/v0.4.2/DeckRecall.zip' \
    >/dev/null 2>&1; then :; else
    FAIL "DeckRecall v0.4.2 未路由到 Gitee 更新镜像清单"
fi
grep -Fq 'deckrecall|DeckRecall|v0.4.2|DeckRecall.zip|https://github.com/Ren-Amamiya-pixle/DeckRecall/releases/download/v0.4.2/DeckRecall.zip|38cbbaa94f39bbe7231f490fd3826f1347ce8c0acb53aa69c784d8511cc058fd|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "DeckRecall v0.4.2 固定镜像清单不完整"
grep -Fq '作者授权 Renkit 镜像分发 | 是' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "DeckRecall 作者镜像授权未写入 License 清单"
savepulse_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/Ren-Amamiya-pixle/SavePulse/releases/download/v0.2.0-alpha.1/SavePulse.zip')"
[ "$savepulse_mirror_id" = "savepulse" ] || FAIL "SavePulse 未路由到 Gitee 分块镜像"
grep -Fq 'savepulse|SavePulse|v0.2.0-alpha.1|SavePulse.zip|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "SavePulse 缺少固定镜像清单"
grep -Fq '| SavePulse |' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 SavePulse"
onexplayer_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/srsholmes/onexplayer-apex-bazzite-fixes/releases/download/build-b696161/OneXPlayer_Apex_Tools.zip')"
[ "$onexplayer_mirror_id" = "onexplayer-apex" ] || FAIL "OneXPlayer Apex 镜像标识映射错误"
for emulator in 'yuzu|yuzu.AppImage|yuzu' 'cemu|Cemu.AppImage|cemu' \
    'duckstation|DuckStation.AppImage|duckstation' 'pcsx2|pcsx2-Qt.AppImage|pcsx2' \
    'rpcs3|rpcs3.AppImage|rpcs3' 'shadps4|Shadps4-qt.AppImage|shadps4'; do
    name="${emulator%%|*}"
    rest="${emulator#*|}"
    asset="${rest%%|*}"
    expected_id="${rest#*|}"
    emulator_mirror_id="$(gitee_mirror_id_for_url \
        "https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/$asset")"
    [ "$emulator_mirror_id" = "$expected_id" ] || FAIL "$name 模拟器镜像标识映射错误"
    grep -Fq "$name|" "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
        FAIL "$name 缺少 Gitee 固定镜像清单"
done
if gitee_mirror_id_for_url \
    'https://github.com/stenzek/duckstation/releases/download/v0.1/DuckStation.AppImage' \
    >/dev/null 2>&1; then
    FAIL "DuckStation 上游 GitHub 地址不应被识别为自有镜像"
fi

grep -Fq 'DeckRecall' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 DeckRecall"
grep -Fq 'CC BY-NC-ND 4.0' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 DuckStation 许可证说明"
grep -Fq 'Gitee 分块镜像优先，GitHub Release 回退' \
    "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少模拟器 Gitee 镜像说明"

echo "PASS: Gitee 分块镜像清单、重组、校验与授权过滤测试通过"
