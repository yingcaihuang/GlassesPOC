# Docker完整部署指南

## 概述

现在前端和后端都已集成到Docker Compose中，无需本地npm或Go环境即可运行整个应用。

## 架构说明

```
┌─────────────────┐
│   Frontend      │  (Nginx + React) - 端口 3000
│   (Port 3000)   │
└────────┬────────┘
         │ /api → proxy
         ▼
┌─────────────────┐
│   Backend       │  (Go API) - 内部端口 8080
│   (Port 8080)   │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│Postgres│ │ Redis  │
└────────┘ └────────┘
```

## 快速启动

### 1. 启动所有服务

```bash
docker-compose up -d
```

这会启动：
- ✅ PostgreSQL 数据库
- ✅ Redis 缓存
- ✅ 后端API服务
- ✅ 前端Web应用

### 2. 查看服务状态

```bash
docker-compose ps
```

### 3. 访问应用

- **前端界面**: http://localhost:3000
- **后端API**: http://localhost:8080
- **健康检查**: http://localhost:8080/health

### 4. 查看日志

```bash
# 所有服务日志
docker-compose logs -f

# 仅前端日志
docker-compose logs -f frontend

# 仅后端日志
docker-compose logs -f app
```

## 服务说明

### Frontend (前端)
- **容器名**: smart-glasses-frontend
- **端口**: 3000 (映射到容器80)
- **技术**: React + Nginx
- **构建**: 多阶段构建（Node.js构建 + Nginx服务）

### Backend (后端)
- **容器名**: smart-glasses-app
- **端口**: 8080 (仅内部，不对外暴露)
- **技术**: Go + Gin
- **API路径**: /api/v1

### PostgreSQL
- **容器名**: smart-glasses-postgres
- **端口**: 5432
- **数据库**: smart_glasses
- **用户**: smartglasses / smartglasses123

### Redis
- **容器名**: smart-glasses-redis
- **端口**: 6379

## 构建和更新

### 首次构建

```bash
# 构建所有镜像
docker-compose build

# 启动服务
docker-compose up -d
```

### 更新前端代码

```bash
# 重新构建前端
docker-compose build frontend

# 重启前端服务
docker-compose up -d frontend
```

### 更新后端代码

```bash
# 重新构建后端
docker-compose build app

# 重启后端服务
docker-compose up -d app
```

### 完全重建

```bash
# 停止并删除所有容器
docker-compose down

# 重新构建并启动
docker-compose up -d --build
```

## 环境变量配置

创建 `.env` 文件配置Azure OpenAI：

```bash
# Azure OpenAI配置
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

然后重启服务：

```bash
docker-compose restart app
```

## 数据持久化

数据存储在Docker volumes中：
- `postgres_data`: PostgreSQL数据
- `redis_data`: Redis数据

### 备份数据库

```bash
docker-compose exec postgres pg_dump -U smartglasses smart_glasses > backup.sql
```

### 恢复数据库

```bash
docker-compose exec -T postgres psql -U smartglasses smart_glasses < backup.sql
```

### 清理所有数据

```bash
# 停止并删除所有数据
docker-compose down -v
```

## 生产环境部署

使用生产配置：

```bash
docker-compose -f docker-compose.prod.yml up -d
```

生产配置特点：
- 使用环境变量管理敏感信息
- 端口映射到80（前端）
- 自动重启策略
- 独立的数据卷

## 故障排查

### 前端无法访问

1. 检查前端容器是否运行：
   ```bash
   docker-compose ps frontend
   ```

2. 查看前端日志：
   ```bash
   docker-compose logs frontend
   ```

3. 检查端口是否被占用：
   ```bash
   netstat -ano | findstr :3000
   ```

### 后端API无法访问

1. 检查后端容器：
   ```bash
   docker-compose ps app
   ```

2. 查看后端日志：
   ```bash
   docker-compose logs app
   ```

3. 测试后端健康检查：
   ```bash
   docker-compose exec app wget -qO- http://localhost:8080/health
   ```

### API代理问题

前端通过Nginx代理访问后端：
- 前端请求: `/api/v1/auth/login`
- Nginx代理到: `http://app:8080/api/v1/auth/login`

如果代理失败，检查：
1. `frontend/nginx.conf` 配置
2. 网络连接：`docker-compose exec frontend ping app`

### 构建失败

1. **前端构建失败**:
   ```bash
   # 查看详细构建日志
   docker-compose build --no-cache frontend
   ```

2. **后端构建失败**:
   ```bash
   # 查看详细构建日志
   docker-compose build --no-cache app
   ```

3. **Go模块下载失败**:
   - 检查Dockerfile中的GOPROXY配置
   - 可能需要配置镜像加速器

## 性能优化

### 前端构建优化

前端使用多阶段构建，生产构建已优化：
- 代码压缩
- Tree shaking
- 静态资源缓存

### Nginx优化

Nginx配置已包含：
- Gzip压缩
- 静态资源缓存
- WebSocket支持

## 开发模式

如果需要开发模式（热重载），可以：

1. 仅启动数据库服务：
   ```bash
   docker-compose -f docker-compose.dev.yml up -d postgres redis
   ```

2. 在本地运行前端和后端：
   ```bash
   # 终端1: 运行后端
   go run cmd/server/main.go
   
   # 终端2: 运行前端
   cd frontend
   npm run dev
   ```

## 常用命令

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart frontend
docker-compose restart app

# 进入容器
docker-compose exec frontend sh
docker-compose exec app sh

# 查看资源使用
docker stats
```

## 下一步

- 配置HTTPS（生产环境）
- 设置域名和DNS
- 配置负载均衡（如需要）
- 设置监控和日志收集

