#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

STEAMOS_RELEASE="$TMP_ROOT/steamos-release"
BAZZITE_RELEASE="$TMP_ROOT/bazzite-release"
FEDORA_RELEASE="$TMP_ROOT/fedora-release"
INJECTION_MARKER="$TMP_ROOT/os-release-was-executed"

cat > "$STEAMOS_RELEASE" <<'EOF'
ID=steamos
ID_LIKE="arch steamos"
PRETTY_NAME="SteamOS 3"
EOF

cat > "$BAZZITE_RELEASE" <<EOF
ID=bazzite
ID_LIKE=fedora
VARIANT_ID=bazzite-deck
PRETTY_NAME="Bazzite 42"
UNTRUSTED=\$(touch "$INJECTION_MARKER")
EOF

cat > "$FEDORA_RELEASE" <<'EOF'
ID=fedora
ID_LIKE=fedora
PRETTY_NAME="Fedora Linux"
EOF

platform_result="$({
    ZHOUKEER_OS_RELEASE_FILE="$STEAMOS_RELEASE"
    source "$PROJECT_ROOT/core/platform.sh"
    detect_platform
    printf '%s|%s|%s|%s\n' "$PLATFORM_FAMILY" "$IS_STEAMOS" "$IS_BAZZITE" "$PLATFORM_NAME"
})"
[ "$platform_result" = "steamos|1|0|SteamOS 3" ] || fail "SteamOS 平台识别错误：$platform_result"

platform_result="$({
    ZHOUKEER_OS_RELEASE_FILE="$BAZZITE_RELEASE"
    source "$PROJECT_ROOT/core/platform.sh"
    detect_platform
    require_supported_gaming_os
    printf '%s|%s|%s|%s\n' "$PLATFORM_FAMILY" "$IS_STEAMOS" "$IS_BAZZITE" "$PLATFORM_NAME"
})"
[ "$platform_result" = "bazzite|0|1|Bazzite 42" ] || fail "Bazzite 平台识别错误：$platform_result"
[ ! -e "$INJECTION_MARKER" ] || fail "os-release 内容被当成 Shell 执行"

platform_result="$({
    ZHOUKEER_OS_RELEASE_FILE="$FEDORA_RELEASE"
    source "$PROJECT_ROOT/core/platform.sh"
    detect_platform
    printf '%s|%s|%s\n' "$PLATFORM_FAMILY" "$IS_STEAMOS" "$IS_BAZZITE"
})"
[ "$platform_result" = "unknown|0|0" ] || fail "普通 Fedora 被核心平台层误标记：$platform_result"

# 启动器按 LGC 的方式分流：SteamOS 使用原主程序，其余 Linux 使用独立 Bazzite 主程序。
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
cat > "$BIN_DIR/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
chmod +x "$LAUNCH_APP"/*.sh "$BIN_DIR/uname"

launch_output="$(HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$STEAMOS_RELEASE" ZHOUKEER_SKIP_STARTUP_UPDATE=1 \
    ZHOUKEER_LAUNCH_LOG="$TMP_ROOT/steam-launch.log" \
    bash "$LAUNCH_APP/launch.sh" --run-main)"
printf '%s\n' "$launch_output" | grep -Fq STEAMOS_MAIN || fail "SteamOS 没有进入原主程序"

launch_output="$(HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$BAZZITE_RELEASE" ZHOUKEER_SKIP_STARTUP_UPDATE=1 \
    ZHOUKEER_LAUNCH_LOG="$TMP_ROOT/bazzite-launch.log" \
    bash "$LAUNCH_APP/launch.sh" --run-main)"
printf '%s\n' "$launch_output" | grep -Fq BAZZITE_MAIN || fail "Bazzite 没有进入独立主程序"

launch_output="$(HOME="$HOME_DIR" PATH="$BIN_DIR:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$FEDORA_RELEASE" ZHOUKEER_SKIP_STARTUP_UPDATE=1 \
    ZHOUKEER_LAUNCH_LOG="$TMP_ROOT/fedora-launch.log" \
    bash "$LAUNCH_APP/launch.sh" --run-main)"
printf '%s\n' "$launch_output" | grep -Fq BAZZITE_MAIN || fail "非 SteamOS Linux 没有按约定进入 Bazzite 版"

# Bazzite Decky 只能走官方 ujust，不能回落到 SteamOS/pacman 安装路径。
DECKY_BIN="$TMP_ROOT/decky-bin"
DECKY_HOME="$TMP_ROOT/decky-home"
UJUST_LOG="$TMP_ROOT/ujust.log"
mkdir -p "$DECKY_BIN" "$DECKY_HOME"
cat > "$DECKY_BIN/ujust" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$UJUST_LOG"
mkdir -p "$HOME/homebrew/services"
printf '#!/bin/bash\n' > "$HOME/homebrew/services/PluginLoader"
chmod +x "$HOME/homebrew/services/PluginLoader"
EOF
chmod +x "$DECKY_BIN/ujust"

HOME="$DECKY_HOME" PATH="$DECKY_BIN:/usr/bin:/bin" UJUST_LOG="$UJUST_LOG" \
ZHOUKEER_OS_RELEASE_FILE="$BAZZITE_RELEASE" \
    bash "$PROJECT_ROOT/modules/bazzite_decky.sh" install > "$TMP_ROOT/decky.out"
[ "$(cat "$UJUST_LOG")" = "setup-decky" ] || fail "Decky 未调用 ujust setup-decky"
grep -Fq 'Decky Loader 安装完成' "$TMP_ROOT/decky.out" || fail "Decky 安装未报告成功"

# Bazzite 已安装官方 Decky 后，汉化功能插件必须通过平台门禁；测试仅在临时
# HOME 中放置完整文件桩，不下载、不提权，也不接触真实 Decky 服务。
BAZZITE_PLUGIN_ROOT="$DECKY_HOME/homebrew/plugins"
for plugin_dir in "Decky LSFG-VK" Decky-Framegen CheatDeck decky-steamgriddb SDH-CssLoader Friendeck-plugin "Decky Music"; do
    mkdir -p "$BAZZITE_PLUGIN_ROOT/$plugin_dir/dist"
    printf 'test bundle\n' > "$BAZZITE_PLUGIN_ROOT/$plugin_dir/dist/index.js"
done
grep -Fq 'OneXPlayer Apex 工具仅支持 Bazzite' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    fail "OneXPlayer Apex 插件缺少 Bazzite 平台隔离"
printf '{"name":"Decky LSFG-VK"}\n' > "$BAZZITE_PLUGIN_ROOT/Decky LSFG-VK/plugin.json"
printf '{"version":"0.12.5"}\n' > "$BAZZITE_PLUGIN_ROOT/Decky LSFG-VK/package.json"
printf '{"name":"Decky-Framegen"}\n' > "$BAZZITE_PLUGIN_ROOT/Decky-Framegen/plugin.json"
printf '{"version":"0.17.0"}\n' > "$BAZZITE_PLUGIN_ROOT/Decky-Framegen/package.json"
printf '{"name":"CheatDeck"}\n' > "$BAZZITE_PLUGIN_ROOT/CheatDeck/plugin.json"
printf '{"version":"2.0.0"}\n' > "$BAZZITE_PLUGIN_ROOT/CheatDeck/package.json"
printf '{"name":"SteamGridDB"}\n' > "$BAZZITE_PLUGIN_ROOT/decky-steamgriddb/plugin.json"
printf '{"version":"1.7.1"}\n' > "$BAZZITE_PLUGIN_ROOT/decky-steamgriddb/package.json"
printf '{"name":"主题美化"}\n' > "$BAZZITE_PLUGIN_ROOT/SDH-CssLoader/plugin.json"
printf '{"version":"2.1.2"}\n' > "$BAZZITE_PLUGIN_ROOT/SDH-CssLoader/package.json"
cp "$PROJECT_ROOT/third_party/cssloader-zh-v2.1.2/dist/index.js" \
    "$BAZZITE_PLUGIN_ROOT/SDH-CssLoader/dist/index.js"
printf '{"name":"Friendeck"}\n' > "$BAZZITE_PLUGIN_ROOT/Friendeck-plugin/plugin.json"
printf '{"version":"0.7.5"}\n' > "$BAZZITE_PLUGIN_ROOT/Friendeck-plugin/package.json"
printf '{"name":"Decky Music"}\n' > "$BAZZITE_PLUGIN_ROOT/Decky Music/plugin.json"
printf '{"version":"1.0.0"}\n' > "$BAZZITE_PLUGIN_ROOT/Decky Music/package.json"
HOME="$DECKY_HOME" PATH="$DECKY_BIN:/usr/bin:/bin" \
DECKY_PLUGIN_DIR="$BAZZITE_PLUGIN_ROOT" ZHOUKEER_TEST_MODE=1 \
ZHOUKEER_OS_RELEASE_FILE="$BAZZITE_RELEASE" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" features > "$TMP_ROOT/bazzite-features.out"
grep -Fq '七款常用功能插件已全部安装' "$TMP_ROOT/bazzite-features.out" || \
    fail "Bazzite 汉化功能插件仍被 SteamOS 平台门禁拦截"

if rg -n 'modules/(todesk|memory_tuning|dual_system)' "$PROJECT_ROOT/main-bazzite.sh"; then
    fail "Bazzite 菜单暴露了未适配的系统模块"
fi
grep -Fq 'modules/clover_boot.sh" install' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite Clover 安装入口缺失"
grep -Fq 'modules/clover_boot.sh" status' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite Clover 状态入口缺失"
grep -Fq 'modules/clover_boot.sh" restore' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite Clover 恢复入口缺失"
grep -Fq 'modules/domestic_source.sh" enable' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 国内 Flatpak 源入口缺失"
grep -Fq 'modules/domestic_source.sh" restore' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 官方 Flatpak 源恢复入口缺失"
grep -Fq 'localsend) title="LocalSend"' "$PROJECT_ROOT/main-bazzite.sh" || fail "LocalSend 菜单动作缺失"
grep -Fq 'modules/ge_proton.sh" install-trainer' "$PROJECT_ROOT/main-bazzite.sh" || fail "修改器常用 GE-Proton 入口缺失"
grep -Fq 'modules/emulators.sh" yuzu-keys' "$PROJECT_ROOT/main-bazzite.sh" || fail "Yuzu 自备密钥导入入口缺失"
grep -Fq 'modules/emulators.sh" yuzu-keys-status' "$PROJECT_ROOT/main-bazzite.sh" || fail "Yuzu 密钥状态入口缺失"
grep -Fq 'modules/emulators.sh" install-all' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 一键安装模拟器入口缺失"
grep -Fq 'modules/decky_bundle.sh" plugin' "$PROJECT_ROOT/main-bazzite.sh" || fail "Decky 官方插件逐个安装入口缺失"
grep -Fq 'DECKY_BUNDLE_INCLUDE_CUSTOM=0' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite Decky 推荐安装未禁用自定义插件"
grep -Fq 'modules/plugin_store.sh" features' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 汉化功能插件组合入口缺失"
grep -Fq 'modules/plugin_store.sh" lsfg-zh-gitee' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 小黄鸭入口缺失"
grep -Fq 'modules/plugin_store.sh" lsfg-mako' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite MAKO 小黄鸭入口缺失"
grep -Fq 'bazzite_lsfg_versions_menu' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 小黄鸭版本子菜单缺失"
grep -Fq 'modules/plugin_store.sh" fsr4-zh-gitee' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite FSR4 入口缺失"
for plugin_action in cheatdeck deckrecall savepulse freedeck newfreedeck tomoon unifideck \
    simpledeckytdp-zh-gitee allycenter huesync legiongo-remapper gpd-control lego-vibe lego2-fan \
    onexplayer-apex; do
    grep -Fq "modules/plugin_store.sh\" $plugin_action" "$PROJECT_ROOT/main-bazzite.sh" || \
        fail "Bazzite 插件入口缺失：$plugin_action"
done
grep -Fq 'modules/plugin_store.sh" feature-status' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 插件真实状态入口缺失"
grep -Fq 'modules/game_guides.sh" show' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 中文兼容攻略入口缺失"
grep -Fq 'modules/handheld_helper.sh" peripherals' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 外接设备检查入口缺失"
grep -Fq 'modules/safety_center.sh" records' "$PROJECT_ROOT/main-bazzite.sh" || fail "Bazzite 操作记录导出入口缺失"
if grep -Eq 'modules/plugin_store.sh" (store|store-test|store-auto|store-uninstall)' "$PROJECT_ROOT/main-bazzite.sh"; then
    fail "Bazzite 菜单误接入 SteamOS Decky Loader 管理动作"
fi
grep -Fq 'main-bazzite.sh' "$PROJECT_ROOT/scripts/package_release.sh" || fail "发布包未校验 Bazzite 主程序"
grep -Fq 'modules/bazzite_decky.sh' "$PROJECT_ROOT/scripts/package_release.sh" || fail "发布包未校验 Bazzite Decky 模块"

echo "PASS: SteamOS/Bazzite 独立分流、平台解析与官方 Decky 安装测试通过"
