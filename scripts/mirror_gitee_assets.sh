#!/bin/bash

# 生成 zhoukeer-toolbox 的 Gitee 分块镜像：从当前固定来源下载大文件，
# 超过 Gitee raw 匿名下载安全上限的文件拆成 8MiB 分块，并写入 latest.txt。
# 此脚本只读下载并写入 mirrors/，不会执行 SteamOS 系统操作。

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
load_config

MIRROR_ROOT="$PROJECT_ROOT/mirrors"
CACHE_ROOT="$PROJECT_ROOT/.mirror-cache"
CHUNK_BYTES="${ZHOUKEER_GITEE_MIRROR_CHUNK_BYTES:-8388608}"
DIRECT_MAX_BYTES="${ZHOUKEER_GITEE_MIRROR_DIRECT_MAX_BYTES:-9437184}"
CONNECT_TIMEOUT="${ZHOUKEER_MIRROR_CONNECT_TIMEOUT:-15}"
MAX_TIME="${ZHOUKEER_MIRROR_MAX_TIME:-1800}"
RETRIES="${ZHOUKEER_MIRROR_RETRIES:-3}"

mirror_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

mirror_md5() {
    local file="$1"
    if command -v md5sum >/dev/null 2>&1; then
        md5sum -- "$file" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$file" 2>/dev/null || md5 "$file" | awk '{print $NF}'
    else
        return 1
    fi
}

mirror_positive_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

mirror_path_is_safe() {
    case "$1" in
        ''|*'/'*|*'..'*|*'\\'*) return 1 ;;
        *) return 0 ;;
    esac
}

mirror_remote_size() {
    local url="$1"
    local size

    size="$(curl -sS -L -I --max-time 15 --proto '=https' --proto-redir '=https' \
        "$url" 2>/dev/null | \
        awk 'tolower($0) ~ /^content-length:/ { gsub(/[^0-9]/, "", $2); print $2 }' | \
        tail -n 1)"
    case "$size" in
        ''|*[!0-9]*) return 1 ;;
        *) printf '%s\n' "$size" ;;
    esac
}

mirror_verify_source_file() {
    local url="$1" file="$2" expected_sha256="$3" expected_md5="${4:-}"
    local actual_sha256 actual_md5

    if ! download_policy_response_is_safe "$url" "$file"; then
        echo "镜像来源响应格式异常：$url"
        return 1
    fi
    actual_sha256="$(mirror_sha256 "$file")" || return 1
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        echo "镜像来源 SHA256 校验失败：$url"
        return 1
    fi
    if [ -n "$expected_md5" ]; then
        actual_md5="$(mirror_md5 "$file")" || return 1
        if [ "$actual_md5" != "$expected_md5" ]; then
            echo "镜像来源 MD5 校验失败：$url"
            return 1
        fi
    fi
}

mirror_parallel_download_attempt() {
    local url="$1" output="$2" expected_sha256="$3" expected_md5="$4"
    local remote_size="$5" proxy="$6"
    local parts_dir part_file start end index prefix download_url
    local part_size expected_size actual_total part_count=8

    parts_dir="$(mktemp -d)" || return 1
    download_url="$url"
    if [ -n "$proxy" ]; then
        case "$proxy" in */) prefix="$proxy" ;; *) prefix="$proxy/" ;; esac
        download_url="${prefix}${url}"
    fi
    index=0
    while [ "$index" -lt "$part_count" ]; do
        start=$((index * (remote_size / part_count)))
        if [ "$index" -eq $((part_count - 1)) ]; then
            end=$((remote_size - 1))
        else
            end=$((start + (remote_size / part_count) - 1))
        fi
        expected_size=$((end - start + 1))
        part_file="$parts_dir/part.$index"
        (
            curl --fail --location --silent --proto '=https' --proto-redir '=https' \
                --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
                --retry "$RETRIES" --retry-delay 2 --retry-all-errors \
                --speed-limit 131072 --speed-time 30 \
                --range "$start-$end" --max-filesize "$expected_size" \
                --output "$part_file" "$download_url" >/dev/null 2>&1
        ) &
        index=$((index + 1))
    done
    wait

    actual_total=0
    index=0
    while [ "$index" -lt "$part_count" ]; do
        part_file="$parts_dir/part.$index"
        part_size="$(wc -c < "$part_file" 2>/dev/null | tr -d ' ')"
        case "$part_size" in ''|*[!0-9]*) return 1 ;; esac
        actual_total=$((actual_total + part_size))
        index=$((index + 1))
    done
    if [ "$actual_total" -ne "$remote_size" ]; then
        rm -rf -- "$parts_dir"
        return 1
    fi
    cat "$parts_dir"/part.* > "$output" 2>/dev/null || {
        rm -rf -- "$parts_dir"
        return 1
    }
    if ! mirror_verify_source_file "$url" "$output" "$expected_sha256" "$expected_md5"; then
        rm -rf -- "$parts_dir"
        return 1
    fi
    rm -rf -- "$parts_dir"
}

mirror_parallel_download_source() {
    local url="$1" output="$2" expected_sha256="$3" expected_md5="${4:-}"
    local remote_size="$5"
    local proxy_list="DIRECT" proxy

    case "$url" in
        https://github.com/*)
            proxy_list="DIRECT ${GITHUB_RELEASE_PROXY:-} ${GITHUB_MIRRORS:-}"
            ;;
    esac
    for proxy in $proxy_list; do
        if [ "$proxy" = "DIRECT" ]; then
            proxy=""
        fi
        if [ -n "$proxy" ] && \
            declare -F download_policy_github_mirror_allowed >/dev/null 2>&1 && \
            ! download_policy_github_mirror_allowed "$proxy"; then
            continue
        fi
        if mirror_parallel_download_attempt \
            "$url" "$output" "$expected_sha256" "$expected_md5" \
            "$remote_size" "$proxy"; then
            return 0
        fi
    done
    return 1
}

mirror_download_source() {
    local url="$1" output="$2" expected_sha256="$3" expected_md5="${4:-}"
    local remote_size

    download_policy_url_allowed "$url" || {
        echo "镜像来源不在白名单：$url"
        return 1
    }
    if remote_size="$(mirror_remote_size "$url" 2>/dev/null)" && \
        [ "$remote_size" -gt "$DIRECT_MAX_BYTES" ] && \
        mirror_parallel_download_source "$url" "$output" \
            "$expected_sha256" "$expected_md5" "$remote_size"; then
        echo "镜像来源并行下载完成：$url"
        return 0
    fi
    curl --fail --location --progress-meter \
        --proto '=https' --proto-redir '=https' \
        --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" \
        --retry "$RETRIES" --retry-delay 2 --retry-all-errors \
        --max-filesize "$(download_policy_max_bytes "$url")" \
        --output "$output" "$url" \
        2> >(download_progress_filter "镜像下载" >&2) || return 1
    mirror_verify_source_file "$url" "$output" "$expected_sha256" "$expected_md5" || {
        rm -f -- "$output"
        return 1
    }
}

mirror_split_file() {
    local source="$1" dest_dir="$2" chunk_size="$3" size="$4"
    local index offset part skip_blocks

    mirror_positive_integer "$chunk_size" || return 1
    mirror_positive_integer "$size" || return 1
    mkdir -p "$dest_dir" || return 1
    index=1
    offset=0
    while [ "$offset" -lt "$size" ]; do
        part="$(printf 'part.%04d' "$index")"
        skip_blocks=$((offset / chunk_size))
        dd if="$source" of="$dest_dir/$part" bs="$chunk_size" count=1 \
            skip="$skip_blocks" 2>/dev/null || return 1
        offset=$((offset + chunk_size))
        index=$((index + 1))
    done
}

mirror_write_manifest() {
    local id="$1" name="$2" version="$3" file="$4" source_url="$5"
    local sha256="$6" size="$7" chunks="$8" chunk_size="$9"
    local manifest="$MIRROR_ROOT/$id/latest.txt"

    mkdir -p "$MIRROR_ROOT/$id" || return 1
    {
        printf 'id=%s\n' "$id"
        printf 'name=%s\n' "$name"
        printf 'version=%s\n' "$version"
        printf 'file=%s\n' "$file"
        printf 'source_url=%s\n' "$source_url"
        printf 'sha256=%s\n' "$sha256"
        printf 'size=%s\n' "$size"
        printf 'chunks=%s\n' "$chunks"
        printf 'chunk_size=%s\n' "$chunk_size"
    } > "$manifest"
}

mirror_asset_is_current() {
    local id="$1" version="$2" file="$3" expected_sha256="$4" size="$5"
    local target="$MIRROR_ROOT/$id/$version/$file"
    local actual_size actual_sha256

    [ -f "$target" ] && [ ! -L "$target" ] || return 1
    actual_size="$(wc -c < "$target" | tr -d ' ')"
    [ "$actual_size" = "$size" ] || return 1
    actual_sha256="$(mirror_sha256 "$target")" || return 1
    [ "$actual_sha256" = "$expected_sha256" ] || return 1
}

mirror_output_is_current() {
    local id="$1" version="$2" file="$3" expected_sha256="$4" chunk_size="$5"
    local manifest="$MIRROR_ROOT/$id/latest.txt"
    local manifest_id manifest_version manifest_file manifest_sha manifest_size manifest_chunks
    local target_dir part part_size index total count

    [ -f "$manifest" ] || return 1
    while IFS= read -r line; do
        case "$line" in
            id=*) manifest_id="${line#id=}" ;;
            version=*) manifest_version="${line#version=}" ;;
            file=*) manifest_file="${line#file=}" ;;
            sha256=*) manifest_sha="${line#sha256=}" ;;
            size=*) manifest_size="${line#size=}" ;;
            chunks=*) manifest_chunks="${line#chunks=}" ;;
        esac
    done < "$manifest"
    [ "$manifest_id" = "$id" ] && [ "$manifest_version" = "$version" ] && \
        [ "$manifest_file" = "$file" ] && [ "$manifest_sha" = "$expected_sha256" ] || return 1
    mirror_positive_integer "$manifest_size" || return 1
    mirror_positive_integer "$manifest_chunks" || return 1

    target_dir="$MIRROR_ROOT/$id/$version"
    if [ "$manifest_chunks" = "0" ]; then
        mirror_asset_is_current "$id" "$version" "$file" \
            "$expected_sha256" "$manifest_size"
        return $?
    fi
    [ -d "$target_dir" ] || return 1
    count="$(find "$target_dir" -maxdepth 1 -type f -name 'part.*' | wc -l | tr -d ' ')"
    [ "$count" = "$manifest_chunks" ] || return 1
    total=0
    index=1
    while [ "$index" -le "$manifest_chunks" ]; do
        part="$(printf 'part.%04d' "$index")"
        part_size="$(wc -c < "$target_dir/$part" 2>/dev/null | tr -d ' ')"
        case "$part_size" in ''|*[!0-9]*) return 1 ;; esac
        [ "$part_size" -le "$chunk_size" ] || return 1
        total=$((total + part_size))
        index=$((index + 1))
    done
    [ "$total" = "$manifest_size" ] || return 1
}

mirror_process_entry() {
    local id="$1" name="$2" version="$3" file="$4" source_url="$5"
    local expected_sha256="$6" expected_md5="${7:-}"
    local size cache_file target_dir target
    local chunks=0
    local existing_size

    mirror_path_is_safe "$id" || return 1
    mirror_path_is_safe "$version" || return 1
    mirror_path_is_safe "$file" || return 1
    echo "正在处理镜像: $name ($version)"

    target_dir="$MIRROR_ROOT/$id/$version"
    target="$target_dir/$file"
    if mirror_output_is_current "$id" "$version" "$file" \
        "$expected_sha256" "$CHUNK_BYTES"; then
        echo "镜像已存在且校验通过：$id/$version/$file"
        size="$(sed -n 's/^size=//p' "$MIRROR_ROOT/$id/latest.txt")"
        chunks="$(sed -n 's/^chunks=//p' "$MIRROR_ROOT/$id/latest.txt")"
        mirror_write_manifest "$id" "$name" "$version" "$file" \
            "$source_url" "$expected_sha256" "$size" "$chunks" \
            "$([ "$chunks" -gt 0 ] && printf '%s' "$CHUNK_BYTES" || printf '0')" || return 1
        echo "镜像完成：$id -> $MIRROR_ROOT/$id/latest.txt"
        return 0
    fi

    if [ -z "${size:-}" ]; then
        mkdir -p "$CACHE_ROOT/$id" || return 1
        cache_file="$CACHE_ROOT/$id/$file"
        rm -f -- "$cache_file"
        mirror_download_source "$source_url" "$cache_file" \
            "$expected_sha256" "$expected_md5" || return 1
        size="$(wc -c < "$cache_file" | tr -d ' ')"
        mirror_positive_integer "$size" || return 1
        mkdir -p "$target_dir" || return 1
        if [ "$size" -le "$DIRECT_MAX_BYTES" ]; then
            cp -f -- "$cache_file" "$target" || return 1
        else
            rm -f -- "$target_dir"/part.*
            mirror_split_file "$cache_file" "$target_dir" \
                "$CHUNK_BYTES" "$size" || return 1
            chunks=$(( (size + CHUNK_BYTES - 1) / CHUNK_BYTES ))
        fi
        rm -f -- "$cache_file"
    fi

    mirror_write_manifest "$id" "$name" "$version" "$file" \
        "$source_url" "$expected_sha256" "$size" "$chunks" \
        "$([ "$chunks" -gt 0 ] && printf '%s' "$CHUNK_BYTES" || printf '0')" || return 1
    echo "镜像完成：$id -> $MIRROR_ROOT/$id/latest.txt"
}

mirror_process_local_file() {
    local id="$1" name="$2" version="$3" file="$4" source_url="$5" local_file="$6"
    local size sha256 target_dir target chunks=0

    mirror_path_is_safe "$id" || { echo "镜像标识不安全：$id"; return 1; }
    mirror_path_is_safe "$version" || { echo "镜像版本路径不安全：$version"; return 1; }
    mirror_path_is_safe "$file" || { echo "镜像文件名不安全：$file"; return 1; }
    [ -f "$local_file" ] && [ ! -L "$local_file" ] || {
        echo "本地安装包不存在：$local_file"
        return 1
    }
    size="$(wc -c < "$local_file" | tr -d ' ')"
    mirror_positive_integer "$size" || {
        echo "无法读取本地安装包大小：$local_file"
        return 1
    }
    [ "$size" -gt 0 ] || {
        echo "本地安装包为空：$local_file"
        return 1
    }
    if ! download_policy_response_is_safe "$source_url" "$local_file"; then
        echo "本地安装包格式或大小校验失败：$local_file"
        return 1
    fi
    sha256="$(mirror_sha256 "$local_file")" || return 1

    echo "正在处理本地镜像: $name ($version)"
    target_dir="$MIRROR_ROOT/$id/$version"
    target="$target_dir/$file"
    if mirror_output_is_current "$id" "$version" "$file" "$sha256" "$CHUNK_BYTES"; then
        size="$(sed -n 's/^size=//p' "$MIRROR_ROOT/$id/latest.txt")"
        chunks="$(sed -n 's/^chunks=//p' "$MIRROR_ROOT/$id/latest.txt")"
        mirror_write_manifest "$id" "$name" "$version" "$file" \
            "$source_url" "$sha256" "$size" "$chunks" \
            "$([ "$chunks" -gt 0 ] && printf '%s' "$CHUNK_BYTES" || printf '0')" || return 1
        echo "镜像已存在且校验通过：$id/$version/$file"
        return 0
    fi

    mkdir -p "$target_dir" || return 1
    rm -f -- "$target" "$target_dir"/part.*
    if [ "$size" -le "$DIRECT_MAX_BYTES" ]; then
        cp -f -- "$local_file" "$target" || return 1
    else
        mirror_split_file "$local_file" "$target_dir" "$CHUNK_BYTES" "$size" || return 1
        chunks=$(( (size + CHUNK_BYTES - 1) / CHUNK_BYTES ))
    fi
    mirror_write_manifest "$id" "$name" "$version" "$file" \
        "$source_url" "$sha256" "$size" "$chunks" \
        "$([ "$chunks" -gt 0 ] && printf '%s' "$CHUNK_BYTES" || printf '0')" || return 1
    echo "镜像完成：$id -> $MIRROR_ROOT/$id/latest.txt"
}

mirror_ge_proton_latest() {
    local version url sha256

    version="GE-Proton11-3"
    url="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-3/GE-Proton11-3.tar.gz"
    sha256="861c2edc8d40d051fb1e7a692deb953be52bd339c46d90f2b7dde50ddad91266"
    if resolve_latest_github_release "GloriousEggroll/proton-ge-custom" \
        '^GE-Proton[0-9]+-[0-9]+[.]tar[.]gz$' "GE-Proton" >/dev/null 2>&1; then
        version="$_LATEST_RELEASE_TAG"
        url="$_LATEST_RELEASE_URL"
        sha256="$_LATEST_RELEASE_SHA256"
    fi
    printf '%s|%s|%s\n' "$version" "$url" "$sha256"
}

mirror_entries() {
    cat <<'EOF'
decky-loader-stable|Decky Loader 稳定版|v3.2.6|PluginLoader|https://github.com/SteamDeckHomebrew/decky-loader/releases/download/v3.2.6/PluginLoader|30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e|
decky-loader-prerelease|Decky Loader 测试版|v3.2.8-pre1|PluginLoader|https://github.com/SteamDeckHomebrew/decky-loader/releases/download/v3.2.8-pre1/PluginLoader|9df160a81df3fc49c96e5665a1d1b3ba5c79de5bf271adc266d6bfedfda399d8|
decky-loader-service-stable|Decky Loader 稳定版服务模板|v3.2.6|plugin_loader-release.service|https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.6/dist/plugin_loader-release.service|64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1|
decky-loader-service-prerelease|Decky Loader 测试版服务模板|v3.2.8-pre1|plugin_loader-prerelease.service|https://raw.githubusercontent.com/SteamDeckHomebrew/decky-loader/v3.2.8-pre1/dist/plugin_loader-prerelease.service|f6fd73f68dca18a64e4cffa2962ae697b247aaf5f3fd9cd8526597f0291fb63e|
lsfg|Decky LSFG-VK|v0.12.5|Decky.LSFG-VK.zip|https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip|13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07|
fsr4|Decky-Framegen|v0.17|Decky-Framegen.zip|https://github.com/xXJSONDeruloXx/Decky-Framegen/releases/download/v0.17/Decky-Framegen.zip|3300b617e3d979b483d03f995c75c829d6d54beaa4ac8dfae300c2560e4fc60f|
cheatdeck|CheatDeck|v2.0.0|CheatDeck.zip|https://github.com/SheffeyG/CheatDeck/releases/download/v2.0.0/CheatDeck.zip|32e2931f9ca8083c1605f04b4ed089b0bf210f79db236a7fd34f02c519e902d9|
steamgriddb|SteamGridDB|v1.7.1|steamgriddb-v1.7.1.zip|https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3.zip|6d6eca184677dc9ff7736439ee7a575ca8ab386c5ffb1627d446bc43dbd1ecf3|
cssloader|CSS Loader|v2.1.2|cssloader-v2.1.2.zip|https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350.zip|1a1e8f4dded8494febe56df16429ef5bba1e5b8feb3fd989d5808fbef0d71350|
friendeck|Friendeck|0.7.7|Friendeck.v.0.7.7.zip|https://github.com/panyiwei-home/Friendeck/releases/download/0.7.7/Friendeck.v.0.7.7.zip|65465ff115e105912adf72b5461e17b697ac07100ce7061de2e962851e41c653|
deckymusic|Decky Music|v1.0.0|Decky.Music.zip|https://github.com/jinzhongjia/decky-music/releases/download/v1.0.0/Decky.Music.zip|ec2956bbee1d84b25b7f8749f06794b54014828a04707beccd06feb5d49dfa53|
tomoon|ToMoon|v0.2.8|tomoon-v0.2.8.zip|https://github.com/YukiCoco/ToMoon/releases/download/v0.2.8/tomoon-v0.2.8.zip|5500e6ed2d110b0e077b9eba3f1908eb50593483e51158b9351978d9a03191a6|
deckrecall|DeckRecall|v0.4.2|DeckRecall.zip|https://github.com/Ren-Amamiya-pixle/DeckRecall/releases/download/v0.4.2/DeckRecall.zip|38cbbaa94f39bbe7231f490fd3826f1347ce8c0acb53aa69c784d8511cc058fd|
savepulse|SavePulse|v0.2.0-alpha.1|SavePulse.zip|https://github.com/Ren-Amamiya-pixle/SavePulse/releases/download/v0.2.0-alpha.1/SavePulse.zip|e0680fc3995b8bbb2971673db43d5e9459d8fa8e4a1b431a1f5d4edad19a35ad|
unifideck|Unifideck|Release-0.7.2|unifideck.prod.v0.7.2.zip|https://github.com/mubaraknumann/unifideck/releases/download/Release-0.7.2/unifideck.prod.v0.7.2.zip|a313be924cabe15255d222742a402cd98cb510a35dfe4b2d06cf1e59366936de|
freedeck|Freedeck|0.6|freedeck.v.0.6.zip|https://github.com/panyiwei-home/Freedeck/releases/download/0.6/freedeck.v.0.6.zip|04329d07761c42cc481e97ddd4fc180fa51eb1d0388761424a8c90a18a822c62|
allycenter|Ally Center|v1.2.0|allycenter-v1.2.0.zip|https://github.com/PixelAddictUnlocked/allycenter/releases/download/v1.2.0/allycenter-v1.2.0.zip|a1059534de2a0e9556669adff3d933bcde802101faae7558f9b33db3a8e51bc7|
huesync|HueSync|v3.9.0|huesync.zip|https://github.com/honjow/HueSync/releases/download/v3.9.0/huesync.zip|7510c96ed22278a914a3aae591c2393ff4e25812a765d1d633f77baa8a593e1f|
legiongo-remapper|LegionGoRemapper|v0.3.0|LegionGoRemapper.tar.gz|https://github.com/aarron-lee/LegionGoRemapper/releases/download/v0.3.0/LegionGoRemapper.tar.gz|b89084ece2df8854a732239043484f510a2384d01221441e3a4242fc85b6d9e1|
gpd-control|GpdControl|v0.0.2|GpdControl.tar.gz|https://github.com/aarron-lee/GpdControl/releases/download/v0.0.2/GpdControl.tar.gz|3efc5694234fb7f2ae1131fd9dec9e342c1fee7c4a804e4f910920d327ae7fb4|
lego-vibe|LeGo-Vibe-Control|1.5.0|LeGo-Vibe-Control-1.5.0.zip|https://github.com/Rayekkk/LeGo-Vibe-Control/releases/download/1.5.0/LeGo-Vibe-Control-1.5.0.zip|adda3be351c14d1c8899fb0997565aa67e7439b988112340fad707cfe6be28b7|
lego2-fan|LeGo2-Fan-Control|Decky|LeGo2FanControl_Decky.zip|https://github.com/Rodpad/LeGo2-Fan-Control/releases/download/Decky/LeGo2FanControl_Decky.zip|a46af0c53eef63b1ad77fff567a120784b6736686565a761524882d011cc6d3e|
onexplayer-apex|OneXPlayer Apex Tools|build-b696161|OneXPlayer_Apex_Tools.zip|https://github.com/srsholmes/onexplayer-apex-bazzite-fixes/releases/download/build-b696161/OneXPlayer_Apex_Tools.zip|7c522bc8145697d78d6165f7f97671d4d67a5bf4f9e4ed5e6feccbb1154acb91|
simpledeckytdp|SimpleDeckyTDP|v1.0.5|SimpleDeckyTDP.zip|https://github.com/aarron-lee/SimpleDeckyTDP/releases/download/v1.0.5/SimpleDeckyTDP.zip|ebf1c68147b6300ee17c2d7ea00a9cfe9ac1c78af78d364d9d306ac64a2cc057|
todesk|ToDesk 官方安装包|v6.0.25|todesk-v4.8.6.2-amd64.deb|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/v6.0.25/todesk-v4.8.6.2-amd64.deb|b3f2af7fc120948903df3aa455955cb5823fb5c1f5ec7dca17ac8a4cba53c808|
steam302|Steamcommunity 302|14.0.02|steamcommunity_302_Linux_AMD64_V14.0.02.tar.gz|https://www.dogfight360.com/blog/wp-content/uploads/2026/02/steamcommunity_302_Linux_AMD64_V14.0.02.tar.gz|5e006f015c807679ef800a87fa7b788562901ad04d7899ade2648f82b4c4a11f|4b9994102b2256ca5fdf2e806a2c7035|
clover|Clover 双系统引导资源|v1.0.0|Clover.tar.gz|https://gitee.com/easylife2025/emu/releases/download/v1.0.0/Clover.tar.gz|10782cebdf1e4130c9b759435c520b4e9452b03a9b10d5f3fff7d2125e99837d|
ge-proton|GE-Proton|GE-Proton11-3|GE-Proton11-3.tar.gz|https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-3/GE-Proton11-3.tar.gz|861c2edc8d40d051fb1e7a692deb953be52bd339c46d90f2b7dde50ddad91266|
yuzu|Yuzu（Switch 模拟器）|emulator-assets-v1|yuzu.AppImage|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/yuzu.AppImage|6d44d52fc6ebd8f3b2e4707516cce535034285d4567302251bafd109c7972258|
cemu|Cemu（Wii U 模拟器）|emulator-assets-v1|Cemu.AppImage|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/Cemu.AppImage|05ad07e3b2fb60f9c19f84c7d65c4e978bc2cf58b4b53d39fca0376227900c27|
duckstation|DuckStation（PS1 模拟器）|emulator-assets-v1|DuckStation.AppImage|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/DuckStation.AppImage|9f213d799c886cde0ab98513b2b439a8d55ea996dba6accde7bb9ba8948c99f9|
pcsx2|PCSX2（PS2 模拟器）|emulator-assets-v1|pcsx2-Qt.AppImage|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/pcsx2-Qt.AppImage|227c8f5a38bd0ae9c565b9350868b4f4bd27ae00cde0a598738c2bdd8ca97e88|
rpcs3|RPCS3（PS3 模拟器）|emulator-assets-v1|rpcs3.AppImage|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/rpcs3.AppImage|2d258b557c17ebba4bea927be4032cfcbc230c26b8f090b796daa5935faa4a8b|
shadps4|ShadPS4（PS4 模拟器）|emulator-assets-v1|Shadps4-qt.AppImage|https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/emulator-assets-v1/Shadps4-qt.AppImage|17385fa479d2b810c3837e162e418c9d0f7c3c32018d3dfb2ef81e8defb611e2|
EOF
}

mirror_main() {
    local only_id="${1:-}" entry
    local ge_latest ge_version ge_url ge_sha256

    mkdir -p "$MIRROR_ROOT" "$CACHE_ROOT" || return 1
    if [ "$only_id" = "ge-proton" ]; then
        ge_latest="$(mirror_ge_proton_latest)" || return 1
        ge_version="${ge_latest%%|*}"
        ge_url="$(printf '%s' "$ge_latest" | cut -d'|' -f2)"
        ge_sha256="$(printf '%s' "$ge_latest" | cut -d'|' -f3)"
        mirror_process_entry ge-proton "GE-Proton" "$ge_version" \
            "${ge_version}.tar.gz" "$ge_url" "$ge_sha256" || return 1
        return 0
    fi

    while IFS='|' read -r id name version file url sha256 md5; do
        [ -n "$id" ] || continue
        if [ -n "$only_id" ] && [ "$id" != "$only_id" ]; then
            continue
        fi
        mirror_process_entry "$id" "$name" "$version" "$file" \
            "$url" "$sha256" "$md5" || return 1
    done < <(mirror_entries)
}

case "${1:-}" in
    --local)
        shift
        if [ "$#" -ne 6 ]; then
            echo "用法: bash scripts/mirror_gitee_assets.sh --local <id> <name> <version> <file> <source_url> <local_file>"
            exit 1
        fi
        mirror_process_local_file "$@"
        ;;
    --only)
        mirror_main "${2:-}"
        ;;
    -h|--help)
        echo "用法: bash scripts/mirror_gitee_assets.sh [--only <id>]"
        echo "      bash scripts/mirror_gitee_assets.sh --local <id> <name> <version> <file> <source_url> <local_file>"
        ;;
    *)
        mirror_main ""
        ;;
esac
