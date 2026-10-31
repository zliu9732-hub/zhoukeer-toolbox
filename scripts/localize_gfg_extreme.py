#!/usr/bin/env python3
"""Build or validate a complete Chinese GFG Extreme package without running plugin code."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

from framegen_package import check_tree, digest, extract_verified

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / 'data/gfg_extreme_files.json'
ASSETS = ROOT / 'assets/gfg-extreme'
NAME = 'GFG Extreme 功耗与补帧'
HUD_REPLACEMENTS = {
    'f"{round(real)} REAL"':'f"{round(real)} 原生"',
    '"label": "FPS"':'"label": "帧率"',
    'else "OFF"':'else "关"',
    'f"CAP {base}"':'f"上限 {base}"',
    '("AUTO" if st.get("auto") else "GEN")':'("自动" if st.get("auto") else "补帧")',
    '"label": "PACE"':'"label": "流畅"',
    'text = "AC"':'text = "供电"',
    '"label": "BATTERY H"':'"label": "续航/时"',
    '"label": f"FPS · {real}" if real else "FPS"':'"label": f"帧率 · {real}" if real else "帧率"',
    '"label": "PACE %"':'"label": "流畅 %"',
    '"label": "TDP W"':'"label": "功耗 W"',
    '"label": "TEMP C"':'"label": "温度 C"',
}


def meta():
    return json.loads(META.read_text())


def build(archive, output, signed, node):
    m = meta()
    if digest(archive) != m['upstream_sha256']:
        raise ValueError('upstream package checksum mismatch')
    output = Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError('build directory already exists')
    upstream = {**m, 'package_sha256':m['upstream_sha256'], 'files':m['original_files'],
                'modes':m['original_modes'], 'plugin_name':'GFG Extreme'}
    extract_verified(archive, output, upstream)
    # Add the corresponding frontend source from the same pinned upstream tag.
    for source in (ASSETS / 'source').rglob('*'):
        if source.is_file():
            target = output / source.relative_to(ASSETS / 'source')
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target)
    for relative in ['dist/index.js','frontend/src/app.js']:
        target = output / relative
        subprocess.run([node,str(ROOT/'scripts/localize_gfg_ui.mjs'),str(target),str(target),
                        str(ROOT/'data/gfg_extreme_zh.json'),str(ASSETS/'zh-runtime.js'),
                        'signed' if signed else 'plain'],check=True)
    description = '自动调节游戏功耗与补帧，兼顾流畅表现和耗电。'
    if signed:
        description += '汉化：RenAmamiya。'
    plugin_path = output/'plugin.json'
    plugin = json.loads(plugin_path.read_text());plugin['name']=NAME;plugin['publish']['description']=description
    plugin_path.write_text(json.dumps(plugin,ensure_ascii=False,indent=2)+'\n')
    package_path = output/'package.json'
    package = json.loads(package_path.read_text());package['description']=description
    package_path.write_text(json.dumps(package,ensure_ascii=False,indent=2)+'\n')
    shim = output/'frontend/shim.js'
    text = shim.read_text();start=text.index('const manifest = ')+len('const manifest = ');end=text.index(';',start)
    shim.write_text(text[:start]+json.dumps(plugin,ensure_ascii=False)+text[end:])
    hud = output/'py_modules/gfg_plugin/kedavra/hud.py'
    text = hud.read_text()
    for before,after in HUD_REPLACEMENTS.items():
        if text.count(before)!=1:
            raise ValueError('unrecognized HUD display literal: '+before)
        text=text.replace(before,after)
    hud.write_text(text)
    shutil.copyfile(ASSETS/'hud_font.py',hud.with_name('hud_font.py'))
    shutil.copyfile(ASSETS/'NotoSansSC-OFL.txt',output/'third_party_licenses/NotoSansSC-OFL.txt')
    (output/'tools').mkdir(exist_ok=True)
    shutil.copyfile(ASSETS/'add_chinese_hud_font.py',output/'tools/add_chinese_hud_font.py')
    (output/'使用说明.txt').write_text(
        'GFG Extreme 3.0.10 中文版\n\n'+('RenAmamiya汉化\n\n' if signed else '')+
        '用于 Steam Deck / SteamOS 的游戏补帧与自动功耗调节。\n'
        '在插件商城的开发者设置中选择从文件安装插件，选中完整 ZIP。\n'
        '进入插件的“设置”页面，安装引擎后手动重启。\n'
        '需要管理员权限，会启用独立画面引擎并调节功耗；避免同时启用其他功耗控制插件。\n'
        '首次启动会按上游行为迁移旧设置并清理旧 GFG/MAKO 组件，备份保留在原用户目录。\n'
        '恢复原来的画面引擎：在插件“设置”中点击“移除”后重启；仅卸载插件不会自动移除引擎。\n'
        '若新的引擎无法进入游戏模式，上游的开机保护会在下次启动尝试恢复原组件。\n'
        '上游标为稳定版，但未完成该版本 Steam Deck 实机检查；中文界面在模拟环境验证，不能保证所有游戏或机型的表现。\n\n'
        '原作者：Eugenio Segala 和原项目贡献者。许可证：GPL-3.0-or-later。\n'
        '上游：https://github.com/wavessevaw/GFG-Extreme/tree/v3.0.10\n'
        '界面及游戏内信息显示改为中文，功耗、补帧、保护和恢复逻辑保持原样。\n'
        '新增中文 HUD 字形使用 Noto Sans SC（SIL OFL 1.1），原有 Inter 字形保持原样。\n'
        '字形来源：https://github.com/google/fonts/tree/main/ofl/notosanssc\n'
        '源字体 SHA256：a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da\n',encoding='utf-8')
    return output


def verify(root):
    m=meta()
    if not m['files'] or not m['package_sha256']:
        raise ValueError('translated package inventory missing')
    check_tree(root,m)


def prepare(archive,root):
    root=Path(root)
    if root.is_symlink() or (root.exists() and (not root.is_dir() or any(root.iterdir()))):
        raise ValueError('staging directory is not empty')
    extract_verified(archive,root,meta())


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=['check','prepare','build'])
    p.add_argument('root',type=Path)
    p.add_argument('--archive',type=Path)
    p.add_argument('--plain',action='store_true')
    p.add_argument('--node',default='node')
    a=p.parse_args()
    try:
        if a.mode=='check':verify(a.root)
        elif a.mode=='prepare':prepare(a.archive,a.root)
        else:build(a.archive,a.root,not a.plain,a.node)
    except (OSError,ValueError,KeyError,zipfile.BadZipFile,subprocess.CalledProcessError) as error:
        print(str(error),file=sys.stderr);return 1
    return 0


if __name__=='__main__':raise SystemExit(main())
