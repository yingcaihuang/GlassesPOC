# Docker 环境配置和 Realtime API 集成

本文档描述了智能眼镜后端应用的 Docker 环境配置，特别是 GPT Realtime API 功能的集成测试环境。

## 概述

项目包含三个 Docker 环境配置：

1. **生产环境** (`docker-compose.yml`) - 完整的应用栈
2. **开发环境** (`docker-compose.dev.yml`) - 仅数据库服务，应用在本地运行
3. **测试环境** (`docker-compose.test.yml`) - 专用于集成测试和 CI/CD

## 环境配置

### 1. 生产环境 (docker-compose.yml)

完整的应用栈，包括：
- PostgreSQL 数据库 (端口 5432)
- Redis 缓存 (端口 6379)
- 后端应用 (内部端口 8080)
- 前端应用 (端口 3000)

**Realtime API 环境变量：**
```yaml
AZURE_OPENAI_REALTIME_ENDPOINT: "${AZURE_OPENAI_REALTIME_ENDPOINT:-}"
AZURE_OPENAI_REALTIME_API_KEY: "${AZURE_OPENAI_REALTIME_API_KEY:-}"
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME: "${AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME:-gpt-4o-realtime-preview}"
AZURE_OPENAI_REALTIME_API_VERSION: "${AZURE_OPENAI_REALTIME_API_VERSION:-2024-10-01-preview}"
```

### 2. 开发环境 (docker-compose.dev.yml)

仅启动数据库服务，应用在本地运行：
- PostgreSQL 数据库 (端口 5432)
- Redis 缓存 (端口 6379)

### 3. 测试环境 (docker-compose.test.yml)

专用于测试的隔离环境：
- PostgreSQL 测试数据库 (端口 5433)
- Redis 测试缓存 (端口 6380)
- 后端测试应用 (端口 8081)
- 前端测试应用 (端口 3001)
- 测试运行器容器

**测试环境特性：**
- 使用不同的端口避免冲突
- 内存存储提高测试速度
- 禁用持久化和自动重启
- 独立的网络子网 (172.20.0.0/16)

## 环境变量配置

### .env 文件

项目根目录的 `.env` 文件包含所有必需的环境变量：

```env
# Azure OpenAI 基础配置
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2024-08-01-preview

# GPT Realtime API 配置
AZURE_OPENAI_REALTIME_ENDPOINT=https://your-resource.cognitiveservices.azure.com
AZURE_OPENAI_REALTIME_API_KEY=your-realtime-api-key
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=gpt-realtime
AZURE_OPENAI_REALTIME_API_VERSION=2025-08-28
```

## 使用说明

### 开发环境

启动开发环境数据库：
```bash
make docker-up
# 或
docker-compose -f docker-compose.dev.yml up -d postgres redis
```

停止开发环境：
```bash
make docker-down
# 或
docker-compose -f docker-compose.dev.yml down
```

### 测试环境

启动测试环境：
```bash
make docker-test-up
# 或
docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
```

运行完整测试：
```bash
make docker-test
# 或
docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit test-runner
```

停止测试环境：
```bash
make docker-test-down
# 或
docker-compose -f docker-compose.test.yml down -v
```

### 生产环境

启动完整应用：
```bash
docker-compose up -d
```

停止应用：
```bash
docker-compose down
```

## 验证和测试

### 配置验证

验证 Docker 配置文件语法和结构：
```bash
make docker-verify
# 或
./scripts/verify-docker-config.sh
```

### 环境测试

完整的环境测试（需要 Docker 运行）：
```bash
./scripts/test-docker-env.sh
```

### Realtime API 集成测试

专门的 Realtime API 功能测试：
```bash
./scripts/test-realtime-integration.sh
```

### 网络通信测试

测试容器间网络通信：
```bash
make test-network
```

## 网络配置

### 主环境网络
- 网络名称: `smart-glasses-network`
- 驱动: bridge
- 默认子网

### 测试环境网络
- 网络名称: `smart-glasses-test-network`
- 驱动: bridge
- 子网: 172.20.0.0/16

## 端口映射

| 服务 | 生产环境 | 测试环境 | 说明 |
|------|----------|----------|------|
| PostgreSQL | 5432 | 5433 | 数据库 |
| Redis | 6379 | 6380 | 缓存 |
| 后端应用 | 8080 (内部) | 8081 | API 服务 |
| 前端应用 | 3000 | 3001 | Web 界面 |

## 健康检查

所有服务都配置了健康检查：

### PostgreSQL
```bash
pg_isready -U smartglasses
```

### Redis
```bash
redis-cli ping
```

### 应用服务
- 健康检查端点: `/health`
- 超时: 30秒
- 重试: 3次

## 故障排除

### 常见问题

1. **端口冲突**
   - 确保测试环境使用不同端口
   - 检查本地是否有服务占用端口

2. **Docker 守护进程未运行**
   ```bash
   # macOS
   open -a Docker
   
   # Linux
   sudo systemctl start docker
   ```

3. **权限问题**
   ```bash
   # 添加用户到 docker 组
   sudo usermod -aG docker $USER
   ```

4. **网络问题**
   ```bash
   # 清理 Docker 网络
   docker network prune
   ```

5. **存储空间不足**
   ```bash
   # 清理 Docker 资源
   docker system prune -a
   ```

### 日志查看

查看服务日志：
```bash
# 生产环境
docker-compose logs app
docker-compose logs postgres
docker-compose logs redis

# 测试环境
docker-compose -f docker-compose.test.yml logs app-test
docker-compose -f docker-compose.test.yml logs postgres-test
```

### 调试模式

启用调试模式：
```bash
# 设置环境变量
export LOG_LEVEL=debug

# 或在 .env 文件中添加
LOG_LEVEL=debug
```

## 性能优化

### 测试环境优化
- 使用内存存储 (tmpfs)
- 禁用持久化
- 减少健康检查间隔
- 限制日志大小

### 生产环境优化
- 启用持久化存储
- 配置资源限制
- 启用日志轮转
- 配置重启策略

## 安全考虑

1. **环境变量保护**
   - 不要将 `.env` 文件提交到版本控制
   - 使用 Docker secrets 管理敏感信息

2. **网络隔离**
   - 测试环境使用独立网络
   - 限制容器间通信

3. **访问控制**
   - 配置防火墙规则
   - 使用非 root 用户运行容器

## 监控和日志

### 日志配置
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 监控指标
- 容器健康状态
- 资源使用情况
- 网络连接状态
- 应用响应时间

## 备份和恢复

### 数据备份
```bash
# PostgreSQL 备份
docker-compose exec postgres pg_dump -U smartglasses smart_glasses > backup.sql

# Redis 备份
docker-compose exec redis redis-cli BGSAVE
```

### 数据恢复
```bash
# PostgreSQL 恢复
docker-compose exec -T postgres psql -U smartglasses smart_glasses < backup.sql
```

## 更新和维护

### 镜像更新
```bash
# 拉取最新镜像
docker-compose pull

# 重新构建
docker-compose build --no-cache
```

### 清理维护
```bash
# 清理未使用的资源
make clean

# 或手动清理
docker system prune -f
docker volume prune -f
```

## 相关文件

- `docker-compose.yml` - 生产环境配置
- `docker-compose.dev.yml` - 开发环境配置
- `docker-compose.test.yml` - 测试环境配置
- `Dockerfile` - 应用镜像构建
- `Dockerfile.test` - 测试镜像构建
- `Makefile` - 构建和测试命令
- `.env` - 环境变量配置
- `scripts/verify-docker-config.sh` - 配置验证脚本
- `scripts/test-docker-env.sh` - 环境测试脚本
- `scripts/test-realtime-integration.sh` - Realtime API 集成测试脚本