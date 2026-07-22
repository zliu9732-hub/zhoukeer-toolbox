#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

HOME_DIR="$TMP_ROOT/home"
PLUGIN_ROOT="$HOME_DIR/homebrew/plugins"
UNIT_PATH="$TMP_ROOT/plugin_loader.service"
mkdir -p "$HOME_DIR/homebrew/services" "$PLUGIN_ROOT/CheatDeck/dist"
printf '#!/bin/sh\n' > "$HOME_DIR/homebrew/services/PluginLoader"
chmod +x "$HOME_DIR/homebrew/services/PluginLoader"
printf '[Service]\n' > "$UNIT_PATH"
printf '{"name":"CheatDeck"}\n' > "$PLUGIN_ROOT/CheatDeck/plugin.json"
printf 'bundle\n' > "$PLUGIN_ROOT/CheatDeck/dist/index.js"

store_output="$(
    HOME="$HOME_DIR" \
    ZHOUKEER_DECKY_HOMEBREW_DIR="$HOME_DIR/homebrew" \
    ZHOUKEER_DECKY_UNIT_PATH="$UNIT_PATH" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    bash -c '
        source "$PROJECT_ROOT/modules/plugin_store.sh"
        detect_platform() { IS_STEAMOS=1; }
        id() { [ "${1:-}" = "-u" ] && printf "1000\n"; }
        require_command() { echo "不应检查下载依赖：$1" >&2; return 1; }
        install_plugin_store
    '
)" || fail "已安装 Decky Loader 仍进入安装流程"
printf '%s\n' "$store_output" | grep -Fq '[已安装]' || \
    fail "Decky Loader 未报告已安装"

plugin_output="$(
    HOME="$HOME_DIR" \
    DECKY_PLUGIN_DIR="$PLUGIN_ROOT" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    bash -c '
        source "$PROJECT_ROOT/modules/plugin_store.sh"
        require_command() { echo "不应检查下载依赖：$1" >&2; return 1; }
        install_decky_zip "CheatDeck" "https://example.invalid/plugin.zip" \
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
            "CheatDeck"
    '
)" || fail "已安装 Decky 插件仍进入下载流程"
printf '%s\n' "$plugin_output" | grep -Fq '[已安装]' || \
    fail "Decky 插件未报告已安装"

BIN_DIR="$TMP_ROOT/bin"
TODESK_LOG="$TMP_ROOT/todesk.log"
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/pacman" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$*" >> "${TODESK_TEST_LOG:?}"
[ "${1:-}" = "-Q" ] && [ "${2:-}" = "todesk-bin" ]
SCRIPT
chmod +x "$BIN_DIR/pacman"

todesk_output="$(
    PATH="$BIN_DIR:/usr/bin:/bin" \
    TODESK_TEST_LOG="$TODESK_LOG" \
    PROJECT_ROOT="$PROJECT_ROOT" \
    bash -c '
        source "$PROJECT_ROOT/modules/todesk.sh"
        detect_platform() { IS_STEAMOS=1; }
        require_command() { echo "不应检查安装依赖：$1" >&2; return 1; }
        install_todesk
    '
)" || fail "已安装 ToDesk 仍进入安装流程"
printf '%s\n' "$todesk_output" | grep -Fq '[已安装]' || \
    fail "ToDesk 未报告已安装"
[ "$(cat "$TODESK_LOG")" = "-Q todesk-bin" ] || \
    fail "ToDesk 已安装检测后仍执行了其他 pacman 操作"

echo "PASS: Decky Loader、独立插件和 ToDesk 已安装检测不会重复安装"
