#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
PLUGIN_ROOT="$TMP_ROOT/plugins"
mkdir -p "$PLUGIN_ROOT"

DECKY_PLUGIN_DIR="$PLUGIN_ROOT" PROJECT_ROOT="$PROJECT_ROOT" bash -c '
    set -euo pipefail
    source "$PROJECT_ROOT/modules/plugin_store.sh"

    make_plugin() {
        local directory="$1" name="$2" version="$3"
        mkdir -p "$DECKY_PLUGIN_DIR/$directory/dist"
        printf '\''{\n  "name": "%s",\n  "author": "upstream"\n}\n'\'' "$name" > \
            "$DECKY_PLUGIN_DIR/$directory/plugin.json"
        printf '\''{"version": "%s", "sentinel": "unchanged"}\n'\'' "$version" > \
            "$DECKY_PLUGIN_DIR/$directory/package.json"
        printf '\''official frontend\n'\'' > "$DECKY_PLUGIN_DIR/$directory/dist/index.js"
        printf '\''official backend\n'\'' > "$DECKY_PLUGIN_DIR/$directory/main.py"
    }

    for entry in \
        "decky-steamgriddb|SteamGridDB|1.7.1|游戏封面更换" \
        "Friendeck-plugin|Friendeck|0.7.5|文件传输助手" \
        "Decky Music|Decky Music|1.0.0|音乐播放器"; do
        directory="${entry%%|*}"
        rest="${entry#*|}"
        official="${rest%%|*}"
        rest="${rest#*|}"
        version="${rest%%|*}"
        localized="${rest##*|}"
        make_plugin "$directory" "$official" "$version"
        backend_hash="$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$directory/main.py")"
        package_hash="$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$directory/package.json")"
        frontend_hash="$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$directory/dist/index.js")"
        rename_decky_plugin_display_name "$directory" "$official" "$localized"
        grep -Fq "\"name\": \"$localized\"" "$DECKY_PLUGIN_DIR/$directory/plugin.json"
        [ "$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$directory/main.py")" = "$backend_hash" ]
        [ "$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$directory/package.json")" = "$package_hash" ]
        [ "$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$directory/dist/index.js")" = "$frontend_hash" ]
    done

    make_plugin "$CSSLOADER_OFFICIAL_DIRECTORY" "CSS Loader" "$CSSLOADER_OFFICIAL_VERSION"
    css_backend_hash="$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$CSSLOADER_OFFICIAL_DIRECTORY/main.py")"
    css_package_hash="$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$CSSLOADER_OFFICIAL_DIRECTORY/package.json")"
    ensure_cssloader_chinese_current
    grep -Fq '\''"name": "主题美化"'\'' "$DECKY_PLUGIN_DIR/$CSSLOADER_OFFICIAL_DIRECTORY/plugin.json"
    [ "$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$CSSLOADER_OFFICIAL_DIRECTORY/dist/index.js")" = \
        "$CSSLOADER_ZH_INDEX_SHA256" ]
    [ "$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$CSSLOADER_OFFICIAL_DIRECTORY/main.py")" = \
        "$css_backend_hash" ]
    [ "$(calculate_decky_sha256 "$DECKY_PLUGIN_DIR/$CSSLOADER_OFFICIAL_DIRECTORY/package.json")" = \
        "$css_package_hash" ]
'

grep -Fq 'DECKY_FRIENDECK_SHA256="65465ff115e105912adf72b5461e17b697ac07100ce7061de2e962851e41c653"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_DECKYMUSIC_SHA256="ec2956bbee1d84b25b7f8749f06794b54014828a04707beccd06feb5d49dfa53"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'CSSLOADER_ZH_INDEX_SHA256="38ec628efcc1238247e0cf771bde98b26be49349dca9c2d7de4270ad242a2567"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"

echo "PASS: 四款常用插件名称、CSS Loader 中文前端和官方后端不变校验通过"
