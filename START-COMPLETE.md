# 完整系统启动指南 🚀

## 一键启动（推荐）

前端和后端已完全集成到Docker Compose，无需本地npm或Go环境！

### 启动所有服务

```powershell
docker-compose up -d
```

这会自动：
1. ✅ 构建前端镜像（React + Nginx）
2. ✅ 构建后端镜像（Go应用）
3. ✅ 启动PostgreSQL数据库
4. ✅ 启动Redis缓存
5. ✅ 启动后端API服务
6. ✅ 启动前端Web应用

### 访问应用

- **前端界面**: http://localhost:3000
- **后端API**: http://localhost:8080
- **健康检查**: http://localhost:8080/health

### 查看服务状态

```powershell
docker-compose ps
```

应该看到4个服务都在运行：
- smart-glasses-postgres
- smart-glasses-redis
- smart-glasses-app (后端)
- smart-glasses-frontend (前端)

## 首次构建

如果是第一次运行，需要构建镜像：

```powershell
# 构建所有镜像（包括前端和后端）
docker-compose build

# 启动服务
docker-compose up -d
```

构建过程可能需要几分钟，特别是前端（需要下载npm依赖）。

## 查看日志

```powershell
# 查看所有服务日志
docker-compose logs -f

# 仅查看前端日志
docker-compose logs -f frontend

# 仅查看后端日志
docker-compose logs -f app
```

## 测试应用

### 1. 访问前端

打开浏览器：http://localhost:3000

### 2. 注册/登录

- 注册新账户
- 或使用测试账户：
  - 邮箱: `test@example.com`
  - 密码: `Test1234!`

### 3. 使用功能

- ✅ 查看仪表盘
- ✅ 进行文本翻译
- ✅ 查看翻译历史
- ✅ 管理用户信息

## 架构说明

```
用户浏览器
    ↓
http://localhost:3000 (前端 - Nginx)
    ↓ /api → proxy
http://app:8080 (后端 - Go API)
    ↓
PostgreSQL + Redis
```

前端通过Nginx反向代理访问后端API，所有请求都通过 `/api` 路径自动转发。

## 更新代码

### 更新前端

```powershell
# 重新构建前端
docker-compose build frontend

# 重启前端服务
docker-compose up -d frontend
```

### 更新后端

```powershell
# 重新构建后端
docker-compose build app

# 重启后端服务
docker-compose up -d app
```

### 完全重建

```powershell
# 停止所有服务
docker-compose down

# 重新构建并启动
docker-compose up -d --build
```

## 环境变量配置

创建 `.env` 文件配置Azure OpenAI：

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

## 停止服务

```powershell
# 停止所有服务（保留数据）
docker-compose down

# 停止并删除所有数据
docker-compose down -v
```

## 故障排查

### 前端无法访问

1. 检查前端容器：
   ```powershell
   docker-compose ps frontend
   ```

2. 查看前端日志：
   ```powershell
   docker-compose logs frontend
   ```

3. 检查端口占用：
   ```powershell
   netstat -ano | findstr :3000
   ```

### 后端API无法访问

1. 检查后端容器：
   ```powershell
   docker-compose ps app
   ```

2. 查看后端日志：
   ```powershell
   docker-compose logs app
   ```

### 构建失败

1. **前端构建失败**:
   - 检查网络连接（需要下载npm包）
   - 查看详细日志：`docker-compose build --no-cache frontend`

2. **后端构建失败**:
   - 检查Go模块下载
   - 查看详细日志：`docker-compose build --no-cache app`

### API代理问题

前端通过Nginx代理访问后端。如果API请求失败：

1. 检查nginx配置：`frontend/nginx.conf`
2. 测试网络连接：
   ```powershell
   docker-compose exec frontend ping app
   ```

## 生产环境

使用生产配置：

```powershell
docker-compose -f docker-compose.prod.yml up -d
```

生产配置特点：
- 前端端口映射到80
- 使用环境变量管理敏感信息
- 自动重启策略

## 常用命令

```powershell
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

1. ✅ 启动服务：`docker-compose up -d`
2. ✅ 访问前端：http://localhost:3000
3. ✅ 注册/登录账户
4. ✅ 开始使用！

## 优势

- ✅ **无需本地环境**：不需要安装npm、Node.js、Go
- ✅ **一键启动**：所有服务自动配置和启动
- ✅ **隔离环境**：每个服务在独立容器中运行
- ✅ **易于部署**：可以轻松部署到任何支持Docker的环境
- ✅ **数据持久化**：数据存储在Docker volumes中

享受使用！🎉

