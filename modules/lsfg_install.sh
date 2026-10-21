#!/bin/bash

# Call only with an already downloaded and verified plugin tree. Backups live
# outside plugins, so Decky cannot discover an old and new copy together.
install_lsfg_v2_clean() (
    local source_dir="$1" plugin_root="$2"
    local backup_dir="" name path manifest_name
    local service_stopped=0 resume_attempted=0 new_started=0 committed=0 rollback_failed=0
    local candidates=() displaced=()

    if [ "${IS_STEAMOS:-0}" -ne 1 ]; then
        install_tree_atomically "$source_dir" "$plugin_root" "$LSFG_V2_DIRECTORY" || return 1
        remove_legacy_lsfg_directories "$plugin_root"
        return 0
    fi
    [ ! -L "$plugin_root" ] && [ -d "$plugin_root" ] || return 1
    prepare_plugin_root "$plugin_root" || return 1
    for name in "$LSFG_V2_DIRECTORY" '小黄鸭' 'LSFG-VK' 'decky-lsfg-vk' 'Decky.LSFG-VK' "$LSFG_V2_ARCHIVE_DIRECTORY"; do
        path="$plugin_root/$name"
        [ -e "$path" ] || [ -L "$path" ] || continue
        if [ -L "$path" ] || [ ! -d "$path" ] || [ -L "$path/plugin.json" ]; then
            echo '现有小黄鸭插件目录异常，未开始清理，请先检查插件目录。'
            return 1
        fi
        if [ -f "$path/plugin.json" ]; then
            manifest_name="$(python3 - "$path/plugin.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1]))['name'])
except (OSError, ValueError, KeyError, TypeError):
    raise SystemExit(1)
PY
            )" || { echo '现有小黄鸭插件信息无法读取，未开始清理。'; return 1; }
            case "$manifest_name" in
                'Decky LSFG-VK'|'LSFG-VK'|'小黄鸭'|'小黄鸭2.0'|'小黄鸭 2.0') ;;
                *)
                    [ "$name" != "$LSFG_V2_DIRECTORY" ] && continue
                    echo '小黄鸭安装位置被其他插件占用，未开始清理。'
                    return 1
                    ;;
            esac
        elif [ "$name" != "$LSFG_V2_DIRECTORY" ]; then
            continue
        fi
        candidates+=("$name")
    done
    # Also remove renamed copies and abandoned staging folders from older
    # installers, but only when their manifest identifies this exact plugin.
    for path in "$plugin_root"/* "$plugin_root"/.[!.]* "$plugin_root"/..?*; do
        [ -d "$path" ] && [ ! -L "$path" ] && [ -f "$path/plugin.json" ] && [ ! -L "$path/plugin.json" ] || continue
        name="${path##*/}"
        local known=0 candidate
        for candidate in "${candidates[@]}"; do [ "$name" != "$candidate" ] || known=1; done
        [ "$known" -eq 0 ] || continue
        manifest_name="$(python3 - "$path/plugin.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1]))['name'])
except (OSError, ValueError, KeyError, TypeError):
    raise SystemExit(1)
PY
        )" || continue
        case "$manifest_name" in
            'Decky LSFG-VK'|'LSFG-VK'|'小黄鸭'|'小黄鸭2.0'|'小黄鸭 2.0') candidates+=("$name") ;;
        esac
    done

    backup_dir="$(mktemp -d)" || return 1
    # A custom TMPDIR must not put rollback files where Decky scans plugins.
    case "$(cd "$backup_dir" && pwd -P)/" in
        "$(cd "$plugin_root" && pwd -P)/"*) rmdir "$backup_dir"; return 1 ;;
    esac
    finish_lsfg_v2_clean() {
        local status="$1" old_name
        trap - EXIT INT TERM
        if [ "$committed" -ne 1 ] && [ "$resume_attempted" -eq 1 ]; then
            # A failed start can still leave a child process alive. Stop it
            # before restoring files so rollback cannot expose mixed copies.
            if ! toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME"; then
                committed=1
                rollback_failed=1
                echo '插件商城未能停止，已保留新插件和恢复备份，未在运行中替换文件。'
            fi
        fi
        if [ "$committed" -ne 1 ]; then
            if [ "$new_started" -eq 1 ]; then
                run_plugin_file_operation rm -rf -- "$plugin_root/$LSFG_V2_DIRECTORY" || rollback_failed=1
                run_plugin_file_operation rm -rf -- "$plugin_root/.$LSFG_V2_DIRECTORY.new.$$" \
                    "$plugin_root/.$LSFG_V2_DIRECTORY.backup.$$" || rollback_failed=1
            fi
            for old_name in "${displaced[@]}"; do
                run_plugin_file_operation mv -- "$backup_dir/$old_name" "$plugin_root/$old_name" || rollback_failed=1
            done
        fi
        if [ "$service_stopped" -eq 1 ]; then
            toolbox_sudo systemctl start "$DECKY_SERVICE_NAME" || {
                echo '插件商城未能恢复运行，请在检查与维护中重试。'
                status=1
            }
        fi
        if [ "$rollback_failed" -eq 1 ]; then
            echo "小黄鸭恢复未完成，备份已保留：$backup_dir"
            status=1
        else
            run_plugin_file_operation rm -rf -- "$backup_dir" || {
                toolbox_sudo rm -rf -- "$backup_dir" || {
                    echo "旧小黄鸭文件备份未能清理：$backup_dir"
                    status=1
                }
            }
        fi
        exit "$status"
    }
    trap 'finish_lsfg_v2_clean $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    echo '正在准备重新安装小黄鸭2.0...'
    toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME" || {
        echo '插件商城未能停止，未清理现有小黄鸭。'
        return 1
    }
    service_stopped=1
    for name in "${candidates[@]}"; do
        run_plugin_file_operation mv -- "$plugin_root/$name" "$backup_dir/$name" || return 1
        displaced+=("$name")
    done
    echo '原有小黄鸭插件已清理，正在安装小黄鸭2.0...'
    new_started=1
    install_tree_atomically "$source_dir" "$plugin_root" "$LSFG_V2_DIRECTORY" || return 1
    lsfg_v2_is_current "$plugin_root" || {
        echo '小黄鸭2.0 文件检查未通过，正在恢复原插件。'
        return 1
    }
    resume_attempted=1
    toolbox_sudo systemctl start "$DECKY_SERVICE_NAME" || {
        echo '插件商城启动失败，正在恢复原插件。'
        return 1
    }
    service_stopped=0
    committed=1
)
