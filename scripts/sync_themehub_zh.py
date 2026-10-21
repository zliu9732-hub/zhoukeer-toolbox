#!/usr/bin/env python3
"""Check ThemeHub every 48 hours; extend the approved Chinese UI, verify, publish."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import urllib.request
import zipfile

from framegen_package import digest, version, zip_files, zip_modes
from inputplumber_release import AssetList
from localize_deckhomethemes import build_frontend
from sync_framegen_zh import backend_ui_inventory, due, fetch, translate_missing
from themehub_package import entry, extract

ROOT=Path(__file__).resolve().parent.parent
REPO='Kaal31/benderthemes'
MIRROR='zhoukeer-toolbox-mirror-4'
CATALOG_URL='https://gitee.com/zliu9732-hub/'+MIRROR+'/raw/main/themehub-auto/catalog.json'
REVISION=1

def latest_json(data):
    if data.get('draft') or data.get('prerelease'):raise ValueError('not a stable ThemeHub release')
    tag=data['tag_name'];version(tag)
    if not re.fullmatch(r'v?\d+\.\d+\.\d+',tag):raise ValueError('unexpected ThemeHub tag')
    filename='DeckHomeThemes-'+tag+'.zip'
    assets=[a for a in data['assets'] if a['name']==filename]
    if len(assets)!=1:raise ValueError('missing or ambiguous ThemeHub asset')
    asset=assets[0];sha=asset.get('digest','');url='https://github.com/'+REPO+'/releases/download/'+tag+'/'+filename
    if not re.fullmatch(r'sha256:[0-9a-f]{64}',sha) or asset['browser_download_url']!=url:raise ValueError('untrusted ThemeHub asset metadata')
    return {'version':tag.lstrip('v'),'sha256':sha[7:],'url':url}

def html_page(url):
    request=urllib.request.Request(url,headers={'User-Agent':'Renkit-ThemeHub-sync'})
    with urllib.request.urlopen(request,timeout=45) as response:
        if not response.url.startswith('https://github.com/'+REPO+'/releases/'):raise ValueError('unexpected ThemeHub release redirect')
        content=response.read(2097153)
        if len(content)>2097152:raise ValueError('ThemeHub release page too large')
        return response.url,content.decode('utf-8')

def latest():
    try:data=fetch('https://api.github.com/repos/'+REPO+'/releases/latest',limit=2097152)
    except OSError:
        url,_=html_page('https://github.com/'+REPO+'/releases/latest');tag=url.rsplit('/',1)[-1]
        if not re.fullmatch(r'v?\d+\.\d+\.\d+',tag):raise ValueError('not a stable ThemeHub tag')
        filename='DeckHomeThemes-'+tag+'.zip';path='/'+REPO+'/releases/download/'+tag+'/'+filename
        _,html=html_page('https://github.com/'+REPO+'/releases/expanded_assets/'+tag)
        parser=AssetList(path);parser.feed(html);parser.close()
        if parser.invalid or parser.depth or len(parser.matches)!=1 or len(parser.matches[0])!=1:raise ValueError('ThemeHub asset SHA256 unavailable')
        return {'version':tag.lstrip('v'),'sha256':next(iter(parser.matches[0])),'url':'https://github.com'+path}
    return latest_json(data)

def plan(catalog,release):
    current=entry(catalog)
    if version(release['version'])<version(current['upstream_version']):raise ValueError('ThemeHub downgrade rejected')
    return release['version']!=current['upstream_version'] or release['sha256']!=current['upstream_sha256'] or current['translation_revision']<REVISION

def node(*args):
    return subprocess.run([os.environ.get('RENKIT_NODE_BINARY','node'),str(ROOT/'scripts/themehub_ui.mjs'),*map(str,args)],check=True,capture_output=True,text=True).stdout

def build(release,archive,output,current=None,machine=False):
    if digest(archive)!=release['sha256']:raise ValueError('ThemeHub upstream checksum mismatch')
    raw=zip_files(archive);prefix='DeckHomeThemes/'
    if any(not name.startswith(prefix) for name in raw):raise ValueError('unexpected ThemeHub archive root')
    files={name[len(prefix):]:data for name,data in raw.items()};modes={name[len(prefix):]:mode for name,mode in zip_modes(archive).items()}
    if json.loads(files['plugin.json'])['name']!='ThemeHub' or version(json.loads(files['package.json'])['version'])!=version(release['version']):raise ValueError('ThemeHub identity/version mismatch')
    baseline=json.loads((ROOT/'data/themehub_ui_baseline.json').read_text())
    translations=json.loads((ROOT/'data/deckhomethemes_zh.json').read_text())
    original_translations=copy.deepcopy(translations)
    work=Path(output);work.mkdir(parents=True,exist_ok=True)
    source=work/'original.js';source.write_bytes(files['dist/index.js']);info=json.loads(node('inspect',source))
    backend=backend_ui_inventory(files)
    known=set(baseline['strings'])|set(baseline['backend_strings'])
    existing={**translations['strings'],**translations['children'],**translations['fragments']}
    extras=copy.deepcopy(entry(current).get('extra_translations',{})) if current else {}
    extras.update(json.loads((ROOT/'data/themehub_zh.json').read_text()))
    if any(key in existing and value!=existing[key] for key,value in extras.items()):raise ValueError('existing ThemeHub wording was changed')
    patterns_by_key={json.dumps(p,ensure_ascii=False):p for p in info['templates']+backend['templates']}
    approved_patterns={json.dumps(p,ensure_ascii=False) for p in baseline['templates']+baseline['backend_templates']}
    new_patterns=[p for key,p in patterns_by_key.items() if key not in approved_patterns]
    required=(set(info['strings'])|set(backend['strings']))-known
    for pattern in new_patterns:
        required.update(part for part in pattern if isinstance(part,str) and re.search('[A-Za-z]{2}',part))
    required-=set(existing)
    missing=sorted(required-set(extras))
    if missing:
        if not machine:raise ValueError('new ThemeHub UI needs translation: '+json.dumps(missing,ensure_ascii=False))
        extras.update(translate_missing(missing))
    if any(not isinstance(extras.get(text),str) or not re.search('[\u3400-\u9fff]',extras[text]) for text in required):raise ValueError('incomplete ThemeHub translation')
    translations['strings'].update(extras)
    # The approved renderer, existing dictionary and yellow author line are reused.
    # Only metadata for this verified official version and new text are supplied.
    translations['version']=release['version'];translations['upstream_sha256']=hashlib.sha256(files['dist/index.js']).hexdigest()
    runtime=(ROOT/'assets/deckhomethemes/zh-runtime.js').read_text()
    if new_patterns:
        runtime+='\n'+(ROOT/'assets/themehub/dynamic-messages.js').read_text().replace('__RENKIT_THEMEHUB_PATTERNS__',json.dumps(new_patterns,ensure_ascii=False))
    localized=build_frontend(files['dist/index.js'],translations,runtime)
    target=work/'localized.js';target.write_bytes(localized);node('verify',source,target)
    files['dist/index.js']=localized
    report={'schema':1,'translation_revision':REVISION,'plugin_name':'ThemeHub','api_plugin_names':info['api_plugin_names'],
        'upstream_frontend_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'approved_chinese_reference':baseline['translated_frontend_sha256'],
        'untranslated':[],'non_ui_ast_verified':True,'existing_translations_unchanged':all(translations[k]==original_translations[k] for k in ['children','fragments']) and all(translations['strings'][k]==v for k,v in original_translations['strings'].items()),
        'inherited_ui_strings':sorted((set(info['strings'])|set(backend['strings']))&known),
        'new_ui_strings':[{'source':text,'translation':extras[text]} for text in sorted(required)]}
    files['RENKIT_UI_COVERAGE.json']=(json.dumps(report,ensure_ascii=False,indent=2)+'\n').encode();modes['RENKIT_UI_COVERAGE.json']=0o644
    files['RENKIT_TRANSLATION.json']=(json.dumps({'translator':'RenAmamiya','upstream':REPO,'upstream_version':release['version'],'upstream_sha256':release['sha256'],'translation_revision':REVISION,'existing_wording_preserved':True},ensure_ascii=False,indent=2)+'\n').encode();modes['RENKIT_TRANSLATION.json']=0o644
    for name,data in raw.items():
        relative=name[len(prefix):]
        if relative!='dist/index.js' and files[relative]!=data:raise ValueError('ThemeHub backend/resources changed')
    package=work/'plugin.zip'
    with zipfile.ZipFile(package,'w') as z:
        for name in sorted(files):
            item=zipfile.ZipInfo(prefix+name,date_time=(2020,1,1,0,0,0));item.external_attr=(0o100000|modes[name])<<16
            z.writestr(item,files[name],compress_type=zipfile.ZIP_DEFLATED,compresslevel=6)
    e={'upstream_version':release['version'],'upstream_sha256':release['sha256'],'package_sha256':digest(package),'frontend_sha256':hashlib.sha256(localized).hexdigest(),'mirror_id':'themehub-zh-auto','archive_root':'DeckHomeThemes','plugin_name':'ThemeHub','attribution':'RenAmamiya','translation_revision':REVISION,'extra_translations':extras,'files':{name:hashlib.sha256(data).hexdigest() for name,data in files.items()},'modes':modes}
    entry({'schema':1,'package':e});return {'schema':1,'package':e},package

def write_mirror(root,catalog,package):
    e=entry(catalog);ident=e['mirror_id'];folder='v'+e['upstream_version']+'-'+e['package_sha256'][:16]
    filename=ident+'-'+folder+'.zip';target=Path(root)/ident/folder;target.mkdir(parents=True,exist_ok=True)
    chunk_size=1048576;count=0
    with Path(package).open('rb') as source:
        while block:=source.read(chunk_size):count+=1;(target/f'part.{count:04d}').write_bytes(block)
    fields={'id':ident,'name':'ThemeHub','version':folder,'file':filename,'source_url':'https://github.com/'+REPO+'/releases','sha256':e['package_sha256'],'size':Path(package).stat().st_size,'chunks':count,'chunk_size':chunk_size}
    (target.parent/'latest.txt').write_text(''.join(f'{key}={value}\n' for key,value in fields.items()));return folder,count

def publish(prepared):
    prepared=Path(prepared);catalog=json.loads((prepared/'catalog.json').read_text());e=entry(catalog);package=prepared/'plugin.zip'
    with tempfile.TemporaryDirectory(prefix='renkit-themehub-publish-') as temp:
        work=Path(temp);extract(package,work/'verified',e)
        report=json.loads((work/'verified/RENKIT_UI_COVERAGE.json').read_text())
        if report.get('untranslated')!=[] or report.get('non_ui_ast_verified') is not True or report.get('existing_translations_unchanged') is not True or report.get('api_plugin_names')!=['ThemeHub'] or report.get('translation_revision')!=e['translation_revision'] or any(not re.search('[\u3400-\u9fff]',row['translation']) for row in report['new_ui_strings']):raise ValueError('ThemeHub translation verification incomplete')
        env=os.environ.copy();token=env.get('GITEE_TOKEN')
        if token:
            askpass=work/'askpass.sh';askpass.write_text('#!/bin/sh\ncase "$1" in *Username*) printf "%s\\n" zliu9732-hub ;; *) printf "%s\\n" "$GITEE_TOKEN" ;; esac\n');askpass.chmod(0o700);env.update(GIT_ASKPASS=str(askpass),GIT_TERMINAL_PROMPT='0')
        def git(*args):return subprocess.run(['git',*map(str,args)],env=env,check=True,timeout=600)
        clone=work/'mirror';url='https://gitee.com/zliu9732-hub/'+MIRROR+'.git' if token else 'git@gitee.com:zliu9732-hub/'+MIRROR+'.git'
        git('clone','--depth','1','--filter=blob:none','--no-checkout',url,clone)
        git('-C',clone,'sparse-checkout','set','--no-cone','themehub-auto/**','themehub-zh-auto/**');git('-C',clone,'checkout','main')
        git('-C',clone,'config','user.name','Renkit localization bot');git('-C',clone,'config','user.email','renkit-bot@users.noreply.github.com')
        folder,count=write_mirror(clone,catalog,package);git('-C',clone,'add','themehub-zh-auto')
        if subprocess.run(['git','-C',str(clone),'diff','--cached','--quiet']).returncode:
            git('-C',clone,'commit','-m','Sync ThemeHub Chinese '+e['upstream_version']);git('-C',clone,'push','origin','HEAD:main')
        base='https://gitee.com/zliu9732-hub/'+MIRROR+'/raw/main/themehub-zh-auto/'+folder+'/'
        downloaded=work/'public.zip'
        with downloaded.open('wb') as target:
            for i in range(1,count+1):
                part=work/'part';fetch(base+f'part.{i:04d}',part,1048576);target.write(part.read_bytes())
        extract(downloaded,work/'public-verified',e)
        target=clone/'themehub-auto/catalog.json';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
        git('-C',clone,'add','themehub-auto/catalog.json')
        if subprocess.run(['git','-C',str(clone),'diff','--cached','--quiet']).returncode:
            git('-C',clone,'commit','-m','Publish verified ThemeHub Chinese catalog');git('-C',clone,'push','origin','HEAD:main')
        for attempt in range(12):
            if fetch(CATALOG_URL,limit=2097152)==catalog:print('ThemeHub public package and catalog verified');return
            time.sleep(10)
        raise ValueError('ThemeHub public catalog cache did not refresh')

def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['due','plan','build','publish']);p.add_argument('--work',type=Path);p.add_argument('--machine',action='store_true');a=p.parse_args()
    if a.mode=='due':print('true' if due() else 'false');return
    if a.mode=='publish':publish(a.work);return
    a.work.mkdir(parents=True,exist_ok=True)
    if a.mode=='plan':
        try:catalog=fetch(CATALOG_URL,limit=2097152)
        except (OSError,ValueError):catalog=json.loads((ROOT/'data/themehub_auto_baseline.json').read_text())
        release=latest();needed=plan(catalog,release)
        (a.work/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n');(a.work/'release.json').write_text(json.dumps(release,indent=2)+'\n')
        print('updates=true' if needed else 'updates=false');return
    release=json.loads((a.work/'release.json').read_text());catalog=json.loads((a.work/'catalog.json').read_text())
    archive=a.work/'official.zip';fetch(release['url'],archive)
    catalog,_=build(release,archive,a.work,catalog,a.machine);(a.work/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,TypeError,SyntaxError,subprocess.SubprocessError,zipfile.BadZipFile) as error:raise SystemExit('ThemeHub sync stopped; published Chinese package preserved: '+str(error))
