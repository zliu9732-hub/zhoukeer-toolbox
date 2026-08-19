#!/bin/bash

set -u

GITEE_URL="${ZHOUKEER_GITEE_BOOTSTRAP_URL:-https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/bootstrap.sh}"
GITHUB_URL="${ZHOUKEER_GITHUB_BOOTSTRAP_URL:-https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/bootstrap.sh}"
DOMAIN_URL="${ZHOUKEER_DOMAIN_BOOTSTRAP_URL:-https://jktool.icu/bootstrap.sh}"
TMP_FILE="$(mktemp)" || exit 1
trap 'rm -f -- "$TMP_FILE"' EXIT INT TERM

download_bootstrap() {
    local url="$1" size

    rm -f -- "$TMP_FILE"
    if ! curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 8 \
        --max-time 45 \
        --retry 1 \
        --output "$TMP_FILE" \
        "$url"; then
        return 1
    fi
    [ -f "$TMP_FILE" ] && [ ! -L "$TMP_FILE" ] && [ -s "$TMP_FILE" ] || return 1
    size="$(wc -c < "$TMP_FILE" | tr -d ' ')"
    case "$size" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$size" -le 1048576 ] || return 1
    if LC_ALL=C head -c 512 "$TMP_FILE" | \
        grep -Eiq '<(!doctype[[:space:]]+html|html[[:space:]>])|access[[:space:]]+denied|error[[:space:]]+403'; then
        return 1
    fi
    bash -n "$TMP_FILE"
}

if download_bootstrap "$GITEE_URL"; then
    :
elif [ -n "$GITHUB_URL" ] && download_bootstrap "$GITHUB_URL"; then
    :
elif [ -n "$DOMAIN_URL" ] && download_bootstrap "$DOMAIN_URL"; then
    :
else
    echo "Renkit安装入口下载失败，请检查网络。"
    exit 1
fi

bash "$TMP_FILE" "$@"
