[根目录](../CLAUDE.md) > **wireproxy**

# WireGuard代理工具模块

## 模块职责

作为完全用户空间的WireGuard客户端，将WireGuard连接转换为SOCKS5/HTTP代理或隧道服务。适用于无需创建新网络接口但需要通过WireGuard代理流量的场景。

## 入口和启动

### 主要入口文件
- `wireproxy` - 主要可执行文件

### 基本用法
```bash
# 使用配置文件启动
./wireproxy -c config.conf

# 后台运行
./wireproxy -c config.conf -d

# 静默模式
./wireproxy -c config.conf -s

# 配置测试
./wireproxy -c config.conf -n
```

## 外部接口

### 命令行参数
```bash
wireproxy [-h|--help] [-c|--config "value"] [-s|--silent] 
          [-d|--daemon] [-i|--info "value"] [-v|--version] 
          [-n|--configtest]

参数说明:
-h, --help        显示帮助信息
-c, --config      配置文件路径 (默认: /etc/wireproxy/wireproxy.conf, ~/.config/wireproxy.conf)
-s, --silent      静默模式
-d, --daemon      后台运行
-i, --info        健康状态监控地址和端口
-v, --version     显示版本信息
-n, --configtest  配置文件验证模式
```

### 代理接口
- **SOCKS5代理**: 支持TCP流量代理
- **HTTP代理**: 支持HTTP CONNECT方法
- **TCP隧道**: 静态端口转发
- **STDIO隧道**: 标准输入输出重定向

## 关键依赖和配置

### 系统要求
- **用户空间运行**: 无需root权限
- **网络访问**: 能够连接WireGuard服务器
- **端口权限**: 绑定监听端口的权限

### 核心配置文件

#### 基础配置示例
```ini
# Interface配置（与wg-quick语义相同）
[Interface]
Address = 10.200.200.2/32  # IPv4使用/32，IPv6使用/128
PrivateKey = your_private_key
DNS = 10.200.200.1
# MTU = 1420 (可选)

# Peer配置
[Peer]
PublicKey = peer_public_key
Endpoint = server.example.com:51820
# PresharedKey = optional_preshared_key
# PersistentKeepalive = 25

# SOCKS5代理配置
[Socks5]
BindAddress = 127.0.0.1:25344
# Username = optional_username
# Password = optional_password

# HTTP代理配置
[http]
BindAddress = 127.0.0.1:25345
# Username = optional_username
# Password = optional_password
```

#### 高级隧道配置
```ini
# TCP客户端隧道
[TCPClientTunnel]
BindAddress = 127.0.0.1:25565
Target = remote.server.com:25565

# TCP服务端隧道
[TCPServerTunnel]
ListenPort = 3422
Target = localhost:25545

# STDIO隧道（SSH ProxyCommand使用）
[STDIOTunnel]
Target = ssh.server.com:22
```

### 多Peer支持
```ini
[Interface]
Address = 10.254.254.40/32
PrivateKey = your_private_key

[Peer]
Endpoint = 192.168.0.204:51820
PublicKey = peer1_public_key
AllowedIPs = 10.254.254.100/32
PersistentKeepalive = 25

[Peer]
PublicKey = peer2_public_key
AllowedIPs = 10.254.254.1/32, fdee:1337:c000:d00d::1/128
Endpoint = 172.16.0.185:44044
PersistentKeepalive = 25
```

## 数据模型

### 连接流向
1. **TCP客户端隧道**: 本地应用 → localhost:port → (WireGuard) → 远程目标
2. **TCP服务端隧道**: 远程客户端 → (WireGuard) → localhost:port → 本地服务
3. **SOCKS5代理**: 客户端 → SOCKS5 → (WireGuard) → 目标服务器
4. **HTTP代理**: 客户端 → HTTP CONNECT → (WireGuard) → 目标服务器

### 网络架构
- **用户空间实现**: 完全绕过系统网络接口
- **多协议支持**: 同时支持TCP隧道和代理协议
- **路由控制**: 基于AllowedIPs的流量分发

## 测试和质量

### 功能测试
```bash
# SOCKS5代理测试
curl --socks5 127.0.0.1:25344 http://ipinfo.io

# HTTP代理测试
curl --proxy http://127.0.0.1:25345 http://ipinfo.io

# TCP隧道测试
telnet localhost 25565
```

### 健康监控
启用健康监控端点：
```bash
wireproxy -c config.conf -i localhost:9080
```

监控端点：
- `/metrics` - WireGuard连接信息
- `/readyz` - 连接健康状态

#### 健康检查配置
```ini
[Interface]
PrivateKey = your_key
Address = 10.2.0.2/32
DNS = 10.2.0.1
CheckAlive = 1.1.1.1, 3.3.3.3
CheckAliveInterval = 3

[Peer]
PublicKey = peer_key
AllowedIPs = 0.0.0.0/0
Endpoint = server:51820
```

## 常见问题

### Q: 为什么选择wireproxy而不是传统WireGuard？
**A:** 适用场景：
1. **无需root权限**: 不需要修改系统网络配置
2. **选择性代理**: 只代理特定应用的流量
3. **网络隔离**: 与系统网络接口完全隔离
4. **灵活部署**: 支持容器和受限环境

### Q: 如何配置SSH通过wireproxy？
**A:** 使用STDIO隧道：
```bash
# wireproxy配置
[STDIOTunnel]
Target = ssh.server.com:22

# SSH配置
ssh -o ProxyCommand='wireproxy -c config.conf' user@ssh.server.com
```

### Q: 支持UDP流量吗？
**A:** 当前限制：
1. SOCKS5代理暂不支持UDP
2. TCP隧道仅支持TCP流量
3. UDP支持在开发计划中

### Q: 如何优化性能？
**A:** 性能调优：
1. 调整MTU设置
2. 使用适当的CheckAliveInterval
3. 合理配置AllowedIPs范围
4. 选择延迟较低的服务器端点

## 相关文件列表

### 主要文件
- `README.md` - 详细使用说明和配置示例
- `UseWithVPN.md` - Firefox容器和macOS自启动指南
- `LICENSE` - ISC许可证
- `wireproxy` - 主要可执行文件

### 配置文件
- `/etc/wireproxy/wireproxy.conf` - 系统级配置
- `~/.config/wireproxy.conf` - 用户级配置
- `config.conf` - 自定义配置文件

### 构建文件
- `Makefile` - 构建脚本
- `go.mod` - Go模块依赖

## 集成指南

### Firefox容器集成
详见`UseWithVPN.md`中的容器配置说明。

### macOS自启动
配置LaunchAgent实现开机自启动。

### 容器部署
```dockerfile
FROM alpine
COPY wireproxy /usr/local/bin/
COPY config.conf /etc/wireproxy/
CMD ["wireproxy", "-c", "/etc/wireproxy/config.conf"]
```

### 与其他工具集成
- **SSH代理**: ProxyCommand配置
- **浏览器代理**: 系统代理或扩展配置
- **应用程序**: SOCKS5/HTTP代理设置

## 构建指南

### 从源码编译
```bash
git clone https://github.com/octeep/wireproxy
cd wireproxy
make
```

### 交叉编译
支持多平台交叉编译，详见项目构建文档。

## 变更日志

### 2025-08-22
- 创建模块文档
- 整理配置示例
- 添加使用场景说明

---

*最后更新: 2025-08-22*