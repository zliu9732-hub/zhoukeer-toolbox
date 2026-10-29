#!/bin/bash

# Reuse the launchers' verified download, storage choice and Proton preparation.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/game_launchers.sh"
source "$PROJECT_ROOT/core/desktop_paths.sh"

QUARK_APP_DIR="$APP_DIR/game-launchers/quark"

quark_paths_safe() {
    local path
    for path in "$APP_DIR" "$APP_DIR/game-launchers" "$QUARK_APP_DIR" \
        "$QUARK_APP_DIR/compatdata" "$QUARK_APP_DIR/compatdata/pfx" \
        "$QUARK_APP_DIR/launch-quark.sh" "$QUARK_APP_DIR/$LAUNCHER_FILE_NAME"; do
        [ ! -L "$path" ] || { echo '夸克网盘文件位置异常，已停止。'; return 1; }
    done
    if [ -L "$QUARK_APP_DIR/compatdata/pfx/drive_c" ] && \
        [ ! -d "$QUARK_APP_DIR/compatdata/pfx/drive_c" ]; then
        echo '夸克网盘原安装位置暂不可用，请连接原存储设备后重试。'
        return 1
    fi
}

quark_exe_valid() {
    [ -f "$1" ] && [ ! -L "$1" ] && \
        [ "$(od -An -tx1 -N2 "$1" 2>/dev/null | tr -d ' \n')" = 4d5a ]
}

quark_download_portable() (
    local output="$1" temporary attempt
    temporary="$(mktemp "$QUARK_APP_DIR/.download.XXXXXX")" || return 1
    trap 'rm -f -- "$temporary"' EXIT
    for attempt in 1 2; do
        if download_gitee_mirror_file "$LAUNCHER_GITEE_MIRROR_ID" "$temporary" \
            "$LAUNCHER_FIXED_SHA256" "$LAUNCHER_NAME" && \
            verify_installer "$temporary" >/dev/null 2>&1; then
            mv -- "$temporary" "$output" || return 1
            return 0
        fi
        [ "$attempt" -ne 1 ] || echo '下载失败，正在重新尝试。'
    done
    echo '夸克网盘下载未完成，请稍后重试。'
    return 1
)

quark_shortcuts() (
    local wrapper="$1" desktop_dir applications_dir target staged
    desktop_dir="$(renkit_desktop_dir)"; applications_dir="$(renkit_applications_dir)"
    for target in "$desktop_dir/夸克网盘.desktop" "$applications_dir/renkit-quark.desktop"; do
        [ ! -L "$target" ] || return 1
        if [ -e "$target" ] && ! grep -Fqx 'X-Renkit-Quark=true' "$target"; then
            echo '已有同名夸克网盘入口，已保留，请先更名后重试。'
            return 1
        fi
    done
    mkdir -p -- "$desktop_dir" "$applications_dir" || return 1
    staged="$(mktemp "$QUARK_APP_DIR/.desktop.XXXXXX")" || return 1
    trap 'rm -f -- "$staged"' EXIT
    local desktop_exec="${wrapper//%/%%}"
    cat > "$staged" <<EOF
[Desktop Entry]
Type=Application
Name=夸克网盘
Comment=上传、下载和管理夸克网盘文件
Exec=$(shell_quote "$desktop_exec")
Icon=$PROJECT_ROOT/assets/software/quark.png
Terminal=false
Categories=Network;FileTransfer;
X-Renkit-Quark=true
EOF
    chmod 0755 "$staged" || return 1
    for target in "$desktop_dir/夸克网盘.desktop" "$applications_dir/renkit-quark.desktop"; do
        cp -- "$staged" "$target" || return 1
    done
)

install_quark() (
    local steam_root prefix exe runner installer selected status wrapper drive
    local helper="$PROJECT_ROOT/scripts/quark_portable.py"
    detect_platform
    [ "$IS_STEAMOS" -eq 1 ] || { echo '夸克网盘安装目前仅支持 SteamOS。'; return 1; }
    launcher_details quark || return 1
    quark_paths_safe || return 1
    steam_root="$(find_steam_root)" || return 1
    prefix="$QUARK_APP_DIR/compatdata"
    exe="$(python3 "$helper" check "$prefix/pfx/drive_c" 2>/dev/null || true)"
    if [ -n "$exe" ] && quark_exe_valid "$exe"; then
        echo '夸克网盘已准备好，正在检查启动入口。'
    else
        if [ ! -d "$prefix/pfx/drive_c" ]; then
            if selected="$(select_launcher_storage_base quark "$steam_root")"; then
                LAUNCHER_BASE="$selected"
            else
                status=$?
                [ "$status" -ne 2 ] || return 0
                return 1
            fi
        fi
        mkdir -p -- "$QUARK_APP_DIR" || return 1
        installer="$QUARK_APP_DIR/$LAUNCHER_FILE_NAME"
        if ! verify_installer "$installer" >/dev/null 2>&1; then
            quark_download_portable "$installer" || return 1
        fi
        verify_installer "$installer" >/dev/null 2>&1 || return 1
        runner="$(ensure_launcher_proton_runner quark "$steam_root")" || return 1
        # A partial previous installation may contain settings/downloads: reuse it.
        if [ ! -d "$prefix/pfx/drive_c" ]; then
            drive="$(launcher_drive_c quark)"
            mkdir -p -- "$drive" || return 1
            prefix="$(prepare_launcher_shared_prefix quark "$drive")" || return 1
        fi
        echo '正在准备夸克网盘…'
        exe="$(python3 "$helper" install "$prefix/pfx/drive_c" "$installer")" || {
            echo '夸克网盘准备未完成，已有文件已保留。'
            return 1
        }
        quark_exe_valid "$exe" || { echo '未找到完整的夸克网盘程序，请重试。'; return 1; }
    fi
    runner="${runner:-$(ensure_launcher_proton_runner quark "$steam_root")}" || return 1
    [ -n "$runner" ] || return 1
    mkdir -p -- "$QUARK_APP_DIR" || return 1
    wrapper="$(create_launcher_wrapper quark "$steam_root" "$prefix" "$runner" "$exe" "$QUARK_APP_DIR")" || return 1
    quark_shortcuts "$wrapper" || return 1
    echo '夸克网盘安装完成，可从桌面或应用菜单打开。'
    echo '登录夸克账号后即可上传、下载和管理文件。'
    log '夸克网盘安装及启动入口检查完成'
)

remove_quark_shortcuts() {
    local target
    detect_platform
    [ "$IS_STEAMOS" -eq 1 ] || return 1
    for target in "$(renkit_desktop_dir)/夸克网盘.desktop" \
        "$(renkit_applications_dir)/renkit-quark.desktop"; do
        if [ -f "$target" ] && [ ! -L "$target" ] && grep -Fqx 'X-Renkit-Quark=true' "$target"; then
            rm -f -- "$target" || return 1
        fi
    done
    echo '夸克网盘启动入口已移除，程序、账号和下载文件已保留。'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-install}" in
        install) install_quark ;;
        remove-shortcuts) remove_quark_shortcuts ;;
        *) echo "用法: $0 {install|remove-shortcuts}"; exit 1 ;;
    esac
fi
