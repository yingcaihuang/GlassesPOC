# 快速启动指南 🚀

## 一键启动完整系统

前端和后端已完全集成到Docker Compose，**无需本地npm或Go环境**！

### 启动命令

```powershell
# 构建并启动所有服务（首次运行）
docker-compose up -d --build

# 或如果镜像已构建，直接启动
docker-compose up -d
```

### 访问应用

启动成功后，访问：
- **前端界面**: http://localhost:3000
- **后端API**: http://localhost:8080/health

### 查看服务状态

```powershell
docker-compose ps
```

应该看到4个服务：
- ✅ smart-glasses-postgres (数据库)
- ✅ smart-glasses-redis (缓存)
- ✅ smart-glasses-app (后端API)
- ✅ smart-glasses-frontend (前端界面)

## 服务说明

| 服务 | 容器名 | 端口 | 说明 |
|------|--------|------|------|
| 前端 | smart-glasses-frontend | 3000 | React + Nginx |
| 后端 | smart-glasses-app | 8080 | Go API (内部) |
| 数据库 | smart-glasses-postgres | 5432 | PostgreSQL |
| 缓存 | smart-glasses-redis | 6379 | Redis |

## 首次使用

1. **启动服务**
   ```powershell
   docker-compose up -d --build
   ```

2. **等待构建完成**（首次可能需要5-10分钟）

3. **访问前端**
   - 打开浏览器：http://localhost:3000

4. **注册账户**
   - 点击"注册"
   - 填写用户名、邮箱、密码
   - 密码要求：至少8位，包含大小写字母和数字

5. **开始使用**
   - 查看仪表盘
   - 进行文本翻译
   - 查看翻译历史

## 常用命令

```powershell
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 查看日志
docker-compose logs -f

# 仅查看前端日志
docker-compose logs -f frontend

# 仅查看后端日志
docker-compose logs -f app

# 重启服务
docker-compose restart frontend
docker-compose restart app

# 重新构建前端
docker-compose build frontend
docker-compose up -d frontend

# 重新构建后端
docker-compose build app
docker-compose up -d app
```

## 配置Azure OpenAI（可选）

如果需要使用翻译功能，创建 `.env` 文件：

```bash
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

然后重启后端：

```powershell
docker-compose restart app
```

## 故障排查

### 构建失败（网络问题）

如果遇到Docker镜像拉取失败：

1. **配置Docker镜像加速器**（参考 `SETUP-DOCKER-MIRROR.md`）

2. **或手动拉取镜像**：
   ```powershell
   docker pull node:20-alpine
   docker pull nginx:alpine
   docker pull golang:1.21-alpine
   docker pull postgres:15-alpine
   docker pull redis:7-alpine
   ```

### 端口被占用

如果3000或8080端口被占用，修改 `docker-compose.yml` 中的端口映射。

### 服务无法启动

1. 查看日志：
   ```powershell
   docker-compose logs [service-name]
   ```

2. 检查服务状态：
   ```powershell
   docker-compose ps
   ```

3. 重启服务：
   ```powershell
   docker-compose restart [service-name]
   ```

## 架构说明

```
浏览器 → http://localhost:3000 (前端Nginx)
              ↓ /api → proxy
         http://app:8080 (后端Go API)
              ↓
    PostgreSQL + Redis
```

前端通过Nginx反向代理自动转发 `/api` 请求到后端。

## 数据持久化

- 数据库数据：存储在 `postgres_data` volume
- Redis数据：存储在 `redis_data` volume

数据不会因为容器重启而丢失。

## 清理

```powershell
# 停止并删除容器（保留数据）
docker-compose down

# 停止并删除所有数据
docker-compose down -v
```

## 下一步

- 查看详细文档：`DOCKER-COMPLETE.md`
- 查看前端文档：`frontend/README.md`
- 查看API文档：`README.md`

---

**提示**：首次构建可能需要较长时间（下载依赖），请耐心等待。后续启动会很快！

