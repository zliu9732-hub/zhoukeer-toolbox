#!/bin/bash
set -euo pipefail
# Synthetic archives and exported mocks; no upstream script runs against the real machine.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$PROJECT_ROOT/tests/test_sdweak_prepare.py"
