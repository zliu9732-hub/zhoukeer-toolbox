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

SYSTEM="$(uname -s 2>/dev/null || echo unknown)"

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

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] 将复制程序文件到: $INSTALL_DIR"
    echo "[dry-run] 将保留已有配置: $INSTALL_DIR/config/settings.conf"
    echo "[dry-run] 将创建桌面快捷方式: $HOME/Desktop/周克儿工具箱.desktop"
    echo "[dry-run] 将创建应用菜单入口: $HOME/.local/share/applications/zhoukeer-toolbox.desktop"
    echo "[dry-run] 不会创建目录、复制文件或修改权限。"
    exit 0
fi

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

if [ ! -f "$INSTALL_DIR/config/settings.conf" ]; then
    if [ -f "$INSTALL_DIR/config/settings.example.conf" ]; then
        cp "$INSTALL_DIR/config/settings.example.conf" "$INSTALL_DIR/config/settings.conf"
        echo "已创建用户配置: $INSTALL_DIR/config/settings.conf"
    fi
else
    echo "保留现有用户配置: $INSTALL_DIR/config/settings.conf"
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
