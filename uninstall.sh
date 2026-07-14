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

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/.local/share/zhoukeer-toolbox"
CONFIG_BACKUP_DIR="$HOME/.config/zhoukeer-toolbox"
LOG_BACKUP_DIR="$HOME/.local/state/zhoukeer-toolbox"

confirm_action() {
    local prompt="$1"
    local answer

    read -r -p "$prompt [y/N]: " answer
    case "$answer" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            echo "已取消"
            return 1
            ;;
    esac
}

echo "================================"
echo " 周克儿工具箱 V4 卸载程序"
echo "================================"
echo "当前目录: $PROJECT_ROOT"
echo "模式: $([ "$DRY_RUN" -eq 1 ] && echo dry-run || echo uninstall)"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] 将删除桌面快捷方式: $HOME/Desktop/周克儿工具箱.desktop"
    echo "[dry-run] 将删除应用菜单入口: $HOME/.local/share/applications/zhoukeer-toolbox.desktop"
    echo "[dry-run] 将删除工具箱专用 Konsole 主题"
    echo "[dry-run] 默认安装目录匹配时将删除: $DEFAULT_INSTALL_DIR"
    echo "[dry-run] 可选择备份配置到: $CONFIG_BACKUP_DIR/settings.conf"
    echo "[dry-run] 可选择备份日志到: $LOG_BACKUP_DIR/logs"
    echo "[dry-run] 不会删除或备份任何文件。"
    exit 0
fi

if ! confirm_action "确认卸载周克儿工具箱？"; then
    exit 0
fi

PRESERVE_CONFIG=0
if confirm_action "是否保留用户配置？"; then
    PRESERVE_CONFIG=1
fi

PRESERVE_LOGS=0
if confirm_action "是否保留日志？"; then
    PRESERVE_LOGS=1
fi

rm -f "$HOME/Desktop/周克儿工具箱.desktop"
rm -f "$HOME/.local/share/applications/zhoukeer-toolbox.desktop"
rm -f "$HOME/.local/share/konsole/ZhoukeerToolbox.profile"
rm -f "$HOME/.local/share/konsole/ZhoukeerToolbox.colorscheme"
echo "已删除快捷方式"

if [ "$PRESERVE_CONFIG" -eq 1 ] && [ -f "$PROJECT_ROOT/config/settings.conf" ]; then
    mkdir -p "$CONFIG_BACKUP_DIR"
    cp "$PROJECT_ROOT/config/settings.conf" "$CONFIG_BACKUP_DIR/settings.conf"
    echo "已备份配置到: $CONFIG_BACKUP_DIR/settings.conf"
fi

if [ "$PRESERVE_LOGS" -eq 1 ] && [ -d "$PROJECT_ROOT/logs" ]; then
    mkdir -p "$LOG_BACKUP_DIR"
    cp -R "$PROJECT_ROOT/logs" "$LOG_BACKUP_DIR/"
    echo "已备份日志到: $LOG_BACKUP_DIR/logs"
fi

if [ "$PROJECT_ROOT" = "$DEFAULT_INSTALL_DIR" ]; then
    cd "$HOME" || exit 1
    rm -rf "$DEFAULT_INSTALL_DIR"
    echo "已删除安装目录: $DEFAULT_INSTALL_DIR"
else
    echo "当前目录不是默认安装目录，未删除源码目录: $PROJECT_ROOT"
fi

echo "卸载完成"
