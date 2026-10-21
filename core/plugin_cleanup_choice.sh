#!/bin/bash

FEATURE_PLUGIN_CLEANUP="${FEATURE_PLUGIN_CLEANUP:-keep}"

feature_plugin_cleanup_label() {
    case "$1" in
        keep) printf '%s\n' '不卸载已有插件' ;;
        remove) printf '%s\n' '卸载已有插件（可能解决有时候报错的问题）' ;;
        *) return 1 ;;
    esac
}

select_feature_plugin_cleanup() {
    local selection="${ZHOUKEER_FEATURE_PLUGIN_CLEANUP:-}"

    FEATURE_PLUGIN_CLEANUP=""
    case "$selection" in
        keep|remove) FEATURE_PLUGIN_CLEANUP="$selection"; return 0 ;;
        '') ;;
        *) echo "已有插件处理选项无效，安装未开始。"; return 1 ;;
    esac

    if command -v kdialog >/dev/null 2>&1; then
        selection="$(kdialog --title '已有插件处理方式' --default keep --menu \
            '请选择安装前如何处理机器上原有的插件。\n\n选择卸载会移除全部已有插件及其目录内的设置，然后安装常用插件；其他插件需自行装回。需要管理员权限，安装失败会尝试恢复原插件。\n选择小黄鸭2.0时，仍会先清理旧的小黄鸭，避免冲突。' \
            keep "$(feature_plugin_cleanup_label keep)" \
            remove "$(feature_plugin_cleanup_label remove)" 2>/dev/null)" || {
                echo "已取消已有插件处理选择，安装未开始。"
                return 1
            }
    else
        echo "1. $(feature_plugin_cleanup_label keep)"
        echo "2. $(feature_plugin_cleanup_label remove)"
        echo "选择卸载会移除全部已有插件及其目录内的设置，然后安装常用插件；其他插件需自行装回。"
        echo "需要管理员权限，安装失败会尝试恢复原插件。"
        echo "选择小黄鸭2.0时，仍会先清理旧的小黄鸭，避免冲突。"
        read -r -p '请选择 [1/2]，回车保留已有插件，其他输入取消：' selection || return 1
        case "$selection" in ''|1) selection=keep ;; 2) selection=remove ;; esac
    fi
    case "$selection" in
        keep|remove) FEATURE_PLUGIN_CLEANUP="$selection" ;;
        *) echo "已取消已有插件处理选择，安装未开始。"; return 1 ;;
    esac
}
