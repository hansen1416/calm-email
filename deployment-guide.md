# Mail Flow 测试版上线完整指南

> **版本**: v1.0.0-beta  
> **更新日期**: 2026-04-19  
> **适用环境**: AWS + Ubuntu 22.04 + MySQL 8.0 + Nginx

---

## 📋 目录

1. [第一阶段：AWS SES 配置](#第一阶段aws-ses-配置)
2. [第二阶段：AWS SNS 配置](#第二阶段aws-sns-配置)
3. [第三阶段：服务器环境准备](#第三阶段服务器环境准备)
4. [第四阶段：应用部署](#第四阶段应用部署)
5. [第五阶段：功能验证](#第五阶段功能验证)
6. [第六阶段：监控与维护](#第六阶段监控与维护)

---

## 第一阶段：AWS SES 配置

### 1.1 验证发件域名/邮箱

1. 登录 [AWS SES 控制台](https://console.aws.amazon.com/ses/)
2. 选择 **Configuration** → **Verified identities**
3. 点击 **Create identity**
4. 选择 **Domain** 或 **Email address**
   - **推荐**: Domain（可以发送任意子域名邮件）
   - 输入域名：`yourdomain.com`
5. 按照 DNS 验证说明添加 TXT 记录
6. 等待验证状态变为 **Verified**（通常几分钟到几小时）

### 1.2 申请生产访问权限（如未申请）

1. 在 SES 控制台选择 **Configuration** → **Account dashboard**
2. 点击 **Request production access**
3. 填写申请理由：
   ```
   We need to send transactional emails to our users
   for account notifications and marketing campaigns.
   Expected volume: 1000-5000 emails per day.
   ```
4. 等待 AWS 审核（通常 24 小时内）

### 1.3 创建 SES 配置集（Configuration Set）

1. 在 SES 控制台选择 **Configuration** → **Configuration sets**
2. 点击 **Create set**
3. 配置集名称：`mailflow-config-set`
4. 点击 **Create**

### 1.4 配置事件发布（Event Publishing）

1. 进入刚创建的 `mailflow-config-set`
2. 选择 **Event destinations** → **Add destination**
3. 选择 **Amazon SNS** → **Next**
4. 事件类型勾选：
   - ✅ Sends
   - ✅ Deliveries
   - ✅ Opens
   - ✅ Clicks
   - ✅ Bounces
   - ✅ Complaints
   - ✅ Delivery delays (可选)
5. SNS Topic 选择（将在第二阶段创建）
6. 点击 **Next** → **Add destination**

### 1.5 创建 IAM 用户并获取凭证

1. 登录 [AWS IAM 控制台](https://console.aws.amazon.com/iam/)
2. 选择 **Users** → **Add users**
3. 用户名：`mailflow-ses-user`
4. 选择 **Attach policies directly**
5. 添加策略：
   - **AmazonSESFullAccess**（或自定义最小权限）
   - **AmazonSNSFullAccess**（用于 SNS 操作）
6. 创建用户后，点击 **Security credentials** → **Create access key**
7. 选择 **Application running outside AWS**
8. 保存 **Access Key ID** 和 **Secret Access Key**（⚠️ Secret Key 只显示一次）

### 1.6 自定义权限策略（推荐）

创建自定义策略，最小权限原则：

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "arn:aws:ses:us-east-1:YOUR_ACCOUNT_ID:identity/yourdomain.com"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": "arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:mailflow-events"
        }
    ]
}
```

---

## 第二阶段：AWS SNS 配置

### 2.1 创建 SNS Topic

1. 登录 [AWS SNS 控制台](https://console.aws.amazon.com/sns/)
2. 选择 **Topics** → **Create topic**
3. 类型：**Standard**
4. 名称：`mailflow-events`
5. 显示名称：`Mail Flow Events`
6. 点击 **Create topic**
7. 复制 **Topic ARN**（如：`arn:aws:sns:us-east-1:123456789:mailflow-events`）

### 2.2 创建 HTTPS 订阅

1. 进入 `mailflow-events` Topic
2. 选择 **Subscriptions** → **Create subscription**
3. 协议：**HTTPS**
4. 端点：`https://yourdomain.com/api/webhooks/sns`
5. 点击 **Create subscription**

### 2.3 确认订阅（自动）

1. SNS 会发送订阅确认请求到您的端点
2. 后端代码会自动处理确认（代码已实现）
3. 确认后状态变为 **Confirmed**

**手动确认方法**（如果需要）：

1. 查看应用日志，找到确认 URL
2. 或检查 SNS 订阅页面，点击 **Request confirmation**
3. 从日志中提取 `SubscribeURL` 并访问

### 2.4 配置 SES 使用 SNS

1. 回到 SES 控制台 → Configuration sets → `mailflow-config-set`
2. 编辑 Event destinations
3. SNS Topic 选择 `mailflow-events`
4. 保存

---

## 第三阶段：服务器环境准备

### 3.1 系统要求

- **OS**: Ubuntu 22.04 LTS
- **Python**: 3.10+
- **Node.js**: 18+
- **数据库**: MySQL 8.0+
- **Web 服务器**: Nginx
- **进程管理**: systemd 或 PM2

### 3.2 安装依赖

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Python 3.10
sudo apt install python3.10 python3.10-venv python3.10-dev -y

# 安装 Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install nodejs -y

# 安装 MySQL
sudo apt install mysql-server -y
sudo mysql_secure_installation

# 安装 Nginx
sudo apt install nginx -y

# 安装其他依赖
sudo apt install build-essential libmysqlclient-dev pkg-config -y
```

### 3.3 配置 MySQL

```bash
# 登录 MySQL
sudo mysql -u root -p

# 创建数据库和用户
CREATE DATABASE IF NOT EXISTS contact_mail_prod CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER 'mailflow'@'localhost' IDENTIFIED BY 'YourStrongPassword123!';

GRANT ALL PRIVILEGES ON contact_mail_prod.* TO 'mailflow'@'localhost';

FLUSH PRIVILEGES;

EXIT;
```

### 3.4 配置防火墙

```bash
# 允许 HTTP/HTTPS
sudo ufw allow 'Nginx Full'

# 允许 SSH（如果未允许）
sudo ufw allow OpenSSH

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

---

## 第四阶段：应用部署

### 4.1 创建应用目录

```bash
# 创建目录
sudo mkdir -p /var/www/mailflow
sudo chown -R $USER:$USER /var/www/mailflow

# 克隆代码（或使用 SCP/FTP 上传）
cd /var/www/mailflow
git clone <your-repo-url> .
```

### 4.2 后端部署

#### 4.2.1 创建 Python 虚拟环境

```bash
cd /var/www/mailflow/pythonBack

# 创建虚拟环境
python3.10 -m venv .venv

# 激活
source .venv/bin/activate

# 升级 pip
pip install --upgrade pip

# 安装依赖
pip install -r requirements.txt
```

#### 4.2.2 配置环境变量

创建 `.env` 文件：

```bash
cd /var/www/mailflow/pythonBack
nano .env
```

添加以下内容：

```bash
# ========================================
# 安全密钥（必须修改！使用随机字符串）
# ========================================
SECRET_KEY=your-random-256-bit-secret-key-change-this-in-production
JWT_SECRET_KEY=your-jwt-secret-key-change-this-in-production

# ========================================
# 数据库配置
# ========================================
DATABASE_URI=mysql+pymysql://mailflow:YourStrongPassword123!@localhost:3306/contact_mail_prod

# ========================================
# AWS 配置（从 IAM 获取）
# ========================================
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SES_SENDER_EMAIL=noreply@yourdomain.com

# ========================================
# 应用配置
# ========================================
# 生产模式：关闭模拟发送
MOCK_EMAIL_SEND=false

# CORS 限制为生产域名
CORS_ORIGINS=https://yourdomain.com

# 日志级别
LOG_LEVEL=INFO
```

**生成随机密钥：**

```bash
# 生成 256-bit 密钥
openssl rand -hex 32
```

#### 4.2.3 初始化数据库

```bash
cd /var/www/mailflow/pythonBack
source .venv/bin/activate

# 创建数据库表
python -c "
from app import create_app
from models import db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database initialized successfully')
"
```

#### 4.2.4 配置 Gunicorn

创建启动脚本：

```bash
sudo nano /var/www/mailflow/pythonBack/start.sh
```

添加：

```bash
#!/bin/bash
cd /var/www/mailflow/pythonBack
source .venv/bin/activate

# 使用环境变量文件
export $(cat .env | xargs)

# 启动 Gunicorn
exec gunicorn -c gunicorn.conf.py app:app
```

修改权限：

```bash
chmod +x /var/www/mailflow/pythonBack/start.sh
```

修改 Gunicorn 配置：

```bash
nano /var/www/mailflow/pythonBack/gunicorn.conf.py
```

内容：

```python
import os
import multiprocessing

# 服务器绑定
bind = "127.0.0.1:8880"

# 工作进程数
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"

# 超时设置
timeout = 120
keepalive = 5

# 日志配置（使用环境变量）
log_dir = os.environ.get('LOG_DIR', '/var/log/mailflow')
os.makedirs(log_dir, exist_ok=True)

accesslog = os.path.join(log_dir, 'access.log')
errorlog = os.path.join(log_dir, 'error.log')
loglevel = os.environ.get('LOG_LEVEL', 'info').lower()

# 进程文件
pidfile = os.path.join(log_dir, 'gunicorn.pid')

# 应用名称
proc_name = 'mailflow'

# 守护进程模式（生产环境使用 systemd 时不开启）
daemon = False

# 工作进程用户（生产环境）
# user = 'www-data'
# group = 'www-data'
```

#### 4.2.5 创建 Systemd 服务

```bash
sudo nano /etc/systemd/system/mailflow.service
```

内容：

```ini
[Unit]
Description=Mail Flow Backend
After=network.target mysql.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/mailflow/pythonBack
Environment="PATH=/var/www/mailflow/pythonBack/.venv/bin"
EnvironmentFile=/var/www/mailflow/pythonBack/.env
ExecStart=/var/www/mailflow/pythonBack/.venv/bin/gunicorn -c gunicorn.conf.py app:app
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

启用服务：

```bash
# 设置权限
sudo chown -R www-data:www-data /var/www/mailflow/pythonBack
sudo chmod 600 /var/www/mailflow/pythonBack/.env

# 重载 systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start mailflow
sudo systemctl enable mailflow

# 查看状态
sudo systemctl status mailflow
```

### 4.3 前端部署

#### 4.3.1 安装依赖并构建

```bash
cd /var/www/mailflow/vue3Model

# 安装依赖
npm install

# 修改生产环境配置
nano vite.config.js
```

修改 `vite.config.js`：

```javascript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5175,
    // 生产环境不需要代理
    proxy: process.env.NODE_ENV === 'development' ? {
      '/api': {
        target: 'http://localhost:8880',
        changeOrigin: true,
      }
    } : undefined
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
  }
})
```

构建：

```bash
# 构建生产版本
npm run build

# 确认构建成功
ls -la dist/
```

#### 4.3.2 复制到 Nginx 目录

```bash
# 创建目录
sudo mkdir -p /var/www/mailflow/dist

# 复制文件
sudo cp -r /var/www/mailflow/vue3Model/dist/* /var/www/mailflow/dist/

# 设置权限
sudo chown -R www-data:www-data /var/www/mailflow/dist
```

### 4.4 配置 Nginx

```bash
sudo nano /etc/nginx/sites-available/mailflow
```

内容：

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    # SSL 证书（使用 Let's Encrypt 或自签名）
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # 日志
    access_log /var/log/nginx/mailflow.access.log;
    error_log /var/log/nginx/mailflow.error.log;

    # 前端静态文件
    location / {
        root /var/www/mailflow/dist;
        try_files $uri $uri/ /index.html;
        
        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }

    # API 代理到后端
    location /api/ {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持（如果需要）
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 健康检查端点（可选，直接暴露）
    location /health {
        proxy_pass http://127.0.0.1:8880/api/health;
    }
}
```

启用配置：

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/mailflow /etc/nginx/sites-enabled/

# 删除默认配置（可选）
sudo rm /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
```

### 4.5 配置 SSL 证书（Let's Encrypt）

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx -y

# 获取证书
sudo certbot --nginx -d yourdomain.com

# 自动续期测试
sudo certbot renew --dry-run
```

---

## 第五阶段：功能验证

### 5.1 基础健康检查

```bash
# 测试健康端点
curl https://yourdomain.com/api/health
curl https://yourdomain.com/api/health/ready
curl https://yourdomain.com/api/health/metrics
```

### 5.2 用户注册/登录测试

```bash
# 1. 注册
curl -X POST https://yourdomain.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!","email":"admin@yourdomain.com"}'

# 2. 登录
curl -X POST https://yourdomain.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!"}'

# 响应应包含 access_token 和 refresh_token
```

### 5.3 邮件发送测试

```bash
# 1. 创建联系人（使用登录返回的 token）
curl -X POST https://yourdomain.com/api/contacts \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"your-test-email@gmail.com"}'

# 2. 创建邮件模板
curl -X POST https://yourdomain.com/api/templates \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"Welcome Email",
    "subject":"Welcome to Mail Flow",
    "body":"<h1>Hello!</h1><p>Welcome to our service.</p>"
  }'

# 3. 发送邮件
curl -X POST https://yourdomain.com/api/email/send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": 1,
    "contact_ids": [1],
    "mock": false
  }'
```

### 5.4 SNS 回调测试

#### 方法 1：模拟事件（推荐）

```bash
# 模拟点击事件
curl -X POST https://yourdomain.com/api/webhooks/simulate/event \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "click",
    "message_id": "test-message-123",
    "recipient_email": "your-test-email@gmail.com",
    "event_data": {
      "click": {
        "link": "https://yourdomain.com/unsubscribe"
      }
    },
    "mock_send": true
  }'
```

#### 方法 2：真实 SES 发送测试

1. 在 Web 界面创建简单工作流（只有一个 email 节点）
2. 配置收件人为您的测试邮箱
3. 执行工作流，检查是否收到邮件
4. 点击邮件中的链接
5. 检查 SNS 事件是否到达后端（查看日志）

### 5.5 工作流执行测试

```bash
# 创建工作流（需要先有模板和联系人）
curl -X POST https://yourdomain.com/api/workflow \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Workflow",
    "flow_data": "{\"nodes\":[],\"edges\":[]}",
    "status": "active"
  }'

# 执行工作流
curl -X POST https://yourdomain.com/api/workflow/1/execute \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# 查看实例状态
curl https://yourdomain.com/api/workflow/1/instances \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 第六阶段：监控与维护

### 6.1 查看应用日志

```bash
# 实时查看日志
sudo tail -f /var/log/mailflow/error.log
sudo tail -f /var/log/mailflow/access.log

# 查看应用日志
tail -f /var/www/mailflow/pythonBack/app.log

# 查看系统服务日志
sudo journalctl -u mailflow -f
```

### 6.2 监控端点

| 端点 | 用途 | 检查命令 |
|------|------|----------|
| `/api/health` | 基础健康检查 | `curl https://yourdomain.com/api/health` |
| `/api/health/ready` | 数据库连接检查 | `curl https://yourdomain.com/api/health/ready` |
| `/api/health/live` | 存活检查 | `curl https://yourdomain.com/api/health/live` |
| `/api/health/metrics` | 系统指标 | `curl https://yourdomain.com/api/health/metrics` |

### 6.3 常用维护命令

```bash
# 重启后端服务
sudo systemctl restart mailflow

# 查看服务状态
sudo systemctl status mailflow

# 重启 Nginx
sudo systemctl reload nginx

# 查看 Nginx 错误日志
sudo tail -f /var/log/nginx/mailflow.error.log

# 数据库备份
mysqldump -u mailflow -p contact_mail_prod > backup_$(date +%Y%m%d).sql

# 更新代码后重新部署
cd /var/www/mailflow
git pull
# 前端重新构建
cd vue3Model && npm run build && sudo cp -r dist/* /var/www/mailflow/dist/
# 后端重启
sudo systemctl restart mailflow
```

### 6.4 性能监控

```bash
# 查看系统资源使用
top
htop

# 查看 MySQL 状态
sudo mysql -u root -p -e "SHOW PROCESSLIST;"

# 查看 Gunicorn 进程
ps aux | grep gunicorn
```

---

## 🚨 故障排查

### 问题 1：SNS 回调失败

**症状**：AWS SNS 订阅显示 PendingConfirmation

**解决**：
1. 检查 HTTPS 证书是否有效
2. 检查 Nginx 配置是否正确转发 `/api/webhooks/sns`
3. 查看应用日志：
   ```bash
   sudo tail -f /var/log/mailflow/error.log
   ```

### 问题 2：邮件发送失败

**症状**：邮件发送 API 返回 500 错误

**解决**：
1. 检查 AWS 凭证是否正确
2. 检查 SES 发件邮箱是否已验证
3. 检查 SES 是否已从沙盒移除
4. 查看详细错误：
   ```bash
   tail -f /var/www/mailflow/pythonBack/app.log
   ```

### 问题 3：数据库连接失败

**症状**：应用启动失败，提示数据库错误

**解决**：
1. 检查 `.env` 文件中的 `DATABASE_URI`
2. 确认 MySQL 用户权限：
   ```sql
   SHOW GRANTS FOR 'mailflow'@'localhost';
   ```
3. 检查 MySQL 服务状态：
   ```bash
   sudo systemctl status mysql
   ```

### 问题 4：前端页面空白

**症状**：访问网站显示空白页面

**解决**：
1. 检查前端是否已构建：`ls /var/www/mailflow/dist/`
2. 检查 Nginx 根目录配置
3. 浏览器 F12 查看 Console 错误

---

## 📞 支持

如遇问题，请检查：

1. **应用日志**: `/var/www/mailflow/pythonBack/app.log`
2. **Nginx 日志**: `/var/log/nginx/mailflow.error.log`
3. **系统日志**: `sudo journalctl -u mailflow`
4. **AWS CloudWatch**: 查看 SES 和 SNS 的 CloudWatch 日志

---

## ✅ 部署检查清单

在正式上线前，请确认以下项目：

- [ ] SES 域名/邮箱已验证
- [ ] SES 生产访问权限已批准
- [ ] SNS Topic 已创建并订阅成功
- [ ] AWS IAM 用户已创建，凭证已配置
- [ ] 服务器防火墙已配置（80/443 开放）
- [ ] MySQL 数据库已创建，用户已授权
- [ ] `.env` 文件已配置，密钥已随机生成
- [ ] 后端服务已通过 systemd 启动
- [ ] Nginx 已配置，SSL 证书已安装
- [ ] 健康检查端点可正常访问
- [ ] 用户注册/登录功能正常
- [ ] 邮件发送功能正常（使用真实 SES）
- [ ] SNS 回调功能正常

---

**完成以上步骤后，您的 Mail Flow 测试版即可上线运行！**
