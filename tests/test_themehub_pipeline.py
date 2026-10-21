#!/usr/bin/env python3
"""Local ZIPs/static parsing only. All release queries and Git publication are mocked."""
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import sync_themehub_zh as sync
import themehub_package as pkg
from framegen_package import zip_files

class ThemeHubPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.archive=self.root/'official.zip'
        self.source='''const manifest = {name:"ThemeHub"};
const api=window.loader.connect(2,manifest.name);
async function installFirmware(release, current) { return release; }
const install = async (release) => { return release; };
const view={titleView:SP_JSX.jsx("div",{children:"ThemeHub"}),
children: [SP_JSX.jsx(Panel, {}), SP_JSX.jsx(Diagnostics, {})]};
SP_JSX.jsx("div",{label:"Settings",children:"Home"});'''
        self.make_zip()
    def tearDown(self):self.temp.cleanup()
    def make_zip(self,extra=''):
        files={'plugin.json':json.dumps({'name':'ThemeHub','author':'Kaal31'}).encode(),'package.json':b'{"version":"1.10.9"}',
            'dist/index.js':(self.source+extra).encode(),'main.py':b'# backend must never execute\n','LICENSE':b'Original license','themes/custom.bin':b'resource','py_modules/unchanged.py':b'# unchanged\n'}
        with zipfile.ZipFile(self.archive,'w') as z:
            for n,b in files.items():
                item=zipfile.ZipInfo('DeckHomeThemes/'+n);item.external_attr=0o100644<<16;z.writestr(item,b)
        self.release={'version':'1.10.9','sha256':pkg.digest(self.archive),'url':'https://github.com/Kaal31/benderthemes/releases/download/v1.10.9/DeckHomeThemes-v1.10.9.zip'}
    def build(self,**kw):return sync.build(self.release,self.archive,self.root/'prepared',**kw)
    def test_48_hour_interval_across_months(self):
        start=datetime.datetime(2026,1,28,tzinfo=datetime.timezone.utc).timestamp()
        times=[start+i*86400 for i in range(70) if sync.due(start+i*86400)]
        self.assertTrue(all(b-a==172800 for a,b in zip(times,times[1:])))
    def test_release_identity_hash_ambiguity_and_prereleases(self):
        d={'tag_name':'v1.10.9','draft':False,'prerelease':False,'assets':[{'name':'DeckHomeThemes-v1.10.9.zip','digest':'sha256:'+self.release['sha256'],'browser_download_url':self.release['url']}]}
        self.assertEqual(sync.latest_json(d),self.release)
        for mutation in ['pre','draft','duplicate','hash','url']:
            bad=copy.deepcopy(d)
            if mutation=='pre':bad['prerelease']=True
            elif mutation=='draft':bad['draft']=True
            elif mutation=='duplicate':bad['assets']*=2
            elif mutation=='hash':bad['assets'][0]['digest']='bad'
            else:bad['assets'][0]['browser_download_url']='https://example.org/other.zip'
            with self.assertRaises(ValueError):sync.latest_json(bad)
    def test_official_asset_page_fallback(self):
        path='/Kaal31/benderthemes/releases/download/v1.10.9/DeckHomeThemes-v1.10.9.zip'
        html=f'<ul><li><a href="{path}">ZIP</a><clipboard-copy value="sha256:{self.release["sha256"]}"></clipboard-copy></li></ul>'
        with patch.object(sync,'fetch',side_effect=OSError('offline')),patch.object(sync,'html_page',side_effect=[('https://github.com/Kaal31/benderthemes/releases/tag/v1.10.9',''),('https://github.com/Kaal31/benderthemes/releases/expanded_assets/v1.10.9',html)]):
            self.assertEqual(sync.latest(),self.release)
    def test_new_version_and_revision_without_downgrading(self):
        c,p=self.build();self.assertFalse(sync.plan(c,self.release))
        newer=dict(self.release,version='1.11.0');self.assertTrue(sync.plan(c,newer))
        with self.assertRaises(ValueError):sync.plan(c,dict(self.release,version='1.10.7'))
        old=copy.deepcopy(c);old['package']['translation_revision']=sync.REVISION+1
        self.assertEqual(pkg.merge(c,old),old)
    def test_existing_wording_author_backend_assets_and_identity_are_preserved(self):
        c,p=self.build();e=pkg.entry(c);out=self.root/'installed';pkg.extract(p,out,e)
        original=zip_files(self.archive);localized=zip_files(p)
        for name,data in original.items():
            if name!='DeckHomeThemes/dist/index.js':self.assertEqual(localized[name],data)
        text=(out/'dist/index.js').read_text()
        self.assertIn('RenAmamiya汉化',text);self.assertIn('#d9a441',text)
        report=json.loads((out/'RENKIT_UI_COVERAGE.json').read_text());self.assertTrue(report['existing_translations_unchanged']);self.assertTrue(report['non_ui_ast_verified'])
        self.assertEqual(report['new_ui_strings'],[]);self.assertEqual(report['api_plugin_names'],['ThemeHub'])
        self.assertIn('SP_JSX',text)
        self.assertEqual(json.loads((out/'plugin.json').read_text()),{'name':'ThemeHub','author':'Kaal31'})
    def test_new_page_and_dynamic_text_must_be_translated(self):
        self.make_zip('\nSP_JSX.jsx("div",{label:"A new ThemeHub option",children:`New count: ${count} themes remaining`});')
        with self.assertRaisesRegex(ValueError,'needs translation'):self.build()
        replacements={'A new ThemeHub option':'新主题选项','New count: ':'新数量：',' themes remaining':' 个主题待处理'}
        with patch.object(sync,'translate_missing',return_value=replacements):c,p=self.build(machine=True)
        report=json.loads(zip_files(p)['DeckHomeThemes/RENKIT_UI_COVERAGE.json']);self.assertTrue(report['existing_translations_unchanged'])
        rows={row['source']:row['translation'] for row in report['new_ui_strings']}
        self.assertEqual(rows,replacements)
        self.assertIn('renkitThemeHubPatterns',zip_files(p)['DeckHomeThemes/dist/index.js'].decode())
        with patch.object(sync,'translate_missing',return_value={'A new ThemeHub option':'New option'}),self.assertRaises(ValueError):self.build(machine=True)
    def test_existing_translation_cannot_be_overwritten(self):
        c,p=self.build();c['package']['extra_translations']={'Settings':'错误措辞'}
        with self.assertRaisesRegex(ValueError,'wording was changed'):self.build(current=c)
    def test_new_dynamic_renderer_preserves_values_and_old_wording(self):
        # Execute only our small renderer, never an upstream plugin bundle.
        runtime=(ROOT/'assets/deckhomethemes/zh-runtime.js').read_text().replace('__RENKIT_THEMEHUB_TRANSLATIONS__',json.dumps({'strings':{'Settings':'原有设置','New count: ':'新数量：',' themes remaining':' 个主题待处理','Exact old text':'原有完整译文'},'children':{},'fragments':{}}))
        adapter=(ROOT/'assets/themehub/dynamic-messages.js').read_text().replace('__RENKIT_THEMEHUB_PATTERNS__',json.dumps([['New count: ',None,' themes remaining'],['Exact ',None,' text']]))
        checks='''const assert=require('node:assert/strict');
const SP_JSX={jsx:(t,p)=>p,jsxs:(t,p)=>p};
'''+runtime+'\n'+adapter+'''
assert.equal(renkitThemeHubText('Settings'),'原有设置');
assert.equal(renkitThemeHubText('Exact old text'),'原有完整译文');
assert.equal(renkitThemeHubText('New count: 42 themes remaining'),'新数量：42 个主题待处理');
assert.equal(renkitThemeHubText('New count: game/path [a]+$ themes remaining'),'新数量：game/path [a]+$ 个主题待处理');
assert.equal(renkitThemeHubText('unrelated original log'),'unrelated original log');
assert.equal(renkitThemeHubText(42),42);
'''
        subprocess.run([os.environ.get('RENKIT_NODE_BINARY','node'),'-e',checks],check=True,capture_output=True,text=True)
    def test_checksum_path_corruption_and_symlinks(self):
        c,p=self.build();e=pkg.entry(c)
        bad=copy.deepcopy(c);bad['package']['files']['../escape']='a'*64
        with self.assertRaises(ValueError):pkg.entry(bad)
        damaged=self.root/'bad.zip';damaged.write_bytes(p.read_bytes()+b'bad')
        with self.assertRaises(ValueError):pkg.extract(damaged,self.root/'bad',e)
        pkg.extract(p,self.root/'installed',e);(self.root/'installed/main.py').write_text('changed')
        with self.assertRaises(ValueError):pkg.check_tree(self.root/'installed',e)
        self.release['sha256']='0'*64
        with self.assertRaises(ValueError):self.build()
    def test_chunk_output(self):
        c,p=self.build();large=self.root/'large';large.write_bytes(b'x'*2500000)
        folder,count=sync.write_mirror(self.root/'mirror',c,large);self.assertEqual(count,3)
        parts=sorted((self.root/'mirror/themehub-zh-auto'/folder).glob('part.*'))
        self.assertEqual(b''.join(part.read_bytes() for part in parts),large.read_bytes())
        self.assertLessEqual(max(part.stat().st_size for part in parts),1048576)
    def test_public_package_verified_before_catalog_and_failure_keeps_catalog(self):
        c,p=self.build();work=p.parent;(work/'catalog.json').write_text(json.dumps(c));events=[]
        def run(args,**kw):
            if len(args)>1 and args[1]=='clone':Path(args[-1]).mkdir()
            if 'commit' in args:events.append(args[-1])
            return subprocess.CompletedProcess(args,1 if 'diff' in args else 0)
        def fetch(url,target=None,limit=0):
            if target:events.append('verified-package');Path(target).write_bytes(p.read_bytes())
            else:return c
        with patch.object(sync.subprocess,'run',side_effect=run),patch.object(sync,'fetch',side_effect=fetch):sync.publish(work)
        self.assertLess(events.index('verified-package'),events.index('Publish verified ThemeHub Chinese catalog'))
        events.clear()
        with patch.object(sync.subprocess,'run',side_effect=run),patch.object(sync,'fetch',side_effect=OSError('offline')),self.assertRaises(OSError):sync.publish(work)
        self.assertNotIn('Publish verified ThemeHub Chinese catalog',events)

if __name__=='__main__':unittest.main()
