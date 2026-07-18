#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
CALL_LOG="$TMP_ROOT/terminal-call.log"
LAUNCH_LOG="$TMP_ROOT/launcher.log"
DIALOG_LOG="$TMP_ROOT/dialog.log"
mkdir -p "$BIN_DIR" "$HOME_DIR/.local/share/konsole"
touch "$HOME_DIR/.local/share/konsole/ZhoukeerToolbox.profile"
touch "$HOME_DIR/.local/share/konsole/ZhoukeerToolboxSplash.profile"

cat > "$BIN_DIR/konsole" <<'SCRIPT'
#!/bin/bash
if [ "${1:-}" = "--help" ]; then
    printf '%s\n' "${FAKE_KONSOLE_HELP:-}"
    exit 0
fi
printf 'konsole %s\n' "$*" >> "$FAKE_TERMINAL_CALL_LOG"
case "${FAKE_KONSOLE_FAILURE:-none}" in
    profile)
        case " $* " in *' --profile '*) exit 23 ;; esac
        ;;
    all) exit 24 ;;
esac
exit 0
SCRIPT
chmod +x "$BIN_DIR/konsole"

cat > "$BIN_DIR/xterm" <<'SCRIPT'
#!/bin/bash
printf 'xterm %s\n' "$*" >> "$FAKE_TERMINAL_CALL_LOG"
exit "${FAKE_XTERM_STATUS:-0}"
SCRIPT
chmod +x "$BIN_DIR/xterm"

cat > "$BIN_DIR/kdialog" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_DIALOG_LOG"
SCRIPT
chmod +x "$BIN_DIR/kdialog"

run_launcher() {
    : > "$CALL_LOG"
    : > "$LAUNCH_LOG"
    : > "$DIALOG_LOG"
    HOME="$HOME_DIR" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_LAUNCH_LOG="$LAUNCH_LOG" \
    FAKE_TERMINAL_CALL_LOG="$CALL_LOG" \
    FAKE_DIALOG_LOG="$DIALOG_LOG" \
    FAKE_KONSOLE_HELP="$1" \
    FAKE_KONSOLE_FAILURE="${2:-none}" \
    FAKE_XTERM_STATUS="${3:-0}" \
        bash "$PROJECT_ROOT/launch.sh"
}

run_launcher $'--profile\n--workdir'
if grep -Fq -- '--geometry' "$CALL_LOG"; then
    echo "FAIL: 不支持 --geometry 时仍传入了该参数"
    exit 1
fi
grep -Fq -- '--profile' "$CALL_LOG"
grep -Fq -- '--workdir' "$CALL_LOG"
grep -Fq -- 'ZhoukeerToolboxSplash.profile' "$CALL_LOG"
grep -Fq -- 'ZHOUKEER_STARTUP_SPLASH=1' "$CALL_LOG"

run_launcher $'--profile\n--workdir\n--geometry'
grep -Fq -- '--geometry 1280x820' "$CALL_LOG"

run_launcher $'--profile\n--workdir\n--fullscreen'
if grep -Fq -- '--fullscreen' "$CALL_LOG"; then
    echo "FAIL: 启动器不应把全屏作为窗口大小后备方案"
    exit 1
fi

: > "$CALL_LOG"
HOME="$HOME_DIR" \
PATH="$BIN_DIR:/usr/bin:/bin" \
ZHOUKEER_LAUNCH_LOG="$LAUNCH_LOG" \
FAKE_TERMINAL_CALL_LOG="$CALL_LOG" \
FAKE_KONSOLE_HELP=$'--profile\n--workdir\n--geometry' \
    bash "$PROJECT_ROOT/launch.sh" --open-main
grep -Fq -- 'ZhoukeerToolbox.profile' "$CALL_LOG"
if grep -Fq -- 'ZhoukeerToolboxSplash.profile' "$CALL_LOG"; then
    echo "FAIL: 主界面仍使用欢迎页主题"
    exit 1
fi
grep -Fq -- 'ZHOUKEER_SKIP_DISCLAIMER=1' "$CALL_LOG"
grep -Fq -- 'ZHOUKEER_SKIP_STARTUP_UPDATE=1' "$CALL_LOG"

mv "$HOME_DIR/.local/share/konsole/ZhoukeerToolboxSplash.profile" \
    "$HOME_DIR/.local/share/konsole/ZhoukeerToolboxSplash.profile.disabled"
run_launcher $'--profile\n--workdir\n--geometry'
grep -Fq -- 'ZhoukeerToolbox.profile' "$CALL_LOG"
if grep -Fq -- 'ZHOUKEER_SKIP_DISCLAIMER=1' "$CALL_LOG"; then
    echo "FAIL: 旧版安装缺少欢迎页主题时不应跳过免责声明"
    exit 1
fi
grep -Fq -- 'ZHOUKEER_STARTUP_SPLASH=0' "$CALL_LOG"
mv "$HOME_DIR/.local/share/konsole/ZhoukeerToolboxSplash.profile.disabled" \
    "$HOME_DIR/.local/share/konsole/ZhoukeerToolboxSplash.profile"

run_launcher $'--profile\n--workdir\n--geometry' profile
if [ "$(grep -c '^konsole ' "$CALL_LOG")" -ne 2 ]; then
    echo "FAIL: 主题启动失败后未进入Konsole兼容模式"
    exit 1
fi
sed -n '2p' "$CALL_LOG" | grep -Fq -- '--geometry 1280x820'
if sed -n '2p' "$CALL_LOG" | grep -Fq -- '--profile'; then
    echo "FAIL: Konsole兼容模式仍使用主题参数"
    exit 1
fi

run_launcher $'--profile\n--workdir\n--geometry' all
grep -Fq 'xterm -e env ZHOUKEER_STARTUP_SPLASH=1 bash' "$CALL_LOG"
grep -Fq 'Konsole 各级启动均不可用' "$LAUNCH_LOG"

mv "$BIN_DIR/konsole" "$BIN_DIR/konsole.disabled"
mv "$BIN_DIR/xterm" "$BIN_DIR/xterm.disabled"
if run_launcher '' none 1; then
    echo "FAIL: 没有可用终端时启动器错误返回成功"
    exit 1
fi
grep -Fq '周克儿工具箱启动失败' "$DIALOG_LOG"
grep -Fq "$LAUNCH_LOG" "$DIALOG_LOG"

FAIL_APP="$TMP_ROOT/failing-app"
mkdir -p "$FAIL_APP"
cp "$PROJECT_ROOT/launch.sh" "$FAIL_APP/launch.sh"
cat > "$FAIL_APP/main.sh" <<'SCRIPT'
#!/bin/bash
echo "模拟主程序错误" >&2
exit 37
SCRIPT
chmod +x "$FAIL_APP/launch.sh" "$FAIL_APP/main.sh"
: > "$LAUNCH_LOG"
: > "$DIALOG_LOG"
if HOME="$HOME_DIR" \
    PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_LAUNCH_LOG="$LAUNCH_LOG" \
    FAKE_DIALOG_LOG="$DIALOG_LOG" \
        bash "$FAIL_APP/launch.sh" --run-main; then
    echo "FAIL: 主程序异常退出时启动器错误返回成功"
    exit 1
fi
grep -Fq '模拟主程序错误' "$LAUNCH_LOG"
grep -Fq '主程序结束：状态码=37' "$LAUNCH_LOG"
grep -Fq '主程序异常退出（状态码：37）' "$DIALOG_LOG"

echo "PASS: 启动器多级兼容、失败提示与独立日志测试通过"
