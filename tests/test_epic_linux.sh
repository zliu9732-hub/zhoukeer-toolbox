#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$TMP_ROOT/user space"
export ZHOUKEER_APP_DIR="$HOME/apps"
export ZHOUKEER_STEAM_ROOT="$HOME/Steam"
export ZHOUKEER_DESKTOP_DIR="$HOME/桌面"
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_AUTO_CONFIRM=1
unset XDG_DATA_HOME XDG_CONFIG_HOME
mkdir -p "$ZHOUKEER_STEAM_ROOT/steamapps" "$ZHOUKEER_STEAM_ROOT/config" \
    "$ZHOUKEER_STEAM_ROOT/userdata/123/config"
source "$PROJECT_ROOT/modules/epic_linux.sh"
log() { return 0; }
detect_platform() { IS_STEAMOS=1; }
uname() { [ "${1:-}" = -m ] && printf '%s\n' x86_64; }
id() { [ "${1:-}" = -u ] && printf '%s\n' 1000; }
require_command() { return 0; }
SHORTCUTS="$ZHOUKEER_STEAM_ROOT/userdata/123/config/shortcuts.vdf"
find_shortcut_file() { printf '%s\n' "$SHORTCUTS"; }
CALLS="$TMP_ROOT/calls"
stop_steam_for_vdf() { printf 'stop\n' >> "$CALLS"; }
start_steam() { printf 'start\n' >> "$CALLS"; }
launcher_cover_file() { printf '%s\n' "$PROJECT_ROOT/assets/icon-toolbox-deck.png"; }
install_launcher_artwork_for_id() { printf 'artwork:%s\n' "$1" >> "$CALLS"; }
FIXTURE="$TMP_ROOT/Epic.AppImage"
python3 - "$FIXTURE" <<'PY'
from pathlib import Path
import sys
b=bytearray(128)
b[:6]=b'\x7fELF\x02\x01'
b[8:11]=b'AI\x02'
b[18:20]=b'\x3e\x00'
Path(sys.argv[1]).write_bytes(b)
PY
EPIC_LINUX_BYTES=128
EPIC_LINUX_SHA256="$(shasum -a 256 "$FIXTURE" | awk '{print $1}')"
MIRROR_MODE=ok
OFFICIAL_MODE=ok
download_gitee_mirror_file() {
    [ "$1" = epic-linux ] || fail '安装未使用独立镜像标识'
    [ "$3" = "$EPIC_LINUX_SHA256" ] || fail '镜像未使用固定校验值'
    printf 'mirror\n' >> "$CALLS"
    case "$MIRROR_MODE" in
        fail) return 1 ;;
        io) DOWNLOAD_LOCAL_IO_FAILED=1; return 1 ;;
    esac
    cp "$FIXTURE" "$2"
    [ "$MIRROR_MODE" != corrupt ] || printf 'corrupt' >> "$2"
    return 0
}
download_github_file() {
    [ "$1" = "$EPIC_LINUX_URL" ] && [ "$3" = "$EPIC_LINUX_SHA256" ] || fail '备用下载没有使用同一官方固定包'
    printf 'official\n' >> "$CALLS"
    [ "$OFFICIAL_MODE" = ok ] || return 1
    cp "$FIXTURE" "$2"
}

[ "$(gitee_mirror_manifest_repo epic-linux)" = zhoukeer-toolbox-mirror-4 ] || fail 'Epic Linux 镜像仓库错误'
epic_linux_file_valid "$FIXTURE" || fail '有效 x86-64 AppImage 被拒绝'
cp "$FIXTURE" "$TMP_ROOT/wrong-arch"
python3 - "$TMP_ROOT/wrong-arch" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); b=bytearray(p.read_bytes()); b[18:20]=b'\xb7\x00'; p.write_bytes(b)
PY
if (EPIC_LINUX_SHA256="$(shasum -a 256 "$TMP_ROOT/wrong-arch" | awk '{print $1}')"; epic_linux_file_valid "$TMP_ROOT/wrong-arch"); then
    fail '其他架构被当作 x86-64 AppImage'
fi

printf 'untouched Steam config\n' > "$ZHOUKEER_STEAM_ROOT/config/config.vdf"
python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$SHORTCUTS" add \
    --name 'Epic Games 启动器' --exe "$HOME/Windows/Epic.exe" --start-dir "$HOME/Windows" >/dev/null
install_epic_linux > "$TMP_ROOT/install.out" || fail '首次安装失败'
IMAGE="$EPIC_LINUX_DIR/EpicGamesLauncher.AppImage"
WRAPPER="$EPIC_LINUX_DIR/launch-epic-linux.sh"
epic_linux_file_valid "$IMAGE" || fail '安装内容不正确'
[ -x "$IMAGE" ] && [ -x "$WRAPPER" ] || fail '程序或启动入口不可执行'
[ -x "$ZHOUKEER_DESKTOP_DIR/Epic Linux 版.desktop" ] || fail '未在本地化桌面创建入口'
[ -f "$HOME/.local/share/applications/renkit-epic-linux.desktop" ] || fail '未创建应用菜单入口'
python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name "$EPIC_LINUX_NAME" --exe "$WRAPPER" --icon "$EPIC_LINUX_DIR/icon.png" >/dev/null || fail '未添加 Linux Steam 条目'
python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name 'Epic Games 启动器' --exe "$HOME/Windows/Epic.exe" >/dev/null || fail '覆盖了 Windows Epic 条目'
grep -Fxq 'untouched Steam config' "$ZHOUKEER_STEAM_ROOT/config/config.vdf" || fail '原生客户端被配置为 Windows 兼容工具'
grep -Fxq mirror "$CALLS" || fail '没有优先使用国内下载'
if grep -Fxq official "$CALLS"; then fail '镜像成功仍进行备用下载'; fi

# 只执行自己的启动包装器和本地假程序，不执行任何真实 AppImage。
cat > "$IMAGE" <<'SH'
#!/bin/bash
printf '%s|%s|%s|%s\n' "$APPIMAGE_EXTRACT_AND_RUN" "${LD_LIBRARY_PATH+set}" "${LD_PRELOAD+set}" "$1" > "$EPIC_TEST_RESULT"
SH
export EPIC_TEST_RESULT="$TMP_ROOT/wrapper-result"
LD_LIBRARY_PATH=/fake LD_PRELOAD=/fake bash "$WRAPPER" 'argument with spaces'
grep -Fxq '1|||argument with spaces' "$EPIC_TEST_RESULT" || fail '启动器未清理 Steam 环境或丢失参数'
cp "$FIXTURE" "$IMAGE"
chmod +x "$IMAGE"

: > "$CALLS"
install_epic_linux > "$TMP_ROOT/repeat.out" || fail '重复安装无法修复入口'
if grep -Eq '^(mirror|official)$' "$CALLS"; then fail '当前完整版本重复下载'; fi
python3 - "$SHORTCUTS" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1]).read_bytes()
assert b.count('Epic Games（Linux 版）'.encode())==1
assert b.count('Epic Games 启动器'.encode())==1
PY

printf 'old program\n' > "$IMAGE"
MIRROR_MODE=fail OFFICIAL_MODE=fail
: > "$CALLS"
if install_epic_linux > "$TMP_ROOT/download-fail.out" 2>&1; then fail '双源失败仍返回成功'; fi
grep -Fxq 'old program' "$IMAGE" || fail '下载失败覆盖了旧程序'
grep -Fxq official "$CALLS" || fail '国内下载失败未尝试官方固定包'
if grep -Fxq stop "$CALLS"; then fail '下载失败仍改动 Steam'; fi

MIRROR_MODE=corrupt OFFICIAL_MODE=ok
if install_epic_linux > "$TMP_ROOT/corrupt.out" 2>&1; then fail '损坏文件仍安装成功'; fi
grep -Fxq 'old program' "$IMAGE" || fail '损坏文件覆盖了旧程序'
MIRROR_MODE=io
: > "$CALLS"
if install_epic_linux > "$TMP_ROOT/io.out" 2>&1; then fail '本地写入失败仍成功'; fi
if grep -Fxq official "$CALLS"; then fail '本地写入失败仍尝试备用下载'; fi
if find "$EPIC_LINUX_DIR" -name '.install.*' | grep -q .; then fail '失败后残留安装临时目录'; fi

MIRROR_MODE=ok
install_epic_linux >/dev/null || fail '失败后无法重新安装'
mv "$IMAGE" "$IMAGE.saved"
printf 'outside\n' > "$TMP_ROOT/outside"
ln -s "$TMP_ROOT/outside" "$IMAGE"
if install_epic_linux >/dev/null 2>&1; then fail '安装接受了符号链接目标'; fi
grep -Fxq outside "$TMP_ROOT/outside" || fail '符号链接导致外部文件被修改'
rm "$IMAGE"
mv "$IMAGE.saved" "$IMAGE"

cp "$SHORTCUTS" "$TMP_ROOT/shortcuts.saved"
printf 'invalid vdf' > "$SHORTCUTS"
: > "$CALLS"
if install_epic_linux > "$TMP_ROOT/steam-fail.out" 2>&1; then fail 'Steam 条目写入失败仍成功'; fi
grep -Fxq start "$CALLS" || fail 'Steam 条目写入失败后未重新启动 Steam'
grep -Fxq 'invalid vdf' "$SHORTCUTS" || fail '覆盖了无法解析的 Steam 文件'
cp "$TMP_ROOT/shortcuts.saved" "$SHORTCUTS"

mkdir -p "$EPIC_LINUX_DIR/games" "$HOME/.config/epic-test"
printf 'keep game\n' > "$EPIC_LINUX_DIR/games/keep"
printf 'keep settings\n' > "$HOME/.config/epic-test/settings"
uninstall_epic_linux > "$TMP_ROOT/uninstall.out" || fail '卸载失败'
[ ! -e "$IMAGE" ] && [ ! -e "$WRAPPER" ] || fail '卸载后残留程序'
[ ! -e "$ZHOUKEER_DESKTOP_DIR/Epic Linux 版.desktop" ] || fail '卸载后残留桌面入口'
grep -Fxq 'keep game' "$EPIC_LINUX_DIR/games/keep" || fail '卸载删除了游戏'
grep -Fxq 'keep settings' "$HOME/.config/epic-test/settings" || fail '卸载删除了设置'
python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name 'Epic Games 启动器' --exe "$HOME/Windows/Epic.exe" >/dev/null || fail '卸载 Linux 版删除了 Windows 版'
if python3 "$STEAM_SHORTCUT_HELPER" --shortcut-file "$SHORTCUTS" verify \
    --name "$EPIC_LINUX_NAME" --exe "$WRAPPER" >/dev/null 2>&1; then fail '卸载后残留 Linux Steam 条目'; fi
if grep -Eiq 'gitee|镜像|AppImage|https://' "$TMP_ROOT/install.out"; then fail '安装界面泄露内部下载信息'; fi
echo 'PASS: Epic Linux 安装、桌面与 Steam 入口、国内优先、完整校验、重复安装和安全卸载模拟通过'
