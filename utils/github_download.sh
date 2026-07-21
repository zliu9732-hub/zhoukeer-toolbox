#!/bin/bash

# =========================================================
# GitHub 统一下载模块
# 提供统一的 GitHub 文件下载，自动检测最快镜像源并回退。
# =========================================================

# 仅在首次加载时初始化
if [ -n "${GITHUB_DOWNLOAD_LOADED:-}" ]; then
    return 0
fi
GITHUB_DOWNLOAD_LOADED=1

# 加载镜像源配置
_load_github_mirror_config() {
    local conf_file="$PROJECT_ROOT/config/github_mirror.conf"
    if [ -f "$conf_file" ]; then
        # shellcheck disable=SC1090
        source "$conf_file"
    fi
    : "${github_enable:=true}"
    : "${mirror_1:=https://github.com}"
    : "${mirror_2:=https://gitclone.com/github.com/}"
    : "${mirror_3:=https://ghproxy.vip/https://github.com/}"
    : "${mirror_4:=https://ghp.ci/https://github.com/}"
}

# 收集所有启用镜像到 _GITHUB_SOURCES 数组
_GITHUB_SOURCES=()
_github_mirrors_loaded=0
_load_github_sources() {
    [ "$_github_mirrors_loaded" -eq 1 ] && return 0
    _load_github_mirror_config
    _GITHUB_SOURCES=()
    [ "$github_enable" != "true" ] && return 0
    for _i in 1 2 3 4 5 6 7 8 9; do
        eval "_val=\"\$mirror_${_i}\""
        [ -n "$_val" ] && _GITHUB_SOURCES+=("$_val")
    done
    _github_mirrors_loaded=1
}

# 解析 GitHub URL 到镜像地址
# 参数：原始 URL、镜像前缀
# 输出：解析后的完整 URL
_resolve_github_url() {
    local url="$1"
    local mirror="$2"
    
    # 官方源直接返回原始 URL
    case "$mirror" in
        https://github.com|https://github.com/|http://github.com|http://github.com/)
            printf '%s' "$url"
            return 0
            ;;
    esac
    
    # 镜像：替换 github.com 域名为镜像地址
    # 处理 https://github.com/... 格式
    case "$url" in
        https://github.com/*)
            printf '%s%s' "$mirror" "${url#https://github.com/}"
            return 0
            ;;
        https://raw.githubusercontent.com/*)
            # raw 地址转换为 github.com 格式再拼接
            local _gh_path="${url#https://raw.githubusercontent.com/}"
            printf '%s%s' "$mirror" "$_gh_path"
            return 0
            ;;
        http://github.com/*)
            printf '%s%s' "$mirror" "${url#http://github.com/}"
            return 0
            ;;
        http://raw.githubusercontent.com/*)
            local _gh_path="${url#http://raw.githubusercontent.com/}"
            printf '%s%s' "$mirror" "$_gh_path"
            return 0
            ;;
    esac
    
    # 非 GitHub URL 原样返回
    printf '%s' "$url"
}

# 测速单个源
# 参数：镜像地址
# 输出：响应时间（秒），失败输出 999
_github_source_speed() {
    local mirror="$1"
    local test_url
    local speed
    
    case "$mirror" in
        */) test_url="${mirror}zliu9732-hub/zhoukeer-toolbox/raw/main/VERSION" ;;
        *) test_url="${mirror}/zliu9732-hub/zhoukeer-toolbox/raw/main/VERSION" ;;
    esac
    
    speed=$(curl -o /dev/null -s -w '%{time_total}' \
        --connect-timeout 3 --max-time 5 \
        "$test_url" 2>/dev/null || echo "999")
    printf '%s' "$speed"
}

# 获取按响应时间排序的镜像列表
# 输出：最快的镜像地址在前，空格分隔
# 缓存结果，避免重复测速
_GITHUB_SOURCES_RANKED=""
_github_sources_ranked_loaded=0
get_ranked_github_sources() {
    [ "$_github_sources_ranked_loaded" -eq 1 ] && { printf '%s' "$_GITHUB_SOURCES_RANKED"; return 0; }
    
    _load_github_sources
    [ ${#_GITHUB_SOURCES[@]} -eq 0 ] && return 0
    
    local tmpfile
    tmpfile="$(mktemp 2>/dev/null)" || return 1
    local _mirror speed
    
    for _mirror in "${_GITHUB_SOURCES[@]}"; do
        speed="$(_github_source_speed "$_mirror")"
        printf '%s|%s\n' "$speed" "$_mirror" >> "$tmpfile"
    done
    
    _GITHUB_SOURCES_RANKED="$(sort -t'|' -k1 -n "$tmpfile" | cut -d'|' -f2 | tr '\n' ' ')"
    rm -f "$tmpfile"
    _github_sources_ranked_loaded=1
    
    printf '%s' "$_GITHUB_SOURCES_RANKED"
}

# 通用的 GitHub 文件下载函数
# 参数：
#   $1 - GitHub URL（支持 github.com 和 raw.githubusercontent.com）
#   $2 - 本地输出路径
#   $3 - 期望 SHA256（可选，留空不校验）
#   $4 - 显示名称（可选）
# 返回值：
#   0 - 下载成功
#   1 - 所有源均失败
download_github_file() {
    local url="$1"
    local output="$2"
    local expected_sha256="${3:-}"
    local name="${4:-GitHub文件}"
    local resolved_url source_index=0
    
    # 检查 URL 是否为 GitHub 地址
    case "$url" in
        *github.com/*|*raw.githubusercontent.com/*) ;;
        *)
            # 非 GitHub 地址，直接下载
            if curl -fL --connect-timeout 15 --max-time 600 -o "$output" "$url" 2>/dev/null; then
                return 0
            fi
            return 1
            ;;
    esac
    
    echo "正在从 GitHub 下载 $name..."
    
    local ranked_sources
    ranked_sources="$(get_ranked_github_sources)" || true
    
    # 按优先级尝试所有源
    local _source _sources_fallback=""
    for _source in $ranked_sources "https://github.com"; do
        source_index=$((source_index + 1))
        
        resolved_url="$(_resolve_github_url "$url" "$_source")"
        [ -z "$resolved_url" ] && continue
        
        echo "  尝试第 ${source_index} 个源..."
        if curl -fL --connect-timeout 15 --max-time 600 \
            --show-error --progress-bar \
            -o "$output" "$resolved_url" 2>/dev/null; then
            
            # SHA256 校验
            if [ -n "$expected_sha256" ]; then
                local actual_sha256
                if command -v sha256sum >/dev/null 2>&1; then
                    actual_sha256="$(sha256sum "$output" | awk '{print $1}')"
                elif command -v shasum >/dev/null 2>&1; then
                    actual_sha256="$(shasum -a 256 "$output" | awk '{print $1}')"
                else
                    echo "$name 下载校验不可用。"
                    return 0
                fi
                if [ "$actual_sha256" != "$expected_sha256" ]; then
                    rm -f -- "$output"
                    echo "$name SHA256 校验失败，尝试下一源。"
                    continue
                fi
                echo "$name 下载完成并通过校验。"
            else
                echo "$name 下载完成。"
            fi
            
            # 记录日志
            log "GitHub 下载成功: $name"
            return 0
        fi
        
        _sources_fallback="${_sources_fallback}  - $_source\n"
    done
    
    # 所有源均失败
    echo ""
    echo "========== GitHub 下载失败 =========="
    echo "资源：$name"
    echo "尝试过的下载源："
    printf '%b' "$_sources_fallback"
    echo "可能的原因：网络连接不稳定，或 GitHub 暂时不可用。"
    echo "请检查网络连接，稍后重试。"
    echo "如持续下载缓慢或失败，请在工具箱【系统设置 · 密码 → 安装 Steam302】中开启 GitHub 加速。"
    echo "日志位置：$LOG_DIR/toolbox.log"
    echo "======================================"
    
    log "GitHub 下载失败: $name - 所有源均不可用"
    return 1
}

# 下载 GitHub Release 资源
# 参数：仓库、标签、资源名、输出路径
download_github_release() {
    local repo="$1"
    local tag="$2"
    local asset="$3"
    local output="$4"
    local expected_sha256="${5:-}"
    local name="${6:-${asset}}"
    
    download_github_file \
        "https://github.com/${repo}/releases/download/${tag}/${asset}" \
        "$output" \
        "$expected_sha256" \
        "Release $name"
}

# 下载 GitHub Raw 文件
# 参数：仓库、分支、路径、输出路径
download_github_raw() {
    local repo="$1"
    local branch="$2"
    local path="$3"
    local output="$4"
    local name="${5:-${path##*/}}"
    
    download_github_file \
        "https://raw.githubusercontent.com/${repo}/${branch}/${path}" \
        "$output" \
        "" \
        "Raw $name"
}
