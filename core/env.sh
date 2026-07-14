#!/bin/bash

if [ -n "${ZHOUKEER_ENV_LOADED:-}" ]; then
    return 0
fi

ZHOUKEER_ENV_LOADED=1

SCRIPT_PATH="${BASH_SOURCE[0]}"
CORE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROJECT_ROOT="$(cd "$CORE_DIR/.." && pwd)"

TOOLBOX_VERSION="V4"
TOOLBOX_NAME="周克儿工具箱"

CONFIG_FILE="$PROJECT_ROOT/config/settings.conf"
CONFIG_EXAMPLE_FILE="$PROJECT_ROOT/config/settings.example.conf"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
APP_DIR="${ZHOUKEER_APP_DIR:-$PROJECT_ROOT/apps}"
ASSET_DIR="$PROJECT_ROOT/assets"

ensure_runtime_dirs() {
    mkdir -p "$LOG_DIR" "$APP_DIR"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    elif [ -f "$CONFIG_EXAMPLE_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_EXAMPLE_FILE"
    fi
}
