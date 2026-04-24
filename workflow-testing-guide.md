# Mail Flow 工作流测试指南

本文档详细介绍如何测试工作流功能，包括基础邮件工作流和包含事件驱动节点的工作流。

---

## 目录

- [基础邮件工作流测试](#基础邮件工作流测试)
- [事件驱动工作流测试](#事件驱动工作流测试)
- [模拟事件触发测试](#模拟事件触发测试)
- [数据库验证](#数据库验证)
- [常见问题排查](#常见问题排查)

---

## 基础邮件工作流测试

### 前置条件

1. 后端服务已启动（端口 8880）
2. 前端服务已启动（端口 5175）
3. 数据库连接正常
4. 已配置至少一个邮件模板
5. 已配置至少一个联系人或群组

### 配置发送模式

编辑 `pythonBack/.env` 文件选择发送模式：

```bash
# 开发测试 - 模拟发送（推荐）
MOCK_EMAIL_SEND=true

# 生产验证 - 真实发送（需配置AWS SES）
MOCK_EMAIL_SEND=false
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
SES_SENDER_EMAIL=verified@yourdomain.com
```

### 测试步骤

#### 1. 创建并执行基础工作流

1. 登录前端，进入 **Workflow** 页面
2. 点击 **"Create New Workflow"** 创建工作流
3. 输入工作流名称，创建空白工作流
4. 点击 **"Add Node"** → **"发送邮件"**，配置：
   - 节点名称：如 "欢迎邮件"
   - 选择邮件模板
   - 选择收件人（联系人或群组）
5. 点击 **"Save Workflow"** 保存
6. 点击 **"Execute Workflow"** 执行

#### 2. 验证结果

**模拟模式验证：**

```bash
# 查看后端控制台输出
[MOCK] 模拟发送邮件:
 收件人: test@example.com
 主题: 测试邮件
 模拟MessageId: mock-a1b2c3d4e5f6
 状态: 模拟成功 (mock_send=True)
```

**数据库验证：**

```sql
-- 查看邮件日志
SELECT * FROM email_log ORDER BY created_at DESC LIMIT 5;

-- 预期结果：status='sent', message_id 以 'mock-' 开头（模拟模式）
```

---

## 事件驱动工作流测试

### 事件驱动节点介绍

事件驱动节点（橙色节点）可以配置三个步骤：

| 步骤 | 功能 | 配置项 |
|------|------|--------|
| **监听事件** | 等待特定的邮件事件 | event_type: send/delivery/open/click/bounce/complaint |
| **条件判断** | 对事件数据进行条件筛选 | field, operator, value |
| **延时** | 事件触发后延时执行 | delayType, delayValue/delayDateTime |

### 测试场景 1：邮件打开触发后续邮件

#### 工作流设计

```
[邮件节点 A: 发送首封邮件] → [事件驱动节点] → [邮件节点 B: 发送跟进邮件]
                              ↓
                        配置：监听 "open" 事件
```

#### 测试步骤

1. **创建工作流**
   - 创建新工作流
   - 添加第一个邮件节点（邮件A）
   - 添加事件驱动节点，配置：
     - 步骤1（监听事件）：启用，event_type = `open`
     - 步骤2（条件判断）：可选
     - 步骤3（延时）：可选
   - 连接事件驱动节点到第二个邮件节点（邮件B）
   - 保存工作流

2. **执行工作流**
   - 点击 **"Execute Workflow"**
   - 工作流执行到事件驱动节点后会暂停，状态变为 `waiting_event`
   - 记录第一个邮件节点的 `message_id`（从控制台或数据库获取）

3. **数据库验证暂停状态**

   ```sql
   -- 查看工作流实例状态
   SELECT id, status, current_node_id, waiting_event_type, 
          waiting_since, message_id, recipient_email
   FROM workflow_instance 
   ORDER BY created_at DESC LIMIT 1;
   
   -- 预期结果：status='waiting_event', waiting_event_type='open'
   ```

4. **模拟邮件打开事件**

   调用模拟事件 API：

   ```bash
   curl -X POST http://localhost:8880/api/webhooks/simulate/event \
     -H "Authorization: Bearer <your_jwt_token>" \
     -H "Content-Type: application/json" \
     -d '{
       "event_type": "open",
       "message_id": "mock-xxx",  
       "recipient_email": "test@example.com",
       "event_data": {
         "eventType": "open",
         "mail": {
           "messageId": "mock-xxx",
           "commonHeaders": {
             "to": ["test@example.com"]
           }
         }
       },
       "mock_send": true
     }'
   ```

   **参数说明：**
   - `message_id`: 必须与首封邮件的 message_id 匹配
   - `recipient_email`: 必须与收件人邮箱匹配
   - `mock_send`: true 表示后续邮件也使用模拟发送

5. **验证后续执行**

   ```sql
   -- 再次检查实例状态
   SELECT id, status, completed_at 
   FROM workflow_instance 
   WHERE id = <instance_id>;
   
   -- 预期结果：status='completed'
   
   -- 查看邮件日志，应有两条记录
   SELECT * FROM email_log WHERE instance_id = <instance_id>;
   ```

---

### 测试场景 2：带条件判断的事件驱动

#### 工作流设计

```
[邮件节点 A] → [事件驱动节点] → [邮件节点 B]
                  ↓
            配置：
            1. 监听 "click" 事件
            2. 条件：link_url contains "promo"
            3. 延时：2 hours
```

#### 测试步骤

1. **配置事件驱动节点**
   - 步骤1（监听事件）：启用，event_type = `click`
   - 步骤2（条件判断）：启用
     - field = `link_url`
     - operator = `contains`
     - value = `promo`
   - 步骤3（延时）：启用，relative = 2 hours

2. **执行并模拟事件**

   ```bash
   curl -X POST http://localhost:8880/api/webhooks/simulate/event \
     -H "Authorization: Bearer <your_jwt_token>" \
     -H "Content-Type: application/json" \
     -d '{
       "event_type": "click",
       "message_id": "mock-xxx",
       "recipient_email": "test@example.com",
       "event_data": {
         "eventType": "click",
         "click": {
           "link": "https://example.com/promo/sale"
         },
         "mail": {
           "messageId": "mock-xxx",
           "commonHeaders": {
             "to": ["test@example.com"]
           }
         }
       },
       "mock_send": true
     }'
   ```

3. **验证条件判断**

   - 如果 `link_url` 包含 `promo` → 条件通过 → 创建延时任务
   - 如果不包含 → 条件失败 → 实例结束

   ```sql
   -- 查看延时任务
   SELECT * FROM scheduled_jobs; -- 或通过 API: GET /api/webhooks/scheduled
   ```

---

## 模拟事件触发测试

### 使用 API 直接触发

#### 1. 模拟发送事件 (Send)

```bash
curl -X POST http://localhost:8880/api/webhooks/simulate/event \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "send",
    "message_id": "mock-xxx",
    "recipient_email": "test@example.com",
    "event_data": {},
    "mock_send": true
  }'
```

#### 2. 模拟送达事件 (Delivery)

```bash
curl -X POST http://localhost:8880/api/webhooks/simulate/event \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "delivery",
    "message_id": "mock-xxx",
    "recipient_email": "test@example.com",
    "event_data": {},
    "mock_send": true
  }'
```

#### 3. 模拟点击事件 (Click)

```bash
curl -X POST http://localhost:8880/api/webhooks/simulate/event \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "click",
    "message_id": "mock-xxx",
    "recipient_email": "test@example.com",
    "event_data": {
      "click": {
        "link": "https://example.com/special-offer"
      }
    },
    "mock_send": true
  }'
```

### 支持的模拟事件类型

| 事件类型 | 说明 | 触发条件 |
|----------|------|----------|
| `send` | 邮件已发送 | SES 调用成功 |
| `delivery` | 邮件已送达收件服务器 | 收件服务器接受邮件 |
| `open` | 收件人打开邮件 | 邮件客户端加载追踪像素 |
| `click` | 收件人点击链接 | 点击带追踪的链接 |
| `bounce` | 邮件被退回 | 收件地址无效或拒收 |
| `complaint` | 收件人标记为垃圾邮件 | 点击"标记为垃圾邮件" |
| `deliveryDelay` | 投递延迟 | 收件服务器暂时不可用 |
| `reject` | SES 拒绝发送 | 内容被 SES 过滤器拦截 |

---

## 数据库验证

### 关键表说明

```sql
-- 1. 工作流实例状态追踪
SELECT 
    wi.id,
    wi.workflow_id,
    wi.status,           -- running/waiting_event/delayed/completed/failed
    wi.current_node_id,
    wi.waiting_event_type,
    wi.waiting_since,
    wi.message_id,
    wi.recipient_email,
    wi.created_at,
    wi.completed_at
FROM workflow_instance wi
ORDER BY wi.created_at DESC;

-- 2. 节点执行记录
SELECT 
    ne.id,
    ne.instance_id,
    ne.node_id,
    ne.node_type,        -- email/driver/delay/condition
    ne.node_label,
    ne.result,           -- running/success/failed
    ne.executed_at,
    ne.completed_at
FROM node_execution ne
ORDER BY ne.executed_at DESC;

-- 3. 邮件发送日志
SELECT 
    el.id,
    el.instance_id,
    el.node_id,
    el.recipient_email,
    el.subject,
    el.message_id,
    el.status,           -- sent/failed
    el.created_at
FROM email_log el
ORDER BY el.created_at DESC;

-- 4. 邮件事件记录
SELECT 
    ee.id,
    ee.message_id,
    ee.event_type,
    ee.recipient_email,
    ee.occurred_at,
    ee.created_at
FROM email_event ee
ORDER BY ee.created_at DESC;

-- 5. 延时任务（通过 APScheduler）
-- 访问 API: GET /api/webhooks/scheduled
```

### 完整执行流程验证示例

```sql
-- 查找最近执行的实例
SET @instance_id = (SELECT id FROM workflow_instance ORDER BY created_at DESC LIMIT 1);

-- 查看实例完整生命周期
SELECT 'Instance' as type, id, status, created_at, completed_at, waiting_event_type
FROM workflow_instance WHERE id = @instance_id
UNION ALL
SELECT 'Node Execution' as type, 
       CONCAT(ne.node_id, ' - ', ne.node_label) as id,
       ne.result as status,
       ne.executed_at as created_at,
       ne.completed_at,
       ne.node_type
FROM node_execution ne WHERE ne.instance_id = @instance_id
UNION ALL
SELECT 'Email Log' as type,
       el.recipient_email as id,
       el.status,
       el.created_at,
       NULL,
       el.subject
FROM email_log el WHERE el.instance_id = @instance_id
ORDER BY created_at;
```

---

## 常见问题排查

### 问题 1：执行工作流后实例卡在 waiting_event 状态

**现象：**
- 实例状态显示 `waiting_event`
- 后续节点未执行

**排查：**

1. 检查实例是否正确记录了 `message_id`：
   ```sql
   SELECT message_id, recipient_email, waiting_event_type 
   FROM workflow_instance WHERE id = <instance_id>;
   ```

2. 模拟事件时确保参数匹配：
   - `message_id` 必须完全一致
   - `recipient_email` 必须完全一致
   - `event_type` 必须匹配 `waiting_event_type`

3. 查看后端控制台是否有错误日志

### 问题 2：事件触发后条件判断不通过

**现象：**
- 事件被接收但后续未执行
- 实例直接标记为 completed

**排查：**

1. 检查条件配置：
   ```sql
   -- 从工作流定义中查看条件
   SELECT flow_data FROM workflow WHERE id = <workflow_id>;
   ```

2. 确认事件数据格式正确，特别是：
   - `click.link` 对于点击事件
   - `mail.commonHeaders.to` 对于收件人匹配

### 问题 3：延时任务未创建

**现象：**
- 事件通过但后续邮件立即发送
- 没有看到延时调度

**排查：**

1. 确认延时步骤已启用
2. 检查调度器服务是否运行（APScheduler）
3. 查看调度任务列表：
   ```bash
   curl -H "Authorization: Bearer <token>" \
     http://localhost:8880/api/webhooks/scheduled
   ```

### 问题 4：JWT Token 过期

**现象：**
- API 返回 401 错误

**解决：**
- 重新登录获取新 Token
- 或使用刷新 Token API 更新 Access Token

---

## 附录：测试清单

### 基础功能测试

- [ ] 创建工作流
- [ ] 添加邮件节点
- [ ] 添加事件驱动节点
- [ ] 节点间建立连接
- [ ] 保存工作流
- [ ] 执行工作流（模拟模式）
- [ ] 验证邮件日志

### 事件驱动测试

- [ ] 执行含事件驱动节点的工作流
- [ ] 验证实例暂停在 waiting_event 状态
- [ ] 模拟 send 事件触发
- [ ] 模拟 open 事件触发
- [ ] 模拟 click 事件触发（带 URL 匹配）
- [ ] 验证条件判断逻辑
- [ ] 验证延时任务创建
- [ ] 验证后续邮件发送

### 边界条件测试

- [ ] 事件类型不匹配（应忽略）
- [ ] 条件判断失败（应结束实例）
- [ ] 多个收件人的工作流实例
- [ ] 并行分支工作流
- [ ] 循环连接检测

---

*文档版本: 1.0*
*最后更新: 2026-04-20*
