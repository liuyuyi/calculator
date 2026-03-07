#!/bin/bash

# Startup script for CentOS 7.9 to set nvm Node.js version and start pm2
# 日志文件
LOG_FILE="/var/log/pm2-nvm-startup.log"

# 记录启动时间
echo "========================================" >> $LOG_FILE
echo "PM2 NVM Startup Script - $(date)" >> $LOG_FILE
echo "========================================" >> $LOG_FILE

# 记录当前用户
echo "Current user: $(whoami)" >> $LOG_FILE
echo "HOME directory: $HOME" >> $LOG_FILE

# 设置 NVM_DIR
export NVM_DIR="$HOME/.nvm"
echo "NVM_DIR: $NVM_DIR" >> $LOG_FILE

# 检查 nvm 是否存在
if [ ! -d "$NVM_DIR" ]; then
    echo "ERROR: NVM directory not found: $NVM_DIR" >> $LOG_FILE
    exit 1
fi

# 加载 nvm
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
    echo "NVM loaded successfully" >> $LOG_FILE
else
    echo "ERROR: nvm.sh not found" >> $LOG_FILE
    exit 1
fi

# 检查 Node.js 14.21.3 是否安装
if ! nvm ls 14.21.3 &> /dev/null; then
    echo "ERROR: Node.js 14.21.3 not installed" >> $LOG_FILE
    echo "Available Node.js versions:" >> $LOG_FILE
    nvm ls >> $LOG_FILE 2>&1
    exit 1
fi

# 使用 Node.js 14.21.3
nvm use 14.21.3
echo "Node.js version set to 14.21.3" >> $LOG_FILE

# 验证 Node.js 版本
NODE_VERSION=$(node -v)
echo "Current Node.js version: $NODE_VERSION" >> $LOG_FILE

# 检查 pm2 是否安装
if ! command -v pm2 &> /dev/null; then
    echo "ERROR: pm2 not found" >> $LOG_FILE
    exit 1
fi

# 记录 pm2 版本
PM2_VERSION=$(pm2 -v)
echo "PM2 version: $PM2_VERSION" >> $LOG_FILE

# 启动 pm2 应用（替换为你的实际文件名）
APP_FILE="/root/simpleHttpServer.js"
echo "Starting PM2 app: $APP_FILE" >> $LOG_FILE

if [ -f "$APP_FILE" ]; then
    pm2 start $APP_FILE
    echo "PM2 app started successfully" >> $LOG_FILE
else
    echo "WARNING: App file not found: $APP_FILE" >> $LOG_FILE
    echo "Please update the APP_FILE path in the script" >> $LOG_FILE
fi

# 保存 pm2 进程列表
pm2 save
echo "PM2 process list saved" >> $LOG_FILE

# 记录 pm2 进程状态
echo "Current PM2 processes:" >> $LOG_FILE
pm2 list >> $LOG_FILE

echo "========================================" >> $LOG_FILE
echo "Startup script completed" >> $LOG_FILE
echo "========================================" >> $LOG_FILE