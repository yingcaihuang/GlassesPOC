# Docker Compose 使用指南

本指南说明如何在Windows环境下使用Docker Compose开发和测试智能眼镜后端应用。

## 目录结构

```
.
├── docker-compose.yml          # 生产/完整环境配置
├── docker-compose.dev.yml      # 仅数据库服务（用于本地开发）
├── Dockerfile                  # 应用镜像构建文件
├── .dockerignore              # Docker构建忽略文件
└── scripts/
    └── init-db.sh              # 数据库初始化脚本
```

## 快速开始

### 1. 启动完整环境（推荐）

启动所有服务（PostgreSQL、Redis、应用）：

```powershell
docker-compose up -d
```

查看服务状态：

```powershell
docker-compose ps
```

查看日志：

```powershell
# 所有服务
docker-compose logs -f

# 仅应用服务
docker-compose logs -f app

# 仅数据库
docker-compose logs -f postgres
```

### 2. 停止服务

```powershell
docker-compose down
```

### 3. 清理所有数据

```powershell
# 停止并删除数据卷
docker-compose down -v
```

## 开发模式

### 方式一：仅使用Docker的数据库服务

如果你想在本地运行Go应用，但使用Docker的数据库：

```powershell
# 1. 启动PostgreSQL和Redis
docker-compose -f docker-compose.dev.yml up -d postgres redis

# 2. 在本地运行应用
go run cmd/server/main.go
```

应用会连接到Docker中的数据库服务。

### 方式二：完全Docker化

所有服务都在Docker中运行：

```powershell
docker-compose up -d
```

## 配置说明

### 环境变量

主要配置在 `docker-compose.yml` 的 `app` 服务中：

```yaml
environment:
  # 数据库连接（自动配置，指向postgres和redis服务）
  POSTGRES_DSN: "postgres://smartglasses:smartglasses123@postgres:5432/smart_glasses?sslmode=disable"
  REDIS_ADDR: "redis:6379"
  
  # Azure OpenAI（需要配置）
  AZURE_OPENAI_ENDPOINT: "${AZURE_OPENAI_ENDPOINT:-}"
  AZURE_OPENAI_API_KEY: "${AZURE_OPENAI_API_KEY:-}"
```

### 使用 .env 文件

创建 `.env` 文件来配置Azure OpenAI：

```bash
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

Docker Compose会自动读取 `.env` 文件。

### 自定义配置

创建 `docker-compose.override.yml` 来覆盖默认配置（此文件不会被git跟踪）：

```yaml
version: '3.8'
services:
  app:
    environment:
      JWT_SECRET_KEY: "my-custom-secret"
```

## 数据库管理

### 查看数据库

```powershell
# 进入PostgreSQL容器
docker-compose exec postgres psql -U smartglasses -d smart_glasses

# 或者使用外部工具连接
# Host: localhost
# Port: 5432
# User: smartglasses
# Password: smartglasses123
# Database: smart_glasses
```

### 运行迁移

迁移文件会自动在容器启动时执行（通过volume挂载）。

如果需要手动运行：

```powershell
docker-compose exec postgres psql -U smartglasses -d smart_glasses -f /docker-entrypoint-initdb.d/001_init.sql
```

### 备份数据库

```powershell
docker-compose exec postgres pg_dump -U smartglasses smart_glasses > backup.sql
```

### 恢复数据库

```powershell
docker-compose exec -T postgres psql -U smartglasses smart_glasses < backup.sql
```

## Redis管理

### 连接Redis

```powershell
# 进入Redis容器
docker-compose exec redis redis-cli

# 查看所有key
KEYS *

# 查看特定key
GET login_attempts:user@example.com
```

## 常见问题

### 1. 端口被占用

如果5432或6379端口被占用，修改 `docker-compose.yml` 中的端口映射：

```yaml
postgres:
  ports:
    - "5433:5432"  # 改为5433
```

### 2. 数据库连接失败

确保服务已启动：

```powershell
docker-compose ps
```

检查健康状态：

```powershell
docker-compose exec postgres pg_isready -U smartglasses
```

### 3. 应用无法启动

查看应用日志：

```powershell
docker-compose logs app
```

检查环境变量：

```powershell
docker-compose exec app env | grep POSTGRES
```

### 4. 数据持久化

数据存储在Docker volumes中：
- `postgres_data`: PostgreSQL数据
- `redis_data`: Redis数据

删除数据卷会清除所有数据：

```powershell
docker-compose down -v
```

### 5. 重新构建镜像

修改代码后需要重新构建：

```powershell
docker-compose build app
docker-compose up -d app
```

## 性能优化

### 开发环境

- 使用 `docker-compose.dev.yml` 仅启动数据库
- 在本地运行应用以获得更好的开发体验

### 生产环境

- 使用 `docker-compose.yml` 完整部署
- 配置适当的资源限制
- 使用外部数据库服务（如Azure Database）

## 安全建议

1. **更改默认密码**：修改 `docker-compose.yml` 中的数据库密码
2. **使用环境变量**：敏感信息通过 `.env` 文件管理
3. **限制网络访问**：生产环境不要暴露数据库端口
4. **定期备份**：设置数据库自动备份

## 下一步

- 查看 [README.md](README.md) 了解API使用
- 查看 [README-DEPLOYMENT.md](README-DEPLOYMENT.md) 了解Azure部署

