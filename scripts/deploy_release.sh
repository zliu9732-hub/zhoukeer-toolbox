#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "此脚本只生成并检查发布包，不自动暂存、提交、打标签或推送。"
echo "发布必须由维护者显式 git add 本次文件，并人工核对版本、diff、标签和 Release。"
bash scripts/package_release.sh
