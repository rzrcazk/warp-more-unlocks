[根目录](../CLAUDE.md) > **pc**

# PC平台工具模块

## 模块职责

为macOS平台提供WARP一键安装和管理解决方案，通过WireGuard隧道实现安全快速的网络连接。专注于Mac系统的用户体验优化，提供中英文双语支持和简化的操作流程。

## 入口和启动

### 主要入口文件
- `mac.sh` - macOS WARP一键安装脚本

### 启动方式
```bash
# 中文安装
sudo curl -o /usr/local/bin/mac.sh https://raw.githubusercontent.com/fscarmen/warp/main/pc/mac.sh && bash mac.sh c

# 英文安装  
sudo curl -o /usr/local/bin/mac.sh https://raw.githubusercontent.com/fscarmen/warp/main/pc/mac.sh && bash mac.sh e

# 本地运行
bash mac.sh [option]
```

## 外部接口

### 命令行接口
| 参数 | 功能描述 |
|------|---------|
| `c` | 中文安装模式 |
| `e` | 英文安装模式 |
| `h` | 显示帮助信息 |
| `o` | WARP开关切换 |
| `u` | 卸载WARP |
| `a` | 账户升级(WARP+/Teams) |
| `v` | 同步最新版本 |

### 快捷命令
安装完成后可使用：
```bash
warp o    # 开关WARP
warp u    # 卸载
warp a    # 账户升级
warp v    # 版本更新
```

## 关键依赖和配置

### 系统依赖
- **macOS** - 目标运行平台
- **brew** - 包管理器，用于安装依赖
- **wireguard-tools** - WireGuard工具集
- **sudo权限** - 系统配置权限

### 核心组件
- **WGCF** - 官方WARP配置生成工具
- **wireguard-go** - WireGuard用户空间实现
- **网络配置** - IPv4路由和DNS设置

### 配置文件
- `/etc/wireguard/wgcf.conf` - WireGuard主配置
- `/etc/wireguard/wgcf-account.toml` - WARP账户信息
- `/etc/wireguard/info.log` - 运行状态日志

## 数据模型

### 账户信息结构
```toml
# wgcf-account.toml
device_id = "设备唯一标识"
access_token = "访问令牌"
private_key = "私钥"
license_key = "WARP+ License（可选）"
```

### 网络配置结构
```ini
# wgcf.conf
[Interface]
PrivateKey = "私钥"
Address = "IP地址段"
DNS = "DNS服务器"
MTU = "最大传输单元"

[Peer]
PublicKey = "Cloudflare公钥"
AllowedIPs = "允许IP范围"
Endpoint = "服务端点"
```

## 测试和质量

### 功能测试
- **安装流程测试**
  - 依赖安装验证
  - 配置文件生成验证
  - 网络连接测试

- **账户管理测试**
  - 免费账户注册
  - WARP+账户升级
  - Teams账户配置

### 网络测试
```bash
# IP地址检查
curl -s https://api.ip.sb/geoip

# 连接状态验证
wg show

# 网络性能测试
ping -c 4 1.1.1.1
```

### 日志监控
```bash
# 查看运行日志
tail -f /etc/wireguard/info.log

# 检查系统状态
sudo launchctl list | grep wireguard
```

## 常见问题

### Q: 安装失败怎么办？
**A:** 检查以下项目：
1. 确认以root权限运行 (`sudo -i`)
2. 检查网络连接
3. 验证brew是否正常工作
4. 查看错误日志定位问题

### Q: WARP+升级失败？
**A:** 可能原因：
1. License格式错误（应为26位字符）
2. 设备数量超限（最多5台）
3. License已被使用
4. 网络连接问题

### Q: 网络连接异常？
**A:** 排查步骤：
1. 检查WireGuard状态 (`wg show`)
2. 验证路由表配置
3. 测试DNS解析
4. 重启WARP服务 (`warp o`)

### Q: 如何完全卸载？
**A:** 运行卸载命令：
```bash
warp u
# 或
bash mac.sh u
```

## 相关文件列表

### 核心脚本
- `mac.sh` - 主安装脚本 (3600+ 行)
  - 多语言支持
  - 依赖自动安装
  - 账户管理功能
  - 网络配置优化

### 生成的配置文件
- `/etc/wireguard/wgcf.conf` - WireGuard配置
- `/etc/wireguard/wgcf-account.toml` - 账户信息
- `/etc/wireguard/info.log` - 运行日志
- `/usr/local/bin/warp` - 快捷命令链接

## 变更日志

### 2025-08-22
- 创建模块文档
- 整理接口规范
- 添加故障排除指南

---

*最后更新: 2025-08-22*