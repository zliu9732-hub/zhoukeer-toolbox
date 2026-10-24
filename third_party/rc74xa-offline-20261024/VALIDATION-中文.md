# 实际验证记录

日期：2026-10-24。全部验证均在当前 Windows 工作目录进行；安装脚本未执行，未修改当前电脑驱动、服务或引导。

完成：下载文件与上游 SHA-256 对照、二进制格式/架构/内核字符串检查、全部部署脚本语法检查、模拟设备与版本拦截、模拟文件备份恢复、纯函数 QAM 与唤醒行为检查。

未执行：Linux systemd/GRUB 真实安装或卸载、完整上游 Linux mount-namespace/FIFO 测试、RC74XA 硬件听音/录音/按键/休眠测试。自制部署流程尚未经目标机实测。

```text
PASS Verified RC74XA BIOS .303 accepted
PASS Verified BIOS .301 accepted
PASS Reject unsupported system=Windows
PASS Reject unsupported arch=aarch64
PASS Reject unsupported device=ROG Xbox Ally X RC73XA
PASS Reject unsupported bios=RC74XA.999
PASS Reject unsupported vendor=LENOVO
PASS Reject unsupported kernel=7.2.9-valve1
PASS Reject unsupported acp=[('0x1043', '0x1234')]
PASS Reject ID=bazzite
PASS Reject VERSION_ID=3.9.4
PASS Reject VERSION_ID=3.8.28
PASS Hardware-only recovery gate permits a changed kernel
PASS Reads EFI supplier 0 and PCI identity from fixture
PASS Reads EFI supplier 1 and PCI identity from fixture
PASS Shell syntax check.sh
PASS Shell syntax install.sh
PASS Shell syntax uninstall.sh
PASS Shell syntax payload/x20-fixes/fix/ally-audio-fix.sh
PASS Python syntax installer.py
PASS Python syntax payload/x20-fixes/compat.py
PASS Python syntax payload/x20-fixes/main.py
PASS Python syntax payload/x20-fixes/py_modules/qam_button.py
PASS Python syntax payload/x20-fixes/py_modules/wake_fix.py
PASS Module is x86_64 ELF64
PASS Module embeds exact target kernel vermagic string
PASS Module matches upstream SHA256SUMS
PASS Decky is Linux x86_64 ELF
PASS Audio direct install gate resolves to deployed compat.py
PASS Unverified module rebuild entry disabled
PASS Audio install firmware path cannot download
PASS Snapshot/restore preserves existing files and removes new file in mock directory
PASS Does not remap old-model A6 QAM report
PASS X20 A0 report triggers QAM callback
PASS QAM release is ignored
PASS Resume targets open SoundWire output only
PASS Resume resends current mode in mock sysfs
```
