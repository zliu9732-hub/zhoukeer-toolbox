#!/bin/bash

set -u

install_dir="${1:-}"
log_file="${2:-}"
pid_file="${3:-}"

case "$install_dir" in
    /*) ;;
    *) echo "Steamcommunity 302 安装目录无效。"; exit 1 ;;
esac
case "$log_file" in
    "$(dirname "$install_dir")"/*) ;;
    *) echo "Steamcommunity 302 日志路径无效。"; exit 1 ;;
esac
case "$pid_file" in
    "$install_dir"/*) ;;
    *) echo "Steamcommunity 302 PID 路径无效。"; exit 1 ;;
esac

[ -x "$install_dir/steamcommunity_302.cli" ] || {
    echo "Steamcommunity 302 CLI 不存在或不可执行。"
    exit 1
}
cd -- "$install_dir" || exit 1
rm -f -- "$install_dir/S302.exit" "$pid_file"
nohup ./steamcommunity_302.cli >>"$log_file" 2>&1 </dev/null &
pid=$!
case "$pid" in
    ''|*[!0-9]*) exit 1 ;;
esac
printf '%s\n' "$pid" > "$pid_file"
