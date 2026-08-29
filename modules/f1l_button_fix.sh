#!/bin/bash

# Renkit 2.1.7 兼容入口；正式功能已扩展为两台壹号掌机自动识别。
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/onexplayer_button_fix.sh" "$@"
