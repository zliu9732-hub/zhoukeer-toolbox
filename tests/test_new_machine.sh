#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_simulated_flow() (
    local skip_update="$1"

    source "$PROJECT_ROOT/modules/new_machine.sh"
    NEW_MACHINE_SKIP_SYSTEM_UPDATE="$skip_update"
    NEW_MACHINE_REPORT_FILE="$TMP_ROOT/report-$skip_update.txt"

    select_optional_launchers() { return 0; }
    select_system_component_update() { return 0; }
    confirm_initialization() { return 0; }
    basic_steamdeck_check() { return 0; }
    run_new_machine_preflight() { return 0; }
    new_machine_report_begin() { : > "$NEW_MACHINE_REPORT_FILE"; }
    new_machine_report_result() { return 0; }
    check_network() { return 0; }
    run_step() { printf 'RUN|%s|%s\n' "$1" "$*"; }
    skip_step() { printf 'SKIP|%s|%s\n' "$1" "$2"; }
    finish_new_machine_report() { return 0; }
    log() { return 0; }

    run_new_machine_initialization
)

# 本测试覆盖的是函数替身和命令记录，不执行网络、提权、pacman、Flatpak 或 SteamOS 操作。
skip_output="$(run_simulated_flow 1)"
printf '%s\n' "$skip_output" | grep -Fq 'SKIP|【02】更新系统组件、密钥环和 locale|已按开始前选择跳过' || \
    fail "选择跳过后仍执行系统组件更新"
printf '%s\n' "$skip_output" | grep -Fq 'modules/domestic_source.sh enable' || \
    fail "跳过系统更新后没有继续配置用户级 Flatpak 国内源"
if printf '%s\n' "$skip_output" | grep -Fq 'modules/domestic_source.sh init'; then
    fail "选择跳过后仍调用完整国内源与系统更新流程"
fi

update_output="$(run_simulated_flow 0)"
printf '%s\n' "$update_output" | grep -Fq 'modules/domestic_source.sh init' || \
    fail "选择不跳过时没有调用完整系统更新流程"
if printf '%s\n' "$update_output" | grep -Fq 'modules/domestic_source.sh enable'; then
    fail "选择不跳过时误用仅配置 Flatpak 国内源流程"
fi

for output in "$skip_output" "$update_output"; do
    printf '%s\n' "$output" | grep -Fq 'modules/ge_proton.sh install-trainer-one 10-29' || \
        fail "新机初始化没有只安装 GE-Proton 10-29"
    if printf '%s\n' "$output" | grep -Eq 'install-trainer($|[|[:space:]])'; then
        fail "新机初始化仍会安装全部四个修改器兼容层"
    fi
    printf '%s\n' "$output" | grep -Fq 'modules/plugin_store.sh lsfg-mako' || \
        fail "新机初始化没有安装 MAKO 小黄鸭"
    printf '%s\n' "$output" | grep -Fq 'modules/plugin_store.sh features' || \
        fail "新机初始化没有保留旧版小黄鸭所在的常用插件组合"
done

prompt_skip="$(
    source "$PROJECT_ROOT/modules/new_machine.sh"
    NEW_MACHINE_SKIP_SYSTEM_UPDATE=0
    ZHOUKEER_AUTO_CONFIRM=0
    select_system_component_update <<< "y" >/dev/null
    printf '%s' "$NEW_MACHINE_SKIP_SYSTEM_UPDATE"
)"
[ "$prompt_skip" = "1" ] || fail "终端提示选择跳过后未记录跳过状态"

prompt_update="$(
    source "$PROJECT_ROOT/modules/new_machine.sh"
    NEW_MACHINE_SKIP_SYSTEM_UPDATE=1
    ZHOUKEER_AUTO_CONFIRM=0
    select_system_component_update <<< "" >/dev/null
    printf '%s' "$NEW_MACHINE_SKIP_SYSTEM_UPDATE"
)"
[ "$prompt_update" = "0" ] || fail "终端提示直接回车后没有保留完整更新"

graphical_skip="$(
    source "$PROJECT_ROOT/modules/new_machine.sh"
    kdialog() { printf '%s\n' skip; }
    NEW_MACHINE_SKIP_SYSTEM_UPDATE=0
    ZHOUKEER_AUTO_CONFIRM=1
    select_system_component_update >/dev/null
    printf '%s' "$NEW_MACHINE_SKIP_SYSTEM_UPDATE"
)"
[ "$graphical_skip" = "1" ] || fail "图形提示选择跳过后未记录跳过状态"

graphical_update="$(
    source "$PROJECT_ROOT/modules/new_machine.sh"
    kdialog() { printf '%s\n' update; }
    NEW_MACHINE_SKIP_SYSTEM_UPDATE=1
    ZHOUKEER_AUTO_CONFIRM=1
    select_system_component_update >/dev/null
    printf '%s' "$NEW_MACHINE_SKIP_SYSTEM_UPDATE"
)"
[ "$graphical_update" = "0" ] || fail "图形提示选择完整更新后未记录更新状态"

run_machine_profile() (
    local test_machine_identity="$1"

    source "$PROJECT_ROOT/modules/new_machine.sh"
    read_machine_identity() { printf '%s\n' "$test_machine_identity"; }
    env() { printf 'PLUGIN|%s\n' "$*"; }
    apply_machine_profile
)

empty_identity_output="$(run_machine_profile '')"
printf '%s\n' "$empty_identity_output" | grep -Fq \
    '机器识别：未提供 DMI 型号' || \
    fail "DMI 为空时没有显示明确的未知型号提示"

for fallback_identity in \
    "valve steam deck galileo" \
    "lenovo legion go 2" \
    "lenovo legion go s" \
    "lenovo 83n0 lnvnb161216" \
    "lenovo 83n1 lnvnb161216" \
    "lenovo 83l3" \
    "lenovo 83n6" \
    "lenovo 83q2" \
    "lenovo 83q3" \
    "lenovo 83e10" \
    "unknown handheld"; do
    profile_output="$(run_machine_profile "$fallback_identity")"
    printf '%s\n' "$profile_output" | grep -Fq \
        'modules/plugin_store.sh simpledeckytdp-zh-gitee' || \
        fail "$fallback_identity 没有回退安装掌机功耗控制"
    if printf '%s\n' "$profile_output" | grep -Eq \
        'modules/plugin_store.sh (allycenter|legiongo-remapper|gpd-control|lego-vibe|lego2-fan)'; then
        fail "$fallback_identity 错误安装了专用掌机插件"
    fi
done

for profile_case in \
    "asus rog ally|allycenter" \
    "asustek rc71l|allycenter" \
    "asustek rc72la|allycenter" \
    "asustek rc73xa|allycenter" \
    "gpd win max 2|gpd-control"; do
    identity="${profile_case%%|*}"
    expected_action="${profile_case##*|}"
    profile_output="$(run_machine_profile "$identity")"
    printf '%s\n' "$profile_output" | grep -Fq \
        "modules/plugin_store.sh $expected_action" || \
        fail "$identity 没有安装匹配的专用掌机插件"
    if printf '%s\n' "$profile_output" | grep -Fq \
        'modules/plugin_store.sh simpledeckytdp-zh-gitee'; then
        fail "$identity 已匹配专用插件却又安装了通用功耗控制"
    fi
done

for legion_identity in \
    "lenovo legion go" \
    "lenovo 83e1 lnvnb161216"; do
    profile_output="$(run_machine_profile "$legion_identity")"
    for expected_action in legiongo-remapper lego-vibe; do
        printf '%s\n' "$profile_output" | grep -Fq \
            "modules/plugin_store.sh $expected_action" || \
            fail "$legion_identity 没有安装 $expected_action"
    done
    if printf '%s\n' "$profile_output" | grep -Fq \
        'modules/plugin_store.sh simpledeckytdp-zh-gitee'; then
        fail "$legion_identity 已匹配专用插件却又安装了通用功耗控制"
    fi
done

failed_legion_output="$({
    source "$PROJECT_ROOT/modules/new_machine.sh"
    env() {
        printf 'PLUGIN|%s\n' "$*"
        case "$*" in *legiongo-remapper) return 1 ;; esac
    }
    install_initial_legion_go_plugins
} 2>&1)" && fail "Legion Go 控制中心失败后错误报告为全部成功"
printf '%s\n' "$failed_legion_output" | grep -Fq \
    'modules/plugin_store.sh lego-vibe' || \
    fail "Legion Go 控制中心失败后没有继续安装震动控制"

dmi_root="$TMP_ROOT/legion-go-dmi"
mkdir -p "$dmi_root"
printf '%s\n' LENOVO > "$dmi_root/sys_vendor"
printf '%s\n' 83E1 > "$dmi_root/product_name"
printf '%s\n' LNVNB161216 > "$dmi_root/board_name"
printf '%s\n' 'Legion Go 8APU1' > "$dmi_root/product_version"
printf '%s\n' 'LENOVO_MT_83E1_BU_idea_FM_Legion Go 8APU1' > "$dmi_root/product_sku"
printf '%s\n' 'Legion Go 8APU1' > "$dmi_root/product_family"
dmi_identity="$(
    source "$PROJECT_ROOT/modules/new_machine.sh"
    NEW_MACHINE_DMI_ROOT="$dmi_root"
    read_machine_identity
)"
printf '%s\n' "$dmi_identity" | grep -Fq \
    'lenovo 83e1 lnvnb161216 legion go 8apu1 lenovo_mt_83e1_bu_idea_fm_legion go 8apu1 legion go 8apu1' || \
    fail "没有读取 Legion Go 的完整 DMI 身份字段"

echo "PASS: 新机初始化更新可选、GE-Proton 10-29 和机型插件回退测试通过"
