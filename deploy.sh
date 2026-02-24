#!/bin/bash

# ==============================================================================
# LinXi 1Panel 自动化部署脚本 (适配版)
# 支持系统: Ubuntu / CentOS
# 技术栈: NestJS (Docker) + React Admin (1Panel 静态网站)
# ==============================================================================

set -e # 如果任何命令返回非零状态，立即退出

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# --- 辅助函数 ---
log_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本 (sudo ./deploy.sh)"
        exit 1
    fi
}

# --- 1. 交互式配置 ---

validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^https?:// ]]; then
        log_error "域名必须以 http:// 或 https:// 开头"
        return 1
    fi
    return 0
}

update_env() {
    local key=$1
    local value=$2
    local env_file=".env"

    if grep -q "^${key}=" "$env_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        echo "${key}=${value}" >> "$env_file"
    fi
}

configure_environment() {
    log_info "开始交互式配置..."
    log_info "注意：本脚本假设您已在 1Panel 中配置好数据库和 Redis，并准备好了网站。"

    # Create .env if not exists
    touch .env

    # API_DOMAIN
    while true; do
        read -p "请输入后端 API 域名 (例如 https://api.example.com): " API_DOMAIN
        if validate_domain "$API_DOMAIN"; then
            break
        fi
    done

    # ADMIN_DOMAIN
    while true; do
        read -p "请输入管理后台域名 (例如 https://admin.example.com): " ADMIN_DOMAIN
        if validate_domain "$ADMIN_DOMAIN"; then
            break
        fi
    done

    # 阿里云密钥
    read -p "请输入阿里云 AccessKey ID: " ALIYUN_AK
    read -s -p "请输入阿里云 AccessKey Secret: " ALIYUN_SK
    echo ""
    read -p "请输入 OSS Bucket 名称: " OSS_BUCKET
    read -p "请输入 OSS Region Endpoint (默认 oss-cn-hangzhou.aliyuncs.com): " OSS_ENDPOINT
    OSS_ENDPOINT=${OSS_ENDPOINT:-oss-cn-hangzhou.aliyuncs.com}
    
    # 数据库配置
    read -p "请输入数据库连接地址 (例如 postgresql://user:pass@ip:5432/db?schema=public): " DATABASE_URL
    
    # Redis 配置
    read -p "请输入 Redis 主机 (默认 127.0.0.1): " REDIS_HOST
    REDIS_HOST=${REDIS_HOST:-127.0.0.1}
    read -p "请输入 Redis 端口 (默认 6379): " REDIS_PORT
    REDIS_PORT=${REDIS_PORT:-6379}
    read -s -p "请输入 Redis 密码 (无密码直接回车): " REDIS_PASSWORD
    echo ""

    # 写入 .env
    update_env "API_DOMAIN" "$API_DOMAIN"
    update_env "ADMIN_DOMAIN" "$ADMIN_DOMAIN"
    update_env "ALIYUN_ACCESS_KEY_ID" "$ALIYUN_AK"
    update_env "ALIYUN_ACCESS_KEY_SECRET" "$ALIYUN_SK"
    update_env "ALIYUN_OSS_BUCKET" "$OSS_BUCKET"
    update_env "ALIYUN_OSS_REGION" "$OSS_ENDPOINT"
    update_env "DATABASE_URL" "$DATABASE_URL"
    update_env "REDIS_HOST" "$REDIS_HOST"
    update_env "REDIS_PORT" "$REDIS_PORT"
    update_env "REDIS_PASSWORD" "$REDIS_PASSWORD"
    
    if ! grep -q "^JWT_SECRET=" ".env"; then
        JWT_SECRET=$(openssl rand -base64 32)
        echo "JWT_SECRET=$JWT_SECRET" >> ".env"
    fi
    if ! grep -q "^CRYPTO_SECRET_KEY=" ".env"; then
        CRYPTO_SECRET_KEY=$(openssl rand -base64 32)
        echo "CRYPTO_SECRET_KEY=$CRYPTO_SECRET_KEY" >> ".env"
    fi

    chmod 600 ".env"
    log_success "配置已保存至 .env。"
}

# --- 2. 后端部署 (Docker) ---

deploy_backend() {
    log_info "正在部署后端..."
    
    if ! command -v docker-compose &> /dev/null; then
        if ! command -v docker &> /dev/null; then
             log_error "未检测到 Docker，请先在 1Panel 中安装 Docker。"
             exit 1
        fi
        # Try docker compose (v2)
        if ! docker compose version &> /dev/null; then
             log_error "未检测到 Docker Compose，请先安装。"
             exit 1
        fi
    fi

    log_info "构建并启动容器..."
    # 使用 docker-compose.yml 启动，确保 env_file 被加载
    docker-compose up --build -d

    log_info "运行数据库迁移..."
    # 等待容器就绪
    sleep 5
    docker-compose exec -T app npx prisma migrate deploy

    log_success "后端部署完成。"
}

# --- 3. 前端部署 (构建产物) ---

deploy_frontend() {
    log_info "正在构建前端..."
    
    cd linxi-admin || exit 1
    
    if ! command -v npm &> /dev/null; then
        log_warn "未检测到 npm，尝试使用 docker 构建前端..."
        # 使用 node 容器构建
        docker run --rm -v $(pwd):/app -w /app node:18-alpine sh -c "npm install && npm run build"
    else
        npm install
        
        # 自动注入 VITE_API_BASE_URL
        if [[ "$API_DOMAIN" != */v1 ]]; then
            export VITE_API_BASE_URL="${API_DOMAIN}/v1"
        else
            export VITE_API_BASE_URL="$API_DOMAIN"
        fi
        
        npm run build
    fi

    # 提示用户手动上传或移动
    DIST_PATH=$(pwd)/dist
    log_success "前端构建完成！产物路径: $DIST_PATH"
    log_info "请在 1Panel 中创建一个静态网站 (域名: $ADMIN_DOMAIN)，并将上述 dist 目录下的内容复制到网站根目录。"
    
    cd ..
}

# --- 主流程 ---

main() {
    check_root
    configure_environment
    deploy_backend
    deploy_frontend
    
    echo -e "\n=================================================="
    echo -e "           1Panel 部署脚本执行完毕                "
    echo -e "=================================================="
    echo -e "1. 后端容器已启动 (端口 3000)。"
    echo -e "2. 请在 1Panel 创建反向代理网站: $API_DOMAIN -> http://127.0.0.1:3000"
    echo -e "3. 请在 1Panel 创建静态网站: $ADMIN_DOMAIN，并上传 dist 目录内容。"
    echo -e "4. 别忘了在 1Panel 网站设置中开启 HTTPS (申请 SSL 证书)。"
    echo -e "==================================================\n"
}

main
