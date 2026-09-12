# Changelog

All notable changes to LeGo2 Brightness Fix, newest first.

## [2.0.0] - 2026-08-06

### Added

- A first-run display-mode chooser, with the selected mode changeable later under **Switch Display Mode**.
- **Hybrid** mode *(default and recommended)*. The panel uses gamma 2.2 for SDR and switches to PQ when a game presents HDR, preserving normal brightness control and black levels in SDR while retaining the full 1100-nit HDR peak. Brief SDR interruptions during loading are ignored so they do not cause an unnecessary second modeset.
- **PQ** mode for keeping the panel in its full-peak HDR transfer function at all times, with the same SDR brightness bridge provided by the 1.0 releases.
- **Gamma 2.2** mode for native hardware brightness control at all times, with HDR tone mapped to the panel's approximately 471-nit gamma ceiling.

### Changed

- The plugin no longer installs PQ as the only display configuration. The chosen mode now determines whether brightness is handled by the panel itself or forwarded to gamescope.
- Hybrid advertises HDR capability while the panel is in gamma 2.2, allowing games to enable HDR and trigger the automatic move into PQ.
- Switching between Hybrid and PQ takes effect immediately. Moving to or from Gamma 2.2 changes the gamescope display script and therefore requires a Game Mode restart.
- The EDID correction operates independently of the selected display mode, so games receive the panel's real HDR metadata in Hybrid, PQ and Gamma 2.2.
- Hybrid suspends internal-panel control while an external display is active and resumes it after returning to the built-in panel.
- Setup, mode changes and uninstall preserve any display script that existed before the plugin and restore the previous display state when control is released.

## [1.0.1] - 2026-07-28

### Fixed

- Brightness is put back when gamescope drops it. It forgets what the plugin wrote whenever it re-initialises, which it does across a suspend and a session restart, and the level stayed wrong until the slider was touched next.
- The brightness half no longer drives an external display. The backlight it reads belongs to the built-in panel while the setting applies to whatever gamescope is showing, so docking set a monitor's brightness from a slider that had nothing to do with it.
- Turning the plugin off puts the brightness back properly. A value the plugin had written itself could be mistaken for the one that was there beforehand, in which case "off" left the level exactly where "on" had put it.
- Uninstalling restores the EDID handed to games even if the plugin was reloaded in between. The bytes to put back are now kept on disk rather than only in memory, so the file is no longer left trimmed with nothing maintaining it.
- Restoring that EDID checks the file is the one that was patched, so docking cannot get this panel's data written over another display's.

### Changed

- The display gamescope is running on is found rather than assumed. Which X server it uses depends on how many it was told to start and what was already taken, so a fixed guess could silently do nothing on another setup.
- A session that restarts or moves is looked for again, instead of reading as unreachable until the plugin is reloaded.
- Both halves read everything they need in one query instead of two.

### Internal

- Backend tests up to 54 from 41, covering the new gate paths, the display search, and the EDID surviving a plugin reload.
- Update and download code stays shared with LeGo Vibe Control and Decky Vibrance HDR, so a fix to certificate handling, the download allowlist or the release check lands in all of them at once.

## 1.0.0

Initial release.

Two fixes for the Lenovo Legion Go 2 OLED under gamescope, both measured on the
device rather than inferred.

**The Steam brightness slider works again in HDR/PQ.** The panel is driven over
eDP AUX luminance control and ignores the backlight while in PQ, so Steam's
writes to `/sys/class/backlight/amdgpu_bl0` went nowhere. The requested level is
forwarded to gamescope's `GAMESCOPE_SDR_ON_HDR_CONTENT_BRIGHTNESS` instead —
both are expressed in the same unit, so the mapping is a plain divide by 1000 and
Steam's own perceptual step spacing carries over untouched.

Stands down whenever HDR content is on screen, where Steam already drives its own
gain atoms, and whenever the panel is not in PQ, where the backlight works by
itself.

**Games read the panel's real HDR metadata.** DXVK vendors libdisplay-info from
March 2023, whose `parse_ext()` ignores `errno` and therefore discards an entire
EDID when it meets a DisplayID 2.0 block it does not support. Games were being
handed DXVK's placeholders — 1499 nits peak, 799 full-frame, 0.01 black, DCI-P3
primaries — none of which describe this panel. Removing the DisplayID block from
the copy gamescope hands to Proton makes the rest parse, and games read
1107.128 / 475.683 / 0.0007 and the panel's own primaries.

**Setup.** The plugin installs the gamescope display script it needs and keeps
any existing one alongside as `.backup`. Until that is done the panel shows only
the setup button, and the background work stays off with it. Uninstalling puts
the previous script back.

**Cost.** No polling: the backlight class raises `sysfs_notify()` on every level
change, so the plugin blocks on that and the kernel wakes it exactly when the
slider moves. The only recurring work is one `xprop` call every two seconds, or
about 0.1% of one core.
