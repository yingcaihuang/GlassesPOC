# 智能眼镜后端应用 (Smart Glasses Backend)

智能眼镜后端应用POC，提供用户认证和实时翻译功能。

## 功能特性

- ✅ 用户注册、登录、JWT认证
- ✅ 基于Azure OpenAI的实时翻译服务
- ✅ RESTful API接口
- ✅ WebSocket实时通信（用于翻译流式传输）
- ✅ 翻译历史记录

## 技术栈

- **后端框架**: Go (Gin)
- **数据库**: PostgreSQL (用户数据) + Redis (缓存/会话)
- **AI服务**: Azure OpenAI (翻译功能)
- **认证**: JWT Token
- **实时通信**: WebSocket (Gorilla WebSocket)

## 项目结构

```
smart-glasses-backend/
├── cmd/
│   └── server/
│       └── main.go              # 应用入口
├── internal/
│   ├── config/                  # 配置管理
│   │   └── config.go
│   ├── handler/                 # HTTP处理器
│   │   ├── auth_handler.go
│   │   ├── user_handler.go
│   │   └── translate_handler.go
│   ├── service/                 # 业务逻辑层
│   │   ├── auth_service.go
│   │   ├── user_service.go
│   │   └── translate_service.go
│   ├── repository/              # 数据访问层
│   │   ├── user_repository.go
│   │   └── translate_repository.go
│   ├── model/                   # 数据模型
│   │   ├── user.go
│   │   └── translation.go
│   └── middleware/              # 中间件
│       ├── auth_middleware.go
│       ├── cors_middleware.go
│       └── logger_middleware.go
├── pkg/
│   ├── jwt/                     # JWT工具
│   │   └── jwt.go
│   ├── azure/                   # Azure OpenAI客户端
│   │   └── openai_client.go
│   └── database/                # 数据库连接
│       ├── postgres.go
│       └── redis.go
├── migrations/                   # 数据库迁移
│   └── 001_init.sql
├── configs/                     # 配置文件
│   └── config.yaml
├── go.mod
└── README.md
```

## 快速开始

### 前置要求

- Go 1.21+
- PostgreSQL 12+
- Redis 6+

### 安装依赖

```bash
go mod download
```

### 配置环境变量

创建 `.env` 文件或设置环境变量：

```bash
# 服务器配置
SERVER_PORT=8080
SERVER_ENV=development

# 数据库配置
POSTGRES_DSN=postgres://user:password@localhost:5432/smart_glasses?sslmode=disable
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=

# JWT配置
JWT_SECRET_KEY=your-secret-key-change-in-production
JWT_ACCESS_TOKEN_EXPIRY=1h
JWT_REFRESH_TOKEN_EXPIRY=168h

# Azure OpenAI配置
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

### 初始化数据库

```bash
# 创建数据库
createdb smart_glasses

# 运行迁移
psql -d smart_glasses -f migrations/001_init.sql
```

### 运行应用

```bash
go run cmd/server/main.go
```

服务器将在 `http://localhost:8080` 启动。

## API文档

### 认证相关API

#### 1. 用户注册

```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "username": "user123",
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**响应 (201)**:
```json
{
  "user_id": "uuid",
  "token": "jwt_token",
  "refresh_token": "refresh_token",
  "user": {
    "id": "uuid",
    "username": "user123",
    "email": "user@example.com"
  },
  "expires_in": 3600
}
```

#### 2. 用户登录

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**响应 (200)**:
```json
{
  "token": "jwt_token",
  "refresh_token": "refresh_token",
  "user": {
    "id": "uuid",
    "username": "user123",
    "email": "user@example.com"
  },
  "expires_in": 3600
}
```

#### 3. Token刷新

```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refresh_token": "refresh_token"
}
```

**响应 (200)**:
```json
{
  "token": "new_jwt_token"
}
```

#### 4. 获取用户信息

```http
GET /api/v1/user/profile
Authorization: Bearer {token}
```

**响应 (200)**:
```json
{
  "id": "uuid",
  "username": "user123",
  "email": "user@example.com"
}
```

### 翻译相关API

#### 1. 文本翻译

```http
POST /api/v1/translate/text
Authorization: Bearer {token}
Content-Type: application/json

{
  "text": "Hello, how are you?",
  "source_language": "en",
  "target_language": "zh"
}
```

**响应 (200)**:
```json
{
  "translated_text": "你好，你好吗？",
  "source_language": "en",
  "target_language": "zh"
}
```

#### 2. WebSocket流式翻译

**连接**:
```
ws://localhost:8080/api/v1/translate/stream?token={jwt_token}
```

**发送消息**:
```json
{
  "type": "translate",
  "text": "Hello world",
  "source_language": "en",
  "target_language": "zh"
}
```

**接收消息**:
```json
{
  "type": "translation_chunk",
  "translated_text": "你好",
  "is_complete": false
}
```

```json
{
  "type": "translation_complete",
  "translated_text": "你好世界",
  "is_complete": true
}
```

#### 3. 翻译历史

```http
GET /api/v1/translate/history?limit=20&offset=0
Authorization: Bearer {token}
```

**响应 (200)**:
```json
{
  "data": [
    {
      "id": "uuid",
      "source_text": "Hello",
      "translated_text": "你好",
      "source_language": "en",
      "target_language": "zh",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

## 安全设计

### 认证安全
- JWT Token过期时间：1小时
- 刷新Token过期时间：7天
- 密码最小长度：8位，包含大小写字母和数字
- 登录失败5次后锁定15分钟

### API安全
- HTTPS强制（生产环境）
- CORS配置
- 请求频率限制（建议在生产环境添加）
- 输入验证和清理

## 部署指南

### 使用 Docker Compose（推荐 - Windows开发环境）

这是最简单的方式来启动整个开发环境，包括PostgreSQL、Redis和应用服务。

#### 前置要求
- Docker Desktop for Windows
- 配置Azure OpenAI环境变量（可选，如果暂时没有可以先不配置）

#### 快速开始

1. **配置Azure OpenAI（可选）**

   创建 `.env` 文件（或直接在docker-compose.yml中修改）：
   ```bash
   AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
   AZURE_OPENAI_API_KEY=your-api-key
   AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
   AZURE_OPENAI_API_VERSION=2024-02-15-preview
   ```

2. **启动所有服务**

   ```bash
   docker-compose up -d
   ```

   这会启动：
   - PostgreSQL (端口 5432)
   - Redis (端口 6379)
   - 应用服务 (端口 8080)

3. **查看日志**

   ```bash
   # 查看所有服务日志
   docker-compose logs -f
   
   # 只查看应用日志
   docker-compose logs -f app
   ```

4. **停止服务**

   ```bash
   docker-compose down
   ```

5. **清理数据（删除所有数据卷）**

   ```bash
   docker-compose down -v
   ```

#### 仅启动数据库服务（本地开发应用）

如果你想在本地运行Go应用，但使用Docker的数据库服务：

```bash
# 启动PostgreSQL和Redis
docker-compose -f docker-compose.dev.yml up -d postgres redis

# 在本地运行应用
go run cmd/server/main.go
```

#### 重新构建应用镜像

```bash
docker-compose build app
docker-compose up -d app
```

### 本地开发（不使用Docker）

1. 安装依赖：`go mod download`
2. 配置环境变量（创建 `.env` 文件）
3. 初始化数据库
4. 运行：`go run cmd/server/main.go`

### 生产环境

#### Docker部署

使用提供的 `Dockerfile` 和 `docker-compose.yml`：

```bash
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d
```

#### Azure App Service部署

1. 创建Azure App Service实例
2. 配置环境变量
3. 使用GitHub Actions或Azure DevOps进行CI/CD
4. 参考 `README-DEPLOYMENT.md` 了解详细部署步骤

## 测试

### 使用curl测试API

```bash
# 注册
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"Test1234!"}'

# 登录
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test1234!"}'

# 翻译（替换TOKEN）
curl -X POST http://localhost:8080/api/v1/translate/text \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello","source_language":"en","target_language":"zh"}'
```

## 故障排查

### 常见问题

1. **数据库连接失败**
   - 检查PostgreSQL是否运行
   - 验证连接字符串是否正确
   - 确认数据库已创建

2. **Redis连接失败**
   - 检查Redis是否运行
   - 验证地址和密码配置

3. **Azure OpenAI调用失败**
   - 验证API密钥和端点配置
   - 检查部署名称是否正确
   - 确认API版本兼容性

4. **JWT Token无效**
   - 检查密钥配置
   - 验证Token是否过期
   - 确认请求头格式正确

## 开发计划

- [x] Phase 1: 基础框架
- [x] Phase 2: 用户认证
- [x] Phase 3: 翻译功能
- [ ] Phase 4: 测试和优化

## 许可证

MIT License

