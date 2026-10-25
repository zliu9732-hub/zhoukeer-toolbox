#!/bin/bash

# V14 helpers are retained only for stopping and migrating existing installations.
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/steam302_legacy.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/modules/steam302_v15.sh"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        install) install_steam302 ;;
        launch) launch_steam302 ;;
        start|enable) enable_steam302 ;;
        reset|restart) reset_steam302 ;;
        stop) stop_steam302_service ;;
        status) show_steam302_status ;;
        ensure) ensure_steam302_for_download ;;
        uninstall) uninstall_steam302 ;;
        *) echo "用法: $0 {install|launch|start|reset|stop|status|ensure|uninstall}"; exit 1 ;;
    esac
fi
