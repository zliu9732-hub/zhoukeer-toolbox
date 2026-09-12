#!/bin/bash
# No live hardware, network, privilege changes, or service operations.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
python3 "$PROJECT_ROOT/tests/test_ally_fan_controller.py" \
    "$PROJECT_ROOT/third_party/allycenter-zh-v1.2.0/main.py"
python3 "$PROJECT_ROOT/tests/test_ally_fan_profiles.py" \
    "$PROJECT_ROOT/third_party/allycenter-zh-v1.2.0/main.py"
node "$PROJECT_ROOT/tests/test_ally_fan_frontend.cjs" \
    "$PROJECT_ROOT/third_party/allycenter-zh-v1.2.0/dist/index.js"
