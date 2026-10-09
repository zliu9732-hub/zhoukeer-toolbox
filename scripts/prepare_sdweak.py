"""Prepare the reviewed SDWEAK release without running any upstream code."""
import hashlib
from pathlib import Path, PurePosixPath
import stat
import re
import sys
import zipfile

SHA256 = '5e91ca94577e3a999b6a8ea1a3e849bb168fedcc5b12b3cc41a00ca355d00d9e'
FILES = {'README.md', 'README_ENG.md', 'install.sh', 'uninstall.sh', 'LICENSE', '.gitignore',
         'assets/zram-generator.conf', 'assets/energy.service', 'assets/common.sh',
         'assets/gamescope-3.16.23.2-1-SDWEAK.pkg.tar.zst',
         'assets/vulkan-radeon-SDWEAK.pkg.tar.zst', 'assets/sdweak.service', 'assets/scx',
         'assets/strings.sh', 'assets/energy.path', 'assets/SDWEAK.sh'}
ZH = {
 'ping_success': '网络检查通过。', 'ping_fail': '网络检查失败，请检查连接后重试。',
 'integrity_fail': '安装文件损坏或不完整，已停止。',
 'compatible': '警告：仅 Steam Deck 可用，其他掌机一律禁止安装。',
 'old_steamos': '仅支持 SteamOS 3.8。', 'readonly_fail': '无法暂时关闭系统保护，已停止。',
 'installation_start': '正在安装 SDWEAK…', 'skip': '已跳过。',
 'invalid_input': '请输入 y（是）或 n（否）。',
 'usbhid_success': '已改善手柄响应。', 'scx_success': '已启用性能优化。',
 'sysctl_success': '已应用系统性能设置。', 'zram_conf': '内存优化已保存，重启后生效。',
 'gpu_optimization_success': '已应用显卡优化设置。',
 'display_overclock_prompt': '是否将 LCD 屏幕提高到 70 Hz？可能影响显示稳定性；回车跳过',
 'display_overclock_success': '已处理屏幕刷新率设置。',
 'power_efficiency_prompt': '是否优先降低处理器耗电？部分游戏可能更卡；回车跳过',
 'power_efficiency_install': '正在设置节能优先…',
 'power_efficiency_success': '已应用节能优先。',
 'sdweak_success': 'SDWEAK 已安装，请手动重启。',
 'installation_time': '安装耗时', 'seconds': '秒。',
}

def prepare(archive, destination):
    if hashlib.sha256(Path(archive).read_bytes()).hexdigest() != SHA256:
        raise ValueError('SDWEAK 校验未通过')
    files = {}
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            path = PurePosixPath(entry.filename)
            if path.is_absolute() or '..' in path.parts or str(path) != entry.filename.rstrip('/'):
                raise ValueError('安装文件路径不安全')
            if entry.is_dir():
                if entry.filename not in ('SDWEAK/', 'SDWEAK/assets/'):
                    raise ValueError('出现意外目录')
                continue
            name = entry.filename.removeprefix('SDWEAK/')
            mode = entry.external_attr >> 16
            if name not in FILES or name in files or stat.S_ISLNK(mode) or entry.file_size > 67108864:
                raise ValueError('出现意外文件、链接或过大文件')
            files[name] = z.read(entry)
    if set(files) != FILES:
        raise ValueError('安装文件不完整')
    script = files['install.sh'].decode()
    script = script.replace('#!/bin/bash\n', '#!/bin/bash\nset -Eeo pipefail\n', 1)
    script = script.replace(': > "$LOG_FILE"\n', ''': > "$LOG_FILE"
RENKIT_SDWEAK_STEP="检查安装文件"
renkit_sdweak_error() {
    local result="$1" line="$2"
    trap - ERR
    printf 'SDWEAK 未完成：%s失败。详细记录：%s\\n' "$RENKIT_SDWEAK_STEP" "$LOG_FILE" >&2
    log "ERROR: step=$RENKIT_SDWEAK_STEP line=$line exit=$result"
    exit "$result"
}
trap 'renkit_sdweak_error "$?" "$LINENO"' ERR
''', 1)
    start = script.index('choose_language() {')
    end = script.index('log "LANGUAGE:', start)
    script = script[:start] + 'selected_lang="en"\n' + script[end:]
    # Do not weaken system-wide signature checks or delete the user's keys/cache.
    start = script.index('# Pacman\n')
    end = script.index('# Unlocking the memory lock', start)
    script = script[:start] + script[end:]
    # The full package is already local and verified; blocked ICMP must not
    # reject an otherwise successful download or require additional internet.
    start = script.index('# Checking Internet access\n')
    end = script.index('# Checksum validation', start)
    script = script[:start] + script[end:]
    script = script.replace('sudo pacman -Rdd --noconfirm gamemode &>/dev/null',
                            'if pacman -Q gamemode >/dev/null 2>&1; then sudo pacman -Rdd --noconfirm gamemode; fi')
    script = script.replace('findmnt -no OPTIONS --target /home 2>/dev/null)',
                            'findmnt -no OPTIONS --target /home 2>/dev/null || true)')
    # grep returns 1 for a valid empty selection (e.g. /home only has relatime).
    script = script.replace("grep -Ev '^(no)?(atime|relatime|strictatime|diratime)$'",
                            "awk '!/^(no)?(atime|relatime|strictatime|diratime)$/'")
    script = script.replace('sudo systemctl disable --now energy.path >> "$LOG_FILE" 2>&1',
                            'if systemctl cat energy.path >/dev/null 2>&1; then '
                            'sudo systemctl disable --now energy.path >> "$LOG_FILE" 2>&1; fi')
    # Omit the experimental unsigned graphics/compositor replacement; core tweaks remain.
    start = script.index('# Frametime fix\n')
    end = script.index('# Overclock LCD', start)
    script = script[:start] + script[end:]
    script = script.replace('\nframetime_fix\n', '\n')
    # Do not restart an in-use swap device. Apply the new configuration at the
    # manual reboot already required by the other boot settings.
    script = script.replace('sudo systemctl restart systemd-zram-setup@zram0 >> "$LOG_FILE" 2>&1\n', '')
    script = script.replace('zram0 restarted', 'activation deferred until manual reboot')
    script = script[:script.index('# Reboot\n')] + 'echo "请保存工作后手动重启。"\n'
    for marker, step in (
        ('sudo steamos-readonly disable', '暂时关闭系统保护'),
        ('# Checksum validation', '检查安装文件'),
        ('# Unlocking the memory lock', '设置内存使用权限'),
        ('# Disable file access time tracking', '优化文件访问'),
        ('# Input controller overclocking', '改善手柄响应'),
        ('# Remove gamemoded', '处理旧性能设置'),
        ('# scx-lavd', '启用性能优化'),
        ('# Sysctl Tweaks', '保存系统性能设置'),
        ('# ZRAM Tweaks', '保存内存优化'),
        ('# Changing amdgpu parameters', '保存显卡设置'),
        ('# Mitigations off', '保存启动设置'),
        ('# display overclock LCD', '设置屏幕刷新率'),
        ('\npower_efficiency\n', '设置节能选项'),
        ('# Finalize', '完成系统设置'),
    ):
        script = script.replace(marker, f'\nRENKIT_SDWEAK_STEP="{step}"\n' + marker, 1)
    # Reuse Renkit's secure authentication for every privileged operation.
    # Raw sudo loses its timestamp after the parent helper invalidates it.
    script = re.sub(r'\bsudo(?=\s)', 'toolbox_sudo', script)
    files['install.sh'] = script.encode()
    strings = files['assets/strings.sh'].decode()
    for key, text in ZH.items():
        strings += f'\ntexts["en_{key}"]="{text}"'
    files['assets/strings.sh'] = (strings + '\n').encode()
    dest = Path(destination)
    if dest.exists() or dest.is_symlink():
        raise ValueError('准备目录已存在')
    dest.mkdir(mode=0o700)
    for name, data in files.items():
        target = dest / 'SDWEAK' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        target.chmod(0o600)
    (dest / 'SDWEAK/RENKIT-CHANGES.txt').write_text(
        'Renkit：中文提示与失败步骤；沿用管理员验证；失败即停止；'
        '已校验文件无需再次联网；内存优化重启后生效；'
        '保留软件签名检查、密钥与缓存；不安装实验性显示组件；'
        '不自动重启。原作者 Taskerer / @noncatt，MIT。\n')

if __name__ == '__main__':
    try:
        prepare(*sys.argv[1:])
    except (OSError, ValueError, zipfile.BadZipFile, KeyError, TypeError) as error:
        print(f'SDWEAK 准备失败：{error}', file=sys.stderr)
        sys.exit(1)
