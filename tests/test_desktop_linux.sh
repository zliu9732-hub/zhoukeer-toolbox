#!/bin/bash
# All platform/service/network/installation commands are mocked in a private HOME.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export HOME="$TMP/home" ZHOUKEER_APP_DIR="$TMP/apps" ZHOUKEER_OS_RELEASE_FILE="$TMP/os-release"
mkdir -p "$HOME" "$TMP/bin"
source "$ROOT/core/platform.sh"
MOCK_SYSTEM=Linux
uname() { case "$1" in -s) echo "$MOCK_SYSTEM";; -m) echo x86_64;; esac; }
for item in anatase:anatase fedora:unknown bazzite:bazzite steamos:steamos chimeraos:chimeraos; do
    id="${item%:*}" expected="${item#*:}"
    printf 'ID=%s\nPRETTY_NAME="Platform test"\n' "$id" > "$ZHOUKEER_OS_RELEASE_FILE"
    detect_platform
    [ "$PLATFORM_FAMILY" = "$expected" ] || fail "Wrong classification: $id"
    case "$id" in
        anatase|fedora)
            [ "$IS_BAZZITE" = 0 ] && [ "$IS_STEAMOS" = 0 ] && [ "$IS_DESKTOP_LINUX" = 1 ] || fail 'Faked Bazzite/SteamOS identity'
            require_supported_gaming_os || fail 'Common Linux apps rejected'
            if require_steamos >/dev/null || require_bazzite >/dev/null || require_steamos_or_bazzite >/dev/null; then fail 'Distro-specific guard removed'; fi
            ;;
        bazzite) require_supported_gaming_os; require_bazzite; require_steamos_or_bazzite ;;
        steamos) require_supported_gaming_os; require_steamos; require_steamos_or_bazzite
            if require_desktop_linux >/dev/null; then fail 'SteamOS sent to desktop-only path'; fi ;;
        chimeraos) if require_supported_gaming_os >/dev/null; then fail 'ChimeraOS isolation removed'; fi ;;
    esac
done
printf 'ID=anatase\nPRETTY_NAME="Anatase"\n' > "$ZHOUKEER_OS_RELEASE_FILE"
MOCK_SYSTEM=Darwin
if require_supported_gaming_os >/dev/null; then fail 'macOS accepted as Linux'; fi
MOCK_SYSTEM=Linux
# Parsing is data-only, never source os-release.
printf 'ID=anatase\nPRETTY_NAME="$(touch %s)"\n' "$TMP/injected" > "$ZHOUKEER_OS_RELEASE_FILE"
detect_platform
[ ! -e "$TMP/injected" ] || fail 'Executed OS metadata'
printf 'ID=anatase\nPRETTY_NAME="Anatase"\n' > "$ZHOUKEER_OS_RELEASE_FILE"
cat > "$TMP/bin/uname" <<'EOF'
#!/bin/sh
case "$1" in -s) echo Linux;; -m) echo x86_64;; esac
EOF
cat > "$TMP/bin/ujust" <<'EOF'
#!/bin/sh
if [ "$1" = --list ]; then
    [ "$RECIPE_MODE" != failed ] || { echo '    setup-decky'; exit 1; }
    if [ "$RECIPE_MODE" = available ]; then echo '    setup-decky # install Decky'; else echo '    unrelated-recipe'; fi
    exit 0
fi
[ "$*" = setup-decky ] || exit 98
echo setup-decky >> "$CALLS"
mkdir -p "$HOME/homebrew/services"
echo fixture > "$HOME/homebrew/services/PluginLoader"
chmod +x "$HOME/homebrew/services/PluginLoader"
EOF
for command in sudo curl wget pacman systemctl rpm-ostree bootc steamos-readonly; do
    printf '#!/bin/sh\necho "Forbidden real command: %s" >&2\nexit 97\n' "$command" > "$TMP/bin/$command"
done
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" CALLS="$TMP/calls" RECIPE_MODE=missing
for RECIPE_MODE in missing failed; do
    export RECIPE_MODE
    if bash "$ROOT/modules/bazzite_decky.sh" install > "$TMP/decky-error"; then fail 'Missing/failed system recipe accepted'; fi
    [ ! -f "$CALLS" ] || fail 'Ran unavailable recipe'
    ! grep -Fq '仅支持 Bazzite' "$TMP/decky-error" || fail 'Anatase blocked by name'
done
export RECIPE_MODE=available
bash "$ROOT/modules/bazzite_decky.sh" install > "$TMP/decky-install" || fail 'Available system recipe rejected'
[ "$(cat "$CALLS")" = setup-decky ] || fail 'Wrong install recipe'
export RECIPE_MODE=missing
bash "$ROOT/modules/bazzite_decky.sh" install > "$TMP/decky-repeat" || fail 'Existing Decky needs no system recipe'
[ "$(wc -l < "$CALLS" | tr -d ' ')" = 1 ] || fail 'Repeated installed Decky'
# Real launcher selects the existing desktop entry for Anatase.
mkdir -p "$TMP/app/core"
cp "$ROOT/launch.sh" "$TMP/app/launch.sh"
cp "$ROOT/core/platform.sh" "$TMP/app/core/platform.sh"
printf '#!/bin/bash\necho DESKTOP_MAIN\n' > "$TMP/app/main-bazzite.sh"
printf '#!/bin/bash\necho WRONG_STEAMOS_MAIN\n' > "$TMP/app/main.sh"
ZHOUKEER_AUTO_UPDATE=0 ZHOUKEER_SKIP_STARTUP_UPDATE=1 ZHOUKEER_LAUNCH_LOG="$TMP/launch.log" \
    bash "$TMP/app/launch.sh" --run-main > "$TMP/launch-output"
grep -Fq DESKTOP_MAIN "$TMP/launch-output" || fail 'Anatase desktop routing failed'
! grep -Fq WRONG_STEAMOS_MAIN "$TMP/launch-output" || fail 'Anatase routed to SteamOS'
# Real plugin entry passes the common gate; only the install operation is replaced.
source "$ROOT/modules/plugin_store.sh"
install_plugin_store() { fail 'Entered SteamOS Loader installer'; }
ensure_plugin_store_ready > "$TMP/ready" || fail 'Existing Anatase Decky rejected'
ensure_allycenter_chinese_current() { echo localized-plugin > "$TMP/plugin-called"; PLUGIN_INSTALL_CHANGED=0; }
install_configured_plugin allycenter > "$TMP/plugin-output" || fail 'Common plugin action rejected Anatase'
[ -f "$TMP/plugin-called" ] || fail 'Plugin action was not reached'
# System/boot operations retain their original scope after the common gate widens.
if require_steamos_or_bazzite > /dev/null; then fail 'Anatase permitted boot writes'; fi
! grep -Fq 'require_supported_gaming_os || return 1' "$ROOT/modules/clover_boot.sh" || fail 'Clover inherited the broad common gate'
source "$ROOT/modules/preflight.sh"
preflight_available_kib() { echo 99999999; }
preflight_network_ok() { return 0; }
preflight_readonly_status() { return 2; }
preflight_power_ok() { return 0; }
run_preflight decky > "$TMP/preflight" || fail 'Read-only plugin preflight rejected Anatase'
if run_preflight memory > "$TMP/preflight-system"; then fail 'System preflight inherited broad desktop gate'; fi
echo 'PASS: Anatase/Fedora common Linux routing and plugin entry; exact OS flags, data-only metadata, actual launcher, system recipe capability checks, idempotency and strict OS/boot guards'
