# Mail Flow - AWS SNS 配置指南

本文档详细说明如何配置 AWS SNS 以接收 SES 邮件事件（发送、送达、打开、点击、退信等），并将其转发到 Mail Flow 应用。

---

## 目录

1. [架构概览](#架构概览)
2. [前置条件](#前置条件)
3. [AWS 控制台配置](#aws-控制台配置)
4. [本地开发环境配置](#本地开发环境配置)
5. [生产环境配置](#生产环境配置)
6. [验证配置](#验证配置)
7. [故障排查](#故障排查)

---

## 架构概览

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│  SES Email  │────▶│  SES Events │────▶│  SNS Topic  │────▶│ Mail Flow App   │
│   Sending   │     │   Config    │     │             │     │ /webhooks/email │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────────┘
                                                              │
                                                              ▼
                                                        ┌─────────────────┐
                                                        │ WorkflowInstance│
                                                        │   Resume Logic  │
                                                        └─────────────────┘
```

---

## 前置条件

- AWS 账户（已验证域名）
- SES 已配置并可发送邮件
- Mail Flow 后端服务可公网访问（或已配置内网穿透）

---

## AWS 控制台配置

### 1. 创建 SNS Topic

1. 登录 AWS 控制台 → SNS → Topics → Create topic
2. 选择类型：**Standard**
3. 名称：`mailflow-ses-events`
4. 其他选项保持默认 → Create topic

### 2. 配置 SES 事件发布

1. 进入 SES → Configuration Sets
2. 如果没有 Configuration Set，创建一个（例如 `mailflow-config`）
3. 选择 Configuration Set → Event Destinations → Add destination
4. 选择 **Amazon SNS** → Next
5. 启用需要的事件类型：
   - ✅ Sends
   - ✅ Deliveries
   - ✅ Opens
   - ✅ Clicks
   - ✅ Bounces
   - ✅ Complaints
6. 选择之前创建的 SNS Topic → Next → Add destination

### 3. 配置 SNS Topic 订阅

1. 进入 SNS → Topics → 选择 `mailflow-ses-events`
2. Subscriptions → Create subscription
3. 协议选择：**HTTPS**
4. Endpoint 填写：`https://your-domain.com/api/webhooks/email`
   - **本地开发**: 使用 `ngrok` 等工具获取公网 URL
   - **生产环境**: 使用实际域名
5. 点击 Create subscription

### 4. 确认订阅

- AWS SNS 会向你的 endpoint 发送确认请求
- 确保应用运行并正确处理确认请求
- 在 SNS Console 中确认订阅状态变为 **Confirmed**

---

## 本地开发环境配置

### 使用 ngrok（推荐）

1. 安装 ngrok
```bash
# Windows
choco install ngrok

# macOS
brew install ngrok

# Linux
sudo snap install ngrok
```

2. 启动 ngrok 转发到本地 Flask 服务
```bash
# Flask 默认运行在 8880 端口
ngrok http 8880
```

3. 获取公网 URL
```
Forwarding: https://xxxxx.ngrok-free.app → http://localhost:8880
```

4. 更新 SNS Subscription Endpoint
```
https://xxxxx.ngrok-free.app/api/webhooks/email
```

**注意**: 每次重启 ngrok URL 会变化，需要重新配置 SNS。
可以使用 ngrok 的固定域名功能（付费）或使用 AWS Lambda 转发。

### 配置环境变量

```bash
# pythonBack/.env
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key_id
AWS_SECRET_ACCESS_KEY=your_secret
SES_SENDER_EMAIL=noreply@yourdomain.com
```

---

## 生产环境配置

### 使用自定义域名

1. 确保域名已备案（国内）或已验证（国际）
2. 配置 HTTPS 证书
3. 在 SNS 中使用完整 URL：
```
https://mailflow.yourdomain.com/api/webhooks/email
```

### 安全配置

#### 1. 验证 SNS 消息签名

生产环境**必须**验证 SNS 消息签名，防止伪造：

```python
# 在 routes/webhooks.py 中添加签名验证
import requests
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
import base64

def verify_sns_signature(message):
    """验证 SNS 消息签名"""
    # 获取签名证书
    cert_url = message.get('SigningCertURL')
    if not cert_url or 'sns.amazonaws.com' not in cert_url:
        return False

    cert_pem = requests.get(cert_url).text
    cert = x509.load_pem_x509_certificate(cert_pem.encode())

    # 构建待签名字符串
    sign_str = "\n".join([
        f"{key}\n{message[key]}"
        for key in ['Message', 'MessageId', 'Subject', 'Timestamp', 'TopicArn', 'Type']
        if key in message and message[key]
    ])

    # 验证签名
    signature = base64.b64decode(message['Signature'])
    try:
        cert.public_key().verify(
            signature,
            sign_str.encode(),
            padding.PKCS1v15(),
            hashes.SHA1()
        )
        return True
    except Exception:
        return False
```

#### 2. 使用 IAM 角色（推荐）

如果使用 AWS 服务（EC2/Lambda），使用 IAM Role 替代 Access Key：

```bash
# 不需要在代码中配置 AK/SK
# 只需配置区域
AWS_REGION=us-east-1
```

#### 3. Webhook URL 安全

- 使用 HTTPS（强制）
- 可添加自定义验证 Header
- 限制 IP 白名单（AWS SNS IP 段）

---

## 验证配置

### 测试邮件发送

1. 启动 Mail Flow 应用
2. 创建一个简单工作流（邮件节点 → 延时节点 → 邮件节点）
3. 执行工作流，发送到测试邮箱
4. 检查数据库确认：
   - EmailLog 记录已创建
   - WorkflowInstance 状态正确
   - message_id 已记录

### 检查 SNS 消息接收

查看应用日志：
```bash
# 应该看到类似的日志
[SNS] Received: {
  "eventType": "Delivery",
  "mail": {
    "messageId": "xxxxx",
    "destination": ["recipient@example.com"]
  }
}
```

### 检查事件匹配

```bash
# 查看事件是否关联到实例
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8880/api/webhooks/events
```

### 检查延时节点恢复

1. 等待延时时间到达
2. 检查调度器日志：
```
[Scheduler] Resuming delayed instance X
[Scheduler] Instance X execution completed
```

---

## 故障排查

### SNS 订阅未确认

**现象**: SNS Console 显示 "PendingConfirmation"

**解决**:
1. 确保应用运行并可公网访问
2. 检查应用日志是否有确认请求
3. 手动确认（如果自动确认失败）：
```bash
curl -X GET "https://sns-endpoint/confirm?token=XXX"
```

### 收不到 SES 事件

**排查步骤**:
1. 检查 SES Configuration Set 是否正确应用到邮件
2. 确认邮件发送时使用了 Configuration Set
3. 检查 SNS Topic 是否有消息
4. 检查 SNS Subscription 是否确认

### MessageId 不匹配

**现象**: 邮件事件无法触发工作流实例恢复

**解决**:
1. 检查 EmailLog.message_id 和 SES messageId 格式
2. 确认应用记录的是 SES 返回的 MessageId
3. 检查数据库中是否存在对应记录

### 延时任务未执行

**排查步骤**:
1. 检查 APScheduler 是否运行
2. 确认数据库连接正常
3. 检查调度器日志：
```python
# 在 app.py 中添加
from services.scheduler import get_scheduled_jobs
print(get_scheduled_jobs())
```

### 本地开发 ngrok 问题

**现象**: ngrok URL 过期，SNS 消息无法送达

**解决**:
1. 付费用户：使用固定域名
2. 免费用户：使用 AWS Lambda 转发

**Lambda 转发器示例**:
```python
import json
import urllib.request

def lambda_handler(event, context):
    # 转发到本地 ngrok
    local_url = "https://xxxxx.ngrok-free.app/api/webhooks/email"

    req = urllib.request.Request(
        local_url,
        data=event['body'].encode(),
        headers={'Content-Type': 'application/json'},
        method='POST'
    )

    try:
        response = urllib.request.urlopen(req)
        return {
            'statusCode': 200,
            'body': json.dumps({'status': 'forwarded'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

---

## 参考文档

- [AWS SES Developer Guide](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/)
- [AWS SNS Developer Guide](https://docs.aws.amazon.com/sns/latest/dg/)
- [ngrok Documentation](https://ngrok.com/docs)

---

**更新日期**: 2026-04-19
**版本**: v1.0
