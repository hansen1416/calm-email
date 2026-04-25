# Changelog

## [待实施] 用户邮箱白名单与系统域名迁移方案 📋

**日期**: 2026-04-25
**版本**: v2.0.0 (计划)
**状态**: 待开始 ⏳
**提交点**: e6c85d4 (实施前版本)

---

### 需求概述

实现用户绑定自己的邮箱作为发件箱，支持前期验证个人邮箱、后期迁移到系统域名的双模式架构。

### 核心设计

```
┌─────────────────────────────────────────────────────────┐
│ 配置开关: EMAIL_SENDER_MODE                              │
│ 值: 'personal'(前期) | 'system'(后期)                     │
└─────────────────────────────────────────────────────────┘
│
┌───────────────┴───────────────┐
▼                               ▼
┌─────────────────┐         ┌─────────────────┐
│  personal 模式  │         │   system 模式   │
│ 用户验证自己邮箱 │         │ 系统分配子邮箱  │
└────────┬────────┘         └────────┬────────┘
│                                      │
▼                                      ▼
user@gmail.com              user001@mail.yourdomain.com
占用 SES 验证额度            不占用额度(子邮箱)
```

### 数据模型（无外键约束）

| 表名 | 用途 | 关键字段 |
|------|------|---------|
| `email_quota_config` | 配额配置模板 | id, name, daily_limit, price_monthly |
| `user_sender_binding` | 用户发件绑定 | user_id, email, email_type, verification_token |
| `user_subscription` | 用户订阅(预留) | user_id, quota_config_id, payment_provider |
| `notification` | 系统通知 | user_id, type, title, content |

### .env 配置预留

```ini
# 邮件发送模式
EMAIL_SENDER_MODE=personal
SYSTEM_DOMAIN=
SYSTEM_SENDER_PREFIX=user
DEFAULT_DAILY_QUOTA=100
QUOTA_RESET_HOUR=0

# 升级功能开关(预留)
UPGRADE_FEATURE_ENABLED=false

# 多支付服务商(并列关系，用户可选)
PAYMENT_ALIPAY_ENABLED=false
PAYMENT_WECHAT_ENABLED=false
PAYMENT_STRIPE_ENABLED=false

# 自动迁移
MIGRATION_USER_THRESHOLD=8000
```

### 实施里程碑

| 阶段 | 任务 | 状态 | 实际时间 |
|------|------|------|---------|
| M1 | 数据模型(QuotaConfig, SenderBinding, Subscription, Notification) | ✅ 已完成(2026-04-25) | 20min |
| M2 | API: 邮箱绑定/验证/解绑/列表 | ✅ 已完成(2026-04-25) | 35min |
| M3 | API: 配额查询与检查 | ✅ 已完成(2026-04-25) | (含M2内) |
| M4 | 改造发送逻辑(双模式) | ✅ 已完成(2026-04-25) | 30min |
| M5 | 回复转发+通知系统 | ✅ 已完成(2026-04-25) | 25min |
| M6 | 前端: 邮箱管理页面 | ✅ 已完成(2026-04-25) | 45min |
| M7 | 前端: 发送时选择发件人 | ✅ 已完成(2026-04-25) | 20min |
| M8 | 预留支付接口(后端) | ✅ 已完成(2026-04-25) | 25min |
| M9 | 迁移脚本 | ✅ 已完成(2026-04-25) | 30min |
| M10 | 测试+文档+数据库更新 | ✅ 已完成(2026-04-25) | 20min |

### 关键设计约束

1. **无外键约束**: 所有表关联通过代码逻辑实现
2. **双模式共存**: personal/system 模式代码共存，配置切换
3. **多支付方式**: 并列关系，用户支付时可选择
4. **迁移触发**: 8000用户时通知管理员，手动执行迁移
5. **回复处理**: 转发到用户真实邮箱 + 系统内通知

### 兼容性

- 不破坏现有工作流、邮件发送逻辑
- 向后兼容：现有 EmailLog 等数据无需修改
- 平滑迁移：切换模式时保留历史绑定记录

---

## [归档] 历史版本变更记录

<details>
<summary>点击展开历史归档记录</summary>

### [2026-04-19] - 工作流添加节点首个节点限制修复
**状态**: 已实现 ✅

#### Bug 修复
- **问题**: 添加第一个节点时仍要求必须选中锚点
- **原因**: `handleAddNode` 函数对所有节点都进行锚点检查，没有区分是否是第一个节点
- **修复**: 添加节点前先检查画布中是否已有节点
  - 如果是第一个节点（画布为空）：不需要选中锚点
  - 如果已有节点：需要选中锚点才能添加新节点
- **影响文件**: `vue3Model/src/views/Workflow.vue`

---

### [2026-04-19] - SNS 订阅确认自动处理
**状态**: 已实现 ✅

#### Bug 修复
- **问题**: SNS 订阅确认消息未真正确认，导致订阅处于 Pending 状态
- **原因**: 收到 `SubscriptionConfirmation` 消息后，必须访问 `SubscribeURL` 才能真正确认订阅
- **修复**: 自动访问 `SubscribeURL` 完成订阅确认
- **实现**: 
  - 接收 `SubscriptionConfirmation` 消息后，提取 `SubscribeURL`
  - 使用 `requests.get()` 访问确认 URL
  - 返回确认结果和状态
- **影响端点**: `POST /api/webhooks/sns`
- **参考文档**: 
  - https://docs.aws.amazon.com/sns/latest/dg/http-subscription-confirmation-json.html
  - https://docs.aws.amazon.com/sns/latest/api/API_ConfirmSubscription.html

---

### [2026-04-19] - SNS Webhook Content-Type 修复
**状态**: 已实现 ✅

#### Bug 修复
- **问题**: AWS SNS 发送的请求 Content-Type 为 `text/plain`，导致 Flask `request.get_json()` 返回 400 错误
- **原因**: SNS HTTP(S) 通知的 Content-Type 是 `text/plain; charset=UTF-8`，而内容是 JSON 字符串
- **修复**: 使用 `request.get_json(force=True)` 强制解析 JSON，忽略 Content-Type 检查
- **影响端点**: `POST /api/webhooks/sns`
- **参考文档**: https://docs.aws.amazon.com/sns/latest/dg/http-subscription-confirmation-json.html

---

### [2026-04-19] - 生产环境准备改进
**状态**: 已实现 ✅

#### 健康检查接口
- 新增 `/health` - 基础健康检查
- 新增 `/health/ready` - 数据库连接检查（K8s readiness probe）
- 新增 `/health/live` - 存活检查（K8s liveness probe）
- 新增 `/health/metrics` - 系统指标（内存、CPU、磁盘、数据库状态）
- 新增 `/health/version` - 版本信息

#### 数据库索引优化
- Contact: user_id, email 索引
- WorkflowInstance: workflow_id, user_id, status, message_id, created_at 索引
- EmailLog: user_id, instance_id, message_id, sent_at 索引
- EmailEvent: message_id, event_type, created_at 索引
- NodeExecution: instance_id, node_id, result, executed_at 索引

#### 结构化日志
- 使用 Python logging 替代 print
- 支持控制台和文件输出（app.log）
- 请求/响应自动日志记录
- 各模块日志级别配置

#### JWT Token 刷新机制
- 后端 `/auth/refresh` 端点
- 后端 `/auth/logout` 端点
- 刷新令牌 30 天有效期
- 前端自动刷新访问令牌
- Token 失效自动跳转登录

#### 全局异常处理
- 统一错误响应格式：`{success, code, message}`
- 支持 400/401/403/404/405/429/500 错误码
- 自动记录异常堆栈

#### CORS 配置改进
- 支持 CORS_ORIGINS 环境变量
- 生产环境可限制特定域名

---

### [2026-04-19] - Workflow.vue Bug Fixes
**状态**: 已实现 ✅

修复工作流节点编辑的三个关键 bug：
- 事件驱动节点编辑修改无法持久保存
- 双击节点编辑时节点名称为空
- 编辑节点 A 后再编辑节点 B 时信息串扰

### [2026-04-08] - i18n Template Binding Fix
**状态**: 已实现 ✅

修复 i18n 模板绑定问题，所有视图文件正确暴露 `$t` 函数。

### [2026-04-08] - Internationalization & Workflow Improvements
**状态**: 已实现 ✅

- 添加国际化支持 (i18n)
- Workflow 节点优化（禁止拖动、自动计算位置）

</details>

---

## [已完成] 工作流实例化架构设计与实现 ✅

### 核心设计概念

#### 每封邮件 = 一个工作流执行实例

**执行流程**:
```
工作流定义 (Workflow)
↓
用户触发执行（手动/定时）
↓
创建多个 WorkflowInstance（每个收件人一个实例）
├─ Instance A → 发送给联系人A → 遇到driver节点暂停 → 等待事件 → 继续执行
├─ Instance B → 发送给联系人B → 遇到driver节点暂停 → 等待事件 → 继续执行
└─ Instance C → 发送给群组C成员 → 批量创建实例 → 各自独立执行
```

#### 触发方式

| 触发类型 | 说明 | 前端配置 |
|---------|------|---------|
| **手动触发** | 用户点击"执行工作流"按钮 | `execution_mode=manual` |
| **定时触发** | 到达指定时间自动执行 | `execution_mode=auto` + `start_time` |

#### Driver 节点 = 等待事件机制

**Driver 节点功能**:
- **不是**发送邮件的节点
- **是**流程暂停等待外部事件的节点
- 配置监听规则（event_type、条件判断、延时）
- 工作流执行到 driver 节点时：
  1. 保存当前实例状态为 `waiting_event`
  2. 记录等待的事件类型（click/open/delivery 等）
  3. 返回，暂停执行
  4. 等待 SNS 事件到达后恢复

#### 节点类型职责

| 节点类型 | 职责 |
|---------|------|
| **email** | 发送邮件，配置模板和收件人 |
| **driver** | 暂停等待 SNS 事件，配置匹配规则 |
| **delay** | 延时执行（相对/绝对时间） |
| **condition** | 条件判断（字段、操作符、值） |

---

## [待办] 工作流实例化实现任务

### 任务 1: WorkflowInstance 数据模型 [已完成]
**说明**: 创建新的数据表记录每个工作流执行实例

**已实现**:
- [x] 新增 `WorkflowInstance` 模型
  - `id`: 实例ID
  - `workflow_id`: 关联的工作流定义
  - `user_id`: 所属用户
  - `source_email_log_id`: 初始邮件日志ID
  - `message_id`: SES Message ID（用于事件匹配）
  - `recipient_email`: 收件人邮箱
  - `status`: pending/running/waiting_event/delayed/completed/failed
  - `current_node_id`: 当前执行到的节点ID
  - `waiting_event_type`: 等待的事件类型
  - `waiting_conditions`: JSON格式的等待条件
  - `context`: 执行上下文数据
  - `created_at/updated_at/completed_at`: 时间戳
- [x] 修改 `EmailLog` 关联到 `WorkflowInstance`
- [x] 数据库迁移脚本（update_schema.sql）

**关联文件**:
- `pythonBack/models.py`

---

### 任务 2: 工作流执行引擎改造 [已完成]
**说明**: 改造执行逻辑，支持为每个收件人创建独立实例

**已实现**:
- [x] 改造 `POST /api/workflow/<id>/execute`
- 解析 email 节点的联系人/群组
- 为**每个收件人**创建独立的 `WorkflowInstance`
- 逐个执行实例到第一个 driver 节点前
- 返回所有创建的实例ID列表
- [x] 实现 driver 节点暂停逻辑
- 发送邮件后记录 message_id
- 更新实例状态为 `waiting_event`
- 记录等待的事件类型和条件
- 暂停执行并返回
- [x] 实现延时节点处理
- 相对延时：计算触发时间 → 创建 APScheduler 任务 → 更新状态为 `delayed`
- 绝对延时：同上
- [x] 实例执行恢复机制
- 从暂停节点继续执行后续节点

**关联文件**:
- `pythonBack/routes/workflow.py`
- `pythonBack/services/scheduler.py`

---

### 任务 3: SNS 事件匹配与实例恢复 [已完成]
**说明**: 通过 message_id 匹配到正确的实例并恢复执行

**已实现**:
- [x] 改造 `POST /api/webhooks/sns` 和 `/simulate/event`
- 通过 `message_id` 查找 `WorkflowInstance`
- 验证事件类型是否匹配 `waiting_event_type`
- 验证条件是否满足（`evaluate_condition`）
- 恢复实例执行（调用后续节点）
- 更新实例状态为 `running` 或 `completed`
- [x] 延时任务恢复
- APScheduler 任务触发时找到对应实例
- 恢复执行并更新状态

**关联文件**:
- `pythonBack/routes/webhooks.py`
- `pythonBack/services/scheduler.py`

---

### 任务 4: 定时触发支持 [已完成]
**说明**: 支持按 `execution_mode` 和 `start_time` 自动执行工作流

**已实现**:
- [x] APScheduler 定时任务调度
- 工作流保存时检查 `execution_mode` 和 `start_time`
- 创建定时执行 Job
- 到达时间后自动触发执行
- [x] 取消定时任务
- 工作流删除或修改时取消已创建的 Job
- [x] 定时执行状态记录

**关联文件**:
- `pythonBack/routes/workflow.py`（保存/更新时处理）
- `pythonBack/services/scheduler.py`

---

### 任务 5: 工作流实例管理 API [已完成]
**说明**: 提供 API 查询和管理工作流执行实例

**已实现**:
- [x] `GET /api/workflow/<id>/instances`
- 获取该工作流的所有实例列表
- 支持按状态过滤
- [x] `GET /api/workflow/instance/<id>`
- 获取单个实例详情
- 包含当前状态、等待条件、执行历史
- [x] `GET /api/workflow/instance/<id>/logs`
- 获取实例的执行日志（关联 EmailLog）
- [x] `POST /api/workflow/instance/<id>/cancel`
- 取消等待中的实例
- [x] `GET /api/user/instances`
- 获取当前用户所有工作流实例（汇总视图）

**关联文件**:
- `pythonBack/routes/workflow.py`（新增/扩展）

---

### 任务 6: 延时任务持久化 [已完成]
**说明**: APScheduler 默认内存存储，重启后任务丢失

**已实现**:
- [x] 配置 APScheduler 使用 SQLAlchemyJobStore
- [x] 数据库表存储定时任务
- [x] 服务重启时恢复未执行的延时任务
- [x] 关联延时任务到 WorkflowInstance

**关联文件**:
- `pythonBack/app.py`（APScheduler 初始化）
- `pythonBack/services/scheduler.py`

---

### 任务 7: 前端实例展示页面 [已完成]
**说明**: 前端页面展示工作流执行实例

**已实现**:
- [x] 工作流实例列表页
- 显示该工作流下的所有邮件实例
- 列：收件人 | 当前节点 | 状态 | 等待事件 | 创建时间
- [x] 实例详情弹窗
- 显示执行轨迹（节点执行历史）
- 关联的事件记录
- 状态变更时间线
- [x] Events 页面增强
- 关联显示工作流实例状态
- 点击 message_id 跳转到实例详情

**关联文件**:
- `vue3Model/src/views/Workflow.vue`
- `vue3Model/src/views/Events.vue`

---

### 任务 8: SNS 回调配置文档 [中优先级]
**说明**: 详细说明 AWS SES/SNS 配置流程

**需要补充**:
- [ ] SES 配置集创建和事件发布配置
- [ ] SNS Topic 创建和订阅
- [ ] Webhook URL 配置（生产环境）
- [ ] 本地测试方案（ngrok 隧道）
- [ ] 订阅确认处理说明
- [ ] 签名验证（可选，生产环境推荐）

**关联文件**:
- `iteminfo.md`（更新 AWS 配置章节）

---

### 任务 9: 生产环境安全检查 [高优先级]
**说明**: 部署前的安全配置

**必须完成**:
- [ ] AWS 凭证移到环境变量（当前硬编码在 config.py）
- [ ] `SECRET_KEY` 和 `JWT_SECRET_KEY` 改为随机强密码
- [ ] 敏感信息脱敏（日志中不打印完整密钥）
- [ ] 数据库连接 SSL/TLS 配置

**关联文件**:
- `pythonBack/config.py`

---

### 任务 10: 测试用例与文档 [中优先级]
**说明**: 完整的测试指南

**需要补充**:
- [ ] 手动执行工作流测试步骤
- [ ] 定时触发测试步骤
- [ ] 模拟事件触发测试 curl 示例
- [ ] 真实 AWS SES/SNS 测试步骤
- [ ] 常见问题排查指南

**关联文件**:
- `iteminfo.md`

---

---

## 待完善事项清单

### 1. 触发器管理 API [高优先级]
**说明**: 前端可能已实现触发器管理界面，后端需要对应的 CRUD API

**需要实现**:
- [ ] `GET /api/webhooks/triggers` - 获取触发器列表
- [ ] `POST /api/webhooks/triggers` - 创建触发器
- [ ] `PUT /api/webhooks/triggers/<id>` - 更新触发器
- [ ] `DELETE /api/webhooks/triggers/<id>` - 删除触发器
- [ ] 触发器与工作流关联的数据库表设计

**关联文件**:
- `pythonBack/routes/webhooks.py`
- `pythonBack/models.py`

---

### 2. SNS 回调配置文档 [高优先级]
**说明**: 需要详细说明如何在 AWS 控制台配置 SNS → SES → Webhook 的完整流程

**需要补充**:
- [ ] SES 配置集创建步骤
- [ ] SNS Topic 创建和订阅配置
- [ ] Webhook URL 配置（支持本地测试隧道）
- [ ] 订阅确认处理说明
- [ ] 签名验证实现（可选，生产环境推荐）

**关联文件**:
- `pythonBack/routes/webhooks.py` (第 12-77 行)

---

### 3. 工作流状态持久化验证 [中优先级]
**说明**: 验证工作流执行状态和节点执行状态的持久化

**需要检查**:
- [ ] `EmailLog` 是否正确记录 `workflow_id` 和 `node_id`
- [ ] `Workflow.last_executed_at` 是否正确更新
- [ ] 工作流执行历史查询接口
- [ ] 节点执行状态追踪

**关联文件**:
- `pythonBack/routes/workflow.py` (第 100-279 行)
- `pythonBack/models.py` (EmailLog, Workflow)

---

### 4. 延时任务持久化 [中优先级]
**说明**: APScheduler 默认使用内存存储，重启后任务丢失

**需要实现**:
- [ ] 配置 APScheduler 使用数据库存储（SQLAlchemyJobStore）
- [ ] 任务重启时恢复未执行的延时任务
- [ ] 任务执行状态回调更新

**关联文件**:
- `pythonBack/services/scheduler.py`
- `pythonBack/app.py` (APScheduler 初始化)

---

### 5. 配置管理接口 [中优先级]
**说明**: 提供 API 查看和修改运行时配置

**需要实现**:
- [ ] `GET /api/config` - 获取当前配置（脱敏）
- [ ] `POST /api/config/mock` - 切换模拟/真实模式
- [ ] 配置热更新（无需重启服务）
- [ ] 前端配置面板（可选）

**关联文件**:
- `pythonBack/config.py`
- `pythonBack/routes/` (新增 config.py)

---

### 6. 邮件事件查询优化 [低优先级]
**说明**: 当前事件查询仅支持基础过滤

**需要增强**:
- [ ] 按时间范围查询
- [ ] 按工作流 ID 查询关联事件
- [ ] 事件统计 API（发送成功率等）
- [ ] 导出事件数据

**关联文件**:
- `pythonBack/routes/webhooks.py` (第 431-470 行)

---

### 7. 测试用例与文档 [中优先级]
**说明**: 完善测试指南和示例

**需要补充**:
- [ ] 完整的工作流测试场景（手动执行 + 事件触发）
- [ ] 模拟事件 curl 示例合集
- [ ] SNS 回调测试方法（使用 ngrok 等工具）
- [ ] AWS SES 发送测试步骤
- [ ] 常见问题排查指南

**关联文件**:
- `iteminfo.md` (更新测试章节)
- 新增 `docs/` 目录存放详细文档

---

### 8. 生产环境检查清单 [高优先级]
**说明**: 部署到生产环境前的必要检查

**必须完成**:
- [ ] AWS 凭证改为环境变量（不要在代码中硬编码）
- [ ] `SECRET_KEY` 和 `JWT_SECRET_KEY` 修改为随机强密码
- [ ] 数据库连接使用 SSL/TLS
- [ ] SNS 回调签名验证启用
- [ ] 日志级别调整为 INFO 或 WARN
- [ ] 敏感信息脱敏（日志中不打印 AWS Secret Key）

**当前代码中的敏感信息**:
```python
# pythonBack/config.py 第 17-18 行
KEY_ID = ''  # 必须移到环境变量
ACCESS_KEY = ''  # 安全风险
```

---

## 已验证功能

### ✅ 邮件发送功能
- [x] 模拟发送模式 (`MOCK_EMAIL_SEND=true`)
- [x] AWS SES 真实发送
- [x] 发送日志记录
- [x] 支持联系人和用户组发送

**测试接口**:
```bash
# 模拟发送
POST /api/email/send
{"template_id": 1, "contact_ids": [1], "mock": true}

# 获取当前模式
GET /api/email/settings
```

### ✅ SNS 事件模拟
- [x] 支持所有 SES 事件类型
- [x] 支持触发工作流执行
- [x] 支持 mock_send 参数

**测试接口**:
```bash
POST /api/webhooks/simulate/event
{
  "event_type": "click",
  "message_id": "test-msg-123",
  "recipient_email": "user@example.com",
  "event_data": {"click": {"link": "https://example.com"}},
  "mock_send": true
}
```

### ✅ 工作流执行
- [x] 手动执行工作流
- [x] 事件触发执行
- [x] 支持 email/driver/delay/condition/event 节点类型
- [x] 延时调度（相对/绝对时间）

### ✅ 延时任务调度
- [x] APScheduler 集成
- [x] 相对延时（分钟/小时/天）
- [x] 绝对延时（指定日期时间）
- [x] 任务取消接口

---

## 配置参考

### 环境变量
| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `MOCK_EMAIL_SEND` | 模拟发送模式 | `true` |
| `AWS_REGION` | AWS 区域 | `us-east-1` |
| `AWS_ACCESS_KEY_ID` | AWS Access Key | (需配置) |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | (需配置) |
| `SES_SENDER_EMAIL` | SES 发件人邮箱 | (需配置) |
| `SNS_TOPIC_ARN` | SNS 主题 ARN | (可选) |

### 快速切换配置
```bash
# 开发/测试（模拟模式）
export MOCK_EMAIL_SEND=true

# 生产（真实发送）
export MOCK_EMAIL_SEND=false
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export SES_SENDER_EMAIL=verified@yourdomain.com
```

---

## [2026-04-19] - 执行历史与并行路径支持
**状态**: 已实现 ✅

### 新增功能

#### 1. NodeExecution 节点执行历史记录
- 新增 `NodeExecution` 模型记录每个节点的执行详情
- 记录内容：节点ID、类型、结果、输入/输出数据、事件数据、条件判断、执行耗时
- 支持通过 context 快速访问运行时执行历史
- 持久化存储到数据库支持分析和报表

#### 2. 并行路径执行支持
- 修改 `traverse_instance` 支持多分支并行执行
- 修改 `continue_instance_execution` 支持事件恢复后的并行处理
- 修改 `execute_delayed_node` 支持延时恢复后的并行处理
- 节点暂停（driver/delay）不再阻塞其他并行分支

#### 3. 前端实例详情增强
- 新增节点执行历史时间线展示
- 支持显示执行结果、耗时、条件判断、错误信息
- 可展开查看输入/输出/事件数据详情

### 并行路径示例

```
                    ┌─▶ [邮件: 分支A1]
                    │
[开始] ──▶ [邮件] ──┼─▶ [驱动: 等待打开] ──▶ [邮件: 分支A2]
                    │
                    └─▶ [邮件: 分支B1]
```

**执行行为**:
1. 初始邮件发送后，三个后续节点并行执行
2. "等待打开"节点暂停，但不影响其他两个分支
3. "分支A1"和"分支B1"继续执行完成
4. 当"等待打开"收到事件后，"分支A2"继续执行

### 数据库迁移

```sql
-- NodeExecution 表
CREATE TABLE node_execution (
    id INT AUTO_INCREMENT PRIMARY KEY,
    instance_id INT NOT NULL,
    node_id VARCHAR(50) NOT NULL,
    node_type VARCHAR(20) NOT NULL,
    node_label VARCHAR(100),
    result VARCHAR(20) NOT NULL, -- success/waiting/resumed/failed/skipped
    input_data JSON,
    output_data JSON,
    event_data JSON,
    conditions_met BOOLEAN,
    error_message TEXT,
    duration_ms INT,
    executed_at DATETIME,
    completed_at DATETIME
);

-- APScheduler 任务表
CREATE TABLE apscheduler_jobs (
    id VARCHAR(191) PRIMARY KEY,
    next_run_time DOUBLE PRECISION,
    job_state BLOB NOT NULL
);
```

---

## [进行中] 工作流页面布局重构
**日期**: 2026-04-19
**状态**: 开发中 🔄

### 需求概述
重构 Workflow.vue 页面布局，优化工作流管理和编辑体验。

### 布局调整方案

#### 整体结构
```
.workflow-page
├── .page-header (顶部)
│   ├── 标题区域: "节点发送" + 描述
│   └── .header-actions: "添加流" 按钮
└── .workflow-main (主内容区，flex横向布局)
    ├── .workflow-sidebar (左侧边栏，220px)
    │   ├── 标题: "已保存工作流"
    │   └── 工作流列表 (item)
    │       ├── 工作流名称
    │       ├── 状态标签 (active/inactive)
    │       └── 齿轮图标 ⚙️ (点击编辑属性)
    └── .workflow-canvas-area (右侧画布区，flex:1)
        ├── .canvas-toolbar-left (左上角绝对定位)
        │   ├── 当前工作流标题
        │   └── Execute 按钮
        ├── .canvas-toolbar-right (右上角绝对定位)
        │   ├── Add Node 按钮 (下拉菜单)
        │   └── Save 按钮
        └── #x6-container (画布主体)
```

#### 交互逻辑变更

| 操作 | 行为 |
|------|------|
| 点击"添加流"按钮 | 清空画布 → 弹出**简化弹窗**(仅输入标题) → 创建空白工作流 |
| 单击列表项 | 加载工作流到画布，标题显示在左上角 |
| 点击齿轮图标 | 弹出**完整属性弹窗** |
| 双击列表项 | 同点击齿轮图标，弹出完整属性弹窗 |
| 保存工作流时 | 无ID(新建) → 弹出完整属性弹窗；有ID → 直接保存 |

#### 弹窗区分

**新建弹窗**（简化版）：
- 字段：仅工作流名称
- 按钮：确定、取消
- 用途：快速创建空白工作流

**属性编辑弹窗**（完整版）：
- 字段：名称、状态开关、执行方式下拉、开始时间选择器
- 按钮：保存、取消
- 用途：编辑工作流完整属性

### 待办任务清单

- [ ] 修改 Workflow.vue 模板结构 - 重构整体布局
- [ ] 添加左侧边栏组件 - 工作流列表 (220px宽度)
- [ ] 移动按钮位置 - Add Node 和 Save 按钮到画布右上角并列
- [ ] 移动 Execute 按钮到画布左上角，左侧显示当前工作流标题
- [ ] 顶部 Header - 添加"添加流"按钮
- [ ] 添加工作流列表项交互 - 齿轮图标、单击加载、双击编辑
- [ ] 实现新建工作流弹窗（简化版 - 仅输入标题）
- [ ] 添加翻译键值 - workflow.addWorkflow, workflow.savedWorkflowsTitle 等
- [ ] 添加样式 - 左侧边栏、画布工具栏、列表项hover效果
- [ ] 测试验证 - 检查布局调整和交互功能

### 新增翻译键值

| 键值 | 中文 | 英文 |
|------|------|------|
| `workflow.addWorkflow` | 添加流 | Add Flow |
| `workflow.savedWorkflowsTitle` | 已保存工作流 | Saved Workflows |
| `workflow.edit` | 编辑 | Edit |
| `workflow.createNewWorkflow` | 新建工作流 | Create New Workflow |
| `workflow.enterWorkflowNameOnly` | 请输入工作流名称 | Please enter workflow name |

---

## [可选完成任务] 生产环境准备清单

基于项目复盘评估（生产就绪度评分：57/100），以下是部署前必须完成的任务清单。

### 🔴 高优先级（必须完成）

| 任务 | 状态 | 说明 |
|------|------|------|
| Dockerfile + docker-compose.yml | ⏳ 待实现 | 容器化部署配置 |
| Gunicorn 硬编码路径修复 | ⏳ 待实现 | 日志路径使用环境变量 |
| CORS `origins="*"` 限制 | ✅ 已完成 | 配置支持 CORS_ORIGINS 环境变量 |
| 请求限流 (Flask-Limiter) | ⏳ 待实现 | 防止 DDoS 攻击 |
| Vite 代理 IP 环境变量化 | ⏳ 待实现 | 生产/开发环境区分 |
| 健康检查接口 | ✅ 已完成 | `/health`, `/health/ready`, `/health/live`, `/health/metrics` |

---

### 🟡 中优先级（建议完成）

| 任务 | 状态 | 说明 |
|------|------|------|
| 数据库索引优化 | ✅ 已完成 | Contact, WorkflowInstance, EmailLog, EmailEvent, NodeExecution 已添加索引 |
| 结构化日志 | ✅ 已完成 | 使用 logging 替代 print，支持文件和控制台输出 |
| JWT Token 刷新机制 | ✅ 已完成 | `/auth/refresh` 端点，前端自动刷新 |
| 全局异常处理 | ✅ 已完成 | 400/401/403/404/405/429/500 统一错误响应 |
| CSRF 防护 | ⏳ 待实现 | 添加 CSRF Token 验证 |

---

### 🟢 低优先级（锦上添花）

| 任务 | 状态 | 说明 |
|------|------|------|
| 邮件模板变量替换 | ⏳ 待实现 | `{{name}}` 等变量替换 |
| 附件支持 | ⏳ 待实现 | 邮件附件上传/发送 |
| 工作流版本控制 | ⏳ 待实现 | 工作流历史版本管理 |
| 单元测试覆盖 | ⏳ 待实现 | 核心功能测试用例 |

---

### 📊 生产就绪度评估

| 维度 | 得分 | 说明 |
|------|------|------|
| 功能完整性 | 85/100 | 核心功能已实现 |
| 代码质量 | 70/100 | 结构清晰但缺少测试 |
| 安全性 | 60/100 | 基础安全有，高级防护缺失 |
| 可观测性 | 40/100 | 日志和监控严重不足 |
| 部署准备 | 30/100 | 缺少容器化配置 |
| **总分** | **57/100** | **不建议直接部署到生产环境** |

---

### ✅ 已实现的核心功能

1. **完整的工作流引擎** - 可视化设计 + 执行 + 并行路径
2. **邮件系统** - AWS SES 集成 + SNS 回调
3. **定时任务** - APScheduler 延迟/定时执行
4. **国际化** - 中英文完整支持
5. **用户认证** - JWT + 登录注册
6. **工作流实例化** - 每封邮件独立实例执行
7. **节点执行历史** - 完整执行轨迹记录

---

### 🔧 部署架构建议

```
[Nginx - 反向代理/静态文件]
         |
    +----+----+
    |         |
[Vue 3 Static] [Gunicorn + Flask]
                     |
              [MySQL + Redis]
```

**预计工作量**: 完成高优先级任务需 **3-5 天**

---

## [已完成] 事件追踪字段修复与完善 ✅
**日期**: 2026-04-21
**版本**: v1.1.1
**状态**: 事件追踪字段全部可用，message_id 问题已修复

### 事件追踪字段说明

#### 1. `EmailLog.source_event_id`
**用途**: 记录触发当前邮件的事件 ID（EmailEvent.id）
**使用场景**: 当 driver 节点触发后续邮件时，记录是哪个事件触发的
**实现位置**: `webhooks.py` 第 507 行 - `execute_node_for_instance(..., source_event_id=event.id)`

#### 2. `NodeExecution.resumed_by_event_id`
**用途**: 记录恢复节点执行的事件 ID
**使用场景**: driver 节点被事件恢复时，记录触发恢复的事件
**实现位置**: `workflow.py` 第 164 行 - `node_exec.resumed_by_event_id = source_event_id`

#### 3. `NodeExecution.event_data`
**用途**: 记录触发恢复的事件完整数据
**使用场景**: 分析事件内容，用于调试和审计
**实现位置**: `workflow.py` 第 165 行 - `node_exec.event_data = resumed_event_data`

#### 4. `EmailEvent.source_email_log_id`
**用途**: 记录触发此事件的原始邮件日志 ID
**使用场景**: 追踪事件是由哪封邮件触发的
**实现位置**: 
- `webhooks.py` 第 143 行 - SNS 回调时设置
- `webhooks.py` 第 490 行 - 模拟事件时设置

### 关键修复

#### SQLAlchemy JSON 字段变更检测
**问题**: `instance.context['key'] = value` 后 `db.session.commit()` 不生效
**原因**: SQLAlchemy 的 JSON 字段检测不到 dict 内部的变化
**修复**: 使用 `flag_modified(instance, 'context')` 强制标记字段已修改
**应用位置**: 
- `webhooks.py` 第 311 行 - 保存 delayed_source_event_id 时
- `webhooks.py` 第 332 行 - 相对延时调度后
- `webhooks.py` 第 350 行 - 绝对延时调度后

#### NodeExecution 排序优化
**修复**: `instance.py` 第 81 行 - 添加 `id.asc()` 作为第二排序条件
**效果**: 执行时间相同时，按节点执行顺序（id 自增）排列

### 事件驱动工作流执行流程

```
┌─────────────────────────────────────────────────────────────┐
│ 工作流执行流程（含事件追踪）                                   │
└─────────────────────────────────────────────────────────────┘

1. 执行工作流 (POST /api/workflow/{id}/execute)
   ↓
2. 创建 WorkflowInstance
   ↓
3. 执行首个邮件节点
   → 发送邮件 → 生成 message_id
   → EmailLog 记录 (message_id=mock-xxx, source_event_id=null)
   → instance.message_id = mock-xxx
   ↓
4. 执行 driver 节点
   → 更新 instance 状态为 waiting_event
   → 暂停执行
   ↓
5. 等待事件 (SNS 回调或模拟事件)
   ↓
6. 事件到达 (通过 message_id 匹配 instance)
   → 创建 EmailEvent
   → EmailEvent.source_email_log_id = 原始邮件的 email_log.id
   ↓
7. 恢复实例执行 (continue_instance_execution)
   → 保存事件上下文到 instance.context
   → flag_modified(instance, 'context')  # 强制标记
   → db.session.commit()
   ↓
8. 有延时步骤？
   → 是: 调度延时任务 (source_event_id 保存到上下文)
   → 否: 直接执行后续节点
   ↓
9. 延时任务执行 (execute_delayed_node)
   → 从 instance.context 恢复 source_event_id
   → execute_node_for_instance(..., source_event_id=source_event_id)
   ↓
10. 执行后续邮件节点
    → EmailLog 记录 (source_event_id = 事件ID)
    → NodeExecution 记录 (resumed_by_event_id, event_data)
```

### 数据库关系图

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   EmailEvent     │     │   EmailLog       │     │ NodeExecution    │
├──────────────────┤     ├──────────────────┤     ├──────────────────┤
│ id               │     │ id               │     │ id               │
│ message_id       │◄────│ message_id       │     │ instance_id      │
│ event_type       │     │ source_event_id  │◄────│ resumed_by_event │◄──┐
│ source_email_log │────►│                  │     │ event_data       │   │
│ instance_id      │────►│ instance_id      │     │                  │   │
└──────────────────┘     └──────────────────┘     └──────────────────┘   │
         ▲                                                            │
         │                                                            │
         └────────────────────────────────────────────────────────────┘
                              事件触发邮件
```

---

## [进行中] 数据库外键约束移除 🔄
**日期**: 2026-04-21  
**版本**: v1.2.0  
**状态**: 代码修改中

### 方案概述
移除数据库层面的外键约束（`ForeignKey`），在代码层面通过 SQLAlchemy 的 `relationship()` 实现表关联逻辑。此方案提高数据库灵活性，避免数据库层面的级联操作。

### 实施范围

#### 1. 需要移除的外键字段（19 个）

| 序号 | 表名 | 字段名 | 原外键约束 | 备注 |
|------|------|--------|------------|------|
| 1 | contact | user_id | `user.id` | 所属用户 |
| 2 | contact_group | user_id | `user.id` | 所属用户 |
| 3 | email_template | user_id | `user.id` | 所属用户 |
| 4 | workflow | user_id | `user.id` | 所属用户 |
| 5 | workflow_instance | workflow_id | `workflow.id` | 关联工作流 |
| 6 | workflow_instance | user_id | `user.id` | 所属用户 |
| 7 | email_log | user_id | `user.id` | 发送用户 |
| 8 | email_log | template_id | `email_template.id` | 邮件模板 |
| 9 | email_log | workflow_id | `workflow.id` | 关联工作流 |
| 10 | email_log | instance_id | `workflow_instance.id` | 关联实例 |
| 11 | email_log | source_event_id | `email_event.id` | 触发事件 |
| 12 | email_event | user_id | `user.id` | 所属用户 |
| 13 | email_event | instance_id | `workflow_instance.id` | 关联实例 |
| 14 | email_event | source_email_log_id | `email_log.id` | 来源邮件 |
| 15 | node_execution | instance_id | `workflow_instance.id` | 关联实例 |
| 16 | node_execution | resumed_by_event_id | `email_event.id` | 恢复事件 |
| 17 | group_contacts | group_id | `contact_group.id` | 复合主键 |
| 18 | group_contacts | contact_id | `contact.id` | 复合主键 |

#### 2. 需要修改的 relationship（6 处）

- **Workflow.instances** → WorkflowInstance（一对多）
- **WorkflowInstance.workflow** → Workflow（多对一）
- **WorkflowInstance.node_executions** → NodeExecution（一对多）
- **EmailLog.instance** → WorkflowInstance（多对一）
- **Contact.groups** ↔ **ContactGroup.contacts**（多对多）
- **WorkflowInstance.email_logs** → EmailLog（一对多）

### 代码修改示例

#### 修改前
```python
class WorkflowInstance(db.Model):
    workflow_id = db.Column(db.Integer, db.ForeignKey('workflow.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    workflow = db.relationship('Workflow', backref='instances', lazy=True)
```

#### 修改后
```python
class WorkflowInstance(db.Model):
    workflow_id = db.Column(db.Integer, nullable=False, comment='工作流ID')
    user_id = db.Column(db.Integer, nullable=False, comment='用户ID')
    
    workflow = db.relationship(
        'Workflow',
        primaryjoin='WorkflowInstance.workflow_id == Workflow.id',
        foreign_keys='WorkflowInstance.workflow_id',
        backref='instances',
        lazy=True
    )
```

### 数据库迁移 SQL

```sql
-- 删除所有外键约束
ALTER TABLE contact DROP FOREIGN KEY IF EXISTS contact_ibfk_1;
ALTER TABLE contact_group DROP FOREIGN KEY IF EXISTS contact_group_ibfk_1;
ALTER TABLE email_template DROP FOREIGN KEY IF EXISTS email_template_ibfk_1;
ALTER TABLE workflow DROP FOREIGN KEY IF EXISTS workflow_ibfk_1;
ALTER TABLE workflow_instance DROP FOREIGN KEY IF EXISTS workflow_instance_ibfk_1;
ALTER TABLE workflow_instance DROP FOREIGN KEY IF EXISTS workflow_instance_ibfk_2;
ALTER TABLE email_log DROP FOREIGN KEY IF EXISTS email_log_ibfk_1;
ALTER TABLE email_log DROP FOREIGN KEY IF EXISTS email_log_ibfk_2;
ALTER TABLE email_log DROP FOREIGN KEY IF EXISTS email_log_ibfk_3;
ALTER TABLE email_log DROP FOREIGN KEY IF EXISTS email_log_ibfk_4;
ALTER TABLE email_log DROP FOREIGN KEY IF EXISTS email_log_ibfk_5;
ALTER TABLE email_event DROP FOREIGN KEY IF EXISTS email_event_ibfk_1;
ALTER TABLE email_event DROP FOREIGN KEY IF EXISTS email_event_ibfk_2;
ALTER TABLE email_event DROP FOREIGN KEY IF EXISTS email_event_ibfk_3;
ALTER TABLE node_execution DROP FOREIGN KEY IF EXISTS node_execution_ibfk_1;
ALTER TABLE node_execution DROP FOREIGN KEY IF EXISTS node_execution_ibfk_2;
ALTER TABLE group_contacts DROP FOREIGN KEY IF EXISTS group_contacts_ibfk_1;
ALTER TABLE group_contacts DROP FOREIGN KEY IF EXISTS group_contacts_ibfk_2;
```

### 实施步骤

1. **修改 models.py** - 移除外键约束，添加 primaryjoin
2. **创建数据库迁移脚本** - 执行 SQL 删除外键
3. **测试验证** - 确保所有功能正常

---

## 最后更新
**日期**: 2026-04-21
**版本**: v1.1.1
**状态**: 事件追踪字段完整，修复 message_id 不匹配问题

---

## [待实施] SES Configuration Set 配置集支持 📋
**日期**: 2026-04-25
**版本**: v1.2.0 (计划中)
**状态**: 开发中 🔄
**提交点**: df5c008 (实施前版本)

### 需求概述
为 SES 白名单验证的邮箱添加 Configuration Set（配置集）支持，用于邮件事件追踪（打开、点击、送达等）。

### 核心设计原则
1. **前端无感知** - 用户界面无需任何改动
2. **全局配置优先** - `.env` 指定默认配置集
3. **预留扩展** - 用户绑定表预留字段，支持后期按邮箱单独配置
4. **向后兼容** - 不配置时不影响现有功能

### 优先级逻辑
```
send_email() 时 ConfigurationSetName 的确定:
│
├─ 1. 用户绑定邮箱的 configuration_set_name (如已设置)
│
├─ 2. .env 中的 SES_CONFIGURATION_SET_NAME 全局配置
│
└─ 3. 都不配置 → 不发送 ConfigurationSetName 参数
```

### 数据库变更

#### 新增字段 (user_sender_binding 表)
```sql
-- MySQL 5.7 兼容
ALTER TABLE user_sender_binding 
ADD COLUMN configuration_set_name VARCHAR(100) DEFAULT NULL 
COMMENT 'SES配置集名称（预留，优先于全局配置）';
```

### .env 配置
```ini
# SES Configuration Set（可选）
# 用于邮件事件追踪（打开、点击、送达等）
# 在 AWS SES 控制台创建配置集后填写名称
SES_CONFIGURATION_SET_NAME=mailflow-tracking
```

### 实施范围

| 层级 | 修改内容 | 文件 |
|------|---------|------|
| 数据库 | 添加预留字段 | `update_schema.sql` |
| 模型 | UserSenderBinding 添加字段 | `models.py` |
| 配置 | 读取环境变量 | `config.py` |
| 发送 | send_ses_email 集成配置集 | `routes/email.py` |
| API | get_sender_for_user 返回配置集 | `routes/email.py` |

### 代码修改要点

#### 1. send_ses_email 函数改造
```python
def send_ses_email(to_email, subject, body_html, source=None, reply_to=None, binding=None):
    kwargs = {...}
    
    # 配置集优先级：binding > 全局 > 无
    config_set = None
    if binding and binding.configuration_set_name:
        config_set = binding.configuration_set_name
    else:
        config_set = cfg.get('SES_CONFIGURATION_SET_NAME')
    
    if config_set:
        kwargs['ConfigurationSetName'] = config_set
    
    response = client.send_email(**kwargs)
```

#### 2. get_sender_for_user 函数改造
```python
# 返回绑定对象，供后续获取配置集
def get_sender_for_user(user_id, sender_binding_id=None):
    ...
    return binding, source_email, reply_to_email, None
```

### 兼容性
- ✅ 不配置 SES_CONFIGURATION_SET_NAME 时，邮件发送行为不变
- ✅ 前端无改动，完全无感知
- ✅ 现有 EmailLog 等数据无需迁移
- ✅ 支持平滑启用（随时添加配置集）

### 实施里程碑

| 阶段 | 任务 | 状态 | 预计时间 |
|------|------|------|---------|
| 1 | 更新 changelog.md | ✅ 已完成 | 5min |
| 2 | 修改 models.py 添加字段 | ✅ 已完成 | 5min |
| 3 | 生成 SQL 更新语句 (MySQL 5.7) | ✅ 已完成 | 5min |
| 4 | 修改 config.py 读取配置 | ✅ 已完成 | 5min |
| 5 | 修改 routes/email.py 集成配置集 | ✅ 已完成 | 10min |
| 6 | 测试验证不破坏现有功能 | ⏳ 待开始 | 10min |

### 注意事项
1. **缩进谨慎** - Python 代码缩进严格，编辑时注意保持
2. **None 处理** - configuration_set_name 可能为 None，需做空值判断
3. **AWS API** - ConfigurationSetName 只在发送邮件时指定，不在绑定邮箱时设置
4. **测试** - 测试模拟模式和真实 SES 模式都要验证

---
