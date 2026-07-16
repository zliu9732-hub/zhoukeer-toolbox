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
DIRECT_PREFIX="$TMP_ROOT/direct-prefix"
DIRECT_EXE="$DIRECT_PREFIX/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
FAKE_PROTON="$TMP_ROOT/GE-Proton-test/proton"
PROTON_LOG="$TMP_ROOT/proton.log"
EXISTING_STEAM="$TMP_ROOT/existing-steam"
EXISTING_SHORTCUTS="$EXISTING_STEAM/userdata/123/config/shortcuts.vdf"
EXISTING_BATTLENET="$EXISTING_STEAM/steamapps/compatdata/777/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
EXISTING_APP_DIR="$TMP_ROOT/existing-apps"
FAKE_HOME="$TMP_ROOT/home"

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

# 同名旧安装器条目再次添加时应原地切换，避免升级后出现两个Epic/战网。
WRAPPER="$TMP_ROOT/launch-epic.sh"
: > "$WRAPPER"
python3 "$HELPER" --shortcut-file "$SHORTCUTS" add \
    --name "Epic Games 启动器" --exe "$WRAPPER" --start-dir "$TMP_ROOT" | grep -Fxq updated
python3 - "$SHORTCUTS" "$WRAPPER" "$EPIC_EXE" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert data.count("Epic Games 启动器".encode()) == 1
assert sys.argv[2].encode() in data
assert sys.argv[3].encode() not in data
PY

mkdir -p "$(dirname "$FAKE_PROTON")"
cat > "$FAKE_PROTON" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" > "${PROTON_LOG:?}"
target="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
mkdir -p "$(dirname "$target")"
: > "$target"
SCRIPT
chmod +x "$FAKE_PROTON"

direct_result="$(
    MODULE="$MODULE" PROTON_LOG="$PROTON_LOG" DIRECT_PREFIX="$DIRECT_PREFIX" \
        FAKE_PROTON="$FAKE_PROTON" INSTALLER="$INSTALLER" TMP_ROOT="$TMP_ROOT" \
        bash -c '
            source "$MODULE"
            POST_INSTALL_TIMEOUT=0
            run_launcher_installer epic "$TMP_ROOT/steam" "$INSTALLER" "$DIRECT_PREFIX" "$FAKE_PROTON"
        '
)"
[ "$direct_result" = "$DIRECT_EXE" ] || {
    echo "FAIL: 直接调用Proton后没有返回Epic主EXE" >&2
    exit 1
}
grep -Fq "run msiexec /i $INSTALLER" "$PROTON_LOG" || {
    echo "FAIL: Epic MSI没有通过Proton的msiexec直接运行" >&2
    exit 1
}

generated_wrapper="$(
    MODULE="$MODULE" DIRECT_PREFIX="$DIRECT_PREFIX" FAKE_PROTON="$FAKE_PROTON" \
        DIRECT_EXE="$DIRECT_EXE" TMP_ROOT="$TMP_ROOT" \
        bash -c '
            source "$MODULE"
            create_launcher_wrapper epic "$TMP_ROOT/steam" "$DIRECT_PREFIX" \
                "$FAKE_PROTON" "$DIRECT_EXE" "$TMP_ROOT"
        '
)"
[ -x "$generated_wrapper" ] || {
    echo "FAIL: 没有生成可执行的Linux启动包装器" >&2
    exit 1
}
grep -Fq 'STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"' "$generated_wrapper" || {
    echo "FAIL: 启动包装器没有复用安装前缀" >&2
    exit 1
}

# 战网第一次不能用当前兼容层时，必须在 PE 与 Proton 10.0-4 间自动切换。
PE_RUNNER="$TMP_ROOT/steam/steamapps/common/Proton - Experimental/proton"
P10_RUNNER="$TMP_ROOT/steam/steamapps/common/Proton 10.0-4/proton"
mkdir -p "$(dirname "$PE_RUNNER")" "$(dirname "$P10_RUNNER")"
cat > "$PE_RUNNER" <<'SCRIPT'
#!/bin/bash
exit 1
SCRIPT
cat > "$P10_RUNNER" <<'SCRIPT'
#!/bin/bash
target="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
mkdir -p "$(dirname "$target")"
: > "$target"
SCRIPT
chmod +x "$PE_RUNNER" "$P10_RUNNER"
alternate_runner="$(MODULE="$MODULE" STEAM_ROOT="$TMP_ROOT/steam" CURRENT_RUNNER="$PE_RUNNER" \
    bash -c '
        source "$MODULE"
        find_battlenet_alternate_runner "$STEAM_ROOT" "$CURRENT_RUNNER"
    ')"
[ "$alternate_runner" = "$P10_RUNNER" ] || {
    echo "FAIL: 战网没有从 PE 自动切换到 Proton 10.0-4" >&2
    exit 1
}
alternate_runner="$(MODULE="$MODULE" STEAM_ROOT="$TMP_ROOT/steam" CURRENT_RUNNER="$P10_RUNNER" \
    bash -c '
        source "$MODULE"
        find_battlenet_alternate_runner "$STEAM_ROOT" "$CURRENT_RUNNER"
    ')"
[ "$alternate_runner" = "$PE_RUNNER" ] || {
    echo "FAIL: 战网没有从 Proton 10.0-4 自动切换到 PE" >&2
    exit 1
}

BATTLE_NET_INSTALLER="$TMP_ROOT/Battle.net-Setup.exe"
: > "$BATTLE_NET_INSTALLER"
battlenet_result="$(MODULE="$MODULE" TMP_ROOT="$TMP_ROOT" PE_RUNNER="$PE_RUNNER" \
    P10_RUNNER="$P10_RUNNER" BATTLE_NET_INSTALLER="$BATTLE_NET_INSTALLER" \
    bash -c '
        source "$MODULE"
        BATTLE_NET_FIRST_ATTEMPT_TIMEOUT=0
        POST_INSTALL_TIMEOUT=0
        POST_INSTALL_INTERVAL=1
        run_battlenet_installer_with_fallback "$TMP_ROOT/steam" "$BATTLE_NET_INSTALLER" \
            "$TMP_ROOT/battlenet-prefix" "$PE_RUNNER"
    ')"
expected_battlenet="$TMP_ROOT/battlenet-prefix/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
[ "$battlenet_result" = "$expected_battlenet|$P10_RUNNER" ] || {
    echo "FAIL: 战网重试后没有将 Proton 10.0-4 写入启动包装器" >&2
    exit 1
}

# 客户已经安装过战网时，必须直接包装真实EXE，不能再下载或运行安装器。
mkdir -p "$(dirname "$EXISTING_SHORTCUTS")" "$(dirname "$EXISTING_BATTLENET")"
: > "$EXISTING_BATTLENET"
existing_output="$(
    MODULE="$MODULE" ZHOUKEER_STEAM_ROOT="$EXISTING_STEAM" \
        ZHOUKEER_SHORTCUT_FILE="$EXISTING_SHORTCUTS" \
        ZHOUKEER_PROTON_RUNNER="$FAKE_PROTON" \
    ZHOUKEER_APP_DIR="$EXISTING_APP_DIR" \
        HOME="$FAKE_HOME" ZHOUKEER_SKIP_STEAM_RESTART=1 PROTON_LOG="$PROTON_LOG" \
        bash -c 'source "$MODULE"; install_launcher battlenet'
)"
printf '%s\n' "$existing_output" | grep -Fq '跳过安装包下载' || {
    echo "FAIL: 已安装战网没有跳过安装包" >&2
    exit 1
}
[ ! -e "$EXISTING_APP_DIR/game-launchers/battlenet/Battle.net-Setup.exe" ] || {
    echo "FAIL: 已安装战网仍生成了安装器" >&2
    exit 1
}
[ -x "$EXISTING_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" ] || {
    echo "FAIL: 已安装战网没有生成直接启动包装器" >&2
    exit 1
}
[ -x "$FAKE_HOME/Desktop/战网启动器.desktop" ] || {
    echo "FAIL: 已安装战网没有创建持久桌面启动图标" >&2
    exit 1
}
python3 - "$EXISTING_SHORTCUTS" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert b"launch-battlenet.sh" in data
assert b"Battle.net-Setup.exe" not in data
PY

grep -Fq 'steamapps/compatdata' "$MODULE"
grep -Fq 'EpicGamesLauncher.exe' "$MODULE"
grep -Fq 'Battle.net Launcher.exe' "$MODULE"
grep -Fq 'Battle.net.exe' "$MODULE"
grep -Fq 'run_launcher_installer' "$MODULE"
grep -Fq 'create_launcher_wrapper' "$MODULE"
grep -Fq '无需再选择兼容层' "$MODULE"
grep -Fq '跳过安装包下载' "$MODULE"
grep -Fq 'steam_shortcut.py' "$MODULE"
grep -Fq 'run_battlenet_installer_with_fallback' "$MODULE"
grep -Fq 'create_launcher_desktop_shortcut' "$MODULE"

echo "PASS: Steam条目写入、Proton直接安装和主EXE包装器测试通过"
