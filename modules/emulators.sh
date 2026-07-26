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

emulator_details() {
    EMULATOR_CATEGORY="Game;Emulator;"
    EMULATOR_MIN_BYTES=20971520
    case "$1" in
        yuzu) EMULATOR_NAME="Yuzu（Switch 模拟器）"; EMULATOR_ASSET="yuzu.AppImage"; EMULATOR_FILE="Yuzu.AppImage"; EMULATOR_SHA256="6d44d52fc6ebd8f3b2e4707516cce535034285d4567302251bafd109c7972258" ;;
        cemu) EMULATOR_NAME="Cemu（Wii U 模拟器）"; EMULATOR_ASSET="Cemu.AppImage"; EMULATOR_FILE="Cemu.AppImage"; EMULATOR_SHA256="05ad07e3b2fb60f9c19f84c7d65c4e978bc2cf58b4b53d39fca0376227900c27" ;;
        duckstation) EMULATOR_NAME="DuckStation（PS1 模拟器）"; EMULATOR_ASSET="DuckStation.AppImage"; EMULATOR_FILE="DuckStation.AppImage"; EMULATOR_SHA256="9f213d799c886cde0ab98513b2b439a8d55ea996dba6accde7bb9ba8948c99f9" ;;
        pcsx2) EMULATOR_NAME="PCSX2（PS2 模拟器）"; EMULATOR_ASSET="pcsx2-Qt.AppImage"; EMULATOR_FILE="PCSX2.AppImage"; EMULATOR_SHA256="227c8f5a38bd0ae9c565b9350868b4f4bd27ae00cde0a598738c2bdd8ca97e88" ;;
        rpcs3) EMULATOR_NAME="RPCS3（PS3 模拟器）"; EMULATOR_ASSET="rpcs3.AppImage"; EMULATOR_FILE="RPCS3.AppImage"; EMULATOR_SHA256="2d258b557c17ebba4bea927be4032cfcbc230c26b8f090b796daa5935faa4a8b" ;;
        shadps4) EMULATOR_NAME="ShadPS4（PS4 模拟器）"; EMULATOR_ASSET="Shadps4-qt.AppImage"; EMULATOR_FILE="ShadPS4.AppImage"; EMULATOR_SHA256="17385fa479d2b810c3837e162e418c9d0f7c3c32018d3dfb2ef81e8defb611e2" ;;
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
Icon=$PROJECT_ROOT/assets/icon-round.png
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
        --name "$EMULATOR_NAME" --exe "$executable" --icon "$PROJECT_ROOT/assets/icon-round.png" >/dev/null || \
       ! python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
        --name "$EMULATOR_NAME" --exe "$executable" --icon "$PROJECT_ROOT/assets/icon-round.png" >/dev/null; then
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
        *) echo "用法: $0 {yuzu|cemu|duckstation|pcsx2|rpcs3|shadps4}"; exit 1 ;;
    esac
fi
