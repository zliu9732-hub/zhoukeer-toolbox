#!/bin/bash

# Epic 官方 Linux 预览版；不修改 Windows 客户端或用户的游戏目录。
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/game_launchers.sh"
source "$PROJECT_ROOT/core/desktop_paths.sh"

EPIC_LINUX_NAME="Epic Games（Linux 版）"
EPIC_LINUX_VERSION="0.96.0+g2fade97"
EPIC_LINUX_URL="https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/0.96.0%2Bg2fade97/Linux/EpicGamesLauncher-x86_64.AppImage"
EPIC_LINUX_SHA256="6c5cc46eef8c80b01759cc76154b69a20645b01b79526442a8550090db5d251e"
EPIC_LINUX_BYTES=181185016
EPIC_LINUX_DIR="$APP_DIR/game-launchers/epic-linux"

epic_linux_file_valid() {
    python3 - "$1" "$EPIC_LINUX_SHA256" "$EPIC_LINUX_BYTES" <<'PY'
import hashlib
import sys
from pathlib import Path

p = Path(sys.argv[1])
if p.is_symlink() or not p.is_file() or p.stat().st_size != int(sys.argv[3]):
    raise SystemExit(1)
with p.open('rb') as f:
    header = f.read(24)
    # 只接受 x86-64、小端 ELF64、AppImage type 2；不执行下载的程序来检查它。
    if header[:6] != b'\x7fELF\x02\x01' or header[8:11] != b'AI\x02' or header[18:20] != b'\x3e\x00':
        raise SystemExit(1)
    f.seek(0)
    digest = hashlib.sha256()
    for block in iter(lambda: f.read(1048576), b''):
        digest.update(block)
if digest.hexdigest() != sys.argv[2]:
    raise SystemExit(1)
PY
}

epic_linux_paths_safe() {
    local path
    for path in "$APP_DIR" "$APP_DIR/game-launchers" "$EPIC_LINUX_DIR"; do
        if [ -L "$path" ] || { [ -e "$path" ] && [ ! -d "$path" ]; }; then
            echo "Epic Linux 版的安装位置不可用，已停止。"
            return 1
        fi
    done
    for path in "$EPIC_LINUX_DIR/EpicGamesLauncher.AppImage" \
        "$EPIC_LINUX_DIR/launch-epic-linux.sh" "$EPIC_LINUX_DIR/icon.png"; do
        if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
            echo "Epic Linux 版的文件类型异常，已停止。"
            return 1
        fi
    done
}

install_epic_linux() (
    local steam_root shortcut_file stage="" desktop_dir applications_dir icon wrapper image
    local steam_stopped=0 app_id
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] || [ "$(uname -m)" != x86_64 ] || [ "$(id -u)" -eq 0 ]; then
        echo "请在 SteamOS 桌面模式使用普通用户安装 Epic Linux 版。"
        return 1
    fi
    require_command python3 || return 1
    require_command curl || return 1
    epic_linux_paths_safe || return 1
    steam_root="$(find_steam_root)" || return 1
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    desktop_dir="$(renkit_desktop_dir)"
    applications_dir="$(renkit_applications_dir)"
    local desktop_target
    for desktop_target in "$desktop_dir/Epic Linux 版.desktop" "$applications_dir/renkit-epic-linux.desktop"; do
        if [ -L "$desktop_target" ] || \
           { [ -e "$desktop_target" ] && { [ ! -f "$desktop_target" ] || ! grep -Fxq 'X-Renkit-Managed=true' "$desktop_target"; }; }; then
            echo "Epic Linux 版的启动入口被其他文件占用，原文件已保留。"
            return 1
        fi
    done
    mkdir -p -- "$EPIC_LINUX_DIR" "$desktop_dir" "$applications_dir" || return 1
    stage="$(mktemp -d "$EPIC_LINUX_DIR/.install.XXXXXX")" || return 1
    trap 'if [ "$steam_stopped" -eq 1 ]; then start_steam || true; fi; rm -rf -- "$stage"' EXIT
    wrapper="$EPIC_LINUX_DIR/launch-epic-linux.sh"
    image="$EPIC_LINUX_DIR/EpicGamesLauncher.AppImage"
    if ! epic_linux_file_valid "$image"; then
        DOWNLOAD_LOCAL_IO_FAILED=0
        download_with_gitee_mirror_fallback epic-linux "$EPIC_LINUX_URL" \
            "$EPIC_LINUX_SHA256" "$stage/EpicGamesLauncher.AppImage" "$EPIC_LINUX_NAME" || return 1
        epic_linux_file_valid "$stage/EpicGamesLauncher.AppImage" || {
            echo "Epic Linux 版安装文件检查未通过，原有程序已保留。"
            return 1
        }
        chmod 0755 "$stage/EpicGamesLauncher.AppImage" || return 1
        mv -f -- "$stage/EpicGamesLauncher.AppImage" "$image" || return 1
    else
        echo "Epic Linux 版已安装，正在检查启动入口。"
        chmod 0755 "$image" || return 1
    fi
    # 官方文件的 AppImage runtime 支持此模式，无需额外安装挂载组件。
    cat > "$stage/launch-epic-linux.sh" <<EOF
#!/bin/bash
unset LD_LIBRARY_PATH LD_PRELOAD
export APPIMAGE_EXTRACT_AND_RUN=1
exec $(shell_quote "$image") "\$@"
EOF
    chmod 0755 "$stage/launch-epic-linux.sh" || return 1
    mv -f -- "$stage/launch-epic-linux.sh" "$wrapper" || return 1
    icon="$(launcher_cover_file epic epic.png 2>/dev/null || true)"
    [ -s "$icon" ] || icon="$PROJECT_ROOT/assets/icon-toolbox-deck.png"
    cp -- "$icon" "$stage/icon.png" || return 1
    mv -f -- "$stage/icon.png" "$EPIC_LINUX_DIR/icon.png" || return 1
    icon="$EPIC_LINUX_DIR/icon.png"
    # Exec 按桌面规范转义百分号，空格和 shell 特殊字符由 shell_quote 处理。
    local desktop_exec="${wrapper//%/%%}"
    cat > "$stage/renkit-epic-linux.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$EPIC_LINUX_NAME
Comment=下载和管理 Epic 游戏（官方测试版）
Exec=$(shell_quote "$desktop_exec")
Icon=$icon
Terminal=false
Categories=Game;
X-Renkit-Managed=true
EOF
    chmod 0755 "$stage/renkit-epic-linux.desktop" || return 1
    for desktop_target in "$desktop_dir/Epic Linux 版.desktop" "$applications_dir/renkit-epic-linux.desktop"; do
        [ ! -L "$desktop_target" ] || return 1
        cp -- "$stage/renkit-epic-linux.desktop" "$desktop_target" || return 1
    done
    stop_steam_for_vdf || return 1
    steam_stopped=1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" add \
        --name "$EPIC_LINUX_NAME" --exe "$wrapper" --start-dir "$EPIC_LINUX_DIR" >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" set-icon \
        --name "$EPIC_LINUX_NAME" --exe "$wrapper" --icon "$icon" >/dev/null || return 1
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" verify \
        --name "$EPIC_LINUX_NAME" --exe "$wrapper" --icon "$icon" >/dev/null || return 1
    app_id="$(python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" find-appid \
        --name "$EPIC_LINUX_NAME" --exe "$wrapper")" || return 1
    install_launcher_artwork_for_id epic "$(dirname "$shortcut_file")/grid" "$app_id" || true
    start_steam || return 1
    steam_stopped=0
    echo "Epic Linux 版已安装，可从桌面或 Steam 打开并登录。"
    echo "目前为官方测试版，部分功能和游戏暂不支持。"
    log "Epic Linux 安装完成 version=$EPIC_LINUX_VERSION"
)

uninstall_epic_linux() (
    local steam_root shortcut_file desktop_dir applications_dir steam_stopped=0
    detect_platform
    [ "$IS_STEAMOS" -eq 1 ] && [ "$(id -u)" -ne 0 ] || return 1
    epic_linux_paths_safe || return 1
    confirm_launcher_uninstall "$EPIC_LINUX_NAME" || return 0
    steam_root="$(find_steam_root)" || return 1
    shortcut_file="$(find_shortcut_file "$steam_root")" || return 1
    stop_steam_for_vdf || return 1
    steam_stopped=1
    trap 'if [ "$steam_stopped" -eq 1 ]; then start_steam || true; fi' EXIT
    python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$shortcut_file" remove \
        --exe-basename launch-epic-linux.sh >/dev/null || return 1
    desktop_dir="$(renkit_desktop_dir)"
    applications_dir="$(renkit_applications_dir)"
    rm -f -- "$EPIC_LINUX_DIR/EpicGamesLauncher.AppImage" \
        "$EPIC_LINUX_DIR/launch-epic-linux.sh" "$EPIC_LINUX_DIR/icon.png" || return 1
    local desktop_target
    for desktop_target in "$desktop_dir/Epic Linux 版.desktop" "$applications_dir/renkit-epic-linux.desktop"; do
        if [ -f "$desktop_target" ] && [ ! -L "$desktop_target" ] && \
           grep -Fxq 'X-Renkit-Managed=true' "$desktop_target"; then
            rm -f -- "$desktop_target" || return 1
        fi
    done
    rmdir "$EPIC_LINUX_DIR" 2>/dev/null || true
    start_steam || return 1
    steam_stopped=0
    echo "Epic Linux 版已卸载，账号设置、游戏和下载文件已保留。"
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-install}" in
        install) install_epic_linux ;;
        uninstall) uninstall_epic_linux ;;
        *) echo "用法: $0 {install|uninstall}"; exit 1 ;;
    esac
fi
