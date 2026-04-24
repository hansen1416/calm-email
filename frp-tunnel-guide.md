# FRP 内网穿透配置指南 - 本地开发测试 AWS 服务

> **场景**: 在本地开发环境测试真实的 AWS SES/SNS 回调  
> **方案**: 使用 FRP (Fast Reverse Proxy) 内网穿透  
> **版本**: v1.0  
> **更新日期**: 2026-04-19

---

## 📋 目录

1. [架构说明](#架构说明)
2. [前置条件](#前置条件)
3. [服务端配置（公网服务器）](#服务端配置公网服务器)
4. [客户端配置（本地开发机）](#客户端配置本地开发机)
5. [AWS SNS 配置调整](#aws-sns-配置调整)
6. [本地开发环境配置](#本地开发环境配置)
7. [启动与测试](#启动与测试)
8. [常见问题](#常见问题)

---

## 架构说明

```
┌─────────────────┐                    ┌──────────────────┐
│   AWS SES/SNS   │ ───HTTPS Callback───▶│  公网服务器      │
│                 │    yourdomain.com    │  (FRP Server)    │
└─────────────────┘                      └────────┬─────────┘
                                                  │
                                                  │ FRP Tunnel
                                                  │ (内网穿透)
                                                  │
                                          ┌───────▼─────────┐
                                          │  本地开发机     │
                                          │  (FRP Client)   │
                                          │  localhost:8880 │
                                          └─────────────────┘
```

**工作流程**:
1. AWS SNS 发送事件到 `https://yourdomain.com/api/webhooks/sns`
2. Nginx 将请求转发到 FRP 服务端（监听 7000 端口）
3. FRP 服务端通过隧道将请求转发到本地开发机
4. 本地 Flask 应用接收并处理 SNS 事件

---

## 前置条件

### 必需组件

| 组件 | 说明 | 安装位置 |
|------|------|----------|
| 公网服务器 | 有公网 IP，用于部署 FRP 服务端 | 云服务器 |
| 域名 + HTTPS | 用于接收 AWS SNS 回调 | 已配置 SSL |
| FRP 服务端 | frps | 公网服务器 |
| FRP 客户端 | frpc | 本地开发机 |
| 本地 Flask 后端 | 运行在 localhost:8880 | 本地开发机 |

### 软件下载

```bash
# 从 GitHub 下载最新版 FRP
# https://github.com/fatedier/frp/releases

# Linux (公网服务器)
wget https://github.com/fatedier/frp/releases/download/v0.53.2/frp_0.53.2_linux_amd64.tar.gz

# Windows (本地开发机)
# 下载 frp_0.53.2_windows_amd64.zip
```

---

## 服务端配置（公网服务器）

### 1. 安装 FRP 服务端

```bash
# 下载并解压
cd /opt
wget https://github.com/fatedier/frp/releases/download/v0.53.2/frp_0.53.2_linux_amd64.tar.gz
tar -xzf frp_0.53.2_linux_amd64.tar.gz
cd frp_0.53.2_linux_amd64

# 复制二进制文件
sudo cp frps /usr/local/bin/
sudo chmod +x /usr/local/bin/frps

# 创建配置目录
sudo mkdir -p /etc/frp
sudo mkdir -p /var/log/frp
```

### 2. 配置 FRP 服务端

创建配置文件 `/etc/frp/frps.toml`：

```toml
# FRP 服务端配置
bindPort = 7000

# 可选：Dashboard 配置（用于监控）
dashboardPort = 7500
dashboardUser = admin
dashboardPwd = your-dashboard-password

# Token 认证（必须与客户端一致）
auth.method = "token"
auth.token = "your-secure-token-change-this"

# 日志配置
log.to = "/var/log/frp/frps.log"
log.level = "info"
log.maxDays = 30

# 允许的端口范围（用于随机分配）
allowPorts = [
  { start = 6000, end = 7000 }
]
```

### 3. 创建 Systemd 服务

创建文件 `/etc/systemd/system/frps.service`：

```ini
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
# 重载配置
sudo systemctl daemon-reload

# 启动 FRP 服务端
sudo systemctl start frps
sudo systemctl enable frps

# 查看状态
sudo systemctl status frps

# 查看日志
sudo journalctl -u frps -f
```

### 4. 开放防火墙

```bash
# 开放 FRP 端口
sudo ufw allow 7000/tcp
sudo ufw allow 7500/tcp  # Dashboard（可选）

# 如果限制 IP，只允许本地开发机 IP
# sudo ufw allow from YOUR_LOCAL_IP to any port 7000
```

### 5. Nginx 配置（重要）

修改 Nginx 配置，将 `/api/webhooks/sns` 转发到 FRP 服务端：

```bash
sudo nano /etc/nginx/sites-available/mailflow
```

在 `server` 块中添加：

```nginx
# SNS Webhook 转发到 FRP 服务端
location /api/webhooks/sns {
    # 方案 1：直接转发到本地 FRP 客户端（如果客户端在同一服务器）
    # proxy_pass http://127.0.0.1:8880;
    
    # 方案 2：通过 FRP 服务端转发（推荐）
    # FRP 服务端会将请求转发到本地开发机
    proxy_pass http://127.0.0.1:7000;
    
    # 或者使用方案 3：直接代理到本地开发机（需要本地有公网 IP）
    # proxy_pass http://YOUR_LOCAL_PUBLIC_IP:8880;
    
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # 超时设置（SNS 可能需要较长时间）
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}

# 其他 API 转发到本地后端（可选，用于统一入口）
# location /api/ {
#     proxy_pass http://127.0.0.1:7000;  # 通过 FRP 转发
# }
```

**注意**: 实际上 FRP 的工作方式是客户端主动连接服务端建立隧道，不需要 Nginx 直接转发到 FRP 端口。

正确的配置应该是：

```nginx
# 正常 API 转发到本地后端（如果后端在服务器上）
location /api/ {
    proxy_pass http://127.0.0.1:8880;
}

# SNS Webhook 保持正常，由后端代码处理
# 如果本地开发时需要测试，使用下面的方案
```

**实际部署方案**:

由于本地开发机无法直接接收外部请求，我们使用 **FRP TCP 隧道**：

```
AWS SNS ──HTTPS──▶ 公网服务器:443 ──▶ Nginx ──▶ localhost:8080 (FRP Server)
                                                    │
                                                    │ TCP Tunnel
                                                    ▼
                                            本地开发机:8880 (FRP Client)
```

修改 FRP 配置，使用 subdomain 或自定义域名：

```toml
# frps.toml - 添加 subdomain 支持
subDomainHost = "frp.yourdomain.com"
```

然后 Nginx 配置：

```nginx
# 通配子域名指向 FRP
server {
    listen 443 ssl;
    server_name *.frp.yourdomain.com;
    
    ssl_certificate /path/to/wildcard.crt;
    ssl_certificate_key /path/to/wildcard.key;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 客户端配置（本地开发机）

### 1. 安装 FRP 客户端

**Windows:**

```powershell
# 下载并解压
# https://github.com/fatedier/frp/releases/download/v0.53.2/frp_0.53.2_windows_amd64.zip

# 解压到 C:\frp
# 目录结构：
# C:\frp\
#   ├── frpc.exe
#   ├── frpc.toml
#   └── start.bat
```

**Mac/Linux:**

```bash
# 下载
wget https://github.com/fatedier/frp/releases/download/v0.53.2/frp_0.53.2_darwin_amd64.tar.gz

# 解压
tar -xzf frp_0.53.2_darwin_amd64.tar.gz
sudo cp frp_0.53.2_darwin_amd64/frpc /usr/local/bin/
```

### 2. 配置 FRP 客户端

创建配置文件 `C:\frp\frpc.toml`（Windows）或 `~/.frp/frpc.toml`（Mac/Linux）：

```toml
# ========================================
# FRP 客户端配置 - 本地开发机
# ========================================

# 服务端地址
serverAddr = "your-server-ip-or-domain"
serverPort = 7000

# 认证（必须与服务端一致）
auth.method = "token"
auth.token = "your-secure-token-change-this"

# 日志配置
log.to = "./frpc.log"
log.level = "info"
log.maxDays = 7

# ========================================
# 代理配置
# ========================================

# 方案 1：TCP 隧道（最简单）
[[proxies]]
name = "local-flask"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8880
# 远程端口（服务端会监听这个端口）
remotePort = 8880

# 方案 2：HTTP 隧道（推荐，支持自定义域名）
[[proxies]]
name = "local-flask-http"
type = "http"
localIP = "127.0.0.1"
localPort = 8880
customDomains = ["dev.yourdomain.com"]

# 方案 3：HTTPS 隧道（需要证书）
[[proxies]]
name = "local-flask-https"
type = "https"
localIP = "127.0.0.1"
localPort = 8880
customDomains = ["dev.yourdomain.com"]
```

### 3. 启动脚本

**Windows (`start.bat`)**：

```batch
@echo off
cd /d C:\frp
frpc.exe -c frpc.toml
pause
```

**Mac/Linux (`start.sh`)**：

```bash
#!/bin/bash
cd ~/frp
./frpc -c frpc.toml
```

```bash
chmod +x start.sh
```

### 4. 后台运行（可选）

**Windows - 使用 NSSM 创建服务**：

```powershell
# 下载 NSSM
# https://nssm.cc/download

# 安装服务
nssm install frpc C:\frp\frpc.exe -c C:\frp\frpc.toml
nssm start frpc
```

**Mac - 使用 LaunchAgent**：

创建文件 `~/Library/LaunchAgents/com.frpc.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.frpc</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/frpc</string>
        <string>-c</string>
        <string>~/.frp/frpc.toml</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

启动：

```bash
launchctl load ~/Library/LaunchAgents/com.frpc.plist
```

---

## AWS SNS 配置调整

### 方案 1：使用 TCP 隧道（临时测试）

如果 FRP 配置了 `remotePort = 8880`，则 AWS SNS 订阅端点为：

```
http://your-server-ip:8880/api/webhooks/sns
```

**注意**: AWS SNS 要求 HTTPS，所以此方案仅适合测试，生产环境不推荐使用。

### 方案 2：使用域名 + HTTPS（推荐）

配置 Nginx 反向代理到 FRP 服务端：

```nginx
# /etc/nginx/sites-available/dev-mailflow

server {
    listen 80;
    server_name dev.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name dev.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # 转发到 FRP 服务端（监听本地 8080 端口）
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

然后 FRP 服务端配置：

```toml
# frps.toml
bindPort = 7000

# vhost HTTP 端口
vhostHTTPPort = 8080
vhostHTTPSPort = 8443

subDomainHost = "frp.yourdomain.com"
```

FRP 客户端配置：

```toml
# frpc.toml
serverAddr = "your-server-ip"
serverPort = 7000

auth.method = "token"
auth.token = "your-secure-token"

[[proxies]]
name = "dev-mailflow"
type = "http"
localIP = "127.0.0.1"
localPort = 8880
customDomains = ["dev.yourdomain.com"]
```

AWS SNS 订阅端点：

```
https://dev.yourdomain.com/api/webhooks/sns
```

---

## 本地开发环境配置

### 1. 修改后端配置

编辑 `pythonBack/.env`：

```bash
# 使用生产模式（真实 AWS 发送）
MOCK_EMAIL_SEND=false

# AWS 凭证（使用测试环境的凭证）
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SES_SENDER_EMAIL=noreply@yourdomain.com

# 数据库（使用本地开发数据库）
DATABASE_URI=mysql+pymysql://root:root@localhost:3306/contact_mail

# CORS 配置（允许 FRP 域名）
CORS_ORIGINS=http://localhost:5175,https://dev.yourdomain.com
```

### 2. 启动本地后端

```bash
cd pythonBack
source .venv/bin/activate  # 或 .venv\Scripts\activate (Windows)

# 加载环境变量
export $(cat .env | xargs)  # Windows: 使用 direnv 或手动设置

# 启动 Flask 开发服务器
python app.py
```

或者使用 Gunicorn：

```bash
gunicorn -w 2 -b 127.0.0.1:8880 app:app
```

### 3. 启动本地前端

```bash
cd vue3Model
npm install
npm run dev
```

### 4. 启动 FRP 客户端

```bash
# Windows
C:\frp\start.bat

# Mac/Linux
~/frp/start.sh
```

检查隧道是否建立成功：

```bash
# 访问 FRP Dashboard（如果启用）
http://your-server-ip:7500

# 或者检查日志
tail -f ~/frp/frpc.log
```

---

## 启动与测试

### 启动顺序

1. **启动本地后端**（localhost:8880）
2. **启动本地前端**（localhost:5175）
3. **启动 FRP 客户端**（建立隧道）
4. **验证隧道**（访问 https://dev.yourdomain.com/api/health）

### 测试 SNS 回调

**方法 1：使用 AWS SES 真实发送**

1. 在本地 Web 界面创建联系人（使用您的真实邮箱）
2. 创建邮件模板
3. 创建工作流（包含 driver 节点）
4. 执行工作流
5. 检查邮箱是否收到邮件
6. 点击邮件中的链接
7. 查看本地后端日志，确认 SNS 事件已收到

**方法 2：使用模拟事件（更快）**

```bash
# 通过 FRP 域名测试
curl -X POST https://dev.yourdomain.com/api/webhooks/simulate/event \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "click",
    "message_id": "test-message-123",
    "recipient_email": "test@example.com",
    "event_data": {
      "click": {"link": "https://example.com"}
    },
    "mock_send": true
  }'
```

**方法 3：AWS SNS 控制台测试**

1. 登录 AWS SNS 控制台
2. 选择您的 Topic
3. 点击 **Publish message**
4. 输入测试消息
5. 查看本地后端日志

---

## 常见问题

### Q1: FRP 连接失败

**症状**: `connection refused` 或 `i/o timeout`

**解决**:
```bash
# 1. 检查服务端是否运行
sudo systemctl status frps

# 2. 检查防火墙
sudo ufw status
sudo ufw allow 7000/tcp

# 3. 检查服务端日志
sudo tail -f /var/log/frp/frps.log

# 4. 检查客户端配置
# serverAddr 必须是公网 IP 或域名
# serverPort 必须与服务端 bindPort 一致
```

### Q2: SNS 回调返回 502/504

**症状**: AWS SNS 控制台显示订阅失败

**解决**:
```bash
# 1. 检查 Nginx 错误日志
sudo tail -f /var/log/nginx/dev-mailflow.error.log

# 2. 检查 FRP 客户端是否在线
# 查看 frpc.log

# 3. 检查本地后端是否运行
curl http://localhost:8880/api/health

# 4. 直接测试 FRP 隧道
curl http://your-server-ip:8080/api/health
```

### Q3: HTTPS 证书错误

**症状**: AWS SNS 无法验证 SSL 证书

**解决**:
```bash
# 1. 确保证书有效
openssl x509 -in /path/to/cert.pem -text -noout

# 2. 检查证书链是否完整
cat /path/to/fullchain.pem

# 3. 使用 Let's Encrypt 自动续期
sudo certbot renew --dry-run
```

### Q4: 本地后端无法访问外网

**症状**: 无法发送真实邮件

**解决**:
```bash
# 1. 检查网络连接
ping www.google.com

# 2. 检查 AWS 凭证
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# 3. 测试 AWS SES
aws ses send-email \
  --from noreply@yourdomain.com \
  --to test@example.com \
  --subject "Test" \
  --text "Test body"
```

### Q5: FRP 隧道断开

**症状**: 隧道不稳定，经常断开

**解决**:
```toml
# frpc.toml 添加心跳配置
heartbeatInterval = 30
heartbeatTimeout = 90

# 启用 TCP 多路复用
transport.tcpMux = true

# 使用 TCP 协议（更稳定）
transport.protocol = "tcp"
```

---

## 安全注意事项

⚠️ **重要安全提示**:

1. **Token 安全**: `auth.token` 必须使用强密码，定期更换
2. **访问控制**: 限制 FRP 端口只允许特定 IP 访问
3. **HTTPS 必需**: AWS SNS 回调必须使用 HTTPS
4. **测试环境**: 使用独立的 AWS 凭证和 SES 配置集
5. **及时关闭**: 测试完成后停止 FRP 客户端，避免长期暴露

---

## 参考配置示例

### 完整服务端配置

```toml
# /etc/frp/frps.toml
bindPort = 7000

dashboardPort = 7500
dashboardUser = admin
dashboardPwd = "YourStrongPassword123!"

auth.method = "token"
auth.token = "your-secure-token-change-this"

vhostHTTPPort = 8080
vhostHTTPSPort = 8443
subDomainHost = "frp.yourdomain.com"

log.to = "/var/log/frp/frps.log"
log.level = "info"
log.maxDays = 30
```

### 完整客户端配置

```toml
# frpc.toml
serverAddr = "your-server-ip"
serverPort = 7000

auth.method = "token"
auth.token = "your-secure-token-change-this"

# 心跳配置
heartbeatInterval = 30
heartbeatTimeout = 90

[[proxies]]
name = "dev-mailflow"
type = "http"
localIP = "127.0.0.1"
localPort = 8880
customDomains = ["dev.yourdomain.com"]

# 可选：TCP 隧道用于直接访问
[[proxies]]
name = "dev-mailflow-tcp"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8880
remotePort = 8880

log.to = "./frpc.log"
log.level = "debug"
```

---

完成以上配置后，您就可以在本地开发环境测试真实的 AWS SES/SNS 回调了！

如有问题，请检查：
1. FRP 服务端和客户端日志
2. Nginx 错误日志
3. AWS SNS 控制台中的订阅确认状态
4. 本地后端应用日志
