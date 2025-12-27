# Docker镜像加速器配置指南

## 问题

在中国大陆访问Docker Hub可能很慢或无法访问，导致镜像拉取失败。

## 解决方案：配置镜像加速器

### 方法一：通过Docker Desktop GUI配置（推荐）

1. **打开Docker Desktop**
   - 右键点击系统托盘中的Docker图标
   - 选择 "Settings" 或 "设置"

2. **进入Docker Engine设置**
   - 点击左侧菜单的 "Docker Engine"
   - 或直接搜索 "Docker Engine"

3. **添加镜像加速器**
   在JSON配置中添加 `registry-mirrors` 字段：

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://dockerhub.azk8s.cn"
  ]
}
```

4. **应用并重启**
   - 点击右上角的 "Apply & Restart"
   - 等待Docker重启完成（约30秒）

5. **验证配置**
   ```powershell
   docker info | Select-String -Pattern "Registry Mirrors"
   ```
   
   应该看到配置的镜像地址。

### 方法二：直接编辑配置文件

如果GUI方式不工作，可以直接编辑配置文件：

1. **找到配置文件位置**
   - Windows: `%USERPROFILE%\.docker\daemon.json`
   - 或: `C:\Users\你的用户名\.docker\daemon.json`

2. **创建或编辑文件**
   ```json
   {
     "registry-mirrors": [
       "https://docker.mirrors.ustc.edu.cn",
       "https://hub-mirror.c.163.com",
       "https://mirror.baidubce.com"
     ]
   }
   ```

3. **重启Docker Desktop**

### 方法三：使用国内镜像源（临时方案）

如果镜像加速器仍然无法使用，可以使用我提供的国内镜像版本：

```powershell
# 使用国内镜像源的配置
docker-compose -f docker-compose.cn.yml up -d
```

## 推荐的镜像加速器

### 国内镜像源（按推荐顺序）

1. **中科大镜像**（推荐）
   ```
   https://docker.mirrors.ustc.edu.cn
   ```

2. **网易镜像**
   ```
   https://hub-mirror.c.163.com
   ```

3. **百度云镜像**
   ```
   https://mirror.baidubce.com
   ```

4. **Azure中国镜像**
   ```
   https://dockerhub.azk8s.cn
   ```

### 阿里云镜像（需要登录）

如果你有阿里云账号：
1. 登录 https://cr.console.aliyun.com/
2. 进入"镜像加速器"
3. 复制你的专属加速地址

## 验证配置

配置完成后，测试拉取镜像：

```powershell
# 测试拉取一个小镜像
docker pull hello-world

# 如果成功，尝试拉取项目需要的镜像
docker pull golang:1.21-alpine
docker pull postgres:15-alpine
docker pull redis:7-alpine
```

## 常见问题

### Q: 配置后仍然很慢？

A: 尝试：
1. 更换其他镜像源
2. 检查网络连接
3. 使用代理

### Q: 配置后无法启动Docker？

A: 检查JSON格式是否正确，确保：
- 使用双引号
- 最后一个元素后没有逗号
- 大括号匹配

### Q: 如何查看当前配置？

A: 运行：
```powershell
docker info
```

查找 "Registry Mirrors" 部分。

## 下一步

配置完成后，重新运行：

```powershell
docker-compose up -d
```

如果仍然有问题，可以使用国内镜像版本：

```powershell
docker-compose -f docker-compose.cn.yml up -d
```

