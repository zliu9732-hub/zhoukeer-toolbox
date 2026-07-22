#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"
MODULE="$PROJECT_ROOT/modules/game_launchers.sh"
grep -Fq 'source "$PROJECT_ROOT/core/platform.sh"' "$MODULE" || {
    echo "FAIL: 启动器模块未加载 require_command 定义" >&2
    exit 1
}
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

SHORTCUTS="$TMP_ROOT/shortcuts.vdf"
INSTALLER="$TMP_ROOT/EpicGamesLauncherInstaller.msi"
EPIC_EXE="$TMP_ROOT/compatdata/123/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
DIRECT_PREFIX="$TMP_ROOT/direct-prefix"
DIRECT_EXE="$DIRECT_PREFIX/pfx/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
UBISOFT_PREFIX="$TMP_ROOT/ubisoft-prefix"
UBISOFT_EXE="$UBISOFT_PREFIX/pfx/drive_c/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe"
UBISOFT_PROTON="$TMP_ROOT/ubisoft-proton/proton"
FAKE_PROTON="$TMP_ROOT/GE-Proton-test/proton"
PROTON_LOG="$TMP_ROOT/proton.log"
STEAM_INSTALL_LOG="$TMP_ROOT/steam-install.log"
EXISTING_STEAM="$TMP_ROOT/existing-steam"
EXISTING_SHORTCUTS="$EXISTING_STEAM/userdata/123/config/shortcuts.vdf"
EXISTING_BATTLENET="$EXISTING_STEAM/steamapps/compatdata/777/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
EXISTING_APP_DIR="$TMP_ROOT/existing-apps"
FAKE_HOME="$TMP_ROOT/home"
AUTO_STEAM_ROOT="$TMP_ROOT/auto-steam"
FAKE_STEAM="$TMP_ROOT/fake-steam"

python3 "$HELPER" --help >/dev/null

python3 "$HELPER" --shortcut-file "$SHORTCUTS" add \
    --name "Epic Games 启动器" --exe "$INSTALLER" --start-dir "$TMP_ROOT"
python3 "$HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name "Epic Games 启动器" --exe "$INSTALLER" | grep -Fxq verified
app_id="$(python3 "$HELPER" --shortcut-file "$SHORTCUTS" appid \
    --name "Epic Games 启动器" --exe "$INSTALLER")"
expected_app_id="$(python3 - "$INSTALLER" <<'PY'
import sys
import zlib
print(zlib.crc32((f'"{sys.argv[1]}"' + 'Epic Games 启动器').encode()) | 0x80000000)
PY
)"
[ "$app_id" = "$expected_app_id" ] || {
    echo "FAIL: Steam 非 Steam 游戏 AppID 计算错误" >&2
    exit 1
}
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

silent_result="$(
    MODULE="$MODULE" PROTON_LOG="$PROTON_LOG" DIRECT_PREFIX="$DIRECT_PREFIX" \
        FAKE_PROTON="$FAKE_PROTON" INSTALLER="$INSTALLER" TMP_ROOT="$TMP_ROOT" \
        bash -c '
            source "$MODULE"
            POST_INSTALL_TIMEOUT=0
            run_launcher_installer epic "$TMP_ROOT/steam" "$INSTALLER" "$DIRECT_PREFIX" "$FAKE_PROTON" 0 silent
        '
)"
[ "$silent_result" = "$DIRECT_EXE" ] || {
    echo "FAIL: Epic 静默安装没有返回主程序" >&2
    exit 1
}
grep -Fq '/qn /norestart' "$PROTON_LOG" || {
    echo "FAIL: Epic 静默安装参数缺失" >&2
    exit 1
}

mkdir -p "$(dirname "$UBISOFT_PROTON")"
cat > "$UBISOFT_PROTON" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" > "${PROTON_LOG:?}"
target="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe"
mkdir -p "$(dirname "$target")"
: > "$target"
SCRIPT
chmod +x "$UBISOFT_PROTON"
ubisoft_result="$(
    MODULE="$MODULE" PROTON_LOG="$PROTON_LOG" UBISOFT_PREFIX="$UBISOFT_PREFIX" \
        UBISOFT_PROTON="$UBISOFT_PROTON" TMP_ROOT="$TMP_ROOT" \
        bash -c '
            source "$MODULE"
            POST_INSTALL_TIMEOUT=0
            run_launcher_installer ubisoft "$TMP_ROOT/steam" "$TMP_ROOT/UbisoftConnectInstaller.exe" \
                "$UBISOFT_PREFIX" "$UBISOFT_PROTON"
        '
)"
[ "$ubisoft_result" = "$UBISOFT_EXE" ] || {
    echo "FAIL: Ubisoft Connect 安装后没有定位主程序" >&2
    exit 1
}
grep -Fq 'run '"$TMP_ROOT/UbisoftConnectInstaller.exe" "$PROTON_LOG" || {
    echo "FAIL: Ubisoft Connect EXE 没有通过 Proton 直接运行" >&2
    exit 1
}

art_shortcuts="$TMP_ROOT/art-account/config/shortcuts.vdf"
mkdir -p "$(dirname "$art_shortcuts")"
MODULE="$MODULE" ART_SHORTCUTS="$art_shortcuts" APP_ID="$app_id" bash -c '
    source "$MODULE"
    install_launcher_steam_artwork epic "$ART_SHORTCUTS" "$APP_ID"
'
for artwork in "$app_id.jpg" "${app_id}p.jpg" "${app_id}_hero.jpg" \
    "${app_id}_logo.png" "${app_id}_icon.png"; do
    [ -s "$(dirname "$art_shortcuts")/grid/$artwork" ] || {
        echo "FAIL: Steam 库美化文件缺失：$artwork" >&2
        exit 1
    }
done

LOGIN_ROOT="$TMP_ROOT/login-steam"
mkdir -p "$LOGIN_ROOT/steamapps" "$LOGIN_ROOT/userdata/123/config" \
    "$LOGIN_ROOT/userdata/456/config" "$LOGIN_ROOT/config"
cat > "$LOGIN_ROOT/config/loginusers.vdf" <<'VDF'
"users"
{
    "76561197960265851"
    {
        "MostRecent" "1"
    }
    "76561197960266184"
    {
        "MostRecent" "0"
    }
}
VDF
selected_shortcuts="$(MODULE="$MODULE" LOGIN_ROOT="$LOGIN_ROOT" bash -c '
    source "$MODULE"
    find_shortcut_file "$LOGIN_ROOT"
')"
[ "$selected_shortcuts" = "$LOGIN_ROOT/userdata/123/config/shortcuts.vdf" ] || {
    echo "FAIL: 未选择 Steam 最近登录账号，可能导致 Epic 不入库" >&2
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

cat > "$FAKE_STEAM" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" > "${STEAM_INSTALL_LOG:?}"
runner="${AUTO_STEAM_ROOT:?}/steamapps/common/Proton 10.0-4/proton"
mkdir -p "$(dirname "$runner")"
printf '#!/bin/bash\nexit 0\n' > "$runner"
chmod +x "$runner"
SCRIPT
chmod +x "$FAKE_STEAM"
auto_runner="$(
    MODULE="$MODULE" AUTO_STEAM_ROOT="$AUTO_STEAM_ROOT" FAKE_STEAM="$FAKE_STEAM" \
        STEAM_INSTALL_LOG="$STEAM_INSTALL_LOG" bash -c '
            source "$MODULE"
            steam_command() { printf "%s\n" "$FAKE_STEAM"; }
            PROTON_INSTALL_TIMEOUT=3
            PROTON_INSTALL_INTERVAL=1
            ensure_proton_runner "$AUTO_STEAM_ROOT"
        '
)"
[ "$auto_runner" = "$AUTO_STEAM_ROOT/steamapps/common/Proton 10.0-4/proton" ] || {
    echo "FAIL: 缺少 Proton 时没有等待 Steam 自动安装 Proton 10" >&2
    exit 1
}
grep -Fxq 'steam://install/3658110' "$STEAM_INSTALL_LOG" || {
    echo "FAIL: 未通过 Steam 官方 Proton 10 安装入口补齐兼容层" >&2
    exit 1
}

# 启动器只使用 Proton 10.0-4 和 PE，并且 10.0-4 优先。
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
preferred_runner="$(MODULE="$MODULE" STEAM_ROOT="$TMP_ROOT/steam" bash -c '
    source "$MODULE"
    find_proton_runner "$STEAM_ROOT"
')"
[ "$preferred_runner" = "$P10_RUNNER" ] || {
    echo "FAIL: Proton 10.0-4 没有优先于 PE" >&2
    exit 1
}
epic_runner="$(MODULE="$MODULE" STEAM_ROOT="$TMP_ROOT/steam" bash -c '
    source "$MODULE"
    ensure_launcher_proton_runner epic "$STEAM_ROOT"
')"
[ "$epic_runner" = "$PE_RUNNER" ] || {
    echo "FAIL: Epic 没有优先使用 Proton Experimental" >&2
    exit 1
}
ubisoft_runner="$(MODULE="$MODULE" STEAM_ROOT="$TMP_ROOT/steam" bash -c '
    source "$MODULE"
    ensure_launcher_proton_runner ubisoft "$STEAM_ROOT"
')"
[ "$ubisoft_runner" = "$PE_RUNNER" ] || {
    echo "FAIL: Ubisoft Connect 没有优先使用 Proton Experimental" >&2
    exit 1
}
GENERIC_P10_DIR="$TMP_ROOT/generic-steam/steamapps/common/Proton 10.0"
mkdir -p "$GENERIC_P10_DIR"
printf '#!/bin/bash\nexit 0\n' > "$GENERIC_P10_DIR/proton"
chmod +x "$GENERIC_P10_DIR/proton"
printf 'proton-10.0-3\n' > "$GENERIC_P10_DIR/version"
if MODULE="$MODULE" GENERIC_STEAM="$TMP_ROOT/generic-steam" bash -c '
    source "$MODULE"
    find_proton_10_runner "$GENERIC_STEAM"
'; then
    echo "FAIL: 非 10.0-4 的 Proton 10 被错误选中" >&2
    exit 1
fi
printf 'proton-10.0-4\n' > "$GENERIC_P10_DIR/version"
generic_runner="$(MODULE="$MODULE" GENERIC_STEAM="$TMP_ROOT/generic-steam" bash -c '
    source "$MODULE"
    find_proton_10_runner "$GENERIC_STEAM"
')"
[ "$generic_runner" = "$GENERIC_P10_DIR/proton" ] || {
    echo "FAIL: Steam 官方 Proton 10.0 目录中的 10.0-4 未被识别" >&2
    exit 1
}
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
        bash -c 'source "$MODULE"; detect_platform() { IS_STEAMOS=1; }; install_launcher battlenet'
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
grep -Fq "Icon=$PROJECT_ROOT/assets/game-launchers/battlenet.png" \
    "$FAKE_HOME/Desktop/战网启动器.desktop" || {
    echo "FAIL: 战网桌面入口没有使用带工具箱标识的图标" >&2
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
grep -Fq 'UbisoftConnectInstaller.exe' "$MODULE"
grep -Fq 'UbisoftConnect.exe' "$MODULE"
grep -Fq 'https://static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe' "$MODULE"
grep -Fq 'https://downloader.battle.net/download/getInstallerForGame?os=win&installer=Battle.net-Setup.exe' "$MODULE"
grep -Fq 'run_launcher_installer' "$MODULE"
grep -Fq 'create_launcher_wrapper' "$MODULE"
grep -Fq '无需再选择兼容层' "$MODULE"
grep -Fq '跳过安装包下载' "$MODULE"
grep -Fq 'steam_shortcut.py' "$MODULE"
grep -Fq 'run_battlenet_installer_with_fallback' "$MODULE"
grep -Fq 'create_launcher_desktop_shortcut' "$MODULE"
grep -Fq 'install_launcher_steam_artwork' "$MODULE"
grep -Fq 'download_launcher_installer' "$MODULE"
grep -Fq '点击 Install（安装）' "$MODULE"
grep -Fq '点击 Continue（继续）' "$MODULE"
grep -Fq '选择中文并依次点击接受、安装、完成' "$MODULE"
grep -Fq 'ensure_launcher_proton_runner' "$MODULE"
grep -Fq '从 Proton 10.0-4 切换到 Proton Experimental' "$MODULE"
grep -Fq 'Epic 改中文：右上角头像' "$MODULE"
grep -Fq '不带 System Default 的中文（简体）' "$MODULE"
if grep -Fq 'GE-Proton*/proton' "$MODULE"; then
    echo "FAIL: Epic/战网安装流程仍会选用 GE-Proton" >&2
    exit 1
fi
if grep -Fq '当前版本仅支持已安装启动器的自动入库' "$MODULE"; then
    echo "FAIL: Epic 不应限制为仅已安装启动器" >&2
    exit 1
fi

echo "PASS: Steam条目写入、Proton直接安装和主EXE包装器测试通过"
