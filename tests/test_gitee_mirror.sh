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
[ "$(gitee_mirror_manifest_repo proton-cachyos)" = "zhoukeer-toolbox-mirror-9" ] || \
    FAIL "Proton-CachyOS 最新清单未使用独立 mirror-9"
[ "$(gitee_mirror_manifest_repo test)" = "zhoukeer-toolbox-mirror" ] || \
    FAIL "其他镜像清单仓库被 GE-Proton 专用路由影响"
[ "$(gitee_mirror_manifest_repo ayaneo3-companion)" = zhoukeer-toolbox-mirror-4 ] || FAIL "AYANEO3 下载仓库路由错误"
[ "$(gitee_mirror_id_for_url 'https://github.com/Rayekkk/Ayaneo3Companion/releases/download/1.2.0/Ayaneo3Companion-1.2.0.zip')" = ayaneo3-companion ] || FAIL "AYANEO3 原包地址路由错误"
grep -Fq 'ayaneo3-companion|AYANEO3 Companion|1.2.0|Ayaneo3Companion-1.2.0.zip|' "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "AYANEO3 镜像配置缺失"
grep -Fq 'sync_plugin ayaneo3-companion' "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || FAIL "AYANEO3 自动同步配置缺失"

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
    'https://github.com/eugeniosegala/MAKO/releases/download/plugin-v2.2.0/MAKO-Decky-v2.2.0.zip')"
[ "$mako_mirror_id" = "lsfg-mako" ] || FAIL "MAKO LSFG 镜像标识映射错误"
newfreedeck_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/panyiwei-home/Freedeck/releases/download/N0.3/NewFreedeck.v.0.3.zip')"
[ "$newfreedeck_mirror_id" = "newfreedeck" ] || \
    FAIL "NewFreedeck 0.2.0 未使用独立 Gitee 镜像标识"
simpledeckytdp_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/aarron-lee/SimpleDeckyTDP/releases/download/v1.0.7/SimpleDeckyTDP.zip')"
[ "$simpledeckytdp_mirror_id" = "simpledeckytdp" ] || \
    FAIL "SimpleDeckyTDP v1.0.7 未使用独立 Gitee 镜像标识"
grep -Fq 'simpledeckytdp|SimpleDeckyTDP|v1.0.7|SimpleDeckyTDP.zip|https://github.com/aarron-lee/SimpleDeckyTDP/releases/download/v1.0.7/SimpleDeckyTDP.zip|dae7cf43ec8936c07a94a08ac418be8d9e129744a54f3aa63d2b31222bc0ad38|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
    FAIL "SimpleDeckyTDP v1.0.7 缺少固定 Gitee 镜像清单"
simpledeckytdp_sync="$(sed -n '/^# SimpleDeckyTDP 需要先由 Renkit/,/^# HMCL 启动器/p' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh")"
printf '%s\n' "$simpledeckytdp_sync" | grep -Fq '"v1.0.7" "SimpleDeckyTDP.zip"' || \
    FAIL "SimpleDeckyTDP Gitee 自动同步未锁定汉化基线 v1.0.7"
printf '%s\n' "$simpledeckytdp_sync" | grep -Fq \
    '"dae7cf43ec8936c07a94a08ac418be8d9e129744a54f3aa63d2b31222bc0ad38"' || \
    FAIL "SimpleDeckyTDP Gitee 自动同步 SHA256 与汉化基线不一致"
grep -Fq 'sync_plugin newfreedeck' "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "NewFreedeck 0.2.0 缺少 Gitee 分块同步入口"
grep -Fq 'newfreedeck|NewFreedeck|N03|NewFreedeck.v.0.3.zip|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
    FAIL "NewFreedeck 0.2.0 缺少固定镜像清单"
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
grep -Fq 'GE_PUSH_BATCH_SIZE=1' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 专用镜像未按小批次推送"
grep -Fq 'push_main_with_retry' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 专用镜像推送缺少超时重试"
grep -Fq 'git -C "$repo" add -- ge-proton/latest.txt' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "GE-Proton 清单没有在全部分块后单独发布"
grep -Fq 'zhoukeer-toolbox-mirror-9' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "Proton-CachyOS 同步未使用独立 mirror-9"
grep -Fq -- '--only-proton-cachyos' \
    "$PROJECT_ROOT/.github/workflows/sync-proton-cachyos-gitee.yml" || \
    FAIL "Proton-CachyOS 专用定时同步工作流缺失"
grep -Fq 'git -C "$repo" add -- README.md proton-cachyos/latest.txt' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "Proton-CachyOS 清单没有在全部分块后单独发布"
grep -Fq '"Proton-CachyOS chunk $first/$PROTON_CACHYOS_CHUNKS" 900' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "Proton-CachyOS 推送未给 Gitee 慢速连接保留足够时间"
grep -Fq "'^MAKO-Decky-v[0-9.]+[.]zip$'" \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "MAKO LSFG 同步未跟随上游最新正式插件包"
grep -Fq 'mirror_mako_latest()' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
    FAIL "MAKO LSFG 手动镜像流程未复用最新 Release 解析"
for mapping in \
    'https://github.com/ShadowBlip/InputPlumber/releases/download/v0.79.2/inputplumber-x86_64.tar.gz|inputplumber' \
    'https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/f1-bios-v1.14/ONEXFLY-F1-7840U-BIOS-V1.14.zip|f1-bios' \
    'https://raw.githubusercontent.com/dahui/onexplayer-x2-mini-pro-cachyos/a0b76a16471174ded80913a681357f43bfb17fa4/etc/inputplumber/devices.d/50-onexplayer_x2_mini.yaml|oxpx2-device' \
    'https://raw.githubusercontent.com/dahui/onexplayer-x2-mini-pro-cachyos/a0b76a16471174ded80913a681357f43bfb17fa4/etc/inputplumber/capability_maps.d/onexplayer_x2mini.yaml|oxpx2-map' \
    'https://raw.githubusercontent.com/dahui/onexplayer-x2-mini-pro-cachyos/a0b76a16471174ded80913a681357f43bfb17fa4/usr/share/steamos-manager/devices/onexplayer-x2-mini.toml|oxpx2-manager' \
    'https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.AppImage|rustdesk' \
    'https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3.zip|steamgriddb' \
    'https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/e84f5b1f111af8862b06218479491fbf61036e1bfd9f16f93f9901e9b9ebc5e0.zip|steamgriddb' \
    'https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350.zip|cssloader' \
    'https://github.com/panyiwei-home/Friendeck/releases/download/0.7.7/Friendeck.v.0.7.7.zip|friendeck' \
    'https://github.com/HMCL-dev/HMCL/releases/download/v3.16.3/HMCL-3.16.3.jar|hmcl' \
    'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12%2B8/OpenJDK21U-jre_x64_linux_hotspot_21.0.12_8.tar.gz|temurin21-jre'; do
    mapping_url="${mapping%%|*}"
    mapping_id="${mapping##*|}"
    [ "$(gitee_mirror_id_for_url "$mapping_url")" = "$mapping_id" ] || \
        FAIL "$mapping_id 镜像标识映射错误"
    grep -Fq "$mapping_id|" "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || \
        FAIL "$mapping_id 缺少 Gitee 固定镜像清单"
done
grep -Fq -- '--only-inputplumber' "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || \
    FAIL "InputPlumber 缺少独立镜像同步模式"
grep -Fxq '        run: bash scripts/sync_gitee_mirrors.sh' \
    "$PROJECT_ROOT/.github/workflows/sync-gitee-mirrors.yml" || \
    FAIL "推送同步脚本后不会运行通用镜像同步"
allycenter_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/PixelAddictUnlocked/allycenter/releases/download/v1.2.0/allycenter-v1.2.0.zip')"
[ "$allycenter_mirror_id" = "allycenter" ] || FAIL "Ally Center 镜像标识映射错误"
grep -Fq 'allycenter|Ally Center|v1.2.0|allycenter-v1.2.0.zip|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "Ally Center 缺少 Gitee 固定镜像清单"
grep -Fq '| Ally Center |' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 Ally Center"
powercontrol_mirror_id="$(gitee_mirror_id_for_url \
    'https://github.com/mengmeet/PowerControl/releases/download/v3.15.1/PowerControl.zip')"
[ "$powercontrol_mirror_id" = "powercontrol" ] || FAIL "PowerControl 镜像标识映射错误"
grep -Fq 'powercontrol|PowerControl|v3.15.1|PowerControl.zip|https://github.com/mengmeet/PowerControl/releases/download/v3.15.1/PowerControl.zip|9c14eddbec7657a23e73eaf811bd8344198159d48303481cf70ebb7c1c1ebd7c|' \
    "$PROJECT_ROOT/scripts/mirror_gitee_assets.sh" || FAIL "PowerControl 缺少固定镜像清单"
grep -Fq 'sync_plugin powercontrol "mengmeet/PowerControl"' \
    "$PROJECT_ROOT/scripts/sync_gitee_mirrors.sh" || FAIL "PowerControl 缺少镜像同步入口"
grep -Fq '| PowerControl |' "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" || \
    FAIL "License 清单缺少 PowerControl"
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

(
    # Coordinate three mocked requests before allowing any to finish. This
    # catches a serial regression without relying on measured execution time.
    mkdir -p "$TMP_ROOT/mako-started"
    mako_mode=success
    download_gitee_mirror_manifest() {
        [ "$1" = lsfg-mako ] || return 1
        sed 's/^id=test$/id=lsfg-mako/' "$FIXTURE/latest.txt" > "$2" &&
            _gitee_mirror_parse_manifest "$2"
    }
    curl() {
        local output="" url="" retry_all=0 pause
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --output) output="$2"; shift 2 ;;
                --retry-all-errors) retry_all=1; shift ;;
                https://*) url="$1"; shift ;;
                *) shift ;;
            esac
        done
        case "$url" in */lsfg-mako/v1/part.*) ;; *) return 99 ;; esac
        [ "$retry_all" = 1 ] || return 98
        local part="${url##*/}"
        : > "$TMP_ROOT/mako-started/$part"
        for pause in {1..100}; do
            [ -f "$TMP_ROOT/mako-started/part.0001" ] &&
              [ -f "$TMP_ROOT/mako-started/part.0002" ] &&
              [ -f "$TMP_ROOT/mako-started/part.0003" ] && break
            sleep 0.03
        done
        [ "$pause" -lt 100 ] || return 97
        if [ "$part" = part.0002 ]; then
            case "$mako_mode" in
                disk) return 23 ;;
                network) return 56 ;;
                bad-data) printf 'bad!' > "$output"; return 0 ;;
            esac
        fi
        cp "$FIXTURE/v1/$part" "$output"
    }
    # Report actual received bytes, even before any complete file is appended.
    printf '12345' > "$TMP_ROOT/mako-progress-part"
    progress_started=$((SECONDS - 1))
    _gitee_mirror_mako_progress MAKO 5 20 "$progress_started" 1 \
        "$TMP_ROOT/mako-progress-part" "$TMP_ROOT/missing-part" > "$TMP_ROOT/mako-progress"
    grep -Fq '50%' "$TMP_ROOT/mako-progress" || FAIL 'MAKO progress ignored received bytes'
    grep -Fq 'KB/s' "$TMP_ROOT/mako-progress" || FAIL 'MAKO progress omitted speed'
    _gitee_mirror_mako_progress MAKO 30 20 "$progress_started" 1 > "$TMP_ROOT/mako-progress"
    grep -Fq '99%' "$TMP_ROOT/mako-progress" || FAIL 'MAKO announced completion before verification'
    download_gitee_mirror_file lsfg-mako "$TMP_ROOT/mako.bin" "$FULL_SHA" MAKO > "$TMP_ROOT/mako-output" ||
        FAIL 'MAKO parts did not run in parallel'
    cmp -s "$FIXTURE/full" "$TMP_ROOT/mako.bin" || FAIL 'MAKO did not assemble parts in manifest order'
    if grep -Eq '分块|Gitee' "$TMP_ROOT/mako-output"; then FAIL 'MAKO showed internal download details'; fi
    download_github_file() { : > "$TMP_ROOT/mako-fallback"; }
    for mako_mode in network disk bad-data; do
        if [ "$mako_mode" = network ]; then
            download_with_gitee_mirror_fallback lsfg-mako 'https://example.invalid/mako.zip' "$FULL_SHA" "$TMP_ROOT/mako-bad.bin" MAKO >/dev/null ||
                FAIL 'Network failure did not switch to backup'
            [ -f "$TMP_ROOT/mako-fallback" ] || FAIL 'Missing backup call'
            rm -f -- "$TMP_ROOT/mako-fallback"
        elif [ "$mako_mode" = disk ]; then
            if download_with_gitee_mirror_fallback lsfg-mako 'https://example.invalid/mako.zip' "$FULL_SHA" "$TMP_ROOT/mako-bad.bin" MAKO >/dev/null; then
                FAIL 'Local I/O failure was hidden'
            fi
            [ "$DOWNLOAD_LOCAL_IO_FAILED" = 1 ] && [ ! -e "$TMP_ROOT/mako-fallback" ] ||
                FAIL 'Local write failure was retried over the network'
        elif download_gitee_mirror_file lsfg-mako "$TMP_ROOT/mako-bad.bin" "$FULL_SHA" MAKO >/dev/null; then
            FAIL 'MAKO accepted a corrupt part'
        fi
        [ ! -e "$TMP_ROOT/mako-bad.bin" ] || FAIL 'Partial MAKO archive was published'
    done
    if compgen -G "$TMP_ROOT/mako*.parts.*" >/dev/null; then FAIL 'MAKO left temporary parts on disk'; fi
)

echo "PASS: Gitee 分块镜像清单、重组、校验与授权过滤测试通过"
