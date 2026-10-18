#!/usr/bin/env python3
"""Local fixtures only; plugin Python and system/hardware commands are never executed."""
import copy
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

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts'))
import localize_ayaneo3 as loc


class Ayaneo3Tests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        self.source = ('const manifest = {"name":"AYANEO 3 Companion"};\n'
            'const api=window.loader.connect(2,manifest.name);\n'
            'const change=api.callable("set_controller");\n'
            'const toaster=api.toaster; const index=()=>({' + loc.TITLE + ',\n'
            'content:SP_JSX.jsx("button",{label:"Vibration",value:"high",onClick:()=>change({vibration:"high"}),children:"Test Vibration"})});\n'
            'export { index as default };')
        self.files = {'plugin.json':json.dumps({'name':'AYANEO 3 Companion','flags':['root'],'api_version':1}).encode(),
            'package.json':b'{"version":"1.2.0","type":"module"}', 'main.py':b'raise RuntimeError("must never execute")\n',
            'quality_runtime.py':b'# unchanged backend helper\n','LICENSE':b'Original BSD-3-Clause',
            'NOTICE':b'Original third-party notices','dist/index.js':self.source.encode(),'bootstrap.sh':b'#!/bin/sh\nexit 1\n'}
        self.archive=self.root/'plugin.zip'
        self.write_zip()
        self.meta={'archive_root':'Ayaneo3Companion','package_sha256':self.sha(self.archive.read_bytes()),
            'upstream_version':'1.2.0','plugin_name':'AYANEO 3 Companion','frontend_zh_sha256':'',
            'files':{n:self.sha(b) for n,b in self.files.items()},
            'modes':{n:0o755 if n.endswith('.sh') else 0o644 for n in self.files}}
        def metadata(translated=False):
            e=copy.deepcopy(self.meta)
            if translated:e['files']['dist/index.js']=e['frontend_zh_sha256']
            return e
        self.patcher=patch.object(loc,'metadata',side_effect=metadata);self.patcher.start()
        self.meta['frontend_zh_sha256']=self.sha(loc.build_frontend(self.files['dist/index.js']))
    def tearDown(self): self.patcher.stop();self.temp.cleanup()
    @staticmethod
    def sha(data):return hashlib.sha256(data).hexdigest()
    def write_zip(self):
        with zipfile.ZipFile(self.archive,'w') as z:
            for n,b in self.files.items():
                info=zipfile.ZipInfo('Ayaneo3Companion/'+n);info.external_attr=(0o100755 if n.endswith('.sh') else 0o100644)<<16
                z.writestr(info,b)
    def test_prepare_retains_all_backend_identity_and_permissions(self):
        out=self.root/'installed';loc.prepare(self.archive,out);loc.verify(out)
        for n,b in self.files.items():
            if n!='dist/index.js':self.assertEqual((out/n).read_bytes(),b,n)
        self.assertTrue((out/'bootstrap.sh').stat().st_mode & 0o111)
        self.assertEqual(json.loads((out/'plugin.json').read_text())['name'],'AYANEO 3 Companion')
        self.assertIn('RenAmamiya汉化',(out/'dist/index.js').read_text())
    def test_same_version_incomplete_install_is_rejected(self):
        out=self.root/'installed';loc.prepare(self.archive,out)
        (out/'quality_runtime.py').write_text('changed')
        with self.assertRaises(ValueError):loc.verify(out)
    def test_corrupt_archive_and_existing_tree_are_preserved(self):
        self.archive.write_bytes(self.archive.read_bytes()+b'corrupt')
        out=self.root/'installed'
        with self.assertRaises(ValueError):loc.prepare(self.archive,out)
        self.assertFalse(out.exists())
        out.mkdir();(out/'keep').write_text('previous')
        with self.assertRaises(ValueError):loc.prepare(self.archive,out)
        self.assertEqual((out/'keep').read_text(),'previous')
    def test_missing_backend_is_rejected_before_extraction(self):
        del self.files['quality_runtime.py'];self.write_zip()
        self.meta['package_sha256']=self.sha(self.archive.read_bytes())
        with self.assertRaises(ValueError):loc.prepare(self.archive,self.root/'incomplete')
        self.assertFalse((self.root/'incomplete').exists())
    def test_symlink_output_is_rejected(self):
        real=self.root/'real';real.mkdir();out=self.root/'link';out.symlink_to(real,target_is_directory=True)
        with self.assertRaises(ValueError):loc.prepare(self.archive,out)
        self.assertFalse(list(real.iterdir()))
    def test_only_render_calls_change_in_complete_ast(self):
        before=self.root/'original.js';before.write_text(self.source)
        after=self.root/'translated.js';after.write_bytes(loc.build_frontend(self.source.encode()))
        command=[os.environ.get('RENKIT_NODE_BINARY','node'),str(ROOT/'scripts/verify_ayaneo3_ui.mjs'),str(before),str(after)]
        subprocess.run(command,check=True,capture_output=True)
        after.write_text(after.read_text().replace('vibration:"high"','vibration:"off"'))
        self.assertNotEqual(subprocess.run(command,capture_output=True).returncode,0)
    def test_render_runtime_keeps_values_callbacks_and_original_props(self):
        dictionary=json.loads((ROOT/'data/ayaneo3_zh.json').read_text())
        runtime=(ROOT/'assets/ayaneo3/zh-runtime.js').read_text().replace('__RENKIT_AYANEO3_TRANSLATIONS__',json.dumps(dictionary,ensure_ascii=False))
        test='''const assert=require('node:assert/strict');
const SP_JSX={jsx:(type,props,...rest)=>({type,props,rest}),jsxs:(type,props,...rest)=>({type,props,rest})};
let toast;const toaster={toast:(value)=>{toast=value;}};
'''+runtime+'''
const click=()=>{};const data={vibration:'high'};const style={color:'red'};
const props={label:'Vibration',value:'high',selectedOption:'high',data,onClick:click,style,
rgOptions:[{label:'High',data:'high'}],children:['Test Vibration',null,15]};
const r=RenkitAyaneo3JSX.jsx('button',props).props;
assert.equal(r.label,'震动');assert.equal(r.children[0],'测试震动');
assert.equal(r.value,'high');assert.equal(r.data,data);assert.equal(r.onClick,click);assert.equal(r.style,style);
assert.equal(r.selectedOption,'high');assert.equal(r.rgOptions[0].data,'high');assert.equal(r.rgOptions[0].label,'强');
assert.equal(props.label,'Vibration');assert.equal(props.rgOptions[0].label,'High');
assert.equal(RenkitAyaneo3JSX.jsx('style',props).props,props);
assert.equal(renkitAyaneo3Text('Apply & Save for My Game'),'应用并保存到 My Game');
assert.equal(renkitAyaneo3Text('Apply & Save for High'),'应用并保存到 High');
assert.equal(renkitAyaneo3Text('Balanced · 15 / 17 / 20 W'),'均衡 · 15 / 17 / 20 W');
assert.equal(renkitAyaneo3Text('Rainbow · #FF00AA'),'彩虹 · #FF00AA');
RenkitAyaneo3JSX.toast({title:'Action failed',body:'Unknown error'});
assert.equal(toast.title,'操作失败');assert.equal(toast.body,'发生未知错误');
const title=JSON.stringify(RenkitAyaneo3JSX.title('AYANEO3'));
assert.equal(title.split('RenAmamiya汉化').length-1,1);assert.ok(title.includes('#ffcc66'));
'''
        subprocess.run([os.environ.get('RENKIT_NODE_BINARY','node')],input=test,text=True,check=True)


if __name__=='__main__':unittest.main()
