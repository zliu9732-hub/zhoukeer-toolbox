#!/bin/bash
set -euo pipefail
# Only local fixtures and mocked dialogs/services/downloads are used.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
source "$PROJECT_ROOT/core/lsfg_choice.sh"
unset ZHOUKEER_LSFG_VARIANT
DIALOG_RESULT=v2
kdialog() { printf '%s\n' "$@" > "$TMP_ROOT/dialog"; printf '%s\n' "$DIALOG_RESULT"; }
ZHOUKEER_AUTO_CONFIRM=1 select_lsfg_variant
[ "$LSFG_INSTALL_VARIANT" = v2 ] || fail '自动确认绕过了版本选择'
grep -Fxq '旧版小黄鸭' "$TMP_ROOT/dialog" || fail '缺少旧版选项'
grep -Fxq '小黄鸭2.0（需要正版小黄鸭本体并切换到 lsfg 分支）' "$TMP_ROOT/dialog" || fail '2.0 缺少本体和分支说明'
DIALOG_RESULT=legacy
select_lsfg_variant
[ "$LSFG_INSTALL_VARIANT" = legacy ] || fail '旧版选择未保存'
kdialog() { return 1; }
if select_lsfg_variant; then fail '取消窗口仍继续'; fi
[ -z "$LSFG_INSTALL_VARIANT" ] || fail '取消沿用了之前选择'
ZHOUKEER_LSFG_VARIANT=v2 select_lsfg_variant || fail '初始化传来的选项被再次询问'
if ZHOUKEER_LSFG_VARIANT='bad' select_lsfg_variant; then fail '无效环境选项被接受'; fi
unset -f kdialog
select_lsfg_variant <<< 2
[ "$LSFG_INSTALL_VARIANT" = v2 ] || fail '终端选项没有生效'
if select_lsfg_variant </dev/null; then fail '无窗口无输入仍默认安装'; fi

run_bundle() (
    local selected="$1" installed="$2"
    source "$PROJECT_ROOT/modules/plugin_store.sh"
    detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
    ensure_plugin_store_ready() { echo READY; }
    refresh_framegen_catalog() { return 0; }
    load_framegen_cached_versions() { return 0; }
    feature_plugin_is_current() {
        [ "$2" != "$LSFG_OFFICIAL_DIRECTORY" ] || [ "$installed" = legacy ]
    }
    lsfg_v2_is_current() { [ "$installed" = v2 ]; }
    lsfg_v2_is_selected() { [ "$installed" = v2 ]; }
    calculate_decky_sha256() { printf '%s\n' "$CSSLOADER_ZH_INDEX_SHA256"; }
    deckymusic_full_is_current() { return 0; }
    mako_official_is_current() { return 0; }
    install_lsfg_v2_from_gitee() { echo INSTALL_V2; }
    install_lsfg_zh_from_gitee() { echo INSTALL_LEGACY; }
    install_fsr4_zh_from_gitee() { return 0; }
    install_configured_plugin() { echo "INSTALL_OTHER:$1"; }
    refresh_feature_usage_guides() { return 0; }
    print_feature_plugin_status() { return 0; }
    reload_decky_plugins() { return 0; }
    feature_plugin_is_present() { return 1; }
    write_flingtrainer_desktop_note() { return 0; }
    print_cef_remote_debugging_tip() { return 0; }
    log() { return 0; }
    ZHOUKEER_LSFG_VARIANT="$selected" ZHOUKEER_FEATURE_PLUGIN_CLEANUP=keep install_feature_plugins
)
out="$(run_bundle v2 legacy)"
grep -Fxq INSTALL_V2 <<< "$out" || fail '选择 2.0 后仍装旧版'
! grep -Fxq INSTALL_LEGACY <<< "$out" || fail '两个版本同时安装'
[ "$(grep -c 'INSTALL_OTHER:lsfg-mako' <<< "$out")" -eq 1 ] || fail '组合内 MAKO 未恰好处理一次'
out="$(run_bundle legacy v2)"
grep -Fxq INSTALL_LEGACY <<< "$out" || fail '选择旧版后仍强行保留 2.0'
! grep -Fxq INSTALL_V2 <<< "$out" || fail '选择旧版仍安装 2.0'
out="$(run_bundle v2 v2)"
grep -Fxq INSTALL_V2 <<< "$out" || fail '已装当前 2.0 时跳过了清理重装'
if out="$(run_bundle invalid legacy)"; then fail '取消或无效选择仍继续'; fi
! grep -Fxq READY <<< "$out" || fail '选择失败仍改动插件商城'

source "$PROJECT_ROOT/modules/plugin_store.sh"
IS_STEAMOS=1
prepare_plugin_root() { PLUGIN_NEEDS_SUDO=0; }
log() { return 0; }
EVENTS="$TMP_ROOT/events"
SYSTEM_MODE=ok
toolbox_sudo() {
    [ "$1" = systemctl ] || fail '测试试图提权执行系统命令'
    printf '%s\n' "$2" >> "$EVENTS"
    case "$SYSTEM_MODE:$2" in stop-fail:stop) return 1 ;; start-fail:start) return 1 ;; esac
}
lsfg_v2_is_current() { [ "$(cat "$1/$LSFG_V2_DIRECTORY/version-marker")" = new ]; }
run_transaction() (
    local mode="$1"
    local root="$TMP_ROOT/$mode/plugins" source_dir="$TMP_ROOT/$mode/source"
    mkdir -p "$root/$LSFG_V2_DIRECTORY" "$root/小黄鸭2.0" "$root/Mako" "$root/LSFG-VK" "$root/.old-backup" "$root/renamed-copy" "$source_dir"
    printf old > "$root/$LSFG_V2_DIRECTORY/version-marker"
    printf '{"name":"小黄鸭2.0"}' > "$root/小黄鸭2.0/plugin.json"
    printf '{"name":"Unrelated"}' > "$root/LSFG-VK/plugin.json"
    printf '{"name":"Decky LSFG-VK"}' > "$root/.old-backup/plugin.json"
    printf '{"name":"小黄鸭2.0"}' > "$root/renamed-copy/plugin.json"
    printf keep > "$root/Mako/settings"
    printf new > "$source_dir/version-marker"
    SYSTEM_MODE="$mode"
    install_tree_atomically() {
        grep -q '^stop$' "$EVENTS" || fail '未停止商城就开始安装'
        [ ! -e "$root/$LSFG_V2_DIRECTORY" ] && [ ! -e "$root/小黄鸭2.0" ] || fail '安装前旧 1.0/2.0 没有清理干净'
        [ ! -e "$root/.old-backup" ] && [ ! -e "$root/renamed-copy" ] || fail '安装前残留副本没有清理'
        printf 'install\n' >> "$EVENTS"
        [ "$mode" != write-fail ] || return 1
        cp -R "$1" "$2/$3"
    }
    status=0
    install_lsfg_v2_clean "$source_dir" "$root" || status=$?
    [ -f "$root/Mako/settings" ] && [ -f "$root/LSFG-VK/plugin.json" ] || fail '清理改动 MAKO 或其他插件'
    if [ "$mode" = ok ]; then
        [ "$status" -eq 0 ] || fail '清理重装失败'
        [ ! -e "$root/小黄鸭2.0" ] || fail '重复 2.0 残留'
        [ "$(cat "$root/$LSFG_V2_DIRECTORY/version-marker")" = new ] || fail '新文件未安装'
    else
        [ "$status" -ne 0 ] || fail '失败仍报告成功'
        [ "$(cat "$root/$LSFG_V2_DIRECTORY/version-marker")" = old ] || fail '失败没有恢复原插件'
        [ -f "$root/小黄鸭2.0/plugin.json" ] || fail '失败丢失原目录'
        [ -f "$root/.old-backup/plugin.json" ] && [ -f "$root/renamed-copy/plugin.json" ] || fail '失败没有恢复旧副本'
    fi
)
for mode in ok write-fail stop-fail start-fail; do
    : > "$EVENTS"
    run_transaction "$mode"
    if [ "$mode" = stop-fail ]; then
        ! grep -q '^install$' "$EVENTS" || fail '停止服务失败仍清理'
    else
        [ "$(head -n 1 "$EVENTS")" = stop ] || fail '安装前没有停止商城'
        [ "$(tail -n 1 "$EVENTS")" = start ] || fail '未尝试恢复商城'
    fi
done
echo 'PASS: 小黄鸭选择、取消、2.0 清理重装与失败恢复、MAKO 保留模拟通过'
