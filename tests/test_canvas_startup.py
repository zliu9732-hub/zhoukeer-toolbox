"""Private PTYs and a simulated Konsole font API only; no OS/app/service changes."""
import os,pty,re,select,subprocess,tempfile,time,tty
from pathlib import Path
from test_responsive_ui import ROOT,check,click,item_position,resize

source=(ROOT/'main-bazzite.sh').read_text()
def extract(text,name):return re.search(r'^'+name+r'\(\).*?^}',text,re.M|re.S).group()
PREFIX=r'''
set -euo pipefail
# stty can only read/resize the test's own PTY. All Konsole operations are mocked.
stty() { case "$1" in size|rows) command stty "$@" ;; *) exit 91 ;; esac; }
tput() { case "$1" in lines) echo "$STALE_ROWS" ;; cols) echo 999 ;; esac; }
konsoleprofile() {
    font="${1##*,}"
    printf '%s\n' "$font" >> "$FONT_CALLS"
    [ "$FONT_MODE" != fail ] || return 1
    # Reproduce the real KDE tool: only emit OSC 50, never change the PTY itself.
    printf '\033]50;%s\a' "$1"
}
[ "$FONT_MODE" != missing ] || unset -f konsoleprofile
source "$UI_TEST_ROOT/core/ui.sh"
# Prevent tests from flushing buffered simulated clicks; no action is ever run.
ui_discard_pending_input() { :; }
run_action() { echo 'UNEXPECTED_ACTION'; exit 92; }
UI_LAYOUT_RETRY_COUNT=8
UI_LAYOUT_RETRY_INTERVAL=0.01
'''
SUFFIX=r'''
show_startup_loading
ui_apply_screen_font
# A captured action must not receive profile escape sequences. A terminal FD is used instead.
exec 9>&1
UI_TERMINAL_OUTPUT_READY=1
captured="$(ui_set_session_font 16 || true)"
[ -z "$captured" ] || exit 94
: > "$FONT_CALLS"
ui_wait_for_minimum_canvas || true
# The waiting logic must use the real PTY, even when tput / inherited LINES lie.
actual="$(ui_terminal_rows)"
read -r actual_rows actual_cols < <(stty size)
[ "$actual" = "$actual_rows" ] || exit 93
apply_navigation() { NEXT_CATEGORY="$1"; }
NEXT_CATEGORY=home
home_menu
printf '\nFIRST=%s FONT=%s\n' "$NEXT_CATEGORY" "$UI_FONT_SIZE"
home_menu
printf '\nDONE=%s FONT=%s\n' "$NEXT_CATEGORY" "$UI_FONT_SIZE"
'''
with tempfile.TemporaryDirectory(prefix='renkit-canvas-') as directory:
 base=Path(directory);fixture=base/'canvas.sh'
 fixture.write_text(PREFIX+'\n'+'\n'.join(extract(source,n)for n in ['show_startup_loading','read_touch_menu','home_menu'])+'\n'+SUFFIX)
 for cols,rows,stale,mode,compact in [(120,21,32,'apply',0),(66,30,32,'apply',0),(120,32,10,'apply',0),(65,20,32,'fail',0),(65,20,32,'ignore',0),(124,21,32,'ignore',1),(124,21,32,'missing',1)]:
  master,slave=pty.openpty();tty.setraw(slave);resize(master,cols,rows)
  calls=base/f'{cols}-{rows}-{mode}.calls'
  env=dict(os.environ,UI_TEST_ROOT=str(ROOT),ZHOUKEER_FONT_SIZE='16',BASE_COLS=str(cols),BASE_ROWS=str(rows),FONT_MODE=mode,FONT_CALLS=str(calls),STALE_ROWS=str(stale),RENKIT_COMPACT_MENUS=str(compact),COLUMNS='999',LINES=str(stale))
  p=subprocess.Popen(['bash',str(fixture)],env=env,stdin=slave,stdout=slave,stderr=slave);os.close(slave)
  stream=b'';offset=0
  def terminal_read(marker,timeout=5):
   # A tiny Konsole emulator applies only font requests actually received on the PTY.
   # Redirecting the tool's stdout to /dev/null therefore fails this regression.
   global stream,offset
   result=b'';deadline=time.monotonic()+timeout
   while marker not in result and time.monotonic()<deadline:
    if not select.select([master],[],[],0.05)[0]:continue
    chunk=os.read(master,65536);result+=chunk;stream+=chunk
    start=offset
    for match in re.finditer(rb'\x1b]50;Font=Noto Sans Mono CJK SC,(\d+)\x07',stream[start:]):
     font=int(match.group(1))
     if mode=='apply':resize(master,cols*16//font,rows*16//font)
     offset=start+match.end()
   check(marker in result,f'Terminal did not produce {marker!r}: {result[-400:]!r}')
   return result.decode()
  try:
   frame=terminal_read(b'\x1b[?1006h')
   if mode!='apply' and not compact:
    check('窗口太小' in frame and '当前 65 列 × 20 行' in frame,'Missing truthful fallback')
    os.write(master,click(40,22))
    # Font command success without an actual size change must never permit clicks.
    resize(master,120,32)
    frame=terminal_read(b'\x1b[?1006h')
   check('Renkit Bazzite版' in frame and '窗口太小' not in frame,'Startup failed to recover real Bazzite screen')
   if compact:
    for width,height in [(124,32),(124,21)]:
     resize(master,width,height)
     frame=terminal_read(b'\x1b[?1006h')
     check('窗口太小' not in frame and '退出Renkit' in frame,'Compact/full resize lost controls')
   y,x=item_position(frame,'退出Renkit');os.write(master,click(x,y))
   output=terminal_read(b'\x1b[?1006h');check('FIRST=nav-exit' in output,'Touch coordinates changed')
   y,x=item_position(output,'退出Renkit');os.write(master,click(x,y))
   result=terminal_read(b'DONE=nav-exit');check(p.wait(timeout=3)==0,'Startup fixture failed')
   check('UNEXPECTED_ACTION' not in frame+output+result,'Installer/action was invoked')
   font_requests=[int(s)for s in calls.read_text().splitlines()]
   if mode=='apply' and (cols<70 or rows<24):
    check(len(font_requests)==1 and 8<=font_requests[0]<16,'Repeated or invalid auto-fit')
   elif mode=='apply' or compact:check(not font_requests,'Usable window was unnecessarily resized by stale tput')
   check(all(8<=font<=32 for font in font_requests),'Font limit violated')
  finally:
   if p.poll() is None:p.kill()
   p.wait();os.close(master)
check('RENKIT_COMPACT_MENUS=1' in source, 'Desktop entry does not enable compact menus')
print('PASS: actual Bazzite home in private PTYs; short/narrow startup auto-fit, stale dimensions, failed/ignored requests, resize recovery and unchanged click actions')
