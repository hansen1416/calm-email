# Mail Flow 文档中心

欢迎使用 Mail Flow 文档中心！这里包含了部署、配置、开发等所有相关文档。

## 📚 文档目录

### 1. 部署文档

| 文档 | 说明 | 适用场景 |
|------|------|----------|
| [deployment-guide.md](./deployment-guide.md) | 完整的生产环境部署指南 | 在服务器上部署生产环境 |
| [frp-tunnel-guide.md](./frp-tunnel-guide.md) | FRP 内网穿透配置，本地测试 AWS 回调 | 本地开发 + 真实 AWS 服务测试 |

### 2. 测试文档

| 文档 | 说明 | 适用场景 |
|------|------|----------|
| [workflow-testing-guide.md](./workflow-testing-guide.md) | 工作流功能测试指南，含事件驱动节点测试 | 测试邮件工作流和事件驱动功能 |

### 3. 配置模板

#### 后端配置 (`backend-config/`)

| 文件 | 说明 |
|------|------|
| [`.env.example`](./backend-config/.env.example) | 环境变量配置模板 |
| [`gunicorn.conf.py`](./backend-config/gunicorn.conf.py) | Gunicorn 配置文件 |
| [`mailflow.service`](./backend-config/mailflow.service) | Systemd 服务文件 |
| [`start.sh`](./backend-config/start.sh) | 后端启动脚本 |

#### Nginx 配置 (`nginx-config/`)

| 文件 | 说明 |
|------|------|
| [`mailflow.conf`](./nginx-config/mailflow.conf) | Nginx 站点配置（生产环境 + 开发环境子域名） |

### 4. 自动化脚本 (`scripts/`)

| 脚本 | 说明 | 适用平台 |
|------|------|----------|
| [`deploy.sh`](./scripts/deploy.sh) | 一键部署脚本（安装依赖、配置服务） | Ubuntu 22.04 |
| [`start-dev.bat`](./scripts/start-dev.bat) | Windows 开发环境启动脚本 | Windows |

## 🚀 快速开始

### 场景 1：生产环境部署

按照顺序执行以下步骤：

1. **AWS 配置**
   - SES：验证域名、申请生产权限、创建配置集
   - SNS：创建 Topic、订阅 HTTPS 回调
   - IAM：创建用户、获取凭证

2. **服务器配置**
   - 运行部署脚本：`sudo bash docs/scripts/deploy.sh yourdomain.com`
   - 或手动按照 [deployment-guide.md](./deployment-guide.md) 操作

3. **配置验证**
   - 访问 `https://yourdomain.com/api/health`
   - 测试邮件发送
   - 验证 SNS 回调

### 场景 2：本地开发 + 真实 AWS 测试

1. **服务器端**
   - 安装 FRP 服务端
   - 配置 Nginx 子域名
   - 使用文档：[frp-tunnel-guide.md](./frp-tunnel-guide.md)

2. **本地开发机**
   - 安装 FRP 客户端
   - 配置 frpc.toml
   - 运行 `docs/scripts/start-dev.bat` 启动服务

3. **AWS 配置**
   - SNS 订阅端点改为 `https://dev.yourdomain.com/api/webhooks/sns`

## 📖 阅读指南

### 生产部署流程

```
1. 阅读 deployment-guide.md 第 1-2 节（AWS 配置）
   ↓
2. 阅读 deployment-guide.md 第 3-4 节（服务器配置、应用部署）
   ↓
3. 参考 backend-config/ 和 nginx-config/ 配置文件
   ↓
4. 执行部署或运行 deploy.sh 脚本
   ↓
5. 阅读 deployment-guide.md 第 5 节（功能验证）
```

### 本地开发流程

```
1. 阅读 frp-tunnel-guide.md 全文
   ↓
2. 配置服务器 FRP 服务端
   ↓
3. 配置本地 FRP 客户端
   ↓
4. 运行 start-dev.bat 启动开发环境
   ↓
5. 配置 AWS SNS 使用开发域名
```

## ⚠️ 重要提示

### 安全事项

- **密钥安全**: 所有 `SECRET_KEY` 和 `JWT_SECRET_KEY` 必须使用随机生成的强密码
- **AWS 凭证**: 使用 IAM 用户，遵循最小权限原则
- **HTTPS 必需**: 生产环境必须使用 HTTPS，SNS 回调不支持 HTTP
- **及时关闭**: FRP 内网穿透测试完成后应及时关闭

### 环境变量

生产环境必须配置的变量：

```bash
SECRET_KEY=                 # 随机 256-bit 密钥
JWT_SECRET_KEY=             # 随机 JWT 密钥
DATABASE_URI=               # 生产数据库连接
AWS_ACCESS_KEY_ID=           # AWS IAM Access Key
AWS_SECRET_ACCESS_KEY=       # AWS IAM Secret Key
SES_SENDER_EMAIL=            # 验证过的发件邮箱
MOCK_EMAIL_SEND=false        # 生产模式关闭模拟发送
CORS_ORIGINS=                # 限制为生产域名
```

## 🔧 常用命令速查

### 后端管理

```bash
# 启动服务
sudo systemctl start mailflow

# 查看状态
sudo systemctl status mailflow

# 查看日志
sudo tail -f /var/log/mailflow/error.log

# 重启服务
sudo systemctl restart mailflow

# 重载配置
sudo systemctl reload mailflow
```

### Nginx 管理

```bash
# 测试配置
sudo nginx -t

# 重载配置
sudo systemctl reload nginx

# 查看日志
sudo tail -f /var/log/nginx/mailflow.error.log
```

### 数据库

```bash
# 备份
mysqldump -u mailflow -p contact_mail_prod > backup_$(date +%Y%m%d).sql

# 恢复
mysql -u mailflow -p contact_mail_prod < backup_20260419.sql
```

### 健康检查

```bash
# 基础检查
curl https://yourdomain.com/api/health

# 就绪检查（含数据库）
curl https://yourdomain.com/api/health/ready

# 系统指标
curl https://yourdomain.com/api/health/metrics
```

## 🆘 故障排查

遇到问题请先查看：

1. **应用日志**: `/var/log/mailflow/error.log`
2. **Nginx 日志**: `/var/log/nginx/mailflow.error.log`
3. **系统日志**: `sudo journalctl -u mailflow -f`
4. **AWS CloudWatch**: SES 和 SNS 的服务日志

详细排查步骤请参考各文档的「常见问题」章节。

## 📞 文档维护

- 文档版本：v1.0.0
- 最后更新：2026-04-19
- 适用版本：Mail Flow v1.1.0-beta

---

**提示**: 本文档为离线版本，如需查看完整说明，请打开对应的 `.md` 文件。
