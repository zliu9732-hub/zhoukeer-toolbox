"""Exercise the real menu/action screen lifecycle in a private terminal."""
import os
from pathlib import Path
import pty
import re
import signal
import subprocess
import tempfile
import tty

from test_responsive_ui import ROOT, SHELL, check, click, item_position, read_until, resize


def audio_confirmation_test(directory, source):
    """Navigate real handheld pages and cancel/confirm without running an installer."""
    extract = lambda name: re.search(r'^' + name + r'\(\).*?^}', source, re.M | re.S).group()
    fixture = directory / 'audio-menu.sh'
    fixture.write_text(SHELL.split("draw_category_frame software '' ''")[0]
                       + 'RENKIT_STEAMOS_DUAL_NAV=1\n'
                       + '\n'.join(extract(name) for name in
                                   ['apply_navigation', 'read_touch_menu', 'handheld_more_menu',
                                    'claw_g3e_audio_menu', 'claw_g3e_audio_confirm']) + r'''
bash() { [ "$*" = "$PROJECT_ROOT/modules/claw_g3e_audio.sh plan" ] || exit 92; }
run_action() {
    [ "$#" -eq 6 ] && [ "$2" = env ] && [ "$3" = ZHOUKEER_AUTO_CONFIRM=1 ] &&
        [ "$4" = bash ] && [ "$5" = "$PROJECT_ROOT/modules/claw_g3e_audio.sh" ] &&
        [ "$6" = install ] || exit 94
    printf '\nMOCK_AUDIO_INSTALL\n'
}
NEXT_CATEGORY=advanced
handheld_more_menu
printf '\nAUDIO_FLOW_DONE\n'
''')
    for action in ('返回', '确认修复'):
        master, slave = pty.openpty()
        tty.setraw(slave)
        resize(master, 70, 24)
        process = subprocess.Popen(['bash', str(fixture)],
                                   env=dict(os.environ, UI_TEST_ROOT=str(ROOT), UI_TEST_MODE='live'),
                                   stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        try:
            frame = read_until(master, b'\x1b[?1006h')
            y, x = item_position(frame, '微星 G3E 无声音修复')
            os.write(master, click(x, y))
            frame = read_until(master, b'\x1b[?1006h')
            y, x = item_position(frame, '修复 G3E 无声音')
            os.write(master, click(x, y))
            frame = read_until(master, b'\x1b[?1006h')
            for notice in ('实验性修复，需要管理员权限', '安装系统组件和开机音频修复',
                           '暂时关闭只读保护，结束后恢复', '可能增加待机耗电',
                           '系统更新后可能需要重新修复', '完成后手动重启，请先保存工作'):
                check(notice in frame, 'Audio risk notice omitted')
                y, x = item_position(frame, notice)
                # Minimum-size screen must show the complete notices, with no clipping.
                import unicodedata
                width = sum(2 if unicodedata.east_asian_width(c) in ('W', 'F') else 1 for c in notice)
                check(x + 1 + width <= 70, 'Audio risk notice clipped in minimum window')
            check('MOCK_AUDIO_INSTALL' not in frame, 'Audio install preceded confirmation')
            y, x = item_position(frame, action)
            os.write(master, click(x, y))
            output = read_until(master, b'\x1b[?1006h')
            check(('MOCK_AUDIO_INSTALL' in output) == (action == '确认修复'),
                  'Audio cancel/confirm dispatched the wrong action')
            # Both choices return to the G3E page; Back then returns through its parent.
            y, x = item_position(output, '返回掌机适配')
            os.write(master, click(x, y))
            frame = read_until(master, b'\x1b[?1006h')
            check('更多掌机功能' in frame, 'Audio Back lost its parent page')
            y, x = item_position(frame, '返回掌机适配')
            os.write(master, click(x, y))
            read_until(master, b'AUDIO_FLOW_DONE')
            check(process.wait(timeout=3) == 0, 'Audio menu failed')
        finally:
            if process.poll() is None:
                process.kill()
            process.wait()
            os.close(master)


def main():
    source = (ROOT / 'main.sh').read_text()
    extract = lambda name: re.search(r'^' + name + r'\(\).*?^}', source, re.M | re.S).group()
    traps = '\n'.join(line for line in source.splitlines() if line.startswith('trap '))
    fixture_source = (SHELL.split("draw_category_frame software '' ''")[0]
                      + 'UI_MENU_SCREEN_ENABLED=1\n'
                      + extract('pause_menu') + '\n' + extract('run_action') + '\n' + traps + r'''
clear() { printf '\033[2J\033[H'; }
mock_action() { for ((i=0; i<100; i++)); do printf 'ACTION_LOG_%s\n' "$i"; done; }
frame() {
    draw_category_frame software '' ''
    ui_touch_button 2 '' TOP 'Top touch target'
    ui_touch_button 23 '' BOTTOM 'Bottom touch target'
    ui_prompt
}
frame
choice="$(read_menu_choice right:2-3:top right:23-24:bottom)"
[ "$choice" = top ] || exit 91
run_action MOCK_ACTION mock_action
frame
while read_ui_event; do :; done
''')
    with tempfile.TemporaryDirectory() as directory:
        fixture = Path(directory) / 'screen.sh'
        fixture.write_text(fixture_source)
        for end_signal, expected_code in [(signal.SIGTERM, 143), (signal.SIGINT, 130),
                                          (signal.SIGHUP, 129)]:
            master, slave = pty.openpty()
            tty.setraw(slave)
            resize(master, 120, 32)
            process = subprocess.Popen(['bash', str(fixture)],
                                       env=dict(os.environ, UI_TEST_ROOT=str(ROOT), UI_TEST_MODE='live'),
                                       stdin=slave, stdout=slave, stderr=slave,
                                       start_new_session=True)
            os.close(slave)
            try:
                frame = read_until(master, '触屏或触控板点击功能'.encode())
                check(frame.count('\x1b[?1049h') == 1, 'Menu did not enter one independent screen')
                check('\x1b[3J' not in frame, 'Menu erased installation history')
                # Resize replay stays on the same screen; re-entering 1049 would erase it.
                resize(master, 160, 48)
                frame = read_until(master, '触屏或触控板点击功能'.encode())
                check('\x1b[?1049h' not in frame and '\x1b[?1049l' not in frame,
                      'Resize switched menu screens')
                y, x = item_position(frame, 'TOP')
                # Wheel/drag/release must not select a button; the following top tap works.
                os.write(master, f'\x1b[<64;{x};{y}M\x1b[<65;{x};{y}M'
                         f'\x1b[<32;{x};{y}M\x1b[<0;{x};{y}m'.encode() + click(x, y))
                logs = read_until(master, '请点击窗口任意位置返回Renkit'.encode())
                check(logs.index('\x1b[?1049l') < logs.index('ACTION_LOG_0'),
                      'Action output still uses the non-scrollable menu screen')
                check('ACTION_LOG_99' in logs, 'Action log lost output')
                os.write(master, click(2, 2))
                frame = read_until(master, '触屏或触控板点击功能'.encode())
                check(frame.count('\x1b[?1049h') == 1, 'Return did not restore the fixed menu')
                check('TOP' in frame and 'BOTTOM' in frame, 'Return lost touch buttons')
                process.send_signal(end_signal)
                restored = read_until(master, b'\x1b[?1049l')
                check('\x1b[?25h' in restored and '\x1b[?1000l' in restored,
                      'Exit did not restore cursor/mouse input')
                check(restored.count('\x1b[?1049l') == 1, 'Exit switched screens more than once')
                check(process.wait(timeout=3) == expected_code, 'Signal exit status was masked')
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
                os.close(master)
        audio_confirmation_test(Path(directory), source)
        # Reuse the real confirmation rendering and click dispatcher for InputPlumber.
        prefix = SHELL.split("draw_category_frame software '' ''")[0]
        for decision in ('确认更新', '返回'):
            fixture.write_text(prefix + extract('read_touch_menu') + '\n'
                               + extract('apply_navigation') + '\n'
                               + extract('inputplumber_manual_confirm') + r'''
bash() { [ "$*" = "$PROJECT_ROOT/modules/inputplumber_update.sh plan" ] || exit 91; }
run_action() {
    [ "$#" -eq 6 ] && [ "$2" = env ] && [ "$3" = ZHOUKEER_AUTO_CONFIRM=1 ] &&
        [ "$4" = bash ] && [ "$5" = "$PROJECT_ROOT/modules/inputplumber_update.sh" ] &&
        [ "$6" = update ] || exit 92
    printf '\nMOCK_INPUTPLUMBER_UPDATE\n'
}
NEXT_CATEGORY=advanced
inputplumber_manual_confirm
printf '\nCONFIRMATION_DONE\n'
''')
            master, slave = pty.openpty()
            tty.setraw(slave)
            resize(master, 70, 24)
            process = subprocess.Popen(['bash', str(fixture)],
                                       env=dict(os.environ, UI_TEST_ROOT=str(ROOT), UI_TEST_MODE='live'),
                                       stdin=slave, stdout=slave, stderr=slave)
            os.close(slave)
            try:
                frame = read_until(master, b'\x1b[?1006h')
                for notice in ('需要管理员权限', '会更新并启用手柄与睡眠支持',
                               '手柄可能暂时断开', '暂时关闭只读保护，结束后恢复',
                               '请先保存工作，完成后关机再开机'):
                    check(notice in frame, 'InputPlumber risk notice missing')
                check('MOCK_INPUTPLUMBER_UPDATE' not in frame, 'Updated before consent')
                y, x = item_position(frame, decision)
                os.write(master, click(x, y))
                result = read_until(master, b'CONFIRMATION_DONE')
                check(('MOCK_INPUTPLUMBER_UPDATE' in result) == (decision == '确认更新'),
                      'InputPlumber confirmation dispatched the wrong action')
                check(process.wait(timeout=3) == 0, 'InputPlumber confirmation failed')
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait()
                os.close(master)
    print('PASS: fixed menu, wheel then top tap, resize, scrollable action logs, return and signal cleanup')


if __name__ == '__main__':
    main()
