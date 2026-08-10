#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zhoukeer-uninstall-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT INT TERM

mkdir -p "$TEST_ROOT/home/Desktop" "$TEST_ROOT/source"
cp "$PROJECT_ROOT/uninstall.sh" "$TEST_ROOT/source/uninstall.sh"
chmod +x "$TEST_ROOT/source/uninstall.sh"
printf '密码：test-only\n' > "$TEST_ROOT/home/Desktop/管理员密码.txt"
chmod 600 "$TEST_ROOT/home/Desktop/管理员密码.txt"

# 确认卸载、不保留配置、不保留日志、明确删除密码记录。
printf 'y\nn\nn\ny\n' | HOME="$TEST_ROOT/home" bash "$TEST_ROOT/source/uninstall.sh" >/dev/null

if [ -e "$TEST_ROOT/home/Desktop/管理员密码.txt" ] || [ -L "$TEST_ROOT/home/Desktop/管理员密码.txt" ]; then
    echo "FAIL: 卸载时确认删除后仍遗留密码记录" >&2
    exit 1
fi

mkdir -p "$TEST_ROOT/home/Desktop/管理员密码.txt"
printf 'y\nn\nn\ny\n' | HOME="$TEST_ROOT/home" bash "$TEST_ROOT/source/uninstall.sh" >/dev/null
if [ ! -d "$TEST_ROOT/home/Desktop/管理员密码.txt" ]; then
    echo "FAIL: 卸载脚本删除了同名目录" >&2
    exit 1
fi

HOME="$TEST_ROOT/home" bash "$TEST_ROOT/source/uninstall.sh" --dry-run |
    grep -Fq '卸载时会询问是否删除桌面明文密码记录'

echo "PASS: 卸载时明文密码记录处理测试通过"
