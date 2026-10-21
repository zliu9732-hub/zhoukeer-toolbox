#!/bin/bash

# Called after plugin_store.sh has loaded its normal download/extraction helpers.
FRAMEGEN_CATALOG_URL="https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-4/raw/main/framegen-auto/catalog.json"
FRAMEGEN_CATALOG_CACHE="$APP_DIR/plugin-updates/framegen/catalog.json"

load_framegen_cached_versions() {
    local kind version package_sha frontend_sha rows
    [ -f "$FRAMEGEN_CATALOG_CACHE" ] && [ ! -L "$FRAMEGEN_CATALOG_CACHE" ] || return 0
    rows="$(python3 "$PROJECT_ROOT/scripts/framegen_package.py" versions --catalog "$FRAMEGEN_CATALOG_CACHE" 2>/dev/null)" || return 0
    while IFS=$'\t' read -r kind version package_sha frontend_sha; do
        case "$kind" in
            lsfg-v2) LSFG_V2_VERSION="$version"; LSFG_V2_PACKAGE_SHA256="$package_sha"; LSFG_V2_INDEX_SHA256="$frontend_sha" ;;
            fsr4) FSR4_OFFICIAL_VERSION="$version"; FSR4_ZH_PACKAGE_SHA256="$package_sha"; FSR4_ZH_INDEX_SHA256="$frontend_sha" ;;
        esac
    done <<< "$rows"
}

framegen_auto_is_current() {
    local kind="$1" root="$2" directory
    case "$kind" in lsfg-v2) directory="Decky LSFG-VK" ;; fsr4) directory="Decky-Framegen" ;; *) return 1 ;; esac
    [ -f "$FRAMEGEN_CATALOG_CACHE" ] && [ ! -L "$FRAMEGEN_CATALOG_CACHE" ] || return 1
    python3 "$PROJECT_ROOT/scripts/framegen_package.py" check --catalog "$FRAMEGEN_CATALOG_CACHE" \
        --kind "$kind" --root "$root/$directory" >/dev/null 2>&1
}

refresh_framegen_catalog() (
    local tmp cache_tmp="" cache_dir
    [ "${IS_STEAMOS:-0}" -eq 1 ] || return 1
    tmp="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$tmp"; [ -z "$cache_tmp" ] || rm -f -- "$cache_tmp"' EXIT
    if ! GITHUB_QUIET=1 GITHUB_CONNECT_TIMEOUT=5 GITHUB_MAX_TIME=20 GITHUB_RETRIES=1 GITHUB_MIN_SPEED_TIME=10 \
        download_github_file "$FRAMEGEN_CATALOG_URL" "$tmp/catalog.json" '' '插件版本信息' > "$tmp/download.log" 2>&1; then
        { [ ! -L "$FRAMEGEN_CATALOG_CACHE" ] && cp -- "$FRAMEGEN_CATALOG_CACHE" "$tmp/catalog.json" 2>/dev/null; } || \
            cp -- "$PROJECT_ROOT/data/framegen_auto_baseline.json" "$tmp/catalog.json" || return 1
    fi
    # A same-version language repair is newer too. The bundled verified catalog
    # prevents an offline/stale cache from reinstalling a known partial build.
    if ! python3 "$PROJECT_ROOT/scripts/framegen_package.py" merge --catalog "$tmp/catalog.json" \
        --previous "$PROJECT_ROOT/data/framegen_auto_baseline.json" > "$tmp/baseline.json" 2> "$tmp/check.log"; then
        { [ ! -L "$FRAMEGEN_CATALOG_CACHE" ] && cp -- "$FRAMEGEN_CATALOG_CACHE" "$tmp/catalog.json" 2>/dev/null; } || \
            cp -- "$PROJECT_ROOT/data/framegen_auto_baseline.json" "$tmp/catalog.json" || return 1
        python3 "$PROJECT_ROOT/scripts/framegen_package.py" merge --catalog "$tmp/catalog.json" \
            --previous "$PROJECT_ROOT/data/framegen_auto_baseline.json" > "$tmp/baseline.json" 2> "$tmp/check.log" || {
                cp -- "$PROJECT_ROOT/data/framegen_auto_baseline.json" "$tmp/baseline.json" || return 1
            }
    fi
    python3 "$PROJECT_ROOT/scripts/framegen_package.py" merge --catalog "$tmp/baseline.json" \
        --previous "$FRAMEGEN_CATALOG_CACHE" > "$tmp/merged.json" 2> "$tmp/check.log" || return 1
    cache_dir="$(dirname "$FRAMEGEN_CATALOG_CACHE")"
    [ ! -L "$cache_dir" ] && [ ! -L "$FRAMEGEN_CATALOG_CACHE" ] || return 1
    mkdir -p -- "$cache_dir" || return 1
    cache_tmp="$(mktemp "$cache_dir/.catalog.XXXXXX")" || return 1
    cp -- "$tmp/merged.json" "$cache_tmp" || return 1
    mv -f -- "$cache_tmp" "$FRAMEGEN_CATALOG_CACHE" || return 1
    cache_tmp=""
)

lsfg_v2_is_selected() {
    python3 "$PROJECT_ROOT/scripts/framegen_package.py" selected \
        --root "$1/Decky LSFG-VK" >/dev/null 2>&1
}

_install_framegen_auto() (
    # Return 2 only when no validated catalog is available, preserving legacy fallback.
    local kind="$1" reload_after="${2:-1}" tmp directory repo display
    local version mirror_id package_sha archive_root plugin_name attribution installed_version
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    [ "$IS_STEAMOS" -eq 1 ] || return 2
    case "$kind" in
        lsfg-v2) directory="Decky LSFG-VK"; repo="zhoukeer-toolbox-mirror-4"; display="小黄鸭 2.0" ;;
        fsr4) directory="Decky-Framegen"; repo="zhoukeer-toolbox-mirror-3"; display="FSR4" ;;
        *) return 1 ;;
    esac
    tmp="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$tmp"' EXIT
    refresh_framegen_catalog || true
    [ -f "$FRAMEGEN_CATALOG_CACHE" ] && [ ! -L "$FRAMEGEN_CATALOG_CACHE" ] || return 2
    cp -- "$FRAMEGEN_CATALOG_CACHE" "$tmp/catalog.json" || return 2
    if ! python3 "$PROJECT_ROOT/scripts/framegen_package.py" resolve --catalog "$tmp/catalog.json" \
        --kind "$kind" --entry-output "$tmp/entry.json" > "$tmp/fields" 2> "$tmp/check.log"; then
        log "Framegen 更新信息校验失败，保留固定基线: $kind"
        return 2
    fi
    IFS=$'\t' read -r version mirror_id package_sha archive_root plugin_name attribution < "$tmp/fields" || return 1
    if [ "$kind" != lsfg-v2 ] && python3 "$PROJECT_ROOT/scripts/framegen_package.py" check --catalog "$tmp/entry.json" \
        --kind "$kind" --root "$plugin_root/$directory" >/dev/null 2>&1; then
        [ "$kind" != lsfg-v2 ] || remove_legacy_lsfg_directories "$plugin_root"
        echo "[已安装] $display v${version} 已是完整的当前版本。"
        return 0
    fi
    installed_version="$(decky_plugin_version "$plugin_root/$directory" 2>/dev/null || true)"
    if [ -n "$installed_version" ] && python3 - "$PROJECT_ROOT/scripts" "$installed_version" "$version" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from framegen_package import version
try: raise SystemExit(0 if version(sys.argv[2]) > version(sys.argv[3]) else 1)
except ValueError: raise SystemExit(1)
PY
    then
        echo "$display 当前安装的版本较新，已保留。"
        return 0
    fi
    echo "正在安装 $display v${version}..."
    GITEE_MIRROR_REPO="$repo" download_gitee_mirror_file "$mirror_id" \
        "$tmp/plugin.zip" "$package_sha" "$display" || {
            echo "$display 下载暂时不可用，已保留现有插件。"
            return 1
        }
    python3 "$PROJECT_ROOT/scripts/framegen_package.py" extract --catalog "$tmp/entry.json" \
        --kind "$kind" --archive "$tmp/plugin.zip" --root "$tmp/plugin" > "$tmp/check.log" 2>&1 || {
            log "Framegen 安装包检查失败: $kind"
            echo "$display 安装文件检查未通过，已保留现有插件。"
            return 1
        }
    prepare_plugin_root "$plugin_root" || return 1
    if [ "$kind" = lsfg-v2 ]; then
        install_lsfg_v2_clean "$tmp/plugin" "$plugin_root" || return 1
    else
        install_tree_atomically "$tmp/plugin" "$plugin_root" "$directory" || return 1
    fi
    [ "$kind" != lsfg-v2 ] || remove_legacy_lsfg_directories "$plugin_root"
    echo "$display v${version} 安装成功。"
    [ "$attribution" != RenAmamiya ] || echo "汉化：RenAmamiya"
    [ "$reload_after" != 1 ] || reload_decky_plugins "Decky 已重新加载，返回游戏模式即可使用。"
)

install_framegen_auto() {
    local status=0
    _install_framegen_auto "$@" || status=$?
    load_framegen_cached_versions
    [ "$status" -ne 0 ] || PLUGIN_INSTALL_CHANGED=1
    return "$status"
}
