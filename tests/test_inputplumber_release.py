"""Release HTML is untrusted metadata; synthetic fixtures never access the network."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release', ROOT / 'scripts/inputplumber_release.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
TAG = 'v0.90.0'
SHA = 'a' * 64
PATH = f'/ShadowBlip/InputPlumber/releases/download/{TAG}/inputplumber-x86_64.tar.gz'


def row(path=PATH, sha=SHA):
    return f'<li><a href="{path}">asset</a><span>sha256:{sha}</span><clipboard-copy value="sha256:{sha}"></clipboard-copy></li>'


def reject(html, tag=TAG):
    try:
        m.parse(tag, html)
    except ValueError:
        return
    raise AssertionError('Untrusted or ambiguous asset accepted')


html = '<ul>' + row(PATH.replace('x86_64', 'aarch64'), 'b' * 64) + row() + '</ul>'
assert m.parse(TAG, html) == (TAG, m.ASSET, SHA, 'https://github.com' + PATH)
assert m.parse(TAG, row('https://github.com' + PATH, SHA.upper()))[2] == SHA
reject(row(sha='a' * 63))
reject(row(sha=''))
reject(row('https://example.com' + PATH))
reject(row(PATH.replace(TAG, 'v0.81.0')))
reject(row() + row())
reject(row().replace('</li>', '<span>sha256:' + 'b' * 64 + '</span></li>'))
reject(row().replace('</li>', ''))
reject('<li><a href="' + PATH + '">asset</a><li>sha256:' + SHA + '</li></li>')
reject('<li><a href="' + PATH + '">asset</a></li>' + row(PATH.replace('x86_64', 'aarch64')))
for tag in ('v0.90.0-rc1', 'nightly', '../v0.90.0', 'v0.90.0?x=1'):
    reject(html, tag)
reject(html + ' ' * 2097152)
print('PASS: exact official asset, associated SHA256, future stable release, ambiguity and malformed HTML gates')
