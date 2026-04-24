# Mail Flow - 邮件工作流管理平台

## 一、项目概述

**Mail Flow** 是一个邮件工作流管理平台，支持可视化编排邮件发送流程、事件驱动自动化、以及邮件状态追踪。

### 核心功能
1. **联系人管理** - 维护联系人信息和分组
2. **邮件模板** - 支持 HTML 模板和预设模板
3. **批量发送** - 向联系人或分组发送邮件
4. **工作流编排** - 可视化拖拽创建工作流（邮件节点 + 事件驱动节点）
5. **事件追踪** - 监听邮件发送后的各类事件（打开、点击、退信等）

### 技术架构
- **前端**: Vue 3 + Vite + Element Plus + AntV X6
- **后端**: Flask + SQLAlchemy + JWT
- **数据库**: MySQL
- **邮件服务**: AWS SES (支持模拟模式)
- **定时任务**: APScheduler

---

## 二、项目结构

```
H:/test/
├── pythonBack/                    # Flask 后端 (端口 8880)
│   ├── app.py                     # Flask 应用工厂入口
│   ├── config.py                  # 应用配置 (含 AWS/DB 配置)
│   ├── models.py                  # SQLAlchemy 数据模型
│   ├── requirements.txt           # Python 依赖
│   ├── init_db.sql                # 数据库初始化脚本
│   ├── gunicorn.conf.py           # Gunicorn 配置
│   ├── routes/                    # API 路由蓝图
│   │   ├── auth.py               # 认证 (登录/注册)
│   │   ├── contacts.py           # 联系人管理
│   │   ├── groups.py             # 用户组管理
│   │   ├── templates.py          # 邮件模板管理
│   │   ├── email.py              # 邮件发送
│   │   ├── workflow.py           # 工作流管理
│   │   └── webhooks.py           # SNS Webhook 和事件处理
│   └── services/
│       └── scheduler.py          # APScheduler 延时任务调度
│
└── vue3Model/                     # Vue 3 前端 (端口 5173)
    ├── src/
    │   ├── main.js               # 应用入口
    │   ├── App.vue               # 根组件
    │   ├── i18n.js               # 国际化配置
    │   ├── router/index.js       # Vue Router 配置
    │   ├── stores/user.js        # Pinia 用户状态
    │   ├── utils/
    │   │   ├── request.js        # Axios 请求封装
    │   │   └── presetTemplates.js # 预设邮件模板
    │   ├── locales/
    │   │   └── zh.json           # 中英文翻译
    │   ├── components/
    │   │   └── LocaleSwitcher.vue # 语言切换组件
    │   └── views/                # 页面组件
    │       ├── Login.vue         # 登录/注册
    │       ├── Layout.vue        # 主布局 (侧边栏)
    │       ├── Contacts.vue      # 联系人管理
    │       ├── Groups.vue        # 用户组管理
    │       ├── Templates.vue     # 邮件模板管理
    │       ├── SendEmail.vue     # 发送邮件
    │       ├── Workflow.vue      # 工作流设计器 (核心)
    │       └── Events.vue        # 邮件事件监控
    ├── vite.config.js            # Vite 配置
    └── package.json
```

---

## 三、数据库配置

### MySQL 连接信息
| 配置项 | 值 |
|--------|-----|
| **主机** | 192.168.56.131 |
| **端口** | 3306 |
| **用户名** | root |
| **密码** | root |
| **数据库名** | contact_mail |

### 远程 SSH 访问 (用于维护)
| 配置项 | 值 |
|--------|-----|
| **IP** | 192.168.56.131 |
| **端口** | 22 |
| **用户名** | root |
| **密码** | root |

### 数据库模型关系
```
User (用户)
  ├── Contact (联系人) ─── ContactGroup (用户组) [多对多]
  ├── EmailTemplate (邮件模板)
  ├── Workflow (工作流)
  ├── EmailLog (邮件发送日志)
  └── EmailEvent (邮件事件记录)
```

---

## 四、后端架构详解

### 4.1 API 端点列表

#### 认证 (`/api/auth`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/register` | POST | 用户注册 |
| `/login` | POST | 用户登录，返回 JWT Token |
| `/me` | GET | 获取当前用户信息 |

#### 联系人 (`/api/contacts`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/` | GET | 获取联系人列表 (支持搜索) |
| `/` | POST | 创建联系人 |
| `/<id>` | PUT | 更新联系人 |
| `/<id>` | DELETE | 删除联系人 |

#### 用户组 (`/api/groups`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/` | GET | 获取用户组列表 |
| `/` | POST | 创建用户组 |
| `/<id>` | PUT | 更新用户组 |
| `/<id>` | DELETE | 删除用户组 |
| `/<id>/members` | POST | 添加组成员 |
| `/<id>/members` | DELETE | 移除组成员 |

#### 邮件模板 (`/api/templates`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/` | GET | 获取模板列表 |
| `/` | POST | 创建模板 |
| `/<id>` | PUT | 更新模板 |
| `/<id>` | DELETE | 删除模板 |

#### 邮件发送 (`/api/email`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/send` | POST | 发送邮件 |
| `/settings` | GET | 获取邮件设置 |

#### 工作流 (`/api/workflow`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/` | GET | 获取工作流列表 |
| `/` | POST | 创建工作流 |
| `/<id>` | PUT | 更新工作流 |
| `/<id>` | DELETE | 删除工作流 |
| `/<id>/execute` | POST | 执行工作流 |

#### Webhook (`/api/webhooks`)
| 端点 | 方法 | 功能 |
|------|------|------|
| `/sns` | POST | 接收 AWS SNS 邮件事件 |
| `/simulate/event` | POST | 模拟邮件事件 (测试用) |
| `/events` | GET | 获取邮件事件列表 |
| `/scheduled` | GET | 获取计划任务列表 |
| `/scheduled/<id>` | DELETE | 取消计划任务 |

### 4.2 工作流数据结构

工作流的 `flow_data` 字段存储为 JSON：
```json
{
  "nodes": [
    {
      "id": "node-1",
      "x": 100,
      "y": 200,
      "data": {
        "nodeType": "email",
        "label": "欢迎邮件",
        "template_id": 1,
        "recipientType": "contact",
        "contact_ids": [1, 2]
      }
    },
    {
      "id": "node-2",
      "data": {
        "nodeType": "driver",
        "label": "事件驱动",
        "steps": [
          {"id": "event", "enabled": true, "event_type": "click", "link_url": ""},
          {"id": "condition", "enabled": true, "field": "event_type", "operator": "eq", "value": "click"},
          {"id": "delay", "enabled": true, "delayType": "relative", "delayValue": 1, "delayUnit": "hours"}
        ],
        "stepOrder": ["event", "condition", "delay"]
      }
    }
  ],
  "edges": [
    {"source": "node-1", "sourcePort": "right", "target": "node-2", "targetPort": "left"}
  ]
}
```

### 4.3 AWS SES 配置

| 环境变量 | 说明 | 默认值 |
|----------|------|--------|
| `AWS_REGION` | AWS 区域 | us-east-1 |
| `AWS_ACCESS_KEY_ID` | AWS Access Key | (预配置) |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | (预配置) |
| `SES_SENDER_EMAIL` | SES 发件人邮箱 | badapplesweetie@gmail.com |
| `MOCK_EMAIL_SEND` | 模拟发送模式 | true |

---

## 五、前端架构详解

### 5.1 技术栈版本
| 技术 | 版本 |
|------|------|
| Vue | 3.5.13 |
| Vue Router | 4.6.4 |
| Pinia | 3.0.4 |
| Element Plus | 2.13.5 |
| Vite | 6.2.4 |
| AntV X6 | 3.1.6 |
| Vue I18n | 11.3.1 |

### 5.2 路由配置
| 路径 | 组件 | 说明 |
|------|------|------|
| `/login` | Login.vue | 登录页 |
| `/` | Layout.vue | 主布局 (默认重定向到 /contacts) |
| `/contacts` | Contacts.vue | 联系人管理 |
| `/groups` | Groups.vue | 用户组管理 |
| `/templates` | Templates.vue | 邮件模板 |
| `/send-email` | SendEmail.vue | 发送邮件 |
| `/workflow` | Workflow.vue | 工作流设计器 |
| `/events` | Events.vue | 邮件事件监控 |

### 5.3 状态管理 (Pinia)
```javascript
// user.js
{
  token: '',        // JWT Token
  username: '',     // 用户名
  login(form),     // 登录
  register(form),  // 注册
  logout()         // 退出
}
```

### 5.4 国际化 (i18n)
- 语言包: `src/locales/zh.json`
- 支持: 中英文切换
- 存储: localStorage
- 默认: 英文

### 5.5 请求封装
```javascript
// utils/request.js
{
  baseURL: '/api',
  timeout: 10000,
  headers: { Authorization: 'Bearer <token>' } // 自动附加
}
```

### 5.6 Vite 代理配置
```javascript
// vite.config.js
proxy: {
  '/api': {
    target: 'http://192.168.123.130:8880',  // 后端地址
    changeOrigin: true,
    secure: false
  }
}
```

---

## 六、工作流节点详解

### 6.1 邮件发送节点 (email)
| 配置项 | 类型 | 说明 |
|--------|------|------|
| `label` | string | 节点名称 |
| `nodeType` | string | "email" |
| `template_id` | number | 邮件模板 ID |
| `recipientType` | string | "contact" 或 "group" |
| `contact_ids` | array | 联系人 ID 列表 |
| `group_ids` | array | 用户组 ID 列表 |

### 6.2 事件驱动节点 (driver)
支持三种可拖拽排序的步骤：

#### 事件监听 (event)
| 配置项 | 说明 |
|--------|------|
| `event_type` | send/delivery/open/click/bounce/complaint/deliveryDelay |
| `link_url` | 当 event_type=click 时，可指定链接过滤 |

#### 条件判断 (condition)
| 配置项 | 说明 |
|--------|------|
| `field` | event_type/link_url/recipient |
| `operator` | eq/neq/contains/not_contains |
| `value` | 比较值 |

#### 延时 (delay)
| 配置项 | 说明 |
|--------|------|
| `delayType` | "relative" (相对) 或 "absolute" (绝对) |
| `delayValue` | 相对延时数值 |
| `delayUnit` | minutes/hours/days |
| `delayDateTime` | 绝对时间 (ISO 格式) |

---

## 七、快速开始

### 7.1 启动后端
```bash
cd H:/test/pythonBack
.venv\Scripts\activate          # Windows 激活虚拟环境
pip install -r requirements.txt  # 安装依赖 (首次)
python app.py                  # 启动 Flask (端口 8880)
```

### 7.2 启动前端
```bash
cd H:/test/vue3Model
npm install                    # 安装依赖 (首次)
npm run dev                    # 启动开发服务器 (端口 5173)
```

### 7.3 访问应用
- 前端地址: http://localhost:5173
- 后端地址: http://localhost:8880

### 7.4 测试账号
| 用户名 | 密码 |
|--------|------|
| test | test123 |

---

## 八、开发历史记录

### 2026-04-19 - Bug 修复
- 修复工作流节点编辑的三个关键 bug
  - 事件驱动节点编辑修改无法持久保存
  - 双击节点编辑时节点名称为空
  - 编辑节点 A 后再编辑节点 B 时信息串扰

### 2026-04-08 - Workflow 优化
- 禁止节点拖动
- 优化节点初始位置计算

### 2026-04-08 - i18n 国际化
- 添加中英文切换
- 所有页面支持多语言

### 早期版本
- 实现基础 CRUD (联系人、用户组、模板)
- 实现邮件发送 (AWS SES + 模拟模式)
- 实现工作流设计器 (基于 AntV X6)
- 实现事件追踪和 Webhook

---

## 九、注意事项

1. **数据库**: 确保 MySQL 服务在 192.168.56.131:3306 可访问
2. **跨域**: 后端已配置 CORS 允许 `/api/*` 路径
3. **JWT Token**: 有效期 24 小时
4. **模拟模式**: 设置 `MOCK_EMAIL_SEND=true` 可不实际发送邮件
5. **工作流保存**: 切换工作流时会提示保存未保存的修改

---

**项目路径**: `H:/test/`  
**前端路径**: `H:/test/vue3Model/`  
**后端路径**: `H:/test/pythonBack/`  
**最后更新**: 2026-04-19
