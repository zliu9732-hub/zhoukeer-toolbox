"""All hardware and settings are disposable fixtures; never touch real sysfs."""
import asyncio
import importlib.util
import logging
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import AsyncMock, patch

sys.modules['decky'] = types.SimpleNamespace(logger=logging.getLogger('test'))
source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent/'ally-source/main.py'
sys.argv = sys.argv[:1]
spec = importlib.util.spec_from_file_location('ally_fullspeed', source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FullSpeedTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.base = self.root/'asus-nb-wmi'
        self.curve = self.base/'hwmon/hwmon31'
        self.fans = self.base/'hwmon/hwmon4'
        self.dmi = self.root/'dmi'
        for directory in (self.curve, self.fans, self.dmi):
            directory.mkdir(parents=True)
        (self.curve/'name').write_text('asus_custom_fan_curve')
        (self.fans/'name').write_text('asus')
        (self.dmi/'board_name').write_text('RC71L_RC71L')
        self.policy = self.base/'throttle_thermal_policy'
        self.policy.write_text('1')
        self.original = {key: '40' if key.endswith('temp') else '2' for key in module.FanCurveFullSpeed.POINTS}
        for key, value in self.original.items():
            (self.curve/key).write_text(value)
        for fan in (1, 2):
            (self.curve/f'pwm{fan}_enable').write_text('2')
            (self.fans/f'fan{fan}_input').write_text('4100')
        self.controller = module.FanCurveFullSpeed(self.root/'settings')
        self.writes = []
        self.fail_path = None
        self.fail_restore = False
        real_write = Path.write_text

        def kernel_write(path, data, *args, **kwargs):
            if path.is_relative_to(self.base):
                self.writes.append((path, str(data)))
                self.assertNotEqual(path.parent, self.fans, 'tachometer device must stay read-only')
                if path == self.fail_path:
                    self.fail_path = None
                    raise OSError('simulated firmware EIO')
                if self.fail_restore and path == self.policy:
                    raise OSError('simulated recovery EIO')
                if path == self.policy:
                    for fan in (1, 2):
                        real_write(self.curve/f'pwm{fan}_enable', '2')
                if path.name in module.FanCurveFullSpeed.POINTS:
                    real_write(self.curve/(path.name[:4]+'_enable'), '2')
                if path.name.endswith('_enable') and str(data) == '1':
                    self.assertTrue(all((self.curve/k).read_text() == v for k, v in module.FanCurveFullSpeed.TARGET.items()))
            return real_write(path, data, *args, **kwargs)

        for context in (patch.object(module, 'ASUS_WMI_PATH', str(self.base)),
                        patch.object(module, 'DMI_PATH', str(self.dmi)),
                        patch.object(Path, 'write_text', kernel_write)):
            context.start()
            self.addCleanup(context.stop)

    def assert_restored(self, policy='1'):
        self.assertEqual(self.policy.read_text(), policy)
        for fan in (1, 2):
            self.assertEqual((self.curve/f'pwm{fan}_enable').read_text(), '2')
        self.assertEqual({k: (self.curve/k).read_text() for k in self.original}, self.original)
        self.assertFalse(self.controller.marker.exists())

    def plugin(self):
        plugin = module.Plugin()
        plugin.settings_path = str(self.root/'settings/settings.json')
        plugin.settings = {'fan_mode': 'performance', 'custom_tdp': 30, 'rgb_color': '#FF0000'}
        plugin.save_settings = AsyncMock()
        plugin._init_fan_control()
        self.controller = plugin._fan_controller
        return plugin

    def test_full_request_and_restore_preserve_original_cache(self):
        self.controller.enable()
        self.assertEqual(self.controller.check_running(), [4100, 4100])
        self.assertEqual(self.policy.read_text(), '0')
        self.assertTrue(self.controller.marker.exists())
        self.assertEqual(len(list((self.root/'settings/fan-backups').glob('*.json'))), 1)
        self.controller.restore()
        self.assert_restored()

    def test_second_fan_enable_failure_restores_both(self):
        self.fail_path = self.curve/'pwm2_enable'
        with self.assertRaisesRegex(RuntimeError, '已恢复'):
            self.controller.enable()
        self.assert_restored()

    def test_backup_failure_has_no_hardware_writes(self):
        with patch.object(self.controller, 'save_json', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.controller.enable()
        self.assertEqual(self.writes, [])

    def test_recovery_failure_keeps_full_cache_and_marker(self):
        self.controller.enable()
        self.fail_restore = True
        with self.assertRaises(OSError):
            self.controller.restore()
        self.assertTrue(self.controller.marker.exists())
        self.assertEqual({k: (self.curve/k).read_text() for k in self.original}, self.controller.TARGET)

    def test_profile_readback_without_disabled_curves_does_not_restore_low_cache(self):
        self.controller.enable()
        with patch.object(self.controller, 'write_checked', return_value=None):
            with self.assertRaisesRegex(RuntimeError, '禁用'):
                self.controller.restore()
        self.assertEqual({k: (self.curve/k).read_text() for k in self.original}, self.controller.TARGET)
        self.assertTrue(self.controller.marker.exists())

    def test_restart_restores_without_reenabling_full(self):
        self.controller.enable()
        plugin = self.plugin()
        asyncio.run(plugin._recover_fan_startup())
        self.assert_restored()
        self.assertFalse(self.controller.active)

    def test_corrupt_marker_uses_auto_without_loading_bad_curve(self):
        self.controller.enable()
        self.controller.marker.write_text('{bad-json')
        self.controller = module.FanCurveFullSpeed(self.root/'settings')
        self.controller.restore()
        self.assertEqual(self.policy.read_text(), '0')
        self.assertEqual((self.curve/'pwm2_enable').read_text(), '2')
        self.assertFalse(self.controller.marker.exists())

    def test_other_controller_is_not_overwritten(self):
        with open(self.curve/'pwm2_enable', 'w') as stream:
            stream.write('1')
        self.writes.clear()
        with self.assertRaisesRegex(RuntimeError, '其他自定义'):
            self.controller.enable()
        self.assertEqual(self.writes, [])

    def test_untested_model_cannot_enable_full(self):
        (self.dmi/'board_name').write_text('RC72LA')
        with self.assertRaisesRegex(RuntimeError, '仅对'):
            self.controller.enable()
        self.assertEqual(self.writes, [])

    def test_changed_settings_and_zero_rpm_are_detected(self):
        self.controller.enable()
        self.policy.write_text('2')
        with self.assertRaisesRegex(RuntimeError, '其他程序'):
            self.controller.check_running()
        self.controller.restore()
        self.controller.enable()
        # Sensor changes represent firmware input, not plugin writes.
        with open(self.fans/'fan2_input', 'w') as stream:
            stream.write('0')
        self.controller.started -= 16
        with self.assertRaisesRegex(RuntimeError, '停转'):
            self.controller.check_running()

    def test_backend_full_not_saved_and_auto_restores(self):
        async def scenario():
            plugin = self.plugin()
            self.assertTrue(await plugin.set_fan_mode('full'))
            self.assertEqual(plugin.settings['fan_mode'], 'performance')
            self.assertEqual(plugin.settings['custom_tdp'], 30)
            self.assertEqual(plugin.settings['rgb_color'], '#FF0000')
            info = await plugin.get_fan_info()
            self.assertEqual(info['mode'], 'full')
            self.assertTrue(info['full_speed_active'])
            self.assertTrue(await plugin.set_fan_mode('auto'))
            self.assert_restored('0')
            await plugin._stop_fan_control()
        asyncio.run(scenario())

    def test_unload_restores(self):
        async def scenario():
            plugin = self.plugin()
            self.assertTrue(await plugin.set_fan_mode('full'))
            await plugin._stop_fan_control()
            self.assert_restored()
        asyncio.run(scenario())

    def test_watchdog_preserves_external_factory_selection(self):
        async def scenario():
            plugin = self.plugin()
            self.controller.enable()
            self.policy.write_text('2')
            with patch.object(module.asyncio, 'sleep', new=AsyncMock()):
                await plugin._watch_full_speed()
            self.assert_restored('2')
            self.assertIn('已恢复', plugin._fan_error)
        asyncio.run(scenario())

    def test_watchdog_gap_exits_without_reapplying(self):
        async def scenario():
            plugin = self.plugin()
            self.controller.enable()
            with patch.object(module.asyncio, 'sleep', new=AsyncMock()), patch.object(module.time, 'time', side_effect=[100, 200]):
                await plugin._watch_full_speed()
            self.assert_restored()
        asyncio.run(scenario())


if __name__ == '__main__':
    unittest.main()
