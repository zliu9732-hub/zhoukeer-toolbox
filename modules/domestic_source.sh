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

ARCHLINUXCN_REPO_URL="https://mirrors.ustc.edu.cn/archlinuxcn/\$arch"
ARCHLINUXCN_BLOCK_BEGIN="# BEGIN ZHOUKEER ARCHLINUXCN"
ARCHLINUXCN_BLOCK_END="# END ZHOUKEER ARCHLINUXCN"

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
    printf '\n%s\n[archlinuxcn]\nServer = %s\n%s\n' \
        "$ARCHLINUXCN_BLOCK_BEGIN" "$ARCHLINUXCN_REPO_URL" \
        "$ARCHLINUXCN_BLOCK_END" >> "$tmp_file"

    if ! toolbox_sudo install -m 0644 -- "$tmp_file" "$pacman_conf"; then
        rm -f -- "$tmp_file"
        echo "写入 archlinuxcn 国内仓库失败。"
        return 1
    fi
    rm -f -- "$tmp_file"
    echo "已配置 archlinuxcn：$ARCHLINUXCN_REPO_URL"
}

remove_managed_archlinuxcn_repo() {
    local pacman_conf="${1:-/etc/pacman.conf}"
    local tmp_file

    [ -f "$pacman_conf" ] && [ ! -L "$pacman_conf" ] || return 1
    if ! grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf"; then
        echo "未发现工具箱管理的 archlinuxcn 配置，无需移除。"
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
    echo "已移除工具箱管理的 archlinuxcn 配置。"
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
    require_steamos || return 1
    require_command flatpak || return 1
    require_command timeout || return 1

    echo "[2/2] 配置上海交大和中科大 Flatpak 国内缓存..."
    if ! ensure_flatpak_remotes; then
        echo "Flatpak 国内缓存配置失败，现有软件和其他来源保持不变。"
        return 1
    fi

    echo "国内下载源配置完成：${FLATHUB_CN_REMOTE}、${FLATHUB_CN_FALLBACK_REMOTE}。"
}

packages_installed_without_known_upgrades() {
    local package_name pending_upgrades

    pacman -Q "$@" >/dev/null 2>&1 || return 1
    pending_upgrades="$(pacman -Qu 2>/dev/null)" || return 1
    for package_name in "$@"; do
        if printf '%s\n' "$pending_upgrades" | awk -v package="$package_name" \
            '$1 == package { found=1 } END { exit(found ? 0 : 1) }'; then
            return 1
        fi
    done
    return 0
}

base_system_components_ready() {
    packages_installed_without_known_upgrades git flatpak archlinux-keyring
}

archlinuxcn_keyring_ready() {
    packages_installed_without_known_upgrades archlinuxcn-keyring
}

configure_archlinuxcn_if_ready() {
    local pacman_conf="${1:-/etc/pacman.conf}"

    if ! archlinuxcn_keyring_ready; then
        if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf" 2>/dev/null && \
            ! remove_managed_archlinuxcn_repo "$pacman_conf"; then
            echo "archlinuxcn 密钥环不可用，且工具箱旧配置移除失败。"
            return 1
        fi
        echo "- 未检测到可直接使用的 archlinuxcn 密钥环，已跳过；不影响 Flatpak 软件安装。"
        return 0
    fi

    if ! write_managed_archlinuxcn_repo "$pacman_conf"; then
        echo "- archlinuxcn 仓库配置失败，已跳过；不影响 Flatpak 软件安装。"
        return 0
    fi
    if toolbox_sudo pacman-key --populate archlinuxcn; then
        echo "✓ archlinuxcn 密钥环可用，已保持软件包 GPG 验证。"
        return 0
    fi

    if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" "$pacman_conf" 2>/dev/null && \
        ! remove_managed_archlinuxcn_repo "$pacman_conf"; then
        echo "archlinuxcn 密钥导入失败，且工具箱配置移除失败。"
        return 1
    fi
    echo "- archlinuxcn 密钥导入失败，已安全跳过；不影响 Flatpak 软件安装。"
    return 0
}

restore_official_flatpak() {
    local repo_file

    require_steamos || return 1
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

    if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" /etc/pacman.conf 2>/dev/null; then
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

    echo "已恢复 Flathub 官方源并启用 GPG 验证，同时移除工具箱管理的 archlinuxcn 配置。"
    log "已恢复Flathub官方源并移除国内缓存源和工具箱管理的archlinuxcn配置"
}

prepare_system_packages() (
    local readonly_disabled=0
    local configuration_complete=0
    local pacman_backup=""
    local locale_backup=""

    cleanup_system_source_setup() {
        if [ "$configuration_complete" -ne 1 ]; then
            if [ -n "$pacman_backup" ] && [ -f "$pacman_backup" ]; then
                toolbox_sudo install -m 0644 -- "$pacman_backup" \
                    /etc/pacman.conf >/dev/null 2>&1 || true
            fi
            if [ -n "$locale_backup" ] && [ -f "$locale_backup" ]; then
                toolbox_sudo install -m 0644 -- "$locale_backup" \
                    /etc/locale.gen >/dev/null 2>&1 || true
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

    for command_name in steamos-readonly pacman pacman-key awk grep install \
        locale-gen mktemp; do
        require_command "$command_name" || return 1
    done

    if [ ! -f /etc/pacman.conf ] || [ -L /etc/pacman.conf ] || \
        [ ! -f /etc/locale.gen ] || [ -L /etc/locale.gen ]; then
        echo "pacman 或 locale 配置文件异常，未修改系统。"
        return 1
    fi
    pacman_backup="$(mktemp)" || return 1
    locale_backup="$(mktemp)" || return 1
    cp -- /etc/pacman.conf "$pacman_backup" || return 1
    cp -- /etc/locale.gen "$locale_backup" || return 1

    echo "[1/2] 检测 pacman/archlinuxcn 密钥环与系统组件..."
    toolbox_sudo steamos-readonly disable || return 1
    readonly_disabled=1

    if base_system_components_ready; then
        echo "✓ 已检测到 git、Flatpak 和系统密钥环均已安装，无需更新系统组件。"
    else
        echo "检测到基础组件不完整，正在初始化系统密钥环并补齐组件..."
        if ! toolbox_sudo pacman-key --init; then
            echo "pacman 密钥环初始化失败，已停止。"
            return 1
        fi
        if ! toolbox_sudo pacman-key --populate archlinux; then
            echo "Arch Linux 系统密钥导入失败，已停止。"
            return 1
        fi
        if ! toolbox_sudo pacman -Syu --needed --noconfirm git flatpak; then
            echo "git 或 Flatpak 组件补齐失败，已停止。"
            return 1
        fi
        if ! toolbox_sudo pacman -S --needed --noconfirm archlinux-keyring; then
            echo "Arch Linux 系统密钥环安装失败，已停止。"
            return 1
        fi
    fi

    configure_archlinuxcn_if_ready /etc/pacman.conf || return 1
    if ! configure_chinese_locales /etc/locale.gen; then
        echo "中英文 locale 配置失败，已停止。"
        return 1
    fi

    if ! toolbox_sudo steamos-readonly enable; then
        echo "系统组件已更新，但恢复 SteamOS 只读保护失败。"
        return 1
    fi
    readonly_disabled=0
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
    echo "将检测系统组件、生成中英文 locale，并配置 Flatpak 国内缓存；已有可用密钥环时兼容 archlinuxcn。"
    echo "可恢复：修改前会在本次临时目录备份 pacman 与语言配置；菜单提供“恢复官方软件源”。"
    echo "管理员权限会读取桌面管理员密码.txt，不会重复询问密码。"

    prepare_system_packages || return 1
    configure_domestic_flatpak || return 1

    echo ""
    echo "国内源与系统组件初始化完成。现在可以正常使用工具箱安装软件。"
    if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" /etc/pacman.conf 2>/dev/null; then
        echo "Arch Linux CN：$ARCHLINUXCN_REPO_URL（GPG 密钥环已启用）"
    else
        echo "Arch Linux CN：未启用（不影响 Flatpak 软件安装）"
    fi
    echo "上海交大：$FLATHUB_CN_URL"
    echo "中科大：$FLATHUB_CN_FALLBACK_URL"
    log "国内源与系统组件初始化完成：已检测系统组件、配置中文locale和Flatpak国内双缓存"
}

show_software_source_status() {
    require_command flatpak || return 1
    if grep -Fqx "$ARCHLINUXCN_BLOCK_BEGIN" /etc/pacman.conf 2>/dev/null; then
        echo "pacman 国内仓库：archlinuxcn｜$ARCHLINUXCN_REPO_URL（工具箱管理）"
    elif pacman_conf_has_archlinuxcn /etc/pacman.conf 2>/dev/null; then
        echo "pacman 国内仓库：检测到用户已有 archlinuxcn 配置（工具箱不覆盖）"
    else
        echo "pacman 国内仓库：未配置 archlinuxcn"
    fi
    echo "当前用户的 Flatpak 下载源："
    flatpak remotes --user --show-details 2>/dev/null || \
        flatpak remotes --user 2>/dev/null || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-init}" in
        init|init-domestic) initialize_software_sources ;;
        enable) configure_domestic_flatpak ;;
        restore) restore_official_flatpak ;;
        status) show_software_source_status ;;
        *) echo "用法: $0 {init|enable|restore|status}"; exit 1 ;;
    esac
fi
