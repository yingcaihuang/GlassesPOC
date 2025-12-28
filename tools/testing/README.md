# 测试工具说明

## 文件说明

### 本地测试文件 (tools/testing/)

这些文件是开发和调试时使用的本地测试工具，**不会打包进Docker镜像**：

#### `test-connection.html`
- **用途**: 原始的连接测试工具
- **使用方式**: 直接在浏览器中打开文件
- **功能**: 测试基本的HTTP连接和API端点

#### `test-connection-fixed.html`  
- **用途**: 修复网络问题后的验证工具
- **使用方式**: 直接在浏览器中打开文件
- **功能**: 验证修复后的系统连接状态

### 在线测试页面 (frontend/public/)

这些文件会打包进前端Docker镜像，通过nginx提供访问：

#### `test-connection.html`
- **访问地址**: http://localhost:3000/test-connection.html
- **用途**: 在线系统连接测试
- **功能**: 
  - 完整的系统连接测试
  - 浏览器兼容性检查
  - API端点验证
  - 实时测试结果显示

#### `test-realtime.html`
- **访问地址**: http://localhost:3000/test-realtime.html  
- **用途**: GPT实时语音功能测试
- **功能**:
  - WebSocket连接测试
  - 麦克风权限检查
  - 音频录制测试
  - 实时语音对话测试

#### `test-webrtc.html`
- **访问地址**: http://localhost:3000/test-webrtc.html
- **用途**: WebRTC功能测试
- **功能**:
  - WebRTC API支持检查
  - 媒体设备访问测试
  - 音频流处理测试

## 使用建议

### 开发阶段
1. 使用本地测试文件 (`tools/testing/`) 进行快速调试
2. 直接在浏览器中打开HTML文件，无需启动Docker

### 部署后测试
1. 使用在线测试页面进行完整的系统验证
2. 访问 http://localhost:3000/test-connection.html 进行全面测试
3. 根据测试结果诊断和解决问题

### 生产环境
- 在线测试页面可以保留，用于运维监控和故障诊断
- 如需移除，可以从 `frontend/public/` 目录删除相关文件

## 测试页面访问

### 在线测试页面 (通过 Docker 访问)

所有测试页面都可以通过浏览器访问：

## 测试账号信息

**重要**: 所有测试页面使用以下统一的测试账号：

- **邮箱**: `betty@123.com`
- **密码**: `Betty@123.com` (注意大小写！)

### 常见问题
- ❌ 错误密码: `123456` 
- ✅ 正确密码: `Betty@123.com`

#### 🔧 系统连接测试
- **访问地址**: http://localhost:3000/test-connection.html
- **用途**: 完整的系统连接测试
- **功能**: 
  - 健康检查验证
  - API端点测试
  - 浏览器兼容性检查
  - 登录功能测试 (使用 betty@123.com / Betty@123.com)

#### 🎤 实时语音测试  
- **访问地址**: http://localhost:3000/test-realtime.html
- **用途**: GPT实时语音功能测试
- **功能**:
  - WebSocket连接测试
  - 麦克风权限检查
  - 音频录制测试
  - 实时语音对话测试

#### 🏠 主应用
- **访问地址**: http://localhost:3000/
- **用途**: 完整的智能眼镜管理后台

#### ⚕️ 健康检查
- **访问地址**: http://localhost:3000/health
- **用途**: 系统健康状态检查

## 故障排除

如果测试失败，请参考：
- [REALTIME-TROUBLESHOOTING.md](../../REALTIME-TROUBLESHOOTING.md) - 详细故障排除指南
- [FIX-NETWORK-ISSUE-REPORT.md](../../FIX-NETWORK-ISSUE-REPORT.md) - 网络问题修复报告

## 文件维护

- **本地测试文件**: 仅用于开发，可以随时修改和删除
- **在线测试页面**: 需要重新构建前端镜像才能更新
- **更新在线页面**: 修改后运行 `docker-compose build frontend && docker-compose restart frontend`