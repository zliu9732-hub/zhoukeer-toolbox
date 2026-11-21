"""Relay a terminal action with a yellow fish badge and red RenAmamiya name."""
import argparse
import errno
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import tty
import unicodedata

FONT = {
 'R': ['████ ', '█   █', '████ ', '█  █ ', '█   █'],
 'E': ['█████', '█    ', '████ ', '█    ', '█████'],
 'N': ['█   █', '██  █', '█ █ █', '█  ██', '█   █'],
 'A': [' ███ ', '█   █', '█████', '█   █', '█   █'],
 'M': ['█   █', '██ ██', '█ █ █', '█   █', '█   █'],
 'I': ['█████', '  █  ', '  █  ', '  █  ', '█████'],
 'Y': ['█   █', ' █ █ ', '  █  ', '  █  ', '  █  '],
}
COMPACT_FONT = {
 'R': ['███ ', '█  █', '███ ', '█ █ ', '█  █'],
 'E': ['████', '█   ', '███ ', '█   ', '████'],
 'N': ['█  █', '██ █', '█ ██', '█  █', '█  █'],
 'A': [' ██ ', '█  █', '████', '█  █', '█  █'],
 'M': FONT['M'],
 'I': ['███', ' █ ', ' █ ', ' █ ', '███'],
 'Y': ['█ █', '█ █', ' █ ', ' █ ', ' █ '],
}
LABEL = 'RenAmamiya'

# One pixel is half a terminal row: keep the rounded face and expressive eyes
# in square-pixel form without needing image support or a special font.
PALETTE = {'Y': 220, 'O': 214, 'W': 231, 'K': 16, 'D': 88, 'R': 196}


def avatar_pixels(width, height):
    """A rounded yellow mascot with large eyes, a wink and a smiling mouth."""
    def ellipse(x, y, cx, cy, rx, ry):
        return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1

    def stroke(x, y, ax, ay, bx, by, radius):
        dx, dy = bx - ax, by - ay
        distance = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
        return (x - ax - distance * dx) ** 2 + (y - ay - distance * dy) ** 2 <= radius ** 2

    rows = []
    for row in range(height):
        pixels = ''
        for column in range(width):
            x, y = (column + .5) * 32 / width, (row + .5) * 26 / height
            color = ' '
            if any(ellipse(x, y, cx, cy, rx, ry) for cx, cy, rx, ry in [
                    (24, 5, 3, 3), (27, 8, 3, 3), (29, 12, 3, 3),
                    (30, 17, 2.5, 3), (29, 22, 3, 3)]):
                color = 'O'
            if ellipse(x, y, 19, 4, 4, 3):
                color = 'Y'
            if ellipse(x, y, 3, 22, 2.5, 4):
                color = 'O'
            if ellipse(x, y, 16, 20, 14, 15):
                color = 'O'
            if ellipse(x, y, 15, 20, 13.5, 15):
                color = 'Y'
            if ellipse(x, y, 10, 12.5, 6, 6) or ellipse(x, y, 21, 13.5, 6.5, 6):
                color = 'W'
            if ellipse(x, y, 10, 12.5, 1.5, 2.5):
                color = 'K'
            if ellipse(x, y, 10, 11.3, .45, .6):
                color = 'W'
            if stroke(x, y, 24, 12, 19.5, 14, 1) or stroke(x, y, 19.5, 14, 23.5, 16, 1):
                color = 'K'
            if y >= 20 and ellipse(x, y, 14.5, 20, 4.5, 4):
                color = 'D'
                if ellipse(x, y, 15.5, 24.3, 3.5, 2.5):
                    color = 'R'
            pixels += color
        rows.append(pixels)
    return rows


FISH_PIXELS = avatar_pixels(25, 18)
FISH_SMALL_PIXELS = avatar_pixels(17, 12)
FISH_TINY_PIXELS = avatar_pixels(9, 8)


def cell_width(line):
    return sum(2 if unicodedata.east_asian_width(char) in ('W', 'F') else 1 for char in line)


def avatar_lines(pixels):
    """Group colored half-blocks; each run keeps its true terminal cell width."""
    padded = pixels + [' ' * len(pixels[0])] if len(pixels) % 2 else pixels
    lines = []
    for row in range(0, len(padded), 2):
        runs = []
        for column, (top, bottom) in enumerate(zip(padded[row], padded[row + 1])):
            if top == bottom:
                char, color = (' ', 220) if top == ' ' else ('█', PALETTE[top])
            elif top == ' ':
                char, color = '▄', PALETTE[bottom]
            elif bottom == ' ':
                char, color = '▀', PALETTE[top]
            else:
                char, color = '▀', (PALETTE[top], PALETTE[bottom])
            if runs and runs[-1][2] == color:
                offset, text, _ = runs[-1]
                runs[-1] = (offset, text + char, color)
            else:
                runs.append((column, char, color))
        lines.append(runs)
    return lines


def fish_badge(small=False, tiny=False):
    pixels = FISH_TINY_PIXELS if tiny else FISH_SMALL_PIXELS if small else FISH_PIXELS
    fish = avatar_lines(pixels)
    entries = [(row, column, text, color)
               for row, runs in enumerate(fish) for column, text, color in runs]
    return len(pixels[0]), len(fish), entries


def name_art(font=FONT):
    return [' '.join(font[c][line] for c in 'RENAMAMIYA') for line in range(5)]


def artwork(rows, columns):
    if rows < 14 or columns < 22:
        return rows, []
    available_height = rows - 9  # Keep at least eight rows for installer logs.
    choices = [
        (False, False, FONT),
        (True, False, FONT),
        (True, False, COMPACT_FONT),
        (True, True, FONT),
        (True, True, COMPACT_FONT),
    ]
    layout = None
    for small, tiny, font in choices:
        icon_width, icon_height, badge = fish_badge(small=small, tiny=tiny)
        name_lines = name_art(font)
        subtitle = available_height >= 6
        height = max(icon_height, 5 + int(subtitle))
        gap = 2
        width = icon_width + gap + len(name_lines[0])
        if height <= available_height and width < columns:
            layout = (icon_width, icon_height, height, badge, name_lines, gap, width, subtitle)
            break
    if layout is None and columns > len(name_art(COMPACT_FONT)[0]):
        # A narrow window can keep the full block name below the fish.
        for small, tiny in [(True, False), (True, True)]:
            icon_width, icon_height, badge = fish_badge(small=small, tiny=tiny)
            name_lines = name_art(COMPACT_FONT)
            height = icon_height + 1 + 5 + 1
            if height <= available_height:
                width = len(name_lines[0])
                column = max(1, columns - width - 2)
                top = rows - height
                icon_column = column + (width - icon_width) // 2
                lines = [(top + row, icon_column + offset, line, color)
                         for row, offset, line, color in badge]
                name_top = top + icon_height + 1
                lines.extend((name_top + row, column, line, 196) for row, line in enumerate(name_lines))
                lines.append((rows - 1, column + width - len(LABEL), LABEL, 196))
                return top - 1, lines
    if layout is None:
        tiny = rows < 20 or columns < 32
        icon_width, icon_height, badge = fish_badge(small=True, tiny=tiny)
        name_lines = [LABEL]
        gap = 1 if columns < 26 else 3
        width = icon_width + gap + len(LABEL)
        height = icon_height
        subtitle = False
    else:
        icon_width, icon_height, height, badge, name_lines, gap, width, subtitle = layout
    column = max(1, columns - width - 2)
    top = rows - height
    icon_top = top + (height - icon_height) // 2
    lines = [(icon_top + row, column + offset, line, color) for row, offset, line, color in badge]
    name_top = top + (height - len(name_lines) - int(subtitle)) // 2
    for i, line in enumerate(name_lines):
        lines.append((name_top + i, column + icon_width + gap, line, 196))
    if subtitle:
        lines.append((name_top + 5, column + width - len(LABEL), LABEL, 196))
    return top - 1, lines


def decoration(rows, columns):
    bottom, lines = artwork(rows, columns)
    if not lines:
        return b''
    # Save cursor/rendition; the child retains its log position and input prompt.
    value = '\x1b7' + f'\x1b[1;{bottom}r'
    for row, col, line, color in lines:
        foreground, background = color if isinstance(color, tuple) else (color, None)
        backdrop = '49' if background is None else f'48;5;{background}'
        value += f'\x1b[{backdrop}m\x1b[1;38;5;{foreground}m\x1b[{row};{col}H{line}'
    return (value + '\x1b8').encode()


class Boundaries:
    """Never insert artwork into a CSI/OSC sequence split across reads."""
    def __init__(self):
        self.pending = b''

    def take(self, data):
        data = self.pending + data
        index = 0
        start = None
        while index < len(data):
            if data[index] != 27:
                index += 1
                continue
            start = index
            index += 1
            if index == len(data):
                break
            code = data[index]
            index += 1
            if code == 91:
                while index < len(data) and not 64 <= data[index] <= 126:
                    index += 1
                if index == len(data):
                    break
                index += 1
            elif code in (93, 80, 95, 94):
                while index < len(data) and data[index] != 7 and data[index:index+2] != b'\x1b\\':
                    index += 1
                if index == len(data):
                    break
                index += 1 if data[index] == 7 else 2
            elif code in (40, 41):
                if index == len(data):
                    break
                index += 1
            start = None
        end = len(data) if start is None else start
        # A UTF-8 glyph may be split even when the ANSI sequence is complete.
        for offset in range(max(0, end - 4), end):
            lead = data[offset]
            needed = 2 if 0xC2 <= lead <= 0xDF else 3 if 0xE0 <= lead <= 0xEF else 4 if 0xF0 <= lead <= 0xF4 else 0
            if needed and end - offset < needed and all(0x80 <= b <= 0xBF for b in data[offset+1:end]):
                end = offset
                break
        self.pending = data[end:]
        return data[:end]


TERMINAL_ESCAPE = re.compile(
    rb'\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|'
    rb'[P_^].*?\x1b\\|[ -/]*[@-Z\\-~])', re.DOTALL
)


def recent_plain_output(data, rows):
    """Recover recent messages and the current prompt after terminal reflow."""
    plain = TERMINAL_ESCAPE.sub(b'', data).decode('utf-8', errors='ignore')
    plain = ''.join(char for char in plain if char in '\r\n\t' or char.isprintable())
    lines = [line.rsplit('\r', 1)[-1] for line in plain.replace('\r\n', '\n').split('\n')]
    return '\r\n'.join(lines[-max(1, rows // 2):]).encode()


ENTER_SCREEN = b'\x1b[?1049h'
LEAVE_SCREEN = b'\x1b[0m\x1b[r\x1b[?1049l'
CLEAR_FRAME = b'\x1b[0m\x1b[r\x1b[2J\x1b[H'
WAIT_MOUSE = b'\x1b[?25l\x1b[?1000h\x1b[?1006h'
RESET_MOUSE = b'\x1b[?1006l\x1b[?1000l\x1b[?25h'


def run(command, allow_pipe_output=False, log_file=None, title=None):
    # Redirected output and noninteractive runs preserve ordinary stream behavior.
    if not os.isatty(0) or (not os.isatty(1) and not allow_pipe_output) or os.environ.get('TERM') == 'dumb':
        return subprocess.call(command)
    action_log = open(log_file, 'ab') if log_file else None
    master, slave = pty.openpty()
    original = termios.tcgetattr(0)
    previous = {}
    process = None
    boundary = Boundaries()
    size = [24, 80]
    footer = b''
    scroll_end = b''
    screen_active = False
    waiting = False
    wait_input = b''
    cancelled = None
    heading = (title + '\r\n\r\n').encode() if title else b''
    recent_output = b''
    resize_pending = False

    def output(value):
        sys.stdout.buffer.write(value)
        sys.stdout.buffer.flush()

    def forward(signum):
        if process and process.poll() is None:
            try:
                os.killpg(process.pid, signum)
            except ProcessLookupError:
                pass

    def resized(initial=False):
        nonlocal size, footer, scroll_end
        winsize = fcntl.ioctl(0, termios.TIOCGWINSZ, b'\0' * 8)
        rows, cols, xpixel, ypixel = struct.unpack('HHHH', winsize)
        new_size = [rows or 24, cols or 80, xpixel, ypixel]
        size = new_size
        bottom, _ = artwork(*size[:2])
        footer = decoration(*size[:2])
        scroll_end = f'\x1b[1;{bottom}r'.encode() if footer else b'\x1b[r'
        # Reflow can move the old artwork anywhere. Clear the dedicated
        # screen and rebuild it from child output, which never contains it.
        replay = b'' if initial else recent_plain_output(recent_output, bottom)
        output(CLEAR_FRAME + scroll_end + heading + replay + footer)
        if not waiting:
            child_size = struct.pack('HHHH', max(1, bottom), size[1], 0, 0)
            fcntl.ioctl(master, termios.TIOCSWINSZ, child_size)

    def interrupted(signum, frame):
        nonlocal cancelled
        cancelled = signum
        forward(signum)

    def request_resize(signum, frame):
        # A signal may arrive while stdout is flushing. Draw only from the
        # relay loop so a resize cannot recursively enter BufferedWriter.
        nonlocal resize_pending
        resize_pending = True

    def child_setup():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    try:
        for signum in (signal.SIGWINCH, signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            previous[signum] = signal.getsignal(signum)
            signal.signal(signum, request_resize if signum == signal.SIGWINCH else interrupted)
        tty.setraw(0)
        output(ENTER_SCREEN)
        screen_active = True
        resized(initial=True)
        process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave if action_log else None, preexec_fn=child_setup)
        os.close(slave)
        slave = -1
        inputs = [master, 0]
        while master in inputs:
            if resize_pending:
                resize_pending = False
                resized()
            ready, _, _ = select.select(inputs, [], [], 0.2)
            if not ready and process.poll() is not None:
                break
            for fd in ready:
                try:
                    data = os.read(fd, 65536)
                except OSError as error:
                    if fd == master and error.errno == errno.EIO:
                        data = b''
                    else:
                        raise
                if not data:
                    inputs.remove(fd)
                    continue
                if fd == master:
                    if resize_pending:
                        resize_pending = False
                        resized()
                    if action_log:
                        action_log.write(data)
                        action_log.flush()
                    chunk = boundary.take(data)
                    if chunk:
                        recent_output = (recent_output + chunk)[-65536:]
                        if footer:
                            chunk = chunk.replace(b'\x1b[r', scroll_end)
                        output(chunk + footer)
                else:
                    os.write(master, data)
        code = process.wait()
        code = code if code >= 0 else 128 - code
        if title is not None and code not in (129, 130, 143) and not cancelled:
            result = '✓ 操作完成' if code == 0 else '✗ 操作未完成，请查看上方提示'
            prompt = f'\r\n{result}\r\n\r\n请点击窗口任意位置返回Renkit\r\n'.encode()
            recent_output += prompt
            waiting = True
            termios.tcflush(0, termios.TCIFLUSH)
            output(prompt + footer + WAIT_MOUSE)
            while not cancelled:
                if resize_pending:
                    resize_pending = False
                    resized()
                if not select.select([0], [], [], 0.2)[0]:
                    continue
                data = os.read(0, 1024)
                if not data or b'\x03' in data:
                    break
                wait_input = (wait_input + data)[-1024:]
                if re.search(rb'\x1b\[<0;\d+;\d+M|[\r\n]', wait_input):
                    break
        return 128 + cancelled if cancelled else code
    finally:
        if process and process.poll() is None:
            forward(signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                forward(signal.SIGKILL)
                process.wait()
        termios.tcsetattr(0, termios.TCSANOW, original)
        if screen_active:
            # Keep the regular terminal and its scrollback out of the artwork.
            output((RESET_MOUSE if waiting else b'') + LEAVE_SCREEN)
            output(recent_plain_output(recent_output, 200))
        for signum, handler in previous.items():
            signal.signal(signum, handler)
        os.close(master)
        if action_log:
            action_log.close()
        if slave >= 0:
            os.close(slave)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--allow-pipe-output', action='store_true')
    parser.add_argument('--log-file')
    parser.add_argument('--title')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('missing command')
    try:
        sys.exit(run(command, args.allow_pipe_output, args.log_file, args.title))
    except OSError as error:
        print(f"安装界面无法启动当前操作：{error}", file=sys.stderr)
        sys.exit(127 if isinstance(error, FileNotFoundError) else 126)
