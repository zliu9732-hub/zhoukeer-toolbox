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
    cp "$PROJECT_ROOT/config/settings.example.conf" "$destination"
    printf '%s\n' \
        '# ToDesk第三方SteamOS安装包。' \
        'TODESK_ARCHIVE_URL="https://custom.example/todesk.tar.gz"' \
        'TODESK_REPOSITORY_URL="https://gitee.com/mclanbai/archtodesk.git"' \
        'TODESK_REPOSITORY_COMMIT="b2b63a834c0fcb77ff87c1424d6c393804d8e1af"' \
        'TODESK_PACKAGE_NAME="todesk-bin-4.7.2.0-4-x86_64.pkg.tar.zst"' \
        'TODESK_PACKAGE_SHA256="60026e9a7163611cd5feba6ed3d246fa4c9763cb95c04e07da09052243e12a29"' \
        >> "$destination"
}

test_blank_config_migration() {
    local case_root="$TMP_ROOT/blank"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"
    local backup_count

    make_blank_config "$config_file"
    run_installer "$case_root/home" "$install_dir"

    if grep -Eq 'TODESK_|mclanbai/archtodesk' "$config_file"; then
        fail "空配置迁移后仍包含退役的 ToDesk 第三方来源"
    fi
    assert_value "$config_file" DECKY_LSFG_SHA256 \
        "13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"
    assert_value "$config_file" DECKY_LOADER_SHA256 \
        "30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e"
    assert_value "$config_file" DECKY_SERVICE_SHA256 \
        "64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1"
    assert_value "$config_file" DECKY_FSR4_SHA256 \
        "3300b617e3d979b483d03f995c75c829d6d54beaa4ac8dfae300c2560e4fc60f"
    assert_value "$config_file" DECKY_CHEATDECK_SHA256 \
        "32e2931f9ca8083c1605f04b4ed089b0bf210f79db236a7fd34f02c519e902d9"
    assert_value "$config_file" DECKY_TOMOON_SHA256 \
        "5500e6ed2d110b0e077b9eba3f1908eb50593483e51158b9351978d9a03191a6"
    assert_value "$config_file" DECKY_DECKRECALL_SHA256 \
        "a460f06f2ff812ad075886728c2140ebbedbcf9db7d6e078eee25a4b058f950c"
    assert_value "$config_file" DECKY_SAVEPULSE_SHA256 \
        "28c150fc7639c51ed7b3b28b70b6a3cd3cbe92b5ac683917129661a1e02b8b1f"
    assert_value "$config_file" DECKY_SAVEPULSE_VERSION "0.1.0-alpha.1"

    backup_count="$(find "$install_dir/config" -maxdepth 1 -type f \
        -name 'settings.conf.bak.*' | wc -l | tr -d ' ')"
    [ "$backup_count" = "1" ] || fail "首次迁移应创建1份备份，实际为 $backup_count"

    run_installer "$case_root/home" "$install_dir"
    backup_count="$(find "$install_dir/config" -maxdepth 1 -type f \
        -name 'settings.conf.bak.*' | wc -l | tr -d ' ')"
    [ "$backup_count" = "1" ] || fail "重复安装不应新增备份，实际为 $backup_count"
}

test_retired_todesk_config_removed() {
    local case_root="$TMP_ROOT/custom"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    make_custom_config "$config_file"
    run_installer "$case_root/home" "$install_dir"

    if grep -Eq 'TODESK_|mclanbai/archtodesk|custom\.example/todesk' "$config_file"; then
        fail "升级后仍保留退役的 ToDesk 第三方配置"
    fi
}

test_chinese_plugin_hashes_migrated() {
    local case_root="$TMP_ROOT/chinese-plugin-hashes"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    sed -i.bak \
        -e 's/11e3c13673e19662364cd86d77d6df7bf636c026ccaa2842421c37b982f73277/9eed12dc0bb0ca1967e57d55c230e6522c9b8c70d1b8337929d5ec0066c2a4cd/' \
        -e 's/dde3fe2d77f3021f2841d9dba31b5fa6a741fc08ba9639508787b20054268608/4b9c8939028919e8bcb76c37c75b9dfc2e84d4fd1d2534521606dc70f0789ad0/' \
        "$config_file"

    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" DECKY_LSFG_ZH_SHA256 \
        "11e3c13673e19662364cd86d77d6df7bf636c026ccaa2842421c37b982f73277"
    assert_value "$config_file" DECKY_FSR4_ZH_SHA256 \
        "dde3fe2d77f3021f2841d9dba31b5fa6a741fc08ba9639508787b20054268608"
}

test_chinese_plugin_v504_hashes_migrated() {
    local case_root="$TMP_ROOT/chinese-plugin-v504-hashes"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    sed -i.bak \
        -e 's/11e3c13673e19662364cd86d77d6df7bf636c026ccaa2842421c37b982f73277/d1dbe2cdc83cdf846a12fb2a33e96f8a08e52fd5b05e0305c05c82c288b9c0d4/' \
        -e 's/dde3fe2d77f3021f2841d9dba31b5fa6a741fc08ba9639508787b20054268608/09148bd445abb713278151f3a9e142f5bb8227704163b8f272e41c44e0e71d50/' \
        "$config_file"

    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" DECKY_LSFG_ZH_SHA256 \
        "11e3c13673e19662364cd86d77d6df7bf636c026ccaa2842421c37b982f73277"
    assert_value "$config_file" DECKY_FSR4_ZH_SHA256 \
        "dde3fe2d77f3021f2841d9dba31b5fa6a741fc08ba9639508787b20054268608"
}

test_retired_freedeck_url_migrated() {
    local case_root="$TMP_ROOT/retired-freedeck"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    sed -i.bak \
        -e 's|https://github.com/panyiwei-home/Freedeck/releases/download/0.6/freedeck.v.0.6.zip|https://github.com/panyiwei-home/Freedeck/archive/refs/tags/0.6.zip|' \
        "$config_file"

    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" DECKY_FREEDECK_URL \
        "https://github.com/panyiwei-home/Freedeck/releases/download/0.6/freedeck.v.0.6.zip"
}

test_retired_unifideck_default_migrated() {
    local case_root="$TMP_ROOT/retired-unifideck"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    sed -i.bak \
        -e 's|Release-0.7.2/unifideck.prod.v0.7.2.zip|Release-0.7/unifideck.prod.v0.7.0.zip|' \
        -e 's/DECKY_UNIFIDECK_VERSION="0.7.2"/DECKY_UNIFIDECK_VERSION="0.7.0"/' \
        -e 's/a313be924cabe15255d222742a402cd98cb510a35dfe4b2d06cf1e59366936de/4715b74d0033b8c1587040e90c1d19b925c7110c7723926605aa62128c4c03e0/' \
        "$config_file"

    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" DECKY_UNIFIDECK_URL \
        "https://github.com/mubaraknumann/unifideck/releases/download/Release-0.7.2/unifideck.prod.v0.7.2.zip"
    assert_value "$config_file" DECKY_UNIFIDECK_VERSION "0.7.2"
    assert_value "$config_file" DECKY_UNIFIDECK_SHA256 \
        "a313be924cabe15255d222742a402cd98cb510a35dfe4b2d06cf1e59366936de"
}

test_retired_deckrecall_default_migrated() {
    local case_root="$TMP_ROOT/retired-deckrecall"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    sed -i.bak \
        -e 's|releases/download/v0.3.2/DeckRecall.zip|releases/download/v0.2.8/DeckRecall.zip|' \
        -e 's/a460f06f2ff812ad075886728c2140ebbedbcf9db7d6e078eee25a4b058f950c/360dfc3897a00ceee8c31492e0a36428da956fdbe0cbd185cd8d52b58df67ac4/' \
        "$config_file"

    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" DECKY_DECKRECALL_URL \
        "https://github.com/Ren-Amamiya-pixle/DeckRecall/releases/download/v0.3.2/DeckRecall.zip"
    assert_value "$config_file" DECKY_DECKRECALL_SHA256 \
        "a460f06f2ff812ad075886728c2140ebbedbcf9db7d6e078eee25a4b058f950c"
}

test_custom_unifideck_version_preserved() {
    local case_root="$TMP_ROOT/custom-unifideck"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    mkdir -p "$(dirname "$config_file")"
    cp "$PROJECT_ROOT/config/settings.example.conf" "$config_file"
    sed -i.bak \
        's/DECKY_UNIFIDECK_VERSION="0.7.2"/DECKY_UNIFIDECK_VERSION="10.7.0-custom"/' \
        "$config_file"

    run_installer "$case_root/home" "$install_dir"

    assert_value "$config_file" DECKY_UNIFIDECK_VERSION "10.7.0-custom"
}

test_retired_rustdesk_config_removed_app_preserved() {
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
    [ "$(cat "$retired_app")" = "retired app" ] || \
        fail "迁移旧 RustDesk 配置时不应删除用户已有的 AppImage"
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
    if grep -Eq 'TODESK_|mclanbai/archtodesk' "$config_file"; then
        fail "新配置仍包含退役的 ToDesk 第三方来源"
    fi
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

    [ -s "$plugin_dir/plugin.json" ] || fail "更新包缺少小黄鸭清单"
    [ -s "$plugin_dir/package.json" ] || fail "更新包缺少小黄鸭模块声明"
    [ -s "$plugin_dir/LICENSE" ] || fail "更新包缺少小黄鸭原始许可证"
    [ -s "$plugin_dir/dist/index.js" ] || fail "更新包缺少小黄鸭运行文件"
    [ ! -e "$plugin_dir/dist/index.js.map" ] || fail "更新包不应包含小黄鸭调试映射"
    [ -d "$plugin_dir/py_modules/lsfg_vk" ] || fail "更新包缺少小黄鸭后端模块"
    [ ! -e "$plugin_dir/node_modules" ] || fail "更新包不应包含小黄鸭开发依赖"
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

test_fsr4_list_and_cssloader_overlay_packaged() {
    local case_root="$TMP_ROOT/fsr4-list-cssloader"
    local install_dir="$case_root/install"
    local game_list="$install_dir/data/fsr4_optiscaler_tested_games_2026-08-07.txt"
    local css_dir="$install_dir/third_party/cssloader-zh-v2.1.2"

    run_installer "$case_root/home" "$install_dir"

    [ -s "$game_list" ] || fail "安装目录缺少 FSR4 官方兼容游戏清单"
    [ "$(grep -vc '^#' "$game_list")" -eq 683 ] || \
        fail "安装后的 FSR4 官方兼容游戏清单条目数不正确"
    [ -s "$css_dir/plugin.json" ] || fail "安装目录缺少 CSS Loader 中文清单"
    [ -s "$css_dir/package.json" ] || fail "安装目录缺少 CSS Loader 版本文件"
    [ -s "$css_dir/LICENSE" ] || fail "安装目录缺少 CSS Loader 许可证"
    [ -s "$css_dir/dist/index.js" ] || fail "安装目录缺少 CSS Loader 中文前端"
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
test_retired_todesk_config_removed
test_chinese_plugin_hashes_migrated
test_chinese_plugin_v504_hashes_migrated
test_retired_freedeck_url_migrated
test_retired_unifideck_default_migrated
test_retired_deckrecall_default_migrated
test_custom_unifideck_version_preserved
test_retired_rustdesk_config_removed_app_preserved
test_retired_decky_installer_config_removed
test_missing_config_created
test_dry_run_has_no_side_effects
test_lsfg_chinese_runtime_files_packaged
test_runtime_scripts_packaged
test_fsr4_list_and_cssloader_overlay_packaged
test_install_from_replaced_workdir

echo "PASS: 配置迁移测试全部通过"
