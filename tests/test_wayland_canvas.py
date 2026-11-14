"""Render SteamOS menus in a private PTY. Never launch Konsole or a system action."""
import os
import pty
import re
import subprocess
import tempfile
import tty
from pathlib import Path

from test_responsive_ui import ROOT, check, click, item_position, read_until, resize


source = (ROOT / "main.sh").read_text()
functions = [
    re.search(rf"^{name}\(\) \{{.*?^}}", source, re.M | re.S).group()
    for name in ("show_disclaimer", "read_touch_menu", "home_menu")
]
fixture = r'''
set -eu
# Mock the missing KDE helper, even on hosts which have it installed.
command() {
    if [ "$*" = "-v konsoleprofile" ]; then return 1; fi
    builtin command "$@"
}
source "$UI_TEST_ROOT/core/ui.sh"
RENKIT_STEAMOS_DUAL_NAV=1
UI_MENU_SCREEN_ENABLED=1
UI_LAYOUT_RETRY_INTERVAL=0.02
UI_LAYOUT_RETRY_COUNT=12
ui_discard_pending_input() { :; }
apply_navigation() { printf '\nCHOSEN=%s\n' "$1"; }
'''

with tempfile.TemporaryDirectory(prefix="renkit-wayland-") as temp:
    script = Path(temp) / "menu.sh"
    script.write_text(fixture + "\n".join(functions) + r'''
if [ "$TEST_SHORT" = 0 ]; then
    show_disclaimer
fi
home_menu
''')
    for columns, rows, maximize in ((124, 21, False), (90, 21, True), (105, 17, False)):
        master, slave = pty.openpty()
        tty.setraw(slave)
        resize(master, columns, rows)
        env = dict(
            os.environ,
            XDG_SESSION_TYPE="wayland",
            UI_TEST_ROOT=str(ROOT),
            KONSOLE_VERSION="250800",
            ZHOUKEER_FONT_SIZE="12",
            RENKIT_COMPACT_MENUS="0",
            TEST_SHORT=str(int(rows < 21)),
        )
        p = subprocess.Popen(["bash", str(script)], env=env, stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        try:
            if rows < 21:
                read_until(master, b"\x1b]50;Font=Noto Sans Mono CJK SC,9\x07")
                # The terminal, not the shell, reports the new rows after the font request.
                resize(master, 140, 22)
            else:
                welcome = read_until(master, "点击窗口任意位置开始使用".encode())
                check("窗口太小" not in welcome, "Welcome screen blocked in Wayland")
                os.write(master, click(12, 16))
            frame = read_until(master, b"\x1b[?1006h")
            check("窗口太小" not in frame, "Home menu blocked in Wayland")
            if maximize:
                resize(master, 146, 28)
                frame = read_until(master, b"\x1b[?1006h")
                check("窗口太小" not in frame, "Maximizing blocked the menu")
            y, x = item_position(frame, "退出Renkit", last=not maximize)
            os.write(master, click(x, y))
            read_until(master, b"CHOSEN=nav-exit")
            check(p.wait(timeout=3) == 0, "Menu did not finish after touch input")
        finally:
            if p.poll() is None:
                p.kill()
            p.wait()
            os.close(master)

print("PASS: Wayland welcome, touch in compact and maximized windows, and session font fallback")
