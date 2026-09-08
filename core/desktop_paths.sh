#!/bin/bash

if [ -n "${RENKIT_DESKTOP_PATHS_LOADED:-}" ]; then
    return 0
fi
RENKIT_DESKTOP_PATHS_LOADED=1

renkit_path_is_in_home() {
    local path="$1"

    case "$path" in
        "$HOME"|"$HOME"/*) ;;
        *) return 1 ;;
    esac
    case "/${path#"$HOME"}/" in
        */../*|*/./*) return 1 ;;
    esac
}

renkit_data_home() {
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"

    if renkit_path_is_in_home "$data_home"; then
        printf '%s\n' "$data_home"
    else
        printf '%s\n' "$HOME/.local/share"
    fi
}

renkit_applications_dir() {
    printf '%s/applications\n' "$(renkit_data_home)"
}

renkit_desktop_dir_from_config() {
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    local value

    [ -r "$config_file" ] || return 1
    value="$(awk -F= '
        $1 == "XDG_DESKTOP_DIR" {
            value = substr($0, index($0, "=") + 1)
        }
        END {
            if (value != "") print value
        }
    ' "$config_file")"
    case "$value" in
        '"$HOME"') value="$HOME" ;;
        '"$HOME/'*'"')
            value="${value#\"\$HOME/}"
            value="${value%\"}"
            value="$HOME/$value"
            ;;
        *) return 1 ;;
    esac
    renkit_path_is_in_home "$value" || return 1
    printf '%s\n' "$value"
}

renkit_desktop_dir() {
    local desktop_dir="${ZHOUKEER_DESKTOP_DIR:-}"

    if [ -n "$desktop_dir" ] && renkit_path_is_in_home "$desktop_dir"; then
        printf '%s\n' "$desktop_dir"
        return 0
    fi
    if command -v xdg-user-dir >/dev/null 2>&1; then
        desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
        if [ -n "$desktop_dir" ] && renkit_path_is_in_home "$desktop_dir"; then
            printf '%s\n' "$desktop_dir"
            return 0
        fi
    fi
    if desktop_dir="$(renkit_desktop_dir_from_config 2>/dev/null)"; then
        printf '%s\n' "$desktop_dir"
        return 0
    fi
    printf '%s/Desktop\n' "$HOME"
}
