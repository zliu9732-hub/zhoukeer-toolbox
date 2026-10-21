#!/bin/bash

LSFG_INSTALL_VARIANT="${LSFG_INSTALL_VARIANT:-legacy}"

lsfg_variant_label() {
    case "$1" in
        legacy) printf '%s\n' '旧版小黄鸭' ;;
        v2) printf '%s\n' '小黄鸭2.0（需要正版小黄鸭本体并切换到 lsfg 分支）' ;;
        *) return 1 ;;
    esac
}

select_lsfg_variant() {
    local selection="${ZHOUKEER_LSFG_VARIANT:-}"

    LSFG_INSTALL_VARIANT=""
    case "$selection" in
        legacy|v2) LSFG_INSTALL_VARIANT="$selection"; return 0 ;;
        '') ;;
        *) echo "小黄鸭版本选项无效，安装未开始。"; return 1 ;;
    esac

    if command -v kdialog >/dev/null 2>&1; then
        selection="$(kdialog --title '选择小黄鸭版本' --menu \
            '请选择本次要安装的小黄鸭版本。\n\n选择 2.0 会清理已有的 1.0 或 2.0 插件后重新安装；Steam 中需要选择的分支名称是 lsfg-vk。' \
            legacy "$(lsfg_variant_label legacy)" \
            v2 "$(lsfg_variant_label v2)" 2>/dev/null)" || {
                echo "已取消小黄鸭版本选择，安装未开始。"
                return 1
            }
    else
        echo "1. $(lsfg_variant_label legacy)"
        echo "2. $(lsfg_variant_label v2)"
        echo "选择 2.0 会先清理已有小黄鸭插件；Steam 分支名称为 lsfg-vk。"
        read -r -p '请选择小黄鸭版本 [1/2]，其他输入取消：' selection || return 1
        case "$selection" in 1) selection=legacy ;; 2) selection=v2 ;; esac
    fi
    case "$selection" in
        legacy|v2) LSFG_INSTALL_VARIANT="$selection" ;;
        *) echo "已取消小黄鸭版本选择，安装未开始。"; return 1 ;;
    esac
}
