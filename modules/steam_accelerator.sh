#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

STEAM302_VERSION="14.0.02"
STEAM302_ARCHIVE_URL="https://www.dogfight360.com/blog/wp-content/uploads/2026/02/steamcommunity_302_Linux_AMD64_V14.0.02.tar.gz"
STEAM302_ARCHIVE_MD5="4b9994102b2256ca5fdf2e806a2c7035"
STEAM302_ARCHIVE_SHA256="5e006f015c807679ef800a87fa7b788562901ad04d7899ade2648f82b4c4a11f"
STEAM302_INSTALL_DIR="$APP_DIR/steamcommunity302"
STEAM302_DESKTOP_FILE="$HOME/Desktop/Steamcommunity 302.desktop"
STEAM302_SERVICE_NAME="steamcommunity302.service"
STEAM302_SYSTEMD_DIR="${ZHOUKEER_SYSTEMD_DIR:-/etc/systemd/system}"
STEAM302_SERVICE_FILE="$STEAM302_SYSTEMD_DIR/$STEAM302_SERVICE_NAME"
STEAM302_CLI="$STEAM302_INSTALL_DIR/steamcommunity_302.cli"
STEAM302_RULES_FILE="$STEAM302_INSTALL_DIR/S302_rules.ini"
STEAM302_CONFIG_FILE="$STEAM302_INSTALL_DIR/S302.ini"
STEAM302_PID_FILE="$STEAM302_INSTALL_DIR/.zhoukeer-cli.pid"
STEAM302_LOG_FILE="$APP_DIR/steamcommunity302.log"
STEAM302_ROOT_STARTER="$PROJECT_ROOT/modules/steam302_root_start.sh"
STEAM302_ENABLED_RULES="Steam_store,Steam_store_unlock,Steam_community,Steam_API,Steam_API_unlock,Steam_community_unlock,steamchat,steamchat_unlock,Steam_cloud_google,steam_update,Steam_broadcast_redir,Steam_broadcast_redir_unlock,imgfix,imgfix_fastly,github"
STEAM302_CONNECT_TIMEOUT=15
STEAM302_MAX_TIME=1200
STEAM302_RETRIES=3
STEAM302_LAYOUT_VALIDATION_REVISION="ascii-files-v2"
STEAM302_PROCESS_CHECK_REVISION="proc-root-v1"

STEAM302_STAGE_DIR=""
STEAM302_BACKUP_DIR=""
STEAM302_KEEP_BACKUP=0
STEAM302_SWAP_FINISHED=0

calculate_steam302_md5() {
    local file="$1"
    local output

    if command -v md5sum >/dev/null 2>&1; then
        output="$(md5sum "$file")" || return 1
        printf '%s\n' "$output" | awk '{ print tolower($1) }'
    elif command -v md5 >/dev/null 2>&1; then
        output="$(md5 -q "$file" 2>/dev/null)" || \
            output="$(md5 "$file")" || return 1
        printf '%s\n' "$output" | awk '{ print tolower($NF) }'
    else
        return 1
    fi
}

calculate_steam302_sha256() {
    local file="$1"
    local output

    if command -v sha256sum >/dev/null 2>&1; then
        output="$(sha256sum "$file")" || return 1
        printf '%s\n' "$output" | awk '{ print tolower($1) }'
    elif command -v shasum >/dev/null 2>&1; then
        output="$(shasum -a 256 "$file")" || return 1
        printf '%s\n' "$output" | awk '{ print tolower($1) }'
    else
        return 1
    fi
}

show_steam302_risk_notice() {
    echo "将安装官方 Steamcommunity 302 V$STEAM302_VERSION，并启用 Steam 与 GitHub 加速。"
    echo "启动时需要管理员权限，官方程序可能修改代理、hosts、DNS 或根证书。"
}

confirm_steam302_install() {
    local answer

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "正在安装 Steamcommunity 302..."
        return 0
    fi

    show_steam302_risk_notice

    echo ""
    read -r -p "确认安装请输入 INSTALL：" answer
    [ "$answer" = "INSTALL" ]
}

confirm_steam302_uninstall() {
    local answer

    echo "将删除 Steamcommunity 302 程序目录和工具箱创建的桌面快捷方式。"
    echo "会先停止工具箱启动的官方 CLI；不会代替官方程序恢复 hosts、移除证书或修改 systemd。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    echo ""
    read -r -p "确认卸载请输入 UNINSTALL：" answer
    [ "$answer" = "UNINSTALL" ]
}

steam302_is_installed() {
    [ -d "$STEAM302_INSTALL_DIR" ] && \
        [ -f "$STEAM302_INSTALL_DIR/run_运行.sh" ] && \
        [ -f "$STEAM302_INSTALL_DIR/Steamcommunity_302" ]
}

steam302_cli_is_running() {
    local pid
    local proc_root="${ZHOUKEER_PROC_ROOT:-/proc}"
    local proc_dir
    local command_line

    [ -r "$STEAM302_PID_FILE" ] || return 1
    pid="$(sed -n '1p' "$STEAM302_PID_FILE" 2>/dev/null || true)"
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    # 非 Linux 测试环境没有 /proc，保留传统探测作为兼容回退；SteamOS
    # 始终走下方不发送信号的 /proc 检查。
    if [ ! -d "$proc_root" ]; then
        kill -0 "$pid" >/dev/null 2>&1
        return
    fi
    proc_dir="$proc_root/$pid"
    [ -d "$proc_dir" ] || return 1

    # CLI 由 root 启动，普通 deck 用户对 root 进程执行 kill -0 会得到
    # EPERM，不能据此判断进程已经退出。/proc 目录可用于无信号探测；
    # 命令行可读时再核对程序名，避免陈旧 PID 恰好指向其他进程。
    if [ -r "$proc_dir/cmdline" ]; then
        command_line="$(tr '\000' ' ' < "$proc_dir/cmdline" 2>/dev/null || true)"
        case "$command_line" in
            *steamcommunity_302.cli*) ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

steam302_config_has_download_targets() {
    local enabled_rules

    [ -r "$STEAM302_CONFIG_FILE" ] || return 1
    enabled_rules="$(awk '
        BEGIN { in_rules = 0 }
        /^\[Rules\][[:space:]]*$/ { in_rules = 1; next }
        /^\[/ { in_rules = 0 }
        in_rules && /^[[:space:]]*enabled[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, "")
            print
            exit
        }
    ' "$STEAM302_CONFIG_FILE")"
    enabled_rules="${enabled_rules//[[:space:]]/}"
    case ",$enabled_rules," in
        *,Steam_store,*) ;;
        *) return 1 ;;
    esac
    case ",$enabled_rules," in
        *,github,*) return 0 ;;
        *) return 1 ;;
    esac
}

ensure_steam302_config() {
    local temporary_config

    steam302_config_has_download_targets && return 0
    [ -f "$STEAM302_RULES_FILE" ] || {
        echo "Steamcommunity 302 缺少官方规则文件 S302_rules.ini。"
        return 1
    }

    temporary_config="$(mktemp "$STEAM302_INSTALL_DIR/.S302.ini.XXXXXX")" || return 1
    if ! awk -v enabled="$STEAM302_ENABLED_RULES" '
        BEGIN { in_rules = 0; replaced = 0 }
        /^\[Rules\][[:space:]]*$/ { in_rules = 1 }
        /^\[/ && $0 !~ /^\[Rules\][[:space:]]*$/ { in_rules = 0 }
        in_rules && /^[[:space:]]*enabled[[:space:]]*=/ {
            if (!replaced) {
                print "enabled = " enabled
                replaced = 1
            }
            next
        }
        { print }
        END { if (!replaced) exit 1 }
    ' "$STEAM302_RULES_FILE" > "$temporary_config"; then
        rm -f "$temporary_config"
        echo "官方规则文件中没有找到 [Rules] enabled 配置项。"
        return 1
    fi
    chmod 644 "$temporary_config" || {
        rm -f "$temporary_config"
        return 1
    }
    if ! mv -f "$temporary_config" "$STEAM302_CONFIG_FILE"; then
        rm -f "$temporary_config"
        return 1
    fi
}

steam302_installed_version() {
    if [ -r "$STEAM302_INSTALL_DIR/.zhoukeer-version" ]; then
        sed -n '1p' "$STEAM302_INSTALL_DIR/.zhoukeer-version"
    fi
}

steam302_service_is_active() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl is-active --quiet "$STEAM302_SERVICE_NAME" >/dev/null 2>&1
}

steam302_service_is_enabled() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl is-enabled --quiet "$STEAM302_SERVICE_NAME" >/dev/null 2>&1
}

steam302_service_exists() {
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl cat "$STEAM302_SERVICE_NAME" >/dev/null 2>&1
}

steam302_service_is_toolbox_managed() {
    [ -f "$STEAM302_SERVICE_FILE" ] && [ ! -L "$STEAM302_SERVICE_FILE" ] || return 1
    grep -Fqx '# Managed by Zhoukeer Toolbox' "$STEAM302_SERVICE_FILE" &&
        grep -Fqx "ExecStart=$STEAM302_CLI" "$STEAM302_SERVICE_FILE"
}

confirm_steam302_service_start() {
    local answer

    echo "将启动 Steam 与 GitHub 后台加速；可能需要管理员权限并修改网络设置。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    read -r -p "确认启动请输入 START：" answer
    [ "$answer" = "START" ]
}

print_steam302_ready_notice() {
    echo "Steam + GitHub 加速已开启。"
}

start_steam302_service() {
    local display_value="${DISPLAY:-:0}"
    local xauthority_value="${XAUTHORITY:-$HOME/.Xauthority}"
    local lang_value="${LANG:-C.UTF-8}"
    local pid

    steam302_is_installed || {
        echo "Steamcommunity 302 尚未安装。"
        return 1
    }
    ensure_steam302_config || return 1
    if steam302_service_is_active; then
        print_steam302_ready_notice
        return 0
    fi
    if steam302_cli_is_running; then
        print_steam302_ready_notice
        return 0
    fi

    confirm_steam302_service_start || {
        echo "已取消启动加速服务。"
        return 0
    }

    [ -x "$STEAM302_ROOT_STARTER" ] || {
        echo "内置加速启动器不存在或不可执行。"
        return 1
    }
    rm -f "$STEAM302_INSTALL_DIR/S302.exit" "$STEAM302_PID_FILE"
    if ! toolbox_sudo /usr/bin/env -i \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        HOME="/root" \
        USER="root" \
        LOGNAME="root" \
        LANG="$lang_value" \
        DISPLAY="$display_value" \
        XAUTHORITY="$xauthority_value" \
        "$STEAM302_ROOT_STARTER" \
        "$STEAM302_INSTALL_DIR" "$STEAM302_LOG_FILE" "$STEAM302_PID_FILE"; then
        echo "内置加速启动失败：管理员权限未通过或官方 CLI 无法启动。"
        return 1
    fi

    sleep 1
    pid="$(sed -n '1p' "$STEAM302_PID_FILE" 2>/dev/null || true)"
    if steam302_cli_is_running; then
        print_steam302_ready_notice
        return 0
    fi
    echo "官方 CLI 未保持运行，请查看日志：$STEAM302_LOG_FILE"
    [ -n "$pid" ] && sed -n '1,20p' "$STEAM302_LOG_FILE" 2>/dev/null || true
    rm -f "$STEAM302_PID_FILE"
    return 1
}

stop_steam302_cli() {
    local pid
    local attempt

    pid="$(sed -n '1p' "$STEAM302_PID_FILE" 2>/dev/null || true)"
    if ! steam302_cli_is_running; then
        rm -f "$STEAM302_PID_FILE"
        return 0
    fi

    printf '1\n' > "$STEAM302_INSTALL_DIR/S302.exit" || return 1
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        steam302_cli_is_running || break
        sleep 1
    done
    if steam302_cli_is_running; then
        toolbox_sudo kill "$pid" >/dev/null 2>&1 || return 1
    fi
    rm -f "$STEAM302_PID_FILE"
}

start_steam_client() {
    local steam_bin

    if command -v steam >/dev/null 2>&1; then
        steam_bin="$(command -v steam)"
    elif [ -x "$HOME/.steam/steam/steam.sh" ]; then
        steam_bin="$HOME/.steam/steam/steam.sh"
    else
        echo "未找到 Steam 启动命令，请手动启动 Steam。"
        return 1
    fi
    if pgrep -x steam >/dev/null 2>&1; then
        echo "Steam 已在运行。"
        return 0
    fi
    "$steam_bin" >/dev/null 2>&1 &
    echo "已启动 Steam。"
}

enable_steam302() {
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" steam302; then
        echo "加速未开启：准备检查未通过。"
        return 1
    fi
    if ! steam302_is_installed; then
        install_steam302 || return 1
    fi
    if ! start_steam302_service; then
        return 1
    fi
    if [ "${ZHOUKEER_START_STEAM_AFTER_302:-0}" = "1" ] && \
        steam302_download_acceleration_is_ready; then
        start_steam_client || true
    fi
}

steam302_download_acceleration_is_ready() {
    steam302_config_has_download_targets || return 1
    steam302_cli_is_running || steam302_service_is_active
}

ensure_steam302_for_download() {
    local enable_output

    if steam302_download_acceleration_is_ready; then
        return 0
    fi

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "下载较慢，正在启用加速，请耐心等待..."
        if enable_output="$(ZHOUKEER_PREFLIGHT_QUIET_SUCCESS=1 enable_steam302 2>&1)"; then
            echo "加速已开启，正在重试下载。"
            return 0
        fi
        log "Steamcommunity 302 自动加速未开启: $enable_output"
        echo "加速未能开启，继续下载。"
    else
        echo "Steam + GitHub 加速未开启。"
    fi
    return 0
}

steam302_setup_autostart() {
    local service_file="$STEAM302_SERVICE_FILE"

    if steam302_service_is_toolbox_managed; then
        :
    elif [ -e "$service_file" ] || [ -L "$service_file" ] || steam302_service_exists; then
        echo "检测到非工具箱创建的同名系统服务，拒绝覆盖：$STEAM302_SERVICE_NAME"
        echo "请先在原程序中停用该服务，再由工具箱配置后台加速。"
        return 1
    else
        local tmp_service
        tmp_service="$(mktemp)" || return 1
        cat > "$tmp_service" << SERVICE_EOF
# Managed by Zhoukeer Toolbox
[Unit]
Description=Steamcommunity 302 (Steam + GitHub Acceleration)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$STEAM302_CLI
WorkingDirectory=$STEAM302_INSTALL_DIR
Restart=on-failure
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
SERVICE_EOF
        toolbox_sudo install -d -m 0755 -- "$STEAM302_SYSTEMD_DIR" || {
            rm -f "$tmp_service"
            return 1
        }
        if ! toolbox_sudo install -m 0644 "$tmp_service" "$service_file"; then
            rm -f "$tmp_service"
            echo "开机自启服务创建失败。"
            return 1
        fi
        rm -f "$tmp_service"
        toolbox_sudo systemctl daemon-reload >/dev/null 2>&1 || true
    fi

    if ! steam302_service_is_enabled; then
        toolbox_sudo systemctl enable "$STEAM302_SERVICE_NAME" >/dev/null 2>&1 || {
            echo "开机自启启用失败。"
            return 1
        }
    fi

    # 启动（如果未运行）
    if steam302_service_is_active; then
        :
    else
        toolbox_sudo systemctl start "$STEAM302_SERVICE_NAME" >/dev/null 2>&1 || {
            echo "系统服务启动失败，将使用内置加速方式重试。"
            return 1
        }
        sleep 1
        steam302_service_is_active || return 1
    fi
}

steam302_remove_autostart() {
    echo "正在停止并移除开机自启服务..."
    if steam302_service_is_toolbox_managed; then
        toolbox_sudo systemctl disable --now "$STEAM302_SERVICE_NAME" >/dev/null 2>&1 || true
        toolbox_sudo rm -f "$STEAM302_SERVICE_FILE"
        toolbox_sudo systemctl daemon-reload >/dev/null 2>&1 || true
        echo "已移除开机自启服务。"
    elif steam302_service_exists || [ -e "$STEAM302_SERVICE_FILE" ] || [ -L "$STEAM302_SERVICE_FILE" ]; then
        echo "检测到非工具箱创建的同名服务，已保留且不会修改。"
    fi
}

stop_steam302_service() {
    if steam302_service_is_toolbox_managed && steam302_service_is_active; then
        toolbox_sudo systemctl stop "$STEAM302_SERVICE_NAME" >/dev/null 2>&1 || {
            echo "Steam + GitHub 后台服务停止失败。"
            return 1
        }
        echo "Steam + GitHub 后台服务已停止；开机自启设置保留。"
    fi
    if steam302_cli_is_running; then
        stop_steam302_cli || {
            echo "内置加速停止失败。"
            return 1
        }
        echo "Steam + GitHub 内置加速已停止。"
    fi
}

download_steam302_archive() {
    local destination="$1"

    download_policy_url_allowed "$STEAM302_ARCHIVE_URL" || {
        echo "Steamcommunity 302 下载地址不在受控来源清单中。"
        return 1
    }
    echo "正在下载 Steamcommunity 302 V$STEAM302_VERSION..."
    if download_gitee_mirror_file \
        "steam302" "$destination" "$STEAM302_ARCHIVE_SHA256" \
        "Steamcommunity 302"; then
        return 0
    fi
    curl \
        --fail \
        --location \
        --progress-meter \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$STEAM302_CONNECT_TIMEOUT" \
        --max-time "$STEAM302_MAX_TIME" \
        --retry "$STEAM302_RETRIES" \
        --retry-delay 2 \
        --retry-all-errors \
        --max-filesize "$(download_policy_max_bytes "$STEAM302_ARCHIVE_URL")" \
        --output "$destination" \
        "$STEAM302_ARCHIVE_URL" \
        2> >(download_progress_filter "Steamcommunity 302" >&2) || return 1
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! download_policy_response_is_safe "$STEAM302_ARCHIVE_URL" "$destination"; then
        rm -f -- "$destination"
        echo "Steamcommunity 302 下载响应格式或大小异常。"
        return 1
    fi
}

verify_steam302_archive() {
    local archive="$1"
    local actual_md5
    local actual_sha256

    actual_md5="$(calculate_steam302_md5 "$archive")" || {
        echo "无法计算安装包 MD5。"
        return 1
    }
    if [ "$actual_md5" != "$STEAM302_ARCHIVE_MD5" ]; then
        echo "Steamcommunity 302 MD5 校验失败，拒绝安装。"
        echo "期望：$STEAM302_ARCHIVE_MD5"
        echo "实际：$actual_md5"
        return 1
    fi

    actual_sha256="$(calculate_steam302_sha256 "$archive")" || {
        echo "无法计算安装包 SHA256。"
        return 1
    }
    if [ "$actual_sha256" != "$STEAM302_ARCHIVE_SHA256" ]; then
        echo "Steamcommunity 302 SHA256 校验失败，拒绝安装。"
        echo "期望：$STEAM302_ARCHIVE_SHA256"
        echo "实际：$actual_sha256"
        return 1
    fi

}

validate_steam302_archive_layout() {
    local archive="$1"
    local members
    local verbose_members

    members="$(LC_ALL=C tar -tzf "$archive" 2>/dev/null)" || {
        echo "无法读取 Steamcommunity 302 安装包。"
        return 1
    }
    [ -n "$members" ] || {
        echo "Steamcommunity 302 安装包为空。"
        return 1
    }

    if ! printf '%s\n' "$members" | awk '
        {
            entry = $0
            sub(/^\.\//, "", entry)
            if (entry ~ /^\// || entry ~ /(^|\/)\.\.(\/|$)/) exit 1
            if (entry != "Steamcommunity_302" &&
                entry !~ /^Steamcommunity_302\//) exit 1
            if (entry == "Steamcommunity_302/Steamcommunity_302") found_app = 1
            if (entry == "Steamcommunity_302/steamcommunity_302.cli") found_cli = 1
            if (entry == "Steamcommunity_302/S302_rules.ini") found_rules = 1
            if (entry == "Steamcommunity_302/.launcher/302_icon.ico") found_icon = 1
        }
        END {
            if (!found_app || !found_cli || !found_rules || !found_icon) exit 1
        }
    '; then
        echo "Steamcommunity 302 安装包目录结构异常，拒绝解压。"
        return 1
    fi

    verbose_members="$(LC_ALL=C tar -tvzf "$archive" 2>/dev/null)" || {
        echo "无法检查 Steamcommunity 302 安装包文件类型。"
        return 1
    }
    if ! printf '%s\n' "$verbose_members" | awk '
        NF > 0 {
            type = substr($1, 1, 1)
            if (type != "-" && type != "d") exit 1
        }
    '; then
        echo "安装包包含链接或特殊文件，拒绝解压。"
        return 1
    fi
}

desktop_exec_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/`/\\`/g' \
        -e 's/\$/\\$/g' \
        -e 's/%/%%/g'
}

create_steam302_shortcut() {
    local desktop_dir="$HOME/Desktop"
    local shortcut_tmp
    local module_script
    local icon_file

    module_script="$(desktop_exec_escape "$PROJECT_ROOT/modules/steam_accelerator.sh")" || return 1
    icon_file="$(desktop_exec_escape "$STEAM302_INSTALL_DIR/.launcher/302_icon.ico")" || return 1

    mkdir -p "$desktop_dir" || return 1
    shortcut_tmp="$(mktemp "$desktop_dir/.steamcommunity302.desktop.XXXXXX")" || return 1

    if ! cat > "$shortcut_tmp" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Steamcommunity 302
Name[zh_CN]=Steamcommunity 302
Comment=启动官方 Steamcommunity 302 配置界面
Exec=/usr/bin/env bash "$module_script" launch
Icon=$icon_file
Terminal=false
Categories=Network;Utility;
StartupNotify=true
EOF
    then
        rm -f "$shortcut_tmp"
        return 1
    fi

    chmod +x "$shortcut_tmp" || {
        rm -f "$shortcut_tmp"
        return 1
    }
    if ! mv -f "$shortcut_tmp" "$STEAM302_DESKTOP_FILE"; then
        rm -f "$shortcut_tmp"
        return 1
    fi

}

launch_steam302() {
    local display_value="${DISPLAY:-:0}"
    local xauthority_value="${XAUTHORITY:-$HOME/.Xauthority}"
    local lang_value="${LANG:-C.UTF-8}"

    steam302_is_installed || {
        echo "Steamcommunity 302 尚未安装。"
        return 1
    }

    # 优先使用工具箱桌面密码记录无感验证；记录缺失或失效时，退回官方
    # launcher 的图形密码框，避免从无终端的桌面入口直接卡住。
    # 不保留调用者的完整环境，避免把工具箱配置或其他敏感变量带入 root 进程。
    if ZHOUKEER_SUDO_INTERACTIVE_FALLBACK=0 toolbox_sudo /usr/bin/env -i \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        HOME="/root" \
        USER="root" \
        LOGNAME="root" \
        LANG="$lang_value" \
        DISPLAY="$display_value" \
        XAUTHORITY="$xauthority_value" \
        "$STEAM302_INSTALL_DIR/Steamcommunity_302"; then
        return 0
    fi

    exec /usr/bin/env bash "$STEAM302_INSTALL_DIR/run_运行.sh"
}

steam302_install_cleanup() {
    if [ -n "$STEAM302_STAGE_DIR" ] && [ -d "$STEAM302_STAGE_DIR" ]; then
        rm -rf "$STEAM302_STAGE_DIR"
    fi

    # 只要交换尚未完整结束，就按备份目录中的实际状态恢复；不能仅依赖
    # “下一行才设置”的标志，否则信号恰好落在 mv 后会丢失旧版本。
    if [ "$STEAM302_SWAP_FINISHED" -eq 0 ] && \
        [ -n "$STEAM302_BACKUP_DIR" ] && [ -d "$STEAM302_BACKUP_DIR" ]; then
        restore_previous_steam302 || true
    fi

    if [ "$STEAM302_KEEP_BACKUP" -eq 0 ] && \
        [ -n "$STEAM302_BACKUP_DIR" ] && [ -d "$STEAM302_BACKUP_DIR" ]; then
        rm -rf "$STEAM302_BACKUP_DIR"
    fi
}

restore_previous_steam302() {
    local old_install="$STEAM302_BACKUP_DIR/steamcommunity302"
    local no_previous_marker="$STEAM302_BACKUP_DIR/.no-previous-version"

    if [ -e "$old_install" ] || [ -L "$old_install" ]; then
        if [ -e "$STEAM302_INSTALL_DIR" ] || [ -L "$STEAM302_INSTALL_DIR" ]; then
            if ! rm -rf "$STEAM302_INSTALL_DIR"; then
                STEAM302_KEEP_BACKUP=1
                echo "无法移除未完成的新版本。旧版仍保留在：$old_install"
                return 1
            fi
        fi
        if ! mv "$old_install" "$STEAM302_INSTALL_DIR"; then
            STEAM302_KEEP_BACKUP=1
            echo "无法自动恢复旧版；旧版仍保留在：$old_install"
            return 1
        fi
        return 0
    fi

    # 首次安装没有旧版本。仅当明确写入该标记后，失败清理才可删除
    # 已经切换进去的新目录；没有标记时，现有目录可能仍是用户旧版本。
    if [ -f "$no_previous_marker" ] && \
        { [ -e "$STEAM302_INSTALL_DIR" ] || [ -L "$STEAM302_INSTALL_DIR" ]; }; then
        if ! rm -rf "$STEAM302_INSTALL_DIR"; then
            STEAM302_KEEP_BACKUP=1
            echo "无法移除未完成的首次安装：$STEAM302_INSTALL_DIR"
            return 1
        fi
    fi
}

install_steam302() (
    local archive_file
    local extract_dir
    local package_dir
    local old_install
    local current_version
    local architecture

    is_linux || {
        echo "Steamcommunity 302 安装仅支持 Linux / SteamOS。"
        return 1
    }
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" steam302; then
        echo "安装已停止：准备检查未通过。"
        return 1
    fi
    architecture="$(uname -m 2>/dev/null || true)"
    case "$architecture" in
        x86_64|amd64) ;;
        *)
            echo "当前架构为 $architecture；此安装项只提供官方 Linux AMD64 包。"
            return 1
            ;;
    esac

    require_command curl || return 1
    require_command tar || return 1
    require_command awk || return 1
    if ! command -v md5sum >/dev/null 2>&1 && ! command -v md5 >/dev/null 2>&1; then
        echo "缺少 MD5 校验工具。"
        return 1
    fi
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        echo "缺少 SHA256 校验工具。"
        return 1
    fi

    if steam302_is_installed; then
        current_version="$(steam302_installed_version)"
        if [ "$current_version" = "$STEAM302_VERSION" ]; then
            ensure_steam302_config || return 1
            rm -f -- "$STEAM302_DESKTOP_FILE" || return 1
            steam302_setup_autostart || return 1
            echo "Steam + GitHub 加速已开启。"
            return 0
        fi
    fi

    confirm_steam302_install || {
        echo "已取消 Steamcommunity 302 安装。"
        return 0
    }

    mkdir -p "$APP_DIR" || return 1
    STEAM302_STAGE_DIR="$(mktemp -d "$APP_DIR/.steamcommunity302-stage.XXXXXX")" || {
        echo "无法创建 Steamcommunity 302 临时目录。"
        return 1
    }
    trap steam302_install_cleanup EXIT
    trap 'exit 130' HUP INT TERM

    archive_file="$STEAM302_STAGE_DIR/steamcommunity_302.tar.gz"
    extract_dir="$STEAM302_STAGE_DIR/extracted"

    download_steam302_archive "$archive_file" || {
        echo "Steamcommunity 302 下载失败；已有版本保持不变。"
        return 1
    }
    verify_steam302_archive "$archive_file" || {
        echo "已有版本保持不变。"
        return 1
    }
    validate_steam302_archive_layout "$archive_file" || {
        echo "已有版本保持不变。"
        return 1
    }

    mkdir -p "$extract_dir" || return 1
    if ! tar -xzf "$archive_file" -C "$extract_dir"; then
        echo "Steamcommunity 302 解压失败；已有版本保持不变。"
        return 1
    fi
    package_dir="$extract_dir/Steamcommunity_302"
    if [ ! -f "$package_dir/run_运行.sh" ] || \
        [ ! -f "$package_dir/Steamcommunity_302" ] || \
        [ ! -f "$package_dir/.launcher/launcher_启动器.sh" ]; then
        echo "解压后的程序文件不完整；已有版本保持不变。"
        return 1
    fi

    printf '%s\n' "$STEAM302_VERSION" > "$package_dir/.zhoukeer-version" || return 1
    chmod +x \
        "$package_dir/run_运行.sh" \
        "$package_dir/Steamcommunity_302" \
        "$package_dir/.launcher/launcher_启动器.sh" || return 1
    [ ! -f "$package_dir/.launcher/setup_desktop_生成桌面快捷方式.sh" ] || \
        chmod +x "$package_dir/.launcher/setup_desktop_生成桌面快捷方式.sh" || return 1
    [ ! -f "$package_dir/steamcommunity_302.cli" ] || \
        chmod +x "$package_dir/steamcommunity_302.cli" || return 1
    [ ! -f "$package_dir/steamcommunity_302.caddy" ] || \
        chmod +x "$package_dir/steamcommunity_302.caddy" || return 1

    STEAM302_BACKUP_DIR="$(mktemp -d "$APP_DIR/.steamcommunity302-backup.XXXXXX")" || {
        echo "无法准备旧版本备份目录；已有版本保持不变。"
        return 1
    }
    old_install="$STEAM302_BACKUP_DIR/steamcommunity302"
    if [ -e "$STEAM302_INSTALL_DIR" ] || [ -L "$STEAM302_INSTALL_DIR" ]; then
        if ! mv "$STEAM302_INSTALL_DIR" "$old_install"; then
            echo "无法暂存已有版本，安装已停止。"
            return 1
        fi
    else
        : > "$STEAM302_BACKUP_DIR/.no-previous-version" || return 1
    fi

    if ! mv "$package_dir" "$STEAM302_INSTALL_DIR"; then
        echo "无法替换 Steamcommunity 302，正在恢复已有版本。"
        return 1
    fi

    if ! ensure_steam302_config; then
        echo "内置 Steam + GitHub 规则生成失败，正在恢复已有版本。"
        return 1
    fi

    STEAM302_SWAP_FINISHED=1
    rm -rf "$STEAM302_BACKUP_DIR"
    STEAM302_BACKUP_DIR=""
    rm -f -- "$STEAM302_DESKTOP_FILE" || return 1
    if ! steam302_setup_autostart; then
        echo "Steamcommunity 302 已安装，但后台自启未完成。"
        return 1
    fi
    echo "Steam + GitHub 加速已开启。"
)

show_steam302_status() {
    local version

    if steam302_is_installed; then
        version="$(steam302_installed_version)"
        [ -n "$version" ] || version="未知（可能由官方程序直接解压）"
        echo "Steamcommunity 302：已安装"
        echo "版本：$version"
        echo "目录：$STEAM302_INSTALL_DIR"
        echo "桌面图标：不创建（由工具箱后台管理）"
    else
        echo "Steamcommunity 302：未安装"
    fi

    if steam302_service_is_active; then
        echo "后台服务：正在运行"
    elif steam302_cli_is_running; then
        echo "内置加速：正在运行（Steam + GitHub）"
    elif steam302_service_is_enabled; then
        echo "后台服务：已设为开机启动，但当前未运行"
    else
        echo "后台服务：未检测到运行或开机启用"
    fi

    steam302_is_installed
}

uninstall_steam302() {
    if ! steam302_is_installed && \
        [ ! -e "$STEAM302_INSTALL_DIR" ] && [ ! -L "$STEAM302_INSTALL_DIR" ] && \
        [ ! -e "$STEAM302_DESKTOP_FILE" ] && [ ! -L "$STEAM302_DESKTOP_FILE" ]; then
        echo "Steamcommunity 302 未安装。"
        return 0
    fi

    confirm_steam302_uninstall || {
        echo "已取消 Steamcommunity 302 卸载。"
        return 0
    }

    steam302_remove_autostart
    stop_steam302_service || return 1

    if steam302_service_is_active; then
        echo "拒绝卸载：检测到 $STEAM302_SERVICE_NAME 正在运行。"
        echo "请先在官方程序中停止并禁用该 systemd 服务，再执行卸载。"
        return 1
    fi
    if steam302_service_is_enabled; then
        echo "拒绝卸载：检测到 $STEAM302_SERVICE_NAME 仍设为开机启动。"
        echo "请先在官方程序中将该 systemd 服务改为禁用，再执行卸载。"
        return 1
    fi

    if [ ! -e "$STEAM302_INSTALL_DIR" ] && [ ! -L "$STEAM302_INSTALL_DIR" ]; then
        rm -f "$STEAM302_DESKTOP_FILE" || return 1
        echo "Steamcommunity 302 程序未安装，残留桌面快捷方式已删除。"
        return 0
    fi

    if ! rm -rf "$STEAM302_INSTALL_DIR"; then
        echo "Steamcommunity 302 程序目录删除失败。"
        return 1
    fi
    rm -f "$STEAM302_DESKTOP_FILE" || {
        echo "程序已删除，但桌面快捷方式删除失败：$STEAM302_DESKTOP_FILE"
        return 1
    }

    echo "Steamcommunity 302 程序文件已删除。"
    echo "工具箱托管的开机自启服务已移除；如仍有 hosts 或证书配置，请按官方程序说明恢复。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) install_steam302 ;;
        launch) launch_steam302 ;;
        start|enable) enable_steam302 ;;
        stop) stop_steam302_service ;;
        status) show_steam302_status ;;
        ensure) ensure_steam302_for_download ;;
        uninstall) uninstall_steam302 ;;
        *) echo "用法: $0 {install|launch|start|stop|status|ensure|uninstall}"; exit 1 ;;
    esac
fi
