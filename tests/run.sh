#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

for test_file in "$PROJECT_ROOT"/tests/test_*.sh; do
    if bash "$test_file"; then
        :
    else
        echo "FAIL: $(basename "$test_file")" >&2
        failures=$((failures + 1))
    fi
done

if [ "$failures" -ne 0 ]; then
    echo "测试失败：$failures 个脚本未通过。" >&2
    exit 1
fi

echo "全部测试通过。"
