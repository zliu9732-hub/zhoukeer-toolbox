#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Read-only compatibility gate. No writes and no downloads."""
import os
from pathlib import Path
import platform
import re
import shlex
import sys

KERNEL = '7.2.7-valve2-1-neptune-72-g31504582a073'
VERSION = '3.9.3'
BIOS = {'RC74XA.301', 'RC74XA.303'}
SPEAKER_VAR = 'SPEAKER_ID-aa61eaaf-6e83-7523-b0d0-7df74bb24a81'

def read_text(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ''

def read_state(root=Path('/')):
    def text(p):
        return read_text(root / p)
    release = {}
    for line in text('etc/os-release').splitlines():
        if '=' in line and not line.startswith('#'):
            k,v=line.split('=',1)
            try:
                release[k]=' '.join(shlex.split(v))
            except ValueError:
                pass
    acp=[]
    for p in (root/'sys/bus/pci/devices').glob('*'):
        if (read_text(p/'vendor'),read_text(p/'device')) == ('0x1022','0x15e2'):
            acp.append((read_text(p/'subsystem_vendor'),read_text(p/'subsystem_device')))
    try:
        b=(root/'sys/firmware/efi/efivars'/SPEAKER_VAR).read_bytes()
        speaker=int.from_bytes(b[4:8],'little') if len(b)>=8 else None
    except OSError:
        speaker=None
    return dict(system=platform.system(),arch=platform.machine(),kernel=platform.release(),
                vendor=text('sys/class/dmi/id/sys_vendor'),device=text('sys/class/dmi/id/product_name'),
                bios=text('sys/class/dmi/id/bios_version'),release=release,acp=acp,speaker=speaker)

def problems(s, install=True):
    out=[]
    if s['system']!='Linux': out.append('仅支持目标掌机的 Linux；当前系统不是 Linux。')
    if s['arch']!='x86_64': out.append('CPU 架构不匹配，要求 x86_64。')
    if 'ASUS' not in s['vendor'].upper(): out.append('DMI 厂商不是 ASUS。')
    if not re.search(r'\bRC74XA\b',s['device']): out.append('DMI 设备不是 RC74XA。')
    if ('0x1043','0x1954') not in s['acp']: out.append('缺少 AMD ACP 1022:15e2 / 1043:1954 音频设备。')
    if install:
        if s['release'].get('ID')!='steamos': out.append('仅支持 Valve SteamOS。')
        if s['release'].get('VERSION_ID')!=VERSION: out.append('只收录已验证的 SteamOS 3.9.3；其他版本停止。')
        if s['kernel']!=KERNEL: out.append('内核不匹配：不允许强制加载、改名套用或自动编译。')
        if s['bios'] not in BIOS: out.append('BIOS 不在已验证的 RC74XA.301 / .303 清单内。')
    return out

if __name__=='__main__':
    state=read_state()
    print('设备:',state['device'],' BIOS:',state['bios'])
    print('SteamOS:',state['release'].get('VERSION_ID','未知'),' Build:',state['release'].get('BUILD_ID','未知'))
    print('内核:',state['kernel'])
    errors=problems(state)
    for error in errors: print('拒绝:',error,file=sys.stderr)
    sys.exit(bool(errors))
