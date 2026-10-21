#!/bin/bash

THEMEHUB_CATALOG_URL="https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-4/raw/main/themehub-auto/catalog.json"
THEMEHUB_CATALOG_CACHE="$APP_DIR/plugin-updates/themehub/catalog.json"

# Keep the old tree until the copied, installed tree passes the same full-file check.
install_themehub_tree() (
    local source_dir="$1" plugin_root="$2" catalog="$3"
    local target="$plugin_root/DeckHomeThemes"
    local staged="$plugin_root/.DeckHomeThemes.new.$$"
    local backup="$plugin_root/.DeckHomeThemes.backup.$$"
    local old_moved=0 new_moved=0 committed=0
    [ ! -L "$plugin_root" ] && [ ! -L "$target" ] || return 1
    [ ! -e "$staged" ] && [ ! -L "$staged" ] && [ ! -e "$backup" ] && [ ! -L "$backup" ] || return 1
    themehub_install_cleanup() {
        local result=$?
        if [ "$committed" = 0 ]; then
            if [ "$new_moved" = 1 ]; then
                run_plugin_file_operation rm -rf -- "$target" || return 1
            fi
            if [ "$old_moved" = 1 ]; then
                run_plugin_file_operation mv -- "$backup" "$target" || {
                    log "ThemeHub 旧版恢复失败，备份保留在 $backup"
                    return 1
                }
            fi
        fi
        run_plugin_file_operation rm -rf -- "$staged" || return 1
        return "$result"
    }
    trap themehub_install_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    run_plugin_file_operation cp -a -- "$source_dir" "$staged" || return 1
    python3 "$PROJECT_ROOT/scripts/themehub_package.py" check --catalog "$catalog" --root "$staged" >/dev/null 2>&1 || return 1
    if [ -e "$target" ]; then
        run_plugin_file_operation mv -- "$target" "$backup" || return 1
        old_moved=1
    fi
    run_plugin_file_operation mv -- "$staged" "$target" || return 1
    new_moved=1
    python3 "$PROJECT_ROOT/scripts/themehub_package.py" check --catalog "$catalog" --root "$target" >/dev/null 2>&1 || return 1
    committed=1
    run_plugin_file_operation rm -rf -- "$backup" || return 3
)

refresh_themehub_catalog() (
    local tmp cache_dir cache_tmp=""
    [ "${IS_STEAMOS:-0}" -eq 1 ] || return 1
    tmp="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$tmp"; [ -z "$cache_tmp" ] || rm -f -- "$cache_tmp"' EXIT
    if ! GITHUB_QUIET=1 GITHUB_CONNECT_TIMEOUT=5 GITHUB_MAX_TIME=20 GITHUB_RETRIES=1 \
        download_github_file "$THEMEHUB_CATALOG_URL" "$tmp/catalog.json" '' '主页主题版本信息' > "$tmp/download.log" 2>&1; then
        { [ ! -L "$THEMEHUB_CATALOG_CACHE" ] && cp -- "$THEMEHUB_CATALOG_CACHE" "$tmp/catalog.json" 2>/dev/null; } || \
            cp -- "$PROJECT_ROOT/data/themehub_auto_baseline.json" "$tmp/catalog.json" || return 1
    fi
    if ! python3 "$PROJECT_ROOT/scripts/themehub_package.py" merge --catalog "$tmp/catalog.json" \
        --previous "$PROJECT_ROOT/data/themehub_auto_baseline.json" > "$tmp/floor.json" 2> "$tmp/check.log"; then
        cp -- "$PROJECT_ROOT/data/themehub_auto_baseline.json" "$tmp/floor.json" || return 1
    fi
    python3 "$PROJECT_ROOT/scripts/themehub_package.py" merge --catalog "$tmp/floor.json" \
        --previous "$THEMEHUB_CATALOG_CACHE" > "$tmp/merged.json" 2> "$tmp/check.log" || return 1
    cache_dir="$(dirname "$THEMEHUB_CATALOG_CACHE")"
    [ ! -L "$cache_dir" ] && [ ! -L "$THEMEHUB_CATALOG_CACHE" ] || return 1
    mkdir -p -- "$cache_dir" || return 1
    cache_tmp="$(mktemp "$cache_dir/.catalog.XXXXXX")" || return 1
    cp -- "$tmp/merged.json" "$cache_tmp" && mv -f -- "$cache_tmp" "$THEMEHUB_CATALOG_CACHE" || return 1
    cache_tmp=""
)

install_themehub_auto() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local selected_version mirror_id package_sha installed_version fields install_status=0
    PLUGIN_INSTALL_CHANGED=0
    [ "${IS_STEAMOS:-0}" -eq 1 ] || return 2
    echo '正在检查主页主题新版本...'
    refresh_themehub_catalog || return 2
    fields="$(python3 "$PROJECT_ROOT/scripts/themehub_package.py" resolve --catalog "$THEMEHUB_CATALOG_CACHE" 2>/dev/null)" || return 2
    IFS=$'\t' read -r selected_version mirror_id package_sha <<< "$fields"
    if python3 "$PROJECT_ROOT/scripts/themehub_package.py" check --catalog "$THEMEHUB_CATALOG_CACHE" \
        --root "$plugin_root/DeckHomeThemes" >/dev/null 2>&1; then
        echo "[已安装] 主页主题（ThemeHub）v${selected_version} 中文版已完整安装。"
        return 0
    fi
    installed_version="$(decky_plugin_version "$plugin_root/DeckHomeThemes" 2>/dev/null || true)"
    if [ -n "$installed_version" ] && python3 - "$PROJECT_ROOT/scripts" "$installed_version" "$selected_version" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from framegen_package import version
try: raise SystemExit(0 if version(sys.argv[2])>version(sys.argv[3]) else 1)
except ValueError: raise SystemExit(1)
PY
    then
        echo '主页主题当前安装的版本较新，已保留。'
        return 0
    fi
    if [ "${ZHOUKEER_TEST_MODE:-0}" != 1 ]; then
        bash "$PROJECT_ROOT/modules/preflight.sh" decky || return 1
    fi
    if (
        local tmp
        tmp="$(mktemp -d)" || return 1
        trap 'rm -rf -- "$tmp"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        cp -- "$THEMEHUB_CATALOG_CACHE" "$tmp/catalog.json" || return 1
        GITEE_MIRROR_REPO=zhoukeer-toolbox-mirror-4 download_gitee_mirror_file \
            "$mirror_id" "$tmp/plugin.zip" "$package_sha" '主页主题（ThemeHub）' || return 1
        python3 "$PROJECT_ROOT/scripts/themehub_package.py" extract --catalog "$tmp/catalog.json" \
            --archive "$tmp/plugin.zip" --root "$tmp/plugin" > "$tmp/check.log" 2>&1 || {
                log 'ThemeHub 中文包完整性检查失败，保留现有插件'
                return 1
            }
        prepare_plugin_root "$plugin_root" || return 1
        install_themehub_tree "$tmp/plugin" "$plugin_root" "$tmp/catalog.json"
    ); then
        PLUGIN_INSTALL_CHANGED=1
        echo "主页主题（ThemeHub）v${selected_version} 中文版安装成功。"
        echo '汉化作者：RenAmamiya，感谢支持！'
        echo '原作者：Kaal31 / ThemeHub；第三方作者和许可说明已保留。'
        log "ThemeHub 自动中文版安装完成: $selected_version"
        return 0
    else
        install_status=$?
    fi
    if [ "$install_status" = 3 ]; then
        echo '主页主题新版已写入，但旧文件未能清理，请重试。'
        return 1
    fi
    echo '主页主题安装未完成，现有插件已保留。'
    return 1
}
