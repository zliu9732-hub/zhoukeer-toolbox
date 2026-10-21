#!/bin/bash

# Invoked only after the explicit cleanup choice. Keep rollback files outside
# plugins so Decky never sees the displaced plugins as duplicate installations.
install_feature_plugins_clean() (
    local lsfg_variant="$1" plugin_root="${DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins}"
    local backup_dir="" entry name
    local service_stopped=0 resume_attempted=0 install_started=0 committed=0
    local rollback_failed=0 displaced=()

    [ "${IS_STEAMOS:-0}" -eq 1 ] || return 1
    if [ -L "$plugin_root" ] || [ ! -d "$plugin_root" ]; then
        echo '插件目录异常，未卸载已有插件。'
        return 1
    fi
    plugin_root="$(cd "$plugin_root" && pwd -P)" || return 1
    if [ "${plugin_root##*/}" != plugins ] || [ "$plugin_root" = "$HOME" ]; then
        echo '插件目录位置异常，未卸载已有插件。'
        return 1
    fi
    prepare_plugin_root "$plugin_root" || return 1
    backup_dir="$(run_plugin_file_operation mktemp -d "${plugin_root%/*}/.renkit-plugin-backup.XXXXXX")" || return 1

    finish_feature_plugins_clean() {
        local status="$1" old_name can_restore=1
        trap - EXIT INT TERM
        if [ "$committed" -ne 1 ] && [ "$resume_attempted" -eq 1 ]; then
            if toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME"; then
                service_stopped=1
            else
                can_restore=0
                rollback_failed=1
                echo '插件商城未能停止，未在运行中替换插件文件。'
            fi
        fi
        if [ "$committed" -ne 1 ] && [ "$can_restore" -eq 1 ]; then
            if [ -L "$plugin_root" ] || [ ! -d "$plugin_root" ]; then
                can_restore=0
                rollback_failed=1
            fi
            if [ "$can_restore" -eq 1 ]; then
                if [ "$install_started" -eq 1 ]; then
                    for entry in "$plugin_root"/* "$plugin_root"/.[!.]* "$plugin_root"/..?*; do
                        [ -e "$entry" ] || [ -L "$entry" ] || continue
                        run_plugin_file_operation rm -rf -- "$entry" || rollback_failed=1
                    done
                fi
                for old_name in "${displaced[@]}"; do
                    if [ -e "$plugin_root/$old_name" ] || [ -L "$plugin_root/$old_name" ]; then
                        rollback_failed=1
                        continue
                    fi
                    run_plugin_file_operation mv -- "$backup_dir/$old_name" "$plugin_root/$old_name" || rollback_failed=1
                done
            fi
        fi
        if [ "$service_stopped" -eq 1 ]; then
            toolbox_sudo systemctl start "$DECKY_SERVICE_NAME" || {
                echo '插件商城未能恢复运行，请在检查与维护中重试。'
                status=1
            }
        fi
        if [ "$rollback_failed" -eq 1 ]; then
            echo "原插件恢复未完成，备份已保留：$backup_dir"
            log "常用插件清理重装恢复未完成，备份保留: $backup_dir"
            status=1
        else
            if [ "$committed" -ne 1 ] && [ "${#displaced[@]}" -gt 0 ]; then
                echo '本次常用插件未装完整，已恢复原有插件。'
                log '常用插件清理重装失败，原插件文件已恢复'
            fi
            run_plugin_file_operation rm -rf -- "$backup_dir" 2>/dev/null || toolbox_sudo rm -rf -- "$backup_dir" || {
                echo "原插件备份未能清理：$backup_dir"
                status=1
            }
        fi
        exit "$status"
    }
    trap 'finish_feature_plugins_clean $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    toolbox_sudo systemctl stop "$DECKY_SERVICE_NAME" || {
        echo '插件商城未能停止，未卸载已有插件。'
        return 1
    }
    service_stopped=1
    for entry in "$plugin_root"/* "$plugin_root"/.[!.]* "$plugin_root"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        name="${entry##*/}"
        run_plugin_file_operation mv -- "$entry" "$backup_dir/$name" || return 1
        displaced+=("$name")
    done
    echo '机器上原有的插件已卸载，正在安装常用插件...'
    log "常用插件安装前已移出原插件: ${#displaced[@]} 项"
    resume_attempted=1
    toolbox_sudo systemctl start "$DECKY_SERVICE_NAME" || return 1
    service_stopped=0
    install_started=1
    install_feature_plugins_selected "$lsfg_variant" || return 1
    toolbox_sudo systemctl start "$DECKY_SERVICE_NAME" || return 1
    committed=1
)
