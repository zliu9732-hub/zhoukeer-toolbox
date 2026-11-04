"""Real desktop menu navigation in private PTYs; installers are never executed."""
import os,pty,re,subprocess,tempfile,tty
from pathlib import Path
from test_responsive_ui import ROOT,SHELL,check,click,item_position,read_until,resize
source=(ROOT/'main-bazzite.sh').read_text()
def extract(name):return re.search(r'^'+name+r'\(\).*?^}',source,re.M|re.S).group()
pages=[[
 ('游戏封面更换','steamgriddb'),('主题美化','cssloader'),('文件传输助手','friendeck'),('音乐播放器','deckymusic'),('主页主题（ThemeHub）','deckhomethemes'),('屏幕色彩','screen-colors'),('SteamDB 游戏数据','steamdb-info')],
 [('GFG Extreme','gfg-extreme'),('Fantastic 风扇控制','fantastic'),('游戏翻译','decky-translator'),('ROG White 白色主题','rog_white_theme.sh:install'),('掌机 Pink 粉色主题','handheld_pink_theme.sh:install'),('粉白渐变主题','pink_white_gradient_theme.sh:install')]]
with tempfile.TemporaryDirectory(prefix='renkit-desktop-plugin-pages-') as directory:
 fixture=Path(directory)/'menu.sh'
 fixture.write_text('RENKIT_COMPACT_MENUS=1\n'+SHELL.split("draw_category_frame software '' ''")[0]+'\n'+
 '\n'.join(extract(n) for n in ['apply_navigation','read_touch_menu','bazzite_common_feature_singles_menu','bazzite_handheld_plugins_more_menu'])+r'''
confirm_and_run() {
 if [ "${@: -1}" = install ]; then action="${@: -2:1}"; action="${action##*/}:install"; else action="${@: -1}"; fi
 printf '\nACTION=%s\n' "$action"
}
NEXT_CATEGORY=games
bazzite_common_feature_singles_menu || true
printf '\nHANDHELD\n'
bazzite_handheld_plugins_more_menu || true
printf '\nDONE\n'
''')
 for columns,rows in [(70,21),(124,21),(120,32)]:
  master,slave=pty.openpty();tty.setraw(slave);resize(master,columns,rows)
  process=subprocess.Popen(['bash',str(fixture)],env=dict(os.environ,UI_TEST_ROOT=str(ROOT),UI_TEST_MODE='live'),stdin=slave,stdout=slave,stderr=slave);os.close(slave)
  try:
   frame=read_until(master,b'\x1b[?1006h')
   for page,items in enumerate(pages):
    check('窗口太小' not in frame,'Real desktop menu blocked')
    for label,action in items:
     y,x=item_position(frame,label);check(1<=y<rows,'Clipped label '+label)
     os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h')
     check('ACTION='+action in frame,'Wrong installer for '+label)
    if not page:
     y,x=item_position(frame,'下一页');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h')
   y,x=item_position(frame,'上一页');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h')
   check('ThemeHub' in frame and 'GFG Extreme' not in frame,'Previous-page navigation failed')
   y,x=item_position(frame,'返回首页');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h')
   check('HANDHELD' in frame,'Home return did not exit submenu')
   y,x=item_position(frame,'AYANEO3 Companion');os.write(master,click(x,y));frame=read_until(master,b'\x1b[?1006h')
   check('ACTION=ayaneo3' in frame,'AYANEO3 route missing')
   y,x=item_position(frame,'返回上一页');os.write(master,click(x,y));read_until(master,b'DONE')
   check(process.wait(timeout=3)==0,'Menu test failed')
  finally:
   if process.poll() is None:process.kill()
   process.wait();os.close(master)
print('PASS: Bazzite common plugin pages, all new installers, previous/next/home and AYANEO3 at 70/124×21 and 120×32; no installers executed')
