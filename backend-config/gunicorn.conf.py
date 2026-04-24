#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gunicorn 配置文件 - Mail Flow 后端
"""
import os
import multiprocessing

# ========================================
# 服务器绑定
# ========================================
bind = "127.0.0.1:8880"

# ========================================
# 工作进程配置
# ========================================
# 工作进程数 = CPU核心数 * 2 + 1
workers = multiprocessing.cpu_count() * 2 + 1

# 工作进程类
worker_class = "sync"

# 每个工作进程的最大请求数（防止内存泄漏）
max_requests = 1000
max_requests_jitter = 50

# 工作进程超时时间（秒）
timeout = 120

# 优雅重启超时
timeout = 30

# 保持连接时间
keepalive = 5

# ========================================
# 日志配置
# ========================================
# 日志目录（从环境变量读取，或使用默认）
log_dir = os.environ.get('LOG_DIR', '/var/log/mailflow')

# 确保日志目录存在
os.makedirs(log_dir, exist_ok=True)

# 访问日志
accesslog = os.path.join(log_dir, 'access.log')

# 错误日志
errorlog = os.path.join(log_dir, 'error.log')

# 日志级别: debug, info, warning, error, critical
loglevel = os.environ.get('LOG_LEVEL', 'info').lower()

# 日志格式
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# ========================================
# 进程管理
# ========================================
# PID 文件
pidfile = os.path.join(log_dir, 'gunicorn.pid')

# 进程名称
proc_name = 'mailflow'

# 是否守护进程（使用 systemd 时设为 False）
daemon = False

# 工作进程用户（生产环境）
# user = 'www-data'
# group = 'www-data'

# ========================================
# 安全设置
# ========================================
# 限制请求头大小
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# ========================================
# 服务器钩子
# ========================================
def on_starting(server):
    """服务器启动时调用"""
    print(f"[Gunicorn] Starting server with {workers} workers")

def on_reload(server):
    """配置重载时调用"""
    print("[Gunicorn] Reloading configuration")

def when_ready(server):
    """工作进程就绪时调用"""
    print(f"[Gunicorn] Server ready on {bind}")

def worker_int(worker):
    """工作进程中断时调用"""
    print(f"[Gunicorn] Worker {worker.pid} interrupted")

def worker_abort(worker):
    """工作进程异常退出时调用"""
    print(f"[Gunicorn] Worker {worker.pid} aborted")
