---
title: Manjaro + 微星 B365M 主板设置 Wake On Lan
date: 2020-12-29 12:00
updated:
category: [OS]
tags: [WOL, Manjaro]
index_img: ../img/cover_wake_on_lan.jpg
---

Wake On Lan，局域网唤醒主机。上学把台式电脑放家里面了，就想着用手机控制家里面的电脑，有时候在寝室睡觉（冬天）忘关电脑，就想了这样一个损招。

<!-- more -->

## 准备工作

- 在主板上设置 `网络唤醒，PCI 唤醒`（请查阅主板相关说明书）
- Manjaro 系统安装 `ethtool` 工具， 查看网卡是否支持 WOL

```bash
> sudo ethtool eno1
Supports Wake-on: pumbg
        Wake-on: g
```

## 启动 WOL

- 如果 Wake-on 参数是 d (disabled)，使用指令 `ethtool -s 网卡名称 wol g` 设置成 g (magic packet activity)

- 查看 tlp 服务，将 tlp 服务设置成开启自启

   - `sudo systemctl status tlp`
   - `sudo systemctl enable tlp`

- 更改 tlp 配置

```bash
> vim /etc/tlp.conf

TLP_ENABLE=1
WOL_DISABLE=N
```

## 无显示器设置 x11vnc 分辨率

没有显示器，只有主机也能操作

1. 安装 `xf86-video-dummy`

```bash
❯ sudo pacman -S dummy
```

2. 添加配置文件

```bash
❯ sudo vim /usr/share/X11/xorg.conf.d/xorg.conf

Section "Device"
    Identifier  "Configured Video Device"
    Driver      "dummy"
EndSection

Section "Monitor"
    Identifier  "Configured Monitor"
    HorizSync 31.5-48.5
    VertRefresh 50-70
EndSection

Section "Screen"
    Identifier  "Default Screen"
    Monitor     "Configured Monitor"
    Device      "Configured Video Device"
    DefaultDepth 24
    SubSection "Display"
    Depth 24
    Modes "1024x800"
    EndSubSection
EndSection
```

3. reboot
