#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

confirm_action() {
    local prompt="$1"
    local answer

    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "$prompt [已通过图形界面确认]"
        return 0
    fi

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

safe_remove_contents() {
    local target="$1"
    local label="$2"

    if [ -z "$target" ] || [ "$target" = "/" ] || [ "$target" = "$HOME" ]; then
        echo "拒绝清理危险路径: $target"
        log "拒绝清理危险路径: $target"
        return 1
    fi

    if [ ! -d "$target" ]; then
        echo "跳过不存在的目录: $target"
        log "跳过不存在的目录: $target"
        return 0
    fi

    if confirm_action "将清理 $label: $target，是否继续？"; then
        find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        local status=$?
        if [ "$status" -eq 0 ]; then
            echo "已清理: $label"
            log "已清理: $label ($target)"
        else
            echo "清理失败: $label"
            log "清理失败: $label ($target)"
        fi
        return "$status"
    fi

    return 1
}

pause_return() {
    read -r -p "回车返回"
}
