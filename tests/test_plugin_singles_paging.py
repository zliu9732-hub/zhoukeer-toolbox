"""Real touch navigation and mocked GUI choices, no installers or OS changes."""
import os,pty,re,subprocess,tempfile,tty
from pathlib import Path
from test_responsive_ui import ROOT,SHELL,check,click,item_position,read_until,resize
source=(ROOT/'main.sh').read_text()
def extract(text,name):return re.search(r'^'+name+r'\(\).*?^}',text,re.M|re.S).group()
with tempfile.TemporaryDirectory() as d:
 base=Path(d);fixture=base/'touch.sh'
 fixture.write_text(SHELL.split("draw_category_frame software '' ''")[0]+'\n'+
 '\n'.join(extract(source,n) for n in ['apply_navigation','read_touch_menu','feature_plugin_singles_menu'])+r'''
confirm_and_run() {
 [ "${@: -1}" = gfg-extreme ] || exit 93
 printf '\nMOCK_GFG_INSTALL\n'
}
NEXT_CATEGORY=games
feature_plugin_singles_menu
printf '\nFLOW_DONE\n'
''')
 for width in [70,120]:
  master,slave=pty.openpty();tty.setraw(slave);resize(master,width,26)
  p=subprocess.Popen(['bash',str(fixture)],env=dict(os.environ,UI_TEST_ROOT=str(ROOT),UI_TEST_MODE='live'),stdin=slave,stdout=slave,stderr=slave);os.close(slave)
  try:
   frame=read_until(master,b'\x1b[?1006h');check('GFG Extreme' not in frame,'Crowded page one')
   for label in ['游戏封面更换','音乐播放器','下一页','返回插件列表','返回首页']:item_position(frame,label)
   y,x=item_position(frame,'下一页');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h')
   for label in ['GFG Extreme','Fantastic','屏幕色彩','上一页']:item_position(frame,label)
   y,x=item_position(frame,'GFG Extreme');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h');check('MOCK_GFG_INSTALL' in frame,'Wrong touch dispatch')
   y,x=item_position(frame,'上一页');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h');check('GFG Extreme' not in frame,'Previous page failed')
   y,x=item_position(frame,'返回首页');os.write(master,click(x,y));read_until(master,b'FLOW_DONE');check(p.wait(timeout=3)==0,'Touch failed')
  finally:
   if p.poll() is None:p.kill()
   p.wait();os.close(master)
 # GUI dialog is replaced by deterministic choices persisted outside subshells.
 gui=base/'gui.sh';counter=base/'count';counter.write_text('0')
 gui.write_text('set -euo pipefail\nPROJECT_ROOT='+repr(str(ROOT))+'\nCOUNT='+repr(str(counter))+'\n'+extract((ROOT/'core/gui.sh').read_text(),'game_environment_gui_menu')+r'''
gui_dialog() {
 n=$(cat "$COUNT"); n=$((n+1)); echo "$n" > "$COUNT"
 case "$n" in
  1) echo feature-singles ;;
  2) [[ "$*" = *'（1/2）'* ]] && [[ "$*" != *gfg-extreme* ]] || exit 91; echo next ;;
  3) [[ "$*" = *'（2/2）'* ]] && [[ "$*" = *gfg-extreme* ]] || exit 92; echo gfg-extreme ;;
  4) echo previous ;;
  5) echo next ;;
  6) echo back ;;
  7) echo home ;;
  *) exit 94 ;;
 esac
}
gui_confirm() { [[ "$*" = *SteamOS* && "$*" = *管理员* && "$*" = *重启* && "$*" = *清理旧* ]]; }
run_gui_action() { [ "${@: -1}" = gfg-extreme ] || exit 95; printf 'MOCK_GUI_INSTALL\n'; }
game_environment_gui_menu
''')
 result=subprocess.run(['bash',str(gui)],capture_output=True,text=True,timeout=10)
 check(result.returncode==0 and 'MOCK_GUI_INSTALL' in result.stdout,result.stdout+result.stderr)
print('PASS: touch 70/120 columns, next/previous, action/return coordinates, GUI pages/confirmation/dispatch')
