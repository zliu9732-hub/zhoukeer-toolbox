#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

STEAM302_VERSION="14.0.02"
STEAM302_ARCHIVE_URL="https://www.dogfight360.com/blog/wp-content/uploads/2026/02/steamcommunity_302_Linux_AMD64_V14.0.02.tar.gz"
STEAM302_ARCHIVE_MD5="4b9994102b2256ca5fdf2e806a2c7035"
STEAM302_ARCHIVE_SHA256="5e006f015c807679ef800a87fa7b788562901ad04d7899ade2648f82b4c4a11f"
STEAM302_INSTALL_DIR="$APP_DIR/steamcommunity302"
STEAM302_DESKTOP_FILE="$HOME/Desktop/Steamcommunity 302.desktop"
STEAM302_SERVICE_NAME="steamcommunity302.service"
STEAM302_CONNECT_TIMEOUT=15
STEAM302_MAX_TIME=1200
STEAM302_RETRIES=3

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
    echo "========================================"
    echo " Steamcommunity 302 安装与安全说明"
    echo "========================================"
    echo "版本：V$STEAM302_VERSION（Linux AMD64 / Steam Deck）"
    echo "来源：Dogfight360 官方发布页"
    echo ""
    echo "工具箱只会："
    echo "- 从固定的官方 HTTPS 地址下载并同时校验 MD5、SHA256"
    echo "- 解压到用户目录：$STEAM302_INSTALL_DIR"
    echo "- 创建桌面快捷方式"
    echo ""
    echo "工具箱不会调用 pacman，不会关闭 SteamOS 只读保护，"
    echo "也不会自行启用或启动 systemd 系统服务。"
    echo ""
    echo "重要：官方程序启动加速时会请求管理员权限，并可能安装根证书、"
    echo "修改 hosts 或拦截 DNS。请只开启自己理解并需要的功能。"
}

confirm_steam302_install() {
    local answer

    show_steam302_risk_notice
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    echo ""
    read -r -p "确认安装请输入 INSTALL：" answer
    [ "$answer" = "INSTALL" ]
}

confirm_steam302_uninstall() {
    local answer

    echo "将删除 Steamcommunity 302 程序目录和工具箱创建的桌面快捷方式。"
    echo "不会代替官方程序停止服务、恢复 hosts、移除证书或修改 systemd。"
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

confirm_steam302_service_start() {
    local answer

    echo "将启动官方 Steamcommunity 302 后台服务。"
    echo "该服务会使用你已在官方界面保存的代理、hosts/DNS 和证书设置。"
    echo "工具箱不会新增或修改这些设置。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi

    read -r -p "确认启动请输入 START：" answer
    [ "$answer" = "START" ]
}

start_steam302_service() {
    steam302_is_installed || {
        echo "Steamcommunity 302 尚未安装。"
        return 1
    }
    require_command systemctl || return 1
    if steam302_service_is_active; then
        echo "加速服务已在运行。"
        return 0
    fi
    if ! steam302_service_exists; then
        echo "尚未找到官方后台服务。"
        echo "请先打开 Steamcommunity 302 官方界面，完成首次设置并启用“开机运行—后台服务(无界面)”。"
        echo "完成一次后，之后即可在工具箱中一键启动。"
        return 1
    fi

    confirm_steam302_service_start || {
        echo "已取消启动加速服务。"
        return 0
    }
    if ! toolbox_sudo systemctl start "$STEAM302_SERVICE_NAME"; then
        echo "加速服务启动失败，官方设置保持不变。"
        return 1
    fi
    if steam302_service_is_active; then
        echo "加速服务已启动。"
        return 0
    fi

    echo "systemd 已收到启动请求，但服务未进入运行状态。请在官方界面查看日志。"
    return 1
}

download_steam302_archive() {
    local destination="$1"

    echo "正在下载 Steamcommunity 302 V$STEAM302_VERSION..."
    curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout "$STEAM302_CONNECT_TIMEOUT" \
        --max-time "$STEAM302_MAX_TIME" \
        --retry "$STEAM302_RETRIES" \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$destination" \
        "$STEAM302_ARCHIVE_URL"
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

    echo "MD5 与 SHA256 校验均通过。"
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
            if (entry == "Steamcommunity_302/run_运行.sh") found_run = 1
            if (entry == "Steamcommunity_302/Steamcommunity_302") found_app = 1
            if (entry == "Steamcommunity_302/.launcher/launcher_启动器.sh") found_launcher = 1
        }
        END {
            if (!found_run || !found_app || !found_launcher) exit 1
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

    echo "已创建桌面快捷方式：$STEAM302_DESKTOP_FILE"
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
            echo "Steamcommunity 302 V$STEAM302_VERSION 已安装，正在修复桌面快捷方式。"
            create_steam302_shortcut || {
                echo "桌面快捷方式创建失败。"
                return 1
            }
            echo "工具箱没有启动或启用任何系统服务。"
            echo "如需开机加速，请在官方 GUI 中选择“开机运行—后台服务(无界面)”。"
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

    if ! create_steam302_shortcut; then
        echo "桌面快捷方式创建失败，正在恢复已有版本。"
        return 1
    fi

    STEAM302_SWAP_FINISHED=1
    rm -rf "$STEAM302_BACKUP_DIR"
    STEAM302_BACKUP_DIR=""
    echo "Steamcommunity 302 V$STEAM302_VERSION 安装完成。"
    echo "工具箱没有启动或启用任何系统服务。"
    echo "请在桌面模式打开“Steamcommunity 302”快捷方式完成首次设置。"
    echo "如需开机加速，请在官方 GUI 中选择“开机运行—后台服务(无界面)”。"
    echo "该选择会涉及管理员权限、根证书以及 hosts / DNS 修改，请按需开启。"
)

show_steam302_status() {
    local version

    if steam302_is_installed; then
        version="$(steam302_installed_version)"
        [ -n "$version" ] || version="未知（可能由官方程序直接解压）"
        echo "Steamcommunity 302：已安装"
        echo "版本：$version"
        echo "目录：$STEAM302_INSTALL_DIR"
        if [ -x "$STEAM302_DESKTOP_FILE" ]; then
            echo "桌面快捷方式：已创建"
        else
            echo "桌面快捷方式：缺失，可重新执行 install 修复"
        fi
    else
        echo "Steamcommunity 302：未安装"
    fi

    if steam302_service_is_active; then
        echo "后台服务：正在运行"
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

    if steam302_service_is_active; then
        echo "拒绝卸载：检测到 $STEAM302_SERVICE_NAME 正在运行。"
        echo "请先打开官方 GUI 停止服务，并将“开机运行—后台服务(无界面)”改为“禁用”。"
        echo "确认后台服务已停止且 hosts / DNS 已恢复后，再执行卸载。"
        return 1
    fi
    if steam302_service_is_enabled; then
        echo "拒绝卸载：检测到 $STEAM302_SERVICE_NAME 仍设为开机启动。"
        echo "请先在官方 GUI 将“开机运行—后台服务(无界面)”改为“禁用”，再执行卸载。"
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
    echo "工具箱没有修改 systemd、hosts 或证书；如仍有相关配置，请在官方 GUI 中先完成停用和恢复。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) install_steam302 ;;
        launch) launch_steam302 ;;
        start) start_steam302_service ;;
        status) show_steam302_status ;;
        uninstall) uninstall_steam302 ;;
        *) echo "用法: $0 {install|launch|start|status|uninstall}"; exit 1 ;;
    esac
fi
