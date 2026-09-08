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
SKORION_RELEASE="$TMP_ROOT/skorion-release"
INJECTION_MARKER="$TMP_ROOT/os-release-was-executed"
cat > "$CHIMERA_RELEASE" <<EOF
ID=chimeraos
ID_LIKE="arch steamos"
PRETTY_NAME="ChimeraOS 50"
UNTRUSTED=\$(touch "$INJECTION_MARKER")
EOF

cat > "$SKORION_RELEASE" <<'EOF'
ID=skorionos
ID_LIKE=arch
PRETTY_NAME="SkorionOS 56"
EOF

DESKTOP_HOME="$TMP_ROOT/desktop-home"
mkdir -p "$DESKTOP_HOME/.config" "$DESKTOP_HOME/桌面"
cat > "$DESKTOP_HOME/.config/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/桌面"
EOF
desktop_result="$(
    HOME="$DESKTOP_HOME"
    XDG_CONFIG_HOME="$DESKTOP_HOME/.config"
    source "$PROJECT_ROOT/core/desktop_paths.sh"
    renkit_desktop_dir
)"
[ "$desktop_result" = "$DESKTOP_HOME/桌面" ] || \
    fail "GNOME 本地化桌面目录识别错误：$desktop_result"

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

platform_result="$({
    ZHOUKEER_OS_RELEASE_FILE="$SKORION_RELEASE"
    source "$PROJECT_ROOT/core/platform.sh"
    detect_platform
    require_chimeraos
    printf '%s|%s|%s|%s|%s\n' \
        "$PLATFORM_FAMILY" "$IS_STEAMOS" "$IS_BAZZITE" "$IS_CHIMERAOS" "$PLATFORM_NAME"
})"
[ "$platform_result" = "chimeraos|0|0|1|SkorionOS 56" ] || \
    fail "SkorionOS 平台识别错误：$platform_result"

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

launch_output="$(HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$SKORION_RELEASE" ZHOUKEER_SKIP_STARTUP_UPDATE=1 \
    ZHOUKEER_LAUNCH_LOG="$TMP_ROOT/skorion-launch.log" \
    bash "$LAUNCH_APP/launch.sh" --run-main)"
printf '%s\n' "$launch_output" | grep -Fq CHIMERA_MAIN || \
    fail "SkorionOS 没有进入 ChimeraOS 独立主程序"
if printf '%s\n' "$launch_output" | grep -Eq 'STEAMOS_MAIN|BAZZITE_MAIN'; then
    fail "SkorionOS 误进入 SteamOS 或 Bazzite 主程序"
fi

grep -Fq 'RENKIT_PLATFORM_LABEL="CHIMERAOS 掌机  /  应用与插件"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 主程序缺少独立平台标识"
grep -Fq 'ZHOUKEER_FLATPAK_SOURCE_MODE="managed"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS Flatpak 下载线路未使用受控选择"
grep -Fq 'modules/software.sh" enable-domestic-remotes' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 缺少国内 Flatpak 下载入口"
grep -Fq 'modules/software.sh" restore-official-remote' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 缺少恢复官方 Flathub 入口"
grep -Fq 'flathub-cn｜https://mirror.sjtu.edu.cn/flathub' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 国内源确认未显示上海交大远程名称与地址"
grep -Fq 'flathub-ustc｜https://mirrors.ustc.edu.cn/flathub' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 国内源确认未显示中科大远程名称与地址"
grep -Fq 'chimera_plugin_environment_ready' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 插件安装缺少现有环境检查"
grep -Fq 'modules/plugin_store.sh" "$action"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 缺少直接插件安装入口"
grep -Fq 'lsfg-zh-gitee lsfg-mako' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 小黄鸭菜单没有同时提供旧版与 MAKO"
grep -Fq 'lsfg-mako|lsfg-zh|lsfg-zh-gitee|' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 插件安全清单未放行旧版小黄鸭"
grep -Fq 'run_action "$title" run_confirmed_action "$@"' \
    "$PROJECT_ROOT/main-chimera.sh" || fail "ChimeraOS 确认操作不能调用 Shell 函数"
if grep -Fq 'run_action "$title" env ZHOUKEER_AUTO_CONFIRM=1 "$@"' \
    "$PROJECT_ROOT/main-chimera.sh"; then
    fail "ChimeraOS 仍通过 env 错误调用 Shell 函数"
fi

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
grep -Fq 'chimera_plugin_root_is_user_scoped' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 插件目录权限修复缺少用户路径限制"
grep -Fq 'chown -R --no-dereference' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 插件目录权限修复缺少禁止跟随链接保护"
grep -Fq '不会修改 PluginLoader、服务或 ChimeraOS 系统' \
    "$PROJECT_ROOT/modules/plugin_store.sh" || fail "ChimeraOS 插件目录权限修复提示不完整"

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
mkdir -p "$INSTALL_HOME/.config" "$INSTALL_HOME/桌面"
cat > "$INSTALL_HOME/.config/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/桌面"
EOF
HOME="$INSTALL_HOME" XDG_CONFIG_HOME="$INSTALL_HOME/.config" \
    ZHOUKEER_INSTALL_DIR="$INSTALL_TARGET" \
    ZHOUKEER_OS_RELEASE_FILE="$SKORION_RELEASE" \
    bash "$PROJECT_ROOT/install.sh" > "$TMP_ROOT/install.out"
[ -x "$INSTALL_TARGET/main-chimera.sh" ] || \
    fail "ChimeraOS 安装后缺少独立主程序"
[ "$(cat "$INSTALL_TARGET/.renkit-platform")" = "chimeraos" ] || \
    fail "SkorionOS 安装平台标记错误"
grep -Fq 'Name=Renkit ChimeraOS版' "$INSTALL_HOME/桌面/Renkit.desktop" || \
    fail "ChimeraOS 桌面入口名称错误"
grep -Fq 'ChimeraOS 应用与插件工具' "$INSTALL_HOME/桌面/Renkit.desktop" || \
    fail "ChimeraOS 桌面入口说明错误"

# 模拟官方 Flathub，确认 ChimeraOS 应用安装只写入当前用户范围。
APP_BIN="$TMP_ROOT/app-bin"
APP_STATE="$TMP_ROOT/app-state"
mkdir -p "$APP_BIN" "$APP_STATE"
cat > "$APP_BIN/flatpak" <<'EOF'
#!/bin/sh
case "${1:-}" in
    info)
        for argument in "$@"; do app_id="$argument"; done
        grep -Fxq "$app_id" "${CHIMERA_APP_STATE:?}/installed" 2>/dev/null
        ;;
    remotes)
        if [ -s "${CHIMERA_APP_STATE:?}/remotes" ]; then
            cat "${CHIMERA_APP_STATE:?}/remotes"
        else
            printf 'flathub\n'
        fi
        ;;
    remote-add)
        printf '%s\n' "$*" >> "${CHIMERA_APP_STATE:?}/commands"
        for argument in "$@"; do
            case "$argument" in
                flathub|flathub-cn|flathub-ustc) printf '%s\n' "$argument" >> "${CHIMERA_APP_STATE:?}/remotes" ;;
            esac
        done
        ;;
    remote-modify)
        printf '%s\n' "$*" >> "${CHIMERA_APP_STATE:?}/commands"
        for argument in "$@"; do
            case "$argument" in
                --gpg-import=*)
                    key_file="${argument#--gpg-import=}"
                    [ "$(cat "$key_file" 2>/dev/null)" = "DummyKey" ] || exit 1
                    ;;
            esac
        done
        ;;
    remote-delete) printf '%s\n' "$*" >> "${CHIMERA_APP_STATE:?}/commands" ;;
    install)
        printf '%s\n' "$*" >> "${CHIMERA_APP_STATE:?}/commands"
        for argument in "$@"; do app_id="$argument"; done
        printf '%s\n' "$app_id" >> "${CHIMERA_APP_STATE:?}/installed"
        ;;
    *) exit 1 ;;
esac
EOF
cat > "$APP_BIN/curl" <<'EOF'
#!/bin/sh
output=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) shift; output="${1:-}" ;;
    esac
    shift
done
[ -n "$output" ] || exit 1
printf '%s\n' '[Flatpak Repo]' 'Title=Flathub' 'Url=https://dl.flathub.org/repo/' 'GPGKey=RHVtbXlLZXk=' > "$output"
EOF
cat > "$APP_BIN/timeout" <<'EOF'
#!/bin/sh
[ "${1:-}" != "--foreground" ] || shift
[ "$#" -eq 0 ] || shift
exec "$@"
EOF
chmod +x "$APP_BIN/flatpak" "$APP_BIN/curl" "$APP_BIN/timeout"
: > "$APP_STATE/commands"
: > "$APP_STATE/installed"
HOME="$CHIMERA_HOME" PATH="$APP_BIN:/usr/bin:/bin" \
    CHIMERA_APP_STATE="$APP_STATE" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    ZHOUKEER_FLATPAK_SOURCE_MODE=official ZHOUKEER_AUTO_CONFIRM=1 \
    bash "$PROJECT_ROOT/modules/software.sh" chrome > "$TMP_ROOT/app-install.out"
grep -Fq 'install --user --noninteractive -y flathub com.google.Chrome' \
    "$APP_STATE/commands" || fail "ChimeraOS 应用安装没有使用用户级官方 Flathub"
grep -Fq 'remote-modify --user --url=https://dl.flathub.org/repo/ --gpg-verify --gpg-import=' \
    "$APP_STATE/commands" || fail "官方 Flathub 缺少公钥自动修复"

SOURCE_STATE="$TMP_ROOT/flatpak-source-mode"
: > "$APP_STATE/commands"
HOME="$HOME_DIR" PATH="$APP_BIN:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    ZHOUKEER_FLATPAK_SOURCE_MODE=managed \
    ZHOUKEER_FLATPAK_SOURCE_STATE_FILE="$SOURCE_STATE" \
    ZHOUKEER_AUTO_CONFIRM=1 \
    ZHOUKEER_DOMESTIC_SOURCE_CONFIRMED=1 \
    CHIMERA_APP_STATE="$APP_STATE" \
    bash "$PROJECT_ROOT/modules/software.sh" enable-domestic-remotes \
        > "$TMP_ROOT/domestic-source.out"
[ "$(cat "$SOURCE_STATE")" = domestic ] || \
    fail "ChimeraOS 未保存国内 Flatpak 下载线路"
grep -Fq 'remote-add --user --if-not-exists --no-gpg-verify flathub-cn https://mirror.sjtu.edu.cn/flathub' \
    "$APP_STATE/commands" || fail "ChimeraOS 未添加上海交大用户级缓存"

: > "$APP_STATE/commands"
: > "$APP_STATE/installed"
HOME="$CHIMERA_HOME" PATH="$APP_BIN:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    ZHOUKEER_FLATPAK_SOURCE_MODE=managed \
    ZHOUKEER_FLATPAK_SOURCE_STATE_FILE="$SOURCE_STATE" \
    ZHOUKEER_AUTO_CONFIRM=1 CHIMERA_APP_STATE="$APP_STATE" \
    bash "$PROJECT_ROOT/modules/software.sh" edge \
        > "$TMP_ROOT/domestic-edge.out"
grep -Fq 'install --user --noninteractive -y flathub-cn com.microsoft.Edge' \
    "$APP_STATE/commands" || fail "ChimeraOS 其他 Flathub 应用没有使用国内用户源"
if grep -Eq -- '--system|sudo' "$APP_STATE/commands"; then
    fail "ChimeraOS 国内源应用安装越界使用了系统级命令"
fi

: > "$APP_STATE/commands"
if HOME="$CHIMERA_HOME" PATH="$APP_BIN:/usr/bin:/bin" \
    CHIMERA_APP_STATE="$APP_STATE" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    ZHOUKEER_AUTO_CONFIRM=1 \
    bash "$PROJECT_ROOT/modules/software.sh" sunshine \
        > "$TMP_ROOT/sunshine-block.out" 2>&1; then
    fail "ChimeraOS 仍可绕过菜单执行 Sunshine 系统级配置"
fi
grep -Fq 'ChimeraOS 版不提供 Sunshine 安装' "$TMP_ROOT/sunshine-block.out" || \
    fail "ChimeraOS Sunshine 拦截缺少中文说明"
[ ! -s "$APP_STATE/commands" ] || \
    fail "ChimeraOS 拦截 Sunshine 后仍调用了 Flatpak 或系统配置"
if HOME="$CHIMERA_HOME" PATH="$APP_BIN:/usr/bin:/bin" \
    CHIMERA_APP_STATE="$APP_STATE" ZHOUKEER_OS_RELEASE_FILE="$CHIMERA_RELEASE" \
    ZHOUKEER_AUTO_CONFIRM=1 \
    bash "$PROJECT_ROOT/modules/software.sh" uninstall sunshine \
        > "$TMP_ROOT/sunshine-uninstall-block.out" 2>&1; then
    fail "ChimeraOS 仍可绕过菜单清理 Sunshine 系统级配置"
fi
grep -Fq 'ChimeraOS 版不管理 Sunshine' "$TMP_ROOT/sunshine-uninstall-block.out" || \
    fail "ChimeraOS Sunshine 卸载拦截缺少中文说明"

echo "PASS: ChimeraOS 独立分流、应用/插件范围与系统功能隔离测试通过"
