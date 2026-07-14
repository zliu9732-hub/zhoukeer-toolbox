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

    actual="$(
        (
            set -u
            # shellcheck disable=SC1090
            source "$file"
            eval "printf '%s' \"\${$key-}\""
        )
    )"

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
        /^RUSTDESK_[A-Z0-9_]+=/ {
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
        /^RUSTDESK_DOWNLOAD=/ { print "RUSTDESK_DOWNLOAD=\"https://custom.example/rustdesk.AppImage\""; next }
        /^RUSTDESK_SHA256=/ { print "RUSTDESK_SHA256=\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""; next }
        /^RUSTDESK_ID_SERVER=/ { print "RUSTDESK_ID_SERVER=\"custom.example:10001\""; next }
        /^RUSTDESK_RELAY_SERVER=/ { print "RUSTDESK_RELAY_SERVER=\"custom.example:10002\""; next }
        /^RUSTDESK_API=/ { print "RUSTDESK_API=\"https://custom.example/api\""; next }
        /^RUSTDESK_KEY=/ { print "RUSTDESK_KEY=\"custom-public-key\""; next }
        /^RUSTDESK_CONFIG_STRING=/ { print "RUSTDESK_CONFIG_STRING=\"custom-config-string\""; next }
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

    assert_value "$config_file" RUSTDESK_DOWNLOAD \
        "https://github.com/rustdesk/rustdesk/releases/download/1.4.6/rustdesk-1.4.6-x86_64.AppImage"
    assert_value "$config_file" RUSTDESK_ID_SERVER "293035.xyz:48845"
    assert_value "$config_file" RUSTDESK_RELAY_SERVER "293035.xyz:48846"
    assert_value "$config_file" RUSTDESK_API "http://293035.xyz:48843"
    assert_value "$config_file" RUSTDESK_KEY \
        "2Vx42GidjDLgp0kT5akymxN3BjXSOLH0QQuhe2TAS4g="
    assert_value "$config_file" RUSTDESK_CONFIG_STRING ""

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

    assert_value "$config_file" RUSTDESK_DOWNLOAD \
        "https://custom.example/rustdesk.AppImage"
    assert_value "$config_file" RUSTDESK_ID_SERVER "custom.example:10001"
    assert_value "$config_file" RUSTDESK_RELAY_SERVER "custom.example:10002"
    assert_value "$config_file" RUSTDESK_API "https://custom.example/api"
    assert_value "$config_file" RUSTDESK_KEY "custom-public-key"
    assert_value "$config_file" RUSTDESK_CONFIG_STRING "custom-config-string"
}

test_missing_config_created() {
    local case_root="$TMP_ROOT/missing"
    local install_dir="$case_root/install"
    local config_file="$install_dir/config/settings.conf"

    run_installer "$case_root/home" "$install_dir"

    [ -f "$config_file" ] || fail "缺少配置时未创建 settings.conf"
    assert_value "$config_file" RUSTDESK_ID_SERVER "293035.xyz:48845"
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

test_blank_config_migration
test_custom_config_preserved
test_missing_config_created
test_dry_run_has_no_side_effects

echo "PASS: 配置迁移测试全部通过"
