#!/usr/bin/env python3
"""Archive-only tests: never execute the Windows client or system commands."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('portable', ROOT / 'scripts/quark_portable.py')
portable = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portable)


class PortableTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.drive = self.root / 'drive with spaces'
        self.drive.mkdir()
        self.original_inventory = portable.INVENTORY
        self.files = {'QuarkCloudDrive.exe': b'MZbootstrap',
                      'app-3.24.0/QuarkCloudDrive.exe': b'MZclient',
                      'app-3.24.0/resources/app.asar': b'complete resource'}
        self.manifest = {name: {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                         for name, data in self.files.items()}
        portable.INVENTORY = self.root / 'inventory.json'
        portable.INVENTORY.write_text(json.dumps(self.manifest))

    def tearDown(self):
        portable.INVENTORY = self.original_inventory
        self.temp.cleanup()

    def archive(self, extra=None, files=None):
        path = self.root / 'client.tar.xz'
        with tarfile.open(path, 'w:xz') as tar:
            for name, data in (self.files if files is None else files).items():
                member = tarfile.TarInfo('quark-cloud-drive/' + name)
                member.size = len(data)
                tar.addfile(member, io.BytesIO(data))
            if extra:
                tar.addfile(extra, io.BytesIO(b'x') if extra.isfile() else None)
        return path

    def assert_clean(self):
        self.assertFalse((self.drive / portable.DIRECTORY).exists())
        self.assertEqual(list(self.drive.glob('.quark-prepare-*')), [])

    def test_install_and_repeat_keep_customer_files(self):
        (self.drive / 'customer.data').write_text('saved')
        exe = portable.install(self.archive(), self.drive)
        self.assertEqual(exe.read_bytes(), self.files['QuarkCloudDrive.exe'])
        (exe.parent / 'new-account.json').write_text('new settings')
        self.assertEqual(portable.install(self.archive(), self.drive), exe)
        self.assertEqual((exe.parent / 'new-account.json').read_text(), 'new settings')
        self.assertEqual((self.drive / 'customer.data').read_text(), 'saved')

    def test_managed_external_drive_link(self):
        link = self.root / 'drive_c'
        link.symlink_to(self.drive, target_is_directory=True)
        self.assertTrue(portable.install(self.archive(), link).is_file())

    def test_unexpected_paths_and_duplicates_rejected_before_writing(self):
        for name in ['../outside', '/absolute', 'quark-cloud-drive/../outside',
                     'quark-cloud-drive/app-3.24.0/./surprise',
                     'quark-cloud-drive/unknown.exe',
                     'quark-cloud-drive/QuarkCloudDrive.exe',
                     'quark-cloud-drive/a\\b']:
            with self.subTest(name=name):
                member = tarfile.TarInfo(name)
                member.size = 1
                with self.assertRaises(ValueError):
                    portable.install(self.archive(member), self.drive)
                self.assert_clean()
                self.assertFalse((self.root / 'outside').exists())

    def test_links_and_special_members_rejected(self):
        for kind in [tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE, tarfile.CHRTYPE, tarfile.DIRTYPE]:
            with self.subTest(kind=kind):
                member = tarfile.TarInfo('quark-cloud-drive/link')
                member.type = kind
                member.linkname = '../outside'
                with self.assertRaises(ValueError):
                    portable.install(self.archive(member), self.drive)
                self.assert_clean()

    def test_missing_and_corrupted_resources_leave_no_install(self):
        missing = dict(self.files)
        del missing['app-3.24.0/resources/app.asar']
        with self.assertRaises(ValueError):
            portable.install(self.archive(files=missing), self.drive)
        self.assert_clean()
        corrupt = dict(self.files)
        corrupt['QuarkCloudDrive.exe'] = b'MZdifferent'
        self.assertEqual(len(corrupt['QuarkCloudDrive.exe']), len(self.files['QuarkCloudDrive.exe']))
        with self.assertRaises(ValueError):
            portable.install(self.archive(files=corrupt), self.drive)
        self.assert_clean()

    def test_existing_directory_or_links_never_overwritten(self):
        target = self.drive / portable.DIRECTORY
        target.mkdir()
        (target / 'account').write_text('saved')
        with self.assertRaises(ValueError):
            portable.install(self.archive(), self.drive)
        self.assertEqual((target / 'account').read_text(), 'saved')
        (target / 'account').unlink()
        target.rmdir()
        target.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            portable.install(self.archive(), self.drive)
        self.assertFalse((self.root / 'QuarkCloudDrive.exe').exists())

    def test_existing_nested_link_rejected(self):
        exe = portable.install(self.archive(), self.drive)
        nested = exe.parent / 'app-3.24.0/resources/app.asar'
        nested.unlink()
        nested.symlink_to(self.root / 'outside')
        with self.assertRaises(ValueError):
            portable.check(self.drive)


if __name__ == '__main__':
    unittest.main()
