#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"
# 复用常用软件模块中经过验证的 Flathub 国内缓存配置。
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/software.sh"

ARCHLINUXCN_REPO_URL="https://mirror.sjtu.edu.cn/archlinux-cn/\$arch"
ARCHLINUXCN_FALLBACK_URL="https://mirrors.ustc.edu.cn/archlinuxcn/\$arch"
ARCHLINUXCN_OFFICIAL_URL="https://repo.archlinuxcn.org/\$arch"
ARCHLINUXCN_BLOCK_BEGIN="# BEGIN ZHOUKEER ARCHLINUXCN"
ARCHLINUXCN_BLOCK_END="# END ZHOUKEER ARCHLINUXCN"
DISCOVER_PACKAGEKIT_BACKEND="${ZHOUKEER_DISCOVER_BACKEND_PATH:-/usr/lib/qt6/plugins/discover/packagekit-backend.so}"
DISCOVER_PACKAGEKIT_BACKEND_DISABLED="${DISCOVER_PACKAGEKIT_BACKEND}.disabled"

pacman_conf_has_archlinuxcn() {
    LC_ALL=C awk '
        /^[[:space:]]*\[archlinuxcn\][[:space:]]*($|#)/ { found=1 }
        END { exit(found ? 0 : 1) }
    ' "$1"
}

write_managed_archlinuxcn_repo() {
    local pacman_conf="${1:-/etc/pacman.conf}"
    local tmp_file

    if [ ! -f "$pacman_conf" ] || [ -L "$pacman_conf" ]; then
        echo "pacman 配置不是安全的普通文件：$pacman_conf"
        return 1
    fi
    if ! grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf" && \
        pacman_conf_has_archlinuxcn "$pacman_conf"; then
        echo "检测到用户已有 archlinuxcn 配置，保持原配置不变。"
        return 0
    fi

    tmp_file="$(mktemp)" || return 1
    if ! LC_ALL=C awk \
        -v begin="$ARCHLINUXCN_BLOCK_BEGIN" \
        -v end="$ARCHLINUXCN_BLOCK_END" '
            $0 == begin { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$pacman_conf" > "$tmp_file"; then
        rm -f -- "$tmp_file"
        return 1
    fi
    printf '\n%s\n[archlinuxcn]\nServer = %s\nServer = %s\nServer = %s\n%s\n' \
        "$ARCHLINUXCN_BLOCK_BEGIN" "$ARCHLINUXCN_REPO_URL" \
        "$ARCHLINUXCN_FALLBACK_URL" "$ARCHLINUXCN_OFFICIAL_URL" \
        "$ARCHLINUXCN_BLOCK_END" >> "$tmp_file"

    if ! toolbox_sudo install -m 0644 -- "$tmp_file" "$pacman_conf"; then
        rm -f -- "$tmp_file"
        echo "写入 archlinuxcn 国内仓库失败。"
        return 1
    fi
    rm -f -- "$tmp_file"
    echo "已配置 archlinuxcn 镜像回退：上海交大 → 中科大 → 官方源"
}

remove_managed_archlinuxcn_repo() {
    local pacman_conf="${1:-/etc/pacman.conf}"
    local tmp_file

    [ -f "$pacman_conf" ] && [ ! -L "$pacman_conf" ] || return 1
    if ! grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf"; then
        echo "未发现Renkit管理的 archlinuxcn 配置，无需移除。"
        return 0
    fi

    tmp_file="$(mktemp)" || return 1
    if ! LC_ALL=C awk \
        -v begin="$ARCHLINUXCN_BLOCK_BEGIN" \
        -v end="$ARCHLINUXCN_BLOCK_END" '
            $0 == begin { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$pacman_conf" > "$tmp_file" || \
        ! toolbox_sudo install -m 0644 -- "$tmp_file" "$pacman_conf"; then
        rm -f -- "$tmp_file"
        return 1
    fi
    rm -f -- "$tmp_file"
    echo "已移除Renkit管理的 archlinuxcn 配置。"
}

configure_chinese_locales() {
    local locale_gen="${1:-/etc/locale.gen}"
    local tmp_file

    if [ ! -f "$locale_gen" ] || [ -L "$locale_gen" ]; then
        echo "locale 配置不是安全的普通文件：$locale_gen"
        return 1
    fi
    tmp_file="$(mktemp)" || return 1
    if ! LC_ALL=C awk '
        /^[#[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8[[:space:]]*$/ {
            if (!seen_en) print "en_US.UTF-8 UTF-8"
            seen_en=1
            next
        }
        /^[#[:space:]]*zh_CN\.UTF-8[[:space:]]+UTF-8[[:space:]]*$/ {
            if (!seen_zh) print "zh_CN.UTF-8 UTF-8"
            seen_zh=1
            next
        }
        { print }
        END {
            if (!seen_en) print "en_US.UTF-8 UTF-8"
            if (!seen_zh) print "zh_CN.UTF-8 UTF-8"
        }
    ' "$locale_gen" > "$tmp_file" || \
        ! toolbox_sudo install -m 0644 -- "$tmp_file" "$locale_gen"; then
        rm -f -- "$tmp_file"
        return 1
    fi
    rm -f -- "$tmp_file"
    toolbox_sudo locale-gen
}

configure_domestic_flatpak() {
    require_supported_gaming_os || return 1
    require_command flatpak || return 1
    require_command timeout || return 1

    DOMESTIC_FLATPAK_SKIPPED=0
    export DOMESTIC_FLATPAK_SKIPPED

    if [ "$IS_BAZZITE" -eq 1 ]; then
        echo "配置 Bazzite 用户级 Flatpak 国内缓存..."
    else
        echo "[2/3] 配置上海交大和中科大 Flatpak 国内缓存..."
    fi
    if ! ensure_flatpak_remotes; then
        if flatpak_any_remote_exists; then
            DOMESTIC_FLATPAK_SKIPPED=1
            export DOMESTIC_FLATPAK_SKIPPED
            echo "Flatpak 国内缓存本次已跳过，继续使用现有软件源，不影响其他功能。"
            log "Flatpak国内缓存配置未完成；检测到现有远程，按可选项跳过"
            return 0
        fi
        echo "未检测到任何可用的 Flatpak 软件源，后续应用安装无法继续。"
        return 1
    fi

    echo "国内下载源配置完成：${FLATHUB_CN_REMOTE}、${FLATHUB_CN_FALLBACK_REMOTE}。"
}

packages_installed_without_known_upgrades() {
    local package_name pending_upgrades

    pacman -Q "$@" >/dev/null 2>&1 || return 1
    # pacman -Qu 在“没有可更新软件包”时会返回 1；这是正常的空结果，
    # 不能据此把已经安装的组件误判为不完整。
    pending_upgrades="$(pacman -Qu 2>/dev/null || true)"
    for package_name in "$@"; do
        if printf '%s\n' "$pending_upgrades" | awk -v package="$package_name" \
            '$1 == package { found=1 } END { exit(found ? 0 : 1) }'; then
            return 1
        fi
    done
    return 0
}

archlinuxcn_keyring_ready() {
    packages_installed_without_known_upgrades archlinuxcn-keyring
}

configure_archlinuxcn_with_fallback() {
    local pacman_conf="${1:-/etc/pacman.conf}"
    local populate_output

    if ! write_managed_archlinuxcn_repo "$pacman_conf"; then
        echo "- archlinuxcn 本次未启用，已跳过并继续配置 Flatpak 国内缓存。"
        return 0
    fi

    if archlinuxcn_keyring_ready; then
        echo "✓ 已检测到 archlinuxcn 密钥环，无需重复安装。"
    else
        echo "正在通过上海交大、中科大和官方回退源安装 archlinuxcn 密钥环..."
        if ! toolbox_sudo pacman -Sy --needed --noconfirm archlinuxcn-keyring; then
            if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf" 2>/dev/null && \
                ! remove_managed_archlinuxcn_repo "$pacman_conf"; then
                echo "archlinuxcn 密钥环安装失败，且Renkit配置移除失败。"
                return 1
            fi
            echo "- archlinuxcn 密钥环本次未启用，已撤销并跳过；将继续配置 Flatpak 国内缓存。"
            return 0
        fi
    fi

    if populate_output="$(toolbox_sudo pacman-key --populate archlinuxcn 2>&1)"; then
        [ -z "$populate_output" ] || log "archlinuxcn 密钥导入明细: ${populate_output//$'\n'/；}"
        echo "✓ archlinuxcn 密钥环可用，已保持软件包 GPG 验证。"
        return 0
    fi
    [ -z "$populate_output" ] || log "archlinuxcn 密钥导入未完成: ${populate_output//$'\n'/；}"

    if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf" 2>/dev/null && \
        ! remove_managed_archlinuxcn_repo "$pacman_conf"; then
        echo "archlinuxcn 密钥导入失败，且Renkit配置移除失败。"
        return 1
    fi
    echo "- archlinuxcn 密钥本次未启用，已撤销并跳过；将继续配置 Flatpak 国内缓存。"
    return 0
}

restore_official_flatpak() {
    local repo_file

    require_supported_gaming_os || return 1
    require_command flatpak || return 1
    require_command timeout || return 1
    require_command curl || return 1
    confirm_official_flatpak_restore || {
        echo "已取消恢复官方 Flatpak 源，未修改任何远程源。"
        return 1
    }

    repo_file="$(mktemp)" || return 1
    if ! download_official_flathub_repo_file "$repo_file"; then
        rm -f -- "$repo_file"
        return 1
    fi

    if ! flatpak_remote_exists flathub; then
        timeout --foreground 30 flatpak remote-add --user --if-not-exists --from \
            flathub "$repo_file" || {
            rm -f -- "$repo_file"
            return 1
        }
    fi
    rm -f -- "$repo_file"

    if ! timeout --foreground 30 flatpak remote-modify --user --gpg-verify \
        --url=https://dl.flathub.org/repo/ flathub; then
        echo "恢复 Flathub 官方地址和 GPG 验证失败。"
        return 1
    fi
    if flatpak_remote_exists "$FLATHUB_CN_REMOTE" && \
        ! timeout --foreground 30 flatpak remote-delete --user --force \
            "$FLATHUB_CN_REMOTE"; then
        echo "官方源已恢复，但移除 $FLATHUB_CN_REMOTE 失败。"
        return 1
    fi
    if flatpak_remote_exists "$FLATHUB_CN_FALLBACK_REMOTE" && \
        ! timeout --foreground 30 flatpak remote-delete --user --force \
            "$FLATHUB_CN_FALLBACK_REMOTE"; then
        echo "官方源已恢复，但移除 $FLATHUB_CN_FALLBACK_REMOTE 失败。"
        return 1
    fi
    if [ "$IS_STEAMOS" -eq 1 ]; then
        if flatpak_system_remote_exists "$FLATHUB_CN_REMOTE" && \
            ! toolbox_sudo timeout --foreground 30 flatpak remote-delete --system --force \
                "$FLATHUB_CN_REMOTE"; then
            echo "官方源已恢复，但移除系统级 $FLATHUB_CN_REMOTE 失败。"
            return 1
        fi
        if flatpak_system_remote_exists "$FLATHUB_CN_FALLBACK_REMOTE" && \
            ! toolbox_sudo timeout --foreground 30 flatpak remote-delete --system --force \
                "$FLATHUB_CN_FALLBACK_REMOTE"; then
            echo "官方源已恢复，但移除系统级 $FLATHUB_CN_FALLBACK_REMOTE 失败。"
            return 1
        fi
    fi

    if [ "$IS_STEAMOS" -eq 1 ] && \
        grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" /etc/pacman.conf 2>/dev/null; then
        require_command steamos-readonly || return 1
        require_command install || return 1
        if ! toolbox_sudo steamos-readonly disable; then
            echo "无法临时关闭 SteamOS 只读保护，archlinuxcn 配置尚未移除。"
            return 1
        fi
        if ! remove_managed_archlinuxcn_repo /etc/pacman.conf; then
            toolbox_sudo steamos-readonly enable >/dev/null 2>&1 || true
            echo "移除 archlinuxcn 配置失败，已尝试恢复只读保护。"
            return 1
        fi
        if ! toolbox_sudo steamos-readonly enable; then
            echo "软件源已恢复，但 SteamOS 只读保护恢复失败。"
            return 1
        fi
    fi

    if [ "$IS_STEAMOS" -eq 1 ]; then
        echo "已恢复 Flathub 官方源并启用 GPG 验证，同时移除Renkit管理的 archlinuxcn 配置。"
        log "已恢复Flathub官方源并移除国内缓存源和Renkit管理的archlinuxcn配置"
    else
        echo "已恢复 Bazzite 官方 Flathub 并启用 GPG 验证；系统更新源保持不变。"
        log "Bazzite已恢复官方Flathub并移除国内缓存源"
    fi
}

# SteamOS 的 pacman 有时会为已被系统裁剪的可选文件反复输出“无法获取文件信息”。
# 这些只是元数据统计警告，不代表安装失败；保留所有其他输出和真实退出码。
run_pacman_without_metadata_warnings() {
    local pacman_status

    # pacman 只有在标准输出或错误输出连接终端时才会显示真实的下载百分比和速度。
    # 不要在交互式更新中把它接到 sed 管道，否则用户只能看到“正在获取软件包”。
    # 自动测试和重定向日志仍走下面的过滤分支，保留原有无害元数据警告的隐藏规则。
    if [ "${ZHOUKEER_FORCE_PACMAN_PROGRESS:-0}" = "1" ] || \
        { [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && { [ -t 1 ] || [ -t 2 ]; }; }; then
        echo "正在使用 pacman 原生下载进度（百分比和速度）..."
        toolbox_sudo pacman "$@"
        return $?
    fi

    toolbox_sudo pacman "$@" 2>&1 | sed -u -E \
        -e '/warning: could not get file information for /d' \
        -e '/警告：无法获取 .* 的文件信息/d'
    pacman_status="${PIPESTATUS[0]}"
    return "$pacman_status"
}

restore_discover_packagekit_backend() {
    if [ -e "$DISCOVER_PACKAGEKIT_BACKEND" ]; then
        return 0
    fi
    if [ -L "$DISCOVER_PACKAGEKIT_BACKEND_DISABLED" ]; then
        echo "Discover 后端备份是符号链接，Renkit不会自动恢复：$DISCOVER_PACKAGEKIT_BACKEND_DISABLED"
        return 1
    fi
    if [ -f "$DISCOVER_PACKAGEKIT_BACKEND_DISABLED" ]; then
        echo "检测到被停用的 Discover PackageKit 后端，正在恢复..."
        toolbox_sudo mv -- "$DISCOVER_PACKAGEKIT_BACKEND_DISABLED" \
            "$DISCOVER_PACKAGEKIT_BACKEND" || return 1
    fi
}

run_discover_refresh_worker() {
    local launch_log="$LOG_DIR/discover-start.log"
    local refresh_failed=0

    require_command flatpak || return 1
    require_command timeout || return 1

    echo "[3/3] 修复 Discover 用户仓库并刷新应用索引..."
    pkill -x plasma-discover >/dev/null 2>&1 || true
    if ! timeout 90 flatpak repair --user; then
        echo "Flatpak 用户仓库修复失败或超时，将继续重建应用索引。"
        refresh_failed=1
    fi
    if ! timeout 120 flatpak update --user --appstream --noninteractive; then
        echo "Flatpak 应用索引刷新失败或超时，将继续重建 KDE 缓存。"
        refresh_failed=1
    fi

    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental || refresh_failed=1
    elif command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 --noincremental || refresh_failed=1
    else
        echo "缺少 KDE 缓存重建命令，将直接尝试启动 Discover。"
        refresh_failed=1
    fi

    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ]; then
        echo "Discover 应用商店修复模拟完成。"
        return "$refresh_failed"
    fi
    require_command plasma-discover || return 1
    mkdir -p "$LOG_DIR" || return 1
    nohup plasma-discover > "$launch_log" 2>&1 &
    sleep 3
    if command -v pgrep >/dev/null 2>&1 && ! pgrep -x plasma-discover >/dev/null 2>&1; then
        echo "Discover 启动失败，最近日志："
        tail -n 12 "$launch_log" 2>/dev/null || true
        return 1
    fi
    echo "Discover 已修复并重新启动。"
    return "$refresh_failed"
}

refresh_discover_after_source_setup() {
    local refresh_log="$LOG_DIR/discover-refresh.log"

    if [ "${ZHOUKEER_DISCOVER_DEFER:-0}" = "1" ]; then
        echo "Discover 用户仓库与应用索引将在新机初始化结束时后台修复。"
        return 0
    fi

    if [ "${ZHOUKEER_DISCOVER_BACKGROUND:-0}" = "1" ] && \
        [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        mkdir -p "$LOG_DIR" || return 1
        (run_discover_refresh_worker) </dev/null > "$refresh_log" 2>&1 &
        echo "Discover 用户仓库与应用索引已转入后台修复，不阻塞新机初始化。"
        echo "后台日志：$refresh_log"
        return 0
    fi
    run_discover_refresh_worker
}

prepare_system_packages() (
    local pacman_conf="${1:-/etc/pacman.conf}"
    local locale_gen="${2:-/etc/locale.gen}"
    local readonly_disabled=0
    local readonly_status=""
    local configuration_complete=0
    local pacman_backup=""
    local locale_backup=""

    cleanup_system_source_setup() {
        if [ "$configuration_complete" -ne 1 ]; then
            if [ -n "$pacman_backup" ] && [ -f "$pacman_backup" ]; then
                toolbox_sudo install -m 0644 -- "$pacman_backup" \
                    "$pacman_conf" >/dev/null 2>&1 || true
            fi
            if [ -n "$locale_backup" ] && [ -f "$locale_backup" ]; then
                toolbox_sudo install -m 0644 -- "$locale_backup" \
                    "$locale_gen" >/dev/null 2>&1 || true
            fi
        fi
        [ -z "$pacman_backup" ] || rm -f -- "$pacman_backup"
        [ -z "$locale_backup" ] || rm -f -- "$locale_backup"
        if [ "$readonly_disabled" -eq 1 ]; then
            toolbox_sudo steamos-readonly enable >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_system_source_setup EXIT
    trap 'exit 130' INT TERM

    for command_name in steamos-readonly pacman pacman-key awk grep install sed \
        locale-gen mktemp; do
        require_command "$command_name" || return 1
    done

    if [ ! -f "$pacman_conf" ] || [ -L "$pacman_conf" ] || \
        [ ! -f "$locale_gen" ] || [ -L "$locale_gen" ]; then
        echo "pacman 或 locale 配置文件异常，未修改系统。"
        return 1
    fi
    pacman_backup="$(mktemp)" || return 1
    locale_backup="$(mktemp)" || return 1
    cp -- "$pacman_conf" "$pacman_backup" || return 1
    cp -- "$locale_gen" "$locale_backup" || return 1

    echo "[1/3] 初始化 pacman 密钥环并完整更新系统组件..."
    readonly_status="$(steamos-readonly status 2>/dev/null || true)"
    if printf '%s' "$readonly_status" | grep -qi 'enabled'; then
        toolbox_sudo steamos-readonly disable >/dev/null 2>&1 || return 1
        readonly_disabled=1
    elif ! printf '%s' "$readonly_status" | grep -qi 'disabled'; then
        toolbox_sudo steamos-readonly disable >/dev/null 2>&1 || return 1
        readonly_disabled=1
    else
        log "SteamOS rootfs 已处于可写状态，本次保持原状态"
    fi

    if ! toolbox_sudo pacman-key --init; then
        echo "pacman 密钥环初始化失败，已停止。"
        return 1
    fi
    if ! toolbox_sudo pacman-key --populate archlinux; then
        echo "Arch Linux 系统密钥导入失败，已停止。"
        return 1
    fi
    if ! toolbox_sudo pacman-key --populate holo; then
        echo "SteamOS（holo）系统密钥导入失败，已停止。"
        return 1
    fi

    configure_archlinuxcn_with_fallback "$pacman_conf" || return 1

    if ! run_pacman_without_metadata_warnings -Syyu --noconfirm; then
        echo "系统组件完整更新失败，已停止。"
        return 1
    fi
    if ! run_pacman_without_metadata_warnings -S --needed --noconfirm git flatpak; then
        echo "git 或 Flatpak 组件补齐失败，已停止。"
        return 1
    fi
    if ! run_pacman_without_metadata_warnings -S --noconfirm archlinux-keyring; then
        echo "archlinux-keyring 重装失败，已停止。"
        return 1
    fi
    if pacman_conf_has_archlinuxcn "$pacman_conf" 2>/dev/null && \
        ! run_pacman_without_metadata_warnings -S --noconfirm archlinuxcn-keyring; then
        echo "archlinuxcn-keyring 重装失败，已停止。"
        return 1
    fi
    if ! run_pacman_without_metadata_warnings -Syyu --noconfirm; then
        echo "密钥环修复后的复查更新失败，已停止。"
        return 1
    fi
    if ! restore_discover_packagekit_backend; then
        echo "恢复 Discover PackageKit 后端失败，已停止。"
        return 1
    fi
    if ! run_pacman_without_metadata_warnings -S --noconfirm \
        discover packagekit packagekit-qt6; then
        echo "Discover 系统组件同步重装失败，已停止。"
        return 1
    fi

    if ! configure_chinese_locales "$locale_gen"; then
        echo "中英文 locale 配置失败，已停止。"
        return 1
    fi

    if [ "$readonly_disabled" -eq 1 ]; then
        if ! toolbox_sudo steamos-readonly enable; then
            echo "系统组件已更新，但恢复 SteamOS 只读保护失败。"
            return 1
        fi
        readonly_disabled=0
    fi
    configuration_complete=1
)

initialize_software_sources() {
    require_steamos || return 1

    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ] && \
        ! bash "$PROJECT_ROOT/modules/preflight.sh" system-update; then
        echo "初始化已停止：准备检查未通过，没有修改系统。"
        return 1
    fi

    echo "================================================"
    echo " 初始化国内源并检测系统组件"
    echo "================================================"
    echo "将完整更新系统组件、配置 archlinuxcn 镜像回退和密钥环、生成中英文 locale，并修复 Discover 与 Flatpak 应用索引。"
    echo "可恢复：修改前会在本次临时目录备份 pacman 与语言配置；菜单提供“恢复官方软件源”。"
    echo "管理员权限会读取桌面管理员密码.txt，不会重复询问密码。"

    prepare_system_packages || return 1
    configure_domestic_flatpak || return 1
    refresh_discover_after_source_setup || return 1

    echo ""
    echo "国内源、系统组件与 Discover 应用商店初始化完成。现在可以继续安装软件。"
    if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" /etc/pacman.conf 2>/dev/null; then
        echo "Arch Linux CN：上海交大 → 中科大 → 官方源（GPG 密钥环已启用）"
    else
        echo "Arch Linux CN：本次未启用；Flatpak 国内缓存已继续配置"
    fi
    if [ "${DOMESTIC_FLATPAK_SKIPPED:-0}" = "1" ]; then
        echo "Flatpak 国内缓存：本次已跳过，继续使用原有软件源"
    else
        echo "上海交大：$FLATHUB_CN_URL"
        echo "中科大：$FLATHUB_CN_FALLBACK_URL"
    fi
    log "国内源与系统组件初始化完成：已同步重装Discover组件、刷新AppStream、处理archlinuxcn密钥环、配置中文locale和Flatpak国内双缓存"
}

show_software_source_status() {
    require_command flatpak || return 1
    detect_platform
    if [ "$IS_STEAMOS" -eq 1 ]; then
        if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" /etc/pacman.conf 2>/dev/null; then
            echo "pacman 国内仓库：archlinuxcn｜$ARCHLINUXCN_REPO_URL（Renkit管理）"
        elif pacman_conf_has_archlinuxcn /etc/pacman.conf 2>/dev/null; then
            echo "pacman 国内仓库：检测到用户已有 archlinuxcn 配置（Renkit不覆盖）"
        else
            echo "pacman 国内仓库：未配置 archlinuxcn"
        fi
    elif [ "$IS_BAZZITE" -eq 1 ]; then
        echo "Bazzite 系统更新源：保持官方配置（Renkit不修改）"
    fi
    echo "用户级 Flatpak 下载源："
    flatpak remotes --user --show-details 2>/dev/null || \
        flatpak remotes --user 2>/dev/null || true
    echo "系统级 Flatpak 下载源："
    flatpak remotes --system --show-details 2>/dev/null || \
        flatpak remotes --system 2>/dev/null || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-init}" in
        init|init-domestic) initialize_software_sources ;;
        enable) configure_domestic_flatpak ;;
        restore) restore_official_flatpak ;;
        status) show_software_source_status ;;
        refresh-discover) require_steamos && refresh_discover_after_source_setup ;;
        *) echo "用法: $0 {init|enable|restore|status|refresh-discover}"; exit 1 ;;
    esac
fi
