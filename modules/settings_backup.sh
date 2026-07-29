#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

SETTINGS_BACKUP_FORMAT=1
SETTINGS_BACKUP_OUTPUT_DIR="${ZHOUKEER_SETTINGS_BACKUP_DIR:-$HOME/Desktop}"
SETTINGS_BACKUP_TMP_DIR=""
SETTINGS_PACMAN_CONF="${ZHOUKEER_PACMAN_CONF:-/etc/pacman.conf}"
SETTINGS_MEMORY_ZRAM="${ZHOUKEER_ZRAM_CONFIG:-/etc/systemd/zram-generator.conf.d/90-zhoukeer.conf}"
SETTINGS_MEMORY_SYSCTL="${ZHOUKEER_MEMORY_SYSCTL_CONFIG:-/etc/sysctl.d/90-zhoukeer-memory.conf}"
SETTINGS_MEMORY_SYSTEMD_DIR="${ZHOUKEER_SYSTEMD_DIR:-/etc/systemd/system}"
SETTINGS_STEAM302_CONFIG="${ZHOUKEER_STEAM302_CONFIG:-$APP_DIR/steamcommunity302/S302.ini}"

settings_backup_cleanup() {
    [ -z "$SETTINGS_BACKUP_TMP_DIR" ] || rm -rf -- "$SETTINGS_BACKUP_TMP_DIR"
}

settings_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    else
        shasum -a 256 -- "$1" | awk '{print $1}'
    fi
}

settings_filter_config() {
    local input="$1" output="$2" line key
    : > "$output"
    [ -f "$input" ] && [ ! -L "$input" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|'#'*) continue ;; esac
        key="${line%%=*}"
        config_key_is_allowed "$key" || continue
        case "$key" in GITHUB_DOWNLOAD_PROXY|DECKY_DOWNLOAD_PROXY) continue ;; esac
        config_value_is_safe "${line#*=}" || continue
        printf '%s\n' "$line" >> "$output"
    done < "$input"
}

settings_copy_regular() {
    local source="$1" destination="$2"
    [ -f "$source" ] && [ ! -L "$source" ] || return 0
    mkdir -p -- "$(dirname "$destination")" || return 1
    cp -- "$source" "$destination"
}

settings_copy_managed() {
    local source="$1" destination="$2"
    [ -f "$source" ] && [ ! -L "$source" ] || return 0
    grep -Fq '# Managed by Zhoukeer Toolbox' "$source" 2>/dev/null || return 0
    settings_copy_regular "$source" "$destination"
}

settings_backup_shortcuts() {
    local destination="$1" base file name
    local -a bases=("$HOME/Desktop" "$HOME/.local/share/applications")
    for base in "${bases[@]}"; do
        [ -d "$base" ] || continue
        for file in "$base"/*.desktop; do
            [ -f "$file" ] && [ ! -L "$file" ] || continue
            name="${file##*/}"
            if grep -Fqx 'X-Zhoukeer-Managed=true' "$file" 2>/dev/null || \
               [ "$name" = "周克儿工具箱.desktop" ] || [ "$name" = "zhoukeer-toolbox.desktop" ]; then
                mkdir -p -- "$destination/$(basename "$base")" || return 1
                cp -- "$file" "$destination/$(basename "$base")/$name" || return 1
            fi
        done
    done
}

settings_backup_sources() {
    local output="$1"
    : > "$output"
    if grep -Fqx '# BEGIN ZHOUKEER ARCHLINUXCN' "$SETTINGS_PACMAN_CONF" 2>/dev/null; then
        echo 'archlinuxcn=present' >> "$output"
    else
        echo 'archlinuxcn=absent' >> "$output"
    fi
    for remote in flathub-cn flathub-ustc; do
        if command -v flatpak >/dev/null 2>&1 && flatpak remote-list --user --columns=name 2>/dev/null | grep -Fxq "$remote"; then
            printf '%s=present\n' "$remote" >> "$output"
        else
            printf '%s=absent\n' "$remote" >> "$output"
        fi
    done
}

settings_backup_steam302() {
    local output="$1" enabled
    [ -f "$SETTINGS_STEAM302_CONFIG" ] && [ ! -L "$SETTINGS_STEAM302_CONFIG" ] || return 0
    enabled="$(awk '
        /^\[Rules\][[:space:]]*$/ { in_rules=1; next }
        /^\[/ { in_rules=0 }
        in_rules && /^[[:space:]]*enabled[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/, ""); print; exit }
    ' "$SETTINGS_STEAM302_CONFIG")"
    case "$enabled" in *[!A-Za-z0-9_,.-]*|'') return 0 ;; esac
    printf 'enabled=%s\n' "$enabled" > "$output"
}

create_settings_backup() {
    local quiet="${1:-0}" stamp root archive version
    mkdir -p -- "$SETTINGS_BACKUP_OUTPUT_DIR" || return 1
    SETTINGS_BACKUP_TMP_DIR="$(mktemp -d)" || return 1
    trap settings_backup_cleanup EXIT INT TERM
    root="$SETTINGS_BACKUP_TMP_DIR/zhoukeer-settings"
    mkdir -m 0700 -p -- "$root/config" "$root/sources" "$root/memory" "$root/shortcuts" "$root/steam302" || return 1
    version="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION" 2>/dev/null || echo 未知)"
    printf 'format=%s\nversion=%s\ncreated=%s\n' \
        "$SETTINGS_BACKUP_FORMAT" "$version" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$root/manifest"
    settings_filter_config "$CONFIG_FILE" "$root/config/settings.conf" || return 1
    settings_backup_sources "$root/sources/managed.state" || return 1
    settings_backup_steam302 "$root/steam302/rules.state" || return 1
    settings_copy_managed "$SETTINGS_MEMORY_ZRAM" "$root/memory/zram.conf" || return 1
    settings_copy_managed "$SETTINGS_MEMORY_SYSCTL" "$root/memory/sysctl.conf" || return 1
    if [ -d "$SETTINGS_MEMORY_SYSTEMD_DIR" ]; then
        local unit
        for unit in "$SETTINGS_MEMORY_SYSTEMD_DIR"/*.swap; do
            [ -f "$unit" ] && grep -Fq '# Managed by Zhoukeer Toolbox' "$unit" 2>/dev/null || continue
            settings_copy_regular "$unit" "$root/memory/$(basename "$unit")" || return 1
        done
    fi
    settings_backup_shortcuts "$root/shortcuts" || return 1
    find "$root" -type f -exec chmod 0600 {} + || return 1
    stamp="$(date '+%Y%m%d-%H%M%S')"
    if [ "$quiet" = "1" ]; then
        archive="$SETTINGS_BACKUP_OUTPUT_DIR/周克儿工具箱设置备份-$stamp-恢复前-$$.tar.gz"
    else
        archive="$SETTINGS_BACKUP_OUTPUT_DIR/周克儿工具箱设置备份-$stamp.tar.gz"
    fi
    tar -czf "$archive" -C "$SETTINGS_BACKUP_TMP_DIR" zhoukeer-settings || return 1
    chmod 0600 "$archive" || { rm -f -- "$archive"; return 1; }
    settings_sha256 "$archive" > "$archive.sha256" || { rm -f -- "$archive"; return 1; }
    chmod 0600 "$archive.sha256" || return 1
    [ "$quiet" = "1" ] || {
        echo "工具箱设置已备份。"
        echo "备份文件：$archive"
        echo "只包含工具箱明确管理的设置，不包含游戏、存档、Steam 账号数据或整个 HOME。"
    }
    log "已创建工具箱设置备份"
    printf '%s\n' "$archive"
    settings_backup_cleanup
    trap - EXIT INT TERM
}

settings_archive_safe() {
    local archive="$1" entry verbose
    while IFS= read -r entry; do
        case "$entry" in
            zhoukeer-settings|zhoukeer-settings/*) ;;
            *) return 1 ;;
        esac
        case "$entry" in /*|../*|*/../*|*/..) return 1 ;; esac
    done < <(tar -tzf "$archive")
    verbose="$(tar -tvzf "$archive")" || return 1
    ! printf '%s\n' "$verbose" | awk '$1 ~ /^[lh]/ { bad=1 } END { exit(bad ? 0 : 1) }'
}

settings_verify_archive() {
    local archive="$1" sidecar="$archive.sha256" expected actual
    [ -f "$archive" ] && [ ! -L "$archive" ] && [ -f "$sidecar" ] && [ ! -L "$sidecar" ] || return 1
    expected="$(awk 'NR == 1 { print $1 }' "$sidecar")"
    case "$expected" in ''|*[!0-9A-Fa-f]* ) return 1 ;; esac
    [ "${#expected}" -eq 64 ] || return 1
    actual="$(settings_sha256 "$archive")" || return 1
    [ "$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')" = "$actual" ] || return 1
    settings_archive_safe "$archive"
}

settings_restore_config() {
    local source="$1" tmp
    [ -s "$source" ] || return 0
    tmp="$(mktemp "$(dirname "$CONFIG_FILE")/.settings.conf.XXXXXX")" || return 1
    settings_filter_config "$source" "$tmp" || { rm -f -- "$tmp"; return 1; }
    chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$CONFIG_FILE"
}

settings_restore_shortcuts() {
    local source_root="$1" sub file target_dir tmp
    for sub in Desktop applications; do
        [ -d "$source_root/$sub" ] || continue
        case "$sub" in Desktop) target_dir="$HOME/Desktop" ;; applications) target_dir="$HOME/.local/share/applications" ;; esac
        mkdir -p -- "$target_dir" || return 1
        for file in "$source_root/$sub"/*.desktop; do
            [ -f "$file" ] && [ ! -L "$file" ] || continue
            if ! grep -Fqx 'X-Zhoukeer-Managed=true' "$file" 2>/dev/null; then
                case "${file##*/}" in 周克儿工具箱.desktop|zhoukeer-toolbox.desktop) ;; *) return 1 ;; esac
            fi
            tmp="$(mktemp "$target_dir/.zhoukeer-shortcut.XXXXXX")" || return 1
            sed "s#${ZHOUKEER_BACKUP_OLD_HOME:-$HOME}#$HOME#g" "$file" > "$tmp" || { rm -f -- "$tmp"; return 1; }
            chmod 0755 "$tmp" || { rm -f -- "$tmp"; return 1; }
            mv -f -- "$tmp" "$target_dir/${file##*/}" || return 1
        done
    done
}

settings_restore_memory() {
    local root="$1" file target
    [ -d "$root" ] || return 0
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        require_steamos || return 1
    fi
    toolbox_sudo true || return 1
    for file in "$root"/*; do
        [ -f "$file" ] && [ ! -L "$file" ] || continue
        grep -Fq '# Managed by Zhoukeer Toolbox' "$file" || return 1
        case "${file##*/}" in
            zram.conf) target="$SETTINGS_MEMORY_ZRAM" ;;
            sysctl.conf) target="$SETTINGS_MEMORY_SYSCTL" ;;
            *.swap) target="$SETTINGS_MEMORY_SYSTEMD_DIR/${file##*/}" ;;
            *) return 1 ;;
        esac
        toolbox_sudo install -d -m 0755 -- "$(dirname "$target")" || return 1
        toolbox_sudo install -m 0644 -- "$file" "$target" || return 1
    done
}

settings_restore_sources() {
    local state_file="$1" readonly_disabled=0 arch_desired="" arch_current="absent"
    local remote desired current
    [ -f "$state_file" ] || return 0
    [ "$(wc -l < "$state_file" | tr -d ' ')" = "3" ] || return 1
    grep -Fxq 'archlinuxcn=present' "$state_file" || grep -Fxq 'archlinuxcn=absent' "$state_file" || return 1
    grep -Fxq 'flathub-cn=present' "$state_file" || grep -Fxq 'flathub-cn=absent' "$state_file" || return 1
    grep -Fxq 'flathub-ustc=present' "$state_file" || grep -Fxq 'flathub-ustc=absent' "$state_file" || return 1
    if grep -Fqx '# BEGIN ZHOUKEER ARCHLINUXCN' "$SETTINGS_PACMAN_CONF" 2>/dev/null; then
        arch_current="present"
    fi
    arch_desired="$(sed -n 's/^archlinuxcn=//p' "$state_file" | head -n 1)"
    if [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        require_steamos || return 1
    fi
    if command -v flatpak >/dev/null 2>&1; then
        for remote in flathub-cn flathub-ustc; do
            desired="$(sed -n "s/^$remote=//p" "$state_file" | head -n 1)"
            current="absent"
            flatpak remote-list --user --columns=name 2>/dev/null | grep -Fxq "$remote" && current="present"
            [ "$desired" = "$current" ] && continue
            if [ "$desired" = "present" ]; then
                case "$remote" in
                    flathub-cn) flatpak remote-add --user --if-not-exists --no-gpg-verify flathub-cn https://mirror.sjtu.edu.cn/flathub || return 1 ;;
                    flathub-ustc) flatpak remote-add --user --if-not-exists --no-gpg-verify flathub-ustc https://mirrors.ustc.edu.cn/flathub || return 1 ;;
                esac
            else
                flatpak remote-delete --user --force "$remote" || return 1
            fi
        done
    elif grep -Eq '^flathub-(cn|ustc)=present$' "$state_file"; then
        return 1
    fi
    if [ "$arch_desired" != "$arch_current" ]; then
        # shellcheck disable=SC1091
        source "$PROJECT_ROOT/modules/domestic_source.sh"
        toolbox_sudo steamos-readonly disable || return 1
        readonly_disabled=1
        if [ "$arch_desired" = "present" ]; then
            write_managed_archlinuxcn_repo "$SETTINGS_PACMAN_CONF"
        elif [ "$arch_desired" = "absent" ]; then
            remove_managed_archlinuxcn_repo "$SETTINGS_PACMAN_CONF"
        else
            false
        fi || {
            toolbox_sudo steamos-readonly enable >/dev/null 2>&1 || true
            return 1
        }
        toolbox_sudo steamos-readonly enable || return 1
        readonly_disabled=0
    fi
    [ "$readonly_disabled" -eq 0 ] || toolbox_sudo steamos-readonly enable >/dev/null 2>&1 || true
}

settings_restore_steam302() {
    local state_file="$1" enabled item tmp
    [ -f "$state_file" ] || return 0
    [ -f "$SETTINGS_STEAM302_CONFIG" ] && [ ! -L "$SETTINGS_STEAM302_CONFIG" ] || return 0
    [ "$(wc -l < "$state_file" | tr -d ' ')" = "1" ] || return 1
    enabled="$(sed -n 's/^enabled=//p' "$state_file")"
    case "$enabled" in ''|*[!A-Za-z0-9_,.-]*) return 1 ;; esac
    while IFS= read -r item; do
        case ",$item," in
            ,Steam_store,|,Steam_store_unlock,|,Steam_community,|,Steam_API,|,Steam_API_unlock,|,Steam_community_unlock,|,steamchat,|,steamchat_unlock,|,Steam_cloud_google,|,steam_update,|,Steam_broadcast_redir,|,Steam_broadcast_redir_unlock,|,imgfix,|,imgfix_fastly,|,github,) ;;
            *) return 1 ;;
        esac
    done < <(printf '%s\n' "$enabled" | tr ',' '\n')
    tmp="$(mktemp "$(dirname "$SETTINGS_STEAM302_CONFIG")/.S302.ini.XXXXXX")" || return 1
    if ! awk -v enabled="$enabled" '
        BEGIN { in_rules=0; replaced=0 }
        /^\[Rules\][[:space:]]*$/ { in_rules=1 }
        /^\[/ && $0 !~ /^\[Rules\][[:space:]]*$/ { in_rules=0 }
        in_rules && /^[[:space:]]*enabled[[:space:]]*=/ {
            if (!replaced) { print "enabled = " enabled; replaced=1 }
            next
        }
        { print }
        END { if (!replaced) exit 1 }
    ' "$SETTINGS_STEAM302_CONFIG" > "$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    chmod 0644 "$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$SETTINGS_STEAM302_CONFIG"
}

restore_settings_backup() {
    local archive="${1:-}" expected_archive extracted root answer rollback restore_tmp
    [ -n "$archive" ] || {
        archive="$(find "$SETTINGS_BACKUP_OUTPUT_DIR" -maxdepth 1 -type f -name '周克儿工具箱设置备份-*.tar.gz' -print 2>/dev/null | sort | tail -n 1)"
    }
    [ -n "$archive" ] || { echo "未找到工具箱设置备份。"; return 1; }
    settings_verify_archive "$archive" || { echo "备份文件校验失败或结构不安全，已拒绝恢复。"; return 1; }
    SETTINGS_BACKUP_TMP_DIR="$(mktemp -d)" || return 1
    trap settings_backup_cleanup EXIT INT TERM
    extracted="$SETTINGS_BACKUP_TMP_DIR/extracted"
    mkdir -p -- "$extracted" || return 1
    tar --no-same-owner --no-same-permissions -xzf "$archive" -C "$extracted" || return 1
    root="$extracted/zhoukeer-settings"
    grep -Fxq "format=$SETTINGS_BACKUP_FORMAT" "$root/manifest" || { echo "备份格式不受支持。"; return 1; }

    echo "将恢复以下工具箱管理内容："
    [ ! -s "$root/config/settings.conf" ] || echo "- 工具箱配置（不含代理认证）"
    [ ! -s "$root/sources/managed.state" ] || echo "- 工具箱管理的国内源状态；Flatpak 国内缓存会关闭 GPG 验证"
    [ ! -s "$root/steam302/rules.state" ] || echo "- Steam302 的工具箱规则"
    [ ! -d "$root/memory" ] || echo "- 工具箱管理的内存参数（不包含 swap 文件本体）"
    [ ! -d "$root/shortcuts" ] || echo "- 工具箱创建的快捷方式"
    echo "远程名称：flathub-cn｜https://mirror.sjtu.edu.cn/flathub"
    echo "备用名称：flathub-ustc｜https://mirrors.ustc.edu.cn/flathub"
    echo "不会覆盖游戏、存档、Steam 账号数据、整个 HOME 或非工具箱管理的系统配置。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        read -r -p "确认恢复请输入 RESTORE：" answer
        [ "$answer" = "RESTORE" ] || { echo "已取消恢复，没有修改设置。"; return 0; }
    fi

    if [ "${SETTINGS_RESTORE_ROLLBACK_MODE:-0}" = "1" ]; then
        rollback=""
    else
        restore_tmp="$SETTINGS_BACKUP_TMP_DIR"
        rollback="$(create_settings_backup 1 | tail -n 1)" || { echo "无法先备份当前状态，已停止恢复。"; return 1; }
        SETTINGS_BACKUP_TMP_DIR="$restore_tmp"
        trap settings_backup_cleanup EXIT INT TERM
        echo "当前状态已先备份到：$rollback"
    fi
    settings_restore_config "$root/config/settings.conf" && \
        settings_restore_shortcuts "$root/shortcuts" && \
        settings_restore_sources "$root/sources/managed.state" && \
        settings_restore_memory "$root/memory" && \
        settings_restore_steam302 "$root/steam302/rules.state" || {
            if [ -n "$rollback" ] && ZHOUKEER_AUTO_CONFIRM=1 SETTINGS_RESTORE_ROLLBACK_MODE=1 \
                restore_settings_backup "$rollback" >/dev/null 2>&1; then
                echo "恢复未完成，已自动回到恢复前状态。"
            else
                echo "恢复未完成，无法自动回滚。恢复前备份：${rollback:-不可用}"
                echo "建议生成诊断包发给维护人员。"
            fi
            log "工具箱设置恢复失败，已保留恢复前备份"
            return 1
        }
    echo "工具箱设置恢复完成。恢复前备份：$rollback"
    log "工具箱设置恢复完成"
    settings_backup_cleanup
    trap - EXIT INT TERM
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        backup) create_settings_backup ;;
        restore) restore_settings_backup "${2:-}" ;;
        *) echo "用法: $0 {backup|restore [备份文件]}"; exit 1 ;;
    esac
fi
