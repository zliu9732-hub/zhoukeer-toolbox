#!/bin/bash
set -euo pipefail
# Local fixtures and mocked dialogs/services only; no network or real elevation.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
source "$PROJECT_ROOT/core/plugin_cleanup_choice.sh"
unset ZHOUKEER_FEATURE_PLUGIN_CLEANUP
kdialog() { printf '%s\n' "$@" > "$TMP_ROOT/dialog"; printf '%s\n' "$DIALOG_RESULT"; }
DIALOG_RESULT=keep
ZHOUKEER_AUTO_CONFIRM=1 select_feature_plugin_cleanup
[ "$FEATURE_PLUGIN_CLEANUP" = keep ] || fail '自动确认跳过了已有插件选择'
grep -Fxq '不卸载已有插件' "$TMP_ROOT/dialog" || fail '缺少保留选项'
grep -Fxq '卸载已有插件（可能解决有时候报错的问题）' "$TMP_ROOT/dialog" || fail '缺少卸载选项'
grep -Fq '全部已有插件及其目录内的设置' "$TMP_ROOT/dialog" || fail '没有说明卸载范围'
grep -Fxq -- --default "$TMP_ROOT/dialog" || fail '没有设置安全默认选项'
DIALOG_RESULT=remove
select_feature_plugin_cleanup
[ "$FEATURE_PLUGIN_CLEANUP" = remove ] || fail '卸载选择未保存'
kdialog() { return 1; }
if select_feature_plugin_cleanup; then fail '取消仍继续'; fi
[ -z "$FEATURE_PLUGIN_CLEANUP" ] || fail '取消沿用旧选择'
ZHOUKEER_FEATURE_PLUGIN_CLEANUP=keep select_feature_plugin_cleanup || fail '初始化保留选项又被询问'
ZHOUKEER_FEATURE_PLUGIN_CLEANUP=remove select_feature_plugin_cleanup || fail '初始化卸载选项又被询问'
if ZHOUKEER_FEATURE_PLUGIN_CLEANUP=invalid select_feature_plugin_cleanup; then fail '接受无效选项'; fi
unset -f kdialog
select_feature_plugin_cleanup <<< ''
[ "$FEATURE_PLUGIN_CLEANUP" = keep ] || fail '回车没有默认保留'
select_feature_plugin_cleanup <<< 2
[ "$FEATURE_PLUGIN_CLEANUP" = remove ] || fail '终端卸载选择未生效'
if select_feature_plugin_cleanup </dev/null; then fail '无输入仍继续安装'; fi

source "$PROJECT_ROOT/modules/plugin_store.sh"
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
log() { return 0; }
ensure_plugin_store_ready() { echo READY; }
install_feature_plugins_selected() { echo "INSTALL:$1"; }
install_feature_plugins_clean() { echo "CLEAN:$1"; }
keep_output="$(ZHOUKEER_LSFG_VARIANT=legacy ZHOUKEER_FEATURE_PLUGIN_CLEANUP=keep install_feature_plugins)"
grep -Fxq INSTALL:legacy <<< "$keep_output" || fail '保留选择没有进入常用插件安装'
! grep -Fq CLEAN: <<< "$keep_output" || fail '选择保留仍卸载插件'
remove_output="$(ZHOUKEER_LSFG_VARIANT=v2 ZHOUKEER_FEATURE_PLUGIN_CLEANUP=remove install_feature_plugins)"
grep -Fxq CLEAN:v2 <<< "$remove_output" || fail '卸载选择没有进入清理重装'
if cancel_output="$(ZHOUKEER_LSFG_VARIANT=v2 ZHOUKEER_FEATURE_PLUGIN_CLEANUP=invalid install_feature_plugins)"; then
    fail '取消或错误选择仍开始安装'
fi
! grep -Fxq READY <<< "$cancel_output" || fail '取消后仍改动商城'

source "$PROJECT_ROOT/modules/feature_plugins_cleanup.sh"
IS_STEAMOS=1
prepare_plugin_root() { PLUGIN_NEEDS_SUDO=0; }
run_cleanup() (
    local mode="$1" root="$TMP_ROOT/$1/plugins" events="$TMP_ROOT/$1/events"
    local DECKY_PLUGIN_DIR="$root" status=0 stop_count=0 start_count=0 move_count=0
    mkdir -p "$root/顾客自带插件" "$root/.hidden-old" "$TMP_ROOT/$mode/outside"
    printf old > "$root/顾客自带插件/settings"
    printf hidden > "$root/.hidden-old/marker"
    printf safe > "$TMP_ROOT/$mode/outside/marker"
    ln -s "$TMP_ROOT/$mode/outside" "$root/linked-plugin"
    : > "$events"
    toolbox_sudo() {
        [ "$1" = systemctl ] || fail '试图执行真实提权命令'
        printf '%s\n' "$2" >> "$events"
        case "$2" in
            stop)
                stop_count=$((stop_count + 1))
                [ "$mode:$stop_count" != stop-fail:1 ] && [ "$mode:$stop_count" != rollback-stop-fail:2 ] ;;
            start)
                start_count=$((start_count + 1))
                [ "$mode:$start_count" != start-fail:1 ] && [ "$mode:$start_count" != final-start-fail:2 ] ;;
            *) fail '未模拟的服务操作' ;;
        esac
    }
    run_plugin_file_operation() {
        if [ "$1" = mv ]; then
            move_count=$((move_count + 1))
            [ "$mode:$move_count" != move-fail:2 ] || return 1
        fi
        "$@"
    }
    install_feature_plugins_selected() {
        [ "$1" = v2 ] || fail '丢失小黄鸭版本'
        [ -z "$(find "$root" -mindepth 1 -maxdepth 1 -print -quit)" ] || fail '原插件未全部移出'
        [ "$(tail -n 1 "$events")" = start ] || fail '未恢复商城就安装'
        printf 'install\n' >> "$events"
        mkdir -p "$root/new-plugin"
        printf new > "$root/new-plugin/marker"
        case "$mode" in write-fail|rollback-stop-fail) return 1 ;; esac
    }
    install_feature_plugins_clean v2 || status=$?
    [ "$(cat "$TMP_ROOT/$mode/outside/marker")" = safe ] || fail '误改插件目录外的文件'
    if [ "$mode" = ok ]; then
        [ "$status" -eq 0 ] || fail '清理重装失败'
        [ -f "$root/new-plugin/marker" ] || fail '没有新插件'
        [ ! -e "$root/顾客自带插件" ] && [ ! -e "$root/.hidden-old" ] && [ ! -L "$root/linked-plugin" ] || fail '残留原插件'
    else
        [ "$status" -ne 0 ] || fail '失败仍报告成功'
        if [ "$mode" = rollback-stop-fail ]; then
            [ -f "$root/new-plugin/marker" ] || fail '运行中的插件被替换'
            [ -n "$(find "$TMP_ROOT/$mode" -maxdepth 1 -name '.renkit-plugin-backup.*' -print -quit)" ] || fail '停止失败丢弃备份'
            return 0
        fi
        [ "$(cat "$root/顾客自带插件/settings")" = old ] || fail '失败没有恢复原设置'
        [ -f "$root/.hidden-old/marker" ] && [ -L "$root/linked-plugin" ] || fail '失败没有恢复全部项目'
        [ ! -e "$root/new-plugin" ] || fail '失败残留新插件'
    fi
    [ -z "$(find "$TMP_ROOT/$mode" -maxdepth 1 -name '.renkit-plugin-backup.*' -print -quit)" ] || fail '备份未清理'
)
for mode in ok write-fail stop-fail move-fail start-fail final-start-fail rollback-stop-fail; do
    run_cleanup "$mode"
done
(
    DECKY_PLUGIN_DIR="$TMP_ROOT/linked-root"
    ln -s "$TMP_ROOT/ok/plugins" "$DECKY_PLUGIN_DIR"
    toolbox_sudo() { fail '异常目录仍操作服务'; }
    if install_feature_plugins_clean legacy; then fail '接受链接插件根目录'; fi
    DECKY_PLUGIN_DIR="$TMP_ROOT"
    if install_feature_plugins_clean legacy; then fail '接受非插件目录'; fi
)
echo 'PASS: 已有插件保留/卸载选择、清理范围、失败恢复、目录保护模拟通过'
