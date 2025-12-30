# HTTPS 配置指南 - 解决麦克风权限问题

## 问题说明

在生产环境中，现代浏览器要求 HTTPS 连接才能访问麦克风等敏感设备。如果你看到以下错误：

- `Cannot read properties of undefined (reading 'getUserMedia')`
- `麦克风权限被拒绝`
- `需要安全连接`

这表明你需要配置 HTTPS。

## 解决方案

### 方案 1: 使用 Nginx 反向代理 + Let's Encrypt (推荐)

#### 1. 安装 Nginx 和 Certbot

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install nginx certbot python3-certbot-nginx
```

#### 2. 配置 Nginx

创建 `/etc/nginx/sites-available/smart-glasses`:

```nginx
server {
    listen 80;
    server_name your-domain.com;  # 替换为你的域名
    
    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;  # 替换为你的域名
    
    # SSL 证书路径 (Let's Encrypt 会自动配置)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # 前端代理
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 后端 API 代理
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSocket 代理
    location /api/v1/realtime/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

#### 3. 启用配置

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/smart-glasses /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

#### 4. 获取 SSL 证书

```bash
# 使用 Let's Encrypt 获取免费 SSL 证书
sudo certbot --nginx -d your-domain.com

# 设置自动续期
sudo crontab -e
# 添加以下行：
0 12 * * * /usr/bin/certbot renew --quiet
```

### 方案 2: 使用 Cloudflare (简单快速)

#### 1. 注册 Cloudflare 账户
- 访问 [cloudflare.com](https://cloudflare.com)
- 添加你的域名

#### 2. 配置 DNS
- 将你的域名 A 记录指向服务器 IP
- 启用 Cloudflare 代理 (橙色云朵图标)

#### 3. 配置 SSL
- 在 Cloudflare 面板中，SSL/TLS → 概述
- 选择 "完全" 或 "完全(严格)" 模式

#### 4. 更新应用配置
不需要修改 Nginx 配置，Cloudflare 会自动处理 HTTPS。

### 方案 3: 自签名证书 (仅用于测试)

#### 1. 生成自签名证书

```bash
# 创建证书目录
sudo mkdir -p /etc/ssl/certs
sudo mkdir -p /etc/ssl/private

# 生成私钥和证书
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/smart-glasses.key \
    -out /etc/ssl/certs/smart-glasses.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=your-server-ip"
```

#### 2. 配置 Nginx

```nginx
server {
    listen 443 ssl;
    server_name your-server-ip;
    
    ssl_certificate /etc/ssl/certs/smart-glasses.crt;
    ssl_certificate_key /etc/ssl/private/smart-glasses.key;
    
    # 其他配置同方案 1
}
```

#### 3. 浏览器设置
- 访问 `https://your-server-ip`
- 点击 "高级" → "继续访问"
- 接受自签名证书

## 更新部署配置

### 1. 更新前端环境变量

如果使用 HTTPS，更新前端构建配置：

```bash
# 构建时使用 HTTPS URL
export SERVER_HOST=your-domain.com
export VITE_API_URL=https://your-domain.com/api/v1
./scripts/build-and-push-images.sh
```

### 2. 更新 Docker Compose

如果使用 Nginx 容器：

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - frontend
      - app
```

## 验证配置

### 1. 检查 HTTPS 连接

```bash
# 测试 HTTPS 连接
curl -I https://your-domain.com

# 检查 SSL 证书
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

### 2. 测试 WebSocket

```bash
# 测试 WSS 连接
curl -I -H "Connection: Upgrade" -H "Upgrade: websocket" \
    https://your-domain.com/api/v1/realtime/chat
```

### 3. 浏览器测试

1. 访问 `https://your-domain.com`
2. 检查地址栏是否显示锁图标
3. 测试麦克风权限是否正常

## 故障排除

### 证书问题

```bash
# 检查证书有效期
sudo certbot certificates

# 手动续期
sudo certbot renew

# 测试续期
sudo certbot renew --dry-run
```

### Nginx 配置问题

```bash
# 检查 Nginx 配置
sudo nginx -t

# 查看 Nginx 日志
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### WebSocket 连接问题

```bash
# 检查后端服务
curl http://localhost:8080/health

# 检查端口监听
sudo netstat -tlnp | grep :8080
```

## 安全建议

1. **定期更新证书**: 设置自动续期
2. **使用强密码套件**: 配置现代 SSL 设置
3. **启用 HSTS**: 强制 HTTPS 连接
4. **配置防火墙**: 只开放必要端口

```nginx
# 添加安全头
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
```

## 成本考虑

- **Let's Encrypt**: 免费
- **Cloudflare**: 免费套餐足够使用
- **商业证书**: $50-200/年
- **自签名证书**: 免费 (仅用于测试)

配置 HTTPS 后，麦克风权限问题应该得到解决，用户可以正常使用语音功能。