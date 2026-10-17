#!/usr/bin/env python3
"""48-hour upstream checks, static UI localization, verified Gitee publication."""
import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

from framegen_package import KINDS, digest, entry, safe_path, version, zip_files, zip_modes

ROOT = Path(__file__).resolve().parent.parent
CATALOG_URL = 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-4/raw/main/framegen-auto/catalog.json'
UPSTREAM = {'lsfg-v2': ('xXJSONDeruloXx/decky-lsfg-vk', 'Decky.LSFG-VK.zip'),
            'fsr4': ('xXJSONDeruloXx/Decky-Framegen', 'Decky-Framegen.zip')}
MODEL = 'Helsinki-NLP/opus-mt-en-zh'
MODEL_REVISION = '408d9bc410a388e1d9aef112a2daba955b945255'
TRANSLATION_REVISION = 2  # Rebuild older automatic packages even without an upstream version bump.

def due(timestamp=None):
    # Unix-day parity, unlike */2 day-of-month cron, stays 48 hours across month boundaries.
    return int((time.time() if timestamp is None else timestamp) // 86400) % 2 == 0

def fetch(url, target=None, limit=536870912):
    if not url.startswith('https://'):
        raise ValueError('HTTPS required')
    headers = {'User-Agent': 'Renkit-localization-sync', 'Accept': 'application/vnd.github+json'}
    if url.startswith('https://api.github.com/') and os.environ.get('GITHUB_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GITHUB_TOKEN']
    request = urllib.request.Request(url, headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                if not response.url.startswith('https://'):
                    raise ValueError('insecure redirect')
                if target:
                    total = 0
                    with Path(target).open('wb') as output:
                        while block := response.read(1048576):
                            total += len(block)
                            if total > limit:
                                raise ValueError('download too large')
                            output.write(block)
                    return None
                data = response.read(limit + 1)
                if len(data) > limit:
                    raise ValueError('metadata too large')
                return json.loads(data)
        except (OSError, ValueError):
            if attempt == 2:
                raise
            time.sleep(2)

def latest(kind):
    repo, filename = UPSTREAM[kind]
    j = fetch('https://api.github.com/repos/' + repo + '/releases/latest', limit=2097152)
    if j.get('draft') or j.get('prerelease'):
        raise ValueError('not a stable release')
    tag = j['tag_name']
    version(tag)
    matches = [a for a in j['assets'] if a['name'] == filename]
    if len(matches) != 1:
        raise ValueError('missing or ambiguous release asset')
    a = matches[0]
    sha = a.get('digest', '')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', sha):
        raise ValueError('upstream asset has no trusted SHA256')
    url = a['browser_download_url']
    if url != 'https://github.com/' + repo + '/releases/download/' + tag + '/' + filename:
        raise ValueError('unexpected upstream asset URL')
    return {'version': tag.lstrip('v'), 'sha256': sha[7:], 'url': url}

def make_plan(catalog, releases):
    result = {}
    for kind in KINDS:
        current = entry(catalog, kind)
        release = releases[kind]
        if version(release['version']) < version(current['upstream_version']):
            raise ValueError('upstream downgrade rejected')
        repair = (current['mirror_id'] == KINDS[kind]['ids'][1] and
                  current['attribution'] == 'RenAmamiya' and
                  current.get('translation_revision', 0) < TRANSLATION_REVISION)
        if repair or release['version'] != current['upstream_version'].lstrip('v') or release['sha256'] != current['upstream_sha256']:
            result[kind] = release
    return result

def translate_missing(strings):
    """No paid API or credentials: pinned CPU translation model, loaded only for new text."""
    from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
    from opencc import OpenCC
    import torch
    tokenizer = AutoTokenizer.from_pretrained(MODEL, revision=MODEL_REVISION, trust_remote_code=False)
    model = AutoModelForSeq2SeqLM.from_pretrained(MODEL, revision=MODEL_REVISION, trust_remote_code=False, weights_only=True)
    model.eval()
    converter = OpenCC('t2s')
    result = {}
    for text in strings:
        body = text.strip()
        inputs = tokenizer('>>cmn_Hans<< ' + body, return_tensors='pt', truncation=False)
        if inputs['input_ids'].shape[-1] > 450:
            raise ValueError('new UI text exceeds translation limit')
        with torch.inference_mode():
            ids = model.generate(**inputs, max_new_tokens=512, num_beams=4, do_sample=False)
        translated = converter.convert(tokenizer.decode(ids[0], skip_special_tokens=True)).strip()
        if not re.search('[\u3400-\u9fff]', translated) or not 0 < len(translated) < len(body)*5:
            raise ValueError('new translation failed content checks')
        if re.findall(r'\d+(?:\.\d+)*', body) != re.findall(r'\d+(?:\.\d+)*', translated):
            raise ValueError('translation changed numbers')
        for token in re.findall(r'\b(?:FSR\d?|DLSS|HDR|DXVK|Vulkan|OptiScaler|LSFG-VK|SteamOS|FP16|GPU|CPU)\b', body):
            if token not in translated:
                raise ValueError('translation changed a product/technical name')
        if re.findall(r'%\w|\{[^}]*\}', body) != re.findall(r'%\w|\{[^}]*\}', translated):
            raise ValueError('translation changed placeholders')
        result[text] = text[:len(text)-len(text.lstrip())] + translated + text[len(text.rstrip()):]
    return result

def node(*args, capture=False):
    return subprocess.run([os.environ.get('RENKIT_NODE_BINARY', 'node'), str(ROOT/'scripts/framegen_ui.mjs'), *map(str, args)],
                          check=True, capture_output=capture, text=True).stdout

def build(kind, release, archive, output, machine=False):
    if digest(archive) != release['sha256']:
        raise ValueError('official archive SHA256 mismatch')
    original = zip_files(archive)
    roots = [n.rsplit('/', 1)[0] for n in original if n.endswith('/plugin.json')]
    if len(roots) != 1:
        raise ValueError('unexpected upstream archive layout')
    prefix = roots[0] + '/'
    if any(not n.startswith(prefix) for n in original):
        raise ValueError('unexpected files outside plugin')
    files = {n[len(prefix):]: b for n, b in original.items()}
    modes = {n[len(prefix):]: mode for n, mode in zip_modes(archive).items()}
    package = json.loads(files['package.json'])
    plugin = json.loads(files['plugin.json'])
    if version(package['version']) != version(release['version']) or plugin['name'] not in KINDS[kind]['names']:
        raise ValueError('upstream identity/version mismatch')
    for binary in package.get('remote_binary', []):
        name = safe_path(binary['name'])
        if '/' in name or hashlib.sha256(files['bin/'+name]).hexdigest() != binary['sha256hash']:
            raise ValueError('bundled upstream runtime is incomplete')
    if not package.get('remote_binary'):
        raise ValueError('upstream runtime layout changed')
    work = Path(output)/kind
    work.mkdir(parents=True, exist_ok=True)
    js = work/'original.js'; js.write_bytes(files['dist/index.js'])
    info = json.loads(node('inspect', js, capture=True))
    if any(name != plugin['name'] for name in info['api_plugin_names']):
        raise ValueError('frontend/backend plugin registration mismatch')
    if info.get('official_chinese'):
        # A complete native Chinese locale wins: preserve the original ZIP and authorship byte-for-byte.
        package_path=work/'plugin.zip'; shutil.copyfile(archive, package_path)
        e={'upstream_version':release['version'],'upstream_sha256':release['sha256'],'package_sha256':digest(package_path),
           'frontend_sha256':hashlib.sha256(files['dist/index.js']).hexdigest(),'mirror_id':KINDS[kind]['ids'][1],
           'archive_root':roots[0],'plugin_name':plugin['name'],'attribution':'upstream',
           'files':{n:hashlib.sha256(b).hexdigest() for n,b in files.items()},'modes':modes}
        entry({'schema':1,'packages':{kind:e}},kind)
        return e,package_path
    dictionary = json.loads((ROOT/'data/framegen_zh.json').read_text())
    missing = [s for s in info['strings'] if s not in dictionary]
    if missing:
        if not machine:
            raise ValueError('new UI strings require translation: ' + json.dumps(missing, ensure_ascii=False))
        dictionary.update(translate_missing(missing))
    (work/'dictionary.json').write_text(json.dumps(dictionary, ensure_ascii=False))
    node('build', js, work/'dictionary.json', ROOT/'assets/framegen/zh-runtime.js', work/'localized.js')
    files['dist/index.js'] = (work/'localized.js').read_bytes()
    # Keep the upstream registration ID. @decky/api embeds it in dist/index.js;
    # translating plugin.json.name alone routes every Python call to a missing plugin.
    # The visible title is already translated by framegen_ui.mjs.
    publish = plugin.setdefault('publish', {})
    publish['description'] = ('小黄鸭补帧插件' if kind == 'lsfg-v2' else '游戏插帧与画面设置') + '；中文汉化：RenAmamiya。'
    files['plugin.json'] = (json.dumps(plugin, ensure_ascii=False, indent=2)+'\n').encode()
    files['RENKIT_TRANSLATION.json'] = (json.dumps({'upstream': UPSTREAM[kind][0], 'upstream_version': release['version'],
        'upstream_sha256': release['sha256'], 'translator': 'RenAmamiya', 'machine_new_strings': missing,
        'translation_revision': TRANSLATION_REVISION,
        'unchanged_backend_and_runtimes': True}, ensure_ascii=False, indent=2)+'\n').encode()
    modes['RENKIT_TRANSLATION.json']=0o644
    for n, b in original.items():
        relative = n[len(prefix):]
        if relative not in ['dist/index.js', 'plugin.json'] and files[relative] != b:
            raise ValueError('non-UI upstream file was modified')
    archive_root = KINDS[kind]['roots'][1 if kind == 'lsfg-v2' else 0]
    package_path = work/'plugin.zip'
    with zipfile.ZipFile(package_path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for relative in sorted(files):
            zi = zipfile.ZipInfo(archive_root+'/'+relative, date_time=(2020,1,1,0,0,0))
            zi.external_attr = ((0o100000 | modes[relative]) << 16)
            z.writestr(zi, files[relative], compress_type=zipfile.ZIP_DEFLATED, compresslevel=6)
    e = {'upstream_version': release['version'], 'upstream_sha256': release['sha256'], 'package_sha256': digest(package_path),
         'frontend_sha256': hashlib.sha256(files['dist/index.js']).hexdigest(), 'mirror_id': KINDS[kind]['ids'][1],
         'archive_root': archive_root, 'plugin_name': plugin['name'], 'attribution': 'RenAmamiya',
         'translation_revision': TRANSLATION_REVISION,
         'files': {n: hashlib.sha256(b).hexdigest() for n, b in files.items()}, 'modes':modes}
    entry({'schema':1,'packages':{kind:e}}, kind)
    return e, package_path

def write_mirror(root, kind, e, package):
    folder = 'v'+e['upstream_version']+'-'+e['package_sha256'][:16]
    ident = e['mirror_id']; filename = ident+'-'+folder+'.zip'
    target = Path(root)/ident/folder; target.mkdir(parents=True, exist_ok=True)
    size = package.stat().st_size; chunk_size = 8388608; chunks = 0
    if size <= chunk_size:
        shutil.copyfile(package, target/filename)
    else:
        with package.open('rb') as source:
            while block := source.read(chunk_size):
                chunks += 1; (target/f'part.{chunks:04d}').write_bytes(block)
    fields = {'id':ident, 'name':e['plugin_name'], 'version':folder, 'file':filename,
              'source_url':UPSTREAM[kind][0] and 'https://github.com/'+UPSTREAM[kind][0]+'/releases',
              'sha256':e['package_sha256'], 'size':size, 'chunks':chunks, 'chunk_size':chunk_size}
    (target.parent/'latest.txt').write_text(''.join(f'{k}={v}\n' for k,v in fields.items()))
    return folder, filename, chunks

def publish(prepared):
    prepared = Path(prepared); c = json.loads((prepared/'catalog.json').read_text())
    changes = json.loads((prepared/'updates.json').read_text())
    token = os.environ.get('GITEE_TOKEN')
    with tempfile.TemporaryDirectory(prefix='renkit-framegen-publish-') as temp:
        work = Path(temp); env = os.environ.copy()
        if token:
            askpass = work/'askpass.sh'
            askpass.write_text('#!/bin/sh\ncase "$1" in *Username*) printf "%s\\n" zliu9732-hub ;; *) printf "%s\\n" "$GITEE_TOKEN" ;; esac\n')
            askpass.chmod(0o700); env['GIT_ASKPASS'] = str(askpass); env['GIT_TERMINAL_PROMPT'] = '0'
        clones = {}
        def git(*args):
            subprocess.run(['git', *map(str,args)], env=env, check=True, timeout=600)
        for repo in sorted({KINDS[k]['repo'] for k in changes} | {'zhoukeer-toolbox-mirror-4'}):
            clone = work/repo; clones[repo] = clone
            url = 'https://gitee.com/zliu9732-hub/'+repo+'.git' if token else 'git@gitee.com:zliu9732-hub/'+repo+'.git'
            git('clone','--depth','1','--filter=blob:none','--no-checkout',url,clone)
            patterns = ['framegen-auto/**'] if repo.endswith('-4') else []
            patterns += [e['mirror_id']+'/**' for kind,e in c['packages'].items() if KINDS[kind]['repo']==repo and kind in changes]
            git('-C',clone,'sparse-checkout','set','--no-cone',*patterns)
            git('-C',clone,'checkout','main')
            git('-C',clone,'config','user.name','Renkit localization bot')
            git('-C',clone,'config','user.email','renkit-bot@users.noreply.github.com')
        # Upload complete packages first. Never publish the catalog before public byte verification.
        for kind in changes:
            e = entry(c,kind); clone = clones[KINDS[kind]['repo']]
            folder,filename,chunks = write_mirror(clone,kind,e,prepared/kind/'plugin.zip')
            git('-C',clone,'add',e['mirror_id'])
            if subprocess.run(['git','-C',str(clone),'diff','--cached','--quiet']).returncode:
                git('-C',clone,'commit','-m','Sync '+kind+' Chinese '+e['upstream_version'])
                git('-C',clone,'push','origin','HEAD:main')
            base='https://gitee.com/zliu9732-hub/'+KINDS[kind]['repo']+'/raw/main/'+e['mirror_id']+'/'+folder+'/'
            check=work/(kind+'.zip')
            if not chunks:
                fetch(base+filename,check)
            else:
                with check.open('wb') as output:
                    for i in range(1,chunks+1):
                        part=work/'part'; fetch(base+f'part.{i:04d}',part,8388608); output.write(part.read_bytes())
            if digest(check)!=e['package_sha256']:
                raise ValueError('Gitee public package verification failed; catalog unchanged')
        clone=clones['zhoukeer-toolbox-mirror-4']; target=clone/'framegen-auto/catalog.json'
        target.parent.mkdir(parents=True,exist_ok=True); target.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
        git('-C',clone,'add','framegen-auto/catalog.json')
        if subprocess.run(['git','-C',str(clone),'diff','--cached','--quiet']).returncode:
            git('-C',clone,'commit','-m','Publish verified framegen Chinese catalog')
            git('-C',clone,'push','origin','HEAD:main')
        # Raw cache may briefly return the old catalog; verify the exact published bytes.
        for attempt in range(12):
            if fetch(CATALOG_URL, limit=1048576)==c:
                print('Published catalog and all package checksums verified'); return
            time.sleep(10)
        raise ValueError('public catalog cache did not refresh')

def main():
    p=argparse.ArgumentParser(); p.add_argument('mode', choices=['due','plan','build','publish'])
    p.add_argument('--work',type=Path); p.add_argument('--machine',action='store_true'); args=p.parse_args()
    if args.mode=='due': print('true' if due() else 'false'); return
    if args.mode=='publish': publish(args.work); return
    args.work.mkdir(parents=True,exist_ok=True)
    if args.mode=='plan':
        c=fetch(CATALOG_URL,limit=1048576); releases={k:latest(k) for k in KINDS}; updates=make_plan(c,releases)
        (args.work/'catalog.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
        (args.work/'updates.json').write_text(json.dumps(updates,indent=2)+'\n')
        print('updates=true' if updates else 'updates=false')
        return
    c=json.loads((args.work/'catalog.json').read_text()); updates=json.loads((args.work/'updates.json').read_text())
    for kind,release in updates.items():
        archive=args.work/(kind+'-official.zip'); fetch(release['url'],archive)
        c['packages'][kind],_=build(kind,release,archive,args.work,args.machine)
    (args.work/'catalog.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    try: main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        raise SystemExit('Framegen sync stopped; published versions are preserved: '+str(error))
