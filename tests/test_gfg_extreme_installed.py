"""Exercise the real release installer with temp HOME and guarded OS commands."""
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

package = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="renkit-gfg-installed-") as temporary:
    base = Path(temporary)
    source = base / "release"
    source.mkdir()
    with tarfile.open(package) as archive:
        for entry in archive.getmembers():
            assert not entry.issym() and not entry.islnk()
            assert not Path(entry.name).is_absolute() and ".." not in Path(entry.name).parts
        archive.extractall(source, filter="data")
    (source / "modules/software.sh").write_text("#!/bin/bash\nexit 0\n")
    (source / "core/platform.sh").write_text("detect_platform() { IS_STEAMOS=1; IS_CHIMERAOS=0; PLATFORM_FAMILY=steamos; }\n")
    binary = base / "bin"
    binary.mkdir()
    for command in ("sudo", "curl", "wget", "pacman", "systemctl", "flatpak", "udevadm", "steamos-readonly"):
        guard = binary / command
        guard.write_text("#!/bin/sh\necho 'Forbidden real command' >&2\nexit 97\n")
        guard.chmod(0o755)
    (binary / "uname").write_text("#!/bin/sh\nprintf 'Linux\\n'\n")
    (binary / "uname").chmod(0o755)
    (binary / "python3").symlink_to(sys.executable)
    home = base / "home"
    installed = home / "renkit"
    installed.mkdir(parents=True)
    (installed / "old-app").write_text("old version")
    (installed / "apps").mkdir()
    (installed / "apps/customer-data").write_text("preserved")
    environment = {key: value for key,value in os.environ.items() if not key.startswith(("ZHOUKEER_","RENKIT_","BASH_FUNC_","XDG_"))}
    environment.update(HOME=str(home), PATH=str(binary) + ":" + os.environ["PATH"],
                       XDG_CONFIG_HOME=str(home / ".config"), XDG_DATA_HOME=str(home / ".local/share"),
                       ZHOUKEER_INSTALL_DIR=str(installed), ZHOUKEER_DESKTOP_DIR=str(home / "Desktop"))
    def install(ok):
        result = subprocess.run(["bash", str(source / "install.sh")], env=environment, capture_output=True, text=True, timeout=90)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr
        return result.stdout + result.stderr
    # A missing source or an earlier copy failure must not activate a partial app.
    resource = source / "assets/sdweak/SDWEAK-core-v2.2.0.zip"
    saved = resource.read_bytes()
    resource.unlink()
    assert "旧版本保持不变" in install(False)
    assert (installed / "old-app").read_text() == "old version"
    resource.write_bytes(saved)
    copier = binary / "cp"
    copier.write_text('#!/bin/sh\ncase "${1:-}" in\n  */modules/gfg_extreme.sh) exit 1 ;;\nesac\nexec /bin/cp "$@"\n')
    copier.chmod(0o755)
    assert "旧版本保持不变" in install(False)
    assert (installed / "old-app").read_text() == "old version"
    copier.unlink()
    install(True)
    assert not (installed / "old-app").exists()
    assert (installed / "apps/customer-data").read_text() == "preserved"
    for relative in ("modules/gfg_extreme.sh","scripts/localize_gfg_extreme.py","data/gfg_extreme_files.json","assets/sdweak/SDWEAK-core-v2.2.0.zip","scripts/prepare_sdweak.py"):
        assert (installed / relative).read_bytes() == (source / relative).read_bytes(), relative
    for path in (source / "assets/screen-colors").rglob("*"):
        if path.is_file():
            assert (installed / path.relative_to(source)).read_bytes() == path.read_bytes(), str(path)
    archive_path=Path(sys.argv[2]).resolve()
    plugin = base / "plugin"
    subprocess.run([sys.executable,str(installed / "scripts/localize_gfg_extreme.py"),"prepare",str(plugin),"--archive",str(archive_path)],check=True)
    subprocess.run([sys.executable,str(installed / "scripts/localize_gfg_extreme.py"),"check",str(plugin)],check=True)
print("PASS: actual release installer preserves old app on incomplete components and installs complete GFG/SDWEAK components")
