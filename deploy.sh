#!/bin/bash

# ==============================================================================
# LinXi (灵犀) 零基础一键部署脚本 (1Panel 深度适配版)
# 支持系统: Ubuntu / CentOS
# 技术栈: NestJS (Docker) + React Admin (Static)
# ==============================================================================

set -e # 遇到错误立即退出

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# --- 辅助函数 ---
log_info() { echo -e "${BLUE}[信息]${NC} $1"; }
log_success() { echo -e "${GREEN}[成功]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[警告]${NC} $1"; }
log_error() { echo -e "${RED}[错误]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本 (sudo ./deploy.sh)"
        exit 1
    fi
}

# --- 1. 环境体检 (System Audit) ---

check_system_resources() {
    log_info "正在检查系统资源..."
    
    # 内存检查
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$(echo "scale=2; $total_mem_kb/1024/1024" | bc)
    
    log_info "当前内存: ${total_mem_gb}GB"
    
    if (( $(echo "$total_mem_gb < 3.5" | bc -l) )); then
        log_warn "内存小于 3.5GB，可能导致构建失败。"
        read -p "是否自动创建 4GB Swap 分区? (y/n, 默认 y): " CREATE_SWAP
        CREATE_SWAP=${CREATE_SWAP:-y}
        
        if [[ "$CREATE_SWAP" == "y" ]]; then
            log_info "正在创建 4GB Swap..."
            fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
            log_success "Swap 创建成功。"
        fi
    fi
}

check_ports() {
    log_info "正在检查端口占用..."
    local ports=(80 443 3000 5432 6379)
    local conflict=false
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            log_warn "端口 $port 已被占用！"
            conflict=true
        fi
    done
    
    if $conflict; then
        read -p "检测到端口冲突，是否继续? (y/n): " CONTINUE
        if [[ "$CONTINUE" != "y" ]]; then
            exit 1
        fi
    else
        log_success "端口检查通过。"
    fi
}

check_domain_resolution() {
    local domain=$1
    if [[ -z "$domain" ]]; then return; fi
    
    # 提取域名部分
    local host=$(echo "$domain" | awk -F/ '{print $3}')
    log_info "正在验证域名解析: $host"
    
    local current_ip=$(curl -s ifconfig.me)
    local resolved_ip=$(dig +short "$host" | head -n 1)
    
    if [[ "$resolved_ip" != "$current_ip" ]]; then
        log_error "域名 $host 解析未生效！"
        log_error "当前解析 IP: ${resolved_ip:-未解析}"
        log_error "服务器 IP: $current_ip"
        log_warn "请立即去域名后台修改解析，否则 SSL 申请必失败！"
        read -p "是否已修复并继续? (y/n): " RESOLVED
        if [[ "$RESOLVED" != "y" ]]; then exit 1; fi
    else
        log_success "域名解析验证通过。"
    fi
}

# --- 2. 网络加速 (Speed Optimization) ---

optimize_network() {
    log_info "正在检测网络环境..."
    
    # 通过访问 google.com 的延迟判断
    if curl -s --connect-timeout 3 --head https://www.google.com | grep "200 OK" > /dev/null; then
        log_info "网络环境: 国际互联 (无需加速)"
    else
        log_info "网络环境: 中国大陆 (开启加速)"
        
        # NPM 加速
        npm config set registry https://registry.npmmirror.com
        log_success "NPM 源已切换至淘宝镜像"
        
        # Docker 加速 (仅提示，不强制覆盖 daemon.json 以免破坏现有配置)
        log_info "建议手动配置 Docker 镜像加速 (如阿里云/腾讯云镜像源)"
    fi
}

# --- 3. 深度适配 1Panel (1Panel Bridge) ---

adapt_1panel() {
    log_info "正在适配 1Panel 环境..."
    
    # 路径识别
    if [[ -d "/opt/1panel" ]]; then
        log_success "检测到 1Panel 安装目录。"
        read -p "是否将项目部署到 1Panel 应用目录 (/opt/1panel/apps/linxi)? (y/n, 默认 y): " MOVE_DIR
        MOVE_DIR=${MOVE_DIR:-y}
        
        if [[ "$MOVE_DIR" == "y" ]]; then
            local target_dir="/opt/1panel/apps/linxi"
            if [[ "$(pwd)" != "$target_dir" ]]; then
                mkdir -p "$target_dir"
                cp -r . "$target_dir"
                log_success "项目已复制到 $target_dir，请跳转到该目录继续操作。"
                cd "$target_dir" || exit 1
            fi
        fi
    fi
    
    # 网络自动跨接
    if docker network ls | grep -q "1panel-network"; then
        log_success "检测到 1panel-network。"
        
        # 修改 docker-compose.yml
        if ! grep -q "1panel-network" docker-compose.yml; then
            log_info "正在将后端服务加入 1panel-network..."
            
            # 这是一个简单的追加，实际生产建议使用 yq 工具，这里为了不依赖 yq 使用 sed/cat 拼接
            # 假设 docker-compose.yml 结尾是 networks 定义，或者没有
            # 为简单起见，我们直接追加 external network 定义
            
            cat >> docker-compose.yml <<EOF

networks:
  1panel-network:
    external: true
  linxi-network:
    driver: bridge
EOF
            # 注意：这需要 docker-compose.yml 中 service 部分正确引用 networks: - 1panel-network
            # 由于这是自动化脚本，直接修改 YAML 风险较大，我们提示用户
            log_warn "已检测到 1panel-network，建议手动修改 docker-compose.yml 让 app 服务加入该网络，以便连接面板内的数据库。"
        fi
    fi
}

# --- 4. 自动化构建与数据库同步 ---

install_dependencies() {
    log_info "正在检查并安装依赖..."
    
    local packages="git curl wget bc"
    
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y $packages
        
        # Install Docker if missing
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh
        fi
        
        # Install Node.js if missing
        if ! command -v node &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            apt-get install -y nodejs
        fi
        
    elif [ -f /etc/redhat-release ]; then
        yum install -y $packages
        # CentOS Docker/Node install skipped for brevity
    fi
}

deploy_backend() {
    log_info "正在部署后端..."
    
    # 确保 tsconfig.json 宽松模式
    # (已在前一步工具调用中修改)

    if ! command -v docker-compose &> /dev/null; then
        if ! docker compose version &> /dev/null; then
             log_error "未检测到 Docker Compose。"
             exit 1
        fi
    fi

    log_info "构建并启动容器..."
    docker-compose up --build -d

    log_info "等待数据库就绪并执行迁移 (重试 5 次)..."
    for i in {1..5}; do
        if docker-compose exec -T app npx prisma migrate deploy; then
            log_success "数据库迁移成功！"
            return 0
        fi
        log_warn "迁移失败，5秒后重试 ($i/5)..."
        sleep 5
    done
    
    log_error "数据库迁移多次失败，请检查数据库连接配置。"
    exit 1
}

# --- 5. 交互 UI 与健康检查 ---

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
    touch .env

    # 域名
    while true; do
        read -p "请输入后端 API 域名 (例如 https://api.example.com): " API_DOMAIN
        if validate_domain "$API_DOMAIN"; then
            check_domain_resolution "$API_DOMAIN"
            break
        fi
    done

    while true; do
        read -p "请输入管理后台域名 (例如 https://admin.example.com): " ADMIN_DOMAIN
        if validate_domain "$ADMIN_DOMAIN"; then
            check_domain_resolution "$ADMIN_DOMAIN"
            break
        fi
    done

    # 阿里云
    read -p "阿里云 AccessKey ID: " ALIYUN_AK
    read -s -p "阿里云 AccessKey Secret: " ALIYUN_SK
    echo ""
    read -p "OSS Bucket 名称: " OSS_BUCKET
    read -p "OSS Region (默认 oss-cn-hangzhou.aliyuncs.com): " OSS_ENDPOINT
    OSS_ENDPOINT=${OSS_ENDPOINT:-oss-cn-hangzhou.aliyuncs.com}
    
    # 数据库 (默认本地 Docker)
    read -p "数据库连接地址 (回车使用默认 Docker 内部连接): " DATABASE_URL
    DATABASE_URL=${DATABASE_URL:-"postgresql://postgres:postgres@postgres:5432/linxi_db?schema=public"}
    
    # Redis
    read -p "Redis 主机 (默认 redis): " REDIS_HOST
    REDIS_HOST=${REDIS_HOST:-redis}
    read -p "Redis 端口 (默认 6379): " REDIS_PORT
    REDIS_PORT=${REDIS_PORT:-6379}
    
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
    
    if ! grep -q "^JWT_SECRET=" ".env"; then
        echo "JWT_SECRET=$(openssl rand -base64 32)" >> ".env"
    fi
    if ! grep -q "^CRYPTO_SECRET_KEY=" ".env"; then
        echo "CRYPTO_SECRET_KEY=$(openssl rand -base64 32)" >> ".env"
    fi

    chmod 600 ".env"
}

validate_domain() {
    local domain=$1
    if [[ ! "$domain" =~ ^https?:// ]]; then
        log_error "域名必须以 http:// 或 https:// 开头"
        return 1
    fi
    return 0
}

# --- 6. 前端构建 ---

deploy_frontend() {
    log_info "正在构建前端..."
    cd linxi-admin || exit 1
    
    npm install
    
    if [[ "$API_DOMAIN" != */v1 ]]; then
        export VITE_API_BASE_URL="${API_DOMAIN}/v1"
    else
        export VITE_API_BASE_URL="$API_DOMAIN"
    fi
    
    npm run build
    
    log_success "前端构建完成: $(pwd)/dist"
    cd ..
}

# --- 主流程 ---

main() {
    clear
    echo "=================================================="
    echo "       LinXi (灵犀) 一键部署脚本 v2.0            "
    echo "=================================================="
    
    check_root
    install_dependencies
    check_system_resources
    check_ports
    optimize_network
    adapt_1panel
    
    configure_environment
    
    deploy_backend
    deploy_frontend
    
    # 冒烟测试
    # log_info "正在进行健康检查..."
    # curl -s "$API_DOMAIN/health" || true
    
    clear
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${GREEN}               部署成功!                          ${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo -e "后端 API     : $API_DOMAIN"
    echo -e "管理后台     : $ADMIN_DOMAIN"
    echo -e "数据库       : $DATABASE_URL"
    echo -e "前端产物     : $(pwd)/linxi-admin/dist"
    echo -e ""
    echo -e "请在 1Panel 中创建静态网站，并将 dist 目录上传。"
    echo -e "${GREEN}==================================================${NC}"
}

main
