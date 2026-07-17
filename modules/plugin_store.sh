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
source "$PROJECT_ROOT/modules/steam_accelerator.sh"

load_config

DECKY_LOADER_URL="${DECKY_LOADER_URL:-https://www.mhhf.com/Deck/decky/v.3.2.6/PluginLoader}"
DECKY_LOADER_SHA256="${DECKY_LOADER_SHA256:-30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e}"
DECKY_SERVICE_URL="${DECKY_SERVICE_URL:-https://www.mhhf.com/Deck/decky/plugin_loader-release.service}"
DECKY_SERVICE_SHA256="${DECKY_SERVICE_SHA256:-64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1}"
DECKY_HOMEBREW_DIR="${ZHOUKEER_DECKY_HOMEBREW_DIR:-$HOME/homebrew}"
DECKY_UNIT_PATH="${ZHOUKEER_DECKY_UNIT_PATH:-/etc/systemd/system/plugin_loader.service}"
DECKY_SERVICE_NAME="plugin_loader.service"
DECKY_TMP_DIR=""
LSFG_OFFICIAL_DIRECTORY="Decky LSFG-VK"
LSFG_OFFICIAL_VERSION="0.12.5"

# 三款功能插件固定使用作者 GitHub Release，避免被用户旧配置改回过期镜像。
DECKY_LSFG_URL="https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip"
DECKY_LSFG_SHA256="13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"
DECKY_FSR4_URL="https://github.com/xXJSONDeruloXx/Decky-Framegen/releases/download/v0.15.6/Decky-Framegen.zip"
DECKY_FSR4_SHA256="236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"
DECKY_CHEATDECK_URL="https://github.com/SheffeyG/CheatDeck/releases/download/v1.2.1/CheatDeck.zip"
DECKY_CHEATDECK_SHA256="83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"

cleanup_decky_tmp() {
    if [ -n "$DECKY_TMP_DIR" ] && [ -d "$DECKY_TMP_DIR" ]; then
        rm -rf -- "$DECKY_TMP_DIR"
    fi
    DECKY_TMP_DIR=""
}

calculate_decky_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -- "$file" | awk '{print $1}'
    else
        return 1
    fi
}

confirm_decky_install() {
    local answer

    echo "将通过国内镜像安装固定版本的Decky Loader插件商城。"
    echo "工具箱会分别校验程序和服务模板，不会执行下载源提供的外层安装脚本。"
    echo "启用系统服务时会请求Steam Deck管理员权限，已有插件会完整保留。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "是否继续？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

download_decky_component() {
    local name="$1"
    local url="$2"
    local expected_sha256="$3"
    local output="$4"
    local actual_sha256

    if [ -z "$url" ] || [ -z "$expected_sha256" ]; then
        echo "$name 的下载配置不完整，请先更新工具箱。"
        return 1
    fi

    if ! curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 15 \
        --max-time 1200 \
        --retry 3 \
        --retry-delay 2 \
        --retry-all-errors \
        --output "$output" \
        "$url"; then
        rm -f -- "$output"
        echo "$name 下载失败，未改动现有Decky安装。"
        return 1
    fi

    actual_sha256="$(calculate_decky_sha256 "$output")" || {
        rm -f -- "$output"
        echo "无法校验$name，已停止安装。"
        return 1
    }
    if [ "$actual_sha256" != "$expected_sha256" ]; then
        rm -f -- "$output"
        echo "$name 已发生变化或下载不完整，为避免安装未经审查的文件，已停止。"
        echo "请更新周克儿工具箱后再试。"
        log "Decky安装停止: $name SHA256变化"
        return 1
    fi
    echo "$name 下载完成并通过SHA256校验。"
}

render_decky_service() {
    local template="$1"
    local output="$2"
    local homebrew_dir="$3"
    local placeholder='${HOMEBREW_FOLDER}'
    local line

    case "$homebrew_dir" in
        /*) ;;
        *)
            echo "Decky安装目录必须是绝对路径。"
            return 1
            ;;
    esac
    case "$homebrew_dir" in
        *[!A-Za-z0-9_./-]*)
            echo "Decky安装目录包含systemd服务不支持的字符：$homebrew_dir"
            return 1
            ;;
    esac

    : > "$output" || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        printf '%s\n' "${line//$placeholder/$homebrew_dir}" >> "$output" || return 1
    done < "$template"

    if grep -Fq "$placeholder" "$output" || \
        [ "$(grep -Fc "ExecStart=$homebrew_dir/services/PluginLoader" "$output")" -ne 1 ] || \
        [ "$(grep -Fc "WorkingDirectory=$homebrew_dir/services" "$output")" -ne 1 ] || \
        ! grep -Fxq 'User=root' "$output" || \
        ! grep -Fxq 'WantedBy=multi-user.target' "$output"; then
        echo "Decky服务模板内容不符合预期，已停止安装。"
        return 1
    fi
}

prepare_decky_homebrew_dirs() {
    local homebrew_dir="$1"
    local services_dir="$homebrew_dir/services"
    local plugins_dir="$homebrew_dir/plugins"

    if [ -L "$homebrew_dir" ] || [ -L "$services_dir" ]; then
        echo "Decky安装目录不能是符号链接，已停止安装。"
        return 1
    fi
    if { [ -e "$homebrew_dir" ] && [ ! -d "$homebrew_dir" ]; } || \
        { [ -e "$services_dir" ] && [ ! -d "$services_dir" ]; } || \
        { [ -e "$plugins_dir" ] && [ ! -d "$plugins_dir" ] && [ ! -L "$plugins_dir" ]; }; then
        echo "Decky安装路径被非目录文件占用，已停止安装。"
        return 1
    fi

    if ! mkdir -p -- "$services_dir"; then
        toolbox_sudo mkdir -p -- "$services_dir" || return 1
    fi
    if [ ! -e "$plugins_dir" ]; then
        if ! mkdir -p -- "$plugins_dir"; then
            toolbox_sudo install -d -m 0755 -o "$(id -u)" -g "$(id -g)" -- "$plugins_dir" || return 1
        fi
    fi

    if [ -w "$services_dir" ]; then
        DECKY_HOME_OP_SUDO=0
    else
        DECKY_HOME_OP_SUDO=1
    fi
}

run_decky_homebrew_operation() {
    if [ "${DECKY_HOME_OP_SUDO:-0}" -eq 1 ]; then
        toolbox_sudo "$@"
    else
        "$@"
    fi
}

rollback_decky_install() {
    if [ "${DECKY_UNIT_SWAP_STARTED:-0}" -eq 1 ]; then
        if [ "${DECKY_UNIT_HAD_OLD:-0}" -eq 1 ]; then
            if toolbox_sudo test -f "$DECKY_UNIT_BACKUP"; then
                toolbox_sudo rm -f -- "$DECKY_UNIT_PATH" || true
                toolbox_sudo mv -- "$DECKY_UNIT_BACKUP" "$DECKY_UNIT_PATH" || true
            fi
        else
            toolbox_sudo rm -f -- "$DECKY_UNIT_PATH" || true
        fi
        toolbox_sudo rm -f -- "$DECKY_UNIT_NEW" || true
    fi

    if [ "${DECKY_LOADER_SWAP_STARTED:-0}" -eq 1 ]; then
        if [ "${DECKY_LOADER_HAD_OLD:-0}" -eq 1 ]; then
            if run_decky_homebrew_operation test -f "$DECKY_LOADER_BACKUP"; then
                run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_TARGET" || true
                run_decky_homebrew_operation mv -- "$DECKY_LOADER_BACKUP" "$DECKY_LOADER_TARGET" || true
            fi
        else
            run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_TARGET" || true
        fi
        run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_NEW" || true
    fi

    if [ "${DECKY_UNIT_SWAP_STARTED:-0}" -eq 1 ]; then
        toolbox_sudo systemctl daemon-reload >/dev/null 2>&1 || true
        if [ "${DECKY_UNIT_HAD_OLD:-0}" -eq 1 ]; then
            if [ "${DECKY_OLD_ENABLED:-0}" -eq 1 ]; then
                toolbox_sudo systemctl enable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            else
                toolbox_sudo systemctl disable "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            fi
            if [ "${DECKY_OLD_ACTIVE:-0}" -eq 1 ]; then
                toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            else
                toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
            fi
        else
            toolbox_sudo systemctl disable --now "$DECKY_SERVICE_NAME" >/dev/null 2>&1 || true
        fi
    fi
}

finish_plugin_store_install() {
    local status="$1"

    trap - EXIT INT TERM
    if [ "${DECKY_INSTALL_COMMITTED:-0}" -ne 1 ]; then
        rollback_decky_install
    fi
    cleanup_decky_tmp
    exit "$status"
}

install_plugin_store() (
    local tmp_dir
    local loader_download
    local service_template
    local rendered_service
    local services_dir

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "插件商城安装仅支持真实SteamOS环境。"
        return 1
    fi
    if [ "$(id -u)" -eq 0 ]; then
        echo "请使用Steam Deck桌面用户运行工具箱，不要直接以root运行。"
        return 1
    fi
    for command_name in curl sudo install systemctl; do
        require_command "$command_name" || return 1
    done
    confirm_decky_install || {
        echo "已取消插件商城安装。"
        return 0
    }

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    loader_download="$tmp_dir/PluginLoader.download"
    service_template="$tmp_dir/plugin_loader-release.service.download"
    rendered_service="$tmp_dir/plugin_loader.service"
    services_dir="$DECKY_HOMEBREW_DIR/services"

    DECKY_INSTALL_COMMITTED=0
    DECKY_HOME_OP_SUDO=0
    DECKY_LOADER_TARGET="$services_dir/PluginLoader"
    DECKY_LOADER_NEW="$services_dir/.PluginLoader.new.$$"
    DECKY_LOADER_BACKUP="$services_dir/.PluginLoader.backup.$$"
    DECKY_LOADER_HAD_OLD=0
    DECKY_LOADER_SWAP_STARTED=0
    DECKY_UNIT_NEW="$DECKY_UNIT_PATH.new.$$"
    DECKY_UNIT_BACKUP="$DECKY_UNIT_PATH.backup.$$"
    DECKY_UNIT_HAD_OLD=0
    DECKY_UNIT_SWAP_STARTED=0
    DECKY_OLD_ENABLED=0
    DECKY_OLD_ACTIVE=0

    trap 'exit 130' INT TERM
    trap 'finish_plugin_store_install $?' EXIT

    download_decky_component \
        "Decky PluginLoader" \
        "$DECKY_LOADER_URL" \
        "$DECKY_LOADER_SHA256" \
        "$loader_download" || return 1
    download_decky_component \
        "Decky systemd服务模板" \
        "$DECKY_SERVICE_URL" \
        "$DECKY_SERVICE_SHA256" \
        "$service_template" || return 1
    render_decky_service "$service_template" "$rendered_service" "$DECKY_HOMEBREW_DIR" || return 1
    prepare_decky_homebrew_dirs "$DECKY_HOMEBREW_DIR" || return 1

    if [ -L "$DECKY_LOADER_TARGET" ] || \
        { [ -e "$DECKY_LOADER_TARGET" ] && [ ! -f "$DECKY_LOADER_TARGET" ]; } || \
        [ -L "$DECKY_UNIT_PATH" ] || \
        { [ -e "$DECKY_UNIT_PATH" ] && [ ! -f "$DECKY_UNIT_PATH" ]; }; then
        echo "Decky现有程序或服务文件类型异常，已停止安装。"
        return 1
    fi
    if [ -e "$DECKY_LOADER_NEW" ] || [ -e "$DECKY_LOADER_BACKUP" ] || \
        toolbox_sudo test -e "$DECKY_UNIT_NEW" || toolbox_sudo test -e "$DECKY_UNIT_BACKUP"; then
        echo "检测到未清理的Decky安装暂存文件，已停止以避免覆盖。"
        return 1
    fi

    if [ -f "$DECKY_LOADER_TARGET" ]; then
        DECKY_LOADER_HAD_OLD=1
    fi
    if toolbox_sudo test -f "$DECKY_UNIT_PATH"; then
        DECKY_UNIT_HAD_OLD=1
        toolbox_sudo systemctl is-enabled --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 && \
            DECKY_OLD_ENABLED=1
        toolbox_sudo systemctl is-active --quiet "$DECKY_SERVICE_NAME" >/dev/null 2>&1 && \
            DECKY_OLD_ACTIVE=1
    fi

    run_decky_homebrew_operation install -m 0755 -- "$loader_download" "$DECKY_LOADER_NEW" || return 1
    toolbox_sudo install -m 0644 -- "$rendered_service" "$DECKY_UNIT_NEW" || return 1

    DECKY_LOADER_SWAP_STARTED=1
    if [ "$DECKY_LOADER_HAD_OLD" -eq 1 ]; then
        run_decky_homebrew_operation mv -- "$DECKY_LOADER_TARGET" "$DECKY_LOADER_BACKUP" || return 1
    fi
    run_decky_homebrew_operation mv -- "$DECKY_LOADER_NEW" "$DECKY_LOADER_TARGET" || return 1

    DECKY_UNIT_SWAP_STARTED=1
    if [ "$DECKY_UNIT_HAD_OLD" -eq 1 ]; then
        toolbox_sudo mv -- "$DECKY_UNIT_PATH" "$DECKY_UNIT_BACKUP" || return 1
    fi
    toolbox_sudo mv -- "$DECKY_UNIT_NEW" "$DECKY_UNIT_PATH" || return 1

    echo "正在启用Decky Loader服务..."
    toolbox_sudo systemctl daemon-reload || return 1
    toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME" || return 1
    toolbox_sudo systemctl enable "$DECKY_SERVICE_NAME" || return 1

    DECKY_INSTALL_COMMITTED=1
    run_decky_homebrew_operation rm -f -- "$DECKY_LOADER_BACKUP" || true
    toolbox_sudo rm -f -- "$DECKY_UNIT_BACKUP" || true

    echo "Decky Loader安装完成，已有插件未被改动。请返回游戏模式检查插件菜单。"
    log "Decky Loader固定版本安装完成"
)

download_verified_package() {
    local name="$1"
    local url="$2"
    local expected_sha256="$3"
    local output="$4"
    local actual_sha256
    local curl_status
    local attempt
    local retry_options=(--retry 5 --retry-delay 2)

    if [ -z "$url" ] || [ -z "$expected_sha256" ]; then
        echo "$name 的下载配置不完整，请先更新工具箱。"
        return 1
    fi

    # SteamOS 自带 curl 支持 retry-all-errors；老版本则保持普通重试，
    # 不因一个未知参数而让整项安装直接失败。
    if curl --help all 2>/dev/null | grep -Fq -- '--retry-all-errors'; then
        retry_options+=(--retry-all-errors)
    fi

    for attempt in 1 2; do
        rm -f -- "$output"
        local _dl_ok=0 _dl_url _mirror
        for _mirror in $GITHUB_MIRRORS ""; do
            if [ -n "$_mirror" ]; then
                _dl_url="${_mirror}${url}"
            else
                _dl_url="$url"
            fi
            echo "正在下载 $name（第 $attempt/2 轮）..."
            if curl \
                --fail \
                --location \
                --show-error \
                --progress-bar \
                --proto '=https' \
                --proto-redir '=https' \
                --connect-timeout 15 \
                --max-time 1200 \
                "${retry_options[@]}" \
                --output "$output" \
                "$_dl_url"; then
                _dl_ok=1
                break
            fi
            rm -f -- "$output"
        done
        if [ "$_dl_ok" -eq 1 ]; then
            actual_sha256="$(calculate_decky_sha256 "$output")" || {
                rm -f -- "$output"
                echo "无法校验 $name，已停止安装。"
                return 1
            }
            if [ "$actual_sha256" = "$expected_sha256" ]; then
                echo "$name 下载完成并通过完整性校验。"
                return 0
            fi
            echo "$name 第 $attempt/2 轮下载不完整，校验失败，正在重新获取。"
        else
            curl_status=$?
            echo "$name 第 $attempt/2 轮下载失败（curl 退出码：$curl_status）。"
        fi
        rm -f -- "$output"
        [ "$attempt" -eq 2 ] || sleep 3
    done

    echo "$name 下载失败，两轮均未成功，未改动现有文件。"
    print_steam302_download_fallback
    return 1
}

archive_paths_are_safe() {
    local archive="$1"
    local archive_type="$2"
    local paths

    case "$archive_type" in
        zip) paths="$(unzip -Z1 "$archive")" || return 1 ;;
        *) return 1 ;;
    esac

    if printf '%s\n' "$paths" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        echo "压缩包包含不安全路径，已停止安装。"
        return 1
    fi
}

run_plugin_file_operation() {
    if [ "${PLUGIN_NEEDS_SUDO:-0}" -eq 1 ]; then
        toolbox_sudo "$@"
    else
        "$@"
    fi
}

prepare_plugin_root() {
    local plugin_root="$1"

    if [ ! -d "$plugin_root" ]; then
        echo "未找到 Decky 插件目录：$plugin_root"
        echo "请先点击“安装或更新 Decky Loader”，完成后再安装插件。"
        return 1
    fi
    if [ -w "$plugin_root" ]; then
        PLUGIN_NEEDS_SUDO=0
    else
        require_command sudo || return 1
        PLUGIN_NEEDS_SUDO=1
    fi
}

install_tree_atomically() {
    local source_dir="$1"
    local target_parent="$2"
    local target_name="$3"
    local target_dir="$target_parent/$target_name"
    local staging_dir="$target_parent/.${target_name}.new.$$"
    local backup_dir="$target_parent/.${target_name}.backup.$$"

    run_plugin_file_operation rm -rf -- "$staging_dir" "$backup_dir" || return 1
    run_plugin_file_operation cp -a -- "$source_dir" "$staging_dir" || return 1

    if [ -e "$target_dir" ]; then
        run_plugin_file_operation mv -- "$target_dir" "$backup_dir" || {
            run_plugin_file_operation rm -rf -- "$staging_dir"
            return 1
        }
    fi

    if ! run_plugin_file_operation mv -- "$staging_dir" "$target_dir"; then
        if [ -e "$backup_dir" ] && [ ! -e "$target_dir" ]; then
            run_plugin_file_operation mv -- "$backup_dir" "$target_dir" || true
        fi
        return 1
    fi
    run_plugin_file_operation rm -rf -- "$backup_dir"
}

find_plugin_source() {
    local extract_dir="$1"
    local plugin_json

    plugin_json="$(find "$extract_dir" -mindepth 2 -maxdepth 3 -type f -name plugin.json -print -quit)"
    [ -n "$plugin_json" ] || return 1
    dirname "$plugin_json"
}

install_decky_zip() {
    local display_name="$1"
    local url="$2"
    local sha256="$3"
    local expected_dir="$4"
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local tmp_dir
    local archive
    local extract_dir
    local plugin_source

    for command_name in curl unzip; do
        require_command "$command_name" || return 1
    done
    prepare_plugin_root "$plugin_root" || return 1

    tmp_dir="$(mktemp -d)" || return 1
    DECKY_TMP_DIR="$tmp_dir"
    archive="$tmp_dir/plugin.zip"
    extract_dir="$tmp_dir/extracted"
    mkdir -p "$extract_dir"
    trap cleanup_decky_tmp EXIT INT TERM

    download_verified_package "$display_name" "$url" "$sha256" "$archive" || return 1
    archive_paths_are_safe "$archive" zip || return 1
    unzip -q "$archive" -d "$extract_dir" || {
        echo "$display_name 解压失败，未改动现有插件。"
        return 1
    }
    plugin_source="$(find_plugin_source "$extract_dir")" || {
        echo "$display_name 压缩包中没有找到 plugin.json。"
        return 1
    }
    if [ "$(basename "$plugin_source")" != "$expected_dir" ]; then
        echo "$display_name 的目录结构不符合预期，已停止安装。"
        return 1
    fi

    install_tree_atomically "$plugin_source" "$plugin_root" "$expected_dir" || {
        echo "$display_name 安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "$display_name 已安装到：$plugin_root/$expected_dir"
    log "$display_name 安装完成"
    cleanup_decky_tmp
    trap - EXIT INT TERM
}

reload_decky_plugins() {
    local success_message="$1"

    if command -v systemctl >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        if toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME"; then
            echo "$success_message"
            return 0
        fi
        echo "插件文件已变更，但 Decky 重载未完成。请完全退出游戏模式后重新进入一次。"
        return 0
    fi

    echo "插件文件已变更。请完全退出游戏模式后重新进入一次，让 Decky 重新扫描插件目录。"
}

install_zhoukeer_localizer() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local source_dir="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "周克儿汉化仅支持真实 SteamOS 环境。"
        return 1
    fi
    if [ -L "$source_dir" ] || [ ! -f "$source_dir/plugin.json" ] || [ ! -s "$source_dir/dist/index.js" ]; then
        echo "周克儿汉化组件不完整，请更新工具箱后再试。"
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1

    install_tree_atomically "$source_dir" "$plugin_root" "zhoukeer-localizer" || {
        echo "周克儿汉化安装失败，已尽量保留旧版本。"
        return 1
    }
    echo "周克儿汉化修复版已安装，正在让 Decky 重新扫描插件目录..."
    reload_decky_plugins "Decky 已重新加载。返回游戏模式后，在插件列表中打开“周克儿汉化”，再打开需要汉化的插件页面。"
    log "周克儿汉化修复版安装完成"
}

uninstall_all_decky_plugins() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local entry
    local removed=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "Decky 插件卸载仅支持真实 SteamOS 环境。"
        return 1
    fi
    if [ -L "$plugin_root" ] || [ ! -d "$plugin_root" ]; then
        echo "Decky 插件目录异常，已停止卸载。"
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        if command -v kdialog >/dev/null 2>&1; then
            kdialog --title "确认清空 Decky 插件" --warningyesno \
                "确定清空插件根目录内的所有 Decky 插件吗？这会删除全部插件文件和插件设置，但不会删除 Decky Loader 本体。" \
                --yes-label "全部删除" --no-label "取消" >/dev/null 2>&1 || {
                echo "已取消卸载。"
                return 0
            }
        else
            echo "请从工具箱菜单点击“一键清空已装插件”后，在触控确认页继续。"
            return 1
        fi
    fi

    for entry in "$plugin_root"/* "$plugin_root"/.[!.]* "$plugin_root"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        run_plugin_file_operation rm -rf -- "$entry" || {
            echo "清空失败，已停止；未处理的插件仍保留。"
            return 1
        }
        removed=$((removed + 1))
    done

    echo "已清空插件根目录：共删除 $removed 个项目。"
    reload_decky_plugins "Decky 已重新加载，插件列表已清空。"
    log "Decky插件根目录已清空: $removed 项"
}

open_lossless_store() {
    echo "正在打开 Lossless Scaling 的 Steam 正版页面..."
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "steam://store/993090" >/dev/null 2>&1 &
    elif command -v steam >/dev/null 2>&1; then
        steam "steam://store/993090" >/dev/null 2>&1 &
    else
        echo "商店地址：https://store.steampowered.com/app/993090/"
    fi
}

LOSSLESS_WORK_DIR=""
LOSSLESS_LOCK_DIR=""
LOSSLESS_ARCHIVE_MEMBERS=0
LOSSLESS_ARCHIVE_BYTES=0

cleanup_lossless_import() {
    if [ -n "$LOSSLESS_WORK_DIR" ] && [ -d "$LOSSLESS_WORK_DIR" ]; then
        rm -rf -- "$LOSSLESS_WORK_DIR"
    fi
    if [ -n "$LOSSLESS_LOCK_DIR" ] && [ -d "$LOSSLESS_LOCK_DIR" ]; then
        rmdir -- "$LOSSLESS_LOCK_DIR" 2>/dev/null || true
    fi
    LOSSLESS_WORK_DIR=""
    LOSSLESS_LOCK_DIR=""
}

file_size_bytes() {
    local file="$1"

    if stat -c '%s' -- "$file" >/dev/null 2>&1; then
        stat -c '%s' -- "$file"
    else
        stat -f '%z' -- "$file"
    fi
}

free_space_bytes() {
    df -Pk "$1" 2>/dev/null | awk 'NR > 1 { free_kb=$4 } END { printf "%.0f\n", free_kb * 1024 }'
}

canonical_directory() {
    (cd "$1" 2>/dev/null && pwd -P)
}

append_steam_library_if_valid() {
    local candidate="$1"
    local output_file="$2"
    local canonical

    [ -n "$candidate" ] || return 0
    [ -d "$candidate/steamapps" ] || return 0
    canonical="$(canonical_directory "$candidate")" || return 0
    if ! grep -Fqx -- "$canonical" "$output_file" 2>/dev/null; then
        printf '%s\n' "$canonical" >> "$output_file"
    fi
}

discover_steam_libraries() {
    local output_file="$1"
    local candidate
    local steam_root
    local vdf
    local vdf_path

    : > "$output_file"
    for candidate in \
        "$HOME/.local/share/Steam" \
        "$HOME/.steam/steam" \
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
        append_steam_library_if_valid "$candidate" "$output_file"
    done

    # Steam 的 libraryfolders.vdf 记录了 SD 卡和其他自定义库。
    # 只接受当前真实存在且含 steamapps 的目录，避免把配置文字当成路径使用。
    while IFS= read -r steam_root; do
        [ -n "$steam_root" ] || continue
        vdf="$steam_root/steamapps/libraryfolders.vdf"
        [ -r "$vdf" ] || continue
        while IFS= read -r vdf_path; do
            case "$vdf_path" in
                /*) append_steam_library_if_valid "$vdf_path" "$output_file" ;;
            esac
        done < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$vdf")
    done < "$output_file"
}

choose_steam_library_root() {
    local requested="${LOSSLESS_STEAM_LIBRARY:-}"
    local libraries_file="$1"
    local count
    local selected
    local candidate
    local index
    local answer
    local -a menu_args

    if [ -n "$requested" ]; then
        [ -d "$requested/steamapps" ] || {
            echo "指定的 Steam 库无效：$requested"
            return 1
        }
        canonical_directory "$requested"
        return
    fi

    discover_steam_libraries "$libraries_file"
    count="$(wc -l < "$libraries_file" | tr -d '[:space:]')"
    [ "$count" -gt 0 ] || {
        echo "未找到 Steam 库，请先启动一次 Steam。"
        return 1
    }
    if [ "$count" -eq 1 ]; then
        sed -n '1p' "$libraries_file"
        return 0
    fi

    if command -v kdialog >/dev/null 2>&1; then
        menu_args=()
        index=0
        while IFS= read -r candidate; do
            index=$((index + 1))
            menu_args+=("$index" "$candidate")
        done < "$libraries_file"
        selected="$(kdialog --title "选择 Lossless Scaling 安装位置" \
            --menu "检测到多个 Steam 库，请选择要导入到哪一个库。" \
            "${menu_args[@]}" 2>/dev/null || true)"
        [ -n "$selected" ] || return 1
        sed -n "${selected}p" "$libraries_file"
        return 0
    fi

    if [ -t 0 ]; then
        echo "检测到多个 Steam 库：" >&2
        index=0
        while IFS= read -r candidate; do
            index=$((index + 1))
            printf '  %s. %s\n' "$index" "$candidate" >&2
        done < "$libraries_file"
        read -r -p "请选择安装位置 [1-$count]：" answer
        case "$answer" in
            *[!0-9]*|'') return 1 ;;
        esac
        [ "$answer" -ge 1 ] && [ "$answer" -le "$count" ] || return 1
        sed -n "${answer}p" "$libraries_file"
        return 0
    fi

    echo "检测到多个 Steam 库，无法在非交互模式中自动选择。" >&2
    echo "请设置 LOSSLESS_STEAM_LIBRARY=/你的/Steam库 后重试。" >&2
    return 1
}

lossless_archive_extension_is_supported() {
    case "$1" in
        *.zip|*.ZIP|*.tar|*.TAR|*.tar.gz|*.TAR.GZ|*.tgz|*.TGZ) return 0 ;;
        *)
            echo "仅支持可安全审计的 zip、tar、tar.gz 或 tgz 本地备份。"
            return 1
            ;;
    esac
}

lossless_limit_is_valid() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -gt 0 ] ;;
    esac
}

audit_lossless_archive() {
    local archive="$1"
    local audit_dir="$2"
    local names_file="$audit_dir/names.txt"
    local verbose_file="$audit_dir/verbose.txt"
    local stats
    local archive_size
    local max_members="${LOSSLESS_MAX_MEMBERS:-20000}"
    local max_total="${LOSSLESS_MAX_EXPANDED_BYTES:-8589934592}"
    local max_single="${LOSSLESS_MAX_SINGLE_FILE_BYTES:-4294967296}"
    local max_ratio="${LOSSLESS_MAX_COMPRESSION_RATIO:-2000}"
    local value

    for value in "$max_members" "$max_total" "$max_single" "$max_ratio"; do
        lossless_limit_is_valid "$value" || {
            echo "本地备份安全限制配置无效。"
            return 1
        }
    done

    # 使用同一个 libarchive/bsdtar 完成列表和解压，避免两套解析器理解不同。
    if ! LC_ALL=C bsdtar -tf "$archive" < /dev/null > "$names_file" 2>/dev/null || \
       ! LC_ALL=C bsdtar -tvf "$archive" < /dev/null > "$verbose_file" 2>/dev/null; then
        echo "本地备份无法读取，可能已损坏、加密或格式不受支持。"
        return 1
    fi
    [ -s "$names_file" ] || {
        echo "本地备份是空压缩包。"
        return 1
    }

    # bsdtar 会将文件名中的换行等控制字符显示成反斜杠转义；本流程完全拒绝
    # 反斜杠和其他控制符，从而不会把它们误当成普通路径。
    if LC_ALL=C grep -Eq '[[:cntrl:]\\]' "$names_file"; then
        echo "本地备份包含控制字符或反斜杠路径，已停止导入。"
        return 1
    fi
    while IFS= read -r value; do
        case "$value" in
            /*|[A-Za-z]:*|*\\*|*//*|.|./*|*/./*|*/.|..|../*|*/../*|*/..)
                echo "本地备份包含不安全路径，已停止导入。"
                return 1
                ;;
            Lossless\ Scaling|Lossless\ Scaling/*) ;;
            *)
                echo "本地备份包含 Lossless Scaling 目录以外的内容。"
                return 1
                ;;
        esac
        [ "${#value}" -le 1024 ] || {
            echo "本地备份包含过长路径，已停止导入。"
            return 1
        }
    done < "$names_file"
    if [ -n "$(LC_ALL=C sort "$names_file" | uniq -d)" ]; then
        echo "本地备份包含重复路径，已停止导入。"
        return 1
    fi
    if [ "$(grep -Fxc 'Lossless Scaling/LosslessScaling.exe' "$names_file")" -ne 1 ]; then
        echo "本地备份必须且只能包含一个 Lossless Scaling/LosslessScaling.exe。"
        return 1
    fi

    stats="$(awk -v max_members="$max_members" -v max_total="$max_total" -v max_single="$max_single" '
        {
            type=substr($1, 1, 1)
            if (type != "-" && type != "d") exit 20
            if ($5 !~ /^[0-9]+$/) exit 21
            count++
            if (type == "-") {
                size=$5 + 0
                if (size > max_single) exit 22
                total += size
                if (total > max_total) exit 23
            }
            if (count > max_members) exit 24
        }
        END {
            if (count > 0 && count <= max_members && total <= max_total)
                printf "%d %.0f\n", count, total
        }
    ' "$verbose_file")" || {
        echo "本地备份包含链接/特殊节点，或文件数量、大小超过安全限制。"
        return 1
    }
    [ -n "$stats" ] || {
        echo "本地备份成员信息不符合安全要求。"
        return 1
    }
    LOSSLESS_ARCHIVE_MEMBERS="${stats%% *}"
    LOSSLESS_ARCHIVE_BYTES="${stats#* }"

    archive_size="$(file_size_bytes "$archive")" || return 1
    [ "$archive_size" -gt 0 ] || {
        echo "本地备份文件大小异常。"
        return 1
    }
    if [ "$LOSSLESS_ARCHIVE_BYTES" -gt $((archive_size * max_ratio)) ]; then
        echo "本地备份压缩比异常，为避免压缩炸弹已停止导入。"
        return 1
    fi
}

sanitize_lossless_tree() {
    local root="$1"

    # 再检查实际落盘结果，拒绝解析器没有在列表阶段暴露的链接和特殊节点。
    if find "$root" ! -type f ! -type d -print -quit | grep -q .; then
        echo "本地备份解压后出现链接或特殊节点，已停止导入。"
        return 1
    fi
    if find "$root" -print | LC_ALL=C grep -Eq '[[:cntrl:]]'; then
        echo "本地备份解压后出现控制字符路径，已停止导入。"
        return 1
    fi
    find "$root" -type d -exec chmod 0755 {} + || return 1
    find "$root" -type f -exec chmod 0644 {} + || return 1
}

move_directory_without_clobber() {
    local source_dir="$1"
    local target_dir="$2"

    [ ! -e "$target_dir" ] && [ ! -L "$target_dir" ] || return 1
    if mv --help 2>&1 | grep -q -- '--no-target-directory'; then
        mv -nT -- "$source_dir" "$target_dir" || return 1
        [ ! -e "$source_dir" ] && [ ! -L "$source_dir" ]
    else
        # macOS 测试环境没有 -T；真实 SteamOS 使用上面的 GNU mv 安全分支。
        mv -- "$source_dir" "$target_dir"
    fi
}

import_lossless_backup() {
    local archive="$1"
    local source_size
    local free_bytes
    local required_bytes
    local extract_dir
    local game_source
    local steam_root
    local target_parent
    local target_dir
    local frozen_archive
    local libraries_file
    local margin="${LOSSLESS_FREE_SPACE_MARGIN_BYTES:-268435456}"
    local old_umask

    [ -f "$archive" ] || {
        echo "没有找到本地备份：$archive"
        return 1
    }
    lossless_archive_extension_is_supported "$archive" || return 1
    require_command bsdtar || return 1
    lossless_limit_is_valid "$margin" || return 1

    # 先发现库，再把压缩包冻结到目标盘的私有临时目录；之后所有审计与解压
    # 都只读取冻结副本，避免原文件在审计后被替换。
    libraries_file="$(mktemp)" || return 1
    steam_root="$(choose_steam_library_root "$libraries_file")" || {
        rm -f -- "$libraries_file"
        return 1
    }
    rm -f -- "$libraries_file"

    target_parent="$steam_root/steamapps/common"
    target_dir="$target_parent/Lossless Scaling"
    mkdir -p "$target_parent" || {
        return 1
    }
    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
        echo "Steam 库中已存在 Lossless Scaling，未覆盖任何文件。"
        echo "请在 Steam 中使用“验证游戏文件完整性”。"
        open_lossless_store
        return 0
    fi

    LOSSLESS_LOCK_DIR="$target_parent/.zhoukeer-lossless-import.lock"
    if ! mkdir -m 0700 -- "$LOSSLESS_LOCK_DIR" 2>/dev/null; then
        echo "已有另一个 Lossless Scaling 导入任务正在运行，请稍后再试。"
        return 1
    fi
    old_umask="$(umask)"
    umask 077
    LOSSLESS_WORK_DIR="$(mktemp -d "$target_parent/.zhoukeer-lossless.XXXXXX")" || {
        umask "$old_umask"
        cleanup_lossless_import
        return 1
    }
    umask "$old_umask"
    trap cleanup_lossless_import EXIT
    trap 'cleanup_lossless_import; exit 130' INT TERM

    source_size="$(file_size_bytes "$archive")" || return 1
    free_bytes="$(free_space_bytes "$target_parent")" || return 1
    required_bytes=$((source_size + margin))
    if [ "$free_bytes" -lt "$required_bytes" ]; then
        echo "Steam 库剩余空间不足，无法安全冻结并解压本地备份。"
        return 1
    fi
    frozen_archive="$LOSSLESS_WORK_DIR/archive"
    if ! cp -- "$archive" "$frozen_archive" || ! chmod 0600 "$frozen_archive"; then
        echo "无法在 Steam 库中创建本地备份的安全副本。"
        return 1
    fi
    audit_lossless_archive "$frozen_archive" "$LOSSLESS_WORK_DIR" || return 1
    free_bytes="$(free_space_bytes "$target_parent")" || return 1
    required_bytes=$((LOSSLESS_ARCHIVE_BYTES + margin))
    if [ "$free_bytes" -lt "$required_bytes" ]; then
        echo "Steam 库剩余空间不足；解压后约需 $LOSSLESS_ARCHIVE_BYTES 字节。"
        return 1
    fi

    extract_dir="$LOSSLESS_WORK_DIR/extracted"
    mkdir -m 0700 -- "$extract_dir" || return 1
    if ! bsdtar \
        --no-same-owner \
        --no-same-permissions \
        --no-acls \
        --no-xattrs \
        --no-fflags \
        -xf "$frozen_archive" \
        -C "$extract_dir" < /dev/null; then
        echo "本地备份解压失败；加密压缩包不会被导入。"
        return 1
    fi
    game_source="$extract_dir/Lossless Scaling"
    [ -d "$game_source" ] && [ ! -L "$game_source" ] && \
        [ -f "$game_source/LosslessScaling.exe" ] && \
        [ ! -L "$game_source/LosslessScaling.exe" ] || {
        echo "解压结果中没有唯一、有效的 Lossless Scaling 游戏目录。"
        return 1
    }
    sanitize_lossless_tree "$game_source" || return 1

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
        echo "导入期间目标目录已出现，已停止且未覆盖任何文件。"
        return 1
    fi
    if ! move_directory_without_clobber "$game_source" "$target_dir" || \
       [ ! -f "$target_dir/LosslessScaling.exe" ] || \
       [ -L "$target_dir/LosslessScaling.exe" ]; then
        echo "导入提交失败，未覆盖已有的 Steam 文件。"
        return 1
    fi

    echo "本地备份已导入：$target_dir"
    echo "已检查 $LOSSLESS_ARCHIVE_MEMBERS 个成员，解压大小 $LOSSLESS_ARCHIVE_BYTES 字节。"
    echo "接下来将由 Steam 检查正版授权并验证现有文件。"
    log "Lossless Scaling本地合法备份已导入"
    cleanup_lossless_import
    trap - EXIT INT TERM
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "steam://install/993090" >/dev/null 2>&1 &
    elif command -v steam >/dev/null 2>&1; then
        steam "steam://install/993090" >/dev/null 2>&1 &
    fi
}

select_and_import_lossless_backup() {
    local archive

    if command -v kdialog >/dev/null 2>&1; then
        archive="$(kdialog --title "选择 Lossless Scaling 本地合法备份" \
            --getopenfilename "$HOME" \
            "压缩包 (*.zip *.tar *.tar.gz *.tgz)" 2>/dev/null || true)"
        [ -n "$archive" ] || {
            echo "已取消选择本地备份。"
            return 0
        }
        import_lossless_backup "$archive"
    else
        echo "如需导入自己合法取得的本地备份，可执行："
        echo "bash modules/plugin_store.sh lsfg-import /本地/备份文件"
        return 1
    fi
}

install_lsfg_bundle() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"

    install_decky_zip \
        "小黄鸭（LSFG-VK）" \
        "${DECKY_LSFG_URL:-}" \
        "${DECKY_LSFG_SHA256:-}" \
        "$LSFG_OFFICIAL_DIRECTORY" || return 1
    remove_legacy_lsfg_directories "$plugin_root"

    check_lossless_scaling_installation
}

remove_legacy_lsfg_directories() {
    local plugin_root="$1"
    local legacy_name
    local legacy_dir
    local manifest_name
    local removed=0

    # 旧工具箱曾把同一插件安装在中文或仓库名目录。Decky 会把它们当成
    # 独立插件继续加载，导致界面仍显示旧版本；只删除名称和清单都能确认的旧副本。
    for legacy_name in "小黄鸭" "LSFG-VK" "decky-lsfg-vk" "Decky.LSFG-VK"; do
        legacy_dir="$plugin_root/$legacy_name"
        [ -e "$legacy_dir" ] || [ -L "$legacy_dir" ] || continue
        if [ -L "$legacy_dir" ]; then
            echo "发现旧小黄鸭符号链接，未自动删除：$legacy_dir"
            continue
        fi
        [ -d "$legacy_dir" ] && [ -f "$legacy_dir/plugin.json" ] || continue
        manifest_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$legacy_dir/plugin.json" | head -n 1)"
        case "$manifest_name" in
            "Decky LSFG-VK"|"LSFG-VK"|"小黄鸭") ;;
            *) continue ;;
        esac
        run_plugin_file_operation rm -rf -- "$legacy_dir" || {
            echo "旧小黄鸭目录未能清理：$legacy_dir"
            continue
        }
        removed=$((removed + 1))
    done
    if [ "$removed" -gt 0 ]; then
        echo "已清理 $removed 个旧小黄鸭目录，只保留官方 $LSFG_OFFICIAL_DIRECTORY。"
    fi
}

check_lossless_scaling_installation() {
    local libraries_file
    local steam_root
    local game_dir

    libraries_file="$(mktemp)" || return 1
    discover_steam_libraries "$libraries_file"
    while IFS= read -r steam_root; do
        [ -n "$steam_root" ] || continue
        game_dir="$steam_root/steamapps/common/Lossless Scaling"
        if [ -d "$game_dir" ] && [ -f "$game_dir/LosslessScaling.exe" ]; then
            rm -f -- "$libraries_file"
            echo "已检测到 Steam 库中的 Lossless Scaling。"
            echo "小黄鸭插件已安装，可以返回游戏模式继续使用。"
            print_lossless_linux_branch_tip
            log "小黄鸭安装后检测到 Lossless Scaling: $game_dir"
            return 0
        fi
    done < "$libraries_file"
    rm -f -- "$libraries_file"

    echo "未检测到 Steam 库中的 Lossless Scaling。"
    echo "将为你打开 Steam 正版页面；完成购买和安装后即可配合插件使用。"
    print_lossless_linux_branch_tip
    open_lossless_store
}

print_lossless_linux_branch_tip() {
    echo ""
    echo "使用提示：安装完成后，请在 Steam 正版页面打开游戏右侧齿轮。"
    echo "进入“属性” → “测试版”，选择名称以 Linux 开头的可用版本。"
    echo "随后进入游戏模式：按 Steam Deck 机身右下角“三个点（…）”按钮。"
    echo "在打开的菜单中依次点击：插头图标 → 小黄鸭 → 安装 LSFG。"
}

install_configured_plugin() {
    local action="$1"
    local reload_after_install="${2:-1}"

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "Decky 插件安装仅支持真实 SteamOS 环境。"
        return 1
    fi

    case "$action" in
        lsfg) install_lsfg_bundle ;;
        fsr4)
            install_decky_zip \
                "FSR4（Decky Framegen）" \
                "${DECKY_FSR4_URL:-}" \
                "${DECKY_FSR4_SHA256:-}" \
                "Decky-Framegen"
            ;;
        cheatdeck)
            install_decky_zip \
                "CheatDeck" \
                "${DECKY_CHEATDECK_URL:-}" \
                "${DECKY_CHEATDECK_SHA256:-}" \
                "CheatDeck"
            ;;
        *) return 1 ;;
    esac || return 1

    if [ "$reload_after_install" = "1" ]; then
        reload_decky_plugins "Decky 已重新加载，返回游戏模式后可在插头菜单看到新插件。"
    fi
}

decky_plugin_version() {
    local plugin_dir="$1"

    [ -f "$plugin_dir/package.json" ] || return 1
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$plugin_dir/package.json" | head -n 1
}

feature_plugin_is_present() {
    local plugin_root="$1"
    local directory_name="$2"
    local plugin_dir="$plugin_root/$directory_name"
    local actual_name
    local expected_name

    shift 2

    [ -d "$plugin_dir" ] && \
        [ -f "$plugin_dir/plugin.json" ] && \
        [ -s "$plugin_dir/dist/index.js" ] || return 1
    actual_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        "$plugin_dir/plugin.json" | head -n 1)"
    for expected_name in "$@"; do
        [ "$actual_name" = "$expected_name" ] && return 0
    done
    return 1
}

print_feature_plugin_status() {
    local plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local missing=0
    local lsfg_version

    echo ""
    echo "========== 常用功能插件状态 =========="
    if feature_plugin_is_present \
        "$plugin_root" "Decky LSFG-VK" "Decky LSFG-VK" "小黄鸭"; then
        lsfg_version="$(decky_plugin_version "$plugin_root/$LSFG_OFFICIAL_DIRECTORY" || true)"
        if [ "$lsfg_version" = "$LSFG_OFFICIAL_VERSION" ]; then
            echo "✓ 小黄鸭（LSFG-VK）：已写入 Decky，官方版本 $lsfg_version"
        else
            echo "✗ 小黄鸭（LSFG-VK）：检测到版本 ${lsfg_version:-未知}，请重新安装官方 $LSFG_OFFICIAL_VERSION"
            missing=1
        fi
    else
        echo "✗ 小黄鸭（LSFG-VK）：未找到完整插件文件"
        missing=1
    fi
    if feature_plugin_is_present "$plugin_root" "Decky-Framegen" "Decky-Framegen"; then
        echo "✓ FSR4（Decky-Framegen）：已写入 Decky"
    else
        echo "✗ FSR4（Decky-Framegen）：未找到完整插件文件"
        missing=1
    fi
    if feature_plugin_is_present "$plugin_root" "CheatDeck" "CheatDeck"; then
        echo "✓ CheatDeck：已写入 Decky"
    else
        echo "✗ CheatDeck：未找到完整插件文件"
        missing=1
    fi

    echo ""
    echo "说明：插件侧栏中的 Decky-Framegen 就是 FSR4；“系统主题”属于 CSS Loader，不是本次三件套。"
    echo "CheatDeck 安装完成后可在 Decky 右侧栏显示。"
    echo "若刚安装完仍未生效，请完全退出游戏模式后重新进入一次，让 Decky 重新加载插件。"
    return "$missing"
}

install_feature_plugins() {
    local plugin
    local failed=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "功能插件安装仅支持真实 SteamOS 环境。"
        return 1
    fi

    echo "将依次安装：小黄鸭（LSFG-VK）、FSR4（Decky Framegen）、CheatDeck。"
    echo "已安装的插件会以新版本安全替换；单项失败不会覆盖该插件的旧版本。"
    for plugin in lsfg fsr4 cheatdeck; do
        echo ""
        case "$plugin" in
            lsfg)
                echo "========== 小黄鸭（LSFG-VK） =========="
                if feature_plugin_is_present "$DECKY_PLUGIN_DIR" "$LSFG_OFFICIAL_DIRECTORY" "Decky LSFG-VK"; then
                    echo "[已跳过] 小黄鸭已安装"
                    continue
                fi
                ;;
            fsr4)
                echo "========== FSR4（Decky Framegen） =========="
                if feature_plugin_is_present "$DECKY_PLUGIN_DIR" "Decky-Framegen" "Decky-Framegen"; then
                    echo "[已跳过] FSR4 已安装"
                    continue
                fi
                ;;
            cheatdeck)
                echo "========== CheatDeck =========="
                if feature_plugin_is_present "$DECKY_PLUGIN_DIR" "CheatDeck" "CheatDeck"; then
                    echo "[已跳过] CheatDeck 已安装"
                    continue
                fi
                ;;
        esac
        if ! install_configured_plugin "$plugin" 0; then
            failed=1
            echo "该插件未完成，继续尝试其余插件。"
        fi
    done

    if ! print_feature_plugin_status; then
        failed=1
        echo "至少有一项插件文件未写入完成，请单独重试对应项目。"
    fi

    reload_decky_plugins \
        "Decky 已重新加载；返回游戏模式后，三款插件会出现在插头菜单中。"

    if [ "$failed" -eq 0 ]; then
        echo "三款常用功能插件已全部安装完成，文件已确认并已通知 Decky 重新扫描。"
        log "常用功能插件整组安装完成"
        return 0
    fi

    echo "部分功能插件未完成，请查看上方提示后单独重试。"
    return 1
}

install_all_plugin_packages() {
    echo "将依次处理 3款独立功能插件和25款精选插件，其中包括SimpleDeckyTDP与Unifideck。"
    echo "官方推荐插件仍由 Decky 内置安装器在 Steam 界面中确认。"

    install_feature_plugins || return 1
    if ! bash "$PROJECT_ROOT/modules/decky_bundle.sh" install; then
        echo "官方推荐插件清单未完成提交；小黄鸭、FSR4 和 CheatDeck 的结果请查看上方提示。"
        return 1
    fi

    echo "当前列表全部插件的安装流程已完成。"
    log "全部插件安装流程完成"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-store}" in
        store) install_plugin_store ;;
        lsfg) install_configured_plugin lsfg ;;
        lsfg-store) open_lossless_store ;;
        lsfg-import-select) select_and_import_lossless_backup ;;
        fsr4) install_configured_plugin fsr4 ;;
        cheatdeck) install_configured_plugin cheatdeck ;;
        localizer) install_zhoukeer_localizer ;;
        feature-status) print_feature_plugin_status ;;
        uninstall) uninstall_all_decky_plugins ;;
        features) install_feature_plugins ;;
        all) install_all_plugin_packages ;;
        lsfg-import)
            [ -n "${2:-}" ] || {
                echo "用法: $0 lsfg-import /本地/备份文件"
                exit 1
            }
            import_lossless_backup "$2"
            ;;
        *) echo "未知插件操作: $1"; exit 1 ;;
    esac
fi
