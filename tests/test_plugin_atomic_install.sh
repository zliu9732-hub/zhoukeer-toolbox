#!/bin/bash
# Real copies/moves in private directories. Ownership failures and sudo are mocked.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_ROOT="$(cd -P -- "$TEST_ROOT" && pwd)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_APP_DIR="$TEST_ROOT/apps" DECKY_PLUGIN_DIR="$TEST_ROOT/homebrew/plugins"
source "$ROOT/modules/plugin_store.sh"
LOG_FILE="$TEST_ROOT/test.log"
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
IS_STEAMOS=1 IS_CHIMERAOS=0 PLUGIN_NEEDS_SUDO=0
MODE=normal CLEANUP_DENIED=0 ADMIN_DENIED=0
mkdir -p "$DECKY_PLUGIN_DIR" "$TEST_ROOT/source"
printf new > "$TEST_ROOT/source/payload"
toolbox_sudo() {
    [ "$1:$2:$3" = 'rm:-rf:--' ] || fail 'Unexpected privileged operation'
    case "$4" in "$TEST_ROOT/homebrew"/.renkit-plugin-install.*) ;; *) fail 'Privileged cleanup escaped scope';; esac
    echo cleanup >> "$TEST_ROOT/authorization"
    [ "$ADMIN_DENIED" = 0 ] || return 1
    "$@"
}
run_plugin_file_operation() {
    local last="${!#}"
    case "$1" in
        cp)
            case "$last" in "$DECKY_PLUGIN_DIR"/*) fail 'Staged plugin exposed to live loader';; esac
            [ "$MODE" != copy-fail ] || return 17 ;;
        mv)
            if [[ "$3" = */new ]] && [ "$MODE" != normal ]; then return 18; fi
            if [[ "$3" = */previous ]] && [ "$MODE" = restore-fail ]; then return 19; fi ;;
        rm)
            if [ "$CLEANUP_DENIED" = 1 ] && [ -d "$last/previous" ]; then
                echo 'Permission denied on old root-owned plugin' >&2
                return 1
            fi ;;
        mktemp) ;;
        *) fail 'Unexpected file operation' ;;
    esac
    "$@"
}
verify_payload() { [ "$(cat "$1/payload")" = new ]; }
reset_case() {
    MODE=normal CLEANUP_DENIED=0 ADMIN_DENIED=0
    rm -rf -- "$TEST_ROOT/homebrew"
    mkdir -p "$DECKY_PLUGIN_DIR/Sample"
    echo old > "$DECKY_PLUGIN_DIR/Sample/payload"
    : > "$TEST_ROOT/authorization"
}
reset_case
install_tree_atomically "$TEST_ROOT/source" "$DECKY_PLUGIN_DIR/" Sample verify_payload
[ "$(cat "$DECKY_PLUGIN_DIR/Sample/payload")" = new ] || fail 'New tree missing'
[ "$(find "$TEST_ROOT/homebrew" -name '.renkit-plugin-install.*' | wc -l)" -eq 0 ] || fail 'Workspace leaked'
ln -s "$DECKY_PLUGIN_DIR" "$TEST_ROOT/plugin-alias"
install_tree_atomically "$TEST_ROOT/source" "$TEST_ROOT/plugin-alias" Sample verify_payload || fail 'Existing plugin-root alias no longer supported'
for MODE in copy-fail promote-fail restore-fail; do
    failure_mode="$MODE"; reset_case; MODE="$failure_mode"
    if install_tree_atomically "$TEST_ROOT/source" "$DECKY_PLUGIN_DIR" Sample verify_payload > "$TEST_ROOT/failure" 2>&1; then fail 'Write failure masked'; fi
    if [ "$MODE" = restore-fail ]; then
        find "$TEST_ROOT/homebrew" -path '*/previous/payload' | grep -q . || fail 'Recovery backup deleted'
        grep -Fq '备份保留在' "$TEST_ROOT/failure" || fail 'Recovery path hidden'
    else
        [ "$(cat "$DECKY_PLUGIN_DIR/Sample/payload")" = old ] || fail 'Original tree lost'
    fi
done
reset_case
reject_payload() { echo 'simulated staging integrity failure'; return 1; }
if install_tree_atomically "$TEST_ROOT/source" "$DECKY_PLUGIN_DIR" Sample reject_payload > "$TEST_ROOT/integrity"; then fail 'Invalid staging accepted'; fi
[ "$(cat "$DECKY_PLUGIN_DIR/Sample/payload")" = old ] || fail 'Invalid staging replaced old plugin'
for ADMIN_DENIED in 0 1; do
    denied="$ADMIN_DENIED"; reset_case; CLEANUP_DENIED=1 ADMIN_DENIED="$denied"
    install_tree_atomically "$TEST_ROOT/source" "$DECKY_PLUGIN_DIR" Sample verify_payload > "$TEST_ROOT/cleanup" || fail 'Complete install reported failure because cleanup failed'
    [ "$(cat "$DECKY_PLUGIN_DIR/Sample/payload")" = new ] || fail 'New files damaged by cleanup'
    [ "$(wc -l < "$TEST_ROOT/authorization")" -eq 1 ] || fail 'Existing sudo adapter was bypassed'
    if [ "$denied" = 1 ]; then
        grep -Fq '新文件已安装' "$TEST_ROOT/cleanup" || fail 'Retained-copy warning misleading'
        find "$TEST_ROOT/homebrew" -path '*/previous/payload' | grep -q . || fail 'Old copy not retained'
        [ "$(find "$DECKY_PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ] || fail 'Backup exposed as duplicate plugin'
    fi
done
reset_case
# Only generated, matching redundant copies may move; retain their contents.
kill() { [ "$*" = '-0 123' ]; } # Read-only active-PID simulation.
for name in CheatDeck .CheatDeck.backup.42 .CheatDeck.new.43 .CheatDeck.backup.44 .CheatDeck.new.123 Unknown .Unknown.backup.42 .DeckyGCM.backup.42; do
    mkdir -p "$DECKY_PLUGIN_DIR/$name/dist"
    printf '{"name":"CheatDeck"}\n' > "$DECKY_PLUGIN_DIR/$name/plugin.json"
    echo bundle > "$DECKY_PLUGIN_DIR/$name/dist/index.js"
done
printf '{"name":"Unrelated"}\n' > "$DECKY_PLUGIN_DIR/.CheatDeck.backup.44/plugin.json"
isolate_legacy_plugin_install_copies > "$TEST_ROOT/isolation"
[ "$LEGACY_PLUGIN_COPIES_MOVED" = 1 ] || fail 'Legacy copies not recognized'
[ ! -e "$DECKY_PLUGIN_DIR/.CheatDeck.backup.42" ] && [ ! -e "$DECKY_PLUGIN_DIR/.CheatDeck.new.43" ] || fail 'Legacy duplicates still visible'
for name in CheatDeck .CheatDeck.backup.44 .CheatDeck.new.123 Unknown .Unknown.backup.42 .DeckyGCM.backup.42; do
    [ -d "$DECKY_PLUGIN_DIR/$name" ] || fail 'Unrelated/only-copy data moved'
done
[ "$(find "$TEST_ROOT/homebrew" -path '*/.CheatDeck.backup.42/plugin.json' | wc -l)" -eq 1 ] || fail 'Old copy deleted instead of retained'
echo 'PASS: actual atomic copies, off-scan staging/backup, staging rejection, write/rename/rollback failures, root-owned cleanup recovery, retained-copy warning and safe legacy isolation'
