# API测试脚本使用指南

## 测试脚本说明

### 1. test-api.ps1 - 完整API测试脚本

测试所有REST API功能，包括：
- ✅ 健康检查
- ✅ 用户注册
- ✅ 用户登录
- ✅ 获取用户信息
- ✅ Token刷新
- ✅ 文本翻译（多个测试用例）
- ✅ 翻译历史

**使用方法：**

```powershell
# 使用默认参数
.\scripts\test-api.ps1

# 自定义参数
.\scripts\test-api.ps1 -BaseUrl "http://localhost:8080" -Email "myemail@example.com" -Password "MyPass123!" -Username "myuser"
```

### 2. test-websocket.ps1 - WebSocket测试说明

提供WebSocket测试的说明和Token获取。

**使用方法：**

```powershell
.\scripts\test-websocket.ps1
```

### 3. test-websocket.js - Node.js WebSocket测试脚本

完整的WebSocket流式翻译测试（需要Node.js）。

**使用方法：**

```powershell
# 需要先安装Node.js
node scripts/test-websocket.js
```

## 快速开始

### 前提条件

1. **确保服务正在运行**

```powershell
docker-compose ps
```

应该看到所有服务都是"Up"状态。

2. **检查服务健康状态**

```powershell
Invoke-WebRequest -Uri http://localhost:8080/health -UseBasicParsing
```

应该返回：`{"status":"ok"}`

### 运行测试

#### 方式一：运行完整测试（推荐）

```powershell
.\scripts\test-api.ps1
```

这会自动执行所有测试步骤。

#### 方式二：手动测试单个功能

**1. 注册用户**

```powershell
$body = @{
    username = "testuser"
    email = "test@example.com"
    password = "Test1234!"
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/v1/auth/register `
    -Method POST `
    -ContentType "application/json" `
    -Body $body `
    -UseBasicParsing
```

**2. 登录获取Token**

```powershell
$body = @{
    email = "test@example.com"
    password = "Test1234!"
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri http://localhost:8080/api/v1/auth/login `
    -Method POST `
    -ContentType "application/json" `
    -Body $body `
    -UseBasicParsing

$token = ($response.Content | ConvertFrom-Json).token
```

**3. 翻译文本**

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$body = @{
    text = "Hello, world!"
    source_language = "en"
    target_language = "zh"
} | ConvertTo-Json

Invoke-WebRequest -Uri http://localhost:8080/api/v1/translate/text `
    -Method POST `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $body `
    -UseBasicParsing
```

## 测试WebSocket

### 使用浏览器控制台

1. 先运行 `test-api.ps1` 获取Token
2. 打开浏览器开发者工具（F12）
3. 在控制台中运行：

```javascript
const token = 'YOUR_TOKEN_HERE';
const ws = new WebSocket('ws://localhost:8080/api/v1/translate/stream?token=' + token);

ws.onopen = () => {
  console.log('连接已建立');
  ws.send(JSON.stringify({
    type: 'translate',
    text: 'Hello, world!',
    source_language: 'en',
    target_language: 'zh'
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('收到消息:', data);
  if (data.is_complete) {
    console.log('翻译完成:', data.translated_text);
    ws.close();
  }
};

ws.onerror = (error) => {
  console.error('错误:', error);
};
```

### 使用Node.js脚本

```powershell
# 需要先安装Node.js
node scripts/test-websocket.js
```

## 常见问题

### 1. 测试失败：连接被拒绝

**原因：** 服务未启动

**解决：**
```powershell
docker-compose up -d
docker-compose ps
```

### 2. 翻译失败：Azure OpenAI错误

**原因：** Azure OpenAI未配置或配置错误

**解决：**
1. 检查 `.env` 文件中的Azure OpenAI配置
2. 确认API密钥和端点正确
3. 重启应用：`docker-compose restart app`

### 3. 用户已存在错误

**原因：** 测试用户已注册

**解决：**
- 脚本会自动处理，跳过注册继续测试
- 或使用不同的邮箱和用户名

### 4. Token无效

**原因：** Token过期或格式错误

**解决：**
- 重新运行登录测试获取新Token
- 检查Token格式是否正确（Bearer token）

## 测试结果解读

### 成功示例

```
✅ 服务器运行正常: ok
✅ 注册成功!
✅ 登录成功!
✅ 获取用户信息成功!
✅ Token刷新成功!
✅ 翻译完成: 你好，世界
✅ 获取翻译历史成功!
```

### 失败示例

```
❌ 翻译失败: Azure OpenAI API error
⚠️  提示: 请检查Azure OpenAI配置
```

## 性能测试

### 测试并发请求

可以修改脚本添加并发测试：

```powershell
# 在test-api.ps1中添加并发测试
1..10 | ForEach-Object -Parallel {
    # 并发翻译请求
} -ThrottleLimit 5
```

## 下一步

- 查看服务日志：`docker-compose logs -f app`
- 查看API文档：`README.md`
- 查看Docker使用说明：`DOCKER.md`

