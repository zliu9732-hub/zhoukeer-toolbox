#!/bin/bash

# Keep downloads and menu routing unchanged; V15 uses the vendor's service helper
# and authenticated local control API instead of the removed S302.run protocol.
STEAM302_VERSION="15.0.9"
STEAM302_CONTROL_REVISION="v15-local-api-1.0"
STEAM302_ARCHIVE_SHA256="7884bbf43abe9b6202de37c133b3edfd8ff768c6c533e8d822d8aabf3a6f3fdd"
STEAM302_CONTROL="$PROJECT_ROOT/scripts/steam302_control.py"

confirm_steam302_uninstall() {
    local answer
    echo "将停止加速，通过官方组件移除加速证书和后台服务，并删除加速工具。"
    echo "会使用管理员权限。"
    [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != 1 ] || return 0
    read -r -p "确认卸载请输入 UNINSTALL：" answer
    [ "$answer" = UNINSTALL ]
}

steam302_v15_control() {
    python3 "$STEAM302_CONTROL" "$@"
}

steam302_is_installed() {
    [ "$(steam302_installed_version)" = "$STEAM302_VERSION" ] &&
        [ -x "$STEAM302_INSTALL_DIR/AppRun" ] &&
        [ -x "$STEAM302_INSTALL_DIR/usr/bin/s302-service-installer" ] &&
        [ -f "$STEAM302_INSTALL_DIR/usr/bin/s302-service-manifest.json" ]
}

steam302_runtime_is_ready() {
    steam302_is_installed && steam302_v15_control ready >/dev/null 2>&1
}

steam302_v15_helper() {
    local uid
    uid="$(id -u)" || return 1
    case "$uid" in ''|0|*[!0-9]*) echo "请用桌面用户运行 Renkit。"; return 1 ;; esac
    case "$1" in
        install) toolbox_sudo "$STEAM302_INSTALL_DIR/usr/bin/s302-service-installer" install "$uid" var-lib ;;
        restart|uninstall) toolbox_sudo "$STEAM302_INSTALL_DIR/usr/bin/s302-service-installer" "$1" "$uid" ;;
        *) return 1 ;;
    esac
}

steam302_v15_service_exists() {
    local uid
    uid="$(id -u)" || return 1
    case "$uid" in ''|0|*[!0-9]*) return 1 ;; esac
    systemctl cat "s302-$uid.service" >/dev/null 2>&1
}

steam302_stop_legacy() {
    # Never overwrite or remove another application's same-named service.
    if steam302_service_exists || [ -e "$STEAM302_SERVICE_FILE" ]; then
        steam302_service_is_toolbox_managed || {
            echo "检测到其他方式安装的旧版加速，请先在原程序中关闭并卸载。"
            return 1
        }
        toolbox_sudo systemctl stop "$STEAM302_SERVICE_NAME" || return 1
    fi
    stop_steam302_cli || return 1
}

steam302_finish_enable() {
    echo "正在应用加速设置..."
    steam302_v15_control configure || return 1
    echo "正在检查并修复加速证书..."
    # Official import checks both system and per-user NSS stores, including Steam.
    steam302_v15_control certificates || {
        echo "证书检查未通过，加速尚未完成。请查看加速工具的证书页面。"
        return 1
    }
    steam302_v15_control start || return 1
    steam302_runtime_is_ready || return 1
    print_steam302_ready_notice
    echo "如果 Steam 仍提示证书错误，请完全退出 Steam 后重新打开。"
}

install_steam302() (
    local stage="" backup="" package="" replaced=0 committed=0 old_active=0
    local new_service=0
    cleanup_v15_install() {
        if [ "$committed" -eq 0 ] && [ "$replaced" -eq 1 ]; then
            # The official helper rolls back a failed service installation itself.
            # After a successful helper installation, do not delete its resources
            # or claim the previous service was restored: preserve both versions.
            if [ "$new_service" -eq 0 ]; then
                rm -rf -- "$STEAM302_INSTALL_DIR"
                if [ -d "$backup/steamcommunity302" ]; then
                    mv -- "$backup/steamcommunity302" "$STEAM302_INSTALL_DIR" || true
                fi
                if [ "$old_active" -eq 1 ]; then
                    toolbox_sudo systemctl start "$STEAM302_SERVICE_NAME" || true
                fi
            else
                echo "安装尚未完成，原版本保留在：$backup/steamcommunity302"
                backup=""
            fi
        fi
        [ -z "$stage" ] || rm -rf -- "$stage"
        [ -z "$backup" ] || rm -rf -- "$backup"
    }
    trap cleanup_v15_install EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    command -v python3 >/dev/null 2>&1 || { echo "缺少运行组件 Python 3，已停止安装。"; return 1; }
    [ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || {
        echo "此功能仅支持 SteamOS 的 64 位掌机。"; return 1;
    }
    confirm_steam302_install || return 1
    if [ "${ZHOUKEER_TEST_MODE:-0}" != 1 ]; then
        bash "$PROJECT_ROOT/modules/preflight.sh" steam302 || return 1
    fi
    mkdir -p -- "$APP_DIR" || return 1
    if steam302_is_installed; then
        steam302_v15_helper install >>"$STEAM302_LOG_FILE" 2>&1 || {
            echo "加速组件未能启动，详情已记入日志：$STEAM302_LOG_FILE"; return 1;
        }
        steam302_finish_enable
        return
    fi
    stage="$(mktemp -d "$APP_DIR/.steamcommunity302-stage.XXXXXX")" || return 1
    package="$stage/Steamcommunity_302.AppImage"
    download_steam302_archive "$package" || return 1
    [ "$(calculate_steam302_sha256 "$package")" = "$STEAM302_ARCHIVE_SHA256" ] || {
        echo "安装文件检查未通过，已保留原来的加速工具。"; return 1;
    }
    steam302_v15_control verify-image "$package" || return 1
    chmod 755 "$package" || return 1
    echo "正在准备加速工具..."
    (cd -- "$stage" && "$package" --appimage-extract) >>"$STEAM302_LOG_FILE" 2>&1 || {
        echo "安装文件无法打开，已保留原来的加速工具。"; return 1;
    }
    steam302_v15_control verify-bundle "$stage/squashfs-root" || return 1
    printf '%s\n' "$STEAM302_VERSION" > "$stage/squashfs-root/.zhoukeer-version" || return 1
    steam302_service_is_active && old_active=1
    steam302_stop_legacy || return 1
    backup="$(mktemp -d "$APP_DIR/.steamcommunity302-backup.XXXXXX")" || return 1
    if [ -e "$STEAM302_INSTALL_DIR" ]; then
        [ ! -L "$STEAM302_INSTALL_DIR" ] || return 1
        mv -- "$STEAM302_INSTALL_DIR" "$backup/steamcommunity302" || return 1
    fi
    replaced=1
    mv -- "$stage/squashfs-root" "$STEAM302_INSTALL_DIR" || return 1
    # If interrupted while the official transaction runs, retain its source
    # bundle and the old version; never restart V14 into a possibly live V15.
    new_service=1
    if ! steam302_v15_helper install >>"$STEAM302_LOG_FILE" 2>&1; then
        new_service=0
        echo "加速组件安装失败，正在恢复原版本。详情：$STEAM302_LOG_FILE"
        return 1
    fi
    # Remove only the old Renkit-owned autostart, after the new daemon is ready.
    if steam302_service_is_toolbox_managed; then
        toolbox_sudo systemctl disable "$STEAM302_SERVICE_NAME" >>"$STEAM302_LOG_FILE" 2>&1 || return 1
    fi
    steam302_finish_enable || return 1
    committed=1
    rm -f -- "$STEAM302_DESKTOP_FILE"
    echo "Steamcommunity 302 V$STEAM302_VERSION 安装成功。"
)

start_steam302_service() {
    confirm_steam302_service_start || return 1
    if ! steam302_is_installed; then install_steam302; return; fi
    steam302_v15_helper install >>"$STEAM302_LOG_FILE" 2>&1 || {
        echo "加速组件未能启动，详情：$STEAM302_LOG_FILE"; return 1;
    }
    steam302_finish_enable
}

enable_steam302() {
    if [ "${ZHOUKEER_TEST_MODE:-0}" != 1 ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" steam302; then
        echo "加速未开启：准备检查未通过。"
        return 1
    fi
    start_steam302_service
}

stop_steam302_service() {
    if steam302_is_installed || steam302_v15_service_exists; then
        steam302_v15_control stop || return 1
        echo "加速已停止。"
    else
        steam302_stop_legacy
    fi
}

reset_steam302() {
    if ! steam302_is_installed; then install_steam302; return; fi
    confirm_steam302_service_start || return 1
    steam302_v15_control stop || return 1
    steam302_finish_enable
}

launch_steam302() {
    if ! steam302_is_installed; then install_steam302 || return 1; fi
    # The frontend runs as the desktop user; only the official helper elevates.
    "$STEAM302_INSTALL_DIR/AppRun"
}

show_steam302_status() {
    echo "Steamcommunity 302 已安装版本：$(steam302_installed_version)"
    if steam302_is_installed; then steam302_v15_control status
    else echo "请先安装或更新加速工具。"; fi
}

uninstall_steam302() {
    confirm_steam302_uninstall || return 1
    if steam302_is_installed; then
        steam302_v15_control stop || return 1
        steam302_v15_control remove-certificates || return 1
        steam302_v15_helper uninstall >>"$STEAM302_LOG_FILE" 2>&1 || return 1
    else
        if steam302_v15_service_exists; then
            echo "加速工具文件不完整，请先更新加速工具，再执行卸载。"
            return 1
        fi
        steam302_stop_legacy || return 1
    fi
    steam302_remove_autostart || return 1
    rm -rf -- "$STEAM302_INSTALL_DIR" || return 1
    rm -f -- "$STEAM302_DESKTOP_FILE"
    echo "网络加速工具已卸载。"
}
