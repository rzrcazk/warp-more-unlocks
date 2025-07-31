# 【WARP】连接CF WARP为服务器添加IPv4/IPv6网络并智能解锁流媒体

* * *

## 目录

- [【WARP】连接CF WARP为服务器添加IPv4/IPv6网络并智能解锁流媒体](#warp连接cf-warp为服务器添加ipv4ipv6网络并智能解锁流媒体)
  - [目录](#目录)
  - [脚本特点](#脚本特点)
  - [运行脚本](#运行脚本)
  - [主要功能说明](#主要功能说明)
  - [原作者](#原作者)
  - [自动化定时更换 IP](#自动化定时更换-ip)
    - [一键部署命令](#一键部署命令)
    - [命令详解](#命令详解)

* * *

## 脚本特点

*   **智能解锁增强**: `warp i` 功能经过魔改，可以交互式选择多种流媒体服务（Netflix, Disney+, ChatGPT 等）进行测试，并自动更换 IP 直至找到满足所有选定服务的完美 IP。
*   **多模式支持**: 全面支持 WARP Interface, WARP Linux Client (Proxy 和 Warp 模式), 以及 WireProxy 模式。
*   **智能判断**: 自动检测操作系统、硬件架构和网络环境，优选最佳配置方案。
*   **账户支持**: 支持免费、WARP+ 及 Teams 账户。
*   **简单易用**: 友好的菜单界面与强大的命令行参数相结合，满足不同用户需求。

## 运行脚本

**首次运行:**
```bash
wget -N https://raw.githubusercontent.com/ccxkai233/warp-more-unlocks/main/menu.sh && bash menu.sh
```

**再次运行:**
```bash
warp
```
*（首次运行后会自动创建 `warp` 快捷命令）*

## 主要功能说明

| 命令 (`warp [option]`) | 功能描述 |
| ---------------------- | ------------------------------------------------------------ |
| `i`                    | **智能更换解锁 IP**：交互式选择一个或多个流媒体服务，脚本将自动更换 IP 并进行测试，直到找到一个能解锁所有选定服务的 IP 地址。 |
| `4` / `6` / `d`        | 添加 WARP IPv4 / IPv6 / 双栈网络接口。 |
| `o`                    | 临时开启或关闭 WARP 网络接口。 |
| `c` / `l`              | 安装 WARP Linux Client，并设置为 Socks5 代理模式 (`c`) 或 WARP 网络接口模式 (`l`)。 |
| `r`                    | 启动或停止 WARP Linux Client。 |
| `w`                    | 安装 WireProxy 解决方案，将 WARP 作为 Socks5 代理。 |
| `y`                    | 启动或停止 WireProxy 服务。 |
| `a`                    | 变更账户类型（免费, WARP+, Teams）。 |
| `u`                    | 完全卸载脚本和相关组件。 |
| `v`                    | 同步脚本至最新版本。 |
| `h`                    | 显示帮助菜单。 |

* * *

## 原作者

*   **原版 WARP 脚本**: [fscarmen/warp](https://gitlab.com/fscarmen/warp/)
*   **IP 质量检测**: [xykt/IPQuality](https://github.com/xykt/IPQuality)

* * *

## 自动化定时更换 IP

为了实现无人值守自动更换 IP，项目提供了一个 `expect` 脚本 (`autowarp.exp`)，它可以模拟用户交互，自动完成 `warp i` 的所有操作。

### 一键部署命令

在您的 VPS 上，使用 root 权限运行以下单行命令，即可完成自动化部署：

```bash
(command -v apt-get &gt;/dev/null &amp;&amp; sudo apt-get update &amp;&amp; sudo apt-get install -y expect || sudo yum install -y expect) &amp;&amp; \
sudo wget -O /usr/local/sbin/autowarp.exp https://raw.githubusercontent.com/ccxkai233/warp-more-unlocks/main/autowarp.exp &amp;&amp; \
sudo chmod +x /usr/local/sbin/autowarp.exp &amp;&amp; \
(crontab -l 2&gt;/dev/null | grep -v -F "/usr/local/sbin/autowarp.exp" ; echo "0 20 * * * /usr/bin/expect /usr/local/sbin/autowarp.exp &gt; /tmp/autowarp.log 2&gt;&amp;1") | sudo crontab -
```

### 命令详解

这条命令会自动执行以下操作：

1.  **安装 `expect`**：自动检测并安装 `expect` 依赖。
2.  **下载脚本**：从本 GitHub 仓库下载 `autowarp.exp` 脚本，并放置在 `/usr/local/sbin/` 目录下。
3.  **授予权限**：为脚本添加可执行权限。
4.  **设置定时任务**：在 `crontab` 中添加一条新任务，该任务会在**每天 UTC 时间 20:00（即北京时间次日凌晨 4:00）**自动执行脚本。此操作是幂等的，重复运行不会创建重复的任务。
5.  **记录日志**：脚本的所有运行输出将被记录在 `/tmp/autowarp.log` 文件中，方便您随时检查。