[根目录](../CLAUDE.md) > **wireguard-go**

# WireGuard Go实现模块

## 模块职责

提供WireGuard协议的用户空间Go语言实现，作为内核WireGuard的替代方案。主要用于不支持内核WireGuard或需要用户空间实现的环境中。

## 入口和启动

### 源码获取
```bash
# 官方仓库克隆
git clone https://git.zx2c4.com/wireguard-go
git clone git://git.zx2c4.com/wireguard-go
git clone ssh://git@git.zx2c4.com/wireguard-go
```

### 编译和运行
```bash
# 编译
go build -o wireguard-go

# 运行（需要TUN设备支持）
./wireguard-go tun_device_name
```

## 外部接口

### 命令行接口
```bash
# 基本用法
wireguard-go [选项] 设备名

# 常用参数
-f, --foreground    前台运行
-v, --version       显示版本信息
```

### 配置接口
- **配置方式**: 通过标准WireGuard配置文件
- **管理接口**: 兼容`wg`命令行工具
- **网络接口**: 创建和管理TUN虚拟网络设备

## 关键依赖和配置

### 系统依赖
- **Go语言**: 编译时依赖
- **TUN支持**: 运行时需要TUN/TAP设备支持
- **网络权限**: 需要创建网络接口的权限

### 平台支持
- **Linux**: 完整支持，推荐使用
- **macOS**: 支持，适用于开发测试
- **Windows**: 部分支持
- **FreeBSD**: 实验性支持

### 关键特性
- **用户空间实现**: 无需内核模块
- **跨平台兼容**: 支持多种操作系统
- **标准兼容**: 完全兼容WireGuard协议
- **高性能**: 优化的Go实现

## 数据模型

### 网络配置
```ini
[Interface]
PrivateKey = 接口私钥
ListenPort = 监听端口 (可选)
Address = 接口IP地址

[Peer]
PublicKey = 对端公钥
AllowedIPs = 允许的IP范围
Endpoint = 对端地址:端口
PersistentKeepalive = 保活间隔 (可选)
```

### 内部数据结构
- **设备实例**: TUN设备管理
- **对等节点**: 加密通信端点
- **路由表**: 流量转发规则
- **密钥管理**: 加密密钥轮换

## 测试和质量

### 功能测试
```bash
# 设备创建测试
ip tuntap add dev wg0 mode tun

# 配置应用测试
wg setconf wg0 config.conf

# 连通性测试
ping 目标IP
```

### 性能测试
```bash
# 带宽测试
iperf3 -c 目标服务器

# 延迟测试
ping -c 100 目标IP

# 并发连接测试
```

### 兼容性测试
- **与内核WireGuard对比**
- **不同操作系统验证**
- **各种网络配置场景**

## 常见问题

### Q: 与内核WireGuard有什么区别？
**A:** 主要差异：
1. **性能**: 内核实现通常更快
2. **兼容性**: 用户空间实现兼容性更好
3. **部署**: 用户空间无需内核模块
4. **维护**: Go实现更易于调试和修改

### Q: 什么情况下选择wireguard-go？
**A:** 适用场景：
1. 系统不支持内核WireGuard
2. 需要自定义协议逻辑
3. 容器化部署环境
4. 开发和测试环境

### Q: 如何解决TUN设备问题？
**A:** 排查步骤：
1. 检查TUN模块是否加载 (`lsmod | grep tun`)
2. 验证设备文件 (`ls -l /dev/net/tun`)
3. 确认权限设置
4. 尝试手动创建TUN设备

### Q: 性能优化建议？
**A:** 优化方法：
1. 调整MTU大小
2. 优化网络缓冲区
3. 使用多队列网络接口
4. 根据CPU核心数调整并发设置

## 相关文件列表

### 核心文件
- `README.md` - 基本克隆信息
- `main.go` - 主程序入口 (假设)
- `device/` - 设备管理模块
- `tun/` - TUN接口实现

### 配置文件
- `*.conf` - WireGuard配置文件
- `wg0.conf` - 典型接口配置示例

### 构建产物
- `wireguard-go` - 编译后的可执行文件

## 集成指南

### 在项目中使用
```bash
# 作为独立服务运行
./wireguard-go wg0

# 配合wg工具管理
wg setconf wg0 /path/to/config.conf
wg show wg0
```

### 与其他模块集成
- **warp-go.sh**: 高级脚本中作为WireGuard后端
- **docker环境**: 容器中的VPN实现
- **自动化脚本**: 批量部署和管理

### 监控和日志
```bash
# 查看接口状态
wg show

# 监控流量统计
watch -n 1 'wg show wg0'

# 系统日志
journalctl -u wireguard-go
```

## 开发说明

### 源码结构
- 基于官方WireGuard-Go项目
- 保持与上游的兼容性
- 适配项目特定需求

### 构建要求
- Go 1.16+ 编译器
- 交叉编译支持
- 静态链接选项

### 贡献指南
- 遵循上游项目的贡献规范
- 提交前进行充分测试
- 保持代码风格一致性

## 变更日志

### 2025-08-22
- 创建模块文档
- 添加使用指南
- 整理常见问题解答

---

*最后更新: 2025-08-22*