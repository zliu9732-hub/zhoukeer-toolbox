"""No real system commands: verified payload, mocked platform and temp rollback."""
import ast
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace

sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'third_party/rc74xa-offline-20261024'
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
m=load('rc74xa_installer',SOURCE/'installer.py')
m.verify()
for p in SOURCE.rglob('*.py'):ast.parse(p.read_text())
manifest=json.loads((SOURCE/'manifest.json').read_text())
assert hashlib.sha256((SOURCE/'manifest.json').read_bytes()).hexdigest() in (ROOT/'scripts/verify_rog_x20_package.py').read_text()
audio=(SOURCE/'payload/x20-fixes/fix/ally-audio-fix.sh').read_text()
assert 'sh -c' not in audio and 'curl ' not in audio and 'cmd_build()' not in audio
valid=dict(system='Linux',arch='x86_64',vendor='ASUSTeK COMPUTER INC.',device='ROG Xbox Ally RC74XA',
    bios='RC74XA.303',kernel=m.compat.KERNEL,release={'ID':'steamos','VERSION_ID':'3.9.3'},
    acp=[('0x1043','0x1954')],speaker=0)
assert not m.compat.problems(valid)
for bios in ['RC74XA.301','RC74XA.303']:
    assert not m.compat.problems({**valid,'bios':bios})
for key,value in [('system','Darwin'),('arch','aarch64'),('device','RC73XA'),('vendor','Valve'),
                  ('bios','RC74XA.999'),('kernel','7.2.9'),('acp',[('0x1043','0x1111')])]:
    assert m.compat.problems({**valid,key:value}),key
for release in [{'ID':'bazzite','VERSION_ID':'3.9.3'},{'ID':'arch','VERSION_ID':'3.9.3'},{}]:
    assert m.compat.problems({**valid,'release':release})
for version in ['3.9.4','3.9.5','3.10.0','4.0','',None]:
    release={'ID':'steamos','BUILD_ID':'new-system-build'}
    if version is not None: release['VERSION_ID']=version
    assert not m.compat.problems({**valid,'release':release}),version
    # Updating the system must never permit the old binary on a different kernel.
    errors=m.compat.problems({**valid,'release':release,'kernel':'7.2.8-new-valve-kernel'})
    assert any('7.2.8-new-valve-kernel' in error and m.compat.KERNEL in error for error in errors)
assert not m.compat.problems({**valid,'kernel':'changed'},install=False)

with tempfile.TemporaryDirectory() as directory:
    base=Path(directory)
    # Tampering, unexpected files and symlinks must fail before deployment.
    test_source=base/'payload-copy';shutil.copytree(SOURCE,test_source)
    m.BASE=test_source
    extra=test_source/'unexpected.py';extra.write_text('raise RuntimeError()')
    try:m.verify();raise AssertionError('unexpected file accepted')
    except RuntimeError:pass
    extra.unlink()
    target=test_source/'check.sh';original=target.read_bytes();target.write_bytes(b'bad')
    try:m.verify();raise AssertionError('tampered file accepted')
    except RuntimeError:pass
    target.unlink();target.symlink_to(SOURCE/'check.sh')
    try:m.verify();raise AssertionError('symlink accepted')
    except RuntimeError:pass
    target.unlink();target.write_bytes(original)
    m.verify();m.BASE=SOURCE

    for failure in ['success','audio','start','updated-grub','linked-parent','unknown-speaker','new-kernel']:
        root=base/failure;root.mkdir()
        def mapped(path):
            text=str(path)
            if text.startswith(('/efi/','/var/lib/','/etc/','/run/','/usr/share/')):
                return root/text.lstrip('/')
            return Path(path)
        m.Path=mapped;m.STATE=root/'var/lib/rc74xa-offline'
        m.os=SimpleNamespace(geteuid=lambda:0,chown=lambda *args:None,readlink=os.readlink,environ={})
        state=copy.deepcopy(valid);state['speaker']=None if failure=='unknown-speaker' else 0
        state['release']={'ID':'steamos','VERSION_ID':'3.9.4','BUILD_ID':'morning-update'}
        if failure=='new-kernel': state['kernel']='7.2.8-new-valve-kernel'
        m.compat.read_state=lambda:state
        m.need_commands=lambda:None
        home=root/'home/customer';(home/'homebrew/services').mkdir(parents=True)
        (home/'homebrew/services/PluginLoader').write_text('fixture loader')
        service=mapped('/etc/systemd/system/plugin_loader.service');service.parent.mkdir(parents=True)
        service.write_text(str(home/'homebrew/services/PluginLoader'))
        grub=mapped('/efi/EFI/steamos/grub.cfg');grub.parent.mkdir(parents=True);grub.write_text('original grub')
        mapped('/usr/share/alsa/ucm2/sof-soundwire').mkdir(parents=True)
        (home/'.steam/steam').mkdir(parents=True)
        m.user=lambda:(SimpleNamespace(pw_uid=os.getuid(),pw_gid=os.getgid(),pw_name='customer'),home)
        if failure=='linked-parent':
            outside=root/'outside';outside.mkdir();(home/'homebrew/plugins').symlink_to(outside)
        commands=[]
        def fake_run(args,**kwargs):
            args=list(map(str,args));commands.append(args)
            if args[0]=='modinfo':return SimpleNamespace(stdout=m.compat.KERNEL+' SMP',returncode=0)
            if args[:2]==['sh',str(SOURCE/'payload/x20-fixes/fix/ally-audio-fix.sh')]:
                if args[-1]=='install':
                    grub.write_text('patched grub')
                    lib=mapped('/var/lib/ally-audio-fix');lib.mkdir(parents=True,exist_ok=True)
                    (lib/'fixture').write_text('audio')
                    if failure=='audio':raise subprocess.CalledProcessError(1,args)
            if args[:2]==['systemctl','start'] and failure=='start':raise subprocess.CalledProcessError(1,args)
            return SimpleNamespace(stdout='',returncode=1 if args[:2] in (['systemctl','is-active'],['systemctl','is-enabled']) else 0)
        m.subprocess=SimpleNamespace(run=fake_run)
        if failure in ['audio','start','linked-parent','unknown-speaker','new-kernel']:
            try:m.install(False);raise AssertionError('failure accepted: '+failure)
            except (RuntimeError,subprocess.CalledProcessError):pass
            assert grub.read_text()=='original grub',failure
            assert not m.STATE.exists(),failure
            assert not (home/'homebrew/plugins/x20-fixes').exists(),failure
            if failure=='new-kernel': assert not commands,commands
        else:
            m.install(False)
            plugin=home/'homebrew/plugins/x20-fixes'
            assert (m.STATE/'complete').exists() and (plugin/'main.py').is_file()
            assert (home/'homebrew/services/PluginLoader').read_text()=='fixture loader'
            assert grub.read_text()=='patched grub'
            state['kernel']='updated kernel'
            if failure=='updated-grub':
                grub.write_text('new system grub')
                try:m.uninstall();raise AssertionError('restored obsolete grub')
                except RuntimeError:pass
                assert grub.read_text()=='new system grub' and m.STATE.exists()
            else:
                m.uninstall()
                assert grub.read_text()=='original grub' and not plugin.exists() and not m.STATE.exists()
                assert (home/'homebrew/services/PluginLoader').exists()
        assert not any(a[0] in ('curl','wget','pacman','sudo') for a in commands)
print('PASS: actual payload integrity, exact hardware gates, mocked installation, rollback, linked paths and update-safe restore')
