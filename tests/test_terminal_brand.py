"""Private PTYs and harmless Python/shell fixtures; no installers or network."""
import importlib.util
import os
from pathlib import Path
import pty
import re
import select
import signal
import subprocess
import tempfile
import termios
import time
import tty
from test_responsive_ui import ROOT,check,read_until,resize
spec=importlib.util.spec_from_file_location('brand',ROOT/'scripts/terminal_brand.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
def input_state(fd):
 state=termios.tcgetattr(fd)
 # macOS sets this transient kernel flag when returning pending input to canonical mode.
 state[3] &= ~getattr(termios,'PENDIN',0)
 return state
def wait_exit(master,process,timeout=4):
 # A real terminal continuously drains redraws. Keep doing the same after the
 # answer marker; otherwise a larger colored footer can fill a private PTY.
 deadline=time.monotonic()+timeout
 while process.poll() is None and time.monotonic()<deadline:
  if select.select([master],[],[],.05)[0]:
   try:os.read(master,65536)
   except OSError:pass
 return process.wait(timeout=1)
for rows,cols in [(32,120),(48,160),(31,94),(26,42),(24,70),(20,32),(18,28),(16,40),(14,22),(10,20)]:
 bottom,lines=b.artwork(rows,cols)
 for row,col,line,color in lines:
  check(row>bottom and row<=rows,'Artwork overlaps scrolling logs')
  width=b.cell_width(line)
  check(col+width<=cols,'Artwork exceeds terminal width')
  if line in [b.LABEL]+[' '.join(b.FONT[c][i] for c in 'RENAMAMIYA') for i in range(5)]:
   check(color==196,'Red name changed color')
  else:
   check(all(c in b.PALETTE.values() for c in (color if isinstance(color,tuple) else (color,))),'Mascot palette invalid')
  check('闲鱼' not in line,'Removed badge label still visible')
 check(bottom>=8,'Branding leaves too little space for logs')
for pixels in [b.FISH_PIXELS,b.FISH_SMALL_PIXELS,b.FISH_TINY_PIXELS]:
 check({'Y','W','K'} <= set(''.join(pixels)),'Mascot lost yellow head or eyes')
 for row,runs in enumerate(b.avatar_lines(pixels)):
  check(sum(len(text) for _,text,_ in runs)==len(pixels[0]),'Colored runs changed mascot width')
for sequence in [b'\x1b[2J',b'\x1b]0;title\x1b\\','🐟中文'.encode()]:
 for split in range(1,len(sequence)):
  parser=b.Boundaries();first=parser.take(sequence[:split]);second=parser.take(sequence[split:])
  check(first+second==sequence and not parser.pending,'Chunk boundary lost bytes')
 # No drawing may split a terminal control or a multibyte glyph.
parser=b.Boundaries();check(parser.take(b'abc\x1b[')==b'abc','Partial CSI leaked');check(parser.take(b'2J')==b'\x1b[2J','Partial CSI changed')
with tempfile.TemporaryDirectory() as directory:
 d=Path(directory);child=d/'action.py'
 child.write_text('''import os,sys,time
print("\\033[2J\\033[H\\033[rSTART",flush=True)
for i in range(100):print(f"LOG_{i:03}")
print("INPUT:",flush=True)
answer=sys.stdin.readline().strip()
print("ANSWER="+answer,flush=True)
time.sleep(.1)
sys.exit(7 if answer=="fail" else 0)
''')
 for answer,status in [('yes',0),('fail',7)]:
  master,slave=pty.openpty();resize(master,120,32);original=input_state(slave)
  process=subprocess.Popen(['python3',str(ROOT/'scripts/terminal_brand.py'),'--log-file',str(d/'action.log'),'--','python3',str(child)],stdin=slave,stdout=slave,stderr=slave,env={**os.environ,'TERM':'xterm-256color'})
  try:
   frame=read_until(master,b'INPUT:');check(b.LABEL in frame and '\x1b[1;38;5;220m' in frame and '\x1b[1;38;5;196m' in frame,'Yellow fish/red name missing')
   check('LOG_000' in frame and 'LOG_099' in frame,'Lost installer output')
   expected_region=f'\x1b[1;{b.artwork(32,120)[0]}r'
   check(expected_region in frame and '\x1b[rSTART' not in frame,'Child removed footer reservation')
   resize(master,70,24);os.kill(process.pid,signal.SIGWINCH)
   expected_region=f'\x1b[1;{b.artwork(24,70)[0]}r'
   frame=read_until(master,expected_region.encode());check(expected_region in frame,'Resize did not fit compact footer')
   os.write(master,(answer+'\n').encode());out=read_until(master,('ANSWER='+answer).encode());check(wait_exit(master,process)==status,'Child exit code changed')
   check(input_state(slave)==original,'Terminal input state not restored')
   logged=(d/'action.log').read_text();check('LOG_099' in logged and b.LABEL not in logged,'Decoration polluted action log')
  finally:
   if process.poll() is None:process.kill()
   process.wait();os.close(master);os.close(slave)
 # External cancellation is forwarded to the action and restores parent input.
 child.write_text('import time\nprint("WAIT",flush=True)\ntime.sleep(60)\n')
 master,slave=pty.openpty();resize(master,120,32);original=input_state(slave)
 process=subprocess.Popen(['python3',str(ROOT/'scripts/terminal_brand.py'),'--','python3',str(child)],stdin=slave,stdout=slave,stderr=slave,env={**os.environ,'TERM':'xterm-256color'})
 try:
  read_until(master,b'WAIT');process.send_signal(signal.SIGTERM)
  check(wait_exit(master,process)==143,'Cancellation status changed')
  check(input_state(slave)==original,'Cancellation left raw input')
 finally:
  if process.poll() is None:process.kill()
  process.wait();os.close(master);os.close(slave)
 # Redirects do not gain decorative ANSI, and preserve argv with spaces/metacharacters.
 result=subprocess.run(['python3',str(ROOT/'scripts/terminal_brand.py'),'--','python3','-c','import sys;print(sys.argv[1]);sys.exit(9)','a b;$(nothing)'],capture_output=True,text=True)
 check(result.returncode==9 and result.stdout=='a b;$(nothing)\n','Redirect/argv semantics changed')
 # Real startup launcher uses only fixture update/main files and a mocked uname.
 (d/'scripts').mkdir();(d/'scripts/terminal_brand.py').write_bytes((ROOT/'scripts/terminal_brand.py').read_bytes())
 (d/'launch.sh').write_bytes((ROOT/'launch.sh').read_bytes());(d/'main.sh').write_text('echo MAIN_DONE\n')
 (d/'update.sh').write_text('echo MOCK_UPDATE >> "$MOCK_STATE"\nsleep .2\n')
 (d/'.zhoukeer-installed').touch();(d/'bin').mkdir();(d/'bin/uname').write_text('#!/bin/sh\necho Linux\n');(d/'bin/uname').chmod(0o755)
 master,slave=pty.openpty();resize(master,120,32)
 env={**os.environ,'PATH':str(d/'bin')+':'+os.environ['PATH'],'TERM':'xterm-256color','ZHOUKEER_LAUNCH_LOG':str(d/'launch.log'),'MOCK_STATE':str(d/'calls')}
 process=subprocess.Popen(['bash',str(d/'launch.sh'),'--run-main'],stdin=slave,stdout=slave,stderr=slave,env=env)
 try:
  frame=read_until(master,b'MAIN_DONE');check('Renkit启动中' in frame and b.LABEL in frame,'Startup waiting screen missing signature')
  check((d/'calls').read_text()=='MOCK_UPDATE\n','Startup update duplicated or skipped')
  check(wait_exit(master,process)==0,'Startup branding broke launch')
 finally:
  if process.poll() is None:process.kill()
  process.wait();os.close(master);os.close(slave)
print('PASS: shared action/startup signature, clear/resize, input and logs, UTF-8/ANSI boundaries, cancellation, redirects and argv')
