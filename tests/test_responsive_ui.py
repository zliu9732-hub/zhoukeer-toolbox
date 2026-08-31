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
import unicodedata

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
ui_touch_button 2 '' 'FIRST' '中文说明与长文本 Mixed 123 · 测试按钮边框不能被覆盖'
ui_touch_button 4 '' 'SECOND' 'Adjacent item'
ui_touch_button 10 '' 'CONFIRM' 'Only after explicit click'
ui_touch_button 15 '' 'CANCEL' 'No change'
ui_touch_button 23 '' 'RETURN' 'Return home'
ui_prompt
if [ "${UI_TEST_MODE:-}" = render ]; then exit 0; fi
choice="$(read_menu_choice left:2-3:nav-init left:18-19:nav-exit right:2-3:first right:4-5:second right:10-11:yes right:15-16:no right:23-24:home)"
printf '\nRESULT=%s\n' "$choice"
'''

MOVE = re.compile(r'\x1b\[(\d+);(\d+)H')
CSI = re.compile(r'\x1b\[([?0-9;]*)([A-Za-z])')


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def item_position(output, label):
    prefix = output[:output.index(label)]
    matches = list(MOVE.finditer(prefix))
    check(matches, f'No cursor before {label}')
    return tuple(map(int, matches[-1].groups()))


def screen_cells(output):
    """Interpret emitted ANSI so later text overwriting a border cannot pass QA."""
    cells = {}
    row = col = 1
    color = 255
    position = 0
    while position < len(output):
        match = CSI.match(output, position)
        if match:
            args, command = match.groups()
            if command == 'H':
                coords = [int(x or '1') for x in args.split(';')]
                row, col = (coords + [1])[:2]
            elif command == 'J' and args == '2':
                cells.clear()
            elif command == 'K':
                cells = {key: val for key, val in cells.items()
                         if key[0] != row or (args != '2' and key[1] < col)}
            elif command == 'm':
                if args in ('', '0'):
                    color = 255
                value = re.search(r'(?:^|;)38;5;(\d+)', args)
                if value:
                    color = int(value[1])
            position = match.end()
            continue
        char = output[position]
        position += 1
        if char == '\n':
            row += 1
            col = 1
        elif char == '\r':
            col = 1
        elif unicodedata.combining(char):
            continue
        else:
            cells[row, col] = (char, color)
            if unicodedata.east_asian_width(char) in ('W', 'F'):
                col += 1
                cells[row, col] = ('', color)
            col += 1
    return cells


def box_bounds(output, label, cells):
    y, caption_col = item_position(output, label)
    left = caption_col - 1
    top = max(r for (r, c), (char, _) in cells.items()
              if c == left and r <= y and char == '╭')
    right = next(c for (r, c), (char, _) in cells.items()
                 if r == top and c > left and char == '╮')
    bottom = min(r for (r, c), (char, _) in cells.items()
                 if c == left and r > top and char == '╰')
    for r, c, char in [(top, left, '╭'), (top, right, '╮'),
                       (bottom, left, '╰'), (bottom, right, '╯')]:
        check(cells.get((r, c)) == (char, 203), f'{label}: missing red corner {r},{c}')
    for r in range(top + 1, bottom):
        check(cells.get((r, left)) == ('│', 203), f'{label}: left border overwritten')
        check(cells.get((r, right)) == ('│', 203), f'{label}: right border overwritten')
    for c in range(left + 1, right):
        check(cells.get((bottom, c)) == ('─', 203), f'{label}: bottom border overwritten')
        if top < y:
            check(cells.get((top, c)) == ('─', 203), f'{label}: top border overwritten')
    return top, bottom, left, right


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
        for cols, rows in [(70, 24), (80, 24), (80, 25), (100, 28), (120, 32), (160, 48), (240, 64), (320, 100)]:
            output = run(fixture, cols, rows)
            moves = [tuple(map(int, match.groups())) for match in MOVE.finditer(output)]
            check(all(1 <= y <= rows and 1 <= x <= cols for y, x in moves),
                  f'Cursor outside {cols}x{rows}')
            cells = screen_cells(output)
            check(all(1 <= r <= rows and 1 <= c <= cols for r, c in cells),
                  'Rendered text escaped terminal bounds')
            if rows > 24:
                check(item_position(output, '触屏或触控板点击功能')[0] == rows, 'Footer not at bottom')
            else:
                check('触屏或触控板点击功能' not in output, 'Footer obscures compact bottom button')
            bounds = []
            for label, action in [('FIRST', 'first'), ('SECOND', 'second'), ('CONFIRM', 'yes'), ('CANCEL', 'no'), ('RETURN', 'home')]:
                top, bottom, left, right = box_bounds(output, label, cells)
                bounds.append((top, bottom))
                check(right == cols - 2, 'Box does not fill panel width')
                y, x = item_position(output, label)
                result = run(fixture, cols, rows, 'choice', click(x + 2, y))
                check(result.endswith(f'RESULT={action}\n'), f'Wrong {label} hit at {cols}x{rows}')
                for bx, by in [(left, top), (right, top), (left, bottom), (right, bottom)]:
                    result = run(fixture, cols, rows, 'choice', click(bx, by))
                    check(result.endswith(f'RESULT={action}\n'), 'Red corner hit mismatch')
            check(all(a[1] < b[0] for a, b in zip(bounds, bounds[1:])), 'Adjacent boxes overlap')
            for label in ['新机器设置', '安装常用软件', '游戏与插件', '模拟器', '检查与维护',
                          '更多设置', '卸载已安装', '免责声明与须知', '退出Renkit']:
                box_bounds(output, label, cells)
            nav_y, _ = item_position(output, '退出Renkit')
            check(run(fixture, cols, rows, 'choice', click(5, nav_y)).endswith('RESULT=nav-exit\n'),
                  'Sidebar hit mismatch')
            # Footer, divider and an off-window click cannot trigger confirmation.
            yes_y, yes_x = item_position(output, 'CONFIRM')
            no_y, no_x = item_position(output, 'CANCEL')
            invalid = click(yes_x - 3, yes_y) + click(cols + 1, yes_y) + click(cols, yes_y) + click(1, 2)
            if rows > 24:
                invalid += click(yes_x, rows)
            check(run(fixture, cols, rows, 'choice', invalid + click(no_x, no_y)).endswith('RESULT=no\n'),
                  'Blank area incorrectly dispatched action')
        # The welcome button also has a red box; its explanation stays inside it.
        welcome = Path(temp) / 'welcome.sh'
        welcome.write_text(SHELL.split("draw_category_frame software '' ''")[0] + r'''
draw_disclaimer_frame
ui_disclaimer_button 16 '' 'WELCOME' 'Read first and click to continue'
''')
        for cols, rows in [(70, 24), (120, 32), (160, 48)]:
            output = run(welcome, cols, rows)
            cells = screen_cells(output)
            box_bounds(output, 'WELCOME', cells)
        for cols, rows in [(60, 24), (120, 18)]:
            output = run(fixture, cols, rows)
            check('窗口太小' in output and 'FIRST' not in output, 'Small-window guard missing')
        live_test(fixture)
    print('PASS: 8 terminal sizes, red boxes and corner hits, CJK clipping, adjacent boxes, idle resize and small-window recovery')


if __name__ == '__main__':
    main()
