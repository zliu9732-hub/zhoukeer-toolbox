# UsbXbox360Dxe UEFI controller driver

- Upstream fork: https://github.com/jlobue10/UsbXbox360Dxe
- Original project: https://github.com/SkorionOS/UsbXbox360Dxe
- Bundled release: v1.8.0 standard build (`UsbXbox360Dxe.efi`)
- Release asset: https://github.com/jlobue10/UsbXbox360Dxe/releases/download/v1.8.0/UsbXbox360Dxe.efi
- SHA256: `9651e547d2842369e69776ce5fd51e5a2562268af91ca3ccfb80bf3f492d14a2`
- Size: 52,032 bytes
- License: BSD-2-Clause-Patent; see `UsbXbox360Dxe.LICENSE`

Renkit bundles the unmodified standard release binary and verifies its SHA256
before copying it into Clover. The driver exposes supported handheld controllers
as UEFI keyboard/pointer input for the boot menu. The maintained fork documents
support for ASUS ROG Ally-family DirectInput devices and Lenovo Legion Go-family
XInput devices, including Legion Go 2 changes in v1.8.0.
