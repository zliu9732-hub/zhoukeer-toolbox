#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/dual_system.sh"

F1_BIOS_PRODUCT_NAME="ONEXPLAYER F1"
F1_BIOS_PRODUCT_FILE="${ZHOUKEER_F1_BIOS_PRODUCT_FILE:-/sys/devices/virtual/dmi/id/product_name}"
F1_BIOS_CPUINFO_FILE="${ZHOUKEER_F1_BIOS_CPUINFO_FILE:-/proc/cpuinfo}"
F1_BIOS_PREFERRED_SHARED_DRIVE="/run/media/deck/GAME"
F1_BIOS_RELEASE_URL="https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/f1-bios-v1.14/ONEXFLY-F1-7840U-BIOS-V1.14.zip"
F1_BIOS_ARCHIVE_SHA256="32b166cf34a59220b3f8c5f9d12fc1f23348dd3af63c5b5ced6c4d5150e8d51e"
F1_BIOS_ARCHIVE_ROOT="F1-AMD7840U-Black-White-BIOS-V1.14-HarmanForWin&Linux-tutorial"
F1_BIOS_TARGET_NAME="F1-BIOS-V1.14"
F1_BIOS_BIN_NAME="OXP_7840U_P6C2L18M0C15_V1.14_AMP_LinuxV0_EC_V1.0.22_S011.8_20240725.bin"
F1_BIOS_TMP_ROOT=""
F1_BIOS_STAGE_DIR=""

f1_bios_cleanup() {
    if [ -n "$F1_BIOS_TMP_ROOT" ] && [ -d "$F1_BIOS_TMP_ROOT" ]; then
        rm -rf -- "$F1_BIOS_TMP_ROOT"
    fi
    if [ -n "$F1_BIOS_STAGE_DIR" ] && [ -d "$F1_BIOS_STAGE_DIR" ]; then
        rm -rf -- "$F1_BIOS_STAGE_DIR"
    fi
}

f1_bios_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$1" | awk '{print $1}'
    else
        return 1
    fi
}

f1_bios_expected_archive_paths() {
    cat <<EOF
${F1_BIOS_ARCHIVE_ROOT}/
${F1_BIOS_ARCHIVE_ROOT}/AFUWINGUIx64.EXE
${F1_BIOS_ARCHIVE_ROOT}/AFUWINx64.exe
${F1_BIOS_ARCHIVE_ROOT}/AfuEfix64.efi
${F1_BIOS_ARCHIVE_ROOT}/OXF.bat
${F1_BIOS_ARCHIVE_ROOT}/${F1_BIOS_BIN_NAME}
${F1_BIOS_ARCHIVE_ROOT}/OneXFly-BIOS-Process Steps.txt
${F1_BIOS_ARCHIVE_ROOT}/Thumbs.db
${F1_BIOS_ARCHIVE_ROOT}/amifldrv64.sys
${F1_BIOS_ARCHIVE_ROOT}/amigendrv64.sys
EOF
}

f1_bios_archive_layout_valid() {
    local archive="$1" actual expected

    actual="$(unzip -Z1 "$archive" 2>/dev/null)" || return 1
    actual="$(printf '%s\n' "$actual" | LC_ALL=C sort)" || return 1
    expected="$(f1_bios_expected_archive_paths)" || return 1
    expected="$(printf '%s\n' "$expected" | LC_ALL=C sort)" || return 1
    [ "$actual" = "$expected" ]
}

f1_bios_vendor_files_valid() {
    local directory="$1" expected name actual

    while IFS='|' read -r expected name; do
        [ -f "$directory/$name" ] && [ ! -L "$directory/$name" ] || return 1
        actual="$(f1_bios_sha256 "$directory/$name")" || return 1
        [ "$actual" = "$expected" ] || return 1
    done <<'EOF'
2f494925a049063a6a0e9f785fd58b6ad966ab2b5bcca5b525b69e86d6efb882|AFUWINGUIx64.EXE
9476498ae0bf344c3a573f3f995a621033be45fe8daff9bbcd25e4cceae72e6d|AFUWINx64.exe
1f01ee07c5b0160fc0442eae871c054265e009be00a3b71cbed6baee508578f4|AfuEfix64.efi
bf061f3c821cba27da194d841c7f2bf22151c06c0c241e0f9b36152b7e168577|OXF.bat
767b8273127bae2cf49acb31b321da87e823108db1f33ee1df903cd92911478c|OXP_7840U_P6C2L18M0C15_V1.14_AMP_LinuxV0_EC_V1.0.22_S011.8_20240725.bin
7bc79e734b4a3f13c53a057c670f7fd2b2d4140fbe28c5516db2e3029161c9ff|OneXFly-BIOS-Process Steps.txt
d28886dac390ff0d5cd0fa460a48295540dc3f02ae166c755a62b6268cc8238e|Thumbs.db
e7cbfb16261de1c7f009431d374d90e9eb049ba78246e38bc4c8b9e06f324b6f|amifldrv64.sys
ffc72f0bde21ba20aa97bee99d9e96870e5aa40cce9884e44c612757f939494f|amigendrv64.sys
EOF
}

f1_bios_require_target_device() {
    local product=""

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "此功能仅在 SteamOS 下准备 BIOS 文件，已停止执行。"
        return 1
    fi
    [ -r "$F1_BIOS_PRODUCT_FILE" ] && \
        product="$(tr -d '\r\n' < "$F1_BIOS_PRODUCT_FILE" 2>/dev/null)"
    if [ "$product" != "$F1_BIOS_PRODUCT_NAME" ]; then
        echo "当前设备不是 ${F1_BIOS_PRODUCT_NAME}，已拒绝准备 BIOS。"
        return 1
    fi
    if [ ! -r "$F1_BIOS_CPUINFO_FILE" ] || \
        ! grep -Eiq 'AMD Ryzen(\(TM\))?[[:space:]]+7[[:space:]]+7840U' "$F1_BIOS_CPUINFO_FILE"; then
        echo "当前设备未检测到 AMD Ryzen 7 7840U。"
        echo "此 BIOS 不适用于 8840U、F1 Pro 或其他处理器，已停止执行。"
        return 1
    fi
}

f1_bios_shared_drive_is_valid() {
    local path="$1" filesystem source

    [ -d "$path" ] || return 1
    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ]; then
        [ -w "$path" ]
        return
    fi
    filesystem="$(findmnt -rn -T "$path" -o FSTYPE 2>/dev/null | head -n 1)"
    is_shared_filesystem "$filesystem" || return 1
    source="$(findmnt -rn -T "$path" -o SOURCE 2>/dev/null | head -n 1)"
    case "$source" in /dev/*) ;; *) return 1 ;; esac
    if shared_partition_is_windows_system "$source" "$filesystem"; then
        return 1
    fi
    [ -w "$path" ]
}

f1_bios_resolve_shared_drive() {
    local preferred="$F1_BIOS_PREFERRED_SHARED_DRIVE"
    local candidate candidate_name device mountpoint

    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ] && \
        [ -n "${ZHOUKEER_F1_BIOS_SHARED_DRIVE:-}" ]; then
        preferred="$ZHOUKEER_F1_BIOS_SHARED_DRIVE"
    fi
    if f1_bios_shared_drive_is_valid "$preferred"; then
        canonical_directory "$preferred"
        return 0
    fi
    for candidate in /run/media/deck/*; do
        [ -d "$candidate" ] || continue
        candidate_name="$(basename "$candidate" | tr '[:upper:]' '[:lower:]')"
        [ "$candidate_name" = "game" ] || continue
        if f1_bios_shared_drive_is_valid "$candidate"; then
            canonical_directory "$candidate"
            return 0
        fi
    done

    for command_name in lsblk udisksctl findmnt; do
        require_command "$command_name" || return 1
    done
    device="$(find_shared_drive_device 1)" || return 1
    mountpoint="$(shared_drive_mountpoint "$device" || true)"
    if [ -z "$mountpoint" ]; then
        echo "正在挂载互通盘：$device" >&2
        mountpoint="$(mount_shared_drive_device "$device")" || return 1
    fi
    create_shared_drive_shortcut "$mountpoint" || return 1
    if ! f1_bios_shared_drive_is_valid "$mountpoint"; then
        echo "互通盘不是可写的 NTFS/exFAT 分区，请先选择“恢复互通盘写入”。" >&2
        return 1
    fi
    canonical_directory "$mountpoint"
}

f1_bios_write_notice() {
    local target="$1"

    cat > "$target/刷写前必读.txt" <<'EOF'
飞行家 F1 V1.14 BIOS（Harman Linux 声音修复）

仅适用于：ONEXPLAYER F1 / ONEXFLY、AMD Ryzen 7 7840U、普通黑色或白色版本。
严禁用于：8840U、EVA、F1 Pro、其他处理器或其他机型。

请重启进入 Windows 后操作：
1. 接通原装或可靠充电器，电量保持充足。
2. 暂时关闭 Windows Defender 实时保护。
3. 打开本目录，双击 OXF.bat；若未启动，使用管理员命令提示符进入本目录后运行 OXF.bat。
4. 刷写开始后不要关机、休眠、拔电源或强制退出。
5. 等待工具提示成功并自动重启；首次启动黑屏 2～3 分钟属于正常现象。
6. 进入 Windows 后运行 msinfo32，确认 BIOS 版本包含 V1.14，然后重新开启 Defender。

Renkit 只负责校验并把原厂文件复制到互通盘，不会在 SteamOS 下执行 BIOS 刷写。
EOF
}

f1_bios_prepare() {
    local shared_drive target archive extract_dir source_dir

    f1_bios_require_target_device || return 1
    for command_name in curl unzip; do
        require_command "$command_name" || return 1
    done
    shared_drive="$(f1_bios_resolve_shared_drive)" || {
        echo "未找到可写互通盘；通常应挂载在 /run/media/deck/GAME（名称不区分大小写）。"
        return 1
    }
    target="$shared_drive/$F1_BIOS_TARGET_NAME"

    if [ -d "$target" ] && [ ! -L "$target" ] && f1_bios_vendor_files_valid "$target"; then
        echo "飞行家 F1 V1.14 BIOS 已经准备完成：$target"
        echo "请重启进入 Windows，阅读“刷写前必读.txt”后运行 OXF.bat。"
        return 0
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "目标位置已存在但内容不完整，Renkit 不会覆盖：$target"
        echo "请先人工核对并改名保存原目录，再重新执行。"
        return 1
    fi

    F1_BIOS_TMP_ROOT="$(mktemp -d 2>/dev/null)" || return 1
    archive="$F1_BIOS_TMP_ROOT/f1-bios-v1.14.zip"
    extract_dir="$F1_BIOS_TMP_ROOT/extracted"
    mkdir -p -- "$extract_dir" || return 1
    if ! download_github_file "$F1_BIOS_RELEASE_URL" "$archive" \
        "$F1_BIOS_ARCHIVE_SHA256" "飞行家 F1 V1.14 BIOS"; then
        echo "BIOS 下载或 SHA256 校验失败，没有写入互通盘。"
        return 1
    fi
    if ! f1_bios_archive_layout_valid "$archive"; then
        echo "BIOS 压缩包结构与已验证原厂包不一致，已停止。"
        return 1
    fi
    if ! unzip -q "$archive" -d "$extract_dir"; then
        echo "BIOS 压缩包解压失败，没有写入互通盘。"
        return 1
    fi
    source_dir="$extract_dir/$F1_BIOS_ARCHIVE_ROOT"
    if ! f1_bios_vendor_files_valid "$source_dir" || \
        find "$source_dir" -type l -print -quit 2>/dev/null | grep -q .; then
        echo "BIOS 文件完整性校验失败，已停止。"
        return 1
    fi

    F1_BIOS_STAGE_DIR="$(mktemp -d "$shared_drive/.renkit-f1-bios.XXXXXX" 2>/dev/null)" || {
        echo "互通盘不可写，请先选择“恢复互通盘写入”。"
        return 1
    }
    cp -R -- "$source_dir/." "$F1_BIOS_STAGE_DIR/" || return 1
    f1_bios_write_notice "$F1_BIOS_STAGE_DIR" || return 1
    if ! f1_bios_vendor_files_valid "$F1_BIOS_STAGE_DIR"; then
        echo "复制到互通盘后的 BIOS 校验失败，已停止。"
        return 1
    fi
    if ! mv -- "$F1_BIOS_STAGE_DIR" "$target"; then
        echo "无法启用互通盘中的 BIOS 目录，已停止。"
        return 1
    fi
    F1_BIOS_STAGE_DIR=""

    log "飞行家 F1 V1.14 BIOS 已准备到互通盘: $target"
    echo "准备完成：$target"
    echo "Renkit 没有刷写 BIOS。请重启进入 Windows，阅读“刷写前必读.txt”后运行 OXF.bat。"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    trap f1_bios_cleanup EXIT
    case "${1:-}" in
        prepare) f1_bios_prepare ;;
        *)
            echo "用法: $0 prepare"
            exit 1
            ;;
    esac
fi
