"""Isolated terminal rendering/input regression tests; no system actions or network."""
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import struct
import subprocess
import tempfile
import termios
import time
import tty

ROOT = Path(__file__).resolve().parents[1]
SHELL = r'''
set -euo pipefail
# Only stty size queries may reach the private PTY; everything else is mocked.
stty() {
    if [ "${UI_TEST_MODE:-}" = live ]; then
        [ "$*" = size ] || return 1
        command stty size
    else
        printf '%s %s\n' "$MOCK_ROWS" "$MOCK_COLS"
    fi
}
tput() { case "$1" in lines) printf '24\n';; cols) printf '120\n';; esac; }
source "$UI_TEST_ROOT/core/ui.sh"
ui_wait_for_minimum_canvas() { return 0; }
ui_discard_pending_input() { return 0; }
# Neither rendering nor replay may run an action or request a font change.
run_action() { printf 'UNEXPECTED ACTION\n' >&2; exit 91; }
konsoleprofile() { exit 92; }
draw_category_frame software '' ''
ui_touch_button 2 '' 'FIRST' 'First item'
ui_touch_button 10 '' 'CONFIRM' 'Only after explicit click'
ui_touch_button 15 '' 'CANCEL' 'No change'
ui_touch_button 23 '' 'RETURN' 'Return home'
ui_prompt
if [ "${UI_TEST_MODE:-}" = render ]; then exit 0; fi
choice="$(read_menu_choice left:2-3:nav-init left:18-19:nav-exit right:2-3:first right:10-11:yes right:15-16:no right:23-24:home)"
printf '\nRESULT=%s\n' "$choice"
'''

MOVE = re.compile(r'\x1b\[(\d+);(\d+)H')


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def item_position(output, label):
    prefix = output[:output.index(label)]
    matches = list(MOVE.finditer(prefix))
    check(matches, f'No cursor before {label}')
    return tuple(map(int, matches[-1].groups()))


def click(x, y):
    return f'\x1b[<0;{x};{y}M'.encode()


def run(fixture, columns, rows, mode='render', data=b''):
    env = dict(os.environ, UI_TEST_ROOT=str(ROOT), MOCK_COLS=str(columns),
               MOCK_ROWS=str(rows), UI_TEST_MODE=mode, COLUMNS='999', LINES='999')
    result = subprocess.run(['bash', str(fixture)], env=env, input=data,
                            capture_output=True, timeout=10)
    check(result.returncode == 0, result.stderr.decode())
    check(not result.stderr, f'Unexpected stderr: {result.stderr!r}')
    return result.stdout.decode()


def read_until(master, expected, timeout=5):
    result = b''
    deadline = time.monotonic() + timeout
    while expected not in result and time.monotonic() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            result += os.read(master, 65536)
    check(expected in result, f'Terminal did not produce {expected!r}: {result[-500:]!r}')
    return result.decode()


def resize(master, columns, rows):
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', rows, columns, 0, 0))


def live_test(fixture):
    master, slave = pty.openpty()
    tty.setraw(slave)
    resize(master, 120, 32)
    env = dict(os.environ, UI_TEST_ROOT=str(ROOT), UI_TEST_MODE='live',
               COLUMNS='120', LINES='24')
    process = subprocess.Popen(['bash', str(fixture)], env=env,
                               stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)
    try:
        read_until(master, '触屏或触控板点击功能'.encode())
        # Idle timeout must redraw without a key/click and preserve the same page.
        resize(master, 200, 60)
        enlarged = read_until(master, '触屏或触控板点击功能'.encode())
        check('FIRST' in enlarged and 'RETURN' in enlarged, 'Resize lost current menu')
        check(item_position(enlarged, 'RETURN')[0] > 50, 'Return did not move down')
        check(item_position(enlarged, 'FIRST')[1] > 50, 'Panel did not move right')

        # An undersized window suppresses clicks, including the former confirmation.
        resize(master, 60, 18)
        read_until(master, '窗口太小'.encode())
        os.write(master, click(40, 10))
        time.sleep(0.15)
        check(process.poll() is None, 'Undersized window accepted an action')

        # Restore, then click the physical CANCEL label from the actual draw output.
        resize(master, 100, 28)
        restored = read_until(master, '触屏或触控板点击功能'.encode())
        # A click that arrives together with a resize is discarded, not reinterpreted.
        old_y, old_x = item_position(restored, 'CONFIRM')
        resize(master, 160, 40)
        os.write(master, click(old_x, old_y))
        restored = read_until(master, '触屏或触控板点击功能'.encode())
        check(process.poll() is None, 'Stale click executed during resize')
        row, col = item_position(restored, 'CANCEL')
        os.write(master, click(col + 2, row))
        result = read_until(master, b'RESULT=no')
        check('RESULT=no' in result and 'UNEXPECTED' not in result, 'Resize polluted action ID')
        check(process.wait(timeout=3) == 0, 'Live menu failed')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)


def main():
    with tempfile.TemporaryDirectory(prefix='renkit-ui-test-') as temp:
        fixture = Path(temp) / 'canvas.sh'
        fixture.write_text(SHELL)
        for cols, rows in [(70, 24), (80, 24), (100, 28), (120, 32), (160, 48), (240, 64), (320, 100)]:
            output = run(fixture, cols, rows)
            moves = [tuple(map(int, match.groups())) for match in MOVE.finditer(output)]
            check(all(1 <= y <= rows and 1 <= x <= cols for y, x in moves),
                  f'Cursor outside {cols}x{rows}')
            check((rows, item_position(output, 'FIRST')[1]) in moves, 'Footer not at bottom')
            # Inspect the actual rule written after FIRST; it must reach the right margin.
            row, col = item_position(output, 'FIRST')
            rule = re.search(r'─{5,}', output[output.index('FIRST'):]).group()
            check(col + len(rule) == cols - 1, 'Rule does not fill panel width')
            for label, action in [('FIRST', 'first'), ('CONFIRM', 'yes'), ('CANCEL', 'no'), ('RETURN', 'home')]:
                y, x = item_position(output, label)
                result = run(fixture, cols, rows, 'choice', click(x + 2, y))
                check(result.endswith(f'RESULT={action}\n'), f'Wrong {label} hit at {cols}x{rows}')
                # Entire stretched button area, including its bottom rule, stays clickable.
                tail = output[output.index(label):]
                bottom = MOVE.search(tail)
                bottom_row = int(bottom.group(1))
                if bottom_row < rows:
                    result = run(fixture, cols, rows, 'choice', click(cols - 2, bottom_row))
                    check(result.endswith(f'RESULT={action}\n'), 'Button bottom hit mismatch')
            nav_y, _ = item_position(output, '退出Renkit')
            check(run(fixture, cols, rows, 'choice', click(5, nav_y)).endswith('RESULT=nav-exit\n'),
                  'Sidebar hit mismatch')
            # Footer, divider and an off-window click cannot trigger confirmation.
            yes_y, yes_x = item_position(output, 'CONFIRM')
            no_y, no_x = item_position(output, 'CANCEL')
            invalid = click(yes_x, rows) + click(yes_x - 3, yes_y) + click(cols + 1, yes_y)
            check(run(fixture, cols, rows, 'choice', invalid + click(no_x, no_y)).endswith('RESULT=no\n'),
                  'Blank area incorrectly dispatched action')
        for cols, rows in [(60, 24), (120, 18)]:
            output = run(fixture, cols, rows)
            check('窗口太小' in output and 'FIRST' not in output, 'Small-window guard missing')
        live_test(fixture)
    print('PASS: 7 terminal sizes, stretched hit regions, footer isolation, idle resize, stale click rejection and small-window recovery')


if __name__ == '__main__':
    main()
