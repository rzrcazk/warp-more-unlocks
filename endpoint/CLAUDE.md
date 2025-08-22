[根目录](../CLAUDE.md) > **endpoint**

# 端点优化工具模块

## 模块职责

提供WARP网络端点的测试、优化和选择功能。通过测试不同端点的连接质量（延迟、丢包率等），自动选择最佳连接端点，提升WARP连接性能和稳定性。

## 入口和启动

### 主要文件
- `warp-linux-amd64` - AMD64架构端点测试工具
- `warp-linux-arm64` - ARM64架构端点测试工具  
- `warp-linux-s390x` - S390X架构端点测试工具
- `ipv4` - IPv4端点列表
- `ipv6` - IPv6端点列表

### 基本用法
```bash
# 基本端点测试
./warp-linux-amd64 -file ipv4 -output result.txt

# IPv6端点测试
./warp-linux-arm64 -file ipv6 -output ipv6_result.txt

# 指定测试参数
./warp-linux-amd64 -file ipv4 -output result.txt -timeout 5 -count 10
```

## 外部接口

### 命令行参数
```bash
warp-linux-[arch] [选项]

常用参数:
-file     端点列表文件
-output   结果输出文件
-timeout  超时时间 (秒)
-count    测试次数
-threads  并发线程数
```

### 输入文件格式

#### IPv4端点列表 (ipv4)
```
162.159.192.1:2408
162.159.193.1:2408
162.159.194.1:2408
...
```

#### IPv6端点列表 (ipv6)
```
[2606:4700:d0::a29f:c001]:2408
[2606:4700:d1::a29f:c001]:2408
[2606:4700:d2::a29f:c001]:2408
...
```

### 输出格式
```
端点地址,丢包率,平均延迟
162.159.192.1:2408,0.00%,45 ms
162.159.193.1:2408,10.00%,67 ms
162.159.194.1:2408,5.00%,52 ms
```

## 关键依赖和配置

### 系统要求
- **Linux系统**: 目标运行平台
- **网络连接**: UDP端口访问能力
- **架构支持**: AMD64、ARM64、S390X

### 测试机制
- **UDP连通性测试**: 测试端点UDP连接
- **延迟测量**: 计算往返时间(RTT)
- **丢包率统计**: 评估连接稳定性
- **并发测试**: 提高测试效率

### 集成使用
在`warp-go.sh`中的集成示例：
```bash
# 下载端点测试工具
wget -qO /tmp/endpoint https://gitlab.com/fscarmen/warp/-/raw/main/endpoint/warp-linux-${ARCHITECTURE//amd64*/amd64}
chmod +x /tmp/endpoint

# 下载端点列表
[ "$IPV4$IPV6" = 01 ] && wget -qO /tmp/ip https://gitlab.com/fscarmen/warp/-/raw/main/endpoint/ipv6 || wget -qO /tmp/ip https://gitlab.com/fscarmen/warp/-/raw/main/endpoint/ipv4

# 执行测试并获取最佳端点
/tmp/endpoint -file /tmp/ip -output /tmp/endpoint_result >/dev/null 2>&1
ENDPOINT=$(grep -sE '[0-9]+[ ]+ms$' /tmp/endpoint_result | awk -F, 'NR==1 {print $1}')
```

## 数据模型

### 端点数据结构
```
端点信息 = {
    地址: IP:PORT,
    协议: IPv4/IPv6,
    延迟: 毫秒,
    丢包率: 百分比,
    质量评分: 综合评估
}
```

### 测试结果排序
1. **丢包率优先**: 丢包率低的端点优先
2. **延迟次优**: 相同丢包率下选择延迟更低的
3. **稳定性**: 多次测试结果的一致性

### 质量评估算法
```
质量评分 = (100 - 丢包率) * 权重1 + (1000 / 延迟) * 权重2
```

## 测试和质量

### 测试场景
```bash
# 基础连通性测试
./warp-linux-amd64 -file ipv4 -output basic_test.txt

# 高负载测试
./warp-linux-amd64 -file ipv4 -output load_test.txt -threads 20 -count 50

# 稳定性测试
for i in {1..10}; do
    ./warp-linux-amd64 -file ipv4 -output stability_$i.txt
done
```

### 结果验证
```bash
# 检查最佳端点
head -1 result.txt

# 验证连接质量
ping -c 4 $(head -1 result.txt | cut -d, -f1 | cut -d: -f1)

# 丢包率统计
awk -F, '{print $2}' result.txt | sort -n
```

### 性能基准
- **延迟目标**: < 100ms
- **丢包率目标**: < 5%
- **测试时间**: < 30秒完成
- **并发能力**: 支持20+并发测试

## 常见问题

### Q: 测试结果显示100%丢包怎么办？
**A:** 可能原因和解决方案：
1. **UDP被限制**: 检查防火墙和ISP政策
2. **网络问题**: 验证基础网络连通性
3. **端点失效**: 尝试其他端点列表
4. **工具问题**: 检查工具文件完整性

### Q: 如何选择合适的端点？
**A:** 选择策略：
1. **地理位置**: 选择就近的端点
2. **网络质量**: 优先考虑延迟和稳定性
3. **负载均衡**: 避免都使用同一个端点
4. **定期更新**: 网络环境变化时重新测试

### Q: 测试工具如何更新？
**A:** 更新方法：
1. 定期从官方仓库下载最新版本
2. 对比文件哈希确认完整性
3. 测试新版本的兼容性
4. 更新自动化脚本中的下载链接

### Q: 不同架构的工具有什么区别？
**A:** 主要差异：
1. **编译目标**: 针对不同CPU架构优化
2. **功能相同**: 测试逻辑和参数一致
3. **性能差异**: 在对应架构上性能最佳
4. **兼容性**: 确保在目标系统正常运行

## 相关文件列表

### 可执行文件
- `warp-linux-amd64` - AMD64架构测试工具 (约1-2MB)
- `warp-linux-arm64` - ARM64架构测试工具 (约1-2MB)
- `warp-linux-s390x` - S390X架构测试工具 (约1-2MB)

### 数据文件
- `ipv4` - IPv4端点列表 (文本文件)
- `ipv6` - IPv6端点列表 (文本文件)

### 输出文件
- `endpoint_result` - 测试结果文件
- `*.txt` - 自定义输出文件

## 集成指南

### 在脚本中使用
```bash
# 架构检测
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) TOOL="warp-linux-amd64" ;;
    aarch64) TOOL="warp-linux-arm64" ;;
    s390x) TOOL="warp-linux-s390x" ;;
esac

# 选择端点列表
[ "$IPV6_ONLY" = "yes" ] && ENDPOINTS="ipv6" || ENDPOINTS="ipv4"

# 执行测试
./$TOOL -file $ENDPOINTS -output result.txt

# 获取最佳端点
BEST_ENDPOINT=$(head -1 result.txt | cut -d, -f1)
```

### 自动化集成
- **定期测试**: 通过cron定期更新最佳端点
- **配置更新**: 自动更新WireGuard配置中的端点
- **监控告警**: 端点质量下降时触发告警

### 性能监控
```bash
# 监控端点质量变化
while true; do
    ./warp-linux-amd64 -file ipv4 -output monitor.txt
    echo "$(date): $(head -1 monitor.txt)" >> endpoint_history.log
    sleep 3600
done
```

## 开发说明

### 工具来源
- 基于官方或社区提供的端点测试工具
- 针对WARP服务端点特点优化
- 支持多架构交叉编译

### 更新维护
- 定期更新端点列表
- 跟进Cloudflare网络变化
- 优化测试算法和参数

## 变更日志

### 2025-08-22
- 创建模块文档
- 整理工具使用说明
- 添加集成示例

---

*最后更新: 2025-08-22*