#!/bin/bash

# ==============================================================================
# LinXi 自动化部署脚本
# 支持系统: Ubuntu / CentOS
# 技术栈: NestJS (Docker) + React Admin (Nginx)
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

# --- 1. 交互式配置与校验 ---

validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^https?:// ]]; then
        log_error "域名必须以 http:// 或 https:// 开头"
        return 1
    fi
    return 0
}

check_connectivity() {
    local url=$1
    log_info "正在检查 $url 的连通性..."
    # 从 URL 中提取主机名
    local host=$(echo "$url" | awk -F/ '{print $3}')
    
    if ping -c 1 -W 2 "$host" &> /dev/null; then
        log_success "$host 连通性检查通过"
        return 0
    else
        log_warn "无法 Ping 通 $host。可能是防火墙拦截或 DNS 尚未生效。将继续尝试部署..."
        return 0
    fi
}

update_env() {
    local key=$1
    local value=$2
    local env_file=".env"

    if grep -q "^${key}=" "$env_file"; then
        # Key exists, update it using sed
        # Use different delimiter for sed to handle slashes in values
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        # Key does not exist, append it
        echo "${key}=${value}" >> "$env_file"
    fi
}

configure_environment() {
    log_info "开始交互式配置..."

    # Create .env if not exists
    touch .env

    # API_DOMAIN
    while true; do
        read -p "请输入后端 API 域名 (例如 https://api.example.com): " API_DOMAIN
        if validate_domain "$API_DOMAIN"; then
            check_connectivity "$API_DOMAIN"
            break
        fi
    done

    # ADMIN_DOMAIN
    while true; do
        read -p "请输入管理后台域名 (例如 https://admin.example.com): " ADMIN_DOMAIN
        if validate_domain "$ADMIN_DOMAIN"; then
            check_connectivity "$ADMIN_DOMAIN"
            break
        fi
    done

    # 阿里云密钥
    while true; do
        read -p "请输入阿里云 AccessKey ID: " ALIYUN_AK
        if [[ ${#ALIYUN_AK} -ge 16 ]]; then
            break
        else
            log_error "AccessKey ID 长度似乎过短。"
        fi
    done

    while true; do
        read -s -p "请输入阿里云 AccessKey Secret (输入时不显示): " ALIYUN_SK
        echo ""
        if [[ ${#ALIYUN_SK} -ge 24 ]]; then
            break
        else
            log_error "AccessKey Secret 长度似乎过短。"
        fi
    done

    read -p "请输入 OSS Bucket 名称: " OSS_BUCKET
    
    # OSS Endpoint (with default)
    read -p "请输入 OSS Region Endpoint (默认 oss-cn-hangzhou.aliyuncs.com): " OSS_ENDPOINT
    OSS_ENDPOINT=${OSS_ENDPOINT:-oss-cn-hangzhou.aliyuncs.com}

    # OSS Bucket ACL
    while true; do
        read -p "OSS Bucket 是私有(private)还是公共读(public-read)? (输入 1: 私有, 2: 公共读): " ACL_CHOICE
        case $ACL_CHOICE in
            1)
                OSS_BUCKET_ACL="private"
                break
                ;;
            2)
                OSS_BUCKET_ACL="public-read"
                break
                ;;
            *)
                log_warn "无效输入，请输入 1 或 2"
                ;;
        esac
    done

    # SMS Template Code (Must start with SMS_)
    while true; do
        read -p "请输入短信模板 ID (必须以 SMS_ 开头): " SMS_TEMPLATE_CODE
        if [[ "$SMS_TEMPLATE_CODE" =~ ^SMS_ ]]; then
            break
        else
            log_error "短信模板 ID 必须以 SMS_ 开头"
        fi
    done

    read -p "请输入短信签名: " SMS_SIGN
    read -p "请输入实人认证场景 ID: " REAL_PERSON_SCENE_ID

    # 幂等写入 .env
    ENV_FILE=".env"
    if [ -f "$ENV_FILE" ]; then
        BACKUP_FILE="$ENV_FILE.bak.$(date +%F_%H-%M-%S)"
        cp "$ENV_FILE" "$BACKUP_FILE"
        log_info "已备份现有 .env 至 $BACKUP_FILE"
    fi

    update_env "API_DOMAIN" "$API_DOMAIN"
    update_env "ADMIN_DOMAIN" "$ADMIN_DOMAIN"
    update_env "ALIYUN_AK" "$ALIYUN_AK"
    update_env "ALIYUN_SK" "$ALIYUN_SK"
    update_env "OSS_BUCKET" "$OSS_BUCKET"
    update_env "OSS_ENDPOINT" "$OSS_ENDPOINT"
    update_env "OSS_BUCKET_ACL" "$OSS_BUCKET_ACL"
    update_env "SMS_TEMPLATE_CODE" "$SMS_TEMPLATE_CODE"
    update_env "SMS_SIGN" "$SMS_SIGN"
    update_env "REAL_PERSON_SCENE_ID" "$REAL_PERSON_SCENE_ID"
    
    # Static values (update if needed, or keep appending if missing)
    update_env "DATABASE_URL" '"postgresql://postgres:postgres@postgres:5432/linxi_db?schema=public"'
    update_env "REDIS_HOST" "redis"
    update_env "REDIS_PORT" "6379"
    
    # JWT Secret - generate only if missing
    if ! grep -q "^JWT_SECRET=" "$ENV_FILE"; then
        JWT_SECRET=$(openssl rand -base64 32)
        echo "JWT_SECRET=$JWT_SECRET" >> "$ENV_FILE"
    fi

    chmod 600 "$ENV_FILE"
    log_success "配置已保存至 .env (权限已限制)。"
}

# --- 2. 环境自动化审计 ---

check_and_install() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        log_warn "未找到 $cmd。尝试自动安装..."
        if [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y "$package"
        elif [ -f /etc/redhat-release ]; then
            yum install -y "$package"
        else
            log_error "不支持的操作系统。请手动安装 $package。"
            exit 1
        fi
        log_success "$package 已安装。"
    else
        log_success "$cmd 已安装。"
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        log_warn "未找到 Docker。正在安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl start docker
        systemctl enable docker
        log_success "Docker 已安装。"
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_warn "未找到 Docker Compose。正在安装..."
        curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose 已安装。"
    fi
}

install_nodejs() {
    if ! command -v node &> /dev/null; then
        log_warn "未找到 Node.js。正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs || yum install -y nodejs
        log_success "Node.js 已安装。"
    fi
}

audit_environment() {
    log_info "正在审计环境..."
    check_and_install git git
    check_and_install nginx nginx
    install_docker
    install_nodejs
}

# --- 3. 后端部署 (Docker) ---

deploy_backend() {
    log_info "正在部署后端..."
    
    # git pull # 生产环境请取消注释
    # log_info "已拉取最新代码。"

    if [ ! -f "docker-compose.yml" ]; then
        log_error "未找到 docker-compose.yml 文件！"
        exit 1
    fi

    log_info "正在构建并启动 Docker 容器..."
    docker-compose up --build -d

    log_info "等待数据库就绪..."
    sleep 10 # 简单等待，生产环境建议使用健康检查

    log_info "正在运行数据库迁移..."
    docker-compose exec -T app npx prisma migrate deploy

    log_success "后端部署成功。"
}

# --- 4. 前端部署 (Nginx) ---

deploy_frontend() {
    log_info "正在部署前端 (管理后台)..."
    
    cd linxi-admin || exit 1
    
    log_info "正在安装前端依赖..."
    npm install

    log_info "正在清理旧构建产物..."
    rm -rf dist

    log_info "正在构建前端..."
    # 设置构建时的 VITE_API_BASE_URL
    # 如果未包含 /v1 后缀，则自动追加
    if [[ "$API_DOMAIN" != */v1 ]]; then
        export VITE_API_BASE_URL="${API_DOMAIN}/v1"
    else
        export VITE_API_BASE_URL="$API_DOMAIN"
    fi
    
    npm run build

    TARGET_DIR="/var/www/linxi-admin"
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi

    log_info "正在部署静态文件至 $TARGET_DIR..."
    rm -rf "$TARGET_DIR"/*
    cp -r dist/* "$TARGET_DIR"/
    
    cd ..

    # 生成 Nginx 配置
    NGINX_CONF="/etc/nginx/conf.d/linxi.conf"
    
    # 提取无协议头的主机名用于 Nginx server_name
    API_HOST=$(echo "$API_DOMAIN" | awk -F/ '{print $3}')
    ADMIN_HOST=$(echo "$ADMIN_DOMAIN" | awk -F/ '{print $3}')

    log_info "正在生成 Nginx 配置 (API: $API_HOST, Admin: $ADMIN_HOST)..."

    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $ADMIN_HOST;

    location / {
        root $TARGET_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen 80;
    server_name $API_HOST;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    log_info "正在测试 Nginx 配置..."
    nginx -t

    log_info "正在重载 Nginx..."
    systemctl reload nginx

    log_success "前端部署成功。"

    # --- SSL 证书自动化 ---
    log_info "正在为域名申请 SSL 证书..."
    check_and_install certbot certbot
    check_and_install python3-certbot-nginx python3-certbot-nginx

    # 申请证书 (非交互式)
    # 提取域名列表
    DOMAINS="-d $ADMIN_HOST -d $API_HOST"
    
    # 使用 certbot 自动配置 Nginx
    # --non-interactive: 非交互模式
    # --agree-tos: 同意服务条款
    # --redirect: 自动配置 HTTP -> HTTPS 重定向
    # -m: 邮箱 (这里使用默认或提示用户输入，为简单起见暂用 admin@$ADMIN_HOST)
    EMAIL="admin@$ADMIN_HOST"
    
    if certbot --nginx $DOMAINS --non-interactive --agree-tos --email "$EMAIL" --redirect; then
        log_success "SSL 证书申请并安装成功！HTTPS 已启用。"
    else
        log_error "SSL 证书申请失败。请检查域名解析是否正确，或稍后手动运行 certbot。"
        # 不退出脚本，因为部署已完成，只是 SSL 失败
    fi
}

# --- 5. 安全与收尾 ---

cleanup() {
    log_info "正在清理..."
    # 如果需要节省空间，可以取消注释以下行来删除前端的 node_modules
    # rm -rf linxi-admin/node_modules 
    log_success "清理完成。"
}

print_report() {
    echo -e "\n=================================================="
    echo -e "                 部署成功                         "
    echo -e "=================================================="
    echo -e "后端 API     : $API_DOMAIN"
    echo -e "管理后台     : $ADMIN_DOMAIN"
    echo -e "数据库       : Docker 容器 (linxi-postgres)"
    echo -e "Redis        : Docker 容器 (linxi-redis)"
    echo -e "Nginx 配置   : /etc/nginx/conf.d/linxi.conf"
    echo -e "环境变量文件 : .env (权限 600)"
    echo -e "==================================================\n"
}

# --- 主执行流程 ---

main() {
    check_root
    audit_environment
    configure_environment
    deploy_backend
    deploy_frontend
    cleanup
    print_report
}

# 捕获错误
trap 'log_error "部署失败！请检查上方日志获取详情。"' ERR

# 运行主函数
main
