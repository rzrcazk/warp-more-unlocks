# 【WARP】连接CF WARP为服务器添加IPv4/IPv6网络并智能解锁流媒体

* * *

## 目录

- [【WARP】连接CF WARP为服务器添加IPv4/IPv6网络并智能解锁流媒体](#warp连接cf-warp为服务器添加ipv4ipv6网络并智能解锁流媒体)
  - [目录](#目录)
  - [脚本特点](#脚本特点)
  - [运行脚本](#运行脚本)
  - [主要功能说明](#主要功能说明)
  - [原脚本作者](#原脚本作者)

* * *

## 脚本特点

*   **智能解锁增强**: `warp i` 功能经过优化，可以交互式选择多种流媒体服务（Netflix, Disney+, ChatGPT 等）进行测试。它会严格筛选并自动更换 IP，直到找到一个能**完美解锁所有选定服务**的 IP。
*   **后台守护服务**: 在 `warp i` 成功找到可用 IP 后，可选择开启后台服务。该服务会**稳定地**在后台监控 IP 的解锁状态，仅在 IP 被**明确封锁**（如区域限制或服务屏蔽）时才自动更换，避免因临时网络问题造成不必要的 IP 切换。
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
| `i`                    | **智能更换解锁 IP**：交互式选择一个或多个流媒体服务，脚本将严格筛选并自动更换 IP，直到找到一个能**完美解锁所有选定服务**的 IP 地址。成功后，可选择开启**后台守护服务**以维持解锁状态。 |
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

## 原脚本作者

*   **WARP 一键脚本**: [fscarmen/warp](https://gitlab.com/fscarmen/warp/)
*   **IP 质量检测**: [xykt/IPQuality](https://github.com/xykt/IPQuality)