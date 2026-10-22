# 虚拟内存排查与验证

2026-10-22：用户反馈虚拟内存修改失败，未保留错误文字，因此不能判定当次失败的具体原因。旧有推荐值、配置与撤销测试通过，但没有覆盖完整的真实创建函数在 Btrfs 以及分配失败时的行为。

检查发现 `memory_create_swapfile` 原先直接 fallocate，再 chmod/mkswap，缺少 Btrfs 交换文件所需的 NOCOW 属性；分配失败时立即返回，也会遗留部分分配的临时文件。现在先通过 findmnt 识别目标父目录文件系统，只支持 ext4 与 Btrfs；在 root 权限下创建 0600 空文件，Btrfs 先设置 +C，再分配空间。准备失败清理新临时文件，不停用或移动旧虚拟内存。真实旧文件停用失败、新文件启用失败仍返回失败，并沿用原文件恢复流程。

依据：[Btrfs 官方 Swapfile 文档](https://btrfs.readthedocs.io/en/latest/Swapfile.html) 要求无空洞、NODATACOW 和无压缩，必须在分配前设置属性。多设备、快照等限制仍可能导致启用失败，不能保证每一种 Btrfs 布局可用，也不自动改动磁盘布局或其他文件属性。

`tests/test_memory_create.sh` 使用 tiny fixture 实际走完整创建函数，mock findmnt/分配/格式化/swapoff/swapon；仅对临时目录内小文件进行读写和移动，验证权限与顺序、分配/属性/格式化失败清理、旧文件停用失败保留、新文件启用失败恢复，以及未知格式/检测失败在停用旧文件前退出。`tests/test_memory_tuning.sh` 覆盖推荐容量、配置、备用文件；`tests/test_memory_restore.sh` 覆盖撤销和保留原文件。macOS 未执行真实 swap、管理员或磁盘操作，未获得用户掌机上的实际失败日志。
