#!/usr/bin/env python3
"""只测试本地字典、显示组件和文件校验，不下载或执行上游插件。"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("dht_zh", ROOT / "scripts/localize_deckhomethemes.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ThemeHubTests(unittest.TestCase):
    def test_resources_and_version(self):
        data = json.loads(module.DATA.read_text())
        files = json.loads(module.FILES.read_text())
        self.assertEqual(data["version"], "1.10.7")
        self.assertEqual(len(files), 67)
        self.assertGreater(len(data["strings"]), 1500)
        self.assertEqual(files["dist/index.js"], data["upstream_sha256"])
        self.assertIn("third-party/Original-Deck-Home-Themes-BSD.txt", files)
        self.assertIn("py_modules/theme_updates.py", files)
        shell = (ROOT / "modules/plugin_store.sh").read_text()
        self.assertIn('DECKHOMETHEMES_ZH_SHA256="' + module.OUTPUT_SHA256 + '"', shell)
        for resource in ["scripts/localize_deckhomethemes.py", "data/deckhomethemes_zh.json",
                         "data/deckhomethemes_files.json", "assets/deckhomethemes/zh-runtime.js"]:
            self.assertIn(resource, (ROOT / "scripts/package_release.sh").read_text())
        self.assertIn("right:17-18:deckhomethemes", (ROOT / "main.sh").read_text())
        self.assertIn('deckhomethemes "主页主题', (ROOT / "core/gui.sh").read_text())

    def test_mismatched_frontend_fails_before_write(self):
        with self.assertRaisesRegex(ValueError, "版本不匹配"):
            module.build_frontend(b"untrusted frontend", json.loads(module.DATA.read_text()), module.RUNTIME.read_text())

    def test_missing_tampered_or_linked_files_rejected(self):
        original = module.FILES
        try:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp) / "plugin"; root.mkdir()
                payload = b"local fixture only"
                manifest = Path(tmp) / "files.json"
                manifest.write_text(json.dumps({"main.py": hashlib.sha256(payload).hexdigest()}))
                module.FILES = manifest
                with self.assertRaises(ValueError): module.verify_files(root)
                (root / "main.py").write_bytes(payload)
                module.verify_files(root)
                (root / "main.py").write_bytes(b"changed")
                with self.assertRaises(ValueError): module.verify_files(root)
                (root / "main.py").write_bytes(payload)
                (root / "link").symlink_to(manifest)
                with self.assertRaisesRegex(ValueError, "外部链接"): module.verify_files(root)
        finally:
            module.FILES = original

    def test_translation_does_not_change_data(self):
        node = os.environ.get("RENKIT_NODE_BINARY", "node")
        runtime = module.RUNTIME.read_text().replace("__RENKIT_THEMEHUB_TRANSLATIONS__", module.DATA.read_text())
        checks = r'''
const assert = require("node:assert/strict");
const SP_JSX = {jsx:(type,props,key)=>({type,props,key}),jsxs:(type,props,key)=>({type,props,key})};
__RUNTIME__
const original = {label:"Themed home screen",description:"Replace Steam's home with the console theme",
 rgOptions:[{data:"Wii U Menu Sounds",label:"Wii U Menu Sounds"},{label:"Themes",options:[{data:"home",label:"Home"}]}],
 value:"ThemeHub",id:"home",method:"get_settings",style:{fontFamily:"Arial",color:"Gold"},
 children:["Settings","Play",{type:"custom",props:{value:"home"}}]};
const output = RenkitThemeHubJSX.jsx("panel",original,"official-key");
assert.equal(output.key,"official-key");assert.equal(output.props.label,"主题主页");
assert.equal(output.props.rgOptions[0].data,"Wii U Menu Sounds");
assert.equal(output.props.rgOptions[0].label,"Wii U 菜单音效");
assert.equal(output.props.rgOptions[1].options[0].data,"home");
assert.equal(output.props.rgOptions[1].options[0].label,"主页");
assert.equal(output.props.value,"ThemeHub");assert.equal(output.props.id,"home");
assert.equal(output.props.method,"get_settings");assert.deepEqual(output.props.style,original.style);
assert.equal(original.label,"Themed home screen");assert.equal(original.rgOptions[0].label,"Wii U Menu Sounds");
assert.equal(output.props.children[0],"设置");assert.equal(output.props.children[1],"开始游戏");
assert.equal(renkitThemeHubText("Downloading Theme.zip"),"正在下载 Theme.zip");
assert.deepEqual(RenkitThemeHubJSX.jsx("style",{children:"Home"}).props,{children:"Home"});
console.log("PASS: 中文显示保留设置值、接口、资源名和样式");
'''.replace("__RUNTIME__", runtime)
        subprocess.run([node, "-e", checks], check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
