# 快速开始指南 - Windows Docker Compose

## 一键启动（推荐）

### 1. 启动所有服务

```powershell
docker-compose up -d
```

这会启动：
- ✅ PostgreSQL 数据库 (端口 5432)
- ✅ Redis 缓存 (端口 6379)  
- ✅ 应用服务 (端口 8080)

### 2. 查看服务状态

```powershell
docker-compose ps
```

### 3. 查看应用日志

```powershell
docker-compose logs -f app
```

### 4. 测试API

打开浏览器访问：`http://localhost:8080/health`

应该看到：
```json
{"status":"ok"}
```

### 5. 停止服务

```powershell
docker-compose down
```

## 配置Azure OpenAI（可选）

如果没有Azure OpenAI配置，翻译功能将无法使用，但其他功能（注册、登录等）可以正常使用。

创建 `.env` 文件：

```bash
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-15-preview
```

然后重启应用：

```powershell
docker-compose restart app
```

## 使用PowerShell脚本

### 启动开发环境

```powershell
.\scripts\start-dev.ps1
```

### 停止开发环境

```powershell
.\scripts\stop-dev.ps1
```

### 清理所有数据

```powershell
.\scripts\clean-dev.ps1
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

### 3. 翻译文本（需要配置Azure OpenAI）

```powershell
curl -X POST http://localhost:8080/api/v1/translate/text `
  -H "Authorization: Bearer YOUR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{\"text\":\"Hello\",\"source_language\":\"en\",\"target_language\":\"zh\"}'
```

## 常见问题

### 端口被占用

如果5432、6379或8080端口被占用，修改 `docker-compose.yml` 中的端口映射。

### 数据库连接失败

确保服务已启动：
```powershell
docker-compose ps
```

查看PostgreSQL日志：
```powershell
docker-compose logs postgres
```

### 应用无法启动

查看应用日志：
```powershell
docker-compose logs app
```

检查环境变量：
```powershell
docker-compose exec app env
```

## 下一步

- 查看 [README.md](README.md) 了解完整API文档
- 查看 [DOCKER.md](DOCKER.md) 了解详细Docker使用说明
- 查看 [README-DEPLOYMENT.md](README-DEPLOYMENT.md) 了解Azure部署

