#!/usr/bin/env python3

"""Set the current user's password through passwd without exposing its prompts."""

import errno
import os
import pty
import select
import shutil
import signal
import sys
import time


PROMPT_TIMEOUT_SECONDS = 15
NEW_PASSWORD_PROMPTS = (b"new password:", b"new unix password:")
RETYPE_PASSWORD_PROMPTS = (
    b"retype new password:",
    b"retype new unix password:",
)


def child_exit_code(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


def stop_child(pid):
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    deadline = time.monotonic() + 1
    while time.monotonic() < deadline:
        waited, _ = os.waitpid(pid, os.WNOHANG)
        if waited == pid:
            return
        time.sleep(0.02)
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    os.waitpid(pid, 0)


def read_password():
    line = sys.stdin.buffer.readline(4098)
    if not line or not line.endswith(b"\n") or len(line) > 4097:
        raise ValueError("invalid password input")
    if sys.stdin.buffer.read(1):
        raise ValueError("password input contains extra lines")
    password = bytearray(line[:-1])
    if not password or b"\x00" in password or b"\r" in password:
        raise ValueError("invalid password value")
    return password


def run_passwd(password):
    passwd_path = shutil.which("passwd")
    if not passwd_path:
        return 10
    passwd_path = os.path.realpath(passwd_path)
    if not os.path.isfile(passwd_path) or not os.access(passwd_path, os.X_OK):
        return 10

    pid, master_fd = pty.fork()
    if pid == 0:
        environment = os.environ.copy()
        environment["LC_ALL"] = "C"
        try:
            os.execve(passwd_path, [passwd_path], environment)
        except OSError:
            os._exit(127)

    stage = 0
    tail = b""
    deadline = time.monotonic() + PROMPT_TIMEOUT_SECONDS
    master_open = True
    status = None
    try:
        while time.monotonic() < deadline:
            waited, current_status = os.waitpid(pid, os.WNOHANG)
            if waited == pid:
                status = current_status
                break

            if not master_open:
                time.sleep(0.02)
                continue
            readable, _, _ = select.select([master_fd], [], [], 0.2)
            if not readable:
                continue
            try:
                chunk = os.read(master_fd, 4096)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                chunk = b""
            if not chunk:
                os.close(master_fd)
                master_open = False
                continue

            tail = (tail + chunk.lower())[-4096:]
            expected_prompts = NEW_PASSWORD_PROMPTS if stage == 0 else RETYPE_PASSWORD_PROMPTS
            if stage < 2 and any(prompt in tail for prompt in expected_prompts):
                os.write(master_fd, password)
                os.write(master_fd, b"\n")
                stage += 1
                tail = b""
                continue
            if stage == 2 and any(
                prompt in tail for prompt in NEW_PASSWORD_PROMPTS + RETYPE_PASSWORD_PROMPTS
            ):
                stop_child(pid)
                return 12

        if status is None:
            stop_child(pid)
            return 11
        if stage != 2:
            return 12
        return child_exit_code(status)
    finally:
        if master_open:
            os.close(master_fd)


def main():
    try:
        password = read_password()
    except ValueError:
        return 2
    try:
        return run_passwd(password)
    finally:
        for index in range(len(password)):
            password[index] = 0


if __name__ == "__main__":
    raise SystemExit(main())
