"""Relay a terminal action with a yellow fish badge and red RenAmamiya name."""
import argparse
import errno
import fcntl
import os
import pty
import select
import signal
import subprocess
import sys
import termios
import tty

LABEL = 'RenAmamiya'
# Ordinary text in the output stream, so resizing can reflow it safely.
SIGNATURE = f'\x1b[1;38;5;220m><(((°>  \x1b[38;5;196m{LABEL}\x1b[0m\r\n'.encode()


def run(command, allow_pipe_output=False, log_file=None):
    # Redirected output and noninteractive runs preserve ordinary stream behavior.
    if not os.isatty(0) or (not os.isatty(1) and not allow_pipe_output) or os.environ.get('TERM') == 'dumb':
        return subprocess.call(command)
    action_log = open(log_file, 'ab') if log_file else None
    master, slave = pty.openpty()
    original = termios.tcgetattr(0)
    previous = {}
    process = None
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

    def resized():
        winsize = fcntl.ioctl(0, termios.TIOCGWINSZ, b'\0' * 8)
        fcntl.ioctl(master, termios.TIOCSWINSZ, winsize)

    def interrupted(signum, frame):
        if process and process.poll() is None:
            forward(signum)

    def request_resize(signum, frame):
        # Apply the new PTY size in the relay loop.
        nonlocal resize_pending
        resize_pending = True

    def child_setup():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    try:
        for signum in (signal.SIGWINCH, signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            previous[signum] = signal.getsignal(signum)
            signal.signal(signum, request_resize if signum == signal.SIGWINCH else interrupted)
        resized()
        tty.setraw(0)
        output(SIGNATURE)
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
                    output(data)
                else:
                    os.write(master, data)
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
        termios.tcsetattr(0, termios.TCSANOW, original)
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
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('missing command')
    try:
        sys.exit(run(command, args.allow_pipe_output, args.log_file))
    except OSError as error:
        print(f"安装界面无法启动当前操作：{error}", file=sys.stderr)
        sys.exit(127 if isinstance(error, FileNotFoundError) else 126)
