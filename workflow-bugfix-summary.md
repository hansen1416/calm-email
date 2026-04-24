# 工作流 Bug 修复总结

## 问题列表与修复方案

### 问题 1: 事件触发后重复执行第一个节点
**根本原因**: `continue_instance_execution` 中执行后续节点时，`visited` 集合只包含 `current_node_id`（driver 节点），但首节点（邮件节点）不在 visited 中，导致如果首节点是后续节点会被重复执行。

**修复**: 确保 visited 集合包含实例已执行的所有节点。

### 问题 2: 延时节点后续邮件立即执行
**根本原因**: driver 节点中的 "延时" 步骤只是配置，没有实际调度。需要在事件触发后检查并执行延时调度。

**修复**: 在 driver 节点处理完成后，检查是否有延时步骤，如有则调度后续邮件节点。

### 问题 3: EmailLog 缺少 instance_id 和 source_event_id
**根本原因**: 创建 EmailLog 时未正确设置 instance_id，source_event_id 也未记录。

**修复**: 在创建 EmailLog 时确保传入 instance_id，并在事件触发时记录 source_event_id。

### 问题 4: EmailEvent 缺少 instance_id
**根本原因**: 创建 EmailEvent 时未设置 instance_id。

**修复**: 在创建 EmailEvent 时设置 instance_id。

---

## 修复步骤

### 1. 修复重复执行问题 (webhooks.py)

```python
# 在 continue_instance_execution 中，visited 应该包含实例已执行的所有节点
# 需要从 node_execution 表中查询已执行的节点
```

### 2. 修复延时调度问题 (webhooks.py)

```python
# 在 driver 节点处理完成后，检查是否有延时步骤
# 如有则调用 schedule_relative_delay 或 schedule_absolute_delay
```

### 3. 完善 EmailLog 记录 (workflow.py & webhooks.py)

```python
# 创建 EmailLog 时确保 instance_id 被正确设置
# 在事件触发场景下记录 source_event_id
```

### 4. 完善 EmailEvent 记录 (webhooks.py)

```python
# 创建 EmailEvent 时设置 instance_id
```
