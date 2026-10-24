# Offline packaging changes

Date: 2026-10-24. Local modifications licensed GPL-2.0-only, matching the upstream project.

- Added read-only compat.py gates for ASUS RC74XA, PCI audio identity, SteamOS 3.9.3, the exact prebuilt kernel and the two reported BIOS versions.
- Added Chinese instructions, provenance, manifests, entry scripts and an offline deployment wrapper with preflight checks and saved-file rollback.
- Cached all four TI firmware blobs, retaining their upstream hashes and licenses. Removed the install-time curl fallback; the upstream build command is disabled in this delivery.
- Kept the upstream built plugin frontend. Added compatibility checks before audio Apply and before enabling the QAM/wake watchers. The original release and source are retained unmodified in upstream/ for comparison.
- Included the official x86_64 Decky runtime and its tagged service template. Existing standard installations are reused. Offline first-time installation follows the official directory, CEF marker and service setup with local files.
- No new audio algorithm, controller mapping, rumble driver, brightness override or HDR/EDID override was invented. The scripts are delivery adaptations, not independently hardware-tested fixes.
