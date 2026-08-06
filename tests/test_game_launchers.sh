#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$PROJECT_ROOT/scripts/steam_shortcut.py"
COMPAT_HELPER="$PROJECT_ROOT/scripts/steam_compat.py"
MODULE="$PROJECT_ROOT/modules/game_launchers.sh"
grep -Fq 'source "$PROJECT_ROOT/core/platform.sh"' "$MODULE" || {
    echo "FAIL: 启动器模块未加载 require_command 定义" >&2
    exit 1
}
grep -Fq 'print_launcher_proton_hint' "$MODULE" || {
    echo "FAIL: 启动器模块缺少醒目的 Proton 兼容层提示" >&2
    exit 1
}
grep -Fq '强制使用兼容性工具' "$MODULE" || {
    echo "FAIL: 启动器模块缺少强制使用兼容层文案" >&2
    exit 1
}
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
export ZHOUKEER_LAUNCHER_BASE="$TMP_ROOT/launcher-root"

SHORTCUTS="$TMP_ROOT/shortcuts.vdf"
INSTALLER="$TMP_ROOT/EpicGamesLauncherInstaller.msi"
printf '\xd0\xcf\x11\xe0' > "$INSTALLER"
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
python3 "$COMPAT_HELPER" --help >/dev/null

python3 "$HELPER" --shortcut-file "$SHORTCUTS" add \
    --name "Epic Games 启动器" --exe "$INSTALLER" --start-dir "$TMP_ROOT"
python3 "$HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name "Epic Games 启动器" --exe "$INSTALLER" | grep -Fxq verified
python3 "$HELPER" --shortcut-file "$SHORTCUTS" set-icon \
    --name "Epic Games 启动器" --exe "$INSTALLER" \
    --icon "$PROJECT_ROOT/assets/game-launchers/epic.png" | grep -Fxq updated
python3 "$HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name "Epic Games 启动器" --exe "$INSTALLER" \
    --icon "$PROJECT_ROOT/assets/game-launchers/epic.png" | grep -Fxq verified
app_id="$(python3 "$HELPER" --shortcut-file "$SHORTCUTS" appid \
    --name "Epic Games 启动器" --exe "$INSTALLER")"
game_id="$(python3 "$HELPER" --shortcut-file "$SHORTCUTS" gameid \
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
expected_game_id="$(python3 - "$app_id" <<'PY'
import sys
print((int(sys.argv[1]) << 32) | 0x02000000)
PY
)"
[ "$game_id" = "$expected_game_id" ] || {
    echo "FAIL: Steam 非 Steam 游戏 GameID 计算错误" >&2
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
    --name "Epic Games 启动器" --exe "$WRAPPER" --start-dir "$TMP_ROOT" \
    --launch-options 'TEST_PREFIX="/tmp/example" %command%' | grep -Fxq updated
python3 "$HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name "Epic Games 启动器" --exe "$WRAPPER" \
    --launch-options 'TEST_PREFIX="/tmp/example" %command%' | grep -Fxq verified
python3 - "$SHORTCUTS" "$WRAPPER" "$EPIC_EXE" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert data.count("Epic Games 启动器".encode()) == 1
assert sys.argv[2].encode() in data
assert sys.argv[3].encode() not in data
PY

# 旧版“Battle.net”条目指向不同 EXE 时，正式条目写入后应被清理，只保留“战网启动器”。
LEGACY_SHORTCUTS="$TMP_ROOT/legacy-shortcuts.vdf"
LEGACY_OLD_EXE="$TMP_ROOT/old-prefix/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
LEGACY_NEW_EXE="$TMP_ROOT/new-prefix/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
mkdir -p "$(dirname "$LEGACY_OLD_EXE")" "$(dirname "$LEGACY_NEW_EXE")"
: > "$LEGACY_OLD_EXE"
: > "$LEGACY_NEW_EXE"
python3 "$HELPER" --shortcut-file "$LEGACY_SHORTCUTS" add \
    --name "Battle.net" --exe "$LEGACY_OLD_EXE" --start-dir "$(dirname "$LEGACY_OLD_EXE")" >/dev/null
python3 "$HELPER" --shortcut-file "$LEGACY_SHORTCUTS" add \
    --name "战网启动器" --exe "$LEGACY_NEW_EXE" --start-dir "$(dirname "$LEGACY_NEW_EXE")" >/dev/null
python3 "$HELPER" --shortcut-file "$LEGACY_SHORTCUTS" remove \
    --exe-basename "Battle.net Launcher.exe" --exe-basename "Battle.net.exe" \
    --exe-basename "Battle.net-Setup.exe" --exe-basename "launch-battlenet.sh" \
    --keep-exe "$LEGACY_NEW_EXE" --keep-name "战网启动器" | grep -Fxq removed
python3 - "$LEGACY_SHORTCUTS" "$LEGACY_OLD_EXE" "$LEGACY_NEW_EXE" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert sys.argv[2].encode() not in data
assert sys.argv[3].encode() in data
assert data.count("战网启动器".encode()) == 1
PY

# Steam 的文本 config.vdf 只修改指定兼容层映射，并能幂等覆盖旧值。
COMPAT_CONFIG="$TMP_ROOT/config.vdf"
printf '%s\n' '"InstallConfigStore"' '{' '    "Software"' '    {' \
    '        "Valve"' '        {' '            "Steam"' '            {' \
    '                "Language"        "schinese"' \
    '                "CompatToolMapping"' '                {' \
    '                    "2147483999"' '                    {' \
    '                        "name"        "proton_10"' \
    '                        "config"      ""' \
    '                        "priority"    "250"' \
    '                    }' '                }' '            }' '        }' '    }' '}' \
    > "$COMPAT_CONFIG"
python3 "$COMPAT_HELPER" --config-file "$COMPAT_CONFIG" \
    --app-id 2147483999 --tool proton_experimental | grep -Fxq updated
python3 "$COMPAT_HELPER" --config-file "$COMPAT_CONFIG" \
    --app-id 2147483999 --tool proton_experimental | grep -Fxq updated
[ "$(grep -c '"2147483999"' "$COMPAT_CONFIG")" -eq 1 ] || {
    echo "FAIL: 重复写入了战网兼容层映射" >&2
    exit 1
}
grep -Fq '"proton_experimental"' "$COMPAT_CONFIG" || {
    echo "FAIL: 战网没有写入 Proton Experimental 映射" >&2
    exit 1
}
grep -Fq '"Language"        "schinese"' "$COMPAT_CONFIG" || {
    echo "FAIL: 写入兼容层时破坏了 Steam 原配置" >&2
    exit 1
}

# 战网先由 Steam 库中的安装条目启动，安装完成后再次运行工具箱才切换为正式条目。
NATIVE_STEAM="$TMP_ROOT/native-steam"
NATIVE_SHORTCUTS="$NATIVE_STEAM/userdata/123/config/shortcuts.vdf"
NATIVE_INSTALLER="$TMP_ROOT/native-app/Battle.net-Setup.exe"
NATIVE_APP_DIR="$TMP_ROOT/native-apps"
mkdir -p "$(dirname "$NATIVE_SHORTCUTS")" "$(dirname "$NATIVE_INSTALLER")" \
    "$NATIVE_STEAM/config" "$NATIVE_STEAM/steamapps/compatdata"
: > "$NATIVE_INSTALLER"
printf '%s\n' '"InstallConfigStore"' '{' '    "Software"' '    {' \
    '        "Valve"' '        {' '            "Steam"' '            {' \
    '            }' '        }' '    }' '}' > "$NATIVE_STEAM/config/config.vdf"
native_installer_app_id="$(python3 "$HELPER" --shortcut-file "$NATIVE_SHORTCUTS" appid \
    --name "战网启动器" --exe "$NATIVE_INSTALLER")"
NATIVE_PREFIX="$NATIVE_STEAM/steamapps/compatdata/$native_installer_app_id"
NATIVE_EXE="$NATIVE_PREFIX/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
NATIVE_PROTON="$TMP_ROOT/native-proton/proton"
mkdir -p "$(dirname "$NATIVE_PROTON")"
printf '#!/bin/bash\nexit 0\n' > "$NATIVE_PROTON"
chmod +x "$NATIVE_PROTON"
mkdir -p "$FAKE_HOME/Desktop"
cat > "$FAKE_HOME/Desktop/战网启动器.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=战网启动器
Exec=steam steam://rungameid/123456
X-Zhoukeer-Managed=true
DESKTOP
native_output="$(
    MODULE="$MODULE" NATIVE_STEAM="$NATIVE_STEAM" \
        NATIVE_INSTALLER="$NATIVE_INSTALLER" NATIVE_SHORTCUTS="$NATIVE_SHORTCUTS" \
        HOME="$FAKE_HOME" bash -c '
            source "$MODULE"
            launcher_details battlenet
            stop_steam_for_vdf() { :; }
            start_steam() { :; }
            prepare_battlenet_steam_installer "$NATIVE_STEAM" "$NATIVE_INSTALLER" "$NATIVE_SHORTCUTS"
        '
)"
[ -f "$NATIVE_SHORTCUTS" ] || {
    echo "FAIL: Steam 战网安装条目没有写入 shortcuts.vdf" >&2
    exit 1
}
printf '%s\n' "$native_output" | grep -Fq '完成安装' || {
    echo "FAIL: 战网安装条目没有提示从 Steam 库完成安装" >&2
    exit 1
}
[ ! -e "$FAKE_HOME/Desktop/战网启动器.desktop" ] || {
    echo "FAIL: 未完成安装阶段仍保留了可能配置不可用的战网桌面入口" >&2
    exit 1
}
mkdir -p "$(dirname "$NATIVE_EXE")"
: > "$NATIVE_EXE"
MODULE="$MODULE" NATIVE_EXE="$NATIVE_EXE" NATIVE_PREFIX="$NATIVE_PREFIX" \
    NATIVE_STEAM="$NATIVE_STEAM" NATIVE_SHORTCUTS="$NATIVE_SHORTCUTS" \
    NATIVE_PROTON="$NATIVE_PROTON" ZHOUKEER_APP_DIR="$NATIVE_APP_DIR" \
    HOME="$FAKE_HOME" bash -c '
        source "$MODULE"
        launcher_details battlenet
        stop_steam_for_vdf() { :; }
        start_steam() { :; }
        finish_battlenet_steam_entry "$NATIVE_STEAM" "$NATIVE_SHORTCUTS" \
            "$NATIVE_EXE" "$NATIVE_PREFIX" "$NATIVE_PROTON"
    ' >/dev/null
python3 - "$NATIVE_SHORTCUTS" "$NATIVE_EXE" "$NATIVE_PREFIX" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert sys.argv[2].encode() in data
assert b"Battle.net-Setup.exe" not in data
assert f'STEAM_COMPAT_DATA_PATH="{sys.argv[3]}" %command%'.encode() not in data
PY
grep -Fq 'STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"' \
    "$NATIVE_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" || {
    echo "FAIL: 战网 Steam 条目已去掉兼容层启动项，但桌面启动包装器没有保留" >&2
    exit 1
}
grep -Fq "Exec=$NATIVE_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" \
    "$FAKE_HOME/Desktop/战网启动器.desktop" || {
    echo "FAIL: Steam 原生战网流程没有创建独立桌面启动入口" >&2
    exit 1
}
[ "$(grep -c '"proton_10"' "$NATIVE_STEAM/config/config.vdf")" -eq 2 ] || {
    echo "FAIL: 战网安装条目和正式条目没有分别绑定 Proton 10" >&2
    exit 1
}
native_final_app_id="$(python3 "$HELPER" --shortcut-file "$NATIVE_SHORTCUTS" appid \
    --name "战网启动器" --exe "$NATIVE_EXE")"
[ "$(readlink "$NATIVE_STEAM/steamapps/compatdata/$native_final_app_id/pfx/drive_c")" = \
    "$NATIVE_PREFIX/pfx/drive_c" ] || {
    echo "FAIL: 战网正式条目没有把 Steam compatdata drive_c 链接到共享前缀" >&2
    exit 1
}

# 同一路径的旧“育碧服务”条目应原地改名为“育碧”，不能重复入库。
UBISOFT_SHORTCUTS="$TMP_ROOT/ubisoft-shortcuts.vdf"
UBISOFT_WRAPPER="$TMP_ROOT/launch-ubisoft.sh"
: > "$UBISOFT_WRAPPER"
python3 "$HELPER" --shortcut-file "$UBISOFT_SHORTCUTS" add \
    --name "育碧服务" --exe "$UBISOFT_WRAPPER" --start-dir "$TMP_ROOT" >/dev/null
python3 "$HELPER" --shortcut-file "$UBISOFT_SHORTCUTS" add \
    --name "育碧" --exe "$UBISOFT_WRAPPER" --start-dir "$TMP_ROOT" | grep -Fxq updated
python3 - "$UBISOFT_SHORTCUTS" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert data.count("育碧".encode()) == 1
assert "育碧服务".encode() not in data
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

EXE_INSTALLER="$TMP_ROOT/EpicInstaller-20.1.4.exe"
printf 'MZ\0' > "$EXE_INSTALLER"
exe_result="$(
    MODULE="$MODULE" PROTON_LOG="$PROTON_LOG" DIRECT_PREFIX="$DIRECT_PREFIX" \
        FAKE_PROTON="$FAKE_PROTON" INSTALLER="$EXE_INSTALLER" TMP_ROOT="$TMP_ROOT" \
        bash -c '
            source "$MODULE"
            POST_INSTALL_TIMEOUT=0
            run_launcher_installer epic "$TMP_ROOT/steam" "$INSTALLER" "$DIRECT_PREFIX" "$FAKE_PROTON"
        '
)"
[ "$exe_result" = "$DIRECT_EXE" ] || {
    echo "FAIL: Epic EXE 没有通过 Proton 直接运行" >&2
    exit 1
}
grep -Fq "run $EXE_INSTALLER" "$PROTON_LOG" || {
    echo "FAIL: Epic EXE 未作为可执行文件运行" >&2
    exit 1
}
silent_exe_result="$(
    MODULE="$MODULE" PROTON_LOG="$PROTON_LOG" DIRECT_PREFIX="$DIRECT_PREFIX" \
        FAKE_PROTON="$FAKE_PROTON" INSTALLER="$EXE_INSTALLER" TMP_ROOT="$TMP_ROOT" \
        bash -c '
            source "$MODULE"
            POST_INSTALL_TIMEOUT=0
            run_launcher_installer epic "$TMP_ROOT/steam" "$INSTALLER" "$DIRECT_PREFIX" "$FAKE_PROTON" 0 silent
        '
)"
[ "$silent_exe_result" = "$DIRECT_EXE" ] || {
    echo "FAIL: Epic EXE 静默安装没有返回主程序" >&2
    exit 1
}
grep -Fq "run $EXE_INSTALLER /S" "$PROTON_LOG" || {
    echo "FAIL: Epic EXE 静默安装参数缺失" >&2
    exit 1
}

# 战网预装客户端：解压助手必须拒绝越界路径，并正确落地主程序。
FAKE_BSDTAR_BIN="$TMP_ROOT/fake-bin"
mkdir -p "$FAKE_BSDTAR_BIN"
cat > "$FAKE_BSDTAR_BIN/bsdtar" <<'SCRIPT'
#!/bin/bash
if printf '%s\n' "$@" | grep -q -- '-tf'; then
    cat "$FAKE_ARCHIVE_LIST"
    exit 0
fi
if printf '%s\n' "$@" | grep -q -- '-xf'; then
    prev=""
    for arg in "$@"; do
        if [ "$prev" = "-C" ]; then
            target_dir="$arg"
        fi
        prev="$arg"
    done
    mkdir -p "$(dirname "$FAKE_EXTRACT_FILE")"
    : > "$FAKE_EXTRACT_FILE"
    exit 0
fi
exit 1
SCRIPT
chmod +x "$FAKE_BSDTAR_BIN/bsdtar"

PREINSTALLED_ARCHIVE="$TMP_ROOT/Battle.net.7z"
: > "$PREINSTALLED_ARCHIVE"
PREINSTALLED_DRIVE_C="$TMP_ROOT/preinstalled-drive-c"
mkdir -p "$PREINSTALLED_DRIVE_C/Program Files (x86)"
printf 'Battle.net/Battle.net Launcher.exe\n' > "$TMP_ROOT/good-archive-list.txt"
if ! MODULE="$MODULE" FAKE_ARCHIVE_LIST="$TMP_ROOT/good-archive-list.txt" \
    PREINSTALLED_ARCHIVE="$PREINSTALLED_ARCHIVE" PREINSTALLED_DRIVE_C="$PREINSTALLED_DRIVE_C" \
    FAKE_EXTRACT_FILE="$PREINSTALLED_DRIVE_C/Program Files (x86)/Battle.net/Battle.net Launcher.exe" \
    PATH="$FAKE_BSDTAR_BIN:$PATH" bash -c '
        source "$MODULE"
        launcher_details battlenet
        extract_preinstalled_launcher "$PREINSTALLED_ARCHIVE" "$PREINSTALLED_DRIVE_C"
    '; then
    echo "FAIL: 战网预装客户端解压失败" >&2
    exit 1
fi
[ -f "$PREINSTALLED_DRIVE_C/Program Files (x86)/Battle.net/Battle.net Launcher.exe" ] || {
    echo "FAIL: 战网预装客户端解压后主程序缺失" >&2
    exit 1
}
printf '../evil\n' > "$TMP_ROOT/bad-archive-list.txt"
if MODULE="$MODULE" FAKE_ARCHIVE_LIST="$TMP_ROOT/bad-archive-list.txt" \
    PREINSTALLED_ARCHIVE="$PREINSTALLED_ARCHIVE" PREINSTALLED_DRIVE_C="$PREINSTALLED_DRIVE_C" \
    FAKE_EXTRACT_FILE="$PREINSTALLED_DRIVE_C/Program Files (x86)/Battle.net/Battle.net Launcher.exe" \
    PATH="$FAKE_BSDTAR_BIN:$PATH" bash -c '
        source "$MODULE"
        launcher_details battlenet
        extract_preinstalled_launcher "$PREINSTALLED_ARCHIVE" "$PREINSTALLED_DRIVE_C"
    '; then
    echo "FAIL: 战网预装客户端接受了越界路径" >&2
    exit 1
fi
printf 'Qingfeng/HeyboxWow/heyboxwow.exe\n' > "$TMP_ROOT/heihe-archive-list.txt"
if ! MODULE="$MODULE" FAKE_ARCHIVE_LIST="$TMP_ROOT/heihe-archive-list.txt" \
    PREINSTALLED_ARCHIVE="$PREINSTALLED_ARCHIVE" PREINSTALLED_DRIVE_C="$PREINSTALLED_DRIVE_C" \
    FAKE_EXTRACT_FILE="$PREINSTALLED_DRIVE_C/Program Files (x86)/Qingfeng/HeyboxWow/heyboxwow.exe" \
    PATH="$FAKE_BSDTAR_BIN:$PATH" bash -c '
        source "$MODULE"
        launcher_details heihe
        extract_preinstalled_launcher "$PREINSTALLED_ARCHIVE" "$PREINSTALLED_DRIVE_C"
    '; then
    echo "FAIL: 黑盒工坊预装客户端解压失败" >&2
    exit 1
fi
[ -f "$PREINSTALLED_DRIVE_C/Program Files (x86)/Qingfeng/HeyboxWow/heyboxwow.exe" ] || {
    echo "FAIL: 黑盒工坊预装客户端解压后主程序缺失" >&2
    exit 1
}

# 共享前缀：战网独立 drive_c 必须挂到 compatdata/pfx/drive_c。
PREINSTALLED_APP_DIR="$TMP_ROOT/preinstalled-app"
PREINSTALLED_PREFIX="$(
    MODULE="$MODULE" ZHOUKEER_APP_DIR="$PREINSTALLED_APP_DIR" \
        PREINSTALLED_DRIVE_C="$PREINSTALLED_DRIVE_C" bash -c '
            source "$MODULE"
            prepare_launcher_shared_prefix battlenet "$PREINSTALLED_DRIVE_C"
        '
)"
[ "$PREINSTALLED_PREFIX" = "$PREINSTALLED_APP_DIR/game-launchers/battlenet/compatdata" ] || {
    echo "FAIL: 战网预装客户端前缀路径错误" >&2
    exit 1
}
[ "$(readlink "$PREINSTALLED_PREFIX/pfx/drive_c")" = "$PREINSTALLED_DRIVE_C" ] || {
    echo "FAIL: 战网预装客户端 drive_c 软链接未指向独立目录" >&2
    exit 1
}

# 旧版隐藏目录中的启动器文件必须自动迁移到用户可见根目录，插件才能找到。
MIGRATE_APP_DIR="$TMP_ROOT/migrate-apps"
MIGRATE_PREFIX="$MIGRATE_APP_DIR/game-launchers/ubisoft/compatdata"
MIGRATE_OLD="$MIGRATE_APP_DIR/game-launchers/ubisoft/drive_c"
MIGRATE_EXE="$MIGRATE_OLD/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe"
mkdir -p "$MIGRATE_PREFIX/pfx" "$(dirname "$MIGRATE_EXE")"
: > "$MIGRATE_EXE"
ln -s "$MIGRATE_OLD" "$MIGRATE_PREFIX/pfx/drive_c"
MODULE="$MODULE" MIGRATE_APP_DIR="$MIGRATE_APP_DIR" \
    ZHOUKEER_APP_DIR="$MIGRATE_APP_DIR" bash -c '
    source "$MODULE"
    launcher_details ubisoft
    migrate_launcher_drive_to_visible ubisoft \
        "$MIGRATE_APP_DIR/game-launchers/ubisoft/compatdata"
' >/dev/null
[ -f "$ZHOUKEER_LAUNCHER_BASE/ubisoft/drive_c/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe" ] || {
    echo "FAIL: 旧版隐藏虚拟目录没有迁移到用户可见根目录" >&2
    exit 1
}
[ ! -e "$MIGRATE_OLD" ] || {
    echo "FAIL: 迁移后旧隐藏虚拟目录仍存在" >&2
    exit 1
}
[ "$(readlink "$MIGRATE_PREFIX/pfx/drive_c")" = "$ZHOUKEER_LAUNCHER_BASE/ubisoft/drive_c" ] || {
    echo "FAIL: 迁移后共享前缀 drive_c 没有指向新位置" >&2
    exit 1
}

# 已安装战网通过 symlink drive_c 时，仍必须能被识别为已安装。
SYM_STEAM="$TMP_ROOT/sym-steam"
mkdir -p "$SYM_STEAM/steamapps/compatdata/123/pfx"
ln -s "$PREINSTALLED_DRIVE_C" "$SYM_STEAM/steamapps/compatdata/123/pfx/drive_c"
sym_found="$(
    MODULE="$MODULE" SYM_STEAM="$SYM_STEAM" bash -c '
        source "$MODULE"
        launcher_details battlenet
        find_installed_launcher "$SYM_STEAM"
    '
)"
[ "$sym_found" = "$SYM_STEAM/steamapps/compatdata/123/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe" ] || {
    echo "FAIL: 战网 symlink drive_c 未被识别为已安装" >&2
    exit 1
}
battle_drive_found="$(
    MODULE="$MODULE" SYM_STEAM="$SYM_STEAM" ZHOUKEER_APP_DIR="$TMP_ROOT/no-app" bash -c '
        source "$MODULE"
        find_battle_platform_drive_c "$SYM_STEAM"
    '
)"
[ "$battle_drive_found" = "$SYM_STEAM/steamapps/compatdata/123/pfx/drive_c" ] || {
    echo "FAIL: 未从 Steam 兼容目录找到战网 drive_c" >&2
    exit 1
}
mkdir -p "$PREINSTALLED_APP_DIR/game-launchers/battlenet/drive_c"
battle_drive_owned="$(
    MODULE="$MODULE" SYM_STEAM="$SYM_STEAM" ZHOUKEER_APP_DIR="$PREINSTALLED_APP_DIR" bash -c '
        source "$MODULE"
        find_battle_platform_drive_c "$SYM_STEAM"
    '
)"
[ "$battle_drive_owned" = "$PREINSTALLED_APP_DIR/game-launchers/battlenet/drive_c" ] || {
    echo "FAIL: 未优先使用工具箱独立战网 drive_c" >&2
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
artwork_raw_app_id="$(python3 "$HELPER" --shortcut-file "$art_shortcuts" appid-raw \
    --name "Epic Games 启动器" --exe "$INSTALLER")"
mkdir -p "$(dirname "$art_shortcuts")"
MODULE="$MODULE" ART_SHORTCUTS="$art_shortcuts" APP_ID="$app_id" RAW_APP_ID="$artwork_raw_app_id" GAME_ID="$game_id" bash -c '
    source "$MODULE"
    install_launcher_steam_artwork epic "$ART_SHORTCUTS" "$APP_ID" "$RAW_APP_ID" "$GAME_ID"
'
for current_app_id in "$app_id" "$artwork_raw_app_id"; do
    signed_app_id="$current_app_id"
    if [ "$current_app_id" -gt 2147483647 ]; then
        signed_app_id=$((current_app_id - 4294967296))
    fi
    for check_id in "$current_app_id" "$signed_app_id"; do
        for artwork in "$check_id.png" "${check_id}p.png" "${check_id}_hero.png" \
            "${check_id}_logo.png" "${check_id}_icon.png" "${check_id}_background.jpg"; do
            [ -s "$(dirname "$art_shortcuts")/grid/$artwork" ] || {
                echo "FAIL: Steam 库美化文件缺失：$artwork" >&2
                exit 1
            }
        done
        for stale in "$check_id.jpg" "$check_id.jpeg" "${check_id}p.jpg" \
            "${check_id}_hero.jpg" "${check_id}_background.png"; do
            [ ! -e "$(dirname "$art_shortcuts")/grid/$stale" ] || {
                echo "FAIL: Steam 库旧封面未清理：$stale" >&2
                exit 1
            }
        done
    done
done
for check_id in "$game_id"; do
    for artwork in "$check_id.png" "${check_id}p.png" "${check_id}_hero.png" \
        "${check_id}_logo.png" "${check_id}_icon.png" "${check_id}_background.jpg"; do
        [ -s "$(dirname "$art_shortcuts")/grid/$artwork" ] || {
            echo "FAIL: Steam 库美化文件缺失：$artwork" >&2
            exit 1
        }
    done
done

# 黑盒工坊背景素材是 PNG，写入时不能错存成 jpg。
HEIHE_ART_SHORTCUTS="$TMP_ROOT/heihe-art/shortcuts.vdf"
mkdir -p "$(dirname "$HEIHE_ART_SHORTCUTS")"
: > "$HEIHE_ART_SHORTCUTS"
MODULE="$MODULE" HEIHE_ART_SHORTCUTS="$HEIHE_ART_SHORTCUTS" bash -c '
    source "$MODULE"
    install_launcher_steam_artwork heihe "$HEIHE_ART_SHORTCUTS" 12345
'
[ -s "$(dirname "$HEIHE_ART_SHORTCUTS")/grid/12345_background.png" ] || {
    echo "FAIL: 黑盒工坊背景图未以 PNG 写入" >&2
    exit 1
}
[ ! -e "$(dirname "$HEIHE_ART_SHORTCUTS")/grid/12345_background.jpg" ] || {
    echo "FAIL: 黑盒工坊背景图错误保存为 jpg" >&2
    exit 1
}

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

# 启动包装器必须正确处理带空格的 Proton 与主程序路径，否则点击入口会直接打不开。
SPACE_RUNNER="$TMP_ROOT/Proton - Experimental/proton"
SPACE_EXE="$TMP_ROOT/space-prefix/compatdata/pfx/drive_c/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe"
SPACE_LOG="$TMP_ROOT/space-proton.log"
mkdir -p "$(dirname "$SPACE_RUNNER")" "$(dirname "$SPACE_EXE")"
cat > "$SPACE_RUNNER" <<'SCRIPT'
#!/bin/bash
{
    printf 'arg=<%s>\n' "$@"
    printf 'data=<%s>\n' "$STEAM_COMPAT_DATA_PATH"
} > "${SPACE_LOG:?}"
SCRIPT
chmod +x "$SPACE_RUNNER"
: > "$SPACE_EXE"
space_wrapper="$(
    MODULE="$MODULE" TMP_ROOT="$TMP_ROOT" SPACE_RUNNER="$SPACE_RUNNER" SPACE_EXE="$SPACE_EXE" bash -c '
        source "$MODULE"
        create_launcher_wrapper ubisoft "$TMP_ROOT/steam" "$TMP_ROOT/space-prefix/compatdata" \
            "$SPACE_RUNNER" "$SPACE_EXE" "$TMP_ROOT/space-wrapper"
    '
)"
SPACE_LOG="$SPACE_LOG" "$space_wrapper"
grep -Fxq "arg=<run>" "$SPACE_LOG" || {
    echo "FAIL: 带空格路径的启动包装器没有执行 Proton run" >&2
    exit 1
}
grep -Fxq "arg=<$SPACE_EXE>" "$SPACE_LOG" || {
    echo "FAIL: 带空格的主程序路径在启动包装器中被拆坏" >&2
    exit 1
}
grep -Fxq "data=<$TMP_ROOT/space-prefix/compatdata>" "$SPACE_LOG" || {
    echo "FAIL: 启动包装器没有复用带空格的安装前缀" >&2
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

# 战网优先 Proton 10.0-4；Epic 和育碧仍优先 Proton Experimental。
PE_RUNNER="$TMP_ROOT/steam/steamapps/common/Proton - Experimental/proton"
P10_RUNNER="$TMP_ROOT/steam/steamapps/common/Proton 10.0-4/proton"
mkdir -p "$(dirname "$PE_RUNNER")" "$(dirname "$P10_RUNNER")"
cat > "$PE_RUNNER" <<'SCRIPT'
#!/bin/bash
if [ ! -e "${BATTLE_ATTEMPT_FILE:?}" ]; then
    : > "$BATTLE_ATTEMPT_FILE"
    exit 1
fi
target="$STEAM_COMPAT_DATA_PATH/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
mkdir -p "$(dirname "$target")"
: > "$target"
SCRIPT
cat > "$P10_RUNNER" <<'SCRIPT'
#!/bin/bash
exit 1
SCRIPT
chmod +x "$PE_RUNNER" "$P10_RUNNER"
preferred_runner="$(MODULE="$MODULE" STEAM_ROOT="$TMP_ROOT/steam" bash -c '
    source "$MODULE"
    ensure_launcher_proton_runner battlenet "$STEAM_ROOT"
')"
[ "$preferred_runner" = "$P10_RUNNER" ] || {
    echo "FAIL: 战网没有使用 Proton 10.0-4" >&2
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
# 战网的 Proton 10.0-4 缺失时必须通过 Steam 官方入口补齐。
AUTO_P10_ROOT="$TMP_ROOT/auto-proton10-steam"
AUTO_P10_STEAM="$TMP_ROOT/fake-steam-proton10"
AUTO_P10_LOG="$TMP_ROOT/steam-proton10-install.log"
mkdir -p "$AUTO_P10_ROOT/steamapps/common"
cat > "$AUTO_P10_STEAM" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" > "${AUTO_P10_LOG:?}"
runner="${AUTO_P10_ROOT:?}/steamapps/common/Proton 10.0-4/proton"
mkdir -p "$(dirname "$runner")"
printf '#!/bin/bash\nexit 0\n' > "$runner"
chmod +x "$runner"
SCRIPT
chmod +x "$AUTO_P10_STEAM"
auto_proton10_runner="$(
    MODULE="$MODULE" AUTO_P10_ROOT="$AUTO_P10_ROOT" AUTO_P10_STEAM="$AUTO_P10_STEAM" \
        AUTO_P10_LOG="$AUTO_P10_LOG" bash -c '
            source "$MODULE"
            steam_command() { printf "%s\n" "$AUTO_P10_STEAM"; }
            PROTON_INSTALL_TIMEOUT=3
            PROTON_INSTALL_INTERVAL=1
            ensure_launcher_proton_runner battlenet "$AUTO_P10_ROOT"
        '
)"
[ "$auto_proton10_runner" = "$AUTO_P10_ROOT/steamapps/common/Proton 10.0-4/proton" ] || {
    echo "FAIL: 战网缺少 Proton 10.0-4 时没有自动补齐" >&2
    exit 1
}
grep -Fxq 'steam://install/3658110' "$AUTO_P10_LOG" || {
    echo "FAIL: 未通过 Steam 官方 Proton 10 入口补齐战网安装环境" >&2
    exit 1
}

# 客户已经安装过战网时，必须直接包装真实EXE，不能再下载或运行安装器。
mkdir -p "$(dirname "$EXISTING_SHORTCUTS")" "$(dirname "$EXISTING_BATTLENET")"
: > "$EXISTING_BATTLENET"
mkdir -p "$EXISTING_STEAM/config"
printf '%s\n' '"InstallConfigStore"' '{' '    "Software"' '    {' \
    '        "Valve"' '        {' '            "Steam"' '            {' \
    '            }' '        }' '    }' '}' > "$EXISTING_STEAM/config/config.vdf"
EXISTING_P10_RUNNER="$EXISTING_STEAM/steamapps/common/Proton 10.0-4/proton"
mkdir -p "$(dirname "$EXISTING_P10_RUNNER")"
printf '#!/bin/bash\nexit 0\n' > "$EXISTING_P10_RUNNER"
chmod +x "$EXISTING_P10_RUNNER"
# 旧版工具箱可能留下指向不同路径的“Battle.net”条目和桌面安装包，正式入库后必须只保留“战网启动器”。
LEGACY_OLD_BATTLENET="$EXISTING_STEAM/steamapps/compatdata/old/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
python3 "$HELPER" --shortcut-file "$EXISTING_SHORTCUTS" add \
    --name "Battle.net" --exe "$LEGACY_OLD_BATTLENET" --start-dir "$(dirname "$LEGACY_OLD_BATTLENET")" >/dev/null
mkdir -p "$FAKE_HOME/Desktop"
printf 'MZ' > "$FAKE_HOME/Desktop/Battle.net-Setup.exe"
dd if=/dev/zero bs=1048574 count=1 >> "$FAKE_HOME/Desktop/Battle.net-Setup.exe" 2>/dev/null
existing_output="$(
    MODULE="$MODULE" ZHOUKEER_STEAM_ROOT="$EXISTING_STEAM" \
        ZHOUKEER_SHORTCUT_FILE="$EXISTING_SHORTCUTS" \
    ZHOUKEER_APP_DIR="$EXISTING_APP_DIR" \
        HOME="$FAKE_HOME" ZHOUKEER_SKIP_STEAM_RESTART=1 PROTON_LOG="$PROTON_LOG" \
        bash -c 'source "$MODULE"; detect_platform() { IS_STEAMOS=1; }; install_launcher battlenet'
)"
printf '%s\n' "$existing_output" | grep -Fq '跳过安装包下载' || {
    echo "FAIL: 已安装战网没有跳过安装包" >&2
    exit 1
}
printf '%s\n' "$existing_output" | grep -Fq '已清理旧版战网 Steam 条目' || {
    echo "FAIL: 旧版战网 Steam 条目没有被清理" >&2
    exit 1
}
[ ! -e "$EXISTING_APP_DIR/game-launchers/battlenet/Battle.net-Setup.exe" ] || {
    echo "FAIL: 已安装战网仍生成了安装器" >&2
    exit 1
}
[ ! -e "$FAKE_HOME/Desktop/Battle.net-Setup.exe" ] || {
    echo "FAIL: 旧版桌面战网安装包没有被清理" >&2
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
python3 - "$EXISTING_SHORTCUTS" "$LEGACY_OLD_BATTLENET" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert b"Battle.net Launcher.exe" in data
assert b"Battle.net-Setup.exe" not in data
assert b"STEAM_COMPAT_DATA_PATH=" not in data
assert sys.argv[2].encode() not in data
assert data.count("战网启动器".encode()) == 1
PY
grep -Fq 'STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"' \
    "$EXISTING_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" || {
    echo "FAIL: 战网 Steam 条目已去掉兼容层启动项，但桌面启动包装器没有保留" >&2
    exit 1
}
grep -Fq "Exec=$EXISTING_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" \
    "$FAKE_HOME/Desktop/战网启动器.desktop" || {
    echo "FAIL: 战网桌面入口没有使用独立启动包装器" >&2
    exit 1
}
if grep -Fq 'steam://rungameid/' "$FAKE_HOME/Desktop/战网启动器.desktop"; then
    echo "FAIL: 战网桌面入口仍依赖 Steam rungameid 链接" >&2
    exit 1
fi
grep -Fq 'PROTON_RUNNER=' "$EXISTING_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" || {
    echo "FAIL: 战网桌面启动包装器没有固定兼容层" >&2
    exit 1
}
existing_app_id="$(python3 "$HELPER" --shortcut-file "$EXISTING_SHORTCUTS" appid \
    --name "战网启动器" --exe "$EXISTING_BATTLENET")"
existing_game_id="$(python3 "$HELPER" --shortcut-file "$EXISTING_SHORTCUTS" gameid \
    --name "战网启动器" --exe "$EXISTING_BATTLENET")"
grep -Fxq "export STEAM_COMPAT_APP_ID=\"$existing_app_id\"" \
    "$EXISTING_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" || {
    echo "FAIL: 战网桌面启动包装器没有写入 Steam AppID" >&2
    exit 1
}
grep -Fxq "export SteamGameId=\"$existing_game_id\"" \
    "$EXISTING_APP_DIR/game-launchers/battlenet/launch-battlenet.sh" || {
    echo "FAIL: 战网桌面启动包装器没有写入 Steam GameID" >&2
    exit 1
}
grep -Fq '"proton_10"' "$EXISTING_STEAM/config/config.vdf" || {
    echo "FAIL: 已安装战网入库时没有绑定 Proton 10" >&2
    exit 1
}

# 育碧等启动器必须像战网一样直接把真实 EXE 写入 Steam 库，并让 Steam
# compatdata 的 drive_c 指向用户可见根目录，封面与黑盒工坊等插件才能找到文件。
UBI_STEAM="$TMP_ROOT/ubi-steam"
UBI_SHORTCUTS="$UBI_STEAM/userdata/123/config/shortcuts.vdf"
UBI_APP_DIR="$TMP_ROOT/ubi-apps"
UBI_HOME="$TMP_ROOT/ubi-home"
UBI_BASE="$TMP_ROOT/launcher-root-ubi"
UBI_DRIVE="$UBI_BASE/ubisoft/drive_c"
UBI_PREFIX="$UBI_APP_DIR/game-launchers/ubisoft/compatdata"
UBI_EXE="$UBI_PREFIX/pfx/drive_c/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe"
UBI_PE="$UBI_STEAM/steamapps/common/Proton - Experimental/proton"
mkdir -p "$(dirname "$UBI_SHORTCUTS")" \
    "$UBI_STEAM/config" "$UBI_HOME/Desktop" "$UBI_PREFIX/pfx"
mkdir -p "$UBI_DRIVE"
ln -s "$UBI_DRIVE" "$UBI_PREFIX/pfx/drive_c"
mkdir -p "$(dirname "$UBI_EXE")"
: > "$UBI_EXE"
printf '%s\n' '"InstallConfigStore"' '{' '    "Software"' '    {' \
    '        "Valve"' '        {' '            "Steam"' '            {' \
    '            }' '        }' '    }' '}' > "$UBI_STEAM/config/config.vdf"
mkdir -p "$(dirname "$UBI_PE")"
printf '#!/bin/bash\nexit 0\n' > "$UBI_PE"
chmod +x "$UBI_PE"
ubi_output="$(
    MODULE="$MODULE" ZHOUKEER_STEAM_ROOT="$UBI_STEAM" \
        ZHOUKEER_SHORTCUT_FILE="$UBI_SHORTCUTS" \
        ZHOUKEER_APP_DIR="$UBI_APP_DIR" HOME="$UBI_HOME" \
        ZHOUKEER_SKIP_STEAM_RESTART=1 ZHOUKEER_LAUNCHER_BASE="$UBI_BASE" bash -c '
            source "$MODULE"
            detect_platform() { IS_STEAMOS=1; }
            install_launcher ubisoft
        '
)"
printf '%s\n' "$ubi_output" | grep -Fq '跳过安装包下载' || {
    echo "FAIL: 已安装育碧没有跳过安装包下载" >&2
    exit 1
}
python3 - "$UBI_SHORTCUTS" "$UBI_EXE" "$UBI_APP_DIR" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert sys.argv[2].encode() in data, "Steam 条目没有指向真实育碧 EXE"
assert b"launch-ubisoft.sh" not in data, "Steam 条目仍指向桌面包装器"
assert sys.argv[3].encode() in data
PY
grep -Fq '"proton_10"' "$UBI_STEAM/config/config.vdf" || {
    echo "FAIL: 育碧入库时没有绑定 Proton 10" >&2
    exit 1
}
ubi_app_id="$(python3 "$HELPER" --shortcut-file "$UBI_SHORTCUTS" appid \
    --name "育碧" --exe "$UBI_EXE")"
[ "$(readlink "$UBI_STEAM/steamapps/compatdata/$ubi_app_id/pfx/drive_c")" = \
    "$UBI_PREFIX/pfx/drive_c" ] || {
    echo "FAIL: 育碧 Steam compatdata drive_c 没有链接到共享前缀" >&2
    exit 1
}
grep -Fq "Exec=$UBI_APP_DIR/game-launchers/ubisoft/launch-ubisoft.sh" \
    "$UBI_HOME/Desktop/育碧.desktop" || {
    echo "FAIL: 育碧桌面入口没有使用独立启动包装器" >&2
    exit 1
}
ubi_grid="$UBI_STEAM/userdata/123/config/grid"
python3 "$HELPER" --shortcut-file "$UBI_SHORTCUTS" verify \
    --name "育碧" --exe "$UBI_EXE" --icon "$ubi_grid/${ubi_app_id}_icon.png" | grep -Fxq verified || {
    echo "FAIL: 育碧 Steam 条目没有使用 grid 图标" >&2
    exit 1
}

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
grep -Fq 'LAUNCHER_GITEE_MIRROR_ID="heihe"' "$MODULE" || {
    echo "FAIL: 黑盒工坊未使用 Gitee 镜像" >&2
    exit 1
}
grep -Fq '9e0bce560d8264eb015a020337167f57918babd755d1671c38a49f3cdb05654a' "$MODULE" || {
    echo "FAIL: 黑盒工坊安装包缺少固定 SHA256" >&2
    exit 1
}
grep -Fq '黑盒工坊' "$MODULE" || {
    echo "FAIL: 黑盒工坊目标缺失" >&2
    exit 1
}
grep -Fq 'prepare_launcher_steam_installer "$target"' "$MODULE" || {
    echo "FAIL: 黑盒工坊未走 Steam 库安装条目流程" >&2
    exit 1
}
grep -Fq 'finish_launcher_steam_entry "$target"' "$MODULE" || {
    echo "FAIL: 黑盒工坊未走 Steam 库转正流程" >&2
    exit 1
}
grep -Fq '桌面入口、封面与工具箱标识均已设置' "$MODULE"
grep -Fq '跳过安装包下载' "$MODULE"
grep -Fq 'find_launcher_in_prefix "$prefix" || find_installed_launcher' "$MODULE"
grep -Fq 'steam_shortcut.py' "$MODULE"
grep -Fq 'prepare_battlenet_steam_installer' "$MODULE"
! grep -Fq 'launch_steam_shortcut' "$MODULE" || {
    echo "FAIL: 战网仍会在 Steam 重启后立即触发 rungameid" >&2
    exit 1
}
grep -Fq 'finish_battlenet_steam_entry' "$MODULE"
grep -Fq 'steam://rungameid/$game_id' "$MODULE"
grep -Fq 'proton_experimental' "$MODULE"
grep -Fq 'create_launcher_desktop_shortcut' "$MODULE"
grep -Fq 'install_launcher_steam_artwork' "$MODULE"
grep -Fq 'set-icon' "$MODULE"
grep -Fq 'download_launcher_installer' "$MODULE"
grep -Fq '点击 Install（安装）' "$MODULE"
grep -Fq '请只在 Steam 库点击“${LAUNCHER_NAME}”完成安装' "$MODULE"
grep -Fq '右侧的齿轮' "$MODULE"
grep -Fq '强制使用兼容性工具' "$MODULE"
grep -Fq 'Proton 10.0-4' "$MODULE"
grep -Fq '选择中文并依次点击接受、安装、完成' "$MODULE"
grep -Fq 'ensure_launcher_proton_runner' "$MODULE"
grep -Fq 'install_official_proton_10 "$steam_root"' "$MODULE"
grep -Fq 'steam://install/$PROTON_10_APP_ID' "$MODULE"
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
grep -Fq -- '--user-agent' "$MODULE" || {
    echo "FAIL: 官方启动器下载缺少浏览器 UA" >&2
    exit 1
}
grep -Fq -- '--compressed' "$MODULE" || {
    echo "FAIL: 官方启动器下载缺少压缩响应支持" >&2
    exit 1
}
grep -Fq -- '--http1.1' "$MODULE" || {
    echo "FAIL: 官方启动器下载缺少备用请求方式" >&2
    exit 1
}
grep -Fq 'LAUNCHER_FALLBACK_URL' "$MODULE" || {
    echo "FAIL: Epic 缺少官方 CDN 备用线路" >&2
    exit 1
}
grep -Fq 'LAUNCHER_GITEE_MIRROR_ID="epic"' "$MODULE" || {
    echo "FAIL: Epic 未启用 Gitee 分块镜像优先" >&2
    exit 1
}
grep -Fq '1513d6cc2afda0367c8375b6f25f490c162da5607ce4b4adbb41906a2d742236' "$MODULE" || {
    echo "FAIL: Epic Gitee 镜像缺少固定 MSI SHA256" >&2
    exit 1
}
grep -Fq 'EpicInstaller-20.1.4.msi' "$MODULE" || {
    echo "FAIL: Epic 镜像安装包文件名缺失" >&2
    exit 1
}
grep -Fq '1513d6cc2afda0367c8375b6f25f490c162da5607ce4b4adbb41906a2d742236' "$MODULE" || {
    echo "FAIL: Epic 官方 CDN 备用包缺少固定 SHA256" >&2
    exit 1
}

echo "PASS: Steam条目写入、启动器安装和战网分步Steam流程测试通过"
