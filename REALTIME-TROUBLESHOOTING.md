# GPT Realtime WebRTC 故障排除指南

## ✅ 最新更新：连接问题已解决 (2025-12-28)

**问题**：HTTP请求挂起，用户无法登录，显示"网络连接出现问题"

**根本原因**：
1. 性能监控服务中的循环依赖导致mutex死锁
2. 安全中间件同步日志记录造成请求阻塞

**解决方案**：
1. 修复了 `SystemMetricsCollector` 和 `PerformanceMonitor` 之间的循环依赖
2. 将安全中间件的日志记录改为异步执行
3. 重新启用了完整的安全监控功能

**验证**：
- ✅ 健康检查端点正常响应
- ✅ 前端应用可以正常访问
- ✅ 用户登录功能恢复正常
- ✅ WebSocket连接正常建立

**测试页面**：[test-connection-fixed.html](./test-connection-fixed.html)

---

## 问题现象
界面显示"网络连接出现问题，正在尝试重新连接..."，无法使用语音功能。

## 解决步骤

### 1. 检查服务状态
```bash
# 检查所有容器是否正常运行
docker-compose ps

# 应该看到所有服务都是 "Up" 状态
```

### 2. 访问测试页面
在浏览器中打开以下地址进行测试：

**主应用**: http://localhost:3000
**测试页面**: http://localhost:3000/test-realtime.html

### 3. 使用测试页面诊断问题

测试页面会自动进行以下检查：
1. **健康检查** - 验证后端服务是否正常
2. **登录测试** - 获取有效的认证 token
3. **WebSocket 测试** - 验证实时连接是否正常

### 4. 常见问题和解决方案

#### 问题 1: "请先登录后再使用语音功能"
**原因**: 用户未登录或 token 已过期
**解决方案**:
1. 访问 http://localhost:3000/login
2. 使用测试账号登录:
   - 邮箱: `betty@123.com`
   - 密码: `Betty@123.com`
3. 登录成功后再访问语音功能

#### 问题 2: "连接超时，请检查网络连接"
**原因**: WebSocket 连接无法建立
**解决方案**:
1. 检查 Docker 服务是否正常运行
2. 重启 Docker 服务:
   ```bash
   docker-compose restart
   ```
3. 检查防火墙设置

#### 问题 3: "认证失败，请重新登录"
**原因**: JWT token 无效或已过期
**解决方案**:
1. 清除浏览器缓存和 localStorage
2. 重新登录获取新的 token

#### 问题 4: 麦克风权限问题
**现象**: 点击"开始录音"后没有反应
**解决方案**:
1. 检查浏览器地址栏是否有麦克风图标
2. 点击麦克风图标，选择"允许"
3. 如果没有弹出权限请求，在浏览器设置中手动允许麦克风权限

### 5. 浏览器兼容性

**推荐浏览器**:
- Chrome 80+
- Firefox 75+
- Safari 13+
- Edge 80+

**不支持的浏览器**:
- Internet Explorer (任何版本)
- 旧版本的移动浏览器

### 6. 开发者调试

如果问题仍然存在，请打开浏览器开发者工具：

1. **按 F12 打开开发者工具**
2. **查看 Console 标签页** - 检查 JavaScript 错误
3. **查看 Network 标签页** - 检查网络请求状态
4. **查看 WebSocket 连接** - 在 Network 标签页中筛选 WS 类型

### 7. 日志检查

检查后端服务日志：
```bash
# 查看后端日志
docker logs smart-glasses-app --tail 50

# 查看前端日志
docker logs smart-glasses-frontend --tail 50
```

### 8. 完全重置

如果所有方法都无效，尝试完全重置：

```bash
# 停止所有服务
docker-compose down

# 清理 Docker 资源
docker system prune -f

# 重新构建并启动
docker-compose up -d --build
```

### 9. 环境变量检查

确保 `.env` 文件包含正确的 Azure OpenAI 配置：

```env
AZURE_OPENAI_REALTIME_ENDPOINT=https://your-endpoint.cognitiveservices.azure.com
AZURE_OPENAI_REALTIME_API_KEY=your-api-key
AZURE_OPENAI_REALTIME_DEPLOYMENT_NAME=gpt-realtime
AZURE_OPENAI_REALTIME_API_VERSION=2025-08-28
```

### 10. 网络配置

如果在企业网络或有代理的环境中：

1. 检查是否有防火墙阻止 WebSocket 连接
2. 确保端口 3000 和 8080 可以访问
3. 如果使用代理，可能需要配置 WebSocket 代理

## 成功指标

当系统正常工作时，您应该看到：

1. ✅ 健康检查返回 `{"status": "ok"}`
2. ✅ 登录成功并获得 token
3. ✅ WebSocket 连接成功建立
4. ✅ 点击"开始录音"时浏览器请求麦克风权限
5. ✅ 录音时显示音频波形可视化
6. ✅ 连接状态显示为"已连接"

## 联系支持

如果问题仍然存在，请提供以下信息：

1. 浏览器类型和版本
2. 操作系统版本
3. Docker 版本
4. 浏览器开发者工具中的错误信息
5. 后端服务日志
6. 测试页面的测试结果

## 快速测试命令

```bash
# 一键诊断脚本
./diagnose-connection.sh

# 检查服务状态
docker-compose ps

# 重启服务
docker-compose restart

# 查看日志
docker logs smart-glasses-app --tail 20
```