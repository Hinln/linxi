# 灵犀 (LinXi) - 全栈社交平台解决方案

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![NestJS](https://img.shields.io/badge/backend-NestJS-red.svg)
![React](https://img.shields.io/badge/admin-React-blue.svg)
![Flutter](https://img.shields.io/badge/mobile-Flutter-02569B.svg)

**灵犀 (LinXi)** 是一个基于现代技术栈构建的全栈社交平台开源项目。它集成了后端服务、管理后台和移动端应用，提供了一套完整的社交应用解决方案，涵盖了用户管理、内容审核、即时通讯、钱包支付等核心功能。

## ✨ 核心特性

- **多端覆盖**：包含 RESTful API 后端、React 管理后台、Flutter 跨平台移动端。
- **用户体系**：
  - JWT 认证与 RBAC 权限控制（普通用户、管理员）。
  - 实名认证对接（集成阿里云实人认证）。
  - 账号封禁与解封机制。
- **内容管理与审核**：
  - 动态发布与管理。
  - 完善的举报与审核流程（支持对用户和内容的举报处理）。
  - 自动化审核操作（自动封禁、自动删除违规内容）。
- **即时通讯 (IM)**：
  - 基于 Socket.io 的实时聊天。
  - 消息类型支持（文本、图片等）。
  - 陌生人社交限制（非好友消息收费机制）。
- **钱包与支付**：
  - 虚拟货币（金币）系统。
  - 充值、消费、提现流程。
  - 严谨的账务逻辑（乐观锁、事务处理、审计日志）。
- **自动化部署**：提供一键部署脚本，支持 Docker 容器化部署与 Nginx 反向代理配置。

## 🛠 技术栈

### 后端 (linxi-server)
- **框架**：NestJS
- **数据库**：PostgreSQL (Prisma ORM)
- **缓存/消息队列**：Redis
- **即时通讯**：Socket.io
- **云服务**：阿里云 (OSS 对象存储, SMS 短信, 实人认证)

### 管理后台 (linxi-admin)
- **框架**：React + Vite
- **UI 组件库**：Ant Design
- **样式**：Tailwind CSS
- **网络请求**：Axios

### 移动端 (linxi-app)
- **框架**：Flutter 3.x
- **状态管理**：Provider
- **网络请求**：Dio
- **原生桥接**：MethodChannel (用于对接原生 SDK)

## 📂 项目结构

```
LinXi/
├── linxi-server/       # NestJS 后端服务源代码
│   ├── prisma/         # 数据库模型定义
│   ├── src/            # 业务逻辑
│   └── Dockerfile      # 后端容器构建文件
│
├── linxi-admin/        # React 管理后台源代码
│   ├── src/            # 前端页面与逻辑
│   └── vite.config.ts  # Vite 配置
│
├── linxi-app/          # Flutter 移动端应用源代码
│   ├── lib/            # Dart 代码
│   └── pubspec.yaml    # 依赖配置
│
├── deploy.sh           # 自动化一键部署脚本 (Shell)
├── docker-compose.yml  # Docker 编排文件 (后端 + 数据库 + Redis)
├── LICENSE             # MIT 开源协议
└── README.md           # 项目说明文档
```

## 🚀 快速开始

### 前置要求
- Node.js (v18+)
- Docker & Docker Compose
- Flutter SDK (v3.0+)
- PostgreSQL & Redis (本地开发需安装或使用 Docker 启动)

### 1. 启动后端服务

```bash
cd linxi-server

# 安装依赖
npm install

# 配置环境变量 (参考 .env.example 创建 .env)
# 确保数据库和 Redis 连接配置正确

# 启动本地数据库容器 (可选)
docker-compose up -d postgres redis

# 同步数据库表结构
npx prisma migrate dev

# 启动服务
npm run start:dev
```

### 2. 启动管理后台

```bash
cd linxi-admin

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```
访问地址：`http://localhost:5173`

### 3. 运行移动端 App

```bash
cd linxi-app

# 获取依赖
flutter pub get

# 运行 (请先连接模拟器或真机)
flutter run
```

## 📦 部署指南

本项目提供了一键部署脚本 `deploy.sh`，适用于 Ubuntu/CentOS 服务器。

1. **上传代码**：将项目代码上传至服务器。
2. **运行脚本**：
   ```bash
   sudo ./deploy.sh
   ```
3. **按提示配置**：脚本会引导输入域名、阿里云密钥等信息，并自动完成 Docker 容器构建、数据库迁移和 Nginx 配置。

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## 📄 开源协议

本项目采用 [MIT 协议](LICENSE) 开源。
