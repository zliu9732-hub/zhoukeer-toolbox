#!/bin/bash

# Run the installation copy prepared from Renkit's checksum-pinned archive in
# a separate Bash process, so a caller's exit-code check cannot disable errexit.
set -eo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/modules/sdweak.sh"
[ "$#" -eq 1 ] || { echo "SDWEAK 安装文件位置无效。" >&2; exit 1; }
sdweak_check || exit 1
[ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ] || { echo "请先从 Renkit 确认安装 SDWEAK。" >&2; exit 1; }
cd -- "$1"
# This is the verified installation program, not a user-editable config file.
# Upstream does not support nounset; the device/consent checks above retain it.
set +u
source ./install.sh
