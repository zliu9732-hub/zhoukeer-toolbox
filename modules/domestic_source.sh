#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
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

    # ----- 第 1 步: 下载并导入 Flathub GPG 公钥 -----
    echo "[1/6] 下载并导入 Flathub GPG 公钥..."
    local gpg_tmp gpg_key
    gpg_tmp="$(mktemp -d)" || return 1
    gpg_key="$gpg_tmp/flathub.gpg"

    if curl -fsL --connect-timeout 10 --max-time 60 -o "$gpg_key"         "https://mirror.sjtu.edu.cn/flathub/flathub.gpg"; then
        echo "  - 从交大镜像下载 GPG 成功"
    elif curl -fsL --connect-timeout 10 --max-time 60 -o "$gpg_key"         "https://flathub.org/repo/flathub.gpg"; then
        echo "  - 从官方源下载 GPG 成功"
    else
        echo "  - GPG 公钥下载失败，跳过导入"
        gpg_key=""
    fi

    if [ -n "$gpg_key" ] && [ -s "$gpg_key" ]; then
        for _src_ in flathub Sjtu Ustc; do
            if flatpak remote-list --system 2>/dev/null | grep -q "$_src_"; then
                sudo flatpak remote-modify "$_src_" --gpg-import="$gpg_key" 2>/dev/null &&                     echo "  - $_src_ GPG 已导入" ||                     echo "  - $_src_ GPG 导入失败"
            fi
        done
    fi
    rm -rf "$gpg_tmp"

    # ----- 第 2 步: 安装 Flatpak(如缺失) -----
    echo "[2/6] 检查 Flatpak..."
    if ! command -v flatpak >/dev/null 2>&1; then
        require_command steamos-readonly || return 1
        require_command pacman || return 1
        require_command pacman-key || return 1
        sudo steamos-readonly disable || { echo "  - 关闭只读保护失败"; return 1; }
        sudo pacman-key --init || true
        sudo pacman-key --populate || true
        sudo pacman -S flatpak --noconfirm || {
            sudo steamos-readonly enable 2>/dev/null
            echo "  - Flatpak 安装失败"; return 1
        }
        sudo steamos-readonly enable || echo "  - 恢复只读保护失败"
        echo "  - Flatpak 已安装"
    else
        echo "  - Flatpak 已存在"
    fi

    # ----- 第 3 步: 配置官方 Flathub -----
    echo "[3/6] 配置官方 Flathub..."
    if ! flatpak remote-list --system 2>/dev/null | grep -q "flathub"; then
        if ! sudo flatpak remote-add --if-not-exists flathub             https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null; then
            local _repo_
            _repo_="$(mktemp)" || return 1
            curl -fsL --connect-timeout 10 --max-time 60                 -o "$_repo_"                 "https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo" &&                 sudo flatpak remote-add --if-not-exists flathub "$_repo_" 2>/dev/null
            rm -f "$_repo_"
        fi
        echo "  - flathub 已添加"
    else
        echo "  - flathub 已存在"
    fi

    # ----- 第 4 步: 添加国内镜像(关闭 GPG 校验)-----
    echo "[4/6] 添加国内镜像..."
    for _pair_ in "Sjtu|https://mirror.sjtu.edu.cn/flathub" "Ustc|https://mirrors.ustc.edu.cn/flathub"; do
        local _name_="${_pair_%%|*}"
        local _url_="${_pair_##*|}"
        if ! flatpak remote-list --system 2>/dev/null | grep -q "$_name_"; then
            if ! sudo flatpak remote-add --if-not-exists "$_name_"                 "$_url_/flathub.flatpakrepo" 2>/dev/null; then
                local _r2_
                _r2_="$(mktemp)" || return 1
                curl -fsL --connect-timeout 10 --max-time 60                     -o "$_r2_" "$_url_/flathub.flatpakrepo" &&                     sudo flatpak remote-add --if-not-exists "$_name_" "$_r2_" 2>/dev/null
                rm -f "$_r2_"
            fi
            echo "  - $_name_ 已添加"
        else
            echo "  - $_name_ 已存在"
        fi
        sudo flatpak remote-modify "$_name_" --url="$_url_" 2>/dev/null
        # 国内镜像使用 --no-gpg-verify 绕过签名问题
        sudo flatpak remote-modify --no-gpg-verify "$_name_" 2>/dev/null &&             echo "  - $_name_ 已关闭 GPG 校验"
    done
    # 同时添加用户级国内源（供 flatpak install --user 使用）
    for _ul_pair_ in "$FLATHUB_CN_REMOTE|$FLATHUB_CN_URL" "$FLATHUB_CN_FALLBACK_REMOTE|$FLATHUB_CN_FALLBACK_URL"; do
        local _ul_name_="${_ul_pair_%%|*}"
        local _ul_url_="${_ul_pair_##*|}"
        if ! flatpak remote-list --user 2>/dev/null | grep -q "$_ul_name_"; then
            flatpak remote-add --user --if-not-exists "$_ul_name_" "$_ul_url_/flathub.flatpakrepo" 2>/dev/null &&                 echo "  - $_ul_name_ (用户级) 已添加"
        fi
        flatpak remote-modify --user "$_ul_name_" --url="$_ul_url_" 2>/dev/null
        flatpak remote-modify --no-gpg-verify --user "$_ul_name_" 2>/dev/null &&             echo "  - $_ul_name_ (用户级) 已关闭 GPG 校验"
    done

    # ----- 第 5 步: 刷新 AppStream -----
    echo "[5/6] 刷新应用索引..."
    sudo rm -rf /var/tmp/flatpak-cache-* 2>/dev/null || true
    rm -rf "$HOME/.local/share/flatpak/repo/tmp" 2>/dev/null || true

    if ! timeout --foreground 180 flatpak update --appstream 2>/dev/null; then
        for _src_ in flathub Sjtu Ustc; do
            flatpak remote-list --system 2>/dev/null | grep -q "$_src_" &&                 timeout --foreground 60 flatpak update --appstream --remote="$_src_" 2>/dev/null || true
        done
    fi
    echo "  - AppStream 刷新完成"

    # ----- 第 6 步: 验证 -----
    echo "[6/6] 验证..."
    local _ok_=0
    for _src_ in Sjtu Ustc flathub; do
        flatpak remote-list --system 2>/dev/null | grep -q "$_src_" || continue
        if timeout --foreground 30 flatpak remote-ls --system "$_src_" --app             --columns=application 2>/dev/null | grep -qm1 .; then
            echo "  - $_src_: 正常"
            _ok_=$((_ok_ + 1))
        else
            echo "  - $_src_: 索引暂不可读"
        fi
    done

    echo ""
    echo "完成: $_ok_ 个源可用"
    log "国内 Flatpak 镜像源初始化完成: $_ok_ 个源可用"
}
setup_flatpak_sjtu() {
    init_domestic_flatpak
}

flatpak_mirror_delete() {
    echo "  - 删除 SJTU 镜像源"
    sudo flatpak remote-delete Sjtu 2>/dev/null &&         echo "  - Sjtu 已删除" || echo "  - Sjtu 不存在"
}

flatpak_mirror_reset() {
    echo "  - 重置官方 Flathub 源"
    sudo flatpak remote-modify flathub --url=https://flathub.org/repo &&         echo "  - flathub 已重置" || echo "  - 重置失败"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-enable}" in
        enable) configure_domestic_source ;;
        status) show_domestic_source_status ;;
        init-domestic) init_domestic_flatpak ;;
        mirror-delete) flatpak_mirror_delete ;;
        mirror-reset) flatpak_mirror_reset ;;
        *) echo "用法: $0 {enable|status|init-domestic|mirror-delete|mirror-reset}"; exit 1 ;;
    esac
fi
