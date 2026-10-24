"""Real menu PTY with fully mocked preflight/install dispatch."""
import os
from pathlib import Path
import pty
import re
import subprocess
import tempfile
import tty
import unicodedata
from test_responsive_ui import ROOT,SHELL,check,click,item_position,read_until,resize
source=(ROOT/'main.sh').read_text()
def extract(name):return re.search(r'^'+name+r'\(\).*?^}',source,re.M|re.S).group()
with tempfile.TemporaryDirectory() as directory:
 fixture=Path(directory)/'menu.sh'
 fixture.write_text(SHELL.split("draw_category_frame software '' ''")[0]+'\n'+
  '\n'.join(extract(n) for n in ['apply_navigation','read_touch_menu','rog_x20_confirm','rog_x20_menu','handheld_more_menu'])+r'''
bash() { [ "$*" = "$PROJECT_ROOT/modules/rog_x20_fix.sh plan" ] || exit 91; }
run_action() {
 [ "$#" -eq 6 ] && [ "$2" = env ] && [ "$3" = ZHOUKEER_AUTO_CONFIRM=1 ] &&
 [ "$4" = bash ] && [ "$5" = "$PROJECT_ROOT/modules/rog_x20_fix.sh" ] && [ "$6" = install ] || exit 92
 printf '\nMOCK_X20_INSTALL\n'
}
NEXT_CATEGORY=advanced
handheld_more_menu || true
printf '\nX20_FLOW_DONE\n'
''')
 for decision in ['返回','确认并一键修复']:
  master,slave=pty.openpty();tty.setraw(slave);resize(master,70,24)
  process=subprocess.Popen(['bash',str(fixture)],env=dict(os.environ,UI_TEST_ROOT=str(ROOT),UI_TEST_MODE='live'),stdin=slave,stdout=slave,stderr=slave);os.close(slave)
  try:
   frame=read_until(master,b'\x1b[?1006h');y,x=item_position(frame,'ROG 20 周年修复');os.write(master,click(x,y))
   frame=read_until(master,b'\x1b[?1006h');y,x=item_position(frame,'一键修复');os.write(master,click(x,y))
   frame=read_until(master,b'\x1b[?1006h')
   for notice in ['仅 ROG 20 周年 RC74XA','Valve SteamOS · BIOS .301/.303','不限系统小版本，核对声音驱动是否匹配',
                  '管理员权限，修改启动和声音设置','实验性组件，可能影响启动或声音',
                  '系统或 BIOS 更新前请先撤销','完成后手动重启，请先保存工作']:
    check(notice in frame,'Missing risk notice: '+notice);y,x=item_position(frame,notice)
    width=sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in notice)
    check(x+1+width<=70,'Risk clipped: '+notice)
   check('MOCK_X20_INSTALL' not in frame,'Executed without consent')
   y,x=item_position(frame,decision);os.write(master,click(x,y));out=read_until(master,b'\x1b[?1006h')
   check(('MOCK_X20_INSTALL' in out)==(decision=='确认并一键修复'),'Wrong consent dispatch')
   y,x=item_position(out,'返回掌机适配');os.write(master,click(x,y));out=read_until(master,b'\x1b[?1006h')
   y,x=item_position(out,'返回首页');os.write(master,click(x,y));read_until(master,b'X20_FLOW_DONE')
   check(process.wait(timeout=3)==0,'Navigation failed')
  finally:
   if process.poll() is None:process.kill()
   process.wait();os.close(master)
print('PASS: reachable X20 menu, complete risks at 70x24, cancel/confirm and back navigation')
