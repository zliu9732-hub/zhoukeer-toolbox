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
    RUSTDESK_DOWNLOAD
    RUSTDESK_SHA256
    RUSTDESK_ID_SERVER
    RUSTDESK_RELAY_SERVER
    RUSTDESK_API
    RUSTDESK_KEY
    RUSTDESK_CONFIG_STRING
    TODESK_ARCHIVE_URL
    TODESK_PACKAGE_NAME
    TODESK_PACKAGE_SHA256
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

mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/config" "$INSTALL_DIR/apps" "$INSTALL_DIR/logs"
mkdir -p "$HOME/.local/share/applications"

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
        copy_file "$src" "$INSTALL_DIR/$rel"
    done
}

for file in main.sh main_old.sh install.sh uninstall.sh update.sh bootstrap.sh README.md VERSION .gitignore; do
    if [ -f "$SOURCE_ROOT/$file" ]; then
        copy_file "$SOURCE_ROOT/$file" "$INSTALL_DIR/$file"
    fi
done

copy_dir_files core
copy_dir_files modules
copy_dir_files utils
copy_dir_files config
copy_dir_files assets

if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$INSTALL_DIR/config/settings.example.conf" ]; then
        cp "$INSTALL_DIR/config/settings.example.conf" "$CONFIG_FILE"
        echo "已创建用户配置: $CONFIG_FILE"
    fi
else
    prepare_config_migration "$CONFIG_FILE" "$INSTALL_DIR/config/settings.example.conf" || exit 1
    migrate_existing_config "$CONFIG_FILE" || exit 1
fi

find "$INSTALL_DIR" -maxdepth 3 -type f -name "*.sh" -exec chmod +x {} +

DESKTOP_FILE="$HOME/Desktop/周克儿工具箱.desktop"
APPLICATION_FILE="$HOME/.local/share/applications/zhoukeer-toolbox.desktop"
ICON_PATH="$INSTALL_DIR/assets/icon.png"
ICON_ENTRY="utilities-terminal"

if [ -f "$ICON_PATH" ]; then
    ICON_ENTRY="$ICON_PATH"
fi

if [ ! -d "$HOME/Desktop" ]; then
    mkdir -p "$HOME/Desktop"
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=周克儿工具箱
Comment=Steam Deck工具箱
Exec=konsole --workdir "$INSTALL_DIR" -e bash "$INSTALL_DIR/main.sh"
Icon=$ICON_ENTRY
Terminal=false
Categories=Utility;
EOF

cp "$DESKTOP_FILE" "$APPLICATION_FILE"
chmod +x "$DESKTOP_FILE" "$APPLICATION_FILE"

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
