# 系统集成测试指南

本文档描述了 GPT Realtime WebRTC 功能的完整系统集成测试方案。

## 测试概览

系统集成测试分为三个主要阶段：

1. **配置和环境验证测试** - 验证 Docker 环境配置的完整性
2. **系统集成测试** - 测试多用户并发、长时间会话、错误恢复等核心功能
3. **负载和压力测试** - 测试系统在高负载下的表现（可选）

## 快速开始

### 运行基础集成测试

```bash
# 运行完整集成测试（不包含负载测试）
make test-complete-integration

# 或直接运行脚本
./scripts/test-complete-integration.sh
```

### 运行包含负载测试的完整测试

```bash
# 运行完整集成测试（包含负载测试）
make test-complete-integration-with-load

# 或直接运行脚本
./scripts/test-complete-integration.sh --with-load-tests
```

## 测试阶段详情

### 阶段 1: 配置和环境验证测试

**脚本**: `scripts/test-integration-complete.sh`

**测试内容**:
- Docker 配置文件验证
- 环境变量配置检查
- 网络配置验证
- 端口配置检查
- Realtime API 配置验证
- 健康检查配置验证
- 测试脚本可用性检查
- Makefile 目标验证
- 文档完整性检查
- Go 依赖验证

**运行方式**:
```bash
./scripts/test-integration-complete.sh
```

### 阶段 2: 系统集成测试

**脚本**: `scripts/test-system-integration.sh`

**测试内容**:
- **基础功能测试**: 健康检查、数据库连接、Redis 连接
- **多用户并发语音对话测试**: 5个并发用户同时进行语音对话
- **长时间会话测试**: 60秒长会话，监控资源使用和清理
- **错误恢复测试**: 数据库中断、Redis 中断、应用重启恢复
- **系统稳定性测试**: 容器状态、内存使用、错误日志检查

**运行方式**:
```bash
./scripts/test-system-integration.sh
```

**测试配置**:
- 并发用户数: 5
- 长会话持续时间: 60秒
- 测试超时: 300秒（5分钟）

### 阶段 3: 负载和压力测试（可选）

**脚本**: `scripts/test-load-stress.sh`

**测试内容**:
- **负载测试**: 10个并发用户，持续2分钟
- **压力测试**: 逐步增加负载（5→10→15→20用户）
- **资源监控**: 内存、CPU、连接数监控
- **性能分析**: 延迟、吞吐量、错误率分析

**运行方式**:
```bash
./scripts/test-load-stress.sh
```

**测试配置**:
- 负载测试: 10用户 × 2分钟
- 压力测试: 4个级别，每级别1分钟
- 消息频率: 100ms - 10ms（逐步增加）

## 前置条件

### 必需工具

- Docker
- Docker Compose
- curl
- jq
- Node.js
- bc (计算器)

### 安装依赖

**macOS**:
```bash
brew install docker docker-compose curl jq node bc
```

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose curl jq nodejs npm bc
```

### 配置文件

确保以下文件存在且配置正确：
- `docker-compose.test.yml`
- `.env`
- `Makefile`

## 测试环境

测试使用独立的 Docker 环境，包含：

- **PostgreSQL 测试数据库** (端口 5433)
- **Redis 测试缓存** (端口 6380)
- **应用服务器** (端口 8081)
- **前端服务** (端口 3001)

测试环境与开发环境完全隔离，使用不同的端口和网络。

## 测试结果

### 成功标准

**配置验证测试**:
- 所有配置文件存在且有效
- 环境变量完整配置
- 网络和端口无冲突

**系统集成测试**:
- 基础功能正常
- 80%+ 并发连接成功
- 长会话无内存泄漏
- 错误恢复机制有效

**负载测试**:
- 90%+ 连接成功率
- 85%+ 消息成功率
- 延迟在可接受范围内

### 测试报告

每次测试运行后会生成详细报告：
- `integration-test-report-YYYYMMDD-HHMMSS.txt`
- `system-integration-test-YYYYMMDD-HHMMSS.txt`
- `comprehensive-integration-test-YYYYMMDD-HHMMSS.txt`

## 故障排除

### 常见问题

**1. 端口冲突**
```bash
# 检查端口占用
lsof -i :8081
lsof -i :5433
lsof -i :6380

# 停止冲突的服务
docker-compose down
```

**2. 容器启动失败**
```bash
# 查看容器日志
docker-compose -f docker-compose.test.yml logs app-test

# 重新构建镜像
docker-compose -f docker-compose.test.yml build --no-cache
```

**3. 网络连接问题**
```bash
# 测试网络连通性
make test-network

# 重置 Docker 网络
docker network prune -f
```

**4. 依赖缺失**
```bash
# 检查所有依赖
./scripts/test-complete-integration.sh --help
```

### 调试模式

启用详细日志输出：
```bash
export DEBUG=1
./scripts/test-system-integration.sh
```

查看实时容器状态：
```bash
# 在另一个终端中运行
watch docker-compose -f docker-compose.test.yml ps
```

## 持续集成

### GitHub Actions 集成

```yaml
name: System Integration Tests
on: [push, pull_request]
jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Integration Tests
        run: |
          make test-complete-integration
```

### 定期测试

建议设置定期运行的集成测试：
```bash
# 添加到 crontab
0 2 * * * cd /path/to/project && make test-complete-integration
```

## 性能基准

### 预期性能指标

**并发连接**:
- 5个并发用户: 100% 成功率
- 10个并发用户: 95%+ 成功率
- 20个并发用户: 90%+ 成功率

**延迟**:
- WebSocket 连接: < 1000ms
- 消息往返: < 500ms
- 音频处理: < 200ms

**资源使用**:
- 内存: < 500MB (正常负载)
- CPU: < 50% (正常负载)
- 连接数: 支持 20+ 并发连接

## 扩展测试

### 添加自定义测试

1. 创建新的测试脚本
2. 添加到 `test-complete-integration.sh`
3. 更新 Makefile 目标
4. 更新文档

### 测试数据生成

使用内置的测试数据生成器：
- 音频数据生成
- 用户数据生成
- 配置数据生成

## 支持

如果遇到测试问题：

1. 查看测试报告文件
2. 检查 Docker 容器日志
3. 验证环境配置
4. 参考故障排除部分

更多信息请参考：
- [Docker 配置文档](DOCKER-REALTIME-SETUP.md)
- [API 文档](README.md)
- [开发指南](FRONTEND-SETUP.md)