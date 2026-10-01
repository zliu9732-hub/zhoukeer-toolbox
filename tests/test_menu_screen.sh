#!/bin/bash
set -euo pipefail
# Private PTYs and mock actions only; no graphical terminal or system changes.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$PROJECT_ROOT/tests/test_menu_screen.py"
