"""Private PTYs and harmless Python/shell fixtures; no installers or network."""
import importlib.util
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import tempfile
import termios
import time
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
with tempfile.TemporaryDirectory() as directory:
 d=Path(directory);child=d/'action.py'
 child.write_text('''import os,sys,time
print("START",flush=True)
for i in range(100):print(f"LOG_{i:03}")
print("INPUT:",flush=True)
answer=sys.stdin.readline().strip()
print("ANSWER="+answer,flush=True)
print("SIZE="+str(os.get_terminal_size()),flush=True)
time.sleep(.1)
sys.exit(7 if answer=="fail" else 0)
''')
 for answer,status in [('yes',0),('fail',7)]:
  master,slave=pty.openpty();resize(master,120,32);original=input_state(slave)
  process=subprocess.Popen(['python3',str(ROOT/'scripts/terminal_brand.py'),'--log-file',str(d/'action.log'),'--','python3',str(child)],stdin=slave,stdout=slave,stderr=slave,env={**os.environ,'TERM':'xterm-256color'})
  try:
   frame=read_until(master,b'INPUT:')
   check(frame.startswith(b.SIGNATURE.decode()),'Yellow fish and red signature should appear once in the output stream')
   check('LOG_000' in frame and 'LOG_099' in frame,'Lost installer output')
   for cols,rows in [(70,24),(120,32),(18,10),(94,28)]:
    resize(master,cols,rows);os.kill(process.pid,signal.SIGWINCH)
   time.sleep(.25)
   os.write(master,(answer+'\n').encode());out=read_until(master,b'SIZE=os.terminal_size(columns=94, lines=28)');check(wait_exit(master,process)==status,'Child exit code changed')
   check('ANSWER='+answer in out,'Input was lost during resize')
   check('\x1b' not in frame.removeprefix(b.SIGNATURE.decode()) + out,'Relay inserted positioning or repaint sequences')
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
print('PASS: shared action/startup signature, repeated resize, input and logs, cancellation, redirects and argv')
