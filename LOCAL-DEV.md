# 本地开发指南

## 当前状态

✅ PostgreSQL 和 Redis 服务已在 Docker 中运行
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`

## 下一步：在本地运行应用

### 1. 配置环境变量

创建 `.env` 文件（如果还没有）：

```bash
# 服务器配置
SERVER_PORT=8080
SERVER_ENV=development

# 数据库配置（连接到Docker中的服务）
POSTGRES_DSN=postgres://smartglasses:smartglasses123@localhost:5432/smart_glasses?sslmode=disable
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=

# JWT配置
JWT_SECRET_KEY=dev-secret-key-change-in-production
JWT_ACCESS_TOKEN_EXPIRY=1h
JWT_REFRESH_TOKEN_EXPIRY=168h

# Azure OpenAI配置（可选）
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

### 2. 运行应用

```powershell
go run cmd/server/main.go
```

### 3. 测试应用

打开浏览器或使用curl：

```powershell
# 健康检查
curl http://localhost:8080/health

# 应该返回: {"status":"ok"}
```

## 开发工作流

### 启动数据库服务

```powershell
docker-compose -f docker-compose.dev.yml up -d postgres redis
```

### 停止数据库服务

```powershell
docker-compose -f docker-compose.dev.yml down
```

### 查看数据库日志

```powershell
docker-compose -f docker-compose.dev.yml logs -f postgres
```

### 连接数据库（使用psql）

```powershell
docker-compose -f docker-compose.dev.yml exec postgres psql -U smartglasses -d smart_glasses
```

### 查看表结构

```powershell
# 在psql中执行
\dt                    # 列出所有表
\d users              # 查看users表结构
\d translation_history # 查看translation_history表结构
```

## 数据库管理

### 重置数据库（删除所有数据）

```powershell
# 停止服务并删除数据卷
docker-compose -f docker-compose.dev.yml down -v

# 重新启动（会自动运行迁移）
docker-compose -f docker-compose.dev.yml up -d postgres redis
```

### 手动运行迁移

```powershell
docker-compose -f docker-compose.dev.yml exec postgres psql -U smartglasses -d smart_glasses -f /docker-entrypoint-initdb.d/001_init.sql
```

## 测试API

### 1. 注册用户

```powershell
curl -X POST http://localhost:8080/api/v1/auth/register `
  -H "Content-Type: application/json" `
  -d '{\"username\":\"testuser\",\"email\":\"test@example.com\",\"password\":\"Test1234!\"}'
```

### 2. 登录

```powershell
curl -X POST http://localhost:8080/api/v1/auth/login `
  -H "Content-Type: application/json" `
  -d '{\"email\":\"test@example.com\",\"password\":\"Test1234!\"}'
```

保存返回的 `token`。

### 3. 获取用户信息

```powershell
curl -X GET http://localhost:8080/api/v1/user/profile `
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 4. 翻译文本（需要配置Azure OpenAI）

```powershell
curl -X POST http://localhost:8080/api/v1/translate/text `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{\"text\":\"Hello\",\"source_language\":\"en\",\"target_language\":\"zh\"}'
```

## 常见问题

### 应用无法连接数据库

1. 确认数据库服务正在运行：
   ```powershell
   docker-compose -f docker-compose.dev.yml ps
   ```

2. 检查连接字符串是否正确（注意端口是5432）

3. 测试连接：
   ```powershell
   docker-compose -f docker-compose.dev.yml exec postgres psql -U smartglasses -d smart_glasses -c "SELECT 1;"
   ```

### 端口被占用

如果8080端口被占用，修改 `.env` 文件中的 `SERVER_PORT`。

### 修改代码后需要重启

使用 `Ctrl+C` 停止应用，然后重新运行 `go run cmd/server/main.go`。

## 优势

使用这种开发方式的优势：
- ✅ 快速启动：数据库在Docker中，无需本地安装
- ✅ 隔离环境：不影响本地PostgreSQL/Redis安装
- ✅ 易于重置：可以快速清理和重建数据库
- ✅ 热重载：修改代码后立即生效（Go的编译特性）

