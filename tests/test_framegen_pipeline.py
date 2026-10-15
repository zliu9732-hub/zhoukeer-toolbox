#!/usr/bin/env python3
"""Pure temporary-file/static-parser tests; all network and publishing are mocked."""
import copy
import datetime
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import framegen_package as pkg
import sync_framegen_zh as sync

class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.root=Path(self.tmp.name)
        self.archive=self.root/'upstream.zip'
        self.source='''const MESSAGES={label:"Settings"}; const backend={action:"Install",path:"/keep/game",value:"Settings"};
        export default {titleView:window.SP_REACT.createElement("div",null,"Plugin"),
        content:window.SP_REACT.createElement("div",{label:MESSAGES.label},"Install","Cancel")};'''
        self.make_archive()
    def tearDown(self): self.tmp.cleanup()
    def make_archive(self, source=None):
        files={'plugin.json':json.dumps({'name':'Decky LSFG-VK','author':'Original Author'}).encode(),
               'package.json':json.dumps({'version':'0.14.5','remote_binary':[{'name':'runtime.xz','sha256hash':hashlib.sha256(b'runtime').hexdigest()}]}).encode(),
               'dist/index.js':(source or self.source).encode(),'main.py':b'raise Exception("must never execute backend")',
               'LICENSE':b'Original BSD license','bin/runtime.xz':b'runtime','defaults/keep.sh':b'#!/bin/sh\nexit 0\n'}
        with zipfile.ZipFile(self.archive,'w') as z:
            for n,b in files.items():
                zi=zipfile.ZipInfo('Decky LSFG-VK/'+n);zi.external_attr=(0o100755 if n.endswith('.sh') else 0o100644)<<16
                z.writestr(zi,b)
        self.release={'version':'0.14.5','sha256':pkg.digest(self.archive),'url':'https://github.com/xXJSONDeruloXx/decky-lsfg-vk/releases/download/v0.14.5/Decky.LSFG-VK.zip'}
    def build(self, machine=False): return sync.build('lsfg-v2',self.release,self.archive,self.root/'build',machine)
    def test_interval_across_months(self):
        start=datetime.datetime(2026,1,28,1,17,tzinfo=datetime.timezone.utc).timestamp()
        times=[start+86400*i for i in range(70) if sync.due(start+86400*i)]
        self.assertTrue(all(b-a==172800 for a,b in zip(times,times[1:])))
    def test_release_checks(self):
        data={'tag_name':'v0.14.5','draft':False,'prerelease':False,'assets':[{'name':'Decky.LSFG-VK.zip','digest':'sha256:'+self.release['sha256'],'browser_download_url':self.release['url']}]}
        with patch.object(sync,'fetch',return_value=data): self.assertEqual(sync.latest('lsfg-v2'),self.release)
        for key,value in [('prerelease',True),('draft',True)]:
            bad=copy.deepcopy(data);bad[key]=value
            with patch.object(sync,'fetch',return_value=bad), self.assertRaises(ValueError):sync.latest('lsfg-v2')
        for mutation in ['hash','duplicate','url']:
            bad=copy.deepcopy(data)
            if mutation=='hash':bad['assets'][0]['digest']=None
            elif mutation=='duplicate':bad['assets']*=2
            else:bad['assets'][0]['browser_download_url']='https://evil.example/payload.zip'
            with patch.object(sync,'fetch',return_value=bad), self.assertRaises((ValueError,TypeError)):sync.latest('lsfg-v2')
    def test_no_change_and_new_version(self):
        c=json.loads((ROOT/'data/framegen_auto_baseline.json').read_text())
        releases={k:{'version':v['upstream_version'],'sha256':v['upstream_sha256']} for k,v in c['packages'].items()}
        self.assertEqual(sync.make_plan(c,releases),{})
        releases['lsfg-v2']=self.release
        self.assertEqual(set(sync.make_plan(c,releases)),{'lsfg-v2'})
        releases['lsfg-v2']['version']='0.12.8'
        with self.assertRaises(ValueError):sync.make_plan(c,releases)
    def test_cached_catalog_cannot_downgrade(self):
        c=json.loads((ROOT/'data/framegen_auto_baseline.json').read_text());new=copy.deepcopy(c)
        new['packages']['lsfg-v2']['upstream_version']='0.15.0'
        merged=pkg.merge_catalog(c,new)
        self.assertEqual(merged['packages']['lsfg-v2']['upstream_version'],'0.15.0')
    def test_build_keeps_non_ui_bytes_and_permissions(self):
        e,p=self.build(); first=p.read_bytes()
        out=self.root/'extracted';pkg.extract_verified(p,out,e)
        self.assertEqual((out/'main.py').read_bytes(),b'raise Exception("must never execute backend")')
        self.assertEqual((out/'bin/runtime.xz').read_bytes(),b'runtime')
        self.assertEqual((out/'LICENSE').read_bytes(),b'Original BSD license')
        self.assertTrue((out/'defaults/keep.sh').stat().st_mode & 0o111)
        js=(out/'dist/index.js').read_text()
        self.assertIn('const backend={action:"Install",path:"/keep/game",value:"Settings"}',js)
        self.assertIn('RenAmamiya汉化',js)
        self.assertEqual(json.loads((out/'plugin.json').read_text())['author'],'Original Author')
        self.assertEqual(self.build()[1].read_bytes(),first)
    def test_style_and_script_bodies_are_not_translated(self):
        self.make_archive(self.source+'\nwindow.SP_REACT.createElement("script",null,"Install");\nwindow.SP_REACT.createElement("style",null,"Settings");')
        e,p=self.build();js=pkg.zip_files(p)[e['archive_root']+'/dist/index.js'].decode()
        self.assertIn('createElement("script",null,"Install")',js)
        self.assertIn('createElement("style",null,"Settings")',js)
    def test_multiple_chunk_output(self):
        e,p=self.build();large=self.root/'large.zip';large.write_bytes(b'x'*9000000)
        e['package_sha256']=pkg.digest(large)
        folder,filename,count=sync.write_mirror(self.root/'mirror','lsfg-v2',e,large)
        parts=sorted((self.root/'mirror'/e['mirror_id']/folder).glob('part.*'))
        self.assertEqual(count,2);self.assertEqual(b''.join(p.read_bytes() for p in parts),large.read_bytes())
    def test_unknown_strings_block_or_use_translation(self):
        self.make_archive(self.source.replace('"Install","Cancel"','"Install","Cancel","A completely new instruction"'))
        with self.assertRaises(ValueError):self.build()
        with patch.object(sync,'translate_missing',return_value={'A completely new instruction':'全新的使用说明'}) as translate:
            e,p=self.build(True)
            self.assertEqual(translate.call_count,1)
            self.assertIn('全新的使用说明',pkg.zip_files(p)[e['archive_root']+'/dist/index.js'].decode())
    def test_complete_official_chinese_is_preserved(self):
        table={f'TEXT_{i}':'Chinese item '+str(i) for i in range(22)}
        zh={k:'中文项目'+str(i) for i,k in enumerate(table)}
        self.make_archive('const template='+json.dumps(table)+'; const zh='+json.dumps(zh,ensure_ascii=False)+';'+self.source)
        e,p=self.build();self.assertEqual(e['attribution'],'upstream')
        self.assertEqual(p.read_bytes(),self.archive.read_bytes())
        self.assertNotIn('RenAmamiya',pkg.zip_files(p)[e['archive_root']+'/dist/index.js'].decode())
    def test_archive_safety_and_corruption(self):
        e,p=self.build()
        for name,mode in [('../escape',0o100644),('link',0o120777)]:
            bad=self.root/'bad.zip'
            with zipfile.ZipFile(bad,'w') as z:
                zi=zipfile.ZipInfo(name);zi.external_attr=mode<<16;z.writestr(zi,'x')
            with self.assertRaises(ValueError):pkg.zip_files(bad)
        p.write_bytes(p.read_bytes()+b'corrupt')
        with self.assertRaises(ValueError):pkg.extract_verified(p,self.root/'bad-output',e)
        self.assertFalse((self.root/'bad-output').exists())
        self.release['sha256']='0'*64
        with self.assertRaises(ValueError):self.build()
    def test_catalog_and_installed_file_checks(self):
        e,p=self.build();c={'schema':1,'packages':{'lsfg-v2':e}}
        pkg.entry(c,'lsfg-v2');pkg.extract_verified(p,self.root/'installed',e)
        (self.root/'installed/main.py').write_text('changed')
        with self.assertRaises(ValueError):pkg.check_tree(self.root/'installed',e)
        for key,value in [('mirror_id','evil'),('archive_root','../outside'),('plugin_name','Other plugin'),('upstream_version','$(touch PWN)'),('package_sha256','bad')]:
            bad=copy.deepcopy(c);bad['packages']['lsfg-v2'][key]=value
            with self.assertRaises(ValueError):pkg.entry(bad,'lsfg-v2')
    def test_publish_orders_package_verification_before_catalog(self):
        e,p=self.build();work=self.root/'prepared';(work/'lsfg-v2').mkdir(parents=True)
        (work/'lsfg-v2/plugin.zip').write_bytes(p.read_bytes())
        c=json.loads((ROOT/'data/framegen_auto_baseline.json').read_text());c['packages']['lsfg-v2']=e
        (work/'catalog.json').write_text(json.dumps(c));(work/'updates.json').write_text(json.dumps({'lsfg-v2':self.release}))
        events=[]
        def run(args,**kwargs):
            if args[1]=='clone':Path(args[-1]).mkdir()
            if 'commit' in args:events.append(args[-1])
            return subprocess.CompletedProcess(args,1 if 'diff' in args else 0)
        def fetch(url,target=None,limit=0):
            if target:
                events.append('verified-package');Path(target).write_bytes(p.read_bytes())
            else:return c
        with patch.object(sync.subprocess,'run',side_effect=run),patch.object(sync,'fetch',side_effect=fetch),patch.dict(os.environ,{'GITEE_TOKEN':'test-only-placeholder'}):
            sync.publish(work)
        self.assertLess(events.index('verified-package'),events.index('Publish verified framegen Chinese catalog'))
    def test_owned_ui_runtime_only(self):
        runtime=(ROOT/'assets/framegen/zh-runtime.js').read_text()
        script='''globalThis.window={SP_REACT:{createElement:(type,props,...children)=>({type,props,children})}};
const r='''+runtime+'''({"Settings":"设置","No ":"没有"});
if(r.text("Settings",["Settings"])!=="设置")throw Error("translation");
if(r.text("Player game",["Settings"])!=="Player game")throw Error("game title changed");
if(r.text("No games",["No "])!=="没有games")throw Error("prefix");
if(JSON.stringify(r.title("Title")).indexOf("RenAmamiya汉化")<0)throw Error("signature");'''
        subprocess.run([os.environ.get('RENKIT_NODE_BINARY','node'),'--input-type=module'],input=script,text=True,check=True)

if __name__=='__main__':unittest.main()
