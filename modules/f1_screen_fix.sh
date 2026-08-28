#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

F1_PRODUCT_LABEL="ONEXPLAYER F1 / ONEXPLAYER F1 OLED"
F1_PRODUCT_FILE="${ZHOUKEER_F1_PRODUCT_FILE:-/sys/devices/virtual/dmi/id/product_name}"
F1_GAMESCOPE_SESSION="${ZHOUKEER_F1_GAMESCOPE_SESSION:-/usr/lib/steamos/gamescope-session}"
F1_ROOT="$HOME/.local/gamescope-f1"
F1_BIN_DIR="$F1_ROOT/bin"
F1_GAMESCOPE_WRAPPER="$F1_BIN_DIR/gamescope"
F1_SESSION_WRAPPER="$F1_ROOT/session-wrapper"
F1_OVERRIDE_DIR="$HOME/.config/systemd/user/gamescope-session.service.d"
F1_OVERRIDE_FILE="$F1_OVERRIDE_DIR/override.conf"

f1_is_target_device() {
    local product=""

    [ -r "$F1_PRODUCT_FILE" ] || return 1
    product="$(tr -d '\r\n' < "$F1_PRODUCT_FILE" 2>/dev/null)"
    case "$product" in
        "ONEXPLAYER F1"|"ONEXPLAYER F1 OLED") return 0 ;;
        *) return 1 ;;
    esac
}

f1_require_target_device() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "此功能仅支持 SteamOS，已停止执行。"
        return 1
    fi
    if ! f1_is_target_device; then
        echo "当前设备不是 ${F1_PRODUCT_LABEL}，本修复不适用。"
        return 1
    fi
    return 0
}

f1_install() {
    f1_require_target_device || return 1
    require_command systemctl || return 1
    if [ ! -f "$F1_GAMESCOPE_SESSION" ]; then
        echo "未找到 ${F1_GAMESCOPE_SESSION}；SteamOS 后续版本可能已修改启动结构，未安装修复。"
        return 1
    fi

    mkdir -p "$F1_BIN_DIR" "$F1_OVERRIDE_DIR" || return 1
    cat > "$F1_GAMESCOPE_WRAPPER" <<'EOF'
#!/bin/bash
case "$(tr -d '\r\n' < /sys/devices/virtual/dmi/id/product_name 2>/dev/null)" in
    "ONEXPLAYER F1"|"ONEXPLAYER F1 OLED")
        exec /usr/bin/gamescope --force-orientation left "$@"
        ;;
    *)
        exec /usr/bin/gamescope "$@"
        ;;
esac
EOF
    chmod 0755 "$F1_GAMESCOPE_WRAPPER" || return 1

    cat > "$F1_SESSION_WRAPPER" <<'EOF'
#!/bin/bash
export PATH="$HOME/.local/gamescope-f1/bin:$PATH"
exec /usr/lib/steamos/gamescope-session "$@"
EOF
    chmod 0755 "$F1_SESSION_WRAPPER" || return 1

    cat > "$F1_OVERRIDE_FILE" <<'EOF'
[Service]
ExecStart=
ExecStart=%h/.local/gamescope-f1/session-wrapper
EOF
    chmod 0644 "$F1_OVERRIDE_FILE" || return 1

    if ! systemctl --user daemon-reload; then
        echo "systemd 用户配置刷新失败，请检查后重试。"
        return 1
    fi

    log "飞行家 F1 屏幕方向修复已安装"
    echo "飞行家 F1 屏幕方向修复完成，重启 SteamOS 后生效。"
    echo "可在菜单选择“立即重启”，或稍后手动重启。"
    return 0
}

f1_status() {
    f1_require_target_device || return 1

    if [ -f "$F1_SESSION_WRAPPER" ] && [ -f "$F1_OVERRIDE_FILE" ]; then
        echo "飞行家 F1 屏幕方向修复：已安装。"
        if systemctl --user show gamescope-session.service -p ExecStart --value 2>/dev/null | \
            grep -Fq "$F1_SESSION_WRAPPER"; then
            echo "systemd override：已生效。"
        else
            echo "注意：文件存在，但 systemd 当前未确认 override；重启或重新登录后应生效。"
        fi
        log "已检查飞行家 F1 屏幕方向修复状态: 已安装"
    else
        echo "飞行家 F1 屏幕方向修复：未安装。"
        log "已检查飞行家 F1 屏幕方向修复状态: 未安装"
    fi
    return 0
}

f1_uninstall() {
    if [ -e "$F1_ROOT" ] || [ -e "$F1_OVERRIDE_DIR" ]; then
        rm -rf -- "$F1_ROOT"
        rm -rf -- "$F1_OVERRIDE_DIR"
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user daemon-reload >/dev/null 2>&1 || \
                echo "警告：systemd 用户配置刷新失败。"
        fi
        echo "飞行家 F1 屏幕方向修复已卸载；重启后恢复 SteamOS 原始 Gamescope 启动方式。"
        log "飞行家 F1 屏幕方向修复已卸载"
    else
        echo "未安装飞行家 F1 屏幕方向修复，无需卸载。"
    fi
    return 0
}

f1_reboot() {
    require_command systemctl || return 1
    if systemctl reboot; then
        return 0
    fi
    echo "无法立即重启（可能需要桌面会话授权），请稍后手动重启。"
    return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) f1_install ;;
        status) f1_status ;;
        uninstall) f1_uninstall ;;
        reboot) f1_reboot ;;
        *) echo "用法: $0 {install|status|uninstall|reboot}"; exit 1 ;;
    esac
fi
