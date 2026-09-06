#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

CHIMERA_RELEASE="$TMP_ROOT/chimera-release"
INJECTION_MARKER="$TMP_ROOT/os-release-was-executed"
cat > "$CHIMERA_RELEASE" <<EOF
ID=chimeraos
ID_LIKE=arch
PRETTY_NAME="ChimeraOS 50"
UNTRUSTED=\$(touch "$INJECTION_MARKER")
EOF

platform_result="$({
    ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE"
    source "$PROJECT_ROOT/core/platform.sh"
    detect_platform
    require_chimeraos
    printf '%s|%s|%s|%s|%s\n' \
        "$PLATFORM_FAMILY" "$IS_STEAMOS" "$IS_BAZZITE" "$IS_CHIMERAOS" "$PLATFORM_NAME"
})"
[ "$platform_result" = "chimeraos|0|0|1|ChimeraOS 50" ] || \
    fail "ChimeraOS 平台识别错误：$platform_result"
[ ! -e "$INJECTION_MARKER" ] || fail "os-release 内容被当成 Shell 执行"

# ChimeraOS 不进入 SteamOS/Bazzite 的系统级功能门禁，避免 Clover 等模块被误开放。
if (
    ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE"
    source "$PROJECT_ROOT/core/platform.sh"
    require_supported_gaming_os >/dev/null 2>&1
); then
    fail "ChimeraOS 被误加入 SteamOS/Bazzite 系统级功能门禁"
fi

LAUNCH_APP="$TMP_ROOT/launch-app"
BIN_DIR="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
mkdir -p "$LAUNCH_APP/core" "$BIN_DIR" "$HOME_DIR"
cp "$PROJECT_ROOT/launch.sh" "$LAUNCH_APP/launch.sh"
cp "$PROJECT_ROOT/core/platform.sh" "$LAUNCH_APP/core/platform.sh"
cat > "$LAUNCH_APP/main.sh" <<'EOF'
#!/bin/bash
echo STEAMOS_MAIN
EOF
cat > "$LAUNCH_APP/main-bazzite.sh" <<'EOF'
#!/bin/bash
echo BAZZITE_MAIN
EOF
cat > "$LAUNCH_APP/main-chimera.sh" <<'EOF'
#!/bin/bash
echo CHIMERA_MAIN
EOF
cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
chmod +x "$LAUNCH_APP"/*.sh "$BIN_DIR/uname"

launch_output="$(HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" ZHOUKEER_SKIP_STARTUP_UPDATE=1 \
    ZHOUKEER_LAUNCH_LOG="$TMP_ROOT/chimera-launch.log" \
    bash "$LAUNCH_APP/launch.sh" --run-main)"
printf '%s\n' "$launch_output" | grep -Fq CHIMERA_MAIN || \
    fail "ChimeraOS 没有进入独立主程序"
if printf '%s\n' "$launch_output" | grep -Eq 'STEAMOS_MAIN|BAZZITE_MAIN'; then
    fail "ChimeraOS 误进入 SteamOS 或 Bazzite 主程序"
fi

grep -Fq 'RENKIT_PLATFORM_LABEL="CHIMERAOS 掌机  /  应用与插件"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 主程序缺少独立平台标识"
grep -Fq 'ZHOUKEER_FLATPAK_SOURCE_MODE="official"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 应用安装未固定为官方 Flathub"
grep -Fq 'chimera_plugin_environment_ready' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 插件安装缺少现有环境检查"
grep -Fq 'modules/plugin_store.sh" "$action"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 缺少直接插件安装入口"

if grep -En 'modules/(bazzite_decky|decky_bundle|clover_boot|dual_system|dual_system_tools|memory_tuning|steam_accelerator|domestic_source|new_machine|emulators|game_launchers|todesk)\.sh' \
    "$PROJECT_ROOT/main-chimera.sh"; then
    fail "ChimeraOS 菜单暴露了禁止的系统、磁盘、商城或非目标功能"
fi
if grep -En 'ujust setup-decky|plugin_store\.sh" (store|store-test|store-auto|store-uninstall)' \
    "$PROJECT_ROOT/main-chimera.sh"; then
    fail "ChimeraOS 菜单试图管理插件商城本体"
fi
grep -Fq 'Renkit ChimeraOS版不会安装或替换插件商城本体' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "插件模块缺少 ChimeraOS Loader 保护"
grep -Fq 'require_existing_chimera_plugin_environment || return 1' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 直接插件安装没有强制检查现有 Loader"
grep -Fq 'Renkit不会重启 ChimeraOS 自带服务' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 插件安装仍可能重启系统服务"
grep -Fq '[ "$IS_CHIMERAOS" -eq 1 ] || ensure_steam302_for_download || true' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 的 Unifideck 仍会启动 Steam302"
grep -Fq 'Renkit不会提权修改系统或 Loader 文件' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 插件目录仍可能使用 sudo 写入"

# 即使命令行绕过菜单，也不能安装/卸载插件商城或机型控制插件。
CHIMERA_HOME="$TMP_ROOT/chimera-home"
mkdir -p "$CHIMERA_HOME"
if HOME="$CHIMERA_HOME" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" cheatdeck \
        > "$TMP_ROOT/no-loader.out" 2>&1; then
    fail "未检测到系统 Loader 时仍允许安装 ChimeraOS 插件"
fi
grep -Fq '不会安装或替换插件商城本体' "$TMP_ROOT/no-loader.out" || \
    fail "缺少 ChimeraOS 现有 Loader 保护提示"

mkdir -p "$CHIMERA_HOME/homebrew/services"
: > "$CHIMERA_HOME/homebrew/services/PluginLoader"
chmod +x "$CHIMERA_HOME/homebrew/services/PluginLoader"
if HOME="$CHIMERA_HOME" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" store \
        > "$TMP_ROOT/store-blocked.out" 2>&1; then
    fail "ChimeraOS 命令行仍允许管理插件商城"
fi
grep -Fq '不管理插件商城或机型控制组件' "$TMP_ROOT/store-blocked.out" || \
    fail "ChimeraOS 插件商城命令行保护提示缺失"
if HOME="$CHIMERA_HOME" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" allycenter \
        > "$TMP_ROOT/hardware-blocked.out" 2>&1; then
    fail "ChimeraOS 命令行仍允许安装机型控制插件"
fi
grep -Fq '不管理插件商城或机型控制组件' "$TMP_ROOT/hardware-blocked.out" || \
    fail "ChimeraOS 机型插件命令行保护提示缺失"

grep -Fq 'main-chimera.sh' "$PROJECT_ROOT/install.sh" || \
    fail "安装器没有携带 ChimeraOS 主程序"
grep -Fq 'main-chimera.sh' "$PROJECT_ROOT/scripts/package_release.sh" || \
    fail "发布包没有校验 ChimeraOS 主程序"

# 在隔离 HOME 中执行一次真实安装，确认独立入口、平台标记和桌面名称落盘。
INSTALL_HOME="$TMP_ROOT/install-home"
INSTALL_TARGET="$INSTALL_HOME/.local/share/zhoukeer-toolbox"
mkdir -p "$INSTALL_HOME/Desktop"
HOME="$INSTALL_HOME" ZHOUKEER_INSTALL_DIR="$INSTALL_TARGET" \
    ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    bash "$PROJECT_ROOT/install.sh" > "$TMP_ROOT/install.out"
[ -x "$INSTALL_TARGET/main-chimera.sh" ] || \
    fail "ChimeraOS 安装后缺少独立主程序"
[ "$(cat "$INSTALL_TARGET/.renkit-platform")" = "chimeraos" ] || \
    fail "ChimeraOS 安装平台标记错误"
grep -Fq 'Name=Renkit ChimeraOS版' "$INSTALL_HOME/Desktop/Renkit.desktop" || \
    fail "ChimeraOS 桌面入口名称错误"
grep -Fq 'ChimeraOS 应用与插件工具' "$INSTALL_HOME/Desktop/Renkit.desktop" || \
    fail "ChimeraOS 桌面入口说明错误"

# 模拟官方 Flathub，确认 ChimeraOS 应用安装只写入当前用户范围。
APP_BIN="$TMP_ROOT/app-bin"
APP_STATE="$TMP_ROOT/app-state"
mkdir -p "$APP_BIN" "$APP_STATE"
cat > "$APP_BIN/flatpak" <<'EOF'
#!/bin/sh
case "${1:-}" in
    info) exit 1 ;;
    remotes) printf 'flathub\n' ;;
    install) printf '%s\n' "$*" >> "${CHIMERA_APP_STATE:?}/commands" ;;
    *) exit 1 ;;
esac
EOF
cat > "$APP_BIN/timeout" <<'EOF'
#!/bin/sh
[ "${1:-}" != "--foreground" ] || shift
[ "$#" -eq 0 ] || shift
exec "$@"
EOF
chmod +x "$APP_BIN/flatpak" "$APP_BIN/timeout"
: > "$APP_STATE/commands"
HOME="$CHIMERA_HOME" PATH="$APP_BIN:/usr/bin:/bin" \
    CHIMERA_APP_STATE="$APP_STATE" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    ZHOUKEER_FLATPAK_SOURCE_MODE=official \
    bash "$PROJECT_ROOT/modules/software.sh" chrome > "$TMP_ROOT/app-install.out"
grep -Fq 'install --user --noninteractive -y flathub com.google.Chrome' \
    "$APP_STATE/commands" || fail "ChimeraOS 应用安装没有使用用户级官方 Flathub"

echo "PASS: ChimeraOS 独立分流、应用/插件范围与系统功能隔离测试通过"
