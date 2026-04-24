#!/bin/bash
# ========================================
# Mail Flow 自动部署脚本
# 在 Ubuntu 22.04 服务器上运行
# ========================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
APP_NAME="mailflow"
APP_DIR="/var/www/mailflow"
DOMAIN="${1:-yourdomain.com}"
DB_PASSWORD="${2:-$(openssl rand -base64 24)}"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 更新系统
update_system() {
    log_info "更新系统..."
    apt update && apt upgrade -y
}

# 安装依赖
install_dependencies() {
    log_info "安装依赖..."
    apt install -y \
        python3.10 python3.10-venv python3.10-dev \
        python3-pip \
        nginx \
        mysql-server \
        curl wget git \
        build-essential libmysqlclient-dev pkg-config \
        certbot python3-certbot-nginx
}

# 配置 MySQL
setup_mysql() {
    log_info "配置 MySQL..."
    
    # 启动 MySQL
    systemctl start mysql
    systemctl enable mysql
    
    # 创建数据库和用户
    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS contact_mail_prod CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'mailflow'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON contact_mail_prod.* TO 'mailflow'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    log_info "数据库密码: ${DB_PASSWORD}"
    echo "${DB_PASSWORD}" > /root/.db_password
    chmod 600 /root/.db_password
}

# 创建应用目录
setup_app_directory() {
    log_info "创建应用目录..."
    
    mkdir -p ${APP_DIR}
    mkdir -p /var/log/mailflow
    mkdir -p /var/log/frp
    
    # 检查代码是否存在
    if [[ ! -d "${APP_DIR}/.git" ]]; then
        log_warn "请手动将代码复制到 ${APP_DIR}"
        log_info "例如: git clone <your-repo> ${APP_DIR}"
        exit 1
    fi
}

# 配置后端
setup_backend() {
    log_info "配置后端..."
    
    cd ${APP_DIR}/pythonBack
    
    # 创建虚拟环境
    python3.10 -m venv .venv
    source .venv/bin/activate
    
    # 安装依赖
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # 创建环境变量文件
    SECRET_KEY=$(openssl rand -hex 32)
    JWT_SECRET=$(openssl rand -hex 32)
    
    cat > .env <<EOF
SECRET_KEY=${SECRET_KEY}
JWT_SECRET_KEY=${JWT_SECRET}
DATABASE_URI=mysql+pymysql://mailflow:${DB_PASSWORD}@localhost:3306/contact_mail_prod
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
SES_SENDER_EMAIL=noreply@${DOMAIN}
MOCK_EMAIL_SEND=true
CORS_ORIGINS=https://${DOMAIN}
LOG_LEVEL=INFO
EOF
    
    # 设置权限
    chmod 600 .env
    
    # 初始化数据库
    python -c "
from app import create_app
from models import db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database initialized')
"
    
    # 设置目录权限
    chown -R www-data:www-data ${APP_DIR}/pythonBack
}

# 配置前端
setup_frontend() {
    log_info "配置前端..."
    
    cd ${APP_DIR}/vue3Model
    
    # 安装 Node.js 依赖
    npm install
    
    # 构建
    npm run build
    
    # 复制到 Nginx 目录
    cp -r dist/* /var/www/mailflow/dist/
    
    # 设置权限
    chown -R www-data:www-data /var/www/mailflow/dist
}

# 配置 Nginx
setup_nginx() {
    log_info "配置 Nginx..."
    
    # 复制配置文件
    cp ${APP_DIR}/docs/nginx-config/mailflow.conf /etc/nginx/sites-available/mailflow
    
    # 替换域名
    sed -i "s/yourdomain.com/${DOMAIN}/g" /etc/nginx/sites-available/mailflow
    
    # 启用配置
    ln -sf /etc/nginx/sites-available/mailflow /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    nginx -t
    
    # 启动 Nginx
    systemctl start nginx
    systemctl enable nginx
}

# 配置 SSL
setup_ssl() {
    log_info "配置 SSL 证书..."
    
    # 使用 Let's Encrypt
    certbot --nginx -d ${DOMAIN} --agree-tos --non-interactive --email admin@${DOMAIN}
    
    # 设置自动续期
    systemctl enable certbot.timer
    systemctl start certbot.timer
}

# 配置 Systemd 服务
setup_systemd() {
    log_info "配置 Systemd 服务..."
    
    # 复制服务文件
    cp ${APP_DIR}/docs/backend-config/mailflow.service /etc/systemd/system/
    
    # 重载配置
    systemctl daemon-reload
    
    # 启动服务
    systemctl start mailflow
    systemctl enable mailflow
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    ufw default deny incoming
    ufw default allow outgoing
    
    ufw allow 22/tcp      # SSH
    ufw allow 80/tcp      # HTTP
    ufw allow 443/tcp     # HTTPS
    
    ufw --force enable
}

# 显示完成信息
show_completion() {
    echo ""
    echo "========================================"
    echo -e "${GREEN}部署完成!${NC}"
    echo "========================================"
    echo ""
    echo "应用地址: https://${DOMAIN}"
    echo "健康检查: https://${DOMAIN}/api/health"
    echo ""
    echo "数据库密码保存在: /root/.db_password"
    echo ""
    echo "常用命令:"
    echo "  查看服务状态: systemctl status mailflow"
    echo "  查看日志: tail -f /var/log/mailflow/error.log"
    echo "  重启服务: systemctl restart mailflow"
    echo "  重启 Nginx: systemctl reload nginx"
    echo ""
    echo -e "${YELLOW}下一步:${NC}"
    echo "1. 配置 AWS 凭证: nano ${APP_DIR}/pythonBack/.env"
    echo "2. 配置 SNS Webhook: https://${DOMAIN}/api/webhooks/sns"
    echo "3. 注册账户并测试"
    echo ""
}

# 主函数
main() {
    log_info "开始部署 Mail Flow..."
    
    check_root
    update_system
    install_dependencies
    setup_mysql
    setup_app_directory
    setup_backend
    setup_frontend
    setup_nginx
    setup_ssl
    setup_systemd
    setup_firewall
    
    show_completion
}

# 运行主函数
main "$@"
