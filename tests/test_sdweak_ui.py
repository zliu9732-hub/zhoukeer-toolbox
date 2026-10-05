"""Real terminal menu navigation with mocked preflight and installation."""
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
extract=lambda name: re.search(r'^'+name+r'\(\).*?^}',source,re.M|re.S).group()
with tempfile.TemporaryDirectory() as d:
 fixture=Path(d)/'menu.sh'
 fixture.write_text(SHELL.split("draw_category_frame software '' ''")[0]+'\n'+
 '\n'.join(extract(n) for n in ['apply_navigation','read_touch_menu','sdweak_manual_confirm','advanced_operations_menu','advanced_tools_menu'])+r'''
bash() { [ "$*" = "$PROJECT_ROOT/modules/sdweak.sh plan" ] || exit 91; }
run_action() {
 [ "$#" -eq 6 ] && [ "$2" = env ] && [ "$3" = ZHOUKEER_AUTO_CONFIRM=1 ] &&
 [ "$4" = bash ] && [ "$5" = "$PROJECT_ROOT/modules/sdweak.sh" ] && [ "$6" = install ] || exit 92
 printf '\nMOCK_SDWEAK_INSTALL\n'
}
NEXT_CATEGORY=advanced
advanced_tools_menu
printf '\nSDWEAK_FLOW_DONE\n'
''')
 for decision in ['返回','确认安装']:
  master,slave=pty.openpty();tty.setraw(slave);resize(master,70,24)
  process=subprocess.Popen(['bash',str(fixture)],env=dict(os.environ,UI_TEST_ROOT=str(ROOT),UI_TEST_MODE='live'),stdin=slave,stdout=slave,stderr=slave);os.close(slave)
  try:
   frame=read_until(master,b'\x1b[?1006h');y,x=item_position(frame,'高级操作');os.write(master,click(x,y))
   frame=read_until(master,b'\x1b[?1006h');y,x=item_position(frame,'安装 SDWEAK');os.write(master,click(x,y))
   frame=read_until(master,b'\x1b[?1006h')
   for notice in ['警告：仅 Steam Deck LCD / OLED 可用','其他掌机一律禁止安装','仅 SteamOS 3.8；先卸载 CryoUtilities','需要管理员权限，修改系统和启动设置','关闭部分安全保护，可能影响稳定性','失败可能留下改动；结束恢复只读保护']:
    check(notice in frame,'Missing risk notice');y,x=item_position(frame,notice)
    width=sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in notice)
    check(x+1+width<=70,f'Risk notice clipped: {notice} x={x}, width={width}')
   check('MOCK_SDWEAK_INSTALL' not in frame,'Install before consent')
   y,x=item_position(frame,decision);os.write(master,click(x,y));out=read_until(master,b'\x1b[?1006h')
   check(('MOCK_SDWEAK_INSTALL' in out)==(decision=='确认安装'),'Wrong dispatch')
   y,x=item_position(out,'返回更多设置');os.write(master,click(x,y));out=read_until(master,b'\x1b[?1006h')
   y,x=item_position(out,'返回首页');os.write(master,click(x,y));read_until(master,b'SDWEAK_FLOW_DONE')
   check(process.wait(timeout=3)==0,'Navigation failed')
  finally:
   if process.poll() is None:process.kill()
   process.wait();os.close(master)
print('PASS: reachable SDWEAK entry, complete warnings at 70x24, confirmation/cancel and return')
