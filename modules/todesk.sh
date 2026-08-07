#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

TODESK_CONNECT_TIMEOUT=15
TODESK_MAX_TIME=1200
TODESK_READONLY_CHANGED=0
TODESK_TMP_DIR=""
TODESK_DOWNLOADED_PACKAGE=""
TODESK_ORPHAN_BACKUP=""
TODESK_ORPHAN_CANDIDATES="${ZHOUKEER_TEST_TODESK_ORPHAN_PATHS:-/opt/todesk /usr/bin/todesk /usr/local/bin/todesk /usr/lib/systemd/system/todeskd.service /etc/systemd/system/todeskd.service /usr/share/applications/todesk.desktop}"
TODESK_CA_BUNDLE_PATHS="${TODESK_CA_BUNDLE_PATHS:-/etc/ssl/certs/ca-certificates.crt:/etc/ca-certificates/extracted/tls-ca-bundle.pem}"
TODESK_PACMAN_CACHE_DIR="${TODESK_PACMAN_CACHE_DIR:-/var/cache/pacman/pkg}"
TODESK_VERSION="4.8.6.2"
TODESK_PACKAGE_VERSION="4.8.6.2-1"
TODESK_OFFICIAL_DEB_NAME="todesk-v4.8.6.2-amd64.deb"
TODESK_RELEASE_DEB_URL="https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/v6.0.25/todesk-v4.8.6.2-amd64.deb"
TODESK_OFFICIAL_DEB_URL="https://dl.todesk.com/linux/todesk-v4.8.6.2-amd64.deb"
TODESK_OFFICIAL_DEB_SHA256="b3f2af7fc120948903df3aa455955cb5823fb5c1f5ec7dca17ac8a4cba53c808"
TODESK_OFFICIAL_DEB_MIN_BYTES=94371840
TODESK_LOCAL_PACKAGE_NAME="todesk-bin-4.8.6.2-1-x86_64.pkg.tar.zst"

cleanup_todesk() {
    if [ -n "$TODESK_TMP_DIR" ] && [ -d "$TODESK_TMP_DIR" ]; then
        rm -rf -- "$TODESK_TMP_DIR"
    fi

    if [ "$TODESK_READONLY_CHANGED" -eq 1 ]; then
        echo "正在恢复 SteamOS 只读保护..."
        if ! toolbox_sudo steamos-readonly enable; then
            echo "警告：未能恢复只读保护，请执行: sudo steamos-readonly enable"
            log "ToDesk安装警告: 未能恢复SteamOS只读保护"
            return 1
        fi
        TODESK_READONLY_CHANGED=0
        echo "SteamOS 只读保护已恢复。"
    fi
}

calculate_sha256() {
    local file="$1"
    local output

    if command -v sha256sum >/dev/null 2>&1; then
        output="$(sha256sum -- "$file")" || return 1
    elif command -v shasum >/dev/null 2>&1; then
        output="$(shasum -a 256 -- "$file")" || return 1
    else
        return 1
    fi

    printf '%s\n' "${output%% *}"
}

validate_todesk_settings() {
    [ -n "$TODESK_VERSION" ] && [ -n "$TODESK_PACKAGE_VERSION" ] && \
        [ -n "$TODESK_OFFICIAL_DEB_NAME" ] && \
        [ -n "$TODESK_RELEASE_DEB_URL" ] && \
        [ -n "$TODESK_OFFICIAL_DEB_URL" ] && \
        [ -n "$TODESK_OFFICIAL_DEB_SHA256" ] && \
        [ -n "$TODESK_LOCAL_PACKAGE_NAME" ] || {
        echo "ToDesk官方包配置不完整，请更新Renkit。"
        return 1
    }
    [ "${#TODESK_OFFICIAL_DEB_SHA256}" -eq 64 ] || {
        echo "ToDesk SHA256必须是64位十六进制字符串。"
        return 1
    }
    case "$TODESK_OFFICIAL_DEB_SHA256" in
        *[!0-9A-Fa-f]*)
            echo "ToDesk SHA256包含无效字符。"
            return 1
            ;;
    esac
    case "$TODESK_OFFICIAL_DEB_URL" in
        https://dl.todesk.com/linux/*.deb) ;;
        *) echo "ToDesk官方包地址不符合受控规则。"; return 1 ;;
    esac
    case "$TODESK_RELEASE_DEB_URL" in
        https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/download/v6.0.25/todesk-v4.8.6.2-amd64.deb) ;;
        *) echo "ToDesk镜像地址不符合受控规则。"; return 1 ;;
    esac
    download_policy_url_allowed "$TODESK_RELEASE_DEB_URL" || {
        echo "ToDesk镜像地址不在受控来源清单中。"
        return 1
    }
    download_policy_url_allowed "$TODESK_OFFICIAL_DEB_URL" || {
        echo "ToDesk官方包地址不在受控来源清单中。"
        return 1
    }
    case "$TODESK_OFFICIAL_DEB_MIN_BYTES" in
        ''|*[!0-9]*) echo "ToDesk官方包大小下限无效。"; return 1 ;;
    esac
}

show_todesk_warning() {
    echo "================================"
    echo " ToDesk SteamOS 安装说明"
    echo "================================"
    echo "来源：ToDesk 官方 Linux 安装包"
    echo "版本：$TODESK_VERSION"
    echo ""
    echo "使用前必须先在游戏模式完成："
    echo "1. Steam键 → 设置 → 系统 → 开启“启用开发者模式”"
    echo "2. 返回设置侧栏 → 进入“开发者”"
    echo "3. 在开发者页面的“杂项”中开启“使用旧版X11桌面模式”"
    echo "4. 重新进入桌面模式后再安装并启动ToDesk"
    echo ""
    echo "该操作将："
    echo "- 通过Renkit受控镜像下载未修改的ToDesk官方DEB并校验固定SHA256"
    echo "- 在本机转换为SteamOS软件包，不执行官方DEB自带的维护脚本"
    echo "- 优先读取桌面管理员密码.txt自动验证，记录不可用时由系统询问"
    echo "- 临时关闭SteamOS只读保护"
    echo "- 使用pacman安装系统软件并启用todeskd服务"
    echo "- 不安装yay、AUR或第三方ToDesk软件包"
    echo "- 完成后恢复SteamOS只读保护"
    echo ""
    echo "SteamOS系统更新可能移除通过pacman安装的软件。"
    echo "本工具不会删除已有ToDesk配置，也不会使用 chmod 777。"
}

confirm_todesk_install() {
    local answer

    show_todesk_warning
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        echo "新机初始化已确认，继续ToDesk安装。"
        return 0
    fi

    echo ""
    read -r -p "确认安装请输入 INSTALL：" answer
    [ "$answer" = "INSTALL" ]
}

confirm_todesk_service_repair() {
    local answer

    echo "ToDesk程序已经安装，将修复后台服务并恢复旧版遗留的启用链接。"
    echo "该操作会临时关闭 SteamOS 只读保护，完成后立即恢复；不会重新下载或安装软件包。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" = "1" ]; then
        return 0
    fi
    read -r -p "确认修复请输入 REPAIR：" answer
    [ "$answer" = "REPAIR" ]
}

todesk_is_installed() {
    todesk_installed_version >/dev/null 2>&1
}

todesk_installed_version() {
    local query package_name package_version extra

    command -v pacman >/dev/null 2>&1 || return 1
    query="$(pacman -Q todesk-bin 2>/dev/null)" || return 1
    read -r package_name package_version extra <<< "$query"
    [ "$package_name" = "todesk-bin" ] && [ -n "$package_version" ] && \
        [ -z "$extra" ] || return 1
    printf '%s\n' "$package_version"
}

validate_todesk_payload_archive() {
    local archive="$1" member normalized

    bsdtar -tf "$archive" >/dev/null 2>&1 || {
        echo "ToDesk官方包的数据归档无法读取。"
        return 1
    }
    while IFS= read -r member; do
        normalized="${member#./}"
        case "/$normalized/" in
            */../*|*/./*) echo "ToDesk官方包包含不安全路径。"; return 1 ;;
        esac
        case "$normalized" in
            ''|etc|etc/|etc/systemd|etc/systemd/|etc/systemd/system|etc/systemd/system/|etc/systemd/system/todeskd.service|\
            opt|opt/|opt/todesk|opt/todesk/|opt/todesk/*|\
            usr|usr/|usr/local|usr/local/|usr/local/bin|usr/local/bin/|usr/local/bin/todesk|\
            usr/share|usr/share/|usr/share/applications|usr/share/applications/|usr/share/applications/todesk.desktop|\
            usr/share/icons|usr/share/icons/|usr/share/icons/hicolor|usr/share/icons/hicolor/|usr/share/icons/hicolor/*) ;;
            *) echo "ToDesk官方包包含预期目录以外的文件：$normalized"; return 1 ;;
        esac
    done < <(bsdtar -tf "$archive")
}

validate_todesk_payload_tree() {
    local root="$1" required link target link_dir

    for required in \
        opt/todesk/bin/ToDesk \
        opt/todesk/bin/ToDesk_Service \
        opt/todesk/bin/ToDesk_Session \
        usr/local/bin/todesk \
        usr/share/applications/todesk.desktop \
        etc/systemd/system/todeskd.service; do
        [ -f "$root/$required" ] && [ ! -L "$root/$required" ] || {
            echo "ToDesk官方包缺少必要文件：$required"
            return 1
        }
    done
    if find "$root" \( -type b -o -type c -o -type p -o -type s \) \
        -print -quit | grep -q .; then
        echo "ToDesk官方包包含不支持的特殊文件。"
        return 1
    fi
    while IFS= read -r link; do
        case "$link" in "$root/opt/todesk/bin/"*) ;; *) return 1 ;; esac
        target="$(readlink "$link")" || return 1
        case "$target" in ''|*/*|*..*) return 1 ;; esac
        link_dir="${link%/*}"
        [ -f "$link_dir/$target" ] || return 1
    done < <(find "$root" -type l -print)
    grep -Fxq 'ExecStart=/opt/todesk/bin/ToDesk_Service' \
        "$root/etc/systemd/system/todeskd.service" || return 1
    grep -Fxq 'User=root' "$root/etc/systemd/system/todeskd.service" || return 1
    grep -Fq 'Exec=env LIBVA_DRIVER_NAME=iHD' \
        "$root/usr/share/applications/todesk.desktop" || return 1
}

build_todesk_pacman_package() {
    local deb_file="$1"
    local outer_members control_archive data_archive control_text
    local payload_root package_root package_file installed_size build_date

    outer_members="$(bsdtar -tf "$deb_file" 2>/dev/null)" || return 1
    [ "$(printf '%s\n' "$outer_members" | grep -Fxc 'debian-binary')" -eq 1 ] && \
        [ "$(printf '%s\n' "$outer_members" | grep -Fxc 'control.tar.zst')" -eq 1 ] && \
        [ "$(printf '%s\n' "$outer_members" | grep -Fxc 'data.tar.zst')" -eq 1 ] && \
        [ "$(printf '%s\n' "$outer_members" | wc -l | tr -d ' ')" -eq 3 ] || {
        echo "ToDesk官方DEB目录结构不符合预期。"
        return 1
    }

    control_archive="$TODESK_TMP_DIR/control.tar.zst"
    data_archive="$TODESK_TMP_DIR/data.tar.zst"
    bsdtar -xOf "$deb_file" control.tar.zst > "$control_archive" || return 1
    bsdtar -xOf "$deb_file" data.tar.zst > "$data_archive" || return 1
    control_text="$(bsdtar -xOf "$control_archive" ./control 2>/dev/null)" || return 1
    printf '%s\n' "$control_text" | grep -Fxq 'Package: ToDesk' || return 1
    printf '%s\n' "$control_text" | grep -Fxq "Version: $TODESK_VERSION" || return 1
    printf '%s\n' "$control_text" | grep -Fxq 'Architecture: amd64' || return 1
    printf '%s\n' "$control_text" | grep -Fxq 'Depends: libgtk-3-0' || return 1
    validate_todesk_payload_archive "$data_archive" || return 1

    payload_root="$TODESK_TMP_DIR/payload"
    package_root="$TODESK_TMP_DIR/package-root"
    mkdir -p "$payload_root" "$package_root" || return 1
    bsdtar -xf "$data_archive" -C "$payload_root" || return 1
    validate_todesk_payload_tree "$payload_root" || return 1
    cp -a -- "$payload_root/." "$package_root/" || return 1

    mkdir -p "$package_root/opt/todesk/config" \
        "$package_root/usr/bin" "$package_root/usr/lib/systemd/system" || return 1
    chmod 755 "$package_root/opt/todesk/config" || return 1
    mv -- "$package_root/usr/local/bin/todesk" "$package_root/usr/bin/todesk" || return 1
    mv -- "$package_root/etc/systemd/system/todeskd.service" \
        "$package_root/usr/lib/systemd/system/todeskd.service" || return 1
    rmdir "$package_root/usr/local/bin" "$package_root/usr/local" \
        "$package_root/etc/systemd/system" "$package_root/etc/systemd" \
        "$package_root/etc" 2>/dev/null || return 1

    installed_size="$(du -sk "$package_root" | awk '{print $1 * 1024}')" || return 1
    build_date="$(date +%s)" || return 1
    case "$installed_size:$build_date" in *[!0-9:]*) return 1 ;; esac
    printf '%s\n' \
        '# Generated locally by zhoukeer-toolbox from the official ToDesk DEB' \
        'pkgname = todesk-bin' \
        'pkgbase = todesk-bin' \
        "pkgver = $TODESK_PACKAGE_VERSION" \
        'pkgdesc = Official ToDesk Linux client converted locally for SteamOS' \
        'url = https://www.todesk.com/' \
        "builddate = $build_date" \
        'packager = zhoukeer-toolbox local converter' \
        "size = $installed_size" \
        'arch = x86_64' \
        'license = custom' \
        'provides = todesk' \
        'conflict = todesk' \
        'depend = gtk3' > "$package_root/.PKGINFO" || return 1

    package_file="$TODESK_TMP_DIR/$TODESK_LOCAL_PACKAGE_NAME"
    (cd "$package_root" && bsdtar --uid 0 --gid 0 --uname root --gname root \
        -a -cf "$package_file" .PKGINFO opt usr) || return 1
    bsdtar -xOf "$package_file" .PKGINFO 2>/dev/null | \
        grep -Fxq "pkgver = $TODESK_PACKAGE_VERSION" || return 1
    TODESK_DOWNLOADED_PACKAGE="$package_file"
}

download_todesk_package() {
    local deb_file actual_sha256 expected_sha256 file_size

    mkdir -p "$APP_DIR" || return 1
    TODESK_TMP_DIR="$(mktemp -d "$APP_DIR/.todesk-download.XXXXXX")" || return 1
    deb_file="$TODESK_TMP_DIR/$TODESK_OFFICIAL_DEB_NAME"
    expected_sha256="$(printf '%s' "$TODESK_OFFICIAL_DEB_SHA256" | tr '[:upper:]' '[:lower:]')"

    if ! download_gitee_mirror_file \
        "todesk" "$deb_file" "$expected_sha256" "ToDesk官方安装包"; then
        if ! GITHUB_MAX_TIME="$TODESK_MAX_TIME" GITHUB_RETRIES=3 \
            download_github_file "$TODESK_RELEASE_DEB_URL" "$deb_file" \
                "$expected_sha256" "ToDesk官方安装包"; then
            rm -f -- "$deb_file"
            echo "ToDesk镜像下载失败，正在尝试官网..."
            if ! curl --fail --location --progress-meter \
                --proto '=https' --proto-redir '=https' \
                --connect-timeout "$TODESK_CONNECT_TIMEOUT" --max-time "$TODESK_MAX_TIME" \
                --retry 3 --retry-delay 2 --retry-connrefused \
                --speed-limit 65536 --speed-time 60 \
                --max-filesize "$(download_policy_max_bytes "$TODESK_OFFICIAL_DEB_URL")" \
                --user-agent 'Mozilla/5.0' \
                --output "$deb_file" "$TODESK_OFFICIAL_DEB_URL" \
                2> >(download_progress_filter "ToDesk" >&2); then
                rm -f -- "$deb_file"
                echo "ToDesk下载失败，请稍后重试。"
                return 1
            fi
        fi
    fi

    if ! download_policy_response_is_safe "$TODESK_OFFICIAL_DEB_URL" "$deb_file"; then
        rm -f -- "$deb_file"
        echo "ToDesk安装包格式异常，已停止安装。"
        return 1
    fi
    file_size="$(download_policy_file_size "$deb_file")" || return 1
    [ "$file_size" -ge "$TODESK_OFFICIAL_DEB_MIN_BYTES" ] || {
        echo "ToDesk官方包大小异常，已停止安装。"
        return 1
    }
    actual_sha256="$(calculate_sha256 "$deb_file")" || return 1
    [ "$actual_sha256" = "$expected_sha256" ] || {
        echo "ToDesk官方包SHA256校验失败，已停止安装。"
        return 1
    }
    echo "ToDesk官方包校验通过，正在生成SteamOS本地安装包..."
    build_todesk_pacman_package "$deb_file" || {
        echo "ToDesk官方包转换失败，现有安装保持不变。"
        return 1
    }
}

has_trusted_ca_bundle() {
    local candidate
    local IFS=':'
    local candidates=()

    read -r -a candidates <<< "$TODESK_CA_BUNDLE_PATHS"
    for candidate in "${candidates[@]}"; do
        [ -f "$candidate" ] && [ -s "$candidate" ] && return 0
    done
    return 1
}

find_cached_pacman_package() {
    local package_name="$1"

    [ -d "$TODESK_PACMAN_CACHE_DIR" ] || return 1
    find "$TODESK_PACMAN_CACHE_DIR" -maxdepth 1 -type f \
        -name "${package_name}-[0-9]*.pkg.tar.*" -print -quit 2>/dev/null
}

restore_cached_ca_certificates() {
    local certificates_package utils_package

    certificates_package="$(find_cached_pacman_package ca-certificates || true)"
    utils_package="$(find_cached_pacman_package ca-certificates-utils || true)"
    if [ -z "$certificates_package" ] || [ -z "$utils_package" ]; then
        echo "系统 HTTPS 证书文件缺失，且未找到可验证的本机证书缓存。"
        echo "已停止 ToDesk 安装，不会关闭 HTTPS 或签名验证。请先连接稳定网络后执行“初始化软件源”，再重试。"
        return 1
    fi

    echo "检测到系统证书缺失，正在仅使用本机缓存恢复证书组件..."
    if ! toolbox_sudo pacman -U --noconfirm --needed "$certificates_package" "$utils_package"; then
        echo "本机证书缓存恢复失败，已停止 ToDesk 安装。"
        return 1
    fi
    if ! has_trusted_ca_bundle; then
        echo "证书组件恢复后仍未找到可用证书文件，已停止 ToDesk 安装。"
        return 1
    fi
    echo "系统 HTTPS 证书已恢复，将继续安装 ToDesk。"
}

ensure_todesk_ca_certificates() {
    has_trusted_ca_bundle && return 0
    restore_cached_ca_certificates
}

install_verified_todesk_package() {
    local package_path="$1"

    [ -f "$package_path" ] && [ ! -L "$package_path" ] || return 1
    toolbox_sudo pacman -U --noconfirm "$package_path"
}

cleanup_todesk_orphan_files() {
    local path relative_path backup_dir backup_file orphan_count=0
    local backup_paths=""

    for path in $TODESK_ORPHAN_CANDIDATES; do
        [ -e "$path" ] || [ -L "$path" ] || continue
        if ! toolbox_sudo pacman -Qo "$path" >/dev/null 2>&1; then
            backup_paths="$backup_paths ${path#/}"
            orphan_count=$((orphan_count + 1))
        fi
    done
    [ "$orphan_count" -eq 0 ] && return 0

    backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox/todesk-backup"
    mkdir -p "$backup_dir" || return 1
    backup_file="$backup_dir/todesk-orphans-$(date '+%Y%m%d-%H%M%S').tar.gz"
    # shellcheck disable=SC2086
    if ! toolbox_sudo tar -czf "$backup_file" -C / $backup_paths >/dev/null 2>&1; then
        echo "ToDesk 旧文件备份失败，已停止安装。"
        return 1
    fi
    chmod 600 "$backup_file" 2>/dev/null || true

    for path in $backup_paths; do
        relative_path="/$path"
        if [ -d "$relative_path" ] && [ ! -L "$relative_path" ]; then
            if ! toolbox_sudo rm -rf -- "$relative_path"; then
                echo "ToDesk 旧目录清理失败，已停止安装。"
                return 1
            fi
        elif ! toolbox_sudo rm -f -- "$relative_path"; then
            echo "ToDesk 旧文件清理失败，已停止安装。"
            return 1
        fi
    done

    TODESK_ORPHAN_BACKUP="$backup_file"
    echo "检测到未被 pacman 登记的 ToDesk 旧文件，已备份到：$backup_file"
    log "ToDesk 旧文件已备份并清理: $backup_file"
    return 0
}

todesk_service_is_ready() {
    command -v systemctl >/dev/null 2>&1 && \
        systemctl is-enabled --quiet todeskd.service >/dev/null 2>&1 && \
        systemctl is-active --quiet todeskd.service >/dev/null 2>&1
}

configure_todesk_service() {
    echo "正在配置ToDesk后台服务..."
    if ! toolbox_sudo systemctl daemon-reload; then
        echo "ToDesk服务配置刷新失败。"
        return 1
    fi
    # 旧版安装或卸载失败可能留下遮罩或指向旧路径的启用链接。
    # 仅处理 ToDesk 自己的服务，并让 systemd 原子替换冲突链接。
    if ! toolbox_sudo systemctl unmask todeskd.service; then
        echo "ToDesk旧服务遮罩清理失败。"
        return 1
    fi
    if ! toolbox_sudo systemctl enable --force todeskd.service; then
        echo "ToDesk开机服务启用失败。"
        return 1
    fi
    if ! toolbox_sudo systemctl restart todeskd.service; then
        echo "ToDesk后台服务启动失败。"
        return 1
    fi
    if ! todesk_service_is_ready; then
        echo "ToDesk后台服务状态检查未通过。"
        return 1
    fi
}

install_todesk() {
    local package_path
    local readonly_status
    local installed_version
    local repair_service=0

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "ToDesk安装仅支持真实SteamOS环境。"
        return 1
    fi

    installed_version="$(todesk_installed_version 2>/dev/null || true)"
    if [ "$installed_version" = "$TODESK_PACKAGE_VERSION" ]; then
        if todesk_service_is_ready; then
            echo "[已安装] ToDesk $TODESK_VERSION 和后台服务均正常。"
            return 0
        fi
        echo "检测到 ToDesk $TODESK_VERSION 已安装，但后台服务未正常启用，将直接修复服务。"
        repair_service=1
    elif [ -n "$installed_version" ]; then
        echo "检测到旧版 ToDesk $installed_version，将保留配置并更新到 $TODESK_PACKAGE_VERSION。"
    fi

    for command_name in sudo pacman systemctl steamos-readonly; do
        require_command "$command_name" || return 1
    done
    if [ "$repair_service" -eq 0 ]; then
        require_command curl || return 1
        require_command bsdtar || return 1
        validate_todesk_settings || return 1
    fi
    if [ "$repair_service" -eq 1 ]; then
        confirm_todesk_service_repair || {
            echo "已取消ToDesk服务修复。"
            return 0
        }
    else
        confirm_todesk_install || {
            echo "已取消ToDesk安装。"
            return 0
        }
    fi

    trap cleanup_todesk EXIT INT TERM
    if [ "$repair_service" -eq 0 ]; then
        download_todesk_package || return 1
        package_path="$TODESK_DOWNLOADED_PACKAGE"
    fi

    echo "操作需要Steam Deck管理员密码。"
    if ! toolbox_sudo true; then
        echo "管理员验证失败，未修改系统。"
        return 1
    fi

    readonly_status="$(steamos-readonly status 2>/dev/null || true)"
    if printf '%s' "$readonly_status" | grep -qi 'enabled'; then
        # 先登记需要恢复并注册处理，再修改只读状态，避免异常中断留下关闭状态。
        TODESK_READONLY_CHANGED=1
        trap cleanup_todesk EXIT INT TERM
        if ! toolbox_sudo steamos-readonly disable; then
            echo "无法关闭SteamOS只读保护。"
            cleanup_todesk
            TODESK_READONLY_CHANGED=0
            trap - EXIT INT TERM
            return 1
        fi
    else
        trap cleanup_todesk EXIT INT TERM
    fi

    if [ "$repair_service" -eq 0 ]; then
        ensure_todesk_ca_certificates || return 1
        cleanup_todesk_orphan_files || return 1

        echo "正在安装ToDesk..."
        if ! install_verified_todesk_package "$package_path"; then
            echo "ToDesk安装失败；未删除原有配置。"
            log "ToDesk安装失败: pacman返回错误"
            return 1
        fi
        if [ "$(todesk_installed_version 2>/dev/null || true)" != "$TODESK_PACKAGE_VERSION" ]; then
            echo "ToDesk安装后版本检查未通过。"
            return 1
        fi
    fi

    configure_todesk_service || return 1

    if [ -f /usr/share/applications/todesk.desktop ]; then
        mkdir -p "$HOME/Desktop"
        cp /usr/share/applications/todesk.desktop "$HOME/Desktop/ToDesk.desktop"
        chmod +x "$HOME/Desktop/ToDesk.desktop"
    fi

    if ! cleanup_todesk; then
        echo "ToDesk已安装，但恢复 SteamOS 只读保护失败。"
        return 1
    fi
    trap - EXIT INT TERM
    if [ "$repair_service" -eq 1 ]; then
        echo "ToDesk后台服务修复完成。"
        log "ToDesk后台服务修复完成"
    else
        echo "ToDesk安装完成。"
        log "ToDesk安装完成"
    fi
}

uninstall_todesk() {
    local readonly_status
    local answer

    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "ToDesk卸载仅支持真实SteamOS环境。"
        return 1
    fi
    if ! todesk_is_installed; then
        echo "ToDesk 未安装。"
        return 0
    fi
    echo "将卸载 ToDesk 软件包并停止 todeskd 服务；个人配置不会主动删除。"
    if [ "${ZHOUKEER_AUTO_CONFIRM:-0}" != "1" ]; then
        read -r -p "确认卸载请输入 UNINSTALL：" answer
        [ "$answer" = "UNINSTALL" ] || { echo "已取消卸载。"; return 0; }
    fi
    for command_name in sudo pacman systemctl steamos-readonly; do
        require_command "$command_name" || return 1
    done
    toolbox_sudo true || return 1
    readonly_status="$(steamos-readonly status 2>/dev/null || true)"
    if printf '%s' "$readonly_status" | grep -qi 'enabled'; then
        TODESK_READONLY_CHANGED=1
        trap cleanup_todesk EXIT INT TERM
        toolbox_sudo steamos-readonly disable || return 1
    else
        trap cleanup_todesk EXIT INT TERM
    fi
    if ! toolbox_sudo systemctl disable --now todeskd.service; then
        if systemctl is-active --quiet todeskd.service >/dev/null 2>&1 || \
            systemctl is-enabled --quiet todeskd.service >/dev/null 2>&1; then
            echo "ToDesk后台服务停用失败，软件包尚未卸载。"
            return 1
        fi
        echo "未检测到运行中的ToDesk后台服务，继续卸载软件包。"
    fi
    toolbox_sudo pacman -Rns --noconfirm todesk-bin || return 1
    rm -f -- "$HOME/Desktop/ToDesk.desktop" || return 1
    if ! cleanup_todesk; then
        echo "ToDesk已卸载，但恢复 SteamOS 只读保护失败。"
        return 1
    fi
    trap - EXIT INT TERM
    echo "ToDesk 已卸载。"
    log "ToDesk 已卸载"
}

todesk_menu() {
    local choice

    echo "1. 安装或更新ToDesk"
    echo "2. 查看安装风险说明"
    echo "0. 返回"
    read -r -p "选择：" choice

    case "$choice" in
        1) install_todesk ;;
        2) show_todesk_warning ;;
        0) return 0 ;;
        *) echo "输入错误" ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        --install) install_todesk ;;
        --uninstall) uninstall_todesk ;;
        "") todesk_menu ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
fi
