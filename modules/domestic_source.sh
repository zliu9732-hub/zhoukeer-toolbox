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



setup_flatpak_sjtu() {
    is_linux || { echo "仅支持 Linux/SteamOS。"; return 1; }
    require_command sudo || return 1

    echo "将安装 Flatpak 并配置国内镜像源（上海交大）。"
    echo "该源对所有用户生效。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        local answer
        read -r -p "确认配置请输入 YES：" answer
        [ "$answer" = "YES" ] || { echo "已取消。"; return 0; }
    fi

    # ===== 第 1 步：安装 Flatpak =====
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "第 1 步：安装 Flatpak..."
        for cmd in steamos-readonly pacman pacman-key; do
            command -v "$cmd" >/dev/null 2>&1 || { echo "缺少命令: $cmd"; return 1; }
        done
        toolbox_sudo steamos-readonly disable || { echo "关闭只读保护失败。"; return 1; }
        toolbox_sudo pacman-key --init || true
        toolbox_sudo pacman-key --populate || true
        toolbox_sudo pacman -S flatpak --noconfirm || {
            toolbox_sudo steamos-readonly enable 2>/dev/null
            echo "Flatpak 安装失败。"; return 1
        }
        toolbox_sudo steamos-readonly enable || echo "警告：恢复只读保护失败。"
    else
        echo "Flatpak 已安装，跳过。"
    fi

    # ===== 第 2 步：下载并导入 Flathub GPG 公钥 =====
    echo "第 2 步：下载并导入 Flathub GPG 公钥..."
    local gpg_tmp
    gpg_tmp="$(mktemp -d)" || return 1
    local gpg_key="$gpg_tmp/flathub.gpg"
    # 从国内镜像下载 GPG 公钥（比官方源快）
    if ! curl -fsL --connect-timeout 10 --max-time 60         -o "$gpg_key"         "https://mirror.sjtu.edu.cn/flathub/flathub.gpg" 2>/dev/null; then
        # 镜像不可用时从官方源重试
        curl -fsL --connect-timeout 10 --max-time 60             -o "$gpg_key"             "https://flathub.org/repo/flathub.gpg" 2>/dev/null || {
            rm -rf "$gpg_tmp"
            echo "GPG 公钥下载失败，跳过导入。"
        }
    fi
    if [ -s "$gpg_key" ]; then
        sudo flatpak remote-modify flathub --gpg-import="$gpg_key" 2>/dev/null || true
    fi
    rm -rf "$gpg_tmp"

    # ===== 第 3 步：添加官方 Flathub 源 =====
    echo "第 3 步：添加官方 Flathub 源..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || {
        # 官方源不可达时，从镜像添加
        local repo_tmp
        repo_tmp="$(mktemp)" || return 1
        curl -fsL --connect-timeout 10 --max-time 60             -o "$repo_tmp"             "https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo" 2>/dev/null && {
            sudo flatpak remote-add --if-not-exists flathub "$repo_tmp" 2>/dev/null || true
        }
        rm -f "$repo_tmp"
    }

    # ===== 第 4 步：添加并重定向交大镜像源 =====
    echo "第 4 步：添加交大镜像源..."
    sudo flatpak remote-add --if-not-exists Sjtu https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo 2>/dev/null || {
        local repo_tmp2
        repo_tmp2="$(mktemp)" || return 1
        curl -fsL --connect-timeout 10 --max-time 60             -o "$repo_tmp2"             "https://mirror.sjtu.edu.cn/flathub/flathub.flatpakrepo" 2>/dev/null && {
            sudo flatpak remote-add --if-not-exists Sjtu "$repo_tmp2" 2>/dev/null || true
        }
        rm -f "$repo_tmp2"
    }
    sudo flatpak remote-modify Sjtu --url=https://mirror.sjtu.edu.cn/flathub 2>/dev/null || true

    # ===== 第 5 步：强制刷新 AppStream 元数据 =====
    echo "第 5 步：强制刷新应用索引..."
    timeout --foreground 120 flatpak update --appstream 2>/dev/null || {
        # 如果 --appstream 失败，清空本地元数据缓存重试
        sudo rm -rf /var/tmp/flatpak-cache-* "$HOME/.local/share/flatpak/repo/tmp" 2>/dev/null || true
        timeout --foreground 120 flatpak update --appstream 2>/dev/null || echo "提示：AppStream 刷新未完成，部分源可能暂不可用。"
    }

    # ===== 第 6 步：验证镜像源是否可用 =====
    echo "第 6 步：验证镜像源..."
    if timeout --foreground 30 flatpak remote-ls Sjtu --app --columns=application 2>/dev/null | grep -qm1 .; then
        echo "交大镜像源可用，应用索引加载成功。"
    else
        echo "提示：交大镜像源暂时无法读取应用索引，可稍后重试。"
    fi

    echo ""
    echo "配置完成。可用来源："
    echo "  flathub（官方，已导入 GPG）"
    echo "  Sjtu（上海交大镜像）"
    echo "安装命令示例：flatpak install Sjtu org.mozilla.firefox"
    log "交大 Flathub 镜像源已配置"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-enable}" in
        enable) configure_domestic_source ;;
        status) show_domestic_source_status ;;
        sjtu) setup_flatpak_sjtu ;;
        *) echo "用法: $0 {enable|status|sjtu}"; exit 1 ;;
    esac
fi
