"""
Ally Center - Decky Loader Plugin Backend
ROG Ally hardware control and system management

2025 Keith Baker / Pixel Addict Games
修补、汉化者：RenAmamiya
Licensed under MIT
"""

import os
import json
import subprocess
import asyncio
import threading
import time
import math
import tempfile
from pathlib import Path

import decky

# Hardware paths - these are specific to the ROG Ally running SteamOS
BATTERY_PATH = "/sys/class/power_supply/BAT0"
BACKLIGHT_PATH = "/sys/class/backlight/amdgpu_bl0"
DMI_PATH = "/sys/class/dmi/id"
ASUS_WMI_PATH = "/sys/devices/platform/asus-nb-wmi"
ALLY_LED_PATH = "/sys/class/leds/ally:rgb:joystick_rings"
FAN_CURVE_PATH = "/sys/devices/platform/asus-nb-wmi/fan_curve_enable"
PWM_PATH = "/sys/devices/platform/asus-nb-wmi/hwmon"
RYZENADJ_PATH = "/usr/bin/ryzenadj"
ALLY_CONTROLLER_PATH = "/sys/devices/platform/asus-nb-wmi"

# Preset power profiles with sensible defaults for the Z1 Extreme
PERFORMANCE_PROFILES = {
    "download": {
        "name": "Download",
        "tdp": 5,
        "gpu_clock": 800,
        "fan_curve": "quiet",
        "description": "Minimum power for downloads"
    },
    "silent": {
        "name": "Silent",
        "tdp": 15,
        "gpu_clock": 1200,
        "fan_curve": "quiet",
        "description": "Low power, minimal fan noise"
    },
    "performance": {
        "name": "Performance",
        "tdp": 25,
        "gpu_clock": 2200,
        "fan_curve": "balanced",
        "description": "Balanced performance and thermals"
    },
    "turbo": {
        "name": "Turbo",
        "tdp": 30,
        "gpu_clock": 2700,
        "fan_curve": "performance",
        "description": "Maximum performance"
    }
}


class FanCurveFullSpeed:
    """Own a temporary 100% dual-fan curve; never write ordinary asus pwm_enable.

    Only RC71L has been checked on hardware. The sysfs readback confirms the
    request/cache, while the UI separately reports measured RPM.
    """

    POINTS = tuple(f'pwm{fan}_auto_point{point}_{kind}' for fan in (1, 2)
                   for point in range(1, 9) for kind in ('temp', 'pwm'))
    TARGET = {f'pwm{fan}_auto_point{point}_{kind}': str(255 if kind == 'pwm' else temp)
              for fan in (1, 2) for point, temp in enumerate(range(20, 100, 10), 1)
              for kind in ('temp', 'pwm')}

    def __init__(self, settings_dir):
        self.directory = Path(settings_dir)
        self.marker = self.directory / 'fan-fullspeed-state.json'
        self.state = None
        self.active = False
        self.started = 0

    @staticmethod
    def locate(name):
        matches = []
        for path in (Path(ASUS_WMI_PATH) / 'hwmon').glob('hwmon*'):
            try:
                if ((path / 'name').read_text().strip() == name
                        and 'asus-nb-wmi' in path.resolve().parts):
                    matches.append(path)
            except OSError:
                continue
        if len(matches) != 1:
            raise RuntimeError(f'无法唯一定位 {name}')
        return matches[0]

    @classmethod
    def available(cls):
        try:
            board = (Path(DMI_PATH) / 'board_name').read_text().strip()
            if not board.startswith('RC71L'):
                return False
            curve, fans = cls.locate('asus_custom_fan_curve'), cls.locate('asus')
            required = (*cls.POINTS, 'pwm1_enable', 'pwm2_enable')
            return (all((curve / key).is_file() for key in required)
                    and all((fans / f'fan{i}_input').is_file() for i in (1, 2)))
        except (OSError, RuntimeError):
            return False

    @staticmethod
    def write_checked(path, value):
        path.write_text(str(value))
        if path.read_text().strip() != str(value):
            raise RuntimeError(f'回读失败：{path.name}')

    @staticmethod
    def save_json(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.fan-backup-', dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump(data, stream, ensure_ascii=False, indent=2)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
            directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def owns_control(self):
        return self.active or self.marker.exists()

    @classmethod
    def valid_state(cls, state):
        return (isinstance(state, dict) and state.get('schema') == 1
                and type(state.get('policy')) is int and state['policy'] in (0, 1, 2)
                and isinstance(state.get('points'), dict)
                and set(state['points']) == set(cls.POINTS)
                and all(isinstance(v, str) and v.isdecimal() and 0 <= int(v) <= 255
                        for v in state['points'].values()))

    def read_state(self):
        state = self.state
        if state is None:
            state = json.loads(self.marker.read_text())
        if not self.valid_state(state):
            raise RuntimeError('全速备份损坏，未读取其中的路径或执行其中的命令')
        return state

    def enable(self):
        if not self.available():
            raise RuntimeError('双风扇全速目前仅对具备完整曲线接口的 ROG Ally RC71L 开放')
        if self.owns_control():
            if self.active:
                self.check_running()
                return
            self.restore()
        curve, fans = self.locate('asus_custom_fan_curve'), self.locate('asus')
        policy_path = Path(ASUS_WMI_PATH) / 'throttle_thermal_policy'
        policy = policy_path.read_text().strip()
        if policy not in ('0', '1', '2'):
            raise RuntimeError('原厂档位未知，没有改动')
        if any((curve / f'pwm{i}_enable').read_text().strip() != '2' for i in (1, 2)):
            raise RuntimeError('其他自定义曲线已启用，请先退出其控制')
        state = {'schema': 1, 'policy': int(policy), 'time': time.time(),
                 'points': {key: (curve / key).read_text().strip() for key in self.POINTS},
                 'rpm_before': [int((fans / f'fan{i}_input').read_text()) for i in (1, 2)]}
        if not self.valid_state(state) or min(state['rpm_before']) < 0:
            raise RuntimeError('无法可靠备份传感器状态，没有改动')
        backup = self.directory / 'fan-backups' / f'fullspeed-{time.time_ns()}.json'
        self.save_json(backup, state)
        self.save_json(self.marker, state)
        self.state = state
        try:
            # Use the exact Balanced + 100% path checked on the RC71L test unit.
            self.write_checked(policy_path, 0)
            for key, value in self.TARGET.items():
                self.write_checked(curve / key, value)
            for i in (1, 2):
                self.write_checked(curve / f'pwm{i}_enable', 1)
            self.active = True
            self.started = time.time()
            self.check_running()
        except Exception as error:
            try:
                self.restore()
            except Exception as recovery:
                raise RuntimeError(f'全速失败；恢复未完全确认：{recovery}') from error
            raise RuntimeError(f'全速失败，已恢复原厂策略：{error}') from error

    def restore(self, policy_override=None):
        if not self.owns_control():
            return None
        state_error = None
        try:
            state = self.read_state()
        except (OSError, ValueError, RuntimeError) as error:
            state, state_error = None, error
        target = policy_override if policy_override is not None else (state['policy'] if state else 0)
        if type(target) is not int or target not in (0, 1, 2):
            raise RuntimeError('恢复档位无效')
        curve = self.locate('asus_custom_fan_curve')
        # Restore the firmware first. Never copy old low PWM values while the
        # hardware might still be using a custom curve.
        self.write_checked(Path(ASUS_WMI_PATH) / 'throttle_thermal_policy', target)
        if any((curve / f'pwm{i}_enable').read_text().strip() != '2' for i in (1, 2)):
            raise RuntimeError('没有确认两路自定义曲线已禁用，保留 100% 缓存和恢复标记')
        self.active = False
        if state is not None:
            for key in self.POINTS:
                self.write_checked(curve / key, state['points'][key])
        elif state_error:
            decky.logger.warning(f'已恢复原厂自动调速，未恢复损坏的曲线备份：{state_error}')
        self.marker.unlink(missing_ok=True)
        self.state = None
        return target

    def check_running(self):
        if not self.active:
            raise RuntimeError('全速请求未启用')
        curve, fans = self.locate('asus_custom_fan_curve'), self.locate('asus')
        if (Path(ASUS_WMI_PATH) / 'throttle_thermal_policy').read_text().strip() != '0':
            raise RuntimeError('原厂档位被其他程序改变')
        if any((curve / f'pwm{i}_enable').read_text().strip() != '1' for i in (1, 2)):
            raise RuntimeError('全速曲线被其他程序停用')
        if any((curve / key).read_text().strip() != value for key, value in self.TARGET.items()):
            raise RuntimeError('全速曲线被其他程序修改')
        rpm = [int((fans / f'fan{i}_input').read_text()) for i in (1, 2)]
        if min(rpm) < 0 or (time.time() - self.started > 15 and min(rpm) == 0):
            raise RuntimeError('风扇转速读取异常或停转')
        return rpm


class Plugin:
    settings_path: str = None
    settings: dict = {}
    screen_off: bool = False
    effect_thread: threading.Thread = None
    effect_running: bool = False

    async def _main(self):
        """Main entry point for the plugin"""
        self.settings_path = os.path.join(decky.DECKY_PLUGIN_SETTINGS_DIR, "settings.json")
        await self.load_settings()
        await self._recover_fan_startup()
        decky.logger.info("Ally Center initialized")

    async def _unload(self):
        """Cleanup when plugin is unloaded"""
        await self._stop_fan_control()
        # Stop any running effect
        self._stop_effect()
        # Restore screen if it was off
        if self.screen_off:
            await self.set_screen_state(True)
        decky.logger.info("Ally Center unloaded")

    async def _migration(self):
        """Handle plugin migrations"""
        pass

    async def load_settings(self):
        try:
            if os.path.exists(self.settings_path):
                with open(self.settings_path, 'r') as f:
                    self.settings = json.load(f)
            else:
                self.settings = {
                    "current_profile": "performance",
                    "rgb_enabled": True,
                    "rgb_color": "#FF0000",
                    "rgb_brightness": 100,
                    "rgb_effect": "static",
                    "charge_limit": 100
                }
                await self.save_settings()
        except Exception as e:
            decky.logger.error(f"Failed to load settings: {e}")
            self.settings = {}
        return self.settings

    async def save_settings(self):
        try:
            os.makedirs(os.path.dirname(self.settings_path), exist_ok=True)
            with open(self.settings_path, 'w') as f:
                json.dump(self.settings, f, indent=2)
        except Exception as e:
            decky.logger.error(f"Failed to save settings: {e}")

    async def get_settings(self) -> dict:
        return self.settings

    async def update_setting(self, key: str, value) -> bool:
        self.settings[key] = value
        await self.save_settings()
        return True

    async def get_device_info(self) -> dict:
        info = {
            "model": "Unknown",
            "bios_version": "Unknown",
            "serial": "Unknown",
            "cpu": "Unknown",
            "gpu": "Unknown",
            "kernel": "Unknown",
            "memory_total": "Unknown"
        }

        try:
            # Read DMI info
            dmi_files = {
                "model": "product_name",
                "bios_version": "bios_version",
                "serial": "product_serial"
            }

            for key, filename in dmi_files.items():
                filepath = os.path.join(DMI_PATH, filename)
                if os.path.exists(filepath):
                    with open(filepath, 'r') as f:
                        info[key] = f.read().strip()

            # Get CPU info
            if os.path.exists("/proc/cpuinfo"):
                with open("/proc/cpuinfo", 'r') as f:
                    for line in f:
                        if line.startswith("model name"):
                            info["cpu"] = line.split(":")[1].strip()
                            break

            # Get kernel version
            result = subprocess.run(["uname", "-r"], capture_output=True, text=True)
            if result.returncode == 0:
                info["kernel"] = result.stdout.strip()

            # Get memory info
            if os.path.exists("/proc/meminfo"):
                with open("/proc/meminfo", 'r') as f:
                    for line in f:
                        if line.startswith("MemTotal"):
                            mem_kb = int(line.split()[1])
                            info["memory_total"] = f"{mem_kb // 1024 // 1024} GB"
                            break

            # GPU info (AMD APU)
            info["gpu"] = "AMD Radeon 780M" if "Z1" in info.get("cpu", "") else "AMD Radeon Graphics"

        except Exception as e:
            decky.logger.error(f"Failed to get device info: {e}")

        return info

    async def get_battery_info(self) -> dict:
        battery = {
            "present": False,
            "status": "Unknown",
            "capacity": 0,
            "health": 100,
            "cycle_count": 0,
            "voltage": 0,
            "current": 0,
            "temperature": 0,
            "design_capacity": 0,
            "full_capacity": 0,
            "charge_limit": self.settings.get("charge_limit", 100),
            "time_to_empty": "Unknown",
            "time_to_full": "Unknown"
        }

        try:
            if not os.path.exists(BATTERY_PATH):
                return battery

            battery["present"] = True

            # Read battery files
            battery_files = {
                "status": "status",
                "capacity": "capacity",
                "cycle_count": "cycle_count",
                "voltage_now": "voltage_now",
                "current_now": "current_now",
                "energy_full_design": "energy_full_design",
                "energy_full": "energy_full"
            }

            for key, filename in battery_files.items():
                filepath = os.path.join(BATTERY_PATH, filename)
                if os.path.exists(filepath):
                    with open(filepath, 'r') as f:
                        value = f.read().strip()
                        if key == "status":
                            battery["status"] = value
                        elif key == "capacity":
                            battery["capacity"] = int(value)
                        elif key == "cycle_count":
                            battery["cycle_count"] = int(value)
                        elif key == "voltage_now":
                            battery["voltage"] = int(value) / 1000000  # Convert to V
                        elif key == "current_now":
                            battery["current"] = int(value) / 1000000  # Convert to A
                        elif key == "energy_full_design":
                            battery["design_capacity"] = int(value) / 1000000  # Convert to Wh
                        elif key == "energy_full":
                            battery["full_capacity"] = int(value) / 1000000  # Convert to Wh

            # Calculate health percentage
            if battery["design_capacity"] > 0:
                battery["health"] = round((battery["full_capacity"] / battery["design_capacity"]) * 100, 1)

            # Try to get temperature from ACPI
            temp_path = os.path.join(BATTERY_PATH, "temp")
            if os.path.exists(temp_path):
                with open(temp_path, 'r') as f:
                    battery["temperature"] = int(f.read().strip()) / 10  # Convert to Celsius

        except Exception as e:
            decky.logger.error(f"Failed to get battery info: {e}")

        return battery

    async def set_charge_limit(self, limit: int) -> bool:
        try:
            limit = max(60, min(100, limit))  # Clamp between 60-100%

            # Try ASUS WMI charge limit
            charge_limit_path = os.path.join(ASUS_WMI_PATH, "charge_control_end_threshold")
            if os.path.exists(charge_limit_path):
                with open(charge_limit_path, 'w') as f:
                    f.write(str(limit))

                self.settings["charge_limit"] = limit
                await self.save_settings()
                decky.logger.info(f"Set charge limit to {limit}%")
                return True
            else:
                decky.logger.warning("Charge limit control not available")
                return False

        except Exception as e:
            decky.logger.error(f"Failed to set charge limit: {e}")
            return False

    async def get_rgb_state(self) -> dict:
        return {
            "enabled": self.settings.get("rgb_enabled", True),
            "color": self.settings.get("rgb_color", "#FF0000"),
            "brightness": self.settings.get("rgb_brightness", 100),
            "effect": self.settings.get("rgb_effect", "static"),
            "speed": self.settings.get("rgb_speed", 50),
            "available": os.path.exists(ALLY_LED_PATH)
        }

    async def set_rgb_color(self, color: str) -> bool:
        try:
            self.settings["rgb_color"] = color
            await self.save_settings()
            await self._apply_rgb()
            return True
        except Exception as e:
            decky.logger.error(f"Failed to set RGB color: {e}")
            return False

    async def set_rgb_brightness(self, brightness: int) -> bool:
        try:
            brightness = max(0, min(100, brightness))
            self.settings["rgb_brightness"] = brightness
            await self.save_settings()
            await self._apply_rgb()
            return True
        except Exception as e:
            decky.logger.error(f"Failed to set RGB brightness: {e}")
            return False

    async def set_rgb_speed(self, speed: int) -> bool:
        try:
            speed = max(10, min(100, speed))
            self.settings["rgb_speed"] = speed
            await self.save_settings()
            # Restart effect if one is running to apply new speed
            effect = self.settings.get("rgb_effect", "static")
            if effect not in ["static", "off"]:
                await self._apply_rgb()
            decky.logger.info(f"Set RGB speed to {speed}%")
            return True
        except Exception as e:
            decky.logger.error(f"Failed to set RGB speed: {e}")
            return False

    async def set_rgb_effect(self, effect: str) -> bool:
        try:
            self.settings["rgb_effect"] = effect
            self.settings["rgb_enabled"] = effect != "off"
            await self.save_settings()
            await self._apply_rgb()
            return True
        except Exception as e:
            decky.logger.error(f"Failed to set RGB effect: {e}")
            return False

    async def set_rgb_enabled(self, enabled: bool) -> bool:
        try:
            self.settings["rgb_enabled"] = enabled
            await self.save_settings()
            await self._apply_rgb()
            # When RGB is disabled, enable MCU powersave to stop charging LED blink
            await self._set_mcu_powersave(not enabled)
            return True
        except Exception as e:
            decky.logger.error(f"Failed to toggle RGB: {e}")
            return False

    async def _set_mcu_powersave(self, enabled: bool) -> bool:
        """Enable/disable MCU powersave mode to control charging LED blink during sleep"""
        try:
            mcu_path = os.path.join(ASUS_WMI_PATH, "mcu_powersave")
            if os.path.exists(mcu_path):
                value = "1" if enabled else "0"
                with open(mcu_path, 'w') as f:
                    f.write(value)
                decky.logger.info(f"MCU powersave {'enabled' if enabled else 'disabled'}")
                return True
            else:
                decky.logger.warning("MCU powersave not available")
                return False
        except PermissionError:
            decky.logger.warning("Permission denied setting MCU powersave")
            return False
        except Exception as e:
            decky.logger.error(f"Failed to set MCU powersave: {e}")
            return False

    def _stop_effect(self):
        self.effect_running = False
        if self.effect_thread and self.effect_thread.is_alive():
            self.effect_thread.join(timeout=1.0)
        self.effect_thread = None

    def _set_led_color(self, r: int, g: int, b: int, brightness: int = 255):
        try:
            brightness_path = os.path.join(ALLY_LED_PATH, "brightness")
            multi_intensity_path = os.path.join(ALLY_LED_PATH, "multi_intensity")

            color_int = (r << 16) | (g << 8) | b

            if os.path.exists(multi_intensity_path):
                color_str = f"{color_int} {color_int} {color_int} {color_int}"
                with open(multi_intensity_path, 'w') as f:
                    f.write(color_str)

            if os.path.exists(brightness_path):
                with open(brightness_path, 'w') as f:
                    f.write(str(brightness))
        except Exception as e:
            pass  # Silently fail during animations

    def _set_led_zones(self, colors: list, brightness: int = 255):
        try:
            brightness_path = os.path.join(ALLY_LED_PATH, "brightness")
            multi_intensity_path = os.path.join(ALLY_LED_PATH, "multi_intensity")

            color_ints = []
            for r, g, b in colors:
                color_ints.append((r << 16) | (g << 8) | b)

            if os.path.exists(multi_intensity_path):
                color_str = " ".join(str(c) for c in color_ints)
                with open(multi_intensity_path, 'w') as f:
                    f.write(color_str)

            if os.path.exists(brightness_path):
                with open(brightness_path, 'w') as f:
                    f.write(str(brightness))
        except Exception as e:
            pass

    def _get_effect_delay(self) -> float:
        """Calculate delay based on speed setting (10-100). Higher speed = shorter delay."""
        speed = self.settings.get("rgb_speed", 50)
        # Map speed 10-100 to delay 0.15-0.01 seconds (inverted)
        return 0.15 - (speed - 10) * (0.14 / 90)

    def _effect_pulse(self):
        color = self.settings.get("rgb_color", "#FF0000").lstrip('#')
        r = int(color[0:2], 16)
        g = int(color[2:4], 16)
        b = int(color[4:6], 16)
        base_brightness = int(self.settings.get("rgb_brightness", 100) * 255 / 100)

        phase = 0.0
        while self.effect_running:
            delay = self._get_effect_delay()
            # Sine wave for smooth breathing (0 to 1)
            factor = (math.sin(phase) + 1) / 2
            brightness = int(base_brightness * (0.1 + 0.9 * factor))
            self._set_led_color(r, g, b, brightness)
            phase += 0.1
            time.sleep(delay)

    def _effect_spectrum(self):
        base_brightness = int(self.settings.get("rgb_brightness", 100) * 255 / 100)

        hue = 0
        while self.effect_running:
            delay = self._get_effect_delay()
            # HSV to RGB conversion
            h = hue / 360.0
            i = int(h * 6)
            f = h * 6 - i
            q = 1 - f
            t = f

            if i % 6 == 0: r, g, b = 1, t, 0
            elif i % 6 == 1: r, g, b = q, 1, 0
            elif i % 6 == 2: r, g, b = 0, 1, t
            elif i % 6 == 3: r, g, b = 0, q, 1
            elif i % 6 == 4: r, g, b = t, 0, 1
            else: r, g, b = 1, 0, q

            self._set_led_color(int(r * 255), int(g * 255), int(b * 255), base_brightness)
            hue = (hue + 2) % 360
            time.sleep(delay)

    def _effect_wave(self):
        base_brightness = int(self.settings.get("rgb_brightness", 100) * 255 / 100)

        offset = 0
        while self.effect_running:
            delay = self._get_effect_delay()
            colors = []
            for zone in range(4):
                hue = ((offset + zone * 90) % 360) / 360.0
                i = int(hue * 6)
                f = hue * 6 - i
                q = 1 - f
                t = f

                if i % 6 == 0: r, g, b = 1, t, 0
                elif i % 6 == 1: r, g, b = q, 1, 0
                elif i % 6 == 2: r, g, b = 0, 1, t
                elif i % 6 == 3: r, g, b = 0, q, 1
                elif i % 6 == 4: r, g, b = t, 0, 1
                else: r, g, b = 1, 0, q

                colors.append((int(r * 255), int(g * 255), int(b * 255)))

            self._set_led_zones(colors, base_brightness)
            offset = (offset + 3) % 360
            time.sleep(delay)

    def _effect_flash(self):
        color = self.settings.get("rgb_color", "#FF0000").lstrip('#')
        r = int(color[0:2], 16)
        g = int(color[2:4], 16)
        b = int(color[4:6], 16)
        base_brightness = int(self.settings.get("rgb_brightness", 100) * 255 / 100)

        on = True
        while self.effect_running:
            # Flash uses longer delay (3x normal) since it's on/off
            delay = self._get_effect_delay() * 3
            if on:
                self._set_led_color(r, g, b, base_brightness)
            else:
                self._set_led_color(0, 0, 0, 0)
            on = not on
            time.sleep(delay)

    def _effect_battery(self):
        """RGB color based on battery level - green (full) to red (empty)"""
        base_brightness = int(self.settings.get("rgb_brightness", 100) * 255 / 100)

        while self.effect_running:
            try:
                # Read battery capacity
                capacity = 50  # Default
                capacity_path = os.path.join(BATTERY_PATH, "capacity")
                if os.path.exists(capacity_path):
                    with open(capacity_path, 'r') as f:
                        capacity = int(f.read().strip())

                # Calculate color: green (100%) -> yellow (50%) -> red (0%)
                if capacity >= 50:
                    # Green to Yellow (100% -> 50%)
                    ratio = (capacity - 50) / 50.0
                    r = int(255 * (1 - ratio))
                    g = 255
                    b = 0
                else:
                    # Yellow to Red (50% -> 0%)
                    ratio = capacity / 50.0
                    r = 255
                    g = int(255 * ratio)
                    b = 0

                self._set_led_color(r, g, b, base_brightness)
                time.sleep(5)  # Update every 5 seconds

            except Exception as e:
                time.sleep(5)

    def _start_effect(self, effect: str):
        self._stop_effect()

        if effect == "static" or effect == "off":
            return  # No animation needed

        effect_map = {
            "pulse": self._effect_pulse,
            "spectrum": self._effect_spectrum,
            "wave": self._effect_wave,
            "flash": self._effect_flash,
            "battery": self._effect_battery,
        }

        effect_func = effect_map.get(effect)
        if effect_func:
            self.effect_running = True
            self.effect_thread = threading.Thread(target=effect_func, daemon=True)
            self.effect_thread.start()
            decky.logger.info(f"Started effect: {effect}")

    async def _apply_rgb(self):
        try:
            if not os.path.exists(ALLY_LED_PATH):
                decky.logger.warning("Ally LED path not found")
                return

            brightness_path = os.path.join(ALLY_LED_PATH, "brightness")

            if not self.settings.get("rgb_enabled", True):
                # Turn off RGB
                self._stop_effect()
                if os.path.exists(brightness_path):
                    with open(brightness_path, 'w') as f:
                        f.write("0")
                decky.logger.info("RGB disabled")
                return

            effect = self.settings.get("rgb_effect", "static")

            if effect == "off":
                self._stop_effect()
                if os.path.exists(brightness_path):
                    with open(brightness_path, 'w') as f:
                        f.write("0")
                return

            if effect == "static":
                # Static color - no animation
                self._stop_effect()
                color = self.settings.get("rgb_color", "#FF0000").lstrip('#')
                brightness = self.settings.get("rgb_brightness", 100)

                r = int(color[0:2], 16)
                g = int(color[2:4], 16)
                b = int(color[4:6], 16)
                hw_brightness = int(brightness * 255 / 100)

                self._set_led_color(r, g, b, hw_brightness)
                decky.logger.info(f"Set static RGB: #{color} @ {brightness}%")
            else:
                # Start animated effect
                self._start_effect(effect)

        except Exception as e:
            decky.logger.error(f"Failed to apply RGB settings: {e}")

    def _command_exists(self, cmd: str) -> bool:
        return subprocess.run(
            ["which", cmd],
            capture_output=True
        ).returncode == 0

    async def get_performance_profiles(self) -> dict:
        return {
            "profiles": PERFORMANCE_PROFILES,
            "current": self.settings.get("current_profile", "performance")
        }

    async def set_performance_profile(self, profile_id: str) -> bool:
        try:
            if profile_id not in PERFORMANCE_PROFILES:
                decky.logger.error(f"Unknown profile: {profile_id}")
                return False

            profile = PERFORMANCE_PROFILES[profile_id]
            tdp = profile["tdp"]
            fan_curve = profile.get("fan_curve", "balanced")

            await self.set_tdp(tdp)
            await self.set_fan_mode(fan_curve)

            self.settings["current_profile"] = profile_id
            self.settings["tdp_override"] = False
            await self.save_settings()

            decky.logger.info(f"Applied profile: {profile['name']} ({tdp}W, fan={fan_curve})")
            return True

        except Exception as e:
            decky.logger.error(f"Failed to set performance profile: {e}")
            return False

    async def get_current_tdp(self) -> dict:
        result = {
            "tdp": 0,
            "gpu_clock": 0,
            "cpu_temp": 0,
            "gpu_temp": 0
        }

        try:
            # Try to read from hwmon
            hwmon_base = "/sys/class/hwmon"
            if os.path.exists(hwmon_base):
                for hwmon in os.listdir(hwmon_base):
                    hwmon_path = os.path.join(hwmon_base, hwmon)
                    name_path = os.path.join(hwmon_path, "name")

                    if os.path.exists(name_path):
                        with open(name_path, 'r') as f:
                            name = f.read().strip()

                        # AMD CPU/APU temps
                        if name in ["k10temp", "zenpower"]:
                            temp_path = os.path.join(hwmon_path, "temp1_input")
                            if os.path.exists(temp_path):
                                with open(temp_path, 'r') as f:
                                    result["cpu_temp"] = int(f.read().strip()) / 1000

                        # AMD GPU temps
                        if name == "amdgpu":
                            temp_path = os.path.join(hwmon_path, "temp1_input")
                            if os.path.exists(temp_path):
                                with open(temp_path, 'r') as f:
                                    result["gpu_temp"] = int(f.read().strip()) / 1000

                            # GPU clock
                            freq_path = os.path.join(hwmon_path, "freq1_input")
                            if os.path.exists(freq_path):
                                with open(freq_path, 'r') as f:
                                    result["gpu_clock"] = int(f.read().strip()) / 1000000  # MHz

        except Exception as e:
            decky.logger.error(f"Failed to get TDP info: {e}")

        return result

    async def get_screen_state(self) -> dict:
        return {
            "screen_off": self.screen_off,
            "brightness": await self._get_brightness()
        }

    async def _get_brightness(self) -> int:
        try:
            # Find the backlight device
            if os.path.exists(BACKLIGHT_PATH):
                for device in os.listdir(BACKLIGHT_PATH):
                    device_path = os.path.join(BACKLIGHT_PATH, device)
                    brightness_path = os.path.join(device_path, "brightness")
                    max_path = os.path.join(device_path, "max_brightness")

                    if os.path.exists(brightness_path) and os.path.exists(max_path):
                        with open(brightness_path, 'r') as f:
                            current = int(f.read().strip())
                        with open(max_path, 'r') as f:
                            maximum = int(f.read().strip())

                        return int((current / maximum) * 100)
        except Exception as e:
            decky.logger.error(f"Failed to get brightness: {e}")

        return 100

    async def set_screen_state(self, on: bool) -> bool:
        try:
            brightness_file = os.path.join(BACKLIGHT_PATH, "brightness")
            max_file = os.path.join(BACKLIGHT_PATH, "max_brightness")

            if not os.path.exists(brightness_file):
                decky.logger.error(f"Backlight device not found at {brightness_file}")
                return False

            if on:
                # Restore brightness to saved value
                with open(max_file, 'r') as f:
                    max_brightness = int(f.read().strip())
                restore_value = self.settings.get("saved_brightness", max_brightness // 2)
                with open(brightness_file, 'w') as f:
                    f.write(str(restore_value))
                decky.logger.info(f"Screen restored to brightness {restore_value}")

                # Restore previous performance profile
                saved_profile = self.settings.get("saved_profile", "performance")
                await self.set_performance_profile(saved_profile)

                # Disable MCU powersave when exiting download mode (restore normal LED behavior)
                await self._set_mcu_powersave(False)

                self.screen_off = False
            else:
                # Save current brightness before turning off
                with open(brightness_file, 'r') as f:
                    current = int(f.read().strip())
                if current > 100:  # Only save if brightness is meaningful
                    self.settings["saved_brightness"] = current
                self.settings["saved_profile"] = self.settings.get("current_profile", "performance")
                await self.save_settings()
                decky.logger.info(f"Saved brightness: {current}, profile: {self.settings['saved_profile']}")

                # Set brightness to minimum
                with open(brightness_file, 'w') as f:
                    f.write("0")
                decky.logger.info("Screen brightness set to 0")

                # Set to download/5W profile
                await self.set_performance_profile("download")

                # Enable MCU powersave to disable charging LED blink during download mode
                await self._set_mcu_powersave(True)

                self.screen_off = True

            return True

        except Exception as e:
            decky.logger.error(f"Failed to set screen state: {e}")
            return False

    async def toggle_screen(self) -> bool:
        return await self.set_screen_state(self.screen_off)

    def _find_throttle_thermal_policy(self) -> str:
        """Find the throttle_thermal_policy sysfs path"""
        # Check direct path first
        direct_path = os.path.join(ASUS_WMI_PATH, "throttle_thermal_policy")
        if os.path.exists(direct_path):
            return direct_path

        # Check under hwmon
        hwmon_path = os.path.join(ASUS_WMI_PATH, "hwmon")
        if os.path.exists(hwmon_path):
            for hwmon in os.listdir(hwmon_path):
                policy_path = os.path.join(hwmon_path, hwmon, "throttle_thermal_policy")
                if os.path.exists(policy_path):
                    return policy_path

        # Check /sys/class/hwmon for asus-nb-wmi device
        hwmon_base = "/sys/class/hwmon"
        if os.path.exists(hwmon_base):
            for hwmon in os.listdir(hwmon_base):
                hwmon_dir = os.path.join(hwmon_base, hwmon)
                name_path = os.path.join(hwmon_dir, "name")
                if os.path.exists(name_path):
                    try:
                        with open(name_path, 'r') as f:
                            if "asus" in f.read().strip().lower():
                                policy_path = os.path.join(hwmon_dir, "throttle_thermal_policy")
                                if os.path.exists(policy_path):
                                    return policy_path
                    except:
                        pass

        return ""

    async def get_fan_info(self) -> dict:
        """Read actual firmware policy and both ASUS fan tachometers."""
        requested = self.settings.get("fan_mode", "auto")
        result = {
            "mode": requested,
            "requested_mode": requested,
            "speed": None,
            "speed2": None,
            "available": False,
            "policy_path": "",
            "current_policy": -1,
            "control_type": "firmware_profile",
        }
        policy_path = self._find_throttle_thermal_policy()
        if policy_path:
            result["policy_path"] = policy_path
            try:
                with open(policy_path, "r") as f:
                    policy = int(f.read().strip())
                result["current_policy"] = policy
                modes = {0: "balanced", 1: "performance", 2: "quiet"}
                if policy in modes:
                    result["available"] = True
                    result["mode"] = "auto" if policy == 0 and requested == "auto" else modes[policy]
            except (OSError, ValueError) as e:
                decky.logger.warning(f"Cannot read fan policy: {e}")

        # hwmon numbers change across boots; never select an unrelated fan.
        for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
            try:
                if (hwmon / "name").read_text().strip() != "asus":
                    continue
                if "asus-nb-wmi" not in hwmon.resolve().parts:
                    continue
            except OSError:
                continue
            for fan, key in ((1, "speed"), (2, "speed2")):
                try:
                    rpm = int((hwmon / f"fan{fan}_input").read_text().strip())
                    if rpm >= 0:
                        result[key] = rpm
                except (OSError, ValueError):
                    pass
            break
        controller = getattr(self, '_fan_controller', None)
        result['full_speed_available'] = FanCurveFullSpeed.available()
        result['full_speed_active'] = False
        result['error'] = getattr(self, '_fan_error', '')
        result['recovery_pending'] = bool(controller and controller.owns_control() and not controller.active)
        if controller and controller.active:
            try:
                controller.check_running()
                result.update(mode='full', full_speed_active=True,
                              requested_percent=100, control_type='custom_curve_full_speed')
            except Exception as error:
                result['error'] = str(error)
                result['recovery_pending'] = True
        return result

    def _init_fan_control(self):
        if not hasattr(self, '_fan_lock'):
            self._fan_lock = asyncio.Lock()
            self._fan_watch_task = None
            self._fan_error = ''
        if not hasattr(self, '_fan_controller'):
            directory = (Path(self.settings_path).parent if self.settings_path
                         else Path(decky.DECKY_PLUGIN_SETTINGS_DIR))
            self._fan_controller = FanCurveFullSpeed(directory)
        return self._fan_controller

    async def _recover_fan_startup(self):
        controller = self._init_fan_control()
        if controller.owns_control():
            try:
                controller.restore()
            except Exception as error:
                self._fan_error = f'上次全速恢复未完成：{error}'
                decky.logger.error(self._fan_error)
        # Full speed is deliberately never persisted or resumed on startup.
        if self.settings.get('fan_mode') == 'full':
            self.settings['fan_mode'] = 'auto'
            await self.save_settings()

    async def set_fan_mode(self, mode: str) -> bool:
        mode_map = {'auto': 0, 'balanced': 0, 'performance': 1, 'quiet': 2}
        if mode not in (*mode_map, 'full'):
            return False
        # Ordinary factory selection does not need to discover curve devices.
        if mode != 'full' and not hasattr(self, '_fan_controller'):
            return await self._set_factory_fan_mode(mode)
        controller = self._init_fan_control()
        async with self._fan_lock:
            try:
                if mode == 'full':
                    controller.enable()
                    if self._fan_watch_task is None or self._fan_watch_task.done():
                        self._fan_watch_task = asyncio.create_task(self._watch_full_speed())
                else:
                    if controller.owns_control():
                        controller.restore(mode_map[mode])
                    if not await self._set_factory_fan_mode(mode):
                        raise RuntimeError('原厂档位写入未确认')
                self._fan_error = ''
                return True
            except Exception as error:
                self._fan_error = str(error)
                decky.logger.error(f'风扇控制失败：{error}')
                return False

    async def _watch_full_speed(self):
        last_check = time.time()
        controller = self._fan_controller
        try:
            while controller.active:
                await asyncio.sleep(3)
                async with self._fan_lock:
                    if not controller.active:
                        return
                    try:
                        now = time.time()
                        # A wall-clock gap also catches suspend/resume. Do not
                        # reapply full speed after waking or fight other writers.
                        if now - last_check > 15 or now < last_check:
                            raise RuntimeError('检测到休眠或监控中断，退出全速')
                        last_check = now
                        controller.check_running()
                    except Exception as error:
                        self._fan_error = f'全速已中止：{error}'
                        try:
                            policy = (Path(ASUS_WMI_PATH) / 'throttle_thermal_policy').read_text().strip()
                            override = int(policy) if policy in ('1', '2') else None
                            controller.restore(override)
                            self._fan_error += '；已恢复原厂调速'
                        except Exception as recovery:
                            self._fan_error += f'；恢复未完全确认：{recovery}'
                        # Logging must not break the recovery path.  In
                        # particular, logging handlers may consult a clock
                        # that is unavailable while the system is resuming.
                        try:
                            decky.logger.error(self._fan_error)
                        except Exception:
                            pass
                        return
        except asyncio.CancelledError:
            raise

    async def _stop_fan_control(self):
        task = getattr(self, '_fan_watch_task', None)
        if task and not task.done():
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
        controller = getattr(self, '_fan_controller', None)
        if controller and controller.owns_control():
            async with self._fan_lock:
                try:
                    controller.restore()
                except Exception as error:
                    decky.logger.error(f'卸载时风扇恢复未完成，保留恢复标记：{error}')


    async def _set_factory_fan_mode(self, mode: str) -> bool:
        # Linux ASUS WMI ABI: 0=balanced, 1=performance, 2=quiet.
        # These are firmware thermal profiles, not custom PWM curves.
        # Keep Auto's existing meaning: factory automatic cooling in Balanced.
        mode_map = {"quiet": "2", "balanced": "0", "performance": "1", "auto": "0"}
        if mode not in mode_map:
            decky.logger.error(f"Unsupported fan mode: {mode}")
            return False
        policy_path = self._find_throttle_thermal_policy()
        if not policy_path:
            decky.logger.warning("Fan control unavailable: no ASUS thermal policy")
            return False

        previous = None
        wrote_policy = False
        try:
            with open(policy_path, "r") as f:
                previous = f.read().strip()
            if previous not in {"0", "1", "2"}:
                raise ValueError(f"Unknown thermal policy: {previous}")
            with open(policy_path, "w") as f:
                f.write(mode_map[mode])
            wrote_policy = True
            with open(policy_path, "r") as f:
                observed = f.read().strip()
            if observed != mode_map[mode]:
                raise RuntimeError(f"Thermal policy readback mismatch: {observed}")
        except Exception as e:
            decky.logger.error(f"Failed to apply fan mode: {e}")
            if wrote_policy and previous in {"0", "1", "2"}:
                try:
                    # Restore the preceding factory profile; never reactivate
                    # unknown or malformed custom fan curves on failure.
                    with open(policy_path, "w") as f:
                        f.write(previous)
                    with open(policy_path, "r") as f:
                        if f.read().strip() != previous:
                            raise RuntimeError("Factory profile recovery did not stick")
                except Exception as recovery_error:
                    decky.logger.error(f"Factory profile recovery failed: {recovery_error}")
            return False

        self.settings["fan_mode"] = mode
        await self.save_settings()
        decky.logger.info(f"Verified fan mode: {mode} (policy={observed}) via {policy_path}")
        return True

    async def get_fan_diagnostics(self) -> dict:
        """Get diagnostic info about fan control paths for debugging"""
        result = {
            "asus_wmi_exists": os.path.exists(ASUS_WMI_PATH),
            "throttle_policy_path": "",
            "throttle_policy_value": -1,
            "fan_boost_mode_path": "",
            "fan_boost_mode_value": -1,
            "fan_curve_enable_path": "",
            "available_files": []
        }

        try:
            # Check direct throttle_thermal_policy
            policy_path = os.path.join(ASUS_WMI_PATH, "throttle_thermal_policy")
            if os.path.exists(policy_path):
                result["throttle_policy_path"] = policy_path
                try:
                    with open(policy_path, 'r') as f:
                        result["throttle_policy_value"] = int(f.read().strip())
                except:
                    pass

            # Check fan_boost_mode (alternative on some models)
            boost_path = os.path.join(ASUS_WMI_PATH, "fan_boost_mode")
            if os.path.exists(boost_path):
                result["fan_boost_mode_path"] = boost_path
                try:
                    with open(boost_path, 'r') as f:
                        result["fan_boost_mode_value"] = int(f.read().strip())
                except:
                    pass

            # Check fan_curve_enable
            curve_path = os.path.join(ASUS_WMI_PATH, "fan_curve_enable")
            if os.path.exists(curve_path):
                result["fan_curve_enable_path"] = curve_path

            # List all files in asus-nb-wmi
            if os.path.exists(ASUS_WMI_PATH):
                result["available_files"] = os.listdir(ASUS_WMI_PATH)

            decky.logger.info(f"Fan diagnostics: {result}")
        except Exception as e:
            decky.logger.error(f"Fan diagnostics error: {e}")

        return result

    async def set_tdp_override(self, enabled: bool) -> bool:
        try:
            self.settings["tdp_override"] = enabled
            await self.save_settings()
            decky.logger.info(f"TDP override {'enabled' if enabled else 'disabled'}")
            return True
        except Exception as e:
            decky.logger.error(f"Failed to set TDP override: {e}")
            return False

    async def get_tdp_settings(self) -> dict:
        return {
            "tdp": self.settings.get("custom_tdp", 15),
            "min": 5,
            "max": 30,
            "tdp_override": self.settings.get("tdp_override", False),
            "use_external_tdp": self.settings.get("use_external_tdp", False),
            "available": os.path.exists(RYZENADJ_PATH) or os.path.exists("/sys/devices/platform/asus-nb-wmi")
        }

    async def set_use_external_tdp(self, enabled: bool) -> bool:
        """Enable/disable external TDP management (e.g., SimpleDeckyTDP)"""
        try:
            self.settings["use_external_tdp"] = enabled
            await self.save_settings()
            decky.logger.info(f"External TDP management {'enabled' if enabled else 'disabled'}")
            return True
        except Exception as e:
            decky.logger.error(f"Failed to set external TDP mode: {e}")
            return False

    async def set_tdp(self, tdp: int) -> bool:
        try:
            tdp = max(5, min(30, tdp))
            self.settings["custom_tdp"] = tdp
            await self.save_settings()

            tdp_set = False

            ppt_paths = [
                os.path.join(ASUS_WMI_PATH, "ppt_pl1_spl"),
                os.path.join(ASUS_WMI_PATH, "ppt_pl2_sppt"),
                os.path.join(ASUS_WMI_PATH, "ppt_apu_sppt"),
                os.path.join(ASUS_WMI_PATH, "ppt_fppt"),
            ]

            for ppt_path in ppt_paths:
                if os.path.exists(ppt_path):
                    try:
                        with open(ppt_path, 'w') as f:
                            f.write(str(tdp))
                        tdp_set = True
                    except PermissionError:
                        decky.logger.warning(f"Permission denied writing to {ppt_path}")

            if tdp_set:
                decky.logger.info(f"Set TDP to {tdp}W via ASUS WMI")
                return True

            if os.path.exists(RYZENADJ_PATH):
                tdp_mw = tdp * 1000
                subprocess.run(
                    [RYZENADJ_PATH, f"--stapm-limit={tdp_mw}", f"--fast-limit={tdp_mw}", f"--slow-limit={tdp_mw}"],
                    capture_output=True
                )
                decky.logger.info(f"Set TDP to {tdp}W via ryzenadj")
                return True

            decky.logger.warning("No TDP control method available")
            return False
        except Exception as e:
            decky.logger.error(f"Failed to set TDP: {e}")
            return False

    async def get_charge_limit(self) -> dict:
        return {
            "limit": self.settings.get("charge_limit", 100),
            "available": os.path.exists(os.path.join(ASUS_WMI_PATH, "charge_control_end_threshold"))
        }

    async def set_charge_limit(self, limit: int) -> bool:
        try:
            limit = max(60, min(100, limit))
            self.settings["charge_limit"] = limit
            await self.save_settings()

            # ASUS WMI charge limit
            charge_path = os.path.join(ASUS_WMI_PATH, "charge_control_end_threshold")
            if os.path.exists(charge_path):
                with open(charge_path, 'w') as f:
                    f.write(str(limit))
                decky.logger.info(f"Set charge limit to {limit}%")
                return True

            return True
        except Exception as e:
            decky.logger.error(f"Failed to set charge limit: {e}")
            return False


    async def set_brightness(self, brightness: int) -> bool:
        """Set screen brightness (0-100)"""
        try:
            brightness = max(0, min(100, brightness))

            if os.path.exists(BACKLIGHT_PATH):
                for device in os.listdir(BACKLIGHT_PATH):
                    device_path = os.path.join(BACKLIGHT_PATH, device)
                    brightness_path = os.path.join(device_path, "brightness")
                    max_path = os.path.join(device_path, "max_brightness")

                    if os.path.exists(brightness_path) and os.path.exists(max_path):
                        with open(max_path, 'r') as f:
                            maximum = int(f.read().strip())

                        hw_brightness = int((brightness / 100) * maximum)

                        with open(brightness_path, 'w') as f:
                            f.write(str(hw_brightness))

                        decky.logger.info(f"Set brightness to {brightness}%")
                        return True

            return False

        except Exception as e:
            decky.logger.error(f"Failed to set brightness: {e}")
            return False

    async def get_cpu_settings(self) -> dict:
        """Get current SMT and CPU boost settings"""
        smt_path = "/sys/devices/system/cpu/smt/control"
        boost_path = "/sys/devices/system/cpu/cpufreq/boost"

        result = {
            "smt_enabled": True,
            "smt_available": os.path.exists(smt_path),
            "boost_enabled": True,
            "boost_available": os.path.exists(boost_path)
        }

        try:
            if os.path.exists(smt_path):
                with open(smt_path, 'r') as f:
                    smt_state = f.read().strip()
                result["smt_enabled"] = smt_state == "on"

            if os.path.exists(boost_path):
                with open(boost_path, 'r') as f:
                    boost_state = f.read().strip()
                result["boost_enabled"] = boost_state == "1"
        except Exception as e:
            decky.logger.error(f"Failed to read CPU settings: {e}")

        return result

    async def set_smt_enabled(self, enabled: bool) -> bool:
        """Enable or disable Simultaneous Multi-Threading (SMT)"""
        try:
            smt_path = "/sys/devices/system/cpu/smt/control"

            if not os.path.exists(smt_path):
                decky.logger.warning("SMT control not available")
                return False

            value = "on" if enabled else "off"
            with open(smt_path, 'w') as f:
                f.write(value)

            self.settings["smt_enabled"] = enabled
            await self.save_settings()

            decky.logger.info(f"SMT {'enabled' if enabled else 'disabled'}")
            return True

        except PermissionError:
            decky.logger.error("Permission denied setting SMT - requires root")
            return False
        except Exception as e:
            decky.logger.error(f"Failed to set SMT: {e}")
            return False

    async def set_cpu_boost_enabled(self, enabled: bool) -> bool:
        """Enable or disable CPU boost"""
        try:
            boost_path = "/sys/devices/system/cpu/cpufreq/boost"

            if not os.path.exists(boost_path):
                decky.logger.warning("CPU boost control not available")
                return False

            value = "1" if enabled else "0"
            with open(boost_path, 'w') as f:
                f.write(value)

            self.settings["cpu_boost_enabled"] = enabled
            await self.save_settings()

            decky.logger.info(f"CPU boost {'enabled' if enabled else 'disabled'}")
            return True

        except PermissionError:
            decky.logger.error("Permission denied setting CPU boost - requires root")
            return False
        except Exception as e:
            decky.logger.error(f"Failed to set CPU boost: {e}")
            return False
