@echo off
chcp 65001
cls

:: ========================================
:: Mail Flow 本地开发启动脚本
:: Windows 环境
:: ========================================

echo.
echo ========================================
echo   Mail Flow 本地开发环境启动
echo ========================================
echo.

:: 配置变量
set BACKEND_DIR=%~dp0..\pythonBack
set FRONTEND_DIR=%~dp0..\vue3Model
set FRP_DIR=C:\frp

:: 显示菜单
:MENU
echo 请选择启动选项:
echo.
echo 1. 启动后端 (Flask Dev Server)
echo 2. 启动后端 (Gunicorn - 推荐)
echo 3. 启动前端 (npm run dev)
echo 4. 启动 FRP 客户端 (内网穿透)
echo 5. 启动全部 (后端 + 前端 + FRP)
echo 6. 检查环境配置
echo 7. 初始化数据库
echo 8. 退出
echo.

set /p choice="请输入选项 (1-8): "

if "%choice%"=="1" goto START_BACKEND
if "%choice%"=="2" goto START_GUNICORN
if "%choice%"=="3" goto START_FRONTEND
if "%choice%"=="4" goto START_FRP
if "%choice%"=="5" goto START_ALL
if "%choice%"=="6" goto CHECK_ENV
if "%choice%"=="7" goto INIT_DB
if "%choice%"=="8" goto EXIT

:: 启动后端 (Flask)
:START_BACKEND
echo.
echo [INFO] 启动后端服务...
cd /d %BACKEND_DIR%
if not exist .venv (
    echo [ERROR] 虚拟环境不存在，请先运行: python -m venv .venv
    pause
    goto MENU
)
call .venv\Scripts\activate
set FLASK_ENV=development
set FLASK_DEBUG=1
echo [INFO] Flask 运行在 http://localhost:8880
echo [INFO] 按 Ctrl+C 停止服务
echo.
python app.py
pause
goto MENU

:: 启动后端 (Gunicorn)
:START_GUNICORN
echo.
echo [INFO] 启动后端服务 (Gunicorn)...
cd /d %BACKEND_DIR%
if not exist .venv (
    echo [ERROR] 虚拟环境不存在，请先运行: python -m venv .venv
    pause
    goto MENU
)
call .venv\Scripts\activate
echo [INFO] Gunicorn 运行在 http://localhost:8880
echo [INFO] 按 Ctrl+C 停止服务
echo.
gunicorn -w 2 -b 127.0.0.1:8880 app:app
pause
goto MENU

:: 启动前端
:START_FRONTEND
echo.
echo [INFO] 启动前端服务...
cd /d %FRONTEND_DIR%
if not exist node_modules (
    echo [WARN] node_modules 不存在，正在安装依赖...
    npm install
)
echo [INFO] Vite 运行在 http://localhost:5175
echo [INFO] 按 Ctrl+C 停止服务
echo.
npm run dev
pause
goto MENU

:: 启动 FRP 客户端
:START_FRP
echo.
echo [INFO] 启动 FRP 客户端...
if not exist %FRP_DIR%\frpc.exe (
    echo [ERROR] FRP 未安装
    echo [INFO] 请下载 FRP 到 %FRP_DIR%
    echo [INFO] 下载地址: https://github.com/fatedier/frp/releases
    pause
    goto MENU
)
if not exist %FRP_DIR%\frpc.toml (
    echo [ERROR] FRP 配置文件不存在: %FRP_DIR%\frpc.toml
    echo [INFO] 请复制配置文件模板并修改
    pause
    goto MENU
)
cd /d %FRP_DIR%
echo [INFO] FRP 客户端启动中...
echo [INFO] 查看日志: frpc.log
echo [INFO] 按 Ctrl+C 停止服务
echo.
frpc.exe -c frpc.toml
pause
goto MENU

:: 启动全部
:START_ALL
echo.
echo [INFO] 启动所有服务...
echo.
echo 1. 启动后端 (在新窗口)
start "MailFlow Backend" cmd /k "cd /d %BACKEND_DIR% && call .venv\Scripts\activate && set FLASK_ENV=development && python app.py"
timeout /t 3 /nobreak >nul

echo 2. 启动前端 (在新窗口)
start "MailFlow Frontend" cmd /k "cd /d %FRONTEND_DIR% && npm run dev"
timeout /t 3 /nobreak >nul

echo 3. 启动 FRP (在新窗口)
if exist %FRP_DIR%\frpc.exe (
    start "MailFlow FRP" cmd /k "cd /d %FRP_DIR% && frpc.exe -c frpc.toml"
) else (
    echo [WARN] FRP 未安装，跳过
)

echo.
echo [INFO] 所有服务已启动
echo [INFO] 前端: http://localhost:5175
echo [INFO] 后端: http://localhost:8880
echo.
pause
goto MENU

:: 检查环境
:CHECK_ENV
echo.
echo ========================================
echo   环境检查
echo ========================================
echo.

:: 检查 Python
echo [CHECK] Python...
python --version 2>nul
if %errorlevel% neq 0 (
    echo [FAIL] Python 未安装或不在 PATH 中
) else (
    echo [OK] Python 已安装
)

:: 检查虚拟环境
echo.
echo [CHECK] Python 虚拟环境...
if exist %BACKEND_DIR%\.venv (
    echo [OK] 虚拟环境存在
) else (
    echo [FAIL] 虚拟环境不存在
    echo [INFO] 请运行: cd %BACKEND_DIR% && python -m venv .venv
)

:: 检查 Node.js
echo.
echo [CHECK] Node.js...
node --version 2>nul
if %errorlevel% neq 0 (
    echo [FAIL] Node.js 未安装
) else (
    echo [OK] Node.js 已安装
)

:: 检查前端依赖
echo.
echo [CHECK] 前端依赖...
if exist %FRONTEND_DIR%\node_modules (
    echo [OK] node_modules 存在
) else (
    echo [FAIL] node_modules 不存在
    echo [INFO] 请运行: cd %FRONTEND_DIR% && npm install
)

:: 检查 FRP
echo.
echo [CHECK] FRP 客户端...
if exist %FRP_DIR%\frpc.exe (
    echo [OK] FRP 已安装
) else (
    echo [WARN] FRP 未安装 (可选)
    echo [INFO] 下载地址: https://github.com/fatedier/frp/releases
)

:: 检查环境变量文件
echo.
echo [CHECK] 环境变量配置...
if exist %BACKEND_DIR%\.env (
    echo [OK] .env 文件存在
    echo [INFO] 配置内容:
    type %BACKEND_DIR%\.env | findstr /B /V "#" 2>nul
) else (
    echo [WARN] .env 文件不存在
    echo [INFO] 请复制 %BACKEND_DIR%\.env.example 为 .env 并修改
)

echo.
echo ========================================
pause
goto MENU

:: 初始化数据库
:INIT_DB
echo.
echo [INFO] 初始化数据库...
cd /d %BACKEND_DIR%
if not exist .venv (
    echo [ERROR] 虚拟环境不存在
    pause
    goto MENU
)
call .venv\Scripts\activate
echo [INFO] 正在创建数据库表...
python -c "from app import create_app; from models import db; app = create_app(); app.app_context().push(); db.create_all(); print('Database initialized successfully')"
if %errorlevel% equ 0 (
    echo.
    echo [OK] 数据库初始化成功
) else (
    echo.
    echo [FAIL] 数据库初始化失败
    echo [INFO] 请检查数据库连接配置
)
pause
goto MENU

:: 退出
:EXIT
echo.
echo [INFO] 退出程序
timeout /t 1 /nobreak >nul
exit /b 0
