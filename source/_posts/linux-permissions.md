---
title: Linux 权限控制系统
date: 2024-11-24 12:24:11
updated:
category: [Tech]
tags: [Linux]
mermaid:
index_img: ../img/cover-linux-permissions.jpg
---

Linux 除了 rwx 权限之外，还有哪些权限呢？

<!-- more -->

## Why

在开始介绍之前，先解释下为什么我会思考这个问题。

我写了一个 Golang 创建 ICMP 监听，代码如下：

```go
func (p *Pinger) connect() error {
 conn, err := icmp.ListenPacket("ip4:icmp", "0.0.0.0")
 if err != nil {
  return fmt.Errorf("error creating ICMP connection: %v", err)
 }
 p.conn = conn
 return nil
}
```

使用非 root 权限的用户运行时报错：error creating ICMP connection: listen ip4:icmp 0.0.0.0: socket: operation not permitted

这串代码其实是我在模拟 ping 的实现，在 Linux 里面，普通用户使用 ping 不会报错，为什么使用我的程序就会报错呢？查资料了解到 Linux 权限控制系统除了 rwx 之外，还存在一个 capabilities。

使用指令 `setcap cap_net_raw=eip my-program` 给程序加上运行创建 socket 的权限后，代码能够顺利运行。

## 传统的权限控制(UGO)

```BASH
➜ ~ ls -l
total 16
drwxr-xr-x 3 artibix artibix 4096 Nov 10 16:35 code/
drwxr-xr-x 8 artibix artibix 4096 Oct 14 18:22 github/
drwxr-xr-x 3 artibix artibix 4096 Oct 26 19:09 project/
drwxr-xr-x 4 artibix artibix 4096 Nov 11 09:46 tmp/
```

- 第一个字母代表文件类型：文件类型(-)、目录(d)、符号链接(l)、块设备(b)、字符设备(c)、管道(p)、套接字(s)
- 权限分为三组：用户(u)、组(g)、其他(o)
- 每组包含读(r=4)、写(w=2)、执行(x=1)权限
- chmod 命令修改权限：chmod 764 file

## 特殊权限位(Special Permissions)

- SUID (Set User ID)：当一个程序以 SUID 方式执行时，它的有效用户 ID 会临时变为文件所有者的 UID。这通常用于一些需要以特权用户身份运行的程序，如sudo。
- SGID (Set Group ID)：与 SUID 类似，当一个程序以 SGID 方式执行时，它的有效组 ID 会临时变为文件所有者的 GID。
- Sticky bit：这个权限位主要用于目录。当一个目录设置了sticky bit后，只有文件的所有者、超级用户和目录的所有者才能删除或重命名目录中的文件。这通常用于共享目录，以防止用户随意删除其他人的文件。
- 设置 SUID：`chmod u+s filename` 在文件所有者的 x 权限位上用 s 表示（如 x 变为 s）
- 设置 SGID：`chmod g+s dirname` 在组权限的 x 权限位上用 s 表示（如 x 变为 s ）
- 设置 Sticky bit：`chmod o+t dirname` 在组权限的 x 权限位上用 s 表示（如 x 变为 s）

示例：

```BASH
➜ ~ ls -l /usr/bin/sudo /usr/bin/passwd
-rwsr-xr-x 1 root root  80888 Jul  2 19:16 /usr/bin/passwd*
-rwsr-xr-x 1 root root 257168 Nov 13 15:17 /usr/bin/sudo*
```

这两个都设置了 SUID 权限，普通用户在执行 sudo 命令时，可以临时获得 root 权限。

{% note primary %}
当然，sudo 执行时会检查 /etc/sudoers 文件，允许的用户和用户组才能够执行 sudo，比如 wheel 用户组
{% endnote %}

## Capabilities

从 Linux 2.2 开始，创建了一种机制，用于细粒度地控制进程或程序的权限，这就是 Capabilities。它将传统的 root（超级用户）权限拆分为更小的能力集，使得程序可以只获取执行其任务所需的特定权限，而不是完整的 root 权限。

Capabilities 相关指令：

```BASH
# 查看当前进程的 Capabilities
capsh --print
# 查看文件当前的 capabilities
getcap /path/to/file
# 设置 capabilities
setcap cap_net_raw=eip /path/to/file
# 查看当前进程的 capabilities
getpcaps PID
# 查看详细文档(如果找不到可以先安装，sudo pacman -S man-pages)
man capabilities
```

![获取 ping 的 capabilities](../img/linux-permissions-getcap.jpg)

设置 Capabilities 需要指定赋予的 Capabilities 和其 sets。两者介绍如下：

### capabilities

- CAP_CHOWN - 允许修改文件的所有者
- CAP_DAC_OVERRIDE - 忽略文件的 DAC 访问限制
- CAP_DAC_READ_SEARCH - 忽略文件读及目录搜索的 DAC 访问限制
- CAP_FOWNER - 忽略文件权限检查
- CAP_FSETID - 允许设置文件的 setuid/setgid 位
- CAP_KILL - 允许发送信号给任意进程
- CAP_SETGID - 允许设置进程的组 ID
- CAP_SETUID - 允许设置进程的用户 ID
- CAP_SETPCAP - 允许修改进程的 capabilities
- CAP_LINUX_IMMUTABLE - 允许修改文件的不可变(immutable)和只追加(append-only)属性
- CAP_NET_BIND_SERVICE - 允许绑定小于 1024 的端口
- CAP_NET_BROADCAST - 允许网络广播和多播访问
- CAP_NET_ADMIN - 允许执行网络管理任务
- CAP_NET_RAW - 允许使用原始套接字
- CAP_IPC_LOCK - 允许锁定共享内存片段
- CAP_IPC_OWNER - 忽略 IPC 所有权检查
- CAP_SYS_MODULE - 允许加载和卸载内核模块
- CAP_SYS_RAWIO - 允许直接访问 I/O 端口
- CAP_SYS_CHROOT - 允许使用 chroot()
- CAP_SYS_PTRACE - 允许跟踪任何进程
- CAP_SYS_PACCT - 允许配置进程记账
- CAP_SYS_ADMIN - 允许执行系统管理操作
- CAP_SYS_BOOT - 允许重启系统
- CAP_SYS_NICE - 允许提升优先级和设置其他进程的优先级
- CAP_SYS_RESOURCE - 忽略资源限制
- CAP_SYS_TIME - 允许修改系统时钟
- CAP_SYS_TTY_CONFIG - 允许配置 TTY 设备
- CAP_MKNOD - 允许创建特殊文件
- CAP_LEASE - 允许修改文件锁的 FL_LEASE 标志
- CAP_AUDIT_WRITE - 允许向内核审计日志写入记录
- CAP_AUDIT_CONTROL - 允许配置审计子系统
- CAP_SETFCAP - 允许设置文件 capabilities
- CAP_MAC_OVERRIDE - 允许忽略 MAC（强制访问控制）
- CAP_MAC_ADMIN - 允许配置 MAC
- CAP_SYSLOG - 允许使用 syslog()
- CAP_WAKE_ALARM - 允许触发唤醒 alarm
- CAP_BLOCK_SUSPEND - 允许阻止系统挂起
- CAP_AUDIT_READ - 允许读取审计日志
- CAP_PERFMON - 允许使用性能监控单元(PMU)
- CAP_BPF - 允许创建 BPF 程序
- CAP_CHECKPOINT_RESTORE - 允许检查点和恢复操作

### Capability sets

在 Capabilities 的权限模型中，Permitted、Inheritable、Effective、Bounding 和 Ambient 是进程的能力集合，每个集合定义了进程在不同上下文下如何使用和限制其权限。前三个可以定义在可执行文件上面，也就是 eip 的缩写。

- Permitted Set：包含当前进程允许拥有的 Capabilities 集合。这是一个进程的核心权限集合，它定义了进程可能使用的能力范围。
- Effective Set：当前进程实际正在使用的 Capabilities 集合，Effective Set 是 Permitted Set 的一个子集，即使某个 Capabilities 在 Permitted Set 中，也需要显式激活后才会出现在 Effective Set 中。
- Inheritable Set：定义了哪些 Capabilities 可以从父进程继承到子进程。
- Bounding Set：定义了进程能够拥有的 Capabilities 上限，即便是 root 用户也无法超出此集合。
- Ambient Set：一个较新的 Capabilities 集合（引入于 Linux 4.3），用于在执行新程序时保留特定 Capabilities，而无需特殊文件权限或 execve 限制。

## SELinux

{% note primary %}
目前，AppArmor 为 Ubuntu、OpenSUSE、SUSE、Debian 默认的 LSM；SELinux 为 RHEL、Fedora、CentOS 默认的 LSM。ArchLinux 默认不使用 LSM，需要单独安装启用。
{% endnote %}

SELinux（Security-Enhanced Linux）是由美国国家安全局（NSA）开发并集成到 Linux 内核中的一个 强制访问控制（Mandatory Access Control, MAC） 系统。它是 Linux 系统中增强安全性的一个重要模块，能够通过策略对系统中的所有对象（文件、进程、网络等）进行精细的权限管理，超越传统的用户权限和文件权限机制。

### 强制访问控制 MAC

自主访问控制（Discretionary Access Control, DAC）

- 文件权限 (rwx) 和 owner。
- 任何拥有文件的用户都可以修改其权限或允许其他人访问。

强制访问控制（Mandatory Access Controls, MAC）

- 权限由系统管理员定义的安全策略决定，用户和程序无法任意修改。
- 即使用户具有 root 权限，也必须遵守 SELinux 策略。

### 安全上下文（Security Context）

每个对象（如文件、进程、设备、端口等）都被分配了一个安全上下文，通常由以下三部分组成：

```text
user:role:type
```

- **User（用户）**：SELinux 的安全用户（如 `system_u`、`user_u`）。
- **Role（角色）**：控制用户可以使用哪些类型的权限（如 `system_r`）。
- **Type（类型）**：核心部分，用于定义资源和进程的访问规则（如 `httpd_t` 或 `httpd_sys_content_t`）。

### 策略（Policy）

SELinux 的策略是访问控制规则的集合，定义了哪些操作被允许。例如：

- 哪些进程可以访问哪些文件。
- 哪些网络端口可以被绑定。

常见策略包括：

- **目标化（Targeted）**：保护指定的系统服务（默认策略，限制系统中关键进程）。
- **最小化（Minimal）**：只有最少的控制。
- **严格（Strict）**：对系统中的所有进程和对象实施全面控制。

### 模式（Modes）

SELinux 有三种运行模式：

- **Enforcing**（强制模式）：严格执行 SELinux 策略，拒绝不符合规则的访问。
- **Permissive**（宽容模式）：记录违规访问，但不实际阻止，用于调试和策略调整。
- **Disabled**（禁用模式）：完全关闭 SELinux 功能。

可以通过以下命令查看当前模式：

```bash
getenforce
```

更改模式：

```bash
sudo setenforce 0  # 切换到 Permissive
sudo setenforce 1  # 切换到 Enforcing
```

### 布尔值（Booleans）

SELinux 中的布尔值允许管理员动态调整策略的行为，而无需修改策略文件。例如：

- 允许或禁止 `httpd` 访问网络：

  ```bash
  sudo setsebool -P httpd_can_network_connect on
  ```

### 工作机制

1. **标签化（Labeling）**
   SELinux 为系统中所有对象分配安全上下文标签（Label），包括：
   - 文件：通过 `ls -Z` 查看：

     ```bash
     ls -Z /var/www/html/
     ```

     输出示例：

     ```
     drwxr-xr-x. root root system_u:object_r:httpd_sys_content_t:s0 index.html
     ```

   - 进程：通过 `ps -Z` 查看：

     ```bash
     ps -Z | grep httpd
     ```

2. **访问控制决策**
   - 每次访问（如读文件、绑定端口）都需要经过 SELinux 策略的检查。
   - SELinux 检查访问请求是否匹配允许规则，如果不匹配，则拒绝并记录日志。

3. **日志记录**
   - 所有被拒绝的操作都会记录到 `/var/log/audit/audit.log` 文件中，可以通过工具解析：

     ```bash
     ausearch -m avc
     ```

