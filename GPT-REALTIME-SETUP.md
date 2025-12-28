# GPT Realtime API 语音对话功能开发指南

## 功能概述

本功能集成了 Azure OpenAI GPT Realtime API，实现了基于 WebRTC 的实时语音对话功能。用户可以通过网页直接与 GPT 进行语音交互，支持：

- 实时语音输入（麦克风采集）
- 实时语音输出（扬声器播放）
- 低延迟的语音到语音对话
- 中文语音交互

## 技术架构

### 前端技术栈
- **WebRTC**: 音频采集和播放
- **WebSocket**: 实时通信
- **Vue 3**: 用户界面
- **MediaRecorder API**: 音频录制
- **Web Audio API**: 音频处理

### 后端技术栈
- **Go + Gin**: WebSocket 服务器
- **Gorilla WebSocket**: WebSocket 连接管理
- **Azure OpenAI Realtime API**: GPT 语音对话服务

## 配置要求

### 1. Azure OpenAI 配置

需要在 `.env` 文件中配置以下环境变量：

```bash
# Azure OpenAI Realtime API 配置
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key
AZURE_OPENAI_API_VERSION=2024-10-01-preview
```

### 2. GPT-4o Realtime 模型部署

确保在 Azure OpenAI 服务中部署了 `gpt-4o-realtime-preview` 模型：

1. 登录 Azure Portal
2. 进入 Azure OpenAI 服务
3. 在"模型部署"中添加 `gpt-4o-realtime-preview` 模型
4. 记录部署名称（默认为 `gpt-4o-realtime-preview`）

## 项目结构

### 新增文件

```
smart-glasses-backend/
├── internal/
│   ├── handler/
│   │   └── realtime_handler.go      # WebSocket 处理器
│   └── service/
│       └── realtime_service.go      # GPT Realtime API 服务
└── frontend/
    └── src/
        └── pages/
            └── RealtimeChat.vue     # 语音对话界面
```

### 核心组件说明

#### 1. RealtimeHandler (后端)
- 处理客户端 WebSocket 连接
- 管理与 GPT Realtime API 的连接
- 转发音频数据和响应

#### 2. RealtimeService (后端)
- 封装 Azure OpenAI Realtime API 调用
- 处理音频格式转换
- 管理会话配置

#### 3. RealtimeChat.vue (前端)
- 语音录制和播放界面
- WebSocket 通信管理
- 音频级别可视化

## API 接口

### WebSocket 端点

```
ws://localhost:8080/api/v1/realtime/chat?token={jwt_token}
```

### 消息格式

#### 客户端发送消息

```json
// 音频数据
{
  "type": "audio_data",
  "audio": "base64_encoded_audio_data"
}

// 提交音频缓冲区
{
  "type": "commit_audio"
}
```

#### 服务器响应消息

```json
// 文本响应
{
  "type": "text_response",
  "text": "GPT 的文本回复"
}

// 音频响应
{
  "type": "audio_response",
  "audio": "base64_encoded_audio_data"
}

// 响应完成
{
  "type": "response_complete"
}

// 错误信息
{
  "type": "error",
  "error": "错误详情"
}
```

## 开发和测试

### 1. 启动后端服务

```bash
# 确保环境变量配置正确
cp .env.example .env
# 编辑 .env 文件，配置 Azure OpenAI 信息

# 启动服务
go run cmd/server/main.go
```

### 2. 启动前端开发服务器

```bash
cd frontend
npm install
npm run dev
```

### 3. 测试功能

1. 访问 `http://localhost:5173/realtime-chat`
2. 登录系统
3. 点击"开始录音"按钮
4. 对着麦克风说话
5. 点击"停止录音"等待 GPT 回复

## 音频格式说明

### 输入音频格式
- **采样率**: 16kHz
- **声道**: 单声道
- **格式**: PCM16
- **编码**: Base64

### 输出音频格式
- **采样率**: 16kHz  
- **声道**: 单声道
- **格式**: PCM16
- **编码**: Base64

## 性能优化建议

### 1. 音频处理优化
- 使用 100ms 的音频块进行实时传输
- 启用回声消除和噪声抑制
- 实现音频级别监控

### 2. 网络优化
- 使用 WebSocket 保持连接
- 实现断线重连机制
- 添加网络状态监控

### 3. 用户体验优化
- 添加录音状态可视化
- 实现音频级别显示
- 提供清晰的错误提示

## 故障排查

### 常见问题

#### 1. 无法连接到 GPT Realtime API
- 检查 Azure OpenAI 配置是否正确
- 确认 API 密钥有效
- 验证模型部署状态

#### 2. 麦克风权限问题
- 确保浏览器允许麦克风访问
- 检查系统麦克风权限设置
- 使用 HTTPS 协议（生产环境）

#### 3. 音频播放问题
- 检查浏览器音频权限
- 确认音频格式转换正确
- 验证 Web Audio API 支持

#### 4. WebSocket 连接失败
- 检查 JWT Token 是否有效
- 确认服务器 WebSocket 端点可访问
- 验证 CORS 配置

### 调试工具

#### 1. 浏览器开发者工具
```javascript
// 检查 WebSocket 连接状态
console.log(websocket.readyState)

// 监听音频设备
navigator.mediaDevices.enumerateDevices()
  .then(devices => console.log(devices))
```

#### 2. 服务器日志
```bash
# 查看实时日志
tail -f /var/log/smart-glasses-backend.log

# 过滤 WebSocket 相关日志
grep "WebSocket\|realtime" /var/log/smart-glasses-backend.log
```

## 安全考虑

### 1. 认证和授权
- 所有 WebSocket 连接需要有效 JWT Token
- 实现会话超时机制
- 添加请求频率限制

### 2. 数据保护
- 音频数据不在服务器存储
- 使用 HTTPS/WSS 加密传输
- 实现数据脱敏处理

### 3. 隐私保护
- 明确告知用户音频采集用途
- 提供音频数据删除选项
- 遵循相关隐私法规

## 部署注意事项

### 1. 生产环境配置
- 使用 HTTPS 协议
- 配置适当的 CORS 策略
- 启用 WebSocket 压缩

### 2. 负载均衡
- WebSocket 连接需要会话粘性
- 考虑使用 Redis 进行会话共享
- 实现健康检查机制

### 3. 监控和日志
- 添加 WebSocket 连接监控
- 记录音频处理性能指标
- 实现错误报警机制

## 后续开发计划

### Phase 1: 基础功能 ✅
- [x] WebSocket 连接管理
- [x] 音频录制和播放
- [x] GPT Realtime API 集成

### Phase 2: 功能增强
- [ ] 多语言支持
- [ ] 语音识别结果显示
- [ ] 对话历史记录
- [ ] 音频质量优化

### Phase 3: 高级功能
- [ ] 实时翻译功能
- [ ] 语音情感分析
- [ ] 多人语音会议
- [ ] 语音指令识别

## 参考资料

- [Azure OpenAI Realtime API 文档](https://learn.microsoft.com/en-us/azure/ai-services/openai/realtime-audio-quickstart)
- [WebRTC API 文档](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)
- [Web Audio API 文档](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [Gorilla WebSocket 文档](https://github.com/gorilla/websocket)