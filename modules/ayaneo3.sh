#!/bin/bash

AYANEO3_VERSION="1.2.0"
AYANEO3_DIRECTORY="Ayaneo3Companion"
AYANEO3_MIRROR_ID="ayaneo3-companion"
AYANEO3_MIRROR_REPO="zhoukeer-toolbox-mirror-4"
AYANEO3_PACKAGE_SHA256="b1c9a5529b3f5a4dee88ca275d285bb6347092a5f7e90db07b87b24725b4f651"

ayaneo3_is_supported_device() {
    local vendor model
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:lower:]' '[:upper:]')"
    model="$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:lower:]' '[:upper:]')"
    [ "$vendor" = AYANEO ] && [ "$model" = 'AYANEO 3' ]
}

ayaneo3_chinese_is_current() {
    python3 "$PROJECT_ROOT/scripts/localize_ayaneo3.py" check \
        "${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}/$AYANEO3_DIRECTORY" >/dev/null 2>&1
}

ensure_ayaneo3_chinese_current() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}" resource
    PLUGIN_INSTALL_CHANGED=0
    [ "$IS_STEAMOS" -eq 1 ] || { echo "AYANEO3 Companion 仅在 SteamOS 主线提供。"; return 1; }
    ayaneo3_is_supported_device || { echo "仅适用于 AYANEO3。"; return 1; }
    require_command python3 || return 1
    for resource in scripts/localize_ayaneo3.py scripts/framegen_package.py \
        data/ayaneo3_files.json data/ayaneo3_zh.json assets/ayaneo3/zh-runtime.js; do
        [ -s "$PROJECT_ROOT/$resource" ] && [ ! -L "$PROJECT_ROOT/$resource" ] || {
            echo "AYANEO3 中文组件不完整，请更新 Renkit 后重试。"
            return 1
        }
    done
    if ayaneo3_chinese_is_current; then
        echo "[已安装] AYANEO3 Companion v$AYANEO3_VERSION 中文版已完整安装。"
        return 0
    fi
    ensure_plugin_store_ready || return 1
    prepare_plugin_root "$plugin_root" || return 1
    echo "正在安装 AYANEO3 Companion v$AYANEO3_VERSION..."
    if (
        local tmp_dir
        tmp_dir="$(mktemp -d)" || return 1
        trap 'rm -rf -- "$tmp_dir"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        GITEE_MIRROR_REPO="$AYANEO3_MIRROR_REPO" download_gitee_mirror_file \
            "$AYANEO3_MIRROR_ID" "$tmp_dir/plugin.zip" "$AYANEO3_PACKAGE_SHA256" \
            "AYANEO3 Companion" || return 1
        python3 "$PROJECT_ROOT/scripts/localize_ayaneo3.py" prepare \
            "$tmp_dir/plugin" --archive "$tmp_dir/plugin.zip" > "$tmp_dir/check.log" 2>&1 || {
                log "AYANEO3 中文组件准备失败：$(cat "$tmp_dir/check.log")"
                return 1
            }
        install_tree_atomically "$tmp_dir/plugin" "$plugin_root" "$AYANEO3_DIRECTORY"
    ); then
        PLUGIN_INSTALL_CHANGED=1
        echo "AYANEO3 Companion v$AYANEO3_VERSION 中文版安装成功。"
        echo "汉化：RenAmamiya；原作者：Rayek；许可证：BSD-3-Clause。"
        return 0
    fi
    echo "AYANEO3 Companion 安装失败，现有插件已保留。"
    return 1
}
