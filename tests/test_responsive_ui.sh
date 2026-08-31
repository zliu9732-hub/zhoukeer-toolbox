#!/bin/bash
set -euo pipefail

# Python 只在临时目录和伪终端中加载 UI；不执行主程序或系统功能。
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$PROJECT_ROOT/tests/test_responsive_ui.py"
