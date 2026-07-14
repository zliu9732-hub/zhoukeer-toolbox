#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

echo "网络检测中..."

ping -c 1 8.8.8.8 >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "网络正常"
    log "网络检测正常"
else
    echo "网络异常"
    log "网络检测异常"
fi
