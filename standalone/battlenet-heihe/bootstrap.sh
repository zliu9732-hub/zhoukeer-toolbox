#!/bin/bash

# 战网 + 黑盒工坊独立工具一行安装/更新引导
# 用法:
#   curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/standalone/battlenet-heihe/bootstrap.sh | bash
#   带目标: ... | bash -s -- battlenet

set -u

BASE="${ZHOUKEER_STANDALONE_BASE:-https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main}"
TARGET_DIR="${ZHOUKEER_STANDALONE_DIR:-$HOME/zhoukeer-battlenet-heihe}"
VERSION="${ZHOUKEER_STANDALONE_VERSION:-2.0.1}"
TMP_DIR="$(mktemp -d)" || exit 1
trap 'rm -rf -- "$TMP_DIR"' EXIT

case "${1:-}" in
    --help|-h)
        echo "用法: curl -fsSL <本脚本地址> | bash"
        echo "可选参数: battlenet|heihe 直接指定安装目标"
        exit 0
        ;;
esac

command -v curl >/dev/null 2>&1 || {
    echo "缺少命令: curl"
    exit 1
}
if command -v sha256sum >/dev/null 2>&1; then
    SHA_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    SHA_TOOL="shasum -a 256"
else
    echo "缺少 SHA256 校验命令: sha256sum 或 shasum"
    exit 1
fi
command -v tar >/dev/null 2>&1 || {
    echo "缺少命令: tar"
    exit 1
}

case "$VERSION" in
    ''|*[!A-Za-z0-9._+-]*)
        echo "远程版本格式无效。"
        exit 1
        ;;
    *)
        [ "${#VERSION}" -le 64 ] || {
            echo "远程版本格式无效。"
            exit 1
        }
        ;;
esac

PACKAGE_NAME="zhoukeer-battlenet-heihe-$VERSION.tar.gz"
PACKAGE_PATH="$TMP_DIR/$PACKAGE_NAME"
SHA_PATH="$TMP_DIR/$PACKAGE_NAME.sha256"

echo "正在下载战网 + 黑盒工坊独立工具 V$VERSION..."
curl -fsSL --proto '=https' --connect-timeout 10 --max-time 300 \
    -o "$PACKAGE_PATH" "$BASE/dist/$PACKAGE_NAME" || {
    echo "独立工具下载失败，旧版本不会被覆盖。"
    exit 1
}
curl -fsSL --proto '=https' --connect-timeout 10 --max-time 30 \
    -o "$SHA_PATH" "$BASE/dist/$PACKAGE_NAME.sha256" || {
    echo "独立工具校验文件下载失败，旧版本不会被覆盖。"
    exit 1
}

echo "正在校验独立工具完整性..."
if ! (cd "$TMP_DIR" && $SHA_TOOL -c "$PACKAGE_NAME.sha256" >/dev/null 2>&1); then
    echo "独立工具 SHA256 校验失败，已停止安装。"
    exit 1
fi

if ! tar -tzf "$PACKAGE_PATH" | grep -Fxq './install.sh'; then
    echo "独立工具包结构异常，已停止安装。"
    exit 1
fi

echo "正在准备独立工具..."
mkdir -p "$TARGET_DIR" || exit 1
tar --no-xattrs --no-same-owner --no-same-permissions \
    -xzf "$PACKAGE_PATH" -C "$TARGET_DIR" || {
    echo "独立工具解压失败，已停止安装。"
    exit 1
}

echo "独立工具已准备：$TARGET_DIR"
bash "$TARGET_DIR/install.sh" "$@"
status=$?
exit "$status"
