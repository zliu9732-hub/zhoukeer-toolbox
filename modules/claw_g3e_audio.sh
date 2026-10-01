#!/bin/bash

set -u

# 只支持用户提供方案对应的 EX / MS-1T91 / SteamOS Neptune 7.2。
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
source "$PROJECT_ROOT/core/platform.sh"
source "$PROJECT_ROOT/core/auth.sh"
source "$PROJECT_ROOT/core/logger.sh"

CLAW_AUDIO_SOURCE="$PROJECT_ROOT/third_party/claw-rt721-fix-v0.1.0"
CLAW_AUDIO_DMI=/sys/class/dmi/id
CLAW_AUDIO_MODULES=/usr/lib/modules
CLAW_AUDIO_SOUNDWIRE=/sys/bus/soundwire/devices/sdw:0:3:025d:0721:01
CLAW_AUDIO_KVER=""

claw_audio_message() {
    echo "$*"
    log "G3E 音频：$*"
}

claw_audio_run() {
    # 构建输出和系统诊断留在日志中，菜单只显示用途与结果。
    log "G3E 音频执行：$*"
    if "$@" >> "$LOG_FILE" 2>&1; then
        return 0
    fi
    claw_audio_message "当前步骤失败，详细记录：$LOG_FILE"
    return 1
}

claw_audio_check() {
    local product board pkgbase
    [ "$(uname -s)" = Linux ] && require_steamos || {
        claw_audio_message "此修复仅适用于 SteamOS，已停止。"; return 1;
    }
    [ "$(uname -m)" = x86_64 ] || return 1
    product="$(cat "$CLAW_AUDIO_DMI/product_name" 2>/dev/null)" || return 1
    board="$(cat "$CLAW_AUDIO_DMI/board_name" 2>/dev/null)" || return 1
    case "$product" in
        'Claw 8 EX AI+ CG3EM'|'Claw 8 EX AI+ CG3EM Launch Pack') ;;
        *) claw_audio_message "当前不是支持的微星 Claw 8 EX G3E，已停止。"; return 1 ;;
    esac
    [ "$board" = MS-1T91 ] && [ -e "$CLAW_AUDIO_SOUNDWIRE" ] || {
        claw_audio_message "未发现此机型对应的音频硬件，已停止。"; return 1;
    }
    CLAW_AUDIO_KVER="$(uname -r)"
    # 版本进入路径与构建参数前只接受内核版本允许的字符。
    case "$CLAW_AUDIO_KVER" in
        ''|*[!a-zA-Z0-9._+-]*) return 1 ;;
        7.2.*) ;;
        *) claw_audio_message "此方案仅适用于 7.2 内核，当前版本不匹配。"; return 1 ;;
    esac
    pkgbase="$(cat "$CLAW_AUDIO_MODULES/$CLAW_AUDIO_KVER/pkgbase" 2>/dev/null)" || return 1
    [ "$pkgbase" = linux-neptune-72 ] || {
        claw_audio_message "当前内核与这项修复不匹配，已停止。"; return 1;
    }
    claw_audio_message "已确认机型：${product}；主板：${board}；内核：${CLAW_AUDIO_KVER}。"
}

claw_audio_plan() {
    claw_audio_check || return 1
    echo "将尝试修复内置扬声器和麦克风无声音的问题。"
    echo "实验性修复，需要管理员权限，会安装系统组件和开机音频修复服务。"
    echo "修复可能增加待机耗电；系统更新后可能需要重新修复。完成后建议手动重启。"
    echo "会暂时关闭系统只读保护，结束时恢复原状态；不会自动重启。"
    echo "作者：stevedamnvan 及贡献者；许可证：GPL-2.0-only。"
}

claw_audio_prepare_source() {
    local destination="$1"
    # 构建前验证内置原包，保留上游来源及许可证；不执行浮动分支脚本。
    python3 "$PROJECT_ROOT/scripts/prepare_claw_audio.py" "$CLAW_AUDIO_SOURCE" "$destination"
}

claw_audio_install() (
    # 独立进程范围保存清理钩子，避免覆盖主界面的退出处理。
    local workspace="" readonly_changed=0 readonly_state installed_kernel header_info header_version
    local build_dir package_file module_state
    claw_audio_cleanup() {
        local status=$?
        trap - EXIT
        if [ "$readonly_changed" = 1 ]; then
            if ! toolbox_sudo steamos-readonly enable; then
                claw_audio_message "恢复系统只读保护失败，请在终端执行 sudo steamos-readonly enable。"
                status=1
            fi
        fi
        [ -z "$workspace" ] || rm -rf -- "$workspace"
        if [ "$status" -ne 0 ]; then
            claw_audio_message "音频修复未完成，请查看上方提示；详细记录已保存到 Renkit 日志。"
        fi
        exit "$status"
    }
    trap claw_audio_cleanup EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    claw_audio_plan || exit 1
    [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = 1 ] || {
        claw_audio_message "请从“掌机适配”进入并点击确认后执行。"; exit 1;
    }
    [ "$(id -u)" -ne 0 ] || { claw_audio_message "请用普通桌面用户启动 Renkit。"; exit 1; }
    for name in python3 pacman makepkg make steamos-readonly systemctl dkms modinfo depmod wpctl; do
        require_command "$name" || exit 1
    done
    # 不进行 pacman -Sy 后的部分升级、不关闭软件签名验证。
    installed_kernel="$(pacman -Q linux-neptune-72)" || exit 1
    installed_kernel="${installed_kernel#* }"
    header_info="$(LC_ALL=C pacman -Si linux-neptune-72-headers)" || exit 1
    header_version="$(printf '%s\n' "$header_info" | awk '$1 == "Version" && $2 == ":" {print $3; exit}')"
    [ -n "$header_version" ] && [ "$header_version" = "$installed_kernel" ] || {
        claw_audio_message "音频修复所需组件与当前系统版本不一致，请先完成 SteamOS 系统更新并重启。"; exit 1;
    }
    if [ -d "/usr/src/claw-rt721-fix-0.1.0" ] && ! pacman -Q claw-rt721-fix-dkms >/dev/null 2>&1; then
        claw_audio_message "发现手动安装的旧音频修复，请先按原方案卸载，避免覆盖。"; exit 1
    fi
    workspace="$(mktemp -d)" || exit 1
    build_dir="$workspace/audio"
    claw_audio_prepare_source "$build_dir" || exit 1
    readonly_state="$(LC_ALL=C steamos-readonly status)" || exit 1
    case "$readonly_state" in
        enabled) readonly_changed=1; toolbox_sudo steamos-readonly disable || exit 1 ;;
        disabled) ;;
        *) claw_audio_message "无法确认系统只读保护状态，已停止。"; exit 1 ;;
    esac
    claw_audio_message "正在准备音频修复所需组件…"
    claw_audio_run toolbox_sudo pacman -S --needed --noconfirm base-devel gcc dkms linux-neptune-72-headers \
        sof-firmware alsa-ucm-conf pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber || exit 1
    [ -e "$CLAW_AUDIO_MODULES/$CLAW_AUDIO_KVER/build/Makefile" ] || {
        claw_audio_message "所需系统组件没有准备完整，已停止。"; exit 1;
    }
    [ "$(make -s -C "$CLAW_AUDIO_MODULES/$CLAW_AUDIO_KVER/build" kernelrelease)" = "$CLAW_AUDIO_KVER" ] || {
        claw_audio_message "修复组件与正在使用的内核不一致，已停止。"; exit 1;
    }
    cd "$build_dir" || exit 1
    claw_audio_message "正在生成适用于这台掌机的音频修复…"
    claw_audio_run make "KERNELRELEASE=$CLAW_AUDIO_KVER" || exit 1
    claw_audio_run makepkg --cleanbuild --force --noconfirm || exit 1
    package_file="$build_dir/claw-rt721-fix-dkms-0.1.0-1-x86_64.pkg.tar.zst"
    [ -f "$package_file" ] && [ ! -L "$package_file" ] || {
        claw_audio_message "没有生成有效的音频修复，已停止。"; exit 1;
    }
    claw_audio_run toolbox_sudo pacman -U --noconfirm "$package_file" || exit 1
    module_state="$(dkms status -m claw-rt721-fix -v 0.1.0 -k "$CLAW_AUDIO_KVER")" || exit 1
    if [[ "$module_state" != *': installed'* ]]; then
        if [[ "$module_state" != *': built'* ]]; then
            claw_audio_run toolbox_sudo dkms build -m claw-rt721-fix -v 0.1.0 -k "$CLAW_AUDIO_KVER" || exit 1
        fi
        claw_audio_run toolbox_sudo dkms install -m claw-rt721-fix -v 0.1.0 -k "$CLAW_AUDIO_KVER" || exit 1
    fi
    claw_audio_run toolbox_sudo depmod -a "$CLAW_AUDIO_KVER" || exit 1
    claw_audio_run modinfo -k "$CLAW_AUDIO_KVER" claw_rt721_amp || exit 1
    claw_audio_run toolbox_sudo systemctl daemon-reload || exit 1
    claw_audio_run toolbox_sudo systemctl enable claw-rt721-fix.service || exit 1
    claw_audio_run toolbox_sudo systemctl restart claw-rt721-fix.service || exit 1
    claw_audio_run systemctl is-active --quiet claw-rt721-fix.service || exit 1
    claw_audio_run systemctl --user restart pipewire pipewire-pulse wireplumber || exit 1
    claw_audio_run wpctl status || exit 1
    claw_audio_message "音频修复已安装，建议保存工作后手动重启，再测试扬声器和麦克风。"
)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        plan) claw_audio_plan ;;
        install) claw_audio_install ;;
        *) echo "请从 Renkit 的“掌机适配”进入。"; exit 1 ;;
    esac
fi
