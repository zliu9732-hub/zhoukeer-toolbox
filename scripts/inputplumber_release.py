"""Read a release asset and its SHA256 from GitHub's official asset list."""
from html.parser import HTMLParser
from pathlib import Path
import re
import sys

REPO = 'ShadowBlip/InputPlumber'
ASSET = 'inputplumber-x86_64.tar.gz'


class AssetList(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.depth = 0
        self.current = None
        self.matches = []
        self.invalid = False

    def digest(self, value):
        if self.current is not None and re.fullmatch(r'sha256:[0-9a-fA-F]{64}', value.strip()):
            self.current['digests'].add(value.strip()[7:].lower())

    def handle_starttag(self, tag, attrs):
        if tag == 'li':
            self.depth += 1
            if self.depth > 1:
                self.invalid = True
            if self.depth == 1:
                self.current = {'target': False, 'digests': set()}
        if self.current is None:
            return
        attrs = dict(attrs)
        if tag == 'a' and attrs.get('href') in (self.path, 'https://github.com' + self.path):
            self.current['target'] = True
        if tag == 'clipboard-copy':
            self.digest(attrs.get('value', ''))

    def handle_data(self, value):
        self.digest(value)

    def handle_endtag(self, tag):
        if tag == 'li' and self.depth:
            if self.depth == 1:
                if self.current['target']:
                    self.matches.append(self.current['digests'])
                self.current = None
            self.depth -= 1


def parse(tag, html):
    if not re.fullmatch(r'v?\d+\.\d+\.\d+', tag):
        raise ValueError('不是适用的正式版本')
    if len(html.encode()) > 2097152:
        raise ValueError('版本信息过大')
    path = f'/{REPO}/releases/download/{tag}/{ASSET}'
    parser = AssetList(path)
    parser.feed(html)
    parser.close()
    if parser.invalid or parser.depth or len(parser.matches) != 1 or len(parser.matches[0]) != 1:
        raise ValueError('未找到唯一且完整的安装包校验信息')
    sha = next(iter(parser.matches[0]))
    return tag, ASSET, sha, 'https://github.com' + path


if __name__ == '__main__':
    try:
        print('\t'.join(parse(sys.argv[1], Path(sys.argv[2]).read_text())))
    except (OSError, UnicodeError, ValueError, IndexError) as error:
        print(f'InputPlumber 版本信息检查失败：{error}', file=sys.stderr)
        sys.exit(1)
