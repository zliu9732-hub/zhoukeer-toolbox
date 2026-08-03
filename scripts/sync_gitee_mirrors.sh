#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/core/env.sh"
load_config

OWNER="zliu9732-hub"
TOKEN="${GITEE_TOKEN:-}"
[ -n "$TOKEN" ] || {
    echo "GITEE_TOKEN secret is missing"
    exit 1
}

BASE="https://${OWNER}:${TOKEN}@gitee.com/${OWNER}"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
MIRROR1="$WORK/mirror1"
MIRROR2="$WORK/mirror2"
git clone -q "$BASE/zhoukeer-toolbox-mirror.git" "$MIRROR1"
git clone -q "$BASE/zhoukeer-toolbox-mirror-2.git" "$MIRROR2"

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
    target_dir="$MIRROR1/$id/$version"
    mkdir -p "$target_dir"
    rm -f -- "$MIRROR1/$id/$version"/*

    if [ "$size" -le 9437184 ]; then
        cp -- "$WORK/$file" "$target_dir/$file"
        chunks=0
    else
        split -b 8388608 --numeric-suffixes=1 -a 4 \
            "$WORK/$file" "$target_dir/part."
        chunks="$(find "$target_dir" -maxdepth 1 -name 'part.*' | wc -l | tr -d ' ')"
    fi
    write_manifest "$MIRROR1" "$id" "$name" "$version" "$file" \
        "$url" "$sha" "$size" "$chunks" 8388608
    echo "Synced $id $version"
}

sync_ge_proton() {
    local version file url sha size chunks target1 target2 i part

    if ! resolve_latest_github_release "GloriousEggroll/proton-ge-custom" \
        '^GE-Proton[0-9]+-[0-9]+[.]tar[.]gz$' "GE-Proton"; then
        echo "Skip GE-Proton: latest release lookup failed"
        return 0
    fi
    version="$_LATEST_RELEASE_TAG"
    file="$_LATEST_RELEASE_ASSET"
    url="$_LATEST_RELEASE_URL"
    sha="$_LATEST_RELEASE_SHA256"

    curl -fsSL --proto '=https' --proto-redir '=https' \
        --connect-timeout 15 --max-time 1800 -o "$WORK/$file" "$url"
    [ "$(sha_of "$WORK/$file")" = "$sha" ] || {
        echo "GE-Proton SHA256 mismatch"
        exit 1
    }
    size="$(wc -c < "$WORK/$file" | tr -d ' ')"
    chunks=$(( (size + 8388607) / 8388608 ))
    target1="$MIRROR1/ge-proton/$version"
    target2="$MIRROR2/ge-proton/$version"
    mkdir -p "$target1" "$target2"
    rm -f -- "$MIRROR1/ge-proton"/*/part.* "$MIRROR2/ge-proton"/*/part.*

    split -b 8388608 --numeric-suffixes=1 -a 4 \
        "$WORK/$file" "$WORK/ge-proton.part."
    i=1
    while [ "$i" -le 8 ]; do
        part="$(printf 'part.%04d' "$i")"
        cp -- "$WORK/ge-proton.$part" "$target1/$part"
        i=$((i + 1))
    done
    while [ "$i" -le "$chunks" ]; do
        part="$(printf 'part.%04d' "$i")"
        cp -- "$WORK/ge-proton.$part" "$target2/$part"
        i=$((i + 1))
    done

    write_manifest "$MIRROR1" "ge-proton" "GE-Proton" "$version" "$file" \
        "$url" "$sha" "$size" "$chunks" 8388608 \
        "zhoukeer-toolbox-mirror" "zhoukeer-toolbox-mirror-2" 8
    echo "Synced GE-Proton $version"
}

# 小黄鸭汉化叠加固定 v0.12.5，镜像必须与工具箱内置版本一致，否则 SHA 校验会拒绝。
sync_plugin lsfg "xXJSONDeruloXx/decky-lsfg-vk" '^Decky[.]LSFG-VK[.]zip$' "Decky LSFG-VK" \
    "v0.12.5" "Decky.LSFG-VK.zip" \
    "https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip" \
    "13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"
# FSR4 汉化叠加固定 v0.15.6，镜像必须与工具箱内置版本一致，否则 SHA 校验会拒绝。
sync_plugin fsr4 "xXJSONDeruloXx/Decky-Framegen" '^Decky-Framegen[.]zip$' "Decky-Framegen" \
    "v0.15.6" "Decky-Framegen.zip" \
    "https://github.com/xXJSONDeruloXx/Decky-Framegen/releases/download/v0.15.6/Decky-Framegen.zip" \
    "236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"
sync_plugin cheatdeck "SheffeyG/CheatDeck" '^CheatDeck[.]zip$' "CheatDeck"
sync_plugin tomoon "YukiCoco/ToMoon" '^tomoon-v[0-9.]+[.]zip$' "ToMoon"
sync_plugin unifideck "mubaraknumann/unifideck" '^unifideck[.]prod[.]v[0-9.]+[.]zip$' "Unifideck"
sync_plugin freedeck "panyiwei-home/Freedeck" '^freedeck[.]v[0-9.]+[.]zip$' "Freedeck"
sync_plugin simpledeckytdp "aarron-lee/SimpleDeckyTDP" '^SimpleDeckyTDP[.]zip$' "SimpleDeckyTDP"
sync_ge_proton

for repo in "$MIRROR1" "$MIRROR2"; do
    git -C "$repo" config user.name "zhoukeer-toolbox[bot]"
    git -C "$repo" config user.email "bot@users.noreply.github.com"
    git -C "$repo" add -A
    if git -C "$repo" diff --cached --quiet; then
        echo "No changes in $(basename "$repo")"
    else
        git -C "$repo" commit -q -m "Sync Gitee mirror assets"
        git -C "$repo" push -q origin main
        echo "Pushed $(basename "$repo")"
    fi
done
