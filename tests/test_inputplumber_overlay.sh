#!/bin/bash
set -euo pipefail
# Synthetic archives and a private root directory; never executes an ELF or writes /usr.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$PROJECT_ROOT/tests/test_inputplumber_overlay.py"
