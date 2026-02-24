# 灵犀 (LinXi) - 1Panel 部署指南

本文档将指导您如何使用 **1Panel** 面板快速部署灵犀 (LinXi) 全栈项目。我们将利用 1Panel 的容器编排（Docker Compose）和网站管理（OpenResty/Nginx）功能。

---

## 🛠 前置准备

1.  **服务器要求**：
    *   操作系统：Ubuntu 20.04+ / CentOS 7+
    *   内存：建议 4GB 以上
    *   已安装 1Panel 面板。
2.  **环境依赖 (通过 1Panel 应用商店安装)**：
    *   **OpenResty** (用于反向代理)
    *   **PostgreSQL** (数据库)
    *   **Redis** (缓存)
3.  **域名**：
    *   准备两个子域名，分别用于后端 API (例如 `api.example.com`) 和管理后台 (例如 `admin.example.com`)。
    *   确保域名已解析到服务器 IP。

---

## 📦 第一步：获取代码与构建镜像

1.  **上传代码**：
    *   登录 1Panel 面板，进入 **文件** 管理。
    *   在 `/opt/1panel/apps` 目录下（或您喜欢的任意目录）新建文件夹 `linxi`。
    *   将项目源码上传并解压到该目录。

2.  **构建后端镜像 (推荐本地构建)**：
    *   由于服务器性能可能有限，建议在本地开发机构建 Docker 镜像并推送至阿里云/腾讯云镜像仓库，或者 Docker Hub。
    *   在本地项目根目录运行：
        ```bash
        # 登录 Docker Hub (如果需要)
        docker login

        # 构建并推送
        docker build -t your-docker-id/linxi-server:latest -f linxi-server/Dockerfile ./linxi-server
        docker push your-docker-id/linxi-server:latest
        ```
    *   *如果您必须在服务器构建*：请确保服务器已安装 Docker 环境，并在服务器终端运行上述 `docker build` 命令。

---

## 🗄 第二步：配置数据库与 Redis

1.  **创建数据库**：
    *   在 1Panel **数据库** -> **PostgreSQL** 中，点击“创建数据库”。
    *   名称：`linxi_db`
    *   用户：`linxi_user`
    *   密码：(请设置一个强密码，并记住它)
    *   *注意：请确保 PostgreSQL 允许容器网络访问，或者直接使用 Docker 内部网络连接。*

2.  **Redis**：
    *   确保 Redis 服务已启动，记下连接密码。

---

## 🐳 第三步：创建容器编排 (Docker Compose)

1.  进入 1Panel **容器** -> **编排** -> **创建编排**。
2.  **名称**：`linxi`
3.  **内容**：复制以下内容，并根据您的实际情况修改环境变量。

```yaml
version: '3.8'

services:
  # 后端服务
  linxi-server:
    image: your-docker-id/linxi-server:latest # 替换为您构建的镜像地址
    container_name: linxi-server
    restart: always
    ports:
      - "3000:3000"
    environment:
      # 数据库配置 (如果使用 1Panel 部署的 PG，host 可以是宿主机 IP 或者 link 名称)
      # 格式: postgresql://用户:密码@主机:端口/数据库名?schema=public
      - DATABASE_URL=postgresql://linxi_user:your_db_password@172.17.0.1:5432/linxi_db?schema=public
      
      # Redis 配置
      - REDIS_HOST=172.17.0.1 # 宿主机 Docker 网关 IP
      - REDIS_PORT=6379
      - REDIS_PASSWORD=your_redis_password
      
      # 阿里云配置
      - ALIYUN_ACCESS_KEY_ID=your_ak
      - ALIYUN_ACCESS_KEY_SECRET=your_sk
      - ALIYUN_OSS_BUCKET=your_bucket
      - ALIYUN_OSS_REGION=oss-cn-hangzhou
      - ALIYUN_SMS_SIGN_NAME=LinXi
      - ALIYUN_SMS_TEMPLATE_CODE=SMS_123456789
      - ALIYUN_REAL_PERSON_SCENE_ID=100000
      
      # JWT 密钥
      - JWT_SECRET=generate_a_long_random_secret_string
      - CRYPTO_SECRET_KEY=generate_another_secret_for_aes

    networks:
      - 1panel-network

networks:
  1panel-network:
    external: true
```

*注意：`172.17.0.1` 通常是 Docker 容器访问宿主机的 IP。如果您的 PostgreSQL 和 Redis 也是容器化部署且在同一个网络下，可以使用服务名。*

4.  点击 **确认**，等待容器启动成功。

---

## ⚙️ 第四步：数据库迁移

容器启动后，首次运行需要初始化数据库表结构。

1.  在 1Panel **容器** 列表中，找到 `linxi-server` 容器。
2.  点击右侧的 **终端** 图标，进入容器命令行。
3.  执行以下命令：
    ```bash
    npx prisma migrate deploy
    ```
    看到 "The migrations have been successfully applied" 即表示成功。

---

## 🌐 第五步：部署前端 (管理后台)

1.  **本地构建前端**：
    *   在本地修改 `linxi-admin/.env` (或构建时指定环境变量)，将 `VITE_API_BASE_URL` 指向您的后端域名 `https://api.example.com/v1`。
    *   运行构建命令：
        ```bash
        cd linxi-admin
        npm install
        npm run build
        ```
    *   这将生成一个 `dist` 文件夹。

2.  **上传静态文件**：
    *   将 `dist` 文件夹内的所有文件，上传到服务器的 `/opt/1panel/apps/openresty/www/sites/admin.example.com/index` (路径取决于您下一步创建网站时的设置，建议先创建网站再上传)。

3.  **创建静态网站**：
    *   进入 1Panel **网站** -> **创建网站** -> **静态网站**。
    *   **主域名**：`admin.example.com`
    *   **代号**：`linxi-admin`
    *   创建完成后，进入该网站的根目录，将刚才的 `dist` 文件内容覆盖上传进去。

---

## 🔄 第六步：配置反向代理 (Nginx)

我们需要配置两个网站：一个是刚才创建的管理后台（静态），一个是后端 API（反代）。

### 1. 后端 API 反向代理
1.  **创建反代网站**：
    *   1Panel **网站** -> **创建网站** -> **反向代理**。
    *   **主域名**：`api.example.com`
    *   **代理地址**：`http://127.0.0.1:3000` (指向 linxi-server 容器映射的端口)。
2.  **配置 SSL**：
    *   在网站设置中，开启 HTTPS，申请 Let's Encrypt 免费证书。

### 2. 管理后台 Nginx 修正
1.  找到 `admin.example.com` 静态网站，点击 **配置** -> **配置文件**。
2.  确保 `location /` 块包含以下内容，以支持 React 路由的 History 模式（防止刷新 404）：
    ```nginx
    location / {
        try_files $uri $uri/ /index.html;
        index index.html;
    }
    ```
3.  同样开启 HTTPS。

---

## ✅ 第七步：验证与完成

1.  访问 `https://api.example.com/v1`，如果看到 404 或后端返回的提示，说明后端部署成功。
2.  访问 `https://admin.example.com`，应该能看到登录界面。尝试登录（需先在数据库手动插入一个管理员账号，或通过注册接口创建）。

**恭喜！您已成功在 1Panel 上部署了灵犀全栈项目。**
