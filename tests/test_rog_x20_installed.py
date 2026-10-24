"""Real app installer from release tar; all writes confined to a temporary HOME.

Only platform detection and software shortcut hooks are replaced. Never run the
hardware repair engine. Pass the release tar path as the sole argument.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

PACKAGE = Path(sys.argv[1]).resolve()
PAYLOAD = Path("third_party/rc74xa-offline-20261024")

with tempfile.TemporaryDirectory(prefix="renkit-installed-") as temporary:
    base = Path(temporary)
    source = base / "release"
    source.mkdir()
    with tarfile.open(PACKAGE) as archive:
        for member in archive.getmembers():
            assert not member.issym() and not member.islnk()
            assert not Path(member.name).is_absolute() and ".." not in Path(member.name).parts
        archive.extractall(source, filter="data")
    # These hooks are unrelated to payload copying and must never reach the host.
    (source / "modules/software.sh").write_text("#!/bin/bash\nexit 0\n")
    (source / "core/platform.sh").write_text(
        "detect_platform() { IS_STEAMOS=1; IS_CHIMERAOS=0; PLATFORM_FAMILY=steamos; }\n")
    binary = base / "bin"
    binary.mkdir()
    (binary / "uname").write_text("#!/bin/sh\nprintf 'Linux\\n'\n")
    (binary / "uname").chmod(0o755)
    (binary / "python3").symlink_to(sys.executable)
    for command in ("sudo", "curl", "wget", "pacman", "systemctl", "flatpak", "udevadm", "steamos-readonly"):
        guard = binary / command
        guard.write_text("#!/bin/sh\necho 'Forbidden real command' >&2\nexit 97\n")
        guard.chmod(0o755)
    home = base / "home"
    home.mkdir()
    installed = home / "renkit"
    installed.mkdir()
    (installed / "old-app").write_text("old version")
    (installed / "apps").mkdir()
    (installed / "apps/customer-data").write_text("preserved")
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith(("ZHOUKEER_", "RENKIT_", "BASH_FUNC_", "XDG_"))}
    environment.update(HOME=str(home), PATH=str(binary) + ":" + os.environ["PATH"],
                       XDG_CONFIG_HOME=str(home / ".config"), XDG_DATA_HOME=str(home / ".local/share"),
                       ZHOUKEER_INSTALL_DIR=str(installed), ZHOUKEER_DESKTOP_DIR=str(home / "Desktop"))

    def install(ok):
        result = subprocess.run(["bash", str(source / "install.sh")], env=environment,
                                capture_output=True, text=True, timeout=90)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr
        return result.stdout + result.stderr

    original = (source / PAYLOAD / "manifest.json").read_bytes()
    # Missing and corrupt source bundles must preserve the previous app.
    for contents in (None, b"{}"):
        manifest = source / PAYLOAD / "manifest.json"
        if contents is None:
            manifest.unlink()
        else:
            manifest.write_bytes(contents)
        assert "旧版本保持不变" in install(False)
        assert (installed / "old-app").read_text() == "old version"
        assert (installed / "apps/customer-data").read_text() == "preserved"
    (source / PAYLOAD / "manifest.json").write_bytes(original)
    # The generic copy loop can finish successfully after an earlier cp failure;
    # the destination verifier must still block activation of the incomplete app.
    copier = binary / "cp"
    copier.write_text("#!/bin/sh\ncase \"${1:-}\" in\n"
                      "  */payload/firmware/1954-0-0-0x8.bin) exit 1 ;;\nesac\n"
                      "exec /bin/cp \"$@\"\n")
    copier.chmod(0o755)
    assert "旧版本保持不变" in install(False)
    assert (installed / "old-app").read_text() == "old version"
    copier.unlink()
    install(True)
    assert not (installed / "old-app").exists()
    assert (installed / "apps/customer-data").read_text() == "preserved"
    files = json.loads(original)["sha256"]
    for name, digest in files.items():
        assert hashlib.sha256((installed / PAYLOAD / name).read_bytes()).hexdigest() == digest, name
    verifier = installed / "scripts/verify_rog_x20_package.py"
    subprocess.run([sys.executable, "-I", "-B", str(verifier), str(installed / PAYLOAD)], check=True)
    # A broken copied file is rejected by the same runtime verifier.
    (installed / PAYLOAD / "installer.py").write_text("broken")
    result = subprocess.run([sys.executable, "-I", "-B", str(verifier), str(installed / PAYLOAD)],
                            capture_output=True, text=True)
    assert result.returncode != 0 and "检查未通过" in result.stderr
print("PASS: release → real installer → complete verified RC74XA payload; invalid bundles preserve old app")
