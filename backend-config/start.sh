#!/bin/bash
# Mail Flow 后端启动脚本
# 用于开发环境手动启动

cd /var/www/mailflow/pythonBack

# 加载环境变量
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# 激活虚拟环境
source .venv/bin/activate

# 启动 Gunicorn
exec gunicorn -c gunicorn.conf.py app:app
