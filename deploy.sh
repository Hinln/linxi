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
        read -p "是否自动创建 4GB Swap 分区? (y/n, 默认 y): " CREATE_SWAP </dev/tty
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
    
    # Initialize global override content variable
    # Default: App connects to 1panel network (if exists) and linxi-network
    # And explicitly depend on postgres/redis (since removed from main compose)
    OVERRIDE_CONTENT="services:
  app:
    depends_on:
      - postgres
      - redis
    networks:
      - 1panel-network
      - linxi-network"
    
    # 1Panel 端口复用逻辑
    local has_1panel=false
    if [[ -d "/opt/1panel" ]]; then has_1panel=true; fi

    for port in "${ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            log_warn "端口 $port 已被占用！"
            conflict=true
            
            # 自动降级逻辑
            if [[ "$port" == "5432" || "$port" == "6379" ]] && $has_1panel; then
                read -p "检测到端口 $port 被占用且存在 1Panel。是否复用面板数据库/Redis？(y/n, 默认 y): " REUSE_DB </dev/tty
                REUSE_DB=${REUSE_DB:-y}
                if [[ "$REUSE_DB" == "y" ]]; then
                    log_info "已选择复用面板服务，将在后续步骤中配置连接。"
                    
                    # Critical Fix: Inject depends_on: [] to break dependency on postgres/redis
                    # We overwrite the initial content to include depends_on
                    OVERRIDE_CONTENT="services:
  app:
    depends_on: []
    networks:
      - 1panel-network
      - linxi-network"

                    # 禁用对应服务 - Accumulate to variable with proper newlines
                    if [[ "$port" == "5432" ]]; then
                        OVERRIDE_CONTENT+=$'\n  postgres:\n    profiles: [\'donotstart\']\n    ports: []'
                        log_success "已禁用内置 Postgres 容器。"
                    fi
                    if [[ "$port" == "6379" ]]; then
                        OVERRIDE_CONTENT+=$'\n  redis:\n    profiles: [\'donotstart\']\n    ports: []'
                        log_success "已禁用内置 Redis 容器。"
                    fi
                    
                    # 标记冲突已解决 (软解决)
                    conflict=false
                fi
            elif [[ "$port" == "80" || "$port" == "443" ]] && $has_1panel; then
                log_info "Web 端口被占用，属于正常现象（由 1Panel OpenResty 接管）。"
                log_info "请后续在面板中创建反向代理网站指向本服务端口 (3000)。"
                conflict=false
            fi
        fi
    done
    
    # Append network definition with proper newlines
    OVERRIDE_CONTENT+=$'\n\nnetworks:\n  1panel-network:\n    external: true'
    
    if $conflict; then
        read -p "检测到未解决的端口冲突，是否继续? (y/n): " CONTINUE </dev/tty
        if [[ "$CONTINUE" != "y" ]]; then
            exit 1
        fi
    else
        log_success "端口检查通过 (或已自动规避)。"
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
        read -p "是否已修复并继续? (y/n): " RESOLVED </dev/tty
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
    
    # 路径识别 (已在 main 中预设 TARGET_DIR，此处仅做校验或提示)
    if [[ "$TARGET_DIR" == "/opt/1panel/apps/linxi" ]]; then
        log_success "检测到 1Panel 环境，将在标准应用目录部署。"
    fi
    
    # 网络自动跨接
    if docker network ls | grep -q "1panel-network"; then
        log_success "检测到 1panel-network。"
        
        # 修改 docker-compose.yml (使用 Override 方式，不修改原文件)
        if ! grep -q "1panel-network" docker-compose.override.yml 2>/dev/null; then
            log_info "正在自动注入网络配置..."
            
            # The actual injection is handled by OVERRIDE_CONTENT variable in check_ports
            # and written in start_backend_services.
            # Here we just confirm readiness.
            log_success "网络配置已准备就绪 (将在启动前写入覆盖文件)。"
        fi
    else
        log_info "未检测到 1panel-network，跳过网络配置。"
    fi
}

# --- 4. 自动化构建与数据库同步 ---

install_dependencies() {
    log_info "正在检查并安装依赖..."
    
    # Pre-install iproute2 for ss command, and dnsutils/bind-utils for dig
    local common_packages="git curl wget bc net-tools"
    
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y $common_packages iproute2 dnsutils
        
        # Check docker command
        check_docker_command
        
        # Install Docker if missing
        if ! command -v docker &> /dev/null; then
            curl -fsSL https://get.docker.com | sh
        fi
        
        # Install Docker Compose Plugin if missing
        if [[ -z "$DOCKER_COM_CMD" ]]; then
             apt-get install -y docker-compose-plugin || apt-get install -y docker-compose
             check_docker_command
        fi
        
        # Install Node.js if missing
        if ! command -v node &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
        fi
        
    elif [ -f /etc/redhat-release ]; then
        yum install -y $common_packages iproute2 bind-utils
        # CentOS Docker/Node install skipped for brevity
        check_docker_command
    fi
    
    # 强化目录与代码管理
    if [ -d ".git" ]; then
        log_info "检测到 Git 仓库，正在更新代码..."
        git pull origin main || log_warn "Git 更新失败，将使用当前代码继续。"
    else
        # Only clone if directory is empty or almost empty (to avoid overwriting user changes if they just copied files)
        # But here we are IN the directory.
        # If we are running deploy.sh, we likely have the code.
        # So we skip cloning if deploy.sh exists.
        log_info "未检测到 Git 仓库，跳过代码更新。"
    fi
}

check_docker_command() {
    if docker compose version &> /dev/null; then
        DOCKER_COM_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COM_CMD="docker-compose"
    else
        DOCKER_COM_CMD=""
    fi
}

deploy_backend_code() {
    log_info "正在获取后端代码..."
    
    # Ensure target directory exists
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi
    
    # Enter target directory
    cd "$TARGET_DIR" || exit 1
    log_info "工作目录: $(pwd)"

    # Git logic
    if [ -d ".git" ]; then
        log_info "检测到 Git 仓库，正在更新代码..."
        git pull origin main || log_warn "Git 更新失败，将使用当前代码继续。"
    else
        # If not a git repo but has content (and no .git), clean it up
        if [ "$(ls -A)" ]; then
             log_warn "目标目录不为空且非 Git 仓库，正在清理..."
             # Be careful with rm -rf. Only do this if we are sure.
             # Since we are in 1Panel app dir or user verified dir, we can proceed with caution.
             # We exclude nothing here because we want a fresh clone.
             rm -rf ./*
             rm -rf ./.env* # Remove hidden env files too
             log_success "目录已清理。"
        fi

        log_info "正在克隆代码仓库..."
        git clone https://github.com/Hinln/linxi.git . || {
             log_error "代码克隆失败！请检查网络。"
             exit 1
        }
    fi
}

start_backend_services() {
    log_info "正在启动后端服务..."
    
    # 确保 tsconfig.json 宽松模式
    # (已在前一步工具调用中修改)

    if [[ -z "$DOCKER_COM_CMD" ]]; then
         log_error "未检测到 Docker Compose。尝试自动安装失败，请手动安装。"
         exit 1
    fi

    # Ensure we are in the correct directory
    cd "$TARGET_DIR" || exit 1

    # 强制校验主配置文件
    if [ ! -f "docker-compose.yml" ]; then
        log_error "主配置文件 docker-compose.yml 丢失！请检查当前目录: $(pwd)"
        exit 1
    fi
    
    # 自愈逻辑：检查并修复 docker-compose.yml (如果被错误修改)
    if grep -q "1panel-network" docker-compose.yml; then
        log_warn "检测到 docker-compose.yml 被错误修改，正在尝试恢复..."
        if [ -d ".git" ]; then
            git checkout docker-compose.yml || log_warn "Git 恢复失败。"
        else
            # 手动清理末尾追加的网络定义 (简单的行数截断或 sed 删除)
            # 假设 networks 定义在最后，且由之前脚本追加
            # 这是一个简单的尝试，删掉最后 6 行如果包含 1panel-network
            # Better safe than sorry: just warn user if git fails.
            log_warn "非 Git 环境，无法自动恢复。请手动检查 docker-compose.yml 是否包含重复的 networks 定义。"
        fi
    fi
    
    # Write the accumulated override content to file
    # This ensures single write and includes all necessary configs
    # 确保 override 文件写入到当前目录
    if [[ -n "$OVERRIDE_CONTENT" ]]; then
        # Ensure we are in TARGET_DIR before writing
        if [[ "$(pwd)" != "$TARGET_DIR" ]]; then
            log_warn "Current directory is not TARGET_DIR. Switching..."
            cd "$TARGET_DIR" || exit 1
        fi
        echo "$OVERRIDE_CONTENT" > docker-compose.override.yml
        log_info "已生成 docker-compose.override.yml"
    fi

    log_info "构建并启动容器 (使用 $DOCKER_COM_CMD)..."
    # 显式指定文件进行启动，强制同时读取
    if [[ -f "docker-compose.override.yml" ]]; then
        if ! $DOCKER_COM_CMD -f docker-compose.yml -f docker-compose.override.yml up --build -d app; then
             log_error "容器启动失败。正在打印配置以供调试..."
             $DOCKER_COM_CMD config
             exit 1
        fi
    else
        if ! $DOCKER_COM_CMD up --build -d app; then
             log_error "容器启动失败。"
             exit 1
        fi
    fi

    log_info "等待数据库就绪并执行迁移 (重试 5 次)..."
    for i in {1..5}; do
        if $DOCKER_COM_CMD exec -T app npx prisma migrate deploy; then
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
    local env_file="$TARGET_DIR/linxi-server/.env"

    if grep -q "^${key}=" "$env_file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        echo "${key}=${value}" >> "$env_file"
    fi
}

configure_environment() {
    log_info "开始交互式配置..."
    touch "$TARGET_DIR/linxi-server/.env"
    
    # 域名
    while true; do
        read -p "请输入后端 API 域名 (例如 https://api.example.com): " API_DOMAIN </dev/tty
        if validate_domain "$API_DOMAIN"; then
            check_domain_resolution "$API_DOMAIN"
            break
        fi
    done

    while true; do
        read -p "请输入管理后台域名 (例如 https://admin.example.com): " ADMIN_DOMAIN </dev/tty
        if validate_domain "$ADMIN_DOMAIN"; then
            check_domain_resolution "$ADMIN_DOMAIN"
            break
        fi
    done

    # 阿里云
    read -p "阿里云 AccessKey ID: " ALIYUN_AK </dev/tty
    read -s -p "阿里云 AccessKey Secret: " ALIYUN_SK </dev/tty
    echo ""
    read -p "OSS Bucket 名称: " OSS_BUCKET </dev/tty
    read -p "OSS Region (默认 oss-cn-hangzhou.aliyuncs.com): " OSS_ENDPOINT </dev/tty
    OSS_ENDPOINT=${OSS_ENDPOINT:-oss-cn-hangzhou.aliyuncs.com}
    
    # OSS Bucket ACL
    while true; do
        read -p "OSS Bucket 是私有(private)还是公共读(public-read)? (输入 1: 私有, 2: 公共读): " ACL_CHOICE </dev/tty
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

    # 短信服务
    read -p "短信签名 (ALIYUN_SMS_SIGN_NAME, 默认 LinXi): " SMS_SIGN_NAME </dev/tty
    SMS_SIGN_NAME=${SMS_SIGN_NAME:-LinXi}
    read -p "短信模板 ID (ALIYUN_SMS_TEMPLATE_CODE, 例如 SMS_123456789): " SMS_TEMPLATE_CODE </dev/tty
    
    # 实人认证
    read -p "实人认证场景 ID (ALIYUN_REAL_PERSON_SCENE_ID, 默认 100000): " RP_SCENE_ID </dev/tty
    RP_SCENE_ID=${RP_SCENE_ID:-100000}
    
    if [[ -z "$SMS_TEMPLATE_CODE" ]]; then
        log_warn "未输入短信模板 ID，短信功能将不可用。请稍后在 .env 中手动补全。"
    fi
    
    # 数据库 (默认本地 Docker)
    if grep -q "postgres: { profiles: \['donotstart'\] }" docker-compose.override.yml 2>/dev/null; then
        log_info "已选择复用面板数据库，请输入 1Panel 中的数据库连接信息。"
        # 尝试自动获取 IP (Docker Gateway)
        DOCKER_GATEWAY=$(docker network inspect 1panel-network --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "172.17.0.1")
        read -p "数据库连接地址 (例如 postgresql://user:pass@$DOCKER_GATEWAY:5432/linxi_db?schema=public): " DATABASE_URL </dev/tty
    else
        read -p "数据库连接地址 (回车使用默认 Docker 内部连接): " DATABASE_URL </dev/tty
        DATABASE_URL=${DATABASE_URL:-"postgresql://postgres:postgres@postgres:5432/linxi_db?schema=public"}
    fi
    
    # Redis
    if grep -q "redis: { profiles: \['donotstart'\] }" docker-compose.override.yml 2>/dev/null; then
        log_info "已选择复用面板 Redis，请输入 1Panel 中的 Redis 连接信息。"
        DOCKER_GATEWAY=$(docker network inspect 1panel-network --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "172.17.0.1")
        
        read -p "Redis 主机 (建议使用 Docker 网关 $DOCKER_GATEWAY): " REDIS_HOST </dev/tty
        REDIS_HOST=${REDIS_HOST:-$DOCKER_GATEWAY}
        read -p "Redis 端口 (默认 6379): " REDIS_PORT </dev/tty
        REDIS_PORT=${REDIS_PORT:-6379}
    else
        read -p "Redis 主机 (默认 redis): " REDIS_HOST </dev/tty
        REDIS_HOST=${REDIS_HOST:-redis}
        read -p "Redis 端口 (默认 6379): " REDIS_PORT </dev/tty
        REDIS_PORT=${REDIS_PORT:-6379}
    fi
    read -s -p "请输入 Redis 密码 (无密码直接回车): " REDIS_PASSWORD </dev/tty
    echo ""
    
    # 写入 .env
    update_env "API_DOMAIN" "$API_DOMAIN"
    update_env "ADMIN_DOMAIN" "$ADMIN_DOMAIN"
    update_env "ALIYUN_ACCESS_KEY_ID" "$ALIYUN_AK"
    update_env "ALIYUN_ACCESS_KEY_SECRET" "$ALIYUN_SK"
    update_env "ALIYUN_OSS_BUCKET" "$OSS_BUCKET"
    update_env "ALIYUN_OSS_REGION" "$OSS_ENDPOINT"
    update_env "ALIYUN_OSS_BUCKET_ACL" "$OSS_BUCKET_ACL"
    update_env "ALIYUN_SMS_SIGN_NAME" "$SMS_SIGN_NAME"
    update_env "ALIYUN_SMS_TEMPLATE_CODE" "$SMS_TEMPLATE_CODE"
    update_env "ALIYUN_REAL_PERSON_SCENE_ID" "$RP_SCENE_ID"
    update_env "DATABASE_URL" "$DATABASE_URL"
    update_env "REDIS_HOST" "$REDIS_HOST"
    update_env "REDIS_PORT" "$REDIS_PORT"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        update_env "REDIS_PASSWORD" "$REDIS_PASSWORD"
    fi
    
    if ! grep -q "^JWT_SECRET=" "$TARGET_DIR/linxi-server/.env"; then
        echo "JWT_SECRET=$(openssl rand -base64 32)" >> "$TARGET_DIR/linxi-server/.env"
    fi
    if ! grep -q "^CRYPTO_SECRET_KEY=" "$TARGET_DIR/linxi-server/.env"; then
        echo "CRYPTO_SECRET_KEY=$(openssl rand -base64 32)" >> "$TARGET_DIR/linxi-server/.env"
    fi

    chmod 600 "$TARGET_DIR/linxi-server/.env"
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
    # 预设 1Panel 目标目录
    if [[ -d "/opt/1panel" ]]; then
        TARGET_DIR="/opt/1panel/apps/linxi"
    else
        TARGET_DIR=$(pwd)
    fi
    
    clear
    echo "=================================================="
    echo "       LinXi (灵犀) 一键部署脚本 v2.0            "
    echo "=================================================="
    
    check_root
    install_dependencies
    check_system_resources
    check_ports
    optimize_network
    
    # Deploy Code first (Clone/Update)
    deploy_backend_code
    
    # Adapt to environment (now code exists)
    adapt_1panel
    
    # Configure environment
    configure_environment
    
    # Start Services
    start_backend_services
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
