# MSI Claw 8 EX RT721 audio workaround

Upstream: https://github.com/lamb2k/msi-claw-8-ex-linux
(the user's https://github.com/stevedamnvan/msi-claw-8-ex-linux redirects here).

Pinned commit: `11909dbca067cdc8a14d77ec1a80909b1cda14dc`.
Files copied unchanged from `fixes/audio-rt721/`, plus the repository LICENSE.
Author: stevedamnvan and contributors. License: GPL-2.0-only.
The original nine files are verified against SHA256SUMS before building.

Renkit prepares a temporary copy with these explicit adaptations:

- Remove `LLVM=1` from the Makefile and use `gcc` instead of `clang` in PKGBUILD.
- Permit product `Claw 8 EX AI+ CG3EM Launch Pack` alongside the original CG3EM;
  keep the original `MS-1T91` board and exact RT721 SoundWire restrictions.
- Recalculate PKGBUILD SHA256 for all verified inputs, including the stale upstream
  README checksum; do not use `--skipinteg`.
- Set the output archive suffix so user makepkg settings cannot break its lookup.

Upstream tests CachyOS, not SteamOS. This is an experimental integration of the
user-provided SteamOS procedure, restricted to Neptune 7.2 with matching headers.
There is no physical-device audio, battery or Wayland validation on macOS.
