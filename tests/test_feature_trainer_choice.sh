#!/bin/bash
set -euo pipefail
# Local fixtures and mocked dialogs/installers only. No real system operations.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
source "$PROJECT_ROOT/modules/plugin_store.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
unset ZHOUKEER_FEATURE_TRAINER_TOOLS
kdialog() { printf '%s\n' "$@" > "$TMP_ROOT/dialog"; printf '%s\n' "$DIALOG_RESULT"; }
DIALOG_RESULT=install
ZHOUKEER_AUTO_CONFIRM=1 select_feature_trainer_tools
[ "$FEATURE_TRAINER_TOOLS" = install ] || fail '自动确认绕过了选择'
grep -Fq '是否需要安装修改器所需工具（GE-10-29）' "$TMP_ROOT/dialog" || fail '缺少窗口说明'
DIALOG_RESULT=skip
select_feature_trainer_tools
[ "$FEATURE_TRAINER_TOOLS" = skip ] || fail '不安装未保存'
kdialog() { return 1; }
if select_feature_trainer_tools; then fail '关闭窗口仍继续'; fi
[ -z "$FEATURE_TRAINER_TOOLS" ] || fail '取消沿用旧选择'
ZHOUKEER_FEATURE_TRAINER_TOOLS=skip select_feature_trainer_tools || fail '初始化再次弹窗'
if ZHOUKEER_FEATURE_TRAINER_TOOLS=bad select_feature_trainer_tools; then fail '接受无效选项'; fi
unset -f kdialog
select_feature_trainer_tools <<< 1
[ "$FEATURE_TRAINER_TOOLS" = install ] || fail '终端安装选择错误'
select_feature_trainer_tools <<< ''
[ "$FEATURE_TRAINER_TOOLS" = skip ] || fail '终端默认没有跳过'
if select_feature_trainer_tools </dev/null; then fail '没有输入仍安装'; fi

detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; }
select_lsfg_variant() { LSFG_INSTALL_VARIANT=legacy; }
select_feature_plugin_cleanup() { FEATURE_PLUGIN_CLEANUP=keep; }
ensure_plugin_store_ready() { echo READY; }
install_feature_plugins_selected() { echo PLUGINS; return "${PLUGIN_RESULT:-0}"; }
bash() {
    [ "$#" -eq 3 ] && [ "$1" = "$PROJECT_ROOT/modules/ge_proton.sh" ] &&
        [ "$2" = install-trainer-one ] && [ "$3" = 10-29 ] || fail '非单版本安装命令'
    echo TRAINER
    return "${TRAINER_RESULT:-0}"
}
out="$(ZHOUKEER_FEATURE_TRAINER_TOOLS=install install_feature_plugins)"
[ "$(grep -cx TRAINER <<< "$out")" -eq 1 ] || fail '未恰好安装一次'
[ "$(tail -n 1 <<< "$out")" = TRAINER ] || fail '工具未在插件完成后安装'
out="$(ZHOUKEER_FEATURE_TRAINER_TOOLS=skip install_feature_plugins)"
! grep -q TRAINER <<< "$out" || fail '选择不安装仍执行'
if out="$(ZHOUKEER_FEATURE_TRAINER_TOOLS=bad install_feature_plugins)"; then fail '无效选择仍开始'; fi
! grep -q READY <<< "$out" || fail '选择取消后改动商城'
if out="$(ZHOUKEER_FEATURE_TRAINER_TOOLS=install PLUGIN_RESULT=1 install_feature_plugins)"; then fail '插件失败被吞掉'; fi
! grep -q TRAINER <<< "$out" || fail '插件失败仍安装工具'
if out="$(ZHOUKEER_FEATURE_TRAINER_TOOLS=install TRAINER_RESULT=1 install_feature_plugins)"; then fail '工具失败被吞掉'; fi
grep -Fq 'ZHOUKEER_FEATURE_TRAINER_TOOLS=skip' "$PROJECT_ROOT/modules/new_machine.sh" || fail '初始化会重复安装'
echo 'PASS: 修改器工具选择、取消、单版本安装、跳过、失败返回与初始化防重复'
