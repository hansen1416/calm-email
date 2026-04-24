# SNS 回调处理指南

## 概述

本文档说明 AWS SES/SNS 回调的处理机制，包括消息去重、延迟监控和并发处理。

## 功能特性

### 1. 消息去重（Message Deduplication）

**问题**：SNS 可能会重复推送同一事件

**解决方案**：
- 使用 SNS `MessageId` 作为唯一标识
- 支持两种去重方式：
  - **数据库唯一约束**：`email_event.sns_message_id` 字段有 UNIQUE 索引
  - **Redis 缓存**：可选启用，更快的去重检查

**配置**：
```bash
# 去重记录保存天数（默认30天）
SNS_DEDUP_DAYS=30

# 是否启用 Redis（可选）
REDIS_ENABLED=false
REDIS_URL=redis://localhost:6379/0
```

### 2. 延迟监控（Latency Monitoring）

**监控指标**：
- `sns_received_at`：SNS 消息接收时间
- `sns_delay_seconds`：回调延迟（秒）

**告警阈值**：
```bash
# 延迟超过此值记录告警（默认60秒）
SNS_DELAY_THRESHOLD_SECONDS=60
```

**查看延迟**：
```sql
-- 查询平均延迟
SELECT AVG(sns_delay_seconds) FROM email_event WHERE sns_delay_seconds IS NOT NULL;

-- 查询超过阈值的延迟
SELECT * FROM email_event 
WHERE sns_delay_seconds > 60 
ORDER BY sns_delay_seconds DESC;
```

### 3. 并发处理（Concurrent Handling）

**问题**：批量发送时 SNS 可能并发推送

**解决方案**：
- 数据库唯一约束：`UNIQUE(instance_id, sns_message_id)`
- 第一个请求成功处理
- 后续并发请求识别为重复并忽略
- 记录并发冲突日志

## API 端点

### 接收 SNS 回调

```http
POST /api/webhooks/sns
Content-Type: text/plain

# SNS 推送的 JSON 数据
```

**响应**：
- `200`：成功处理
- `200` (duplicate)：重复消息被忽略
- `400`：数据无效

### 模拟事件

```http
POST /api/webhooks/simulate/event
Content-Type: application/json

{
  "event_type": "open",
  "message_id": "msg-123",
  "recipient_email": "user@example.com",
  "event_data": {...},
  "mock_send": false
}
```

## 数据库表结构

### email_event 表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| sns_message_id | VARCHAR(100) | SNS 消息ID（唯一） |
| sns_received_at | DATETIME | 接收时间 |
| sns_delay_seconds | FLOAT | 延迟秒数 |
| event_type | VARCHAR(20) | 事件类型（小写） |
| message_id | VARCHAR(100) | SES Message ID |
| ... | ... | 其他字段 |

## 常见问题

### Q1: SNS 消息多久会到达？

**A**: 通常是实时的，但可能有以下延迟：
- Send/Delivery：几秒内
- Open/Click：用户行为触发，可能有延迟
- Bounce/Complaint：可能有轻微延迟

### Q2: 如何处理重复消息？

**A**: 系统会自动去重：
- 根据 `sns_message_id` 判断
- 重复消息会返回 `200`，但会标记为重复
- 并发请求会由数据库唯一约束处理

### Q3: 延迟告警如何触发？

**A**: 当 `sns_delay_seconds > SNS_DELAY_THRESHOLD_SECONDS` 时：
- 记录 WARNING 级别日志
- 日志包含 `sns_message_id` 和实际延迟时间

### Q4: 如何清理旧的去重记录？

**A**: Redis 会自动过期（根据 `SNS_DEDUP_DAYS`），数据库记录建议保留用于审计。

## 监控建议

1. **日志监控**：关注 `[SNS Handler]` 开头的日志
2. **延迟告警**：设置 CloudWatch 或日志告警
3. **重复率监控**：统计 `Duplicate event ignored` 日志数量

## 相关配置

详见 `.env.example` 文件中的 SNS 相关配置项。
