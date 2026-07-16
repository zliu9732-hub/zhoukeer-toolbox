#!/bin/bash

set -u

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        *)
            echo "未知参数: $arg"
            exit 1
            ;;
    esac
done

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${ZHOUKEER_INSTALL_DIR:-$HOME/.local/share/zhoukeer-toolbox}"
CONFIG_FILE="$INSTALL_DIR/config/settings.conf"
CONFIG_EXAMPLE_FILE="$SOURCE_ROOT/config/settings.example.conf"

CONFIG_MIGRATION_VARIABLES=(
    DUAL_BOOT_TIMEOUT
    TODESK_ARCHIVE_URL
    TODESK_REPOSITORY_URL
    TODESK_REPOSITORY_COMMIT
    TODESK_PACKAGE_NAME
    TODESK_PACKAGE_SHA256
    DECKY_LOADER_URL
    DECKY_LOADER_SHA256
    DECKY_SERVICE_URL
    DECKY_SERVICE_SHA256
    DECKY_LSFG_URL
    DECKY_LSFG_SHA256
    DECKY_FSR4_URL
    DECKY_FSR4_SHA256
    DECKY_CHEATDECK_URL
    DECKY_CHEATDECK_SHA256
    DECKY_SIMPLE_TDP_URL
    DECKY_SIMPLE_TDP_VERSION
    DECKY_SIMPLE_TDP_SHA256
    DECKY_UNIFIDECK_URL
    DECKY_UNIFIDECK_VERSION
    DECKY_UNIFIDECK_SHA256
    GE_PROTON_URL
    GE_PROTON_VERSION
    GE_PROTON_SHA256
)
CONFIG_MIGRATION_KEYS=()
CONFIG_MIGRATION_DEFAULTS=()

get_config_assignment() {
    local file="$1"
    local key="$2"

    awk -v key="$key" '
        $0 ~ "^[[:space:]]*(export[[:space:]]+)?" key "[[:space:]]*=" {
            assignment = $0
            found = 1
        }
        END {
            if (found) {
                print assignment
            } else {
                exit 1
            }
        }
    ' "$file"
}

assignment_is_empty() {
    local assignment="$1"
    local value

    value="${assignment#*=}"
    value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    case "$value" in
        ""|'""'|"''")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

prepare_config_migration() {
    local config_file="$1"
    local example_file="$2"
    local key
    local current_assignment
    local default_assignment

    CONFIG_MIGRATION_KEYS=()
    CONFIG_MIGRATION_DEFAULTS=()

    if [ ! -f "$example_file" ]; then
        echo "缺少配置示例文件: $example_file"
        return 1
    fi

    for key in "${CONFIG_MIGRATION_VARIABLES[@]}"; do
        if ! default_assignment="$(get_config_assignment "$example_file" "$key")"; then
            echo "配置示例缺少默认项: $key"
            return 1
        fi

        if [ ! -f "$config_file" ]; then
            CONFIG_MIGRATION_KEYS+=("$key")
            CONFIG_MIGRATION_DEFAULTS+=("$default_assignment")
            continue
        fi

        if ! current_assignment="$(get_config_assignment "$config_file" "$key")"; then
            CONFIG_MIGRATION_KEYS+=("$key")
            CONFIG_MIGRATION_DEFAULTS+=("$default_assignment")
            continue
        fi

        # 示例默认值同样为空时，现有空赋值已经与默认配置一致，无需反复迁移。
        if assignment_is_empty "$current_assignment" && ! assignment_is_empty "$default_assignment"; then
            CONFIG_MIGRATION_KEYS+=("$key")
            CONFIG_MIGRATION_DEFAULTS+=("$default_assignment")
        fi
    done
}

sanitize_retired_rustdesk_config() {
    local config_file="$1"
    local sanitized_file

    sanitized_file="$(mktemp "$config_file.sanitize.XXXXXX")" || return 1
    awk '
        /^[[:space:]]*(export[[:space:]]+)?RUSTDESK_[A-Z0-9_]+[[:space:]]*=/ { next }
        /RustDesk/ { next }
        { print }
    ' "$config_file" > "$sanitized_file" || {
        rm -f -- "$sanitized_file"
        return 1
    }
    chmod 600 "$sanitized_file" || {
        rm -f -- "$sanitized_file"
        return 1
    }
    mv -f -- "$sanitized_file" "$config_file"
}

sanitize_retired_decky_installer_config() {
    local config_file="$1"
    local sanitized_file

    sanitized_file="$(mktemp "$config_file.sanitize.XXXXXX")" || return 1
    awk '
        /^[[:space:]]*(export[[:space:]]+)?DECKY_INSTALLER_(URL|SHA256)[[:space:]]*=/ { next }
        /Decky Loader 国内安装器/ { next }
        { print }
    ' "$config_file" > "$sanitized_file" || {
        rm -f -- "$sanitized_file"
        return 1
    }
    chmod 600 "$sanitized_file" || {
        rm -f -- "$sanitized_file"
        return 1
    }
    mv -f -- "$sanitized_file" "$config_file"
}

write_config_assignment() {
    local input_file="$1"
    local output_file="$2"
    local key="$3"
    local default_assignment="$4"

    awk -v key="$key" -v replacement="$default_assignment" '
        $0 ~ "^[[:space:]]*(export[[:space:]]+)?" key "[[:space:]]*=" {
            if (!replaced) {
                print replacement
                replaced = 1
            }
            next
        }
        { print }
        END {
            if (!replaced) {
                print replacement
            }
        }
    ' "$input_file" > "$output_file"
}

migrate_existing_config() {
    local config_file="$1"
    local backup_file
    local working_file
    local next_file
    local index

    if [ "${#CONFIG_MIGRATION_KEYS[@]}" -eq 0 ]; then
        echo "现有用户配置无需迁移: $config_file"
        return 0
    fi

    backup_file="$config_file.bak.$(date '+%Y%m%d%H%M%S').$$"
    if ! cp -p "$config_file" "$backup_file"; then
        echo "备份配置失败，已停止迁移: $config_file"
        return 1
    fi
    chmod 600 "$backup_file" || {
        rm -f "$backup_file"
        echo "无法限制配置备份权限，已停止迁移: $config_file"
        return 1
    }
    echo "已备份原配置: $backup_file"

    working_file="$(mktemp "$config_file.migrate.XXXXXX")" || return 1
    if ! cp -p "$config_file" "$working_file"; then
        rm -f "$working_file"
        return 1
    fi

    for index in "${!CONFIG_MIGRATION_KEYS[@]}"; do
        next_file="$(mktemp "$config_file.migrate.XXXXXX")" || {
            rm -f "$working_file"
            return 1
        }
        if ! cp -p "$working_file" "$next_file"; then
            rm -f "$working_file" "$next_file"
            return 1
        fi

        if ! write_config_assignment \
            "$working_file" \
            "$next_file" \
            "${CONFIG_MIGRATION_KEYS[$index]}" \
            "${CONFIG_MIGRATION_DEFAULTS[$index]}"; then
            rm -f "$working_file" "$next_file"
            echo "迁移配置失败，原配置保持不变。"
            return 1
        fi

        rm -f "$working_file"
        working_file="$next_file"
    done

    if ! mv -f "$working_file" "$config_file"; then
        rm -f "$working_file"
        echo "替换迁移配置失败，备份保存在: $backup_file"
        return 1
    fi

    for index in "${!CONFIG_MIGRATION_KEYS[@]}"; do
        echo "已补充默认配置: ${CONFIG_MIGRATION_KEYS[$index]}"
    done
}

show_config_migration_dry_run() {
    local key

    prepare_config_migration "$CONFIG_FILE" "$CONFIG_EXAMPLE_FILE" || return 1

    if [ "${#CONFIG_MIGRATION_KEYS[@]}" -eq 0 ]; then
        echo "[dry-run] 配置无需迁移"
        return 0
    fi

    for key in "${CONFIG_MIGRATION_KEYS[@]}"; do
        echo "[dry-run] 准备补充默认配置: $key"
    done
}

SYSTEM="$(uname -s 2>/dev/null || echo unknown)"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] 将复制程序文件到: $INSTALL_DIR"
    if [ -f "$CONFIG_FILE" ]; then
        echo "[dry-run] 将保留已有非空配置: $CONFIG_FILE"
    else
        echo "[dry-run] 将创建用户配置: $CONFIG_FILE"
    fi
    show_config_migration_dry_run
    echo "[dry-run] 将创建桌面快捷方式: $HOME/Desktop/周克儿工具箱.desktop"
    echo "[dry-run] 将创建应用菜单入口: $HOME/.local/share/applications/zhoukeer-toolbox.desktop"
    echo "[dry-run] 将创建工具箱专用的 Konsole 大字体和背景主题"
    echo "[dry-run] 不会创建目录、复制文件或修改权限。"
    exit $?
fi

if [ "$SYSTEM" = "Darwin" ]; then
    echo "检测到 macOS。安装目标是 SteamOS/Arch Linux，已停止安装。"
    echo "开发调试请在项目目录运行: bash main.sh"
    exit 0
fi

if [ "$SYSTEM" != "Linux" ]; then
    echo "不支持的系统: $SYSTEM"
    exit 1
fi

echo "================================"
echo " 周克儿工具箱 V4 安装程序"
echo "================================"
echo "来源目录: $SOURCE_ROOT"
echo "安装目录: $INSTALL_DIR"
echo "模式: $([ "$DRY_RUN" -eq 1 ] && echo dry-run || echo install)"
echo ""

INSTALL_PARENT="$(dirname "$INSTALL_DIR")"
INSTALL_NAME="$(basename "$INSTALL_DIR")"
STAGING_DIR="$INSTALL_PARENT/.${INSTALL_NAME}.install.$$"
BACKUP_DIR="$INSTALL_PARENT/.${INSTALL_NAME}.backup.$$"
SWAP_STARTED=0
SWAP_FINISHED=0

cleanup_install() {
    if [ -n "${STAGING_DIR:-}" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf -- "$STAGING_DIR"
    fi

    if [ "$SWAP_STARTED" -eq 1 ] && [ "$SWAP_FINISHED" -eq 0 ] && \
        [ -d "$BACKUP_DIR" ] && [ ! -e "$INSTALL_DIR" ]; then
        mv -- "$BACKUP_DIR" "$INSTALL_DIR" || \
            echo "警告：自动恢复旧版本失败，旧文件保存在: $BACKUP_DIR"
    fi
}

trap 'exit 130' INT TERM
trap cleanup_install EXIT

mkdir -p "$INSTALL_PARENT"
rm -rf -- "$STAGING_DIR" "$BACKUP_DIR"
mkdir -p "$STAGING_DIR/config" "$STAGING_DIR/apps" "$STAGING_DIR/logs"
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/konsole"

# 配置、已下载应用和日志属于用户数据，先复制到新版本暂存目录。
# 新程序完全准备好后才会一次切换，避免更新中断形成新旧混合版本。
if [ -d "$INSTALL_DIR" ]; then
    for persistent_dir in config apps logs; do
        if [ -d "$INSTALL_DIR/$persistent_dir" ]; then
            cp -a "$INSTALL_DIR/$persistent_dir/." "$STAGING_DIR/$persistent_dir/" || exit 1
        fi
    done
fi

copy_file() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

copy_dir_files() {
    local dir="$1"

    if [ ! -d "$SOURCE_ROOT/$dir" ]; then
        return 0
    fi

    find "$SOURCE_ROOT/$dir" -type f | while IFS= read -r src; do
        rel="${src#$SOURCE_ROOT/}"
        case "$rel" in
            config/settings.conf|logs/*|apps/*)
                continue
                ;;
        esac
        copy_file "$src" "$STAGING_DIR/$rel"
    done
}

copy_zhoukeer_localizer() {
    local source_dir="$SOURCE_ROOT/decky-plugins/zhoukeer-localizer"
    local relative_file

    # Decky 运行只需要清单与构建后的前端文件，不把开发依赖带入更新包。
    for relative_file in plugin.json package.json README.md LICENSE dist/index.js; do
        if [ -f "$source_dir/$relative_file" ]; then
            copy_file "$source_dir/$relative_file" \
                "$STAGING_DIR/decky-plugins/zhoukeer-localizer/$relative_file"
        fi
    done
}

for file in main.sh main_old.sh launch.sh install.sh uninstall.sh update.sh bootstrap.sh i README.md VERSION .gitignore; do
    if [ -f "$SOURCE_ROOT/$file" ]; then
        copy_file "$SOURCE_ROOT/$file" "$STAGING_DIR/$file"
    fi
done

copy_dir_files core
copy_dir_files modules
copy_dir_files utils
copy_dir_files config
copy_dir_files assets
copy_dir_files scripts
copy_zhoukeer_localizer

# 标记由安装器管理的目录，启动器只在这类目录中执行自动更新。
printf '%s\n' "zhoukeer-toolbox" > "$STAGING_DIR/.zhoukeer-installed"

# RustDesk 已从工具箱退役。更新时同步清除主配置和历史备份里的服务器字段，
# 避免旧 ID、中继、API 或公钥继续留在安装目录中。
while IFS= read -r retired_config; do
    sanitize_retired_rustdesk_config "$retired_config" || {
        echo "清理旧 RustDesk 配置失败: $retired_config"
        exit 1
    }
    sanitize_retired_decky_installer_config "$retired_config" || {
        echo "清理旧 Decky 外层安装器配置失败: $retired_config"
        exit 1
    }
done < <(find "$STAGING_DIR/config" -maxdepth 1 -type f -name 'settings.conf*' -print)
rm -f -- "$STAGING_DIR/apps/rustdesk.AppImage"

CONFIG_FILE="$STAGING_DIR/config/settings.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$STAGING_DIR/config/settings.example.conf" ]; then
        cp "$STAGING_DIR/config/settings.example.conf" "$CONFIG_FILE"
        echo "已创建用户配置: $CONFIG_FILE"
    fi
else
    prepare_config_migration "$CONFIG_FILE" "$STAGING_DIR/config/settings.example.conf" || exit 1
    migrate_existing_config "$CONFIG_FILE" || exit 1
fi

if ! find "$STAGING_DIR" -type f -name '*.sh' -exec bash -n {} \;; then
    echo "新版本包含Shell语法错误，旧版本保持不变。"
    exit 1
fi
find "$STAGING_DIR" -maxdepth 3 -type f -name "*.sh" -exec chmod +x {} +

# 安装目录即将被原子替换。先离开它，避免从工具箱内部发起更新时，
# 当前 Shell 落在已删除目录并持续输出 getcwd/chdir 错误。
if ! cd "$INSTALL_PARENT" 2>/dev/null; then
    cd "$HOME" 2>/dev/null || cd / || exit 1
fi

if [ -d "$INSTALL_DIR" ]; then
    SWAP_STARTED=1
    if ! mv -- "$INSTALL_DIR" "$BACKUP_DIR"; then
        echo "无法备份旧版本，安装已停止。"
        exit 1
    fi
fi

if ! mv -- "$STAGING_DIR" "$INSTALL_DIR"; then
    echo "无法启用新版本，正在恢复旧版本。"
    exit 1
fi
SWAP_FINISHED=1

if [ -d "$BACKUP_DIR" ]; then
    rm -rf -- "$BACKUP_DIR"
fi

DESKTOP_FILE="$HOME/Desktop/周克儿工具箱.desktop"
APPLICATION_FILE="$HOME/.local/share/applications/zhoukeer-toolbox.desktop"
ICON_PATH="$INSTALL_DIR/assets/icon-round.png"
BACKGROUND_PATH="$INSTALL_DIR/assets/background.png"
KONSOLE_PROFILE="$HOME/.local/share/konsole/ZhoukeerToolbox.profile"
KONSOLE_COLOR_SCHEME="$HOME/.local/share/konsole/ZhoukeerToolbox.colorscheme"
ICON_ENTRY="utilities-terminal"

if [ -f "$ICON_PATH" ]; then
    ICON_ENTRY="$ICON_PATH"
fi

if [ ! -d "$HOME/Desktop" ]; then
    mkdir -p "$HOME/Desktop"
fi

if [ -f "$INSTALL_DIR/assets/Zhoukeer.colorscheme.in" ] && [ -f "$BACKGROUND_PATH" ]; then
    awk -v wallpaper="$BACKGROUND_PATH" '
        /^Wallpaper=@WALLPAPER@$/ { print "Wallpaper=" wallpaper; next }
        { print }
    ' "$INSTALL_DIR/assets/Zhoukeer.colorscheme.in" > "$KONSOLE_COLOR_SCHEME"

    cat > "$KONSOLE_PROFILE" <<EOF
[Appearance]
ColorScheme=ZhoukeerToolbox
Font=Noto Sans Mono CJK SC,17,-1,5,50,0,0,0,0,0
LineSpacing=0

[General]
Name=周克儿工具箱
Parent=FALLBACK/
TerminalColumns=102
TerminalMargin=6
TerminalRows=28
EOF
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=周克儿工具箱
Comment=Steam Deck工具箱
Exec=/usr/bin/env bash "$INSTALL_DIR/launch.sh"
Icon=$ICON_ENTRY
Terminal=false
Categories=Utility;
EOF

cp "$DESKTOP_FILE" "$APPLICATION_FILE"
chmod +x "$DESKTOP_FILE" "$APPLICATION_FILE"

# 更新工具箱时，为已安装的Firefox刷新URL处理器，供战网等应用调用。
if [ -x "$INSTALL_DIR/apps/firefox/firefox" ] && \
    [ -f "$INSTALL_DIR/modules/software.sh" ]; then
    ZHOUKEER_AUTO_CONFIRM=1 \
        bash "$INSTALL_DIR/modules/software.sh" browser || \
        echo "Firefox网页链接处理器刷新失败，可在工具箱中重新点击安装Firefox。"
fi

if [ -f "$INSTALL_DIR/core/env.sh" ]; then
    # shellcheck disable=SC1091
    source "$INSTALL_DIR/core/env.sh"
    # shellcheck disable=SC1091
    source "$INSTALL_DIR/core/logger.sh"
    ensure_runtime_dirs
    log "安装完成: $INSTALL_DIR"
fi

echo ""
echo "安装完成"
echo "桌面快捷方式: $DESKTOP_FILE"
echo "应用菜单入口: $APPLICATION_FILE"
echo ""
echo "启动命令: bash \"$INSTALL_DIR/main.sh\""
