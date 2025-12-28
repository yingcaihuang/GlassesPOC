# 智能眼镜管理后台 - 前端

现代化的React + TypeScript管理界面，用于管理用户、进行翻译和查看翻译历史。

## 功能特性

- ✅ 用户认证（登录/注册）
- ✅ 仪表盘统计
- ✅ 文本翻译（支持多语言）
- ✅ 翻译历史查看
- ✅ 用户信息管理
- ✅ 响应式设计
- ✅ 现代化UI（Tailwind CSS）

## 技术栈

- **框架**: React 18 + TypeScript
- **构建工具**: Vite
- **样式**: Tailwind CSS
- **路由**: React Router v6
- **HTTP客户端**: Axios
- **图标**: Lucide React
- **日期处理**: date-fns

## 快速开始

### 安装依赖

```bash
cd frontend
npm install
```

### 配置环境变量

创建 `.env` 文件：

```bash
VITE_API_URL=http://localhost:8080/api/v1
```

### 启动开发服务器

```bash
npm run dev
```

应用将在 `http://localhost:3000` 启动。

### 构建生产版本

```bash
npm run build
```

构建文件将输出到 `dist` 目录。

## 项目结构

```
frontend/
├── src/
│   ├── components/          # 可复用组件
│   │   ├── Layout.tsx      # 布局组件
│   │   └── ProtectedRoute.tsx  # 路由保护
│   ├── contexts/            # React Context
│   │   └── AuthContext.tsx # 认证上下文
│   ├── pages/               # 页面组件
│   │   ├── Login.tsx       # 登录页
│   │   ├── Dashboard.tsx    # 仪表盘
│   │   ├── Translation.tsx  # 翻译页
│   │   ├── History.tsx      # 历史记录
│   │   └── Users.tsx        # 用户管理
│   ├── services/            # API服务
│   │   └── api.ts          # API客户端
│   ├── types/               # TypeScript类型
│   │   └── index.ts
│   ├── App.tsx              # 主应用组件
│   ├── main.tsx             # 入口文件
│   └── index.css            # 全局样式
├── public/                  # 静态资源
├── package.json
├── vite.config.ts
├── tsconfig.json
└── tailwind.config.js
```

## 页面说明

### 登录/注册页
- 用户登录
- 新用户注册
- 表单验证

### 仪表盘
- 统计信息展示
- 快速操作入口

### 翻译页
- 多语言选择
- 文本输入和翻译
- 翻译结果展示
- 复制功能

### 翻译历史
- 历史记录列表
- 搜索功能
- 分页显示

### 用户管理
- 用户信息展示
- 账户状态

## API集成

前端通过 `src/services/api.ts` 与后端API通信：

- 认证API：登录、注册、获取用户信息
- 翻译API：文本翻译、获取历史记录

## 开发说明

### 添加新页面

1. 在 `src/pages/` 创建新组件
2. 在 `src/App.tsx` 添加路由
3. 在 `src/components/Layout.tsx` 添加导航项

### 自定义样式

使用Tailwind CSS类名，或修改 `tailwind.config.js` 扩展主题。

### 环境变量

所有环境变量必须以 `VITE_` 前缀开头，在代码中通过 `import.meta.env.VITE_*` 访问。

## 部署

### 构建

```bash
npm run build
```

### 静态文件部署

将 `dist` 目录部署到任何静态文件服务器：
- Nginx
- Apache
- Vercel
- Netlify
- GitHub Pages

### Docker部署

可以创建Dockerfile将前端和后端一起部署。

## 浏览器支持

- Chrome (最新)
- Firefox (最新)
- Safari (最新)
- Edge (最新)

## 故障排查

### API连接失败

1. 检查后端服务是否运行：`docker-compose ps`
2. 检查 `.env` 文件中的 `VITE_API_URL` 配置
3. 查看浏览器控制台错误信息

### 样式不显示

1. 确保Tailwind CSS已正确配置
2. 检查 `tailwind.config.js` 中的content路径
3. 重启开发服务器

## 下一步

- [ ] WebSocket流式翻译支持
- [ ] 批量翻译功能
- [ ] 翻译收藏功能
- [ ] 用户设置页面
- [ ] 暗色模式
- [ ] 国际化支持

