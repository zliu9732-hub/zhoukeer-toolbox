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
ui_touch_button 10 '\033[48;5;160m' 'CONFIRM' 'Only after explicit click'
ui_touch_button 15 '\033[48;5;238m' 'CANCEL' 'No change'
ui_touch_button 23 '' 'RETURN' 'Return home'
ui_prompt
if [ "${UI_TEST_MODE:-}" = render ]; then exit 0; fi
choice="$(read_menu_choice left:2-3:nav-init left:4-5:nav-software left:6-7:nav-games left:8-9:nav-emulators left:10-11:nav-check left:12-13:nav-advanced left:14-15:nav-uninstall left:16-17:nav-notice left:18-19:nav-exit right:2-3:first right:4-5:second right:10-11:yes right:15-16:no right:23-24:home)"
printf '\nRESULT=%s\n' "$choice"
'''

MOVE = re.compile(r'\x1b\[(\d+);(\d+)H')
CSI = re.compile(r'\x1b\[([?0-9;]*)([A-Za-z])')


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def item_position(output, label, last=False):
    prefix = output[:output.rindex(label) if last else output.index(label)]
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


def box_bounds(output, label, cells, last=False):
    y, caption_col = item_position(output, label, last=last)
    left = caption_col - 1
    top = max(r for (r, c), (char, _) in cells.items()
              if c == left and r <= y and char == '╭')
    right = next(c for (r, c), (char, _) in cells.items()
                 if r == top and c > left and char == '╮')
    bottom = min(r for (r, c), (char, _) in cells.items()
                 if c == left and r > top and char == '╰')
    border = cells[top, left][1]
    check(border in (131, 203), f'{label}: border is not red')
    for r, c, char in [(top, left, '╭'), (top, right, '╮'),
                       (bottom, left, '╰'), (bottom, right, '╯')]:
        check(cells.get((r, c)) == (char, border), f'{label}: missing red corner {r},{c}')
    for r in range(top + 1, bottom):
        check(cells.get((r, left)) == ('│', border), f'{label}: left border overwritten')
        check(cells.get((r, right)) == ('│', border), f'{label}: right border overwritten')
    for c in range(left + 1, right):
        check(cells.get((bottom, c)) == ('─', border), f'{label}: bottom border overwritten')
        if top < y:
            check(cells.get((top, c)) == ('─', border), f'{label}: top border overwritten')
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
        check(item_position(enlarged, 'RETURN')[0] > 32, 'Return did not move down')
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


def input_stream_test(directory):
    """A partial packet must not consume the next tap; release must not open another page."""
    start = SHELL.index('choice="$(read_menu_choice')
    reader = SHELL[start:]
    fixture = directory / 'stream.sh'
    fixture.write_text(SHELL[:start] + reader.replace('RESULT=', 'FIRST_RESULT=')
                       + reader.replace('RESULT=', 'SECOND_RESULT='))
    for raw in (False, True):
        master, slave = pty.openpty()
        if raw:
            tty.setraw(slave)
        resize(master, 120, 32)
        env = dict(os.environ, UI_TEST_ROOT=str(ROOT), UI_TEST_MODE='live')
        process = subprocess.Popen(['bash', str(fixture)], env=env,
                                   stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        try:
            frame = read_until(master, '触屏或触控板点击功能'.encode())
            y, x = item_position(frame, 'CANCEL')
            os.write(master, b'\x1b[<0;')
            time.sleep(0.05)
            # Deliver a new valid tap in fragments, like delayed terminal input.
            packet = click(x + 2, y)
            for part in (packet[:1], packet[1:5], packet[5:-1], packet[-1:]):
                os.write(master, part)
                time.sleep(0.02)
            os.write(master, packet[:-1] + b'm')
            result = read_until(master, b'FIRST_RESULT=no')
            check('SECOND_RESULT=' not in result, 'Release triggered another menu')
            time.sleep(0.05)
            check(process.poll() is None, 'Release or leftover bytes dispatched another action')
            y, x = item_position(frame, 'FIRST')
            packet = click(x + 2, y)
            os.write(master, packet + packet[:-1] + b'm')
            result = read_until(master, b'SECOND_RESULT=first')
            check('UNEXPECTED' not in result, 'Input stream executed a system action')
            check(process.wait(timeout=3) == 0, 'Input stream reader failed')
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
                check(cells[top, left][1] == 131, 'Right button border colors differ')
                bounds.append((top, bottom, left, right))
                if cols < 110 or label == 'RETURN':
                    check(right == cols - 2, 'Single/spanning box does not fill panel width')
                y, x = item_position(output, label)
                result = run(fixture, cols, rows, 'choice', click(x + 2, y))
                check(result.endswith(f'RESULT={action}\n'), f'Wrong {label} hit at {cols}x{rows}')
                for bx, by in [(left, top), (right, top), (left, bottom), (right, bottom)]:
                    result = run(fixture, cols, rows, 'choice', click(bx, by))
                    check(result.endswith(f'RESULT={action}\n'), 'Red corner hit mismatch')
            for index, (top, bottom, left, right) in enumerate(bounds):
                for ot, ob, ol, oright in bounds[index + 1:]:
                    check(bottom < ot or ob < top or right < ol or oright < left, 'Cards overlap')
            if cols >= 110:
                check(bounds[0][0] == bounds[1][0] and bounds[0][3] < bounds[1][2], 'Two-column layout missing')
                check(all(bottom - top >= 2 for top, bottom, _, _ in bounds), 'Grid caption overlaps border')
            side_heights = []
            for index, (label, action) in enumerate([
                    ('新机器设置', 'nav-init'), ('安装常用软件', 'nav-software'),
                    ('游戏与插件', 'nav-games'), ('模拟器', 'nav-emulators'),
                    ('检查与维护', 'nav-check'), ('更多设置', 'nav-advanced'),
                    ('卸载已安装', 'nav-uninstall'), ('免责声明与须知', 'nav-notice'),
                    ('退出Renkit', 'nav-exit')]):
                y, caption_col = item_position(output, label)
                left = caption_col - 1
                right = next(c for (r, c), (char, _) in cells.items()
                             if r == y and c > left and char == '│')
                top = max(r for (r, c), (char, _) in cells.items()
                          if c == left and r < y and char in '╭├')
                bottom = min(r for (r, c), (char, _) in cells.items()
                             if c == left and r > y and char in '├╰')
                side_heights.append(bottom - top)
                check(abs((y - top) - (bottom - y)) <= 1, 'Sidebar caption not centered')
                check(index != 0 or top == 2, 'Sidebar no longer starts below header')
                for rail_y in range(top + 1, bottom):
                    for c in (left, right):
                        check(cells.get((rail_y, c)) == ('│', 203 if index == 1 else 131),
                              'Sidebar rail or selected highlight missing')
                for c, char in [(left, '╭' if index == 0 else '├'),
                                (right, '╮' if index == 0 else '┤')]:
                    check(cells.get((top, c)) == (char, 131), 'Sidebar junction missing')
                check(all(cells.get((top, c)) == ('─', 131) for c in range(left + 1, right)),
                      'Sidebar separator overwritten')
                # The shared separator belongs to the following option; both rails remain clickable.
                for x, hit_y in [(left, top), (right, top), (left, y), (right, bottom - 1)]:
                    check(run(fixture, cols, rows, 'choice', click(x, hit_y)).endswith(f'RESULT={action}\n'),
                          f'Sidebar boundary dispatched wrong action: {label}')
            check(max(side_heights) - min(side_heights) <= 1, 'Sidebar height not evenly distributed')
            check(rows - 2 <= bottom <= rows, 'Excessive blank space below sidebar')
            check(cells.get((bottom, left)) == ('╰', 131)
                  and cells.get((bottom, right)) == ('╯', 131), 'Sidebar bottom corners missing')
            check(all(cells.get((bottom, c)) == ('─', 131) for c in range(left + 1, right)),
                  'Sidebar bottom border overwritten')
            check(run(fixture, cols, rows, 'choice', click(right, bottom)).endswith('RESULT=nav-exit\n'),
                  'Sidebar bottom border cannot exit')
            nav_y, _ = item_position(output, '退出Renkit')
            check(run(fixture, cols, rows, 'choice', click(5, nav_y)).endswith('RESULT=nav-exit\n'),
                  'Sidebar hit mismatch')
            # Footer, divider and an off-window click cannot trigger confirmation.
            yes_y, yes_x = item_position(output, 'CONFIRM')
            no_y, no_x = item_position(output, 'CANCEL')
            invalid = (click(yes_x - 3, yes_y) + click(cols + 1, yes_y) + click(cols, yes_y)
                       + click(1, 2) + click(5, bottom + 1))
            if rows > 24:
                invalid += click(yes_x, rows)
            check(run(fixture, cols, rows, 'choice', invalid + click(no_x, no_y)).endswith('RESULT=no\n'),
                  'Blank area incorrectly dispatched action')

        # Render the real homepage calls and prove each right card reuses its left action.
        home_function = re.search(r'^home_menu\(\).*?^}', (ROOT / 'main.sh').read_text(), re.M | re.S).group()
        home_lines = [line.strip() for line in home_function.splitlines()
                      if line.strip().startswith(('draw_category_frame ', 'ui_panel_line ')) or line.strip() == 'ui_prompt']
        navigation = [('新机器设置', 'nav-init'), ('安装常用软件', 'nav-software'),
                      ('游戏与插件', 'nav-games'), ('模拟器', 'nav-emulators'),
                      ('检查与维护', 'nav-check'), ('更多设置', 'nav-advanced'),
                      ('卸载已安装', 'nav-uninstall'), ('免责声明与使用须知', 'nav-notice')]
        mappings = ' '.join(f'left:{2 + i * 2}-{3 + i * 2}:{action}' for i, (_, action) in enumerate(navigation))
        home = Path(temp) / 'home.sh'
        home.write_text(SHELL.split("draw_category_frame software '' ''")[0] + '\n'.join(home_lines) + '\n'
                        + 'if [ "$UI_TEST_MODE" = render ]; then exit 0; fi\n'
                        + 'choice="$(read_menu_choice ' + mappings + ')"\nprintf "\\nRESULT=%s\\n" "$choice"\n')
        for cols, rows in [(80, 24), (120, 32), (160, 48)]:
            output = run(home, cols, rows)
            cells = screen_cells(output)
            for label, action in navigation:
                top, bottom, left, right = box_bounds(output, label, cells, last=True)
                for x, y in [(left, top), (right, bottom)]:
                    result = run(home, cols, rows, 'choice', click(x, y))
                    check(result.endswith(f'RESULT={action}\n'), 'Homepage card changed navigation')

        # Extra risk text disables the grid and remains above the original confirmation.
        mixed = Path(temp) / 'mixed.sh'
        mixed.write_text(SHELL.split("draw_category_frame software '' ''")[0] + r'''
draw_category_frame advanced 'RISK_PAGE' 'Read before choosing'
ui_panel_line 7 '' 'WARNING: review all consequences before confirming'
ui_touch_button 9 '' 'CONFIRM'
ui_touch_button 12 '' 'STATUS'
ui_touch_button 15 '' 'CANCEL'
ui_touch_button 22 '' 'RETURN'
ui_prompt
''')
        for cols, rows in [(120, 32), (160, 48)]:
            output = run(mixed, cols, rows)
            cells = screen_cells(output)
            boxes = [box_bounds(output, label, cells) for label in ['CONFIRM', 'STATUS', 'CANCEL', 'RETURN']]
            check(len({left for _, _, left, _ in boxes}) == 1, 'Risk page was rearranged into columns')
            check(item_position(output, 'WARNING')[0] < boxes[0][0], 'Risk notice moved below confirmation')
            # Some real preflight pages omit ui_prompt and read the choice directly.
            implicit = Path(temp) / 'implicit-prompt.sh'
            implicit.write_text(mixed.read_text().replace('ui_prompt\n', '')
                                + 'choice="$(read_menu_choice right:15-16:no)"\nprintf "RESULT=%s\\n" "$choice"\n')
            _, _, left, _ = boxes[2]
            y, _ = item_position(output, 'CANCEL')
            result = subprocess.run(['bash', str(implicit)], input=click(left, y), capture_output=True,
                                    env=dict(os.environ, UI_TEST_ROOT=str(ROOT), MOCK_COLS=str(cols),
                                             MOCK_ROWS=str(rows), UI_TEST_MODE='choice'), timeout=10)
            check(result.returncode == 0 and result.stdout == b'RESULT=no\n', 'Implicit frame polluted choice')
            check(b'WARNING' in result.stderr and b'CONFIRM' in result.stderr, 'Preflight did not display before reading')
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
        input_stream_test(Path(temp))
    print('PASS: 8 sizes, full-height sidebar, right cards, boundary hits, live resize and fragmented taps without duplicate actions')


if __name__ == '__main__':
    main()
