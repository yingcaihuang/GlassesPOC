# 解决Docker网络问题

## 当前问题

镜像加速器已配置，但连接不稳定（EOF错误）。

## 解决方案

### 方案一：测试并修复镜像加速器（推荐）

1. **测试镜像加速器是否工作**

```powershell
# 测试拉取一个小镜像
docker pull hello-world

# 如果成功，尝试拉取项目需要的镜像
docker pull golang:1.21-alpine
docker pull alpine:latest
docker pull postgres:15-alpine
docker pull redis:7-alpine
```

2. **如果仍然失败，尝试更换镜像加速器**

编辑Docker Desktop设置，尝试其他镜像源：

```json
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
```

3. **重启Docker Desktop**

### 方案二：使用VPN或代理

如果有VPN或代理：
1. 打开Docker Desktop设置
2. 进入 "Resources" → "Proxies"
3. 配置HTTP/HTTPS代理

### 方案三：分步拉取镜像

如果网络不稳定，可以分步拉取：

```powershell
# 1. 先拉取基础镜像
docker pull golang:1.21-alpine
docker pull alpine:latest

# 2. 再拉取数据库镜像
docker pull postgres:15-alpine
docker pull redis:7-alpine

# 3. 然后构建应用
docker-compose build app

# 4. 最后启动所有服务
docker-compose up -d
```

### 方案四：仅使用数据库服务（最简单）

如果应用构建有问题，可以：
1. 只启动数据库服务（已经在运行）
2. 在本地运行应用

```powershell
# 数据库服务已经在运行（docker-compose.dev.yml）
# 只需在本地运行应用
go run cmd/server/main.go
```

这是最简单的开发方式！

## 推荐方案

**对于开发环境，推荐使用方案四**：
- ✅ 数据库在Docker中（已运行）
- ✅ 应用在本地运行（快速开发、热重载）
- ✅ 无需构建Docker镜像
- ✅ 避免网络问题

## 验证当前状态

检查数据库服务是否正在运行：

```powershell
docker-compose -f docker-compose.dev.yml ps
```

如果看到postgres和redis都是"healthy"，就可以直接在本地运行应用了！

