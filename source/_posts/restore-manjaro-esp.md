---
title: 双系统恢复删除的 Linux ESP 分区
date: 2020-08-07 22:00
updated:
category: [OS]
tags: [Manjaro, Windows, ESP, UEFI]
index_img: ../img/cover_manjaro.jpg
---

旧文整理：Manjaro + Windows 双系统，在 Windows 上误删除了 Linux 的 ESP 分区，开机只识别到 Windows 的解决方法。

<!-- more -->

## 前言

我是 Manjaro + Widnwos 双系统，其他系统也可以试一试。一般这种情况我建议备份数据直接重装。不过嘛，在我不断折腾下还是找到了恢复 ESP 的方法。在此之前，先简单介绍下 ESP 这个东西。

## ESP

ESP 是 EFI System Partition 的缩写，即 EFI 系统分区。它是一个特殊的磁盘分区，主要用于支持 UEFI 固件的启动。

ESP 分区的格式一般是 FAT32，UEFI 通过读取 ESP 上的配置信息去加载 OS 的内核，从而启动操作系统。

## BIOS 和 UEFI 的区别

### 功能方面

| 区别 | 传统 BIOS | UEFI |
|---|---|---|
| 分区表 | 使用主引导记录 (MBR) | 使用全局唯一标识分区表 (GPT) |
| 存储位置 | 主板的 BIOS 芯片 | EFI |
| 运行模式 | 16 位 | 64 位 |
| 安全性 | 相对较低 | 支持安全启动 |
| 用户界面 | 只能键盘导航的简单界面 | 可以联网更新的复杂界面 |

### 启动流程

BIOS：自检 -> 查找启动设备（硬盘） -> 将 MBR 加载进内存 -> 启动操作系统

UEFI：初始化设备 -> 查找启动设备 -> 加载 EFI（在 ESP 里面）进内存 -> 启动操作系统

## 恢复分区

OK，介绍完毕，正事开干

### 制作 livecd (U 盘启动盘)

下载镜像

- [Manjaro 官网](https://manjaro.org/) 下载 iso 镜像文件

{% note primary %}
下载太慢可以去 [清华镜像站](https://mirrors.tuna.tsinghua.edu.cn/osdn/storage/g/m/ma/manjaro/) 下载
{% endnote %}

制作启动盘

- Windows，使用 [rufus](https://github.com/pbatard/rufus/tree/master/src) 工具向 U 盘写入镜像。

- Linux，使用 dd 指令。

```bash
# 示例
sudo dd if=manjaro.iso of=/dev/sdb bs=4M status=progress
```

- Android，使用 Termux 的 dd 指令。（没尝试过）

### 进入 livecd

将 U 盘插入需要修复的电脑，进入 BIOS，选择 U 盘启动，进入临时的 Manjaro 系统。

### 挂载 & chroot

打开终端输入以下指令自动挂载电脑上的 Manjaro 操作系统，自动 chroot.

```bash
sudo manjaro-chroot -a

## 正常情况等待提示输入 '1' 即可
```

{% note danger %}
注意，如果是格式化 esp 分区 (uuid 发生变化), 会导致格式化的分区不能自动挂载，有两种解决方案
1. 进入 chroot 后修改 /etc/fstab 修改格式化分区 uuid 后再次使用上述指令
2. 尝试手动挂载 linux 系统所在分区
{% endnote %}

因为我是格式化的 esp 分区，不能自动挂载上 efi 分区，我尝试的是手动挂载，下面是我我挂载的分区

```bash
/dev/nvme0n1p7  --> /mnt/Manjaro/
/dev/nvme0n1p6  --> /mnt/Manjaro/boot/
Restore_the_GRUB_Bootloader/dev/nvme0n1p8 --> /mnt/Manjaro/home/
/dev/nvme0n1p9  --> /mnt/Manjaro/boot/efi/
```

手动挂载还需要输入以下指令

```bash
sudo mount -t proc proc /mnt/proc
sudo mount -t sysfs sys /mnt/sys
sudo mount -o bind /dev/mnt/dev
sudo mount -t devpts pts /mnt/dev/pts/
sudo modprobe efivarfs
sudo chroot /mnt
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
```

{% note info %}
挂载好后别忘了 `sudo manjaro-chroot -a`
{% endnote %}

### 重装并更新 grub

```bash
sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=manjaro --recheck
sudo update-grub
# 提示 ' 未知的设备 nvme0n1' 不用管他
```

如果上述指令无误的话就可以重启了.

进入系统后再次输入 `update-grub`, grub 会识别到电脑的其他系统，开机才会出现 grub 多重引导.

{% note info %}
如果出现超时无法进入系统，注意修改 /etc/fstab 文件里面 ESP 的 UUID
{% endnote %}


## 参考文章

- [Restore_the_GRUB_Bootloader](https://wiki.manjaro.org/index.php?title=Restore_the_GRUB_Bootloader)

- [第十九章、开机流程、模组管理与 Loader](http://linux.vbird.org/linux_basic/0510osloader.php#process_1)