#!/bin/bash
# Only mocked downloads and installs. All state is stored in a temporary directory.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
export HOME="$fixture/home"
mkdir -p "$HOME"
export ZHOUKEER_FLATPAK_SOURCE_MODE=domestic
source "$PROJECT_ROOT/modules/software.sh"

is_linux() { return 0; }
detect_platform() { IS_CHIMERAOS=0; }
software_is_installed() { [ -f "$fixture/installed" ]; }
confirm_software_install() { return 0; }
require_command() { return 0; }
choose_install_remotes() { :; }
create_software_shortcut() { echo shortcut >> "$fixture/calls"; }
log() { :; }
ensure_flatpak_remotes() { echo domestic >> "$fixture/calls"; }
ensure_official_flathub_remote() { echo official >> "$fixture/calls"; }
timeout() {
    [ "$1 $2 $3 $4 $5" = '--foreground 15 flatpak remote-info --user' ] || return 97
    [ "$7" = 'com.github.gmg137.netease-cloud-music-gtk' ] || return 97
    echo "probe $6" >> "$fixture/calls"
    case "$scenario:$6" in
        secondary:flathub-ustc|install_failure:flathub-cn) return 0 ;;
        *) return 1 ;;
    esac
}
run_flatpak_install() {
    echo "install $1" >> "$fixture/calls"
    case "$scenario:$1" in
        secondary:flathub-ustc|official:flathub|install_failure:flathub) touch "$fixture/installed" ;;
        *) return 1 ;;
    esac
}

for scenario in secondary official install_failure failure; do
    : > "$fixture/calls"
    rm -f "$fixture/installed"
    status=0
    install_software netease-music > "$fixture/output" || status=$?
    expected=$'domestic\nprobe flathub-cn\nprobe flathub-ustc\n'
    case "$scenario" in
        secondary) expected+=$'install flathub-ustc\nshortcut'; [ "$status" = 0 ] ;;
        official) expected+=$'official\ninstall flathub\nshortcut'; [ "$status" = 0 ] ;;
        install_failure)
            expected=$'domestic\nprobe flathub-cn\ninstall flathub-cn\nprobe flathub-ustc\nofficial\ninstall flathub\nshortcut'
            [ "$status" = 0 ]
            ;;
        failure)
            expected+=$'official\ninstall flathub'
            [ "$status" = 1 ]
            grep -Fq '网易云音乐 下载或安装失败' "$fixture/output"
            ;;
    esac
    diff -u <(printf '%s\n' "$expected") "$fixture/calls"
done
echo 'PASS: NetEase skips missing refs, falls back to signed Flathub, and stops on failure'
