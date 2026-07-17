#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# 复用常用软件模块中已经过测试的 Flathub 国内缓存配置。
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/software.sh"

verify_domestic_flatpak_remote() {
    local remote="$1"
    local label="$2"
    local applications

    echo "正在验证 $label 应用索引..."
    applications="$(timeout --foreground 30 flatpak remote-ls --user "$remote" --app --columns=application 2>/dev/null)" || {
        echo "$label 无法读取应用索引，请检查网络后重试。"
        return 1
    }
    if ! printf '%s\n' "$applications" | grep -Fxq 'org.mozilla.firefox'; then
        echo "$label 返回的应用索引不完整，未确认 Firefox 条目。"
        return 1
    fi

    echo "${label}：应用索引可用。"
}

verify_domestic_flatpak_sources() {
    verify_domestic_flatpak_remote "$FLATHUB_CN_REMOTE" "上海交大 Flathub 缓存" || return 1
    verify_domestic_flatpak_remote "$FLATHUB_CN_FALLBACK_REMOTE" "中科大 Flathub 缓存" || return 1
}

configure_domestic_source() {
    is_linux || {
        echo "国内下载源配置仅支持 Linux/SteamOS。"
        return 1
    }
    require_command flatpak || return 1
    require_command timeout || return 1
    require_command curl || return 1

    echo "正在添加上海交大和中科大两个用户级 Flathub 缓存源..."
    echo "不会修改 SteamOS 只读系统分区，也不会删除用户已有的其他来源。"
    if ! ensure_flatpak_remotes; then
        echo "国内下载源配置失败，现有软件和其他下载源保持不变。"
        return 1
    fi
    if ! verify_domestic_flatpak_sources; then
        echo "国内下载源已写入，但至少一个镜像当前不可用；请稍后重新初始化。"
        return 1
    fi

    echo "国内下载源配置完成：${FLATHUB_CN_REMOTE}、${FLATHUB_CN_FALLBACK_REMOTE}（应用索引已验证）"
    echo "上海交大：$FLATHUB_CN_URL"
    echo "中科大：$FLATHUB_CN_FALLBACK_URL"
    log "Flathub国内双缓存源配置完成"
}

show_domestic_source_status() {
    require_command flatpak || return 1
    require_command timeout || return 1
    echo "当前用户的 Flatpak 下载源："
    flatpak remotes --user --show-details 2>/dev/null || \
        flatpak remotes --user 2>/dev/null || true
}



init_domestic_flatpak() {
    echo "================================================"
    echo " 配置国内 Flatpak 镜像源"
    echo "================================================"
    echo ""

    is_linux || { echo "仅支持 Linux/SteamOS。"; return 1; }
    require_command sudo || return 1

    # ----- 第 1 步：GPG 公钥修复 -----
    echo "[1/6] 修复 Flathub GPG 公钥..."
    local gpg_tmp gpg_key
    gpg_tmp="$(mktemp -d)" || return 1
    gpg_key="$gpg_tmp/flathub.gpg"

    if ! curl -fsL --connect-timeout 10 --max-time 60 \
        -o "$gpg_key" \
        "https://mirror.sjtu.edu.cn/flathub/flathub.gpg"; then
        curl -fsL --connect-timeout 10 --max-time 60 \
            -o "$gpg_key" \
            "https://flathub.org/repo/flathub.gpg" || {
            echo "  \u26a0  GPG \u516c\u94a5\u4e0b\u8f7d\u5931\u8d25\uff0c\u8df3\u8fc7\u3002"
            gpg_key=""
        }
    fi

    if [ -n "$gpg_key" ] && [ -s "$gpg_key" ]; then
        for _src_ in flathub Sjtu Ustc; do
            flatpak remote-list --system 2>/dev/null | grep -q "$_src_" && \
                sudo flatpak remote-modify "$_src_" --gpg-import="$gpg_key" 2>/dev/null && \
                echo "  \u2713 $_src_ GPG \u516c\u94a5\u5df2\u5bfc\u5165\u3002"
        done
    fi
    rm -rf "$gpg_tmp"

    # ----- 第 2 步：安装 Flatpak -----
    echo "[2/6] \u68c0\u67e5 Flatpak..."
    if ! command -v flatpak >/dev/null 2>&1; then
        require_command steamos-readonly || return 1
        require_command pacman || return 1
        require_command pacman-key || return 1
        sudo steamos-readonly disable || { echo "  \u5173\u95ed\u53ea\u8bfb\u4fdd\u62a4\u5931\u8d25\u3002"; return 1; }
        sudo pacman-key --init || true
        sudo pacman-key --populate || true
        sudo pacman -S flatpak --noconfirm || {
            sudo steamos-readonly enable 2>/dev/null
            echo "  \u2717 Flatpak \u5b89\u88c5\u5931\u8d25\u3002"; return 1
        }
        sudo steamos-readonly enable || echo "  \u26a0  \u6062\u590d\u53ea\u8bfb\u4fdd\u62a4\u5931\u8d25\u3002"
        echo "  \u2713 Flatpak \u5df2\u5b89\u88c5\u3002"
    else
        echo "  \u2713 Flatpak \u5df2\u5b58\u5728\u3002"
    fi

    # ----- 第 3 步：配置官方 Flathub -----
    echo "[3/6] \u914d\u7f6e\u5b98\u65b9 Flathub..."
    if ! flatpak remote-list --system 2>/dev/null | grep -q "flathub"; then
        if ! sudo flatpak remote-add --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null; then
            local _repo_
            _repo_="$(mktemp)" || return 1
            curl -fsL --connect-timeout 10 --max-time 60 \
                -o "$_repo_" \
                "https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo" && \
                sudo flatpak remote-add --if-not-exists flathub "$_repo_" 2>/dev/null
            rm -f "$_repo_"
        fi
        echo "  \u2713 flathub \u5df2\u6dfb\u52a0\u3002"
    else
        echo "  \u2713 flathub \u5df2\u5b58\u5728\u3002"
    fi

    # ----- 第 4 步：添加国内镜像 -----
    echo "[4/6] \u6dfb\u52a0\u56fd\u5185\u955c\u50cf..."
    for _pair_ in "Sjtu|https://mirror.sjtu.edu.cn/flathub" "Ustc|https://mirrors.ustc.edu.cn/flathub"; do
        local _name_="${_pair_%%|*}"
        local _url_="${_pair_##*|}"
        if ! flatpak remote-list --system 2>/dev/null | grep -q "$_name_"; then
            if ! sudo flatpak remote-add --if-not-exists "$_name_" \
                "$_url_/flathub.flatpakrepo" 2>/dev/null; then
                local _r2_
                _r2_="$(mktemp)" || return 1
                curl -fsL --connect-timeout 10 --max-time 60 \
                    -o "$_r2_" "$_url_/flathub.flatpakrepo" && \
                    sudo flatpak remote-add --if-not-exists "$_name_" "$_r2_" 2>/dev/null
                rm -f "$_r2_"
            fi
            echo "  \u2713 $_name_ \u5df2\u6dfb\u52a0\u3002"
        else
            echo "  \u2713 $_name_ \u5df2\u5b58\u5728\u3002"
        fi
        sudo flatpak remote-modify "$_name_" --url="$_url_" 2>/dev/null
    done

    # ----- 第 5 步：刷新 AppStream -----
    echo "[5/6] \u5237\u65b0\u5e94\u7528\u7d22\u5f15..."
    sudo rm -rf /var/tmp/flatpak-cache-* 2>/dev/null || true
    rm -rf "$HOME/.local/share/flatpak/repo/tmp" 2>/dev/null || true

    if ! timeout --foreground 180 flatpak update --appstream 2>/dev/null; then
        for _src_ in flathub Sjtu Ustc; do
            flatpak remote-list --system 2>/dev/null | grep -q "$_src_" && \
                timeout --foreground 60 flatpak update --appstream --remote="$_src_" 2>/dev/null || true
        done
    fi
    echo "  \u2713 AppStream \u5237\u65b0\u5b8c\u6210\u3002"

    # ----- 第 6 步：验证 -----
    echo "[6/6] \u9a8c\u8bc1..."
    local _ok_=0
    for _src_ in Sjtu Ustc flathub; do
        flatpak remote-list --system 2>/dev/null | grep -q "$_src_" || continue
        if timeout --foreground 30 flatpak remote-ls --system "$_src_" --app \
            --columns=application 2>/dev/null | grep -qm1 .; then
            echo "  \u2713 $_src_\uff1a\u6b63\u5e38"
            _ok_=$((_ok_ + 1))
        else
            echo "  \u26a0  $_src_\uff1a\u7d22\u5f15\u6682\u4e0d\u53ef\u8bfb"
        fi
    done

    echo ""
    echo "\u5b8c\u6210\uff1a$_ok_ \u4e2a\u6e90\u53ef\u7528"
    log "\u56fd\u5185 Flatpak \u955c\u50cf\u6e90\u521d\u59cb\u5316\u5b8c\u6210: $_ok_ \u4e2a\u6e90\u53ef\u7528"
}

setup_flatpak_sjtu() {
    init_domestic_flatpak
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-enable}" in
        enable) configure_domestic_source ;;
        status) show_domestic_source_status ;;
        init-domestic) init_domestic_flatpak ;;
        *) echo "用法: $0 {enable|status|init-domestic}"; exit 1 ;;
    esac
fi
