"""Audit actual ZIPs without starting the plugin or touching Linux state."""
import ast, base64, hashlib, importlib.util, json, os, subprocess, sys, tempfile, types, zipfile, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import localize_gfg_extreme as m
from framegen_package import zip_files,zip_modes,extract_verified
original,signed,plain=map(Path,sys.argv[1:4])
meta=m.meta()
with tempfile.TemporaryDirectory() as tmp:
 tmp=Path(tmp)
 m.prepare(signed,tmp/'signed');m.verify(tmp/'signed')
 original_files=zip_files(original);files=zip_files(signed);plain_files=zip_files(plain)
 assert set(files)==set(plain_files)
 modified={'dist/index.js','plugin.json','package.json','py_modules/gfg_plugin/kedavra/hud.py','py_modules/gfg_plugin/kedavra/hud_font.py'}
 for name,value in original_files.items():
  relative=name.split('/',1)[1]
  if relative not in modified:assert files[name]==value,relative
 assert json.loads(files['GFG-Extreme/plugin.json'])['author']=='Eugenio Segala'
 assert json.loads(files['GFG-Extreme/plugin.json'])['flags']==['root']
 assert json.loads(files['GFG-Extreme/package.json'])['version']=='3.0.10'
 assert zip_modes(signed)['GFG-Extreme/runtime/bin/gamescope']==0o755
 for name,data in plain_files.items():
  if name.endswith(('.js','.json','.py','.txt','.md','.sh')):assert b'renamamiya' not in data.lower() and b'renkit' not in data.lower(),name
 # Only display literals can differ in HUD; every numeric/control structure stays equal.
 old=original_files['GFG-Extreme/py_modules/gfg_plugin/kedavra/hud.py'].decode()
 for before,after in m.HUD_REPLACEMENTS.items():old=old.replace(before,after)
 assert old.encode()==files['GFG-Extreme/py_modules/gfg_plugin/kedavra/hud.py']
 # Atlas adds glyphs while keeping all original number/Latin pixels and metrics.
 def atlas(blob):
  tree=ast.parse(blob);data=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and n.targets[0].id=='DATA')
  return json.loads(zlib.decompress(base64.b64decode(''.join(data))))
 a=atlas(original_files['GFG-Extreme/py_modules/gfg_plugin/kedavra/hud_font.py']);b=atlas(files['GFG-Extreme/py_modules/gfg_plugin/kedavra/hud_font.py'])
 for style in a:
  for char,value in a[style]['glyphs'].items():assert b[style]['glyphs'][char]==value
  for char in '原生帧率关上限自动补流畅供电续航时功耗温度':assert char in b[style]['glyphs'] and any(base64.b64decode(b[style]['glyphs'][char]['a']))
 # Import only the pure bitmap renderer into a synthetic package, never plugin lifecycle.
 package=types.ModuleType('gfg_hud_test');package.__path__=[str(tmp/'signed/py_modules/gfg_plugin/kedavra')];sys.modules[package.__name__]=package
 spec=importlib.util.spec_from_file_location('gfg_hud_test.hud',Path(package.__path__[0])/'hud.py');hud=importlib.util.module_from_spec(spec);sys.modules[spec.name]=hud;spec.loader.exec_module(hud)
 from PIL import Image
 state={'state':'active','refresh_ns':11111111,'base_fps':30,'cap_fps':30,'multiplier':3,'auto':True}
 rates={'real':30,'gen':59,'repeat':1,'sources':30,'flips':90};extra={'tdp_w':10,'ceiling_w':15,'temp_c':70,'battery':{'percent':80,'external_power':True}}
 for scale in hud.SCALES:
  for detail in ['minimal','standard']:
   items=hud.gfg_items(state,rates,extra,detail)
   for item in items:
    for key in ['label','text','sub']:
     for char in item.get(key) or '':assert char in b['lab@'+str(scale)]['glyphs'],char
   w,h,pixels=hud.render(state,rates,scale,items);assert len(pixels)==w*h*4
   if len(sys.argv)>4:Image.frombytes('RGBA',(w,h),pixels,'raw','BGRA').save(Path(sys.argv[4])/f'hud-{detail}-{scale}.png')
 # Partial localization, modified backend, extra files, links and corrupt bytes rejected.
 (tmp/'signed/dist/index.js').write_text('partial Chinese')
 try:m.verify(tmp/'signed');raise AssertionError('partial package accepted')
 except ValueError:pass
 for kind in ['extra','link','corrupt']:
  broken=tmp/(kind+'.zip')
  if kind=='corrupt':broken.write_bytes(signed.read_bytes()[:-50])
  else:
   with zipfile.ZipFile(broken,'w') as z:
    for name,value in files.items():z.writestr(name,value)
    info=zipfile.ZipInfo('GFG-Extreme/bad');info.external_attr=(0o120777<<16) if kind=='link' else (0o100644<<16)
    z.writestr(info,'outside')
  try:m.prepare(broken,tmp/kind);raise AssertionError('bad package accepted')
  except (ValueError,zipfile.BadZipFile):pass
print('PASS: complete ZIP install root, every runtime file/mode, author/license, plain signature isolation, Chinese HUD glyph/render, corruption rejection and display-only backend diff')
