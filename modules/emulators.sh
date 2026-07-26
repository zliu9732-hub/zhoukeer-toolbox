#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# Reuse the mature Steam userdata detection, safe Steam shutdown/restart and VDF writer path.
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/game_launchers.sh"

EMULATOR_RELEASE_REPO="zliu9732-hub/zhoukeer-toolbox"
EMULATOR_RELEASE_TAG="emulator-assets-v1"
EMULATOR_ROOT="${ZHOUKEER_EMULATOR_DIR:-$APP_DIR/emulators}"
YUZU_KEYS_DIR="${ZHOUKEER_YUZU_KEYS_DIR:-$HOME/.local/share/yuzu/keys}"
YUZU_KEY_IMPORT_DIR="${ZHOUKEER_YUZU_KEY_IMPORT_DIR:-$HOME/Desktop/Yuzu密钥}"
YUZU_KEY_MAX_BYTES=1048576

emulator_details() {
    EMULATOR_CATEGORY="Game;Emulator;"
    EMULATOR_MIN_BYTES=20971520
    case "$1" in
        yuzu) EMULATOR_NAME="Yuzu（Switch 模拟器）"; EMULATOR_ASSET="yuzu.AppImage"; EMULATOR_FILE="Yuzu.AppImage"; EMULATOR_ICON="$PROJECT_ROOT/assets/emulators/yuzu.png"; EMULATOR_SHA256="6d44d52fc6ebd8f3b2e4707516cce535034285d4567302251bafd109c7972258" ;;
        cemu) EMULATOR_NAME="Cemu（Wii U 模拟器）"; EMULATOR_ASSET="Cemu.AppImage"; EMULATOR_FILE="Cemu.AppImage"; EMULATOR_ICON="$PROJECT_ROOT/assets/emulators/cemu.png"; EMULATOR_SHA256="05ad07e3b2fb60f9c19f84c7d65c4e978bc2cf58b4b53d39fca0376227900c27" ;;
        duckstation) EMULATOR_NAME="DuckStation（PS1 模拟器）"; EMULATOR_ASSET="DuckStation.AppImage"; EMULATOR_FILE="DuckStation.AppImage"; EMULATOR_ICON="$PROJECT_ROOT/assets/emulators/duckstation.png"; EMULATOR_SHA256="9f213d799c886cde0ab98513b2b439a8d55ea996dba6accde7bb9ba8948c99f9" ;;
        pcsx2) EMULATOR_NAME="PCSX2（PS2 模拟器）"; EMULATOR_ASSET="pcsx2-Qt.AppImage"; EMULATOR_FILE="PCSX2.AppImage"; EMULATOR_ICON="$PROJECT_ROOT/assets/emulators/pcsx2.png"; EMULATOR_SHA256="227c8f5a38bd0ae9c565b9350868b4f4bd27ae00cde0a598738c2bdd8ca97e88" ;;
        rpcs3) EMULATOR_NAME="RPCS3（PS3 模拟器）"; EMULATOR_ASSET="rpcs3.AppImage"; EMULATOR_FILE="RPCS3.AppImage"; EMULATOR_ICON="$PROJECT_ROOT/assets/emulators/rpcs3.png"; EMULATOR_SHA256="2d258b557c17ebba4bea927be4032cfcbc230c26b8f090b796daa5935faa4a8b" ;;
        shadps4) EMULATOR_NAME="ShadPS4（PS4 模拟器）"; EMULATOR_ASSET="Shadps4-qt.AppImage"; EMULATOR_FILE="ShadPS4.AppImage"; EMULATOR_ICON="$PROJECT_ROOT/assets/emulators/shadps4.png"; EMULATOR_SHA256="17385fa479d2b810c3837e162e418c9d0f7c3c32018d3dfb2ef81e8defb611e2" ;;
        *) echo "未知模拟器：$1"; return 1 ;;
    esac
}

emulator_file_is_valid() {
    local file="$1" size magic actual_sha256
    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    size="$(wc -c < "$file" | tr -d ' ')"
    magic="$(od -An -tx1 -N4 "$file" | tr -d ' \n')"
    [ "${size:-0}" -ge "$EMULATOR_MIN_BYTES" ] && [ "$magic" = "7f454c46" ] || return 1
    actual_sha256="$(_github_sha256 "$file")" || return 1
    [ "$actual_sha256" = "$EMULATOR_SHA256" ]
}

yuzu_key_file_is_valid() {
    local file="$1" size

    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    size="$(wc -c < "$file" | tr -d ' ')"
    [ "${size:-0}" -gt 0 ] && [ "$size" -le "$YUZU_KEY_MAX_BYTES" ] || return 1
    LC_ALL=C grep -Eq '^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*[0-9A-Fa-f]{32,64}[[:space:]]*$' "$file"
}

copy_yuzu_key_file() {
    local source="$1" target_name="$2" temporary

    temporary="$YUZU_KEYS_DIR/.${target_name}.new.$$"
    umask 077
    cp -- "$source" "$temporary" || return 1
    chmod 600 "$temporary" || { rm -f -- "$temporary"; return 1; }
    mv -f -- "$temporary" "$YUZU_KEYS_DIR/$target_name"
}

confirm_yuzu_key_import() {
    local answer

    echo "仅可导入你本人从合法拥有的设备备份的 Yuzu 密钥。"
    echo "工具箱不会下载、生成、分享或显示密钥内容。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认导入自己的密钥请输入 IMPORT：" answer
    [ "$answer" = "IMPORT" ]
}

import_yuzu_keys() {
    local prod_source="$YUZU_KEY_IMPORT_DIR/prod.keys"
    local title_source="$YUZU_KEY_IMPORT_DIR/title.keys"

    require_steamos || return 1
    confirm_yuzu_key_import || { echo "已取消导入密钥。"; return 1; }
    if ! yuzu_key_file_is_valid "$prod_source"; then
        echo "未找到有效的 prod.keys。请把本人备份的 prod.keys 放到：$YUZU_KEY_IMPORT_DIR"
        return 1
    fi

    if [ -e "$title_source" ] && ! yuzu_key_file_is_valid "$title_source"; then
        echo "title.keys 格式无效或不是普通文件，已保留原有密钥。"
        return 1
    fi

    mkdir -p "$YUZU_KEYS_DIR" || return 1
    chmod 700 "$YUZU_KEYS_DIR" || return 1
    copy_yuzu_key_file "$prod_source" "prod.keys" || { echo "导入 prod.keys 失败。"; return 1; }

    if [ -e "$title_source" ]; then
        copy_yuzu_key_file "$title_source" "title.keys" || { echo "导入 title.keys 失败。"; return 1; }
    fi

    log "Yuzu 用户自备密钥已导入"
    echo "Yuzu 密钥已安全导入。密钥内容不会显示或写入日志。"
}

show_yuzu_key_status() {
    require_steamos || return 1
    if yuzu_key_file_is_valid "$YUZU_KEYS_DIR/prod.keys"; then
        echo "Yuzu prod.keys：已就绪"
    else
        echo "Yuzu prod.keys：未导入或格式无效"
    fi
    if [ -e "$YUZU_KEYS_DIR/title.keys" ]; then
        if yuzu_key_file_is_valid "$YUZU_KEYS_DIR/title.keys"; then
            echo "Yuzu title.keys：已就绪"
        else
            echo "Yuzu title.keys：格式无效"
        fi
    else
        echo "Yuzu title.keys：未导入（可选）"
    fi
}

create_emulator_desktop_shortcut() {
    local executable="$1" desktop_dir="$HOME/Desktop" applications_dir="$HOME/.local/share/applications"
    local desktop_file="$desktop_dir/$EMULATOR_NAME.desktop" application_file="$applications_dir/$EMULATOR_FILE.desktop"
    mkdir -p "$desktop_dir" "$applications_dir" || return 1
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=$EMULATOR_NAME
Comment=由周克儿工具箱安装
Exec="$executable"
Icon=$EMULATOR_ICON
Terminal=false
Categories=$EMULATOR_CATEGORY
X-Zhoukeer-Managed=true
EOF
    cp "$desktop_file" "$application_file" || return 1
    chmod +x "$desktop_file" "$application_file" || return 1
}

add_emulator_to_steam() {
    local executable="$1" steam_root shortcut_file
    require_command python3 || return 1
    steam_root="$(find_steam_root)" || return 1
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    stop_steam_for_vdf || return 1
    if ! python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$EMULATOR_NAME" --exe "$executable" --start-dir "$(dirname "$executable")" >/dev/null; then
        start_steam
        return 1
    fi
    if ! python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$EMULATOR_NAME" --exe "$executable" --icon "$EMULATOR_ICON" >/dev/null || \
       ! python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
        --name "$EMULATOR_NAME" --exe "$executable" --icon "$EMULATOR_ICON" >/dev/null; then
        start_steam
        return 1
    fi
    start_steam
}

install_emulator() {
    local target temporary
    require_steamos || return 1
    require_command od || return 1
    require_command python3 || return 1
    emulator_details "$1" || return 1
    [ -f "$EMULATOR_ICON" ] || { echo "缺少 $EMULATOR_NAME 的专用图标。"; return 1; }
    mkdir -p "$EMULATOR_ROOT" || return 1
    target="$EMULATOR_ROOT/$EMULATOR_FILE"
    if ! emulator_file_is_valid "$target"; then
        temporary="$target.new.$$"
        echo "正在下载并校验 $EMULATOR_NAME…"
        download_github_release "$EMULATOR_RELEASE_REPO" "$EMULATOR_RELEASE_TAG" "$EMULATOR_ASSET" \
            "$temporary" "$EMULATOR_SHA256" "$EMULATOR_NAME" || return 1
        emulator_file_is_valid "$temporary" || { rm -f -- "$temporary"; echo "模拟器文件格式或大小异常。"; return 1; }
        mv -f -- "$temporary" "$target" || return 1
    fi
    chmod 755 "$target" || return 1
    create_emulator_desktop_shortcut "$target" || return 1
    if ! add_emulator_to_steam "$target"; then
        echo "$EMULATOR_NAME 已安装并创建桌面入口，但未能安全写入 Steam 库；请先完整登录 Steam 后重试。"
        return 1
    fi
    log "模拟器安装完成：$EMULATOR_NAME"
    echo "$EMULATOR_NAME 已安装，桌面图标和 Steam 库条目已创建。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4) install_emulator "$1" ;;
        yuzu-keys) import_yuzu_keys ;;
        yuzu-keys-status) show_yuzu_key_status ;;
        *) echo "用法: $0 {yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4|yuzu-keys|yuzu-keys-status}"; exit 1 ;;
    esac
fi
