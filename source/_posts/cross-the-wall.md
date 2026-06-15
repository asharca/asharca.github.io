---
title: 科学上网跨平台详解：iOS / Android / Windows / macOS / Linux
category:
  - 网络
tags:
  - 科学上网
  - 代理
  - Clash
  - sing-box
  - VPN
date: 2026-06-15 14:20:00
updated:
mermaid:
index_img:
---


科学上网的本质是「把流量加密后转发给一台在墙外的服务器」。协议、客户端、平台三者排列组合让新手无从下手。本文从原理讲起，对比 Windows / macOS / Linux / Android / iOS 五大平台的主流客户端，并给出自建节点的完整流程。

<!--more -->

{% note warning %}
本文仅用于学习网络代理技术、访问学术与开发资源等正当用途。请遵守你所在地区的法律法规，并对自己的行为负责。
{% endnote %}

## 一、原理与术语

「翻墙」要解决的核心问题是：**让你的设备和一台位于审查范围之外的服务器（节点）之间建立一条审查者既看不懂、也不容易识别的通道。**

整个链路通常是：

```
你的设备 → 本地客户端(加密/伪装) → 墙 → 墙外节点(VPS/机场) → 目标网站
```

### 代理 vs VPN

很多人把两者混为一谈，其实区别很大：

| 维度 | 代理（Proxy） | VPN |
| --- | --- | --- |
| 工作层级 | 应用层 / SOCKS / HTTP | 网络层（虚拟网卡） |
| 分流能力 | 强，可按域名 / IP / 进程精细分流 | 弱，通常全局接管 |
| 抗封锁 | 协议可深度伪装（Reality、Hysteria2） | 特征明显，易被识别封锁 |
| 代表 | Shadowsocks、VLESS、Trojan | WireGuard、OpenVPN、IKEv2 |

> 在国内长期稳定使用，**代理类协议（尤其是 VLESS + Reality）比传统 VPN 协议更难被封**。WireGuard 速度快但握手特征明显，更适合自用小流量或配合中转。

### 常见协议一览

| 协议 | 传输 | 特点 | 现状 |
| --- | --- | --- | --- |
| Shadowsocks (SS) | TCP/UDP | 轻量、老牌 | 仍可用，建议配合插件 |
| VMess | TCP/WS/gRPC | V2Ray 早期主力 | 已逐渐被 VLESS 取代 |
| VLESS + Reality | TCP | **当前抗封锁最优解**，无需域名/证书，借用真实网站 TLS 指纹 | 主流推荐 |
| Trojan | TLS | 伪装成 HTTPS，需要域名+证书 | 稳定，需配证书 |
| Hysteria2 | QUIC/UDP | 基于 UDP，弱网/高丢包下速度快 | 推荐，注意 UDP QoS |
| TUIC | QUIC/UDP | 同样走 QUIC，低延迟 | 小众但好用 |
| WireGuard | UDP | 速度快、配置简单 | 易被识别，适合中转/自用 |
| Tor | 多跳 | 匿名性强、速度慢 | 仅适合特定匿名需求 |

{% note primary %}
**新手结论**：如果是自建，优先 **VLESS + Reality**（无需域名、抗封最强）或 **Hysteria2**（追求速度）；如果是买机场，客户端选 **Clash 系**（mihomo 内核）即可全协议通吃。
{% endnote %}

## 二、先决条件：你得先有一个「节点」

客户端只是「门」，真正翻墙靠的是墙外那台服务器。三种获取方式：

### 方案 A：购买机场订阅（最省心）

机场提供一条 **订阅链接（Subscription URL）**，里面包含一批节点。客户端导入订阅后自动更新节点列表。

- 优点：开箱即用、多地区节点、无需运维
- 缺点：共享 IP 易被封、隐私依赖商家、需甄别跑路风险
- 选择建议：优先支持 Clash / sing-box 订阅格式、有 Trojan/Hysteria2 节点、按流量计费的中大型机场

### 方案 B：自建 VPS（最自由，推荐进阶）

自己买一台海外 VPS，独享 IP，协议自己定。见第四节完整教程。

- 优点：独享、可控、隐私好、成本可低至每月一两美元
- 缺点：需要一点 Linux 基础；IP 被封需更换

### 方案 C：商业 VPN（最简单但最不灵活）

下载即用的 App（如各类付费 VPN）。适合完全不想折腾、且对稳定性要求不高的人。在国内封锁严重时段这类服务往往最先挂掉。

## 三、五大平台客户端对比

先看总览，再看每个平台的细节。

| 平台 | 首选客户端 | 内核 | 协议支持 | 备注 |
| --- | --- | --- | --- | --- |
| Windows | Clash Verge Rev | mihomo | 全 | GUI 友好，支持 TUN 全局 |
| Windows | v2rayN | Xray/sing-box | 全 | 老牌，节点手动管理强 |
| macOS | Clash Verge Rev | mihomo | 全 | 跨平台一致体验 |
| macOS | Surge（付费） | 自研 | 全 | 规则与排错能力最强 |
| Linux | Clash Verge Rev | mihomo | 全 | 有 GUI；服务器用 CLI |
| Linux | mihomo / sing-box CLI | - | 全 | 无头服务器/软路由 |
| Android | ClashMetaForAndroid | mihomo | 全 | 开源、免费 |
| Android | NekoBox / v2rayNG | sing-box/Xray | 全 | 手动节点党首选 |
| iOS | Shadowrocket（付费） | 自研 | 全 | 需**非中国区** Apple ID |
| iOS | sing-box / Stash | sing-box | 全 | 免费替代/规则强 |

下面分平台展开。

### 3.1 Windows

**推荐：Clash Verge Rev**（mihomo 内核，开源免费）

1. 从官方 GitHub Release 下载 `.exe` 安装。
2. 「订阅」页粘贴机场订阅链接，或导入自建节点。
3. 开启 **TUN 模式**（虚拟网卡）即可全局代理，包括不支持代理设置的程序。
4. 「设置」里开启「开机自启」和「系统代理」。

{% note info %}
**v2rayN** 更适合喜欢手动逐个管理节点、调试协议参数的用户，内置 Xray 与 sing-box 双内核切换。**NekoRay** 也曾是跨平台手动配置党的常用选择，但目前已停止维护，新用户建议优先 Clash Verge Rev 或 sing-box。
{% endnote %}

### 3.2 macOS

**推荐：Clash Verge Rev**（与 Windows 体验一致）

- Apple Silicon / Intel 都有对应安装包，首次打开需在「系统设置 → 隐私与安全性」放行。
- 同样支持 TUN 全局、规则分流、订阅自动更新。

**进阶：Surge（付费）**

- 规则系统、脚本、MitM、网络诊断能力是目前 macOS 上最强的，适合重度玩家与开发者。

**轻量：ClashX Meta** 曾经流行，但维护趋缓，新用户建议直接上 Clash Verge Rev。

### 3.3 Linux

桌面端和服务器端走法不同。

**桌面（GNOME/KDE）：Clash Verge Rev**

- 提供 `.deb` / `.rpm` / `.AppImage`。Arch 系可从 AUR 安装：

```bash
yay -S clash-verge-rev-bin
```

**无头服务器 / 软路由：mihomo 或 sing-box CLI**

以 mihomo 为例，下载二进制后用配置文件运行：

```bash
# 下载 mihomo（按架构选择 release）：https://github.com/MetaCubeX/mihomo/releases
sudo install mihomo /usr/local/bin/mihomo

# 配置目录
mkdir -p ~/.config/mihomo
# 把机场提供的 Clash 配置保存为 config.yaml

mihomo -d ~/.config/mihomo
```

配合 systemd 开机自启：

```ini
# /etc/systemd/system/mihomo.service
[Unit]
Description=mihomo proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now mihomo
```

然后让系统/其他设备把 `http://本机IP:7890` 设为代理即可。

### 3.4 Android

**推荐：ClashMetaForAndroid（CMFA）**（mihomo 内核，开源免费）

1. GitHub 下载 APK 安装。
2. 「配置」→ 新建 → URL，粘贴订阅链接。
3. 启动后系统会请求建立 VPN（其实是本地 TUN），授权即可全局。

**手动节点党：NekoBox（sing-box 内核）/ v2rayNG（Xray 内核）**

- 支持扫码导入单节点、二维码分享，调参灵活。
- **Surfboard** 是 Surge 风格的免费 Android 客户端，规则迁移方便。

### 3.5 iOS（最麻烦的平台）

iOS 的难点不在客户端，而在 **App Store 区域限制**：主流代理 App 在中国区下架，需要一个**非中国区（如美区）Apple ID** 才能下载。

| App | 价格 | 内核 | 说明 |
| --- | --- | --- | --- |
| Shadowrocket（小火箭） | 付费 | 自研 | 最经典，协议全、轻量 |
| Stash | 付费 | sing-box | Clash 风格规则，体验好 |
| Quantumult X | 付费 | 自研 | 重度玩家，脚本能力强 |
| sing-box（商店名 sing-box VT） | 免费 | sing-box | 官方出品，开源免费 |
| Streisand | 免费 | sing-box | 免费替代，协议齐全 |

操作流程：

1. 注册一个美区 Apple ID（地址填美国、无需绑卡）。
2. App Store 切换到该账号，搜索并下载上述 App。
3. 打开 App → 导入订阅 / 扫码导入节点 → 连接（首次需允许「添加 VPN 配置」）。

{% note warning %}
不要在 iOS 设置里手动配 HTTP 代理来翻墙——很多 App 不走系统代理。务必用上面这些基于 NEPacketTunnel 的客户端做全局 TUN。
{% endnote %}

### 3.6 客户端下载地址（请认准官方源）

第三方下载站常夹带篡改后门，务必从下面的官方仓库 / App Store 获取。

| 平台 | 客户端 | 价格 | 下载地址 |
| --- | --- | --- | --- |
| Windows | Clash Verge Rev | 免费 | [GitHub Release](https://github.com/clash-verge-rev/clash-verge-rev/releases) |
| Windows | v2rayN | 免费 | [GitHub Release](https://github.com/2dust/v2rayN/releases) |
| Windows/Linux | NekoRay（已停更） | 免费 | [GitHub Release](https://github.com/MatsuriDayo/nekoray/releases) |
| macOS | Clash Verge Rev | 免费 | [GitHub Release](https://github.com/clash-verge-rev/clash-verge-rev/releases) |
| macOS | ClashX Meta | 免费 | [GitHub Release](https://github.com/MetaCubeX/ClashX.Meta/releases) |
| macOS | Surge 5 | 付费 | [官网 nssurge.com](https://nssurge.com/) |
| Linux | Clash Verge Rev | 免费 | [GitHub Release](https://github.com/clash-verge-rev/clash-verge-rev/releases) |
| Linux（CLI） | mihomo | 免费 | [GitHub Release](https://github.com/MetaCubeX/mihomo/releases) |
| Linux（CLI） | sing-box | 免费 | [GitHub Release](https://github.com/SagerNet/sing-box/releases) |
| Android | ClashMetaForAndroid | 免费 | [GitHub Release](https://github.com/MetaCubeX/ClashMetaForAndroid/releases) |
| Android | NekoBox for Android | 免费 | [GitHub Release](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases) |
| Android | v2rayNG | 免费 | [GitHub Release](https://github.com/2dust/v2rayNG/releases) |
| Android | Surfboard | 免费 | [GitHub Release](https://github.com/getsurfboard/surfboard/releases) |
| iOS | Shadowrocket | 付费 | [App Store](https://apps.apple.com/us/app/shadowrocket/id932747118) |
| iOS | Stash | 付费 | [App Store](https://apps.apple.com/us/app/stash-rule-based-proxy/id1596063349) |
| iOS | Quantumult X | 付费 | [App Store](https://apps.apple.com/us/app/quantumult-x/id1443988620) |
| iOS | sing-box VT | 免费 | [App Store](https://apps.apple.com/us/app/sing-box-vt/id6673731168) |
| iOS | Streisand | 免费 | [App Store](https://apps.apple.com/us/app/streisand/id6450534064) |
| iOS | Surge 5 | 付费 | [App Store](https://apps.apple.com/us/app/surge-5/id1442620678) |

{% note info %}
iOS 应用均需**非中国区 Apple ID**（中国区已下架）。官方 sing-box 旧版曾被下架，现在 App Store 上的官方版本叫 **sing-box VT**。
{% endnote %}

## 四、进阶：自建 VLESS + Reality 节点

这是目前**性价比与抗封锁兼顾**的方案。以一台海外 VPS（Debian/Ubuntu）为例。

### 4.1 买 VPS 与基础加固

- 选择延迟低、被封概率低的机房（不同地区差异大，可多对比）。
- 登录后先更新并配置防火墙、关闭 root 密码登录（改用密钥）。

### 4.2 用 3x-ui 面板一键搭建（适合新手）

3x-ui 是带 Web 面板的 Xray 管理工具，可视化创建 VLESS+Reality 节点：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```

安装后访问 `http://VPS_IP:面板端口`，在面板里：

1. 新建入站 → 协议选 **VLESS**。
2. 安全选 **Reality**，「目标网站（dest）」填一个真实存在、支持 TLS1.3 的境外大站（借用它的握手指纹）。
3. 生成 `publicKey` / `shortId`，保存。
4. 面板会给出节点链接 / 二维码，导入任意客户端即可。

### 4.3 用 sing-box 手动搭建（更干净）

不想要面板可以直接用 sing-box 服务端。核心配置（节选）：

```json
{
  "inbounds": [{
    "type": "vless",
    "listen": "::",
    "listen_port": 443,
    "users": [{ "uuid": "粘贴你生成的UUID", "flow": "xtls-rprx-vision" }],
    "tls": {
      "enabled": true,
      "server_name": "www.example-bigsite.com",
      "reality": {
        "enabled": true,
        "handshake": { "server": "www.example-bigsite.com", "server_port": 443 },
        "private_key": "服务端私钥",
        "short_id": ["生成的shortId"]
      }
    }
  }]
}
```

```bash
# 生成 UUID 与 Reality 密钥对
sing-box generate uuid
sing-box generate reality-keypair
# 运行
sing-box run -c /etc/sing-box/config.json
```

客户端用对应的 `uuid` / `publicKey` / `server_name` / `short_id` 填好即可连上。

{% note primary %}
追求速度可改用 **Hysteria2**：基于 QUIC，弱网/跨境高丢包时表现明显优于 TCP 协议。注意有些机房对 UDP 有 QoS 限速，需实测。
{% endnote %}

## 五、分流规则：别让所有流量都绕一圈

国内网站走代理既慢又浪费，正确做法是 **按规则分流**：国内直连、国外走代理、广告拦截。

Clash 系客户端通常用「规则模式 + 规则集（rule-provider）」实现：

```yaml
rules:
  - GEOIP,CN,DIRECT          # 国内 IP 直连
  - DOMAIN-SUFFIX,cn,DIRECT  # .cn 域名直连
  - MATCH,PROXY              # 其余走代理
```

机场订阅通常已内置成熟规则集（如 GeoIP/GeoSite 规则），开箱即用。自建则可引入社区维护的规则集。

## 六、常见问题排查

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| 连上但打不开网站 | DNS 污染 | 客户端开启 fake-ip / DoH，DNS 用境外解析 |
| 全部节点超时 | 节点 IP 被封 | 更换节点/机房；自建则换 IP |
| 时通时断 | 协议特征被识别/限速 | 换 Reality 或 Hysteria2 |
| 国内网站也变慢 | 没做分流，全局代理 | 切换规则模式、加 GEOIP,CN,DIRECT |
| iOS 连不上 | App 不走系统代理 | 用 TUN 类客户端，别手动设 HTTP 代理 |
| UDP 游戏/通话异常 | 协议不支持 UDP 或被 QoS | 选支持 UDP 的协议（Hysteria2/TUIC） |

## 七、安全与隐私

- **机场即中间人**：你的明文流量在节点处解密，选商家等于选信任对象，敏感操作仍要靠 HTTPS/端到端加密。
- **自建更可信**，但 VPS 商家依然能看到流量元数据；真正匿名需求请用 Tor。
- 不要在公共/不信任的代理上登录重要账号、做转账等操作。
- 定期更换 UUID / 密码，开启服务器防火墙，最小化对外暴露端口。

## 参考

- [mihomo（Clash.Meta）文档](https://wiki.metacubex.one/)
- [sing-box 官方文档](https://sing-box.sagernet.org/)
- [Xray-core / Project X 文档](https://xtls.github.io/)
- [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev)
- [3x-ui 面板](https://github.com/MHSanaei/3x-ui)
