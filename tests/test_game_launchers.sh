#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"
MODULE="$PROJECT_ROOT/modules/game_launchers.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

SHORTCUTS="$TMP_ROOT/shortcuts.vdf"
INSTALLER="$TMP_ROOT/EpicGamesLauncherInstaller.msi"
EPIC_EXE="$TMP_ROOT/compatdata/123/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"

python3 "$HELPER" --help >/dev/null

python3 "$HELPER" --shortcut-file "$SHORTCUTS" add \
    --name "Epic Games 启动器" --exe "$INSTALLER" --start-dir "$TMP_ROOT"
python3 "$HELPER" --shortcut-file "$SHORTCUTS" add \
    --name "Epic Games 启动器" --exe "$INSTALLER" --start-dir "$TMP_ROOT" | grep -Fxq existing
# Steam 自己写出的 shortcuts.vdf 在根对象后可能保留额外结束标记。
# 模拟客户现有文件，确保更新主 EXE 时不会误报 trailing data，写回后会规范化。
printf '\010' >> "$SHORTCUTS"
python3 - "$SHORTCUTS" "$INSTALLER" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert "Epic Games 启动器".encode() in data
assert sys.argv[2].encode() in data
PY

mkdir -p "$(dirname "$EPIC_EXE")"
: > "$EPIC_EXE"
python3 "$HELPER" --shortcut-file "$SHORTCUTS" update \
    --old-exe "$INSTALLER" --new-exe "$EPIC_EXE" | grep -Fxq updated
python3 - "$SHORTCUTS" "$INSTALLER" "$EPIC_EXE" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert sys.argv[3].encode() in data
assert sys.argv[2].encode() not in data
assert data.endswith(b"\x08\x08")
PY

grep -Fq 'steamapps/compatdata' "$MODULE"
grep -Fq 'EpicGamesLauncher.exe' "$MODULE"
grep -Fq 'Battle.net.exe' "$MODULE"
grep -Fq 'start_launcher_watch' "$MODULE"
grep -Fq 'steam_shortcut.py' "$MODULE"

echo "PASS: Steam非Steam条目写入与安装后主EXE切换测试通过"
