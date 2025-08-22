[根目录](../CLAUDE.md) > **wgcf**

# 非官方WARP CLI工具模块

## 模块职责

提供跨平台的Cloudflare WARP命令行界面，作为官方客户端的非官方替代方案。支持账户注册、License管理、WireGuard配置生成和连接状态检查等核心功能。

## 入口和启动

### 主要入口文件
- `wgcf` - 主要可执行文件（需从releases下载）

### 基本用法
```bash
# 显示帮助
wgcf

# 注册新账户
wgcf register

# 生成WireGuard配置
wgcf generate

# 更新账户License
wgcf update

# 检查设备状态
wgcf status

# 验证WARP连接
wgcf trace
```

## 外部接口

### 核心命令

#### 账户管理
```bash
# 注册新的免费WARP账户
wgcf register
# 输出: wgcf-account.toml

# 更新License（升级到WARP+）
wgcf update
# 或使用环境变量
WGCF_LICENSE_KEY="your-license" wgcf update
```

#### 配置生成
```bash
# 生成WireGuard配置文件
wgcf generate  
# 输出: wgcf-profile.conf

# 自定义MTU（默认1280）
# 可在生成后手动修改配置文件中的MTU值
```

#### 状态检查
```bash
# 检查设备注册状态
wgcf status

# 验证WARP连接状态
wgcf trace
# 输出: warp=on 或 warp=plus
```

### 环境变量支持
- `WGCF_LICENSE_KEY` - WARP+ License密钥

## 关键依赖和配置

### 系统要求
- **跨平台支持**: Linux, Windows, macOS, BSD
- **架构支持**: amd64, arm64, 386等
- **网络要求**: 访问Cloudflare WARP API

### 依赖关系
- **WireGuard**: 用于配置文件的实际连接
- **OpenAPI3客户端**: 自动生成的API客户端代码
- **Optic工具**: API文档生成和测试

### 核心配置文件

#### 账户配置 (wgcf-account.toml)
```toml
device_id = "设备唯一标识符"
access_token = "API访问令牌"
private_key = "WireGuard私钥"
license_key = "WARP+ License (可选)"
```

#### WireGuard配置 (wgcf-profile.conf)
```ini
[Interface]
PrivateKey = 生成的私钥
Address = 分配的IP地址
DNS = 1.1.1.1
MTU = 1280

[Peer] 
PublicKey = Cloudflare服务器公钥
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 服务器端点
```

## 数据模型

### API数据结构
- **设备注册**: 设备ID、访问令牌、私钥
- **License管理**: License验证、设备绑定
- **网络配置**: IP分配、端点信息、路由规则

### 配置转换流程
1. **注册阶段**: API调用 → 账户文件生成
2. **配置阶段**: 账户信息 → WireGuard配置
3. **连接阶段**: 配置文件 → WireGuard连接

## 测试和质量

### API测试套件
- **测试位置**: `api_tests/main.go`
- **覆盖范围**: 所有wgcf使用的API端点
- **文档生成**: 使用Optic自动生成OpenAPI3规范

### 连接验证
```bash
# 验证连接是否建立
wgcf trace

# 检查期望输出
# warp=on (免费账户)
# warp=plus (WARP+账户)
```

### 故障排除
```bash
# 检查账户文件
cat wgcf-account.toml

# 验证配置文件
wg-quick up wgcf-profile.conf

# 网络连通性测试
ping 1.1.1.1
```

## 常见问题

### Q: 注册失败怎么办？
**A:** 检查网络连接和API访问：
1. 确认能访问Cloudflare API
2. 检查防火墙设置
3. 重试注册命令

### Q: License更新失败？
**A:** 验证License有效性：
1. 确认License格式正确（26位字符）
2. 检查设备数量限制（最多5台）
3. 验证License是否已激活

### Q: 生成的配置无法连接？
**A:** 检查配置和网络：
1. 验证WireGuard工具安装
2. 检查MTU设置（可尝试调整）
3. 确认防火墙允许WireGuard流量

### Q: MTU优化建议？
**A:** 性能调优：
1. 默认1280保证兼容性
2. 可尝试更高值提升性能
3. 参考issue #40的详细说明

## 相关文件列表

### 主要文件
- `README.md` - 项目说明和使用指南
- `openapi-spec.json` - API规范文档
- `generate-api.sh` - API客户端代码生成脚本

### 开发文件
- `api_tests/main.go` - API测试套件
- `spec_format/main.go` - OpenAPI规范格式化工具
- `openapi/client.go` - 生成的Go API客户端

### 输出文件
- `wgcf-account.toml` - 账户信息文件
- `wgcf-profile.conf` - WireGuard配置文件

## 开发指南

### API文档更新
```bash
# 安装Optic
# 启动API监控
api start

# 在Web UI中解决差异并保存
```

### 客户端代码重新生成
```bash
# 安装openapi-generator
# 重新生成Go客户端
bash generate-api.sh
```

### 支持平台
- Linux (支持WSL)
- Windows
- macOS
- 各种BSD变体

## 变更日志

### 2025-08-22
- 创建模块文档
- 整理命令接口规范
- 添加开发指南

---

*最后更新: 2025-08-22*