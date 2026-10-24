#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
unset LD_PRELOAD LD_LIBRARY_PATH PYTHONHOME PYTHONPATH
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
if [ "$#" -eq 0 ]; then set -- check; fi
exec python3 -I -B "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/installer.py" "$@"
