#!/bin/bash

set -eu

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_value() {
    local file="$1"
    local key="$2"
    local expected="$3"
    local actual

    actual="$(awk -F= -v wanted="$key" '$1 == wanted { value=$0; sub(/^[^=]*=/, "", value); gsub(/^\"|\"$/, "", value); print value; exit }' "$file")"

    [ "$actual" = "$expected" ] || \
        fail "$key 期望为 '$expected'，实际为 '$actual'"
}

run_installer() {
    local home_dir="$1"
    local install_dir="$2"

    mkdir -p "$home_dir"
    (
        uname() {
            echo Linux
        }
        export -f uname
        HOME="$home_dir" \
            ZHOUKEER_INSTALL_DIR="$install_dir" \
            bash "$PROJECT_ROOT/install.sh" >/dev/null
    )
}

make_blank_config() {
    local destination="$1"

    mkdir -p "$(dirname "$destination")"
    awk '
        /^(TODESK|DECKY)_[A-Z0-9_]+=/ {
            split($0, parts, "=")
            print parts[1] "=\"\""
            next
        }
        { print }
    ' "$PROJECT_ROOT/config/settings.example.conf" > "$destination"
}

make_custom_config() {
    local destination="$1"

    mkdir -p "$(dirname "$destination")"
    awk '
        /^TODESK_ARCHIVE_URL=/ { print "TODESK_ARCHIVE_URL=\"https://custom.example/todesk.tar.gz\""; next }
        { print }
    ' "$PROJECT_ROOT/config/settings.example.conf" > "$destination"
}

test_blank_config_migration() {
    local case_root="$TMP_ROOT/blank"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"
    local backup_count

    make_blank_config "$config_file"
    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" TODESK_PACKAGE_NAME \
        "todesk-bin-4.7.2.0-4-x86_64.pkg.tar.zst"
    assert_value "$config_file" TODESK_PACKAGE_SHA256 \
        "60026e9a7163611cd5feba6ed3d246fa4c9763cb95c04e07da09052243e12a29"
    assert_value "$config_file" DECKY_LSFG_SHA256 \
        "13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"
    assert_value "$config_file" DECKY_LOADER_SHA256 \
        "30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e"
    assert_value "$config_file" DECKY_SERVICE_SHA256 \
        "64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1"
    assert_value "$config_file" DECKY_FSR4_SHA256 \
        "236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"
    assert_value "$config_file" DECKY_CHEATDECK_SHA256 \
        "83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"

    backup_count="$(find "$install_dir/config" -maxdepth 1 -type f \
        -name 'settings.conf.bak.*' | wc -l | tr -d ' ')"
    [ "$backup_count" = "1" ] || fail "首次迁移应创建1份备份，实际为 $backup_count"

    run_installer "$case_root/home" "$install_dir"
    backup_count="$(find "$install_dir/config" -maxdepth 1 -type f \
        -name 'settings.conf.bak.*' | wc -l | tr -d ' ')"
    [ "$backup_count" = "1" ] || fail "重复安装不应新增备份，实际为 $backup_count"
}

test_custom_config_preserved() {
    local case_root="$TMP_ROOT/custom"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    make_custom_config "$config_file"
    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" TODESK_ARCHIVE_URL \
        "https://custom.example/todesk.tar.gz"
}

test_retired_rustdesk_config_removed() {
    local case_root="$TMP_ROOT/retired-rustdesk"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"
    local backup_file="$install_dir/config/settings.conf.bak.old"
    local retired_app="$install_dir/apps/rustdesk.AppImage"

    mkdir -p "$(dirname "$config_file")" "$(dirname "$retired_app")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    printf '%s\n' \
        '# RustDesk服务器配置' \
        'RUSTDESK_ID_SERVER="private.example:10001"' \
        'RUSTDESK_RELAY_SERVER="private.example:10002"' \
        'RUSTDESK_API="https://private.example/api"' \
        'RUSTDESK_KEY="private-public-key"' >> "$config_file"
    cp "$config_file" "$backup_file"
    printf 'retired app\n' > "$retired_app"

    run_installer "$case_root/home" "$install_dir"

    if grep -Eqi 'RUSTDESK|private\.example|private-public-key' "$config_file" "$backup_file"; then
        fail "退役的 RustDesk 服务器配置仍留在配置或备份中"
    fi
    [ ! -e "$retired_app" ] || fail "退役的 RustDesk AppImage 仍留在安装目录中"
}

test_retired_decky_installer_config_removed() {
    local case_root="$TMP_ROOT/retired-decky-installer"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    printf '%s\n' \
        '# Decky Loader 国内安装器。旧配置应被移除。' \
        'DECKY_INSTALLER_URL="https://www.mhhf.com/Deck/install.sh"' \
        'DECKY_INSTALLER_SHA256="retired"' >> "$config_file"

    run_installer "$case_root/home" "$install_dir"

    if grep -Eq 'DECKY_INSTALLER_|/Deck/install\.sh' "$config_file"; then
        fail "退役的Decky外层安装器配置仍留在用户配置中"
    fi
    assert_value "$config_file" DECKY_LOADER_SHA256 \
        "30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e"
    assert_value "$config_file" DECKY_SERVICE_SHA256 \
        "64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1"
}

test_missing_config_created() {
    local case_root="$TMP_ROOT/missing"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    run_installer "$case_root/home" "$install_dir"

    [ -f "$config_file" ] || fail "缺少配置时未创建 settings.conf"
    assert_value "$config_file" TODESK_PACKAGE_NAME \
        "todesk-bin-4.7.2.0-4-x86_64.pkg.tar.zst"
}

test_dry_run_has_no_side_effects() {
    local case_root="$TMP_ROOT/dry-run"
    local install_dir="$case_root/install"
    local output

    mkdir -p "$case_root/home"
    output="$(
        HOME="$case_root/home" \
            ZHOUKEER_INSTALL_DIR="$install_dir" \
            bash "$PROJECT_ROOT/install.sh" --dry-run
    )"

    [ ! -e "$install_dir" ] || fail "dry-run 创建了安装目录"
    printf '%s\n' "$output" | grep -F -q "不会创建目录、复制文件或修改权限" || \
        fail "dry-run 缺少无副作用提示"
}

test_lsfg_chinese_runtime_files_packaged() {
    local case_root="$TMP_ROOT/lsfg-chinese"
    local install_dir="$case_root/install"
    local plugin_dir="$install_dir/third_party/decky-lsfg-vk-zh-v0.12.5"

    run_installer "$case_root/home" "$install_dir"

    [ -s "$plugin_dir/plugin.json" ] || fail "更新包缺少小黄鸭中文清单"
    [ -s "$plugin_dir/package.json" ] || fail "更新包缺少小黄鸭中文模块声明"
    [ -s "$plugin_dir/LICENSE" ] || fail "更新包缺少小黄鸭原始许可证"
    [ -s "$plugin_dir/dist/index.js" ] || fail "更新包缺少小黄鸭中文运行文件"
    [ -d "$plugin_dir/py_modules/lsfg_vk" ] || fail "更新包缺少小黄鸭后端模块"
    [ ! -e "$plugin_dir/node_modules" ] || fail "更新包不应包含小黄鸭中文开发依赖"
}

test_runtime_scripts_packaged() {
    local case_root="$TMP_ROOT/runtime-scripts"
    local install_dir="$case_root/install"

    run_installer "$case_root/home" "$install_dir"

    [ -s "$install_dir/scripts/steam_shortcut.py" ] || \
        fail "安装目录缺少 Epic/战网 Steam 入库组件"
    [ -x "$install_dir/scripts/install-decky-plugin.sh" ] || \
        fail "安装目录缺少可执行的 Decky 官方插件安装脚本"
}

test_install_from_replaced_workdir() {
    local case_root="$TMP_ROOT/replaced-workdir"
    local install_dir="$case_root/install"
    local output

    mkdir -p "$case_root/home" "$install_dir"
    printf 'old install\n' > "$install_dir/old-version.txt"
    output="$(
        cd "$install_dir"
        (
            uname() {
                echo Linux
            }
            export -f uname
            HOME="$case_root/home" \
                ZHOUKEER_INSTALL_DIR="$install_dir" \
                bash "$PROJECT_ROOT/install.sh" 2>&1
        )
    )" || fail "从旧安装目录内执行更新失败"

    if printf '%s\n' "$output" | grep -Eq 'getcwd|无法访问父目录|No such file or directory'; then
        fail "替换安装目录时仍产生失效工作目录错误"
    fi
    [ -s "$install_dir/scripts/steam_shortcut.py" ] || \
        fail "替换更新后 Steam 入库组件缺失"
}

test_blank_config_migration
test_custom_config_preserved
test_retired_rustdesk_config_removed
test_retired_decky_installer_config_removed
test_missing_config_created
test_dry_run_has_no_side_effects
test_lsfg_chinese_runtime_files_packaged
test_runtime_scripts_packaged
test_install_from_replaced_workdir

echo "PASS: 配置迁移测试全部通过"
