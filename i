#!/bin/bash

set -u

GITEE_URL="${ZHOUKEER_GITEE_BOOTSTRAP_URL:-https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/bootstrap.sh}"
GITHUB_URL="${ZHOUKEER_GITHUB_BOOTSTRAP_URL:-https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/bootstrap.sh}"
DOMAIN_URL="${ZHOUKEER_DOMAIN_BOOTSTRAP_URL:-https://jktool.icu/bootstrap.sh}"
TMP_FILE="$(mktemp)" || exit 1
trap 'rm -f -- "$TMP_FILE"' EXIT INT TERM

download_bootstrap() {
    curl \
        --fail \
        --location \
        --show-error \
        --proto '=https' \
        --proto-redir '=https' \
        --connect-timeout 10 \
        --max-time 60 \
        --retry 2 \
        --output "$TMP_FILE" \
        "$1"
}

if download_bootstrap "$DOMAIN_URL"; then
    :
elif download_bootstrap "$GITEE_URL"; then
    :
elif download_bootstrap "$GITHUB_URL"; then
    :
else
    echo "工具箱安装入口下载失败，请检查网络。"
    exit 1
fi

bash -n "$TMP_FILE" || {
    echo "安装入口语法检查失败，已停止。"
    exit 1
}

bash "$TMP_FILE" "$@"
