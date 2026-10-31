#!/usr/bin/env python3
"""Append Chinese coverage glyphs to the upstream atlas; keep every original glyph."""
import ast
import base64
import json
from pathlib import Path
import sys
import zlib
from PIL import Image, ImageDraw, ImageFont

original, font_path, output = map(Path, sys.argv[1:])
tree = ast.parse(original.read_text())
data = next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'DATA' for t in n.targets))
atlas = json.loads(zlib.decompress(base64.b64decode(''.join(data))))
chars = sorted(set('原生帧率关上限自动补流畅供电续航时功耗温度'))
sizes = {'fps':20,'val':16,'vsm':13,'sub':8,'lab':8}
for key, style in atlas.items():
    name, scale = key.split('@')
    font = ImageFont.truetype(str(font_path), round(sizes[name] * float(scale)))
    ascent, _ = font.getmetrics()
    for char in chars:
        assert char not in style['glyphs']
        x0,y0,x1,y1 = font.getbbox(char)
        w,h = max(0,x1-x0),max(0,y1-y0)
        image = Image.new('L',(max(w,1),max(h,1)),0)
        ImageDraw.Draw(image).text((-x0,-y0),char,font=font,fill=255)
        style['glyphs'][char] = {'x0':x0,'y0':y0+style['ascent']-ascent,'w':w,'h':h,'adv':font.getlength(char),'a':base64.b64encode(image.tobytes()).decode()}
blob=base64.b64encode(zlib.compress(json.dumps(atlas,separators=(',',':'),ensure_ascii=False).encode(),9)).decode()
output.write_text('"""HUD coverage atlas: original Inter and additional Chinese glyphs, SIL OFL 1.1.\nSee third_party_licenses/NotoSansSC-OFL.txt and tools/add_chinese_hud_font.py."""\nDATA = (\n'+''.join('    '+repr(blob[i:i+100])+'\n' for i in range(0,len(blob),100))+')\n')
print(len(chars),'new characters,',len(atlas),'styles,',len(blob),'bytes')
