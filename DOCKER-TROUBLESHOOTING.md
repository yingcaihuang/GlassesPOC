# Docker 故障排查指南

## 问题：无法拉取Docker镜像

### 错误信息
```
failed to resolve source metadata for docker.io/library/golang:1.21-alpine: failed to do request
```

### 解决方案

#### 方案一：配置Docker镜像加速器（推荐 - 中国用户）

1. **打开Docker Desktop设置**
   - 右键点击系统托盘中的Docker图标
   - 选择 "Settings" 或 "设置"

2. **配置镜像加速器**
   - 进入 "Docker Engine"
   - 在JSON配置中添加以下内容：

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

3. **应用并重启**
   - 点击 "Apply & Restart"
   - 等待Docker重启完成

4. **验证配置**
   ```powershell
   docker info | Select-String -Pattern "Registry Mirrors"
   ```

#### 方案二：使用代理

如果你有代理，可以在Docker Desktop中配置：
- Settings → Resources → Proxies
- 配置HTTP/HTTPS代理

#### 方案三：手动拉取镜像

```powershell
# 尝试手动拉取镜像
docker pull golang:1.21-alpine
docker pull alpine:latest
docker pull postgres:15-alpine
docker pull redis:7-alpine
```

#### 方案四：使用国内镜像源构建

修改 `Dockerfile` 使用国内镜像源（见下方）

## 其他常见问题

### 问题：Docker Desktop未运行

**错误**：
```
error during connect: Get "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine"
```

**解决**：
1. 启动 Docker Desktop
2. 等待Docker完全启动（系统托盘图标不再闪烁）

### 问题：端口被占用

**错误**：
```
Bind for 0.0.0.0:8080 failed: port is already allocated
```

**解决**：
1. 查找占用端口的进程：
   ```powershell
   netstat -ano | findstr :8080
   ```
2. 停止占用端口的服务，或修改 `docker-compose.yml` 中的端口映射

### 问题：磁盘空间不足

**解决**：
```powershell
# 清理未使用的镜像和容器
docker system prune -a

# 清理数据卷（谨慎使用，会删除数据）
docker volume prune
```

### 问题：权限问题

**解决**：
- 确保以管理员身份运行PowerShell
- 或在Docker Desktop设置中启用WSL 2集成

## 验证Docker环境

运行以下命令验证Docker是否正常工作：

```powershell
# 检查Docker版本
docker --version

# 检查Docker Compose版本
docker-compose --version

# 测试拉取镜像
docker pull hello-world
docker run hello-world
```

## 获取帮助

如果问题仍然存在：
1. 查看Docker Desktop日志
2. 检查网络连接
3. 尝试重启Docker Desktop
4. 查看Docker官方文档

