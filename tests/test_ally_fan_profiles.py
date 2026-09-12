import asyncio
import importlib.util
import io
import logging
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import AsyncMock, patch

sys.modules['decky'] = types.SimpleNamespace(logger=logging.getLogger('test'))
source = Path(sys.argv[1])
sys.argv = sys.argv[:1]
spec = importlib.util.spec_from_file_location('ally_repair', source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FanRepairTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.policy = self.root/'throttle_thermal_policy'
        self.policy.write_text('1')
        self.plugin = module.Plugin()
        self.plugin.settings = {'fan_mode': 'auto', 'custom_tdp': 30}
        self.plugin._find_throttle_thermal_policy = lambda: str(self.policy)
        self.plugin.save_settings = AsyncMock()

    def tearDown(self):
        self.tmp.cleanup()

    def test_linux_profile_semantics_and_unchanged_tdp(self):
        for mode, expected in [('quiet', '2'), ('balanced', '0'), ('performance', '1'), ('auto', '0')]:
            with self.subTest(mode=mode):
                self.assertTrue(asyncio.run(self.plugin.set_fan_mode(mode)))
                self.assertEqual(self.policy.read_text(), expected)
                self.assertEqual(self.plugin.settings['fan_mode'], mode)
                self.assertEqual(self.plugin.settings['custom_tdp'], 30)

    def test_unknown_mode_never_changes_hardware_or_saved_selection(self):
        self.assertFalse(asyncio.run(self.plugin.set_fan_mode('arbitrary')))
        self.assertEqual(self.policy.read_text(), '1')
        self.assertEqual(self.plugin.settings['fan_mode'], 'auto')
        self.plugin.save_settings.assert_not_called()

    def test_write_failure_does_not_persist_success(self):
        real_open = open
        def guarded(path, mode='r', *args, **kwargs):
            if path == str(self.policy) and mode == 'w':
                raise PermissionError('simulated')
            return real_open(path, mode, *args, **kwargs)
        with patch('builtins.open', guarded):
            self.assertFalse(asyncio.run(self.plugin.set_fan_mode('quiet')))
        self.assertEqual(self.policy.read_text(), '1')
        self.plugin.save_settings.assert_not_called()

    def test_readback_mismatch_restores_factory_profile(self):
        real_open = open
        reads = 0
        def changed_by_other_writer(path, mode='r', *args, **kwargs):
            nonlocal reads
            if path == str(self.policy) and mode == 'r':
                reads += 1
                if reads == 2:
                    return io.StringIO('2')
            return real_open(path, mode, *args, **kwargs)
        with patch('builtins.open', changed_by_other_writer):
            self.assertFalse(asyncio.run(self.plugin.set_fan_mode('balanced')))
        self.assertEqual(self.policy.read_text(), '1')
        self.plugin.save_settings.assert_not_called()

    def test_unknown_current_policy_is_not_overwritten(self):
        self.policy.write_text('99')
        self.assertFalse(asyncio.run(self.plugin.set_fan_mode('quiet')))
        self.assertEqual(self.policy.read_text(), '99')

    def test_dynamic_asus_tachometers_ignore_unrelated_hwmon(self):
        base = self.root/'hwmon'
        base.mkdir()
        unrelated = base/'hwmon0'
        unrelated.mkdir()
        (unrelated/'name').write_text('amdgpu')
        (unrelated/'fan1_input').write_text('999')
        target = self.root/'asus-nb-wmi/hwmon/hwmon27'
        target.mkdir(parents=True)
        (target/'name').write_text('asus')
        (target/'fan1_input').write_text('5300')
        (target/'fan2_input').write_text('4400')
        (base/'hwmon27').symlink_to(target, target_is_directory=True)
        with patch.object(module, 'Path', return_value=base):
            info = asyncio.run(self.plugin.get_fan_info())
        self.assertEqual(info['speed'], 5300)
        self.assertEqual(info['speed2'], 4400)
        self.assertEqual(info['mode'], 'performance')
        self.assertEqual(info['requested_mode'], 'auto')
        self.assertTrue(info['available'])


if __name__ == '__main__':
    unittest.main()
