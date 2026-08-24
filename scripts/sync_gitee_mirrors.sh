#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"
load_config

OWNER="zliu9732-hub"
TOKEN="${GITEE_TOKEN:-}"
MODE="${1:-}"
case "$MODE" in
    ''|--only-ge-proton) ;;
    *) echo "Usage: $0 [--only-ge-proton]"; exit 2 ;;
esac
[ -n "$TOKEN" ] || {
    echo "GITEE_TOKEN secret is missing"
    exit 1
}

BASE="https://${OWNER}:${TOKEN}@gitee.com/${OWNER}"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
MIRROR1="$WORK/mirror1"
MIRROR2="$WORK/mirror2"
MIRROR3="$WORK/mirror3"
MIRROR8="$WORK/mirror8"
GE_PROTON_VERSION=""
GE_PROTON_CHUNKS=0
GE_PUSH_BATCH_SIZE=1

prepare_empty_main() {
    local repo="$1"
    if ! git -C "$repo" rev-parse --verify HEAD >/dev/null 2>&1; then
        git -C "$repo" switch -q -C main
    fi
}

if [ "$MODE" != "--only-ge-proton" ]; then
    git clone -q "$BASE/zhoukeer-toolbox-mirror.git" "$MIRROR1"
    git clone -q "$BASE/zhoukeer-toolbox-mirror-2.git" "$MIRROR2"
    git clone -q "$BASE/zhoukeer-toolbox-mirror-3.git" "$MIRROR3"
fi
git clone -q "$BASE/zhoukeer-toolbox-mirror-8.git" "$MIRROR8"
prepare_empty_main "$MIRROR8"

sha_of() {
    sha256sum -- "$1" | awk '{print $1}'
}

write_manifest() {
    local dir="$1" id="$2" name="$3" version="$4" file="$5" url="$6" sha="$7"
    local size="$8" chunks="$9" chunk_size="${10:-0}" repo1="${11:-}" repo2="${12:-}" parts_repo1="${13:-}"

    {
        printf 'id=%s\n' "$id"
        printf 'name=%s\n' "$name"
        printf 'version=%s\n' "$version"
        printf 'file=%s\n' "$file"
        printf 'source_url=%s\n' "$url"
        printf 'sha256=%s\n' "$sha"
        printf 'size=%s\n' "$size"
        printf 'chunks=%s\n' "$chunks"
        printf 'chunk_size=%s\n' "$chunk_size"
        [ -z "$repo1" ] || printf 'repo1=%s\n' "$repo1"
        [ -z "$repo2" ] || printf 'repo2=%s\n' "$repo2"
        [ -z "$parts_repo1" ] || printf 'parts_repo1=%s\n' "$parts_repo1"
    } > "$dir/$id/latest.txt"
}

sync_plugin() {
    local id="$1" repo="$2" pattern="$3" name="$4"
    local pinned_version="${5:-}" pinned_file="${6:-}" pinned_url="${7:-}" pinned_sha="${8:-}"
    local mirror_repo="${9:-$MIRROR1}"
    local version file url sha size chunks target_dir

    if [ -n "$pinned_version" ]; then
        version="$pinned_version"
        file="$pinned_file"
        url="$pinned_url"
        sha="$pinned_sha"
    else
        if ! resolve_latest_github_release "$repo" "$pattern" "$name"; then
            echo "Skip $id: latest release lookup failed"
            return 0
        fi
        version="$_LATEST_RELEASE_TAG"
        file="$_LATEST_RELEASE_ASSET"
        url="$_LATEST_RELEASE_URL"
        sha="$_LATEST_RELEASE_SHA256"
    fi
    [ -n "$version" ] && [ -n "$file" ] && [ -n "$url" ] || return 1

    curl -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 600 -o "$WORK/$file" "$url"
    [ "$(sha_of "$WORK/$file")" = "$sha" ] || {
        echo "$id SHA256 mismatch"
        exit 1
    }
    size="$(wc -c < "$WORK/$file" | tr -d ' ')"
    target_dir="$mirror_repo/$id/$version"
    mkdir -p "$target_dir"
    rm -f -- "$mirror_repo/$id/$version"/*

    if [ "$size" -le 9437184 ]; then
        cp -- "$WORK/$file" "$target_dir/$file"
        chunks=0
    else
        split -b 8388608 --numeric-suffixes=1 -a 4 \
            "$WORK/$file" "$target_dir/part."
        chunks="$(find "$target_dir" -maxdepth 1 -name 'part.*' | wc -l | tr -d ' ')"
    fi
    write_manifest "$mirror_repo" "$id" "$name" "$version" "$file" \
        "$url" "$sha" "$size" "$chunks" 8388608
    echo "Synced $id $version"
}

sync_ge_proton() {
    local version file url sha size chunks target i part

    version="GE-Proton11-5"
    file="GE-Proton11-5-x86_64.tar.gz"
    url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-5/GE-Proton11-5-x86_64.tar.gz"
    sha="de43c4b25f3c047db49b96c44d84759952c5a01332a68805a09e69f95dc38a75"
    if resolve_latest_github_release "GloriousEggroll/proton-ge-custom" \
        '^GE-Proton[0-9]+-[0-9]+(-x86_64)?[.]tar[.]gz$' "GE-Proton"; then
        version="$_LATEST_RELEASE_TAG"
        file="$_LATEST_RELEASE_ASSET"
        url="$_LATEST_RELEASE_URL"
        sha="$_LATEST_RELEASE_SHA256"
    else
        echo "GE-Proton latest release lookup failed; using pinned $version"
    fi

    curl -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 1800 -o "$WORK/$file" "$url"
    [ "$(sha_of "$WORK/$file")" = "$sha" ] || {
        echo "GE-Proton SHA256 mismatch"
        exit 1
    }
    size="$(wc -c < "$WORK/$file" | tr -d ' ')"
    chunks=$(( (size + 8388607) / 8388608 ))
    target="$MIRROR8/ge-proton/$version"
    mkdir -p "$target"
    rm -f -- "$MIRROR8/ge-proton"/*/part.*

    split -b 8388608 --numeric-suffixes=1 -a 4 \
        "$WORK/$file" "$WORK/ge-proton.part."
    i=1
    while [ "$i" -le "$chunks" ]; do
        part="$(printf 'part.%04d' "$i")"
        cp -- "$WORK/ge-proton.$part" "$target/$part"
        i=$((i + 1))
    done

    write_manifest "$MIRROR8" "ge-proton" "GE-Proton" "$version" "$file" \
        "$url" "$sha" "$size" "$chunks" 8388608 \
        "zhoukeer-toolbox-mirror-8" "zhoukeer-toolbox-mirror-8" "$chunks"
    GE_PROTON_VERSION="$version"
    GE_PROTON_CHUNKS="$chunks"
    echo "Synced GE-Proton $version"
}

push_main_with_retry() {
    local repo="$1" label="$2" attempt=1

    while [ "$attempt" -le 3 ]; do
        echo "Uploading $label (attempt $attempt/3)..."
        if timeout 300 git -C "$repo" push --progress -u origin main; then
            return 0
        fi
        echo "Upload failed or timed out for $label"
        attempt=$((attempt + 1))
    done
    return 1
}

commit_and_push_ge_proton_batches() {
    local repo="$1" first last i part
    local -a paths=()

    [ -n "$GE_PROTON_VERSION" ] && [ "$GE_PROTON_CHUNKS" -gt 0 ] || {
        echo "GE-Proton batch metadata is missing"
        return 1
    }
    git -C "$repo" config user.name "zhoukeer-toolbox[bot]"
    git -C "$repo" config user.email "bot@users.noreply.github.com"

    first=1
    while [ "$first" -le "$GE_PROTON_CHUNKS" ]; do
        last=$((first + GE_PUSH_BATCH_SIZE - 1))
        [ "$last" -le "$GE_PROTON_CHUNKS" ] || last="$GE_PROTON_CHUNKS"
        paths=()
        i="$first"
        while [ "$i" -le "$last" ]; do
            part="$(printf 'part.%04d' "$i")"
            paths+=("ge-proton/$GE_PROTON_VERSION/$part")
            i=$((i + 1))
        done
        git -C "$repo" add -- "${paths[@]}"
        if git -C "$repo" diff --cached --quiet; then
            echo "GE-Proton chunks $first-$last already uploaded"
        else
            git -C "$repo" -c commit.gpgsign=false commit -q \
                -m "Sync GE-Proton $GE_PROTON_VERSION chunks $first-$last"
            push_main_with_retry "$repo" "GE-Proton chunks $first-$last/$GE_PROTON_CHUNKS"
        fi
        first=$((last + 1))
    done

    # 最后发布清单，避免客户端在所有分块上传完成前读到不完整版本。
    git -C "$repo" add -- ge-proton/latest.txt
    if git -C "$repo" diff --cached --quiet; then
        echo "GE-Proton manifest already published"
    else
        git -C "$repo" -c commit.gpgsign=false commit -q \
            -m "Publish GE-Proton $GE_PROTON_VERSION manifest"
        push_main_with_retry "$repo" "GE-Proton manifest"
    fi
    echo "Pushed GE-Proton $GE_PROTON_VERSION in resumable batches"
}

commit_and_push() {
    local repo="$1"

    git -C "$repo" config user.name "zhoukeer-toolbox[bot]"
    git -C "$repo" config user.email "bot@users.noreply.github.com"
    git -C "$repo" add -A
    if git -C "$repo" diff --cached --quiet; then
        echo "No changes in $(basename "$repo")"
    else
        git -C "$repo" -c commit.gpgsign=false commit -q -m "Sync Gitee mirror assets"
        git -C "$repo" push -q -u origin main
        echo "Pushed $(basename "$repo")"
    fi
}

if [ "$MODE" = "--only-ge-proton" ]; then
    sync_ge_proton
    commit_and_push_ge_proton_batches "$MIRROR8"
    exit 0
fi

# 小黄鸭汉化叠加固定 v0.12.8，镜像必须与Renkit内置版本一致，否则 SHA 校验会拒绝。
sync_plugin lsfg "xXJSONDeruloXx/decky-lsfg-vk" '^Decky[.]LSFG-VK[.]zip$' "Decky LSFG-VK" \
    "v0.12.8" "Decky.LSFG-VK.zip" \
    "https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.8/Decky.LSFG-VK.zip" \
    "322f6eec21a489ef9f12938ea2ec4e43c234093876f95b7245fbd260f882ce9c" "$MIRROR3"
# Renkit 安装只使用署名完整包；官方原包镜像仅保留给历史兼容流程。
sync_plugin lsfg-zh-signed "zliu9732-hub/decky-lsfg-vk-zh" \
    '^Decky[.]LSFG-VK-zh-signed-v0[.]12[.]8-r4[.]zip$' "Decky LSFG-VK 署名中文插件" \
    "v0.12.8" "Decky.LSFG-VK-zh-signed-v0.12.8-r4.zip" \
    "https://github.com/zliu9732-hub/decky-lsfg-vk-zh/releases/download/v0.12.8/Decky.LSFG-VK-zh-signed-v0.12.8-r4.zip" \
    "7f846c28bf5f9d08f6589a618c4e0c4ee4dffb05ad15938c39359c6460f1157b" "$MIRROR3"
# MAKO 跟随上游最新正式 Release，镜像与安装器共用 GitHub 提供的 SHA256。
sync_plugin lsfg-mako "eugeniosegala/MAKO" \
    '^MAKO-Decky-v[0-9.]+[.]zip$' "MAKO LSFG-VK" \
    "" "" "" "" "$MIRROR3"
# FSR4 汉化叠加固定 v0.17，镜像必须与Renkit内置版本一致，否则 SHA 校验会拒绝。
sync_plugin fsr4 "xXJSONDeruloXx/Decky-Framegen" '^Decky-Framegen[.]zip$' "Decky-Framegen" \
    "v0.17" "Decky-Framegen.zip" \
    "https://github.com/xXJSONDeruloXx/Decky-Framegen/releases/download/v0.17/Decky-Framegen.zip" \
    "3300b617e3d979b483d03f995c75c829d6d54beaa4ac8dfae300c2560e4fc60f"
sync_plugin fsr4-zh-signed "zliu9732-hub/decky-framegen-zh" \
    '^Decky-Framegen-zh-signed-v0[.]17-r3[.]zip$' "Decky-Framegen 署名中文插件" \
    "v0.17" "Decky-Framegen-zh-signed-v0.17-r3.zip" \
    "https://github.com/zliu9732-hub/decky-framegen-zh/releases/download/v0.17/Decky-Framegen-zh-signed-v0.17-r3.zip" \
    "409aa32b843500a6828b73feeed5cc7307d9c7c60a470e288f2c8cf777d03adb" "$MIRROR3"
sync_plugin cheatdeck "SheffeyG/CheatDeck" '^CheatDeck[.]zip$' "CheatDeck"
sync_plugin steamgriddb "SteamGridDB/decky-steamgriddb" '^$' "SteamGridDB" \
    "v1.7.1" "steamgriddb-v1.7.1.zip" \
    "https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3.zip" \
    "6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3"
sync_plugin cssloader "DeckThemes/SDH-CssLoader" '^$' "CSS Loader" \
    "v2.1.2" "cssloader-v2.1.2.zip" \
    "https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350.zip" \
    "1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350"
sync_plugin friendeck "panyiwei-home/Friendeck" '^Friendeck[.]v[.]0[.]7[.]7[.]zip$' "Friendeck" \
    "0.7.7" "Friendeck.v.0.7.7.zip" \
    "https://github.com/panyiwei-home/Friendeck/releases/download/0.7.7/Friendeck.v.0.7.7.zip" \
    "65465ff115e105912adf72b5461e17b697ac07100ce7061de2e962851e41c653"
sync_plugin deckymusic "jinzhongjia/decky-music" '^Decky[.]Music[.]full[.]zip$' "Decky Music 完整包" \
    "v1.0.2" "Decky.Music.full.zip" \
    "https://github.com/jinzhongjia/decky-music/releases/download/v1.0.2/Decky.Music.full.zip" \
    "37b79e28e54691f9c7e301aaa83823e20f6cffc8948d312b7398dcc87e466e11"
sync_plugin tomoon "YukiCoco/ToMoon" '^tomoon-v[0-9.]+[.]zip$' "ToMoon"
sync_plugin savepulse "Ren-Amamiya-pixle/SavePulse" '^SavePulse[.]zip$' "SavePulse" \
    "v0.2.0-alpha.1" "SavePulse.zip" \
    "https://github.com/Ren-Amamiya-pixle/SavePulse/releases/download/v0.2.0-alpha.1/SavePulse.zip" \
    "e0680fc3995b8bbb2971673db43d5e9459d8fa8e4a1b431a1f5d4edad19a35ad"
sync_plugin unifideck "mubaraknumann/unifideck" '^unifideck[.]prod[.]v[0-9.]+[.]zip$' "Unifideck"
sync_plugin freedeck "panyiwei-home/Freedeck" '^freedeck[.]v[0-9.]+[.]zip$' "Freedeck"
sync_plugin newfreedeck "panyiwei-home/Freedeck" \
    '^NewFreedeck[.]v[.][0-9]+[.][0-9]+([.][0-9]+)?[.]zip$' \
    "NewFreedeck" "" "" "" "" "$MIRROR3"
sync_plugin simpledeckytdp "aarron-lee/SimpleDeckyTDP" '^SimpleDeckyTDP[.]zip$' "SimpleDeckyTDP"
# HMCL 启动器固定版本，镜像必须与Renkit内置版本一致，否则 SHA 校验会拒绝。
sync_plugin hmcl "HMCL-dev/HMCL" '^HMCL-[0-9.]+[.]jar$' "HMCL" \
    "v3.16.3" "HMCL-3.16.3.jar" \
    "https://github.com/HMCL-dev/HMCL/releases/download/v3.16.3/HMCL-3.16.3.jar" \
    "5d02f4d04d9442116354ecfccf679910cca371d00a23cd5d6b16558c20a73dd3"
sync_plugin temurin21-jre "adoptium/temurin21-binaries" \
    '^OpenJDK21U-jre_x64_linux_hotspot_[0-9._]+[.]tar[.]gz$' "Temurin JRE 21" \
    "jdk-21.0.12+8" "OpenJDK21U-jre_x64_linux_hotspot_21.0.12_8.tar.gz" \
    "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12%2B8/OpenJDK21U-jre_x64_linux_hotspot_21.0.12_8.tar.gz" \
    "8a379a67c91a3ae61ffb33d46e0a40c7ba35e70713c4db31cfca30492f792eff"
sync_ge_proton

for repo in "$MIRROR8" "$MIRROR1" "$MIRROR2" "$MIRROR3"; do
    commit_and_push "$repo"
done
