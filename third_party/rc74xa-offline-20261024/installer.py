#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Offline delivery wrapper; upstream fixes remain in payload/x20-fixes.
Changes only the target Linux installation when explicitly invoked with install/uninstall.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys

BASE=Path(__file__).resolve().parent
PAYLOAD=BASE/'payload'
spec=importlib.util.spec_from_file_location('compat',PAYLOAD/'x20-fixes/compat.py')
compat=importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)
STATE=Path('/var/lib/rc74xa-offline')
ENV={'PATH':'/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin','LANG':'C.UTF-8','HOME':'/root'}

def run(args, **kwargs):
    return subprocess.run([str(a) for a in args],check=True,env=ENV,**kwargs)
def fail(msg):
    raise RuntimeError(msg)
def verify():
    manifest=json.loads((BASE/'manifest.json').read_text())
    paths=list(BASE.rglob('*'))
    if any(p.is_symlink() for p in paths): fail('安装目录含链接，已停止。')
    names={str(p.relative_to(BASE)) for p in paths if p.is_file()}
    if names != set(manifest['sha256']) | {'manifest.json'}: fail('安装文件集合不匹配。')
    for name,want in manifest['sha256'].items():
        path=BASE/name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=want:
            fail('文件校验失败：'+name)
    print('离线文件 SHA-256 校验通过。')
def user():
    name=os.environ.get('SUDO_USER') or os.environ.get('USER','')
    if not name or name=='root': fail('请从掌机普通桌面用户执行 sudo bash install.sh install。')
    pw=pwd.getpwnam(name)
    home=Path(pw.pw_dir)
    if not str(home).startswith('/home/') or re.search(r'[^/A-Za-z0-9_.-]',str(home)):
        fail('不支持此用户主目录。')
    return pw,home
def need_commands():
    commands=('sh','lspci','awk','sed','grep','head','cut','od','tr','findmnt','lsblk','python3',
              'bsdcpio','find','cp','rm','mkdir','basename','grub-script-check','modinfo','sha256sum',
              'install','mktemp','ln','aplay','amixer','sort','readlink','ls','chmod','sync','cat',
              'systemctl','runuser','pactl','lsinitcpio','pacman','zstd','tail')
    missing=[c for c in commands if not shutil.which(c,path=ENV['PATH'])]
    if missing: fail('SteamOS 基础命令缺失，停止而不安装其他发行版软件包：'+', '.join(missing))
    if sys.version_info<(3,10): fail('要求 SteamOS 自带 Python 3.10 或更新版本。')
def snapshot(paths):
    if STATE.exists(): fail('已有本包安装记录，请先 status / uninstall，避免覆盖恢复备份。')
    (STATE/'backup').mkdir(parents=True)
    records=[]
    for i,p in enumerate(paths):
        item={'path':str(p),'exists':p.exists() or p.is_symlink(),'backup':str(i)}
        if item['exists']:
            dst=STATE/'backup'/str(i)
            if p.is_symlink(): dst.symlink_to(os.readlink(p))
            elif p.is_dir(): shutil.copytree(p,dst,symlinks=True)
            else: shutil.copy2(p,dst)
        records.append(item)
    return records
def restore(records):
    for item in reversed(records):
        p=Path(item['path']); b=STATE/'backup'/item['backup']
        if p.is_symlink() or p.is_file(): p.unlink()
        elif p.exists(): shutil.rmtree(p)
        if item['exists']:
            p.parent.mkdir(parents=True,exist_ok=True)
            if b.is_symlink(): p.symlink_to(os.readlink(b))
            elif b.is_dir(): shutil.copytree(b,p,symlinks=True)
            else: shutil.copy2(b,p)
def copy_owned_tree(src,dst,uid,gid):
    shutil.copytree(src,dst,dirs_exist_ok=True)
    for p in [dst,*dst.rglob('*')]:
        os.chown(p,uid,gid)
        if p.is_file(): p.chmod(0o755 if p.suffix=='.sh' else 0o644)
def install(audio_only):
    if os.geteuid()!=0: fail('安装需要 sudo；当前只做检测。请执行 sudo bash install.sh install。')
    state=compat.read_state()
    errors=compat.problems(state)
    if errors: fail('\n'.join(errors))
    if state['speaker'] not in (0,1): fail('无法读取 BIOS SPEAKER_ID 0/1；停止，不猜测扬声器调音。')
    verify(); need_commands()
    pw,home=user()
    fix=PAYLOAD/'x20-fixes/fix/ally-audio-fix.sh'
    module=PAYLOAD/'x20-fixes/fix/prebuilt'/compat.KERNEL/'snd-soc-acpi-amd-match.ko'
    vm=run(['modinfo','-F','vermagic',module],capture_output=True,text=True).stdout.split()[0]
    if vm!=compat.KERNEL: fail('模块 vermagic 不匹配。')
    if not Path('/efi/EFI/steamos/grub.cfg').is_file(): fail('未找到 SteamOS 当前槽的 GRUB 配置。')
    if not Path('/usr/share/alsa/ucm2/sof-soundwire').is_dir(): fail('缺少系统 SoundWire UCM 基础配置。')
    # No alternate firmware search path is overwritten.
    fwpath=Path('/sys/module/firmware_class/parameters/path')
    if fwpath.exists() and fwpath.read_text().strip() not in ('','/var/lib/ally-audio-fix/firmware'):
        fail('已有自定义 firmware_class.path，停止以免冲突。')
    hb=home/'homebrew'; plugin=hb/'plugins/x20-fixes'; service=Path('/etc/systemd/system/plugin_loader.service')
    for parent in (home,hb,hb/'plugins',hb/'services',hb/'settings',home/'.local',home/'.local/share',
                   home/'.local/share/ally-audio-fix',home/'.local/share/ally-audio-fix/cache',
                   home/'.local/share/ally-audio-fix/cache/firmware'):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()): fail('安装路径不是安全目录：'+str(parent))
    for path in (service,hb/'services/PluginLoader'):
        if path.is_symlink() or (path.exists() and not path.is_file()): fail('服务路径不是安全文件：'+str(path))
    fresh=not (hb/'services/PluginLoader').is_file()
    if not audio_only:
        if fresh: fail('请先通过 Renkit 安装插件商城，再重试修复。')
        if plugin.exists(): fail('已存在 X20 Fixes，请先用原插件卸载，或选择 install --audio-only。')
        if fresh and ((hb/'services').exists() or service.exists()): fail('发现非标准 Decky 安装；请先整理现有安装，或用 --audio-only。')
        if not fresh and (not service.is_file() or str(hb/'services/PluginLoader') not in service.read_text()):
            fail('现有 Decky 服务路径不是此用户的标准目录；请选择 --audio-only。')
        if not (home/'.steam/steam').is_dir(): fail('找不到 Steam 原生客户端目录；请先完成 Steam 登录。')
    cache=home/'.local/share/ally-audio-fix/cache/firmware'
    tracked=[Path(p) for p in ['/efi/EFI/steamos/grub.cfg','/efi/EFI/steamos/grub.cfg.pre-ally-audio-fix',
             '/efi/EFI/steamos/grub.cfg.ally-audio-fix.bak','/efi/acpi_override.cpio',
             '/var/lib/ally-audio-fix','/etc/modprobe.d/ally-audio-fix.conf',
             '/etc/environment.d/90-ally-audio-fix.conf','/run/ally-audio-fix.removed']]
    tracked.extend(cache/p.name for p in (PAYLOAD/'firmware').glob('*.bin'))
    if not audio_only:
        tracked += [plugin,home/'homebrew/settings/x20-fixes']
        if fresh: tracked += [hb/'services',service,home/'.steam/steam/.cef-enable-remote-debugging']
    was_active=subprocess.run(['systemctl','is-active','--quiet','plugin_loader'],env=ENV).returncode==0
    was_enabled=subprocess.run(['systemctl','is-enabled','--quiet','plugin_loader'],env=ENV).returncode==0
    records=snapshot(tracked)
    meta=dict(records=records,fresh_decky=fresh and not audio_only,audio_only=audio_only,
              was_active=was_active,was_enabled=was_enabled,user=pw.pw_name,home=str(home))
    (STATE/'state.json').write_text(json.dumps(meta,indent=2))
    try:
        cache.mkdir(parents=True,exist_ok=True)
        for p in (PAYLOAD/'firmware').glob('*.bin'):
            shutil.copy2(p,cache/p.name); os.chown(cache/p.name,pw.pw_uid,pw.pw_gid)
        for p in (home/'.local',home/'.local/share',home/'.local/share/ally-audio-fix',cache.parent,cache):
            os.chown(p,pw.pw_uid,pw.pw_gid)
        print('应用已验证的音频修复（将修改当前 SteamOS 槽的 ACPI 引导覆盖和模块加载配置）…')
        env=dict(ENV,ALLY_AUDIO_DATA=str(cache.parent.parent))
        subprocess.run(['sh',str(fix),'install'],env=env,check=True)
        if not audio_only:
            run(['systemctl','stop','plugin_loader'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL) if was_active else None
            plugin.parent.mkdir(parents=True,exist_ok=True)
            copy_owned_tree(PAYLOAD/'x20-fixes',plugin,pw.pw_uid,pw.pw_gid)
            run(['systemctl','start','plugin_loader'])
        (STATE/'installed-grub.sha256').write_text(hashlib.sha256(Path('/efi/EFI/steamos/grub.cfg').read_bytes()).hexdigest())
        (STATE/'complete').write_text('installed\n')
        print('文件已部署。请手动重启掌机，然后检查 X20 Fixes 与声音；本脚本不会自动重启。')
    except Exception:
        print('安装未完成；恢复本次安装前的文件。',file=sys.stderr)
        rollback(meta)
        raise
def rollback(meta):
    if not meta['audio_only']:
        subprocess.run(['systemctl','stop','plugin_loader'],env=ENV)
        if meta['fresh_decky']: subprocess.run(['systemctl','disable','plugin_loader'],env=ENV)
    restore(meta['records'])
    if not meta['audio_only']:
        run(['systemctl','daemon-reload'])
        if meta['was_active']: run(['systemctl','start','plugin_loader'])
    shutil.rmtree(STATE)
def uninstall():
    if os.geteuid()!=0: fail('卸载需要 sudo。')
    errors=compat.problems(compat.read_state(),install=False)
    if errors: fail('\n'.join(errors))
    if not (STATE/'state.json').is_file(): fail('没有本包备份记录；不要用本包卸载其他来源的安装。')
    meta=json.loads((STATE/'state.json').read_text())
    # Never restore a pre-update boot configuration over a different SteamOS slot.
    saved=STATE/'installed-grub.sha256'
    current=Path('/efi/EFI/steamos/grub.cfg')
    if not saved.exists() or hashlib.sha256(current.read_bytes()).hexdigest()!=saved.read_text().strip():
        fail('引导配置在安装后发生变化（可能已更新系统）；停止恢复旧备份。请参照中文说明的更新后卸载步骤。')
    rollback(meta)
    print('已恢复安装前文件。请手动重启掌机。')
def main():
    parser=argparse.ArgumentParser(description='RC74XA SteamOS 修复包（默认只检测，核对驱动兼容性）')
    parser.add_argument('action',choices=['plan','check','install','status','uninstall'],nargs='?',default='check')
    parser.add_argument('--audio-only',action='store_true',help='仅部署音频，不安装 Decky 或插件')
    args=parser.parse_args()
    if args.action=='plan':
        verify(); state=compat.read_state(); errors=compat.problems(state)
        if errors: fail('\n'.join(errors))
        print('已确认 ROG 20 周年 RC74XA，系统与 BIOS 符合本方案。')
    elif args.action=='check':
        verify(); s=compat.read_state(); print(json.dumps(s,ensure_ascii=False,indent=2))
        errors=compat.problems(s)
        if errors: fail('\n'.join(errors))
        need_commands()
        if s['speaker'] not in (0,1): fail('需用 sudo 检测 SPEAKER_ID，或该设备未提供受支持的扬声器 ID。')
        print('兼容性预检查通过；未修改系统。')
    elif args.action=='install':
        install(args.audio_only)
    elif args.action=='uninstall': uninstall()
    else:
        print('本包状态：', '已部署' if (STATE/'complete').exists() else '未完成部署或未安装')
        errors=compat.problems(compat.read_state(),install=False)
        if errors: fail('\n'.join(errors))
        run(['sh',PAYLOAD/'x20-fixes/fix/ally-audio-fix.sh','status'])

if __name__=='__main__':
    try: main()
    except (RuntimeError,OSError,subprocess.CalledProcessError) as exc:
        print('停止：'+str(exc),file=sys.stderr); sys.exit(1)
