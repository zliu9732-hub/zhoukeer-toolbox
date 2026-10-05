"""Relay a terminal action while keeping Renkit's yellow signature below its logs."""
import argparse
import errno
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import tty

FONT = {
 'R': ['████ ', '█   █', '████ ', '█  █ ', '█   █'],
 'E': ['█████', '█    ', '████ ', '█    ', '█████'],
 'N': ['█   █', '██  █', '█ █ █', '█  ██', '█   █'],
 'A': [' ███ ', '█   █', '█████', '█   █', '█   █'],
 'M': ['█   █', '██ ██', '█ █ █', '█   █', '█   █'],
 'I': ['█████', '  █  ', '  █  ', '  █  ', '█████'],
 'Y': ['█   █', ' █ █ ', '  █  ', '  █  ', '  █  '],
}
LABEL = 'RenAmamiya'
FISH = '><(((°>'
FISH_LARGE = ['     ▄▄▄▄▄    ', ' ▄▄████████▄  ', '◀██████○████▶ ', ' ▀▀████████▀  ', '     ▀▀▀▀▀    ']


def artwork(rows, columns):
    if rows < 14 or columns < 22:
        return rows, []
    if rows >= 24 and columns >= 90:
        name_lines = [' '.join(FONT[c][line] for c in 'RENAMAMIYA') for line in range(5)]
        icon_width = len(FISH_LARGE[0])
        width = icon_width + 2 + len(name_lines[0])
        column = max(1, columns - width - 2)
        top = rows - 6
        lines = []
        for i in range(5):
            lines.append((top + i, column, FISH_LARGE[i], 220))
            lines.append((top + i, column + icon_width + 2, name_lines[i], 196))
        lines.append((rows - 1, columns - len(LABEL) - 2, LABEL, 196))
    else:
        width = len(FISH) + 2 + len(LABEL)
        column = max(1, columns - width - 2)
        top = rows - 1
        lines = [(top, column, FISH, 220),
                 (top, column + len(FISH) + 2, LABEL, 196)]
    return top - 1, lines


def decoration(rows, columns):
    bottom, lines = artwork(rows, columns)
    if not lines:
        return b''
    # Save cursor/rendition; the child retains its log position and input prompt.
    value = '\x1b7' + f'\x1b[1;{bottom}r'
    for row, col, line, color in lines:
        value += f'\x1b[1;38;5;{color}m\x1b[{row};{col}H{line}'
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


def run(command, keep_footer=False, allow_pipe_output=False, log_file=None):
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
    previous_art = []

    def output(value):
        sys.stdout.buffer.write(value)
        sys.stdout.buffer.flush()

    def forward(signum):
        if process and process.poll() is None:
            try:
                os.killpg(process.pid, signum)
            except ProcessLookupError:
                pass

    def resized(signum=None, frame=None):
        nonlocal size, previous_art
        winsize = fcntl.ioctl(0, termios.TIOCGWINSZ, b'\0' * 8)
        rows, cols, _, _ = struct.unpack('HHHH', winsize)
        size = [rows or 24, cols or 80]
        fcntl.ioctl(master, termios.TIOCSWINSZ, winsize)
        if process and process.poll() is None:
            forward(signal.SIGWINCH)
        # Clear only cells previously owned by the signature before a resize.
        erase = '\x1b7'
        for row, col, line, color in previous_art:
            if row <= size[0] and col <= size[1]:
                width = len(line)
                erase += f'\x1b[{row};{col}H' + ' ' * min(width, size[1] - col)
        output((erase + '\x1b8').encode())
        previous_art = artwork(*size)[1]
        output(decoration(*size))

    def interrupted(signum, frame):
        if process and process.poll() is None:
            forward(signum)

    def child_setup():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    try:
        resized()
        for signum in (signal.SIGWINCH, signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            previous[signum] = signal.getsignal(signum)
            signal.signal(signum, resized if signum == signal.SIGWINCH else interrupted)
        tty.setraw(0)
        process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave if action_log else None, preexec_fn=child_setup)
        os.close(slave)
        slave = -1
        inputs = [master, 0]
        while master in inputs:
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
                    if action_log:
                        action_log.write(data)
                        action_log.flush()
                    chunk = boundary.take(data)
                    if chunk:
                        bottom, lines = artwork(*size)
                        if lines:
                            chunk = chunk.replace(b'\x1b[r', f'\x1b[1;{bottom}r'.encode())
                        output(chunk)
                        output(decoration(*size))
                else:
                    os.write(master, data)
        if boundary.pending:
            output(boundary.pending)
        code = process.wait()
        return code if code >= 0 else 128 - code
    finally:
        if process and process.poll() is None:
            forward(signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                forward(signal.SIGKILL)
                process.wait()
        for signum, handler in previous.items():
            signal.signal(signum, handler)
        termios.tcsetattr(0, termios.TCSANOW, original)
        if not keep_footer or not process or process.returncode is None or process.returncode < 0:
            output(b'\x1b[0m\x1b[r')
        os.close(master)
        if action_log:
            action_log.close()
        if slave >= 0:
            os.close(slave)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--keep-footer', action='store_true')
    parser.add_argument('--allow-pipe-output', action='store_true')
    parser.add_argument('--log-file')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('missing command')
    try:
        sys.exit(run(command, args.keep_footer, args.allow_pipe_output, args.log_file))
    except OSError as error:
        print(f"安装界面无法启动当前操作：{error}", file=sys.stderr)
        sys.exit(127 if isinstance(error, FileNotFoundError) else 126)
