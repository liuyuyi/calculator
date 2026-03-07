#!/bin/bash

# CentOS 7.9.2111-x64 自动配置脚本
# 功能：配置 nvm 使用 Node.js 14.21.3 并设置 pm2 开机自启

set -e

echo "=========================================="
echo "CentOS 7.9 PM2 自动启动配置脚本"
echo "=========================================="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 用户运行此脚本"
    exit 1
fi

# 获取用户输入的 JavaScript 文件名
read -p "请输入要启动的 JavaScript 文件名 (例如: app.js): " APP_FILE

if [ -z "$APP_FILE" ]; then
    echo "错误: 必须提供 JavaScript 文件名"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$APP_FILE" ]; then
    echo "警告: 文件 $APP_FILE 不存在，请确保文件路径正确"
    read -p "是否继续? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

echo ""
echo "步骤 1: 检查 nvm 安装..."
if [ ! -d "$HOME/.nvm" ]; then
    echo "错误: nvm 未安装在 $HOME/.nvm"
    echo "请先安装 nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
    exit 1
fi
echo "✓ nvm 已安装"

echo ""
echo "步骤 2: 检查 Node.js 14.21.3 安装..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! nvm ls 14.21.3 &> /dev/null; then
    echo "Node.js 14.21.3 未安装，正在安装..."
    nvm install 14.21.3
fi
echo "✓ Node.js 14.21.3 已安装"

echo ""
echo "步骤 3: 检查 pm2 安装..."
if ! command -v pm2 &> /dev/null; then
    echo "pm2 未安装，正在安装..."
    nvm use 14.21.3
    npm install -g pm2
fi
echo "✓ pm2 已安装"

echo ""
echo "步骤 4: 创建启动脚本..."
cat > /root/startup-nvm-pm2.sh << 'EOF'
#!/bin/bash

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 使用 Node.js 14.21.3
nvm use 14.21.3

# 启动 pm2 应用
pm2 start /root/APP_FILE_PLACEHOLDER

# 保存 pm2 进程列表
pm2 save
EOF

# 替换占位符为实际的文件名
sed -i "s|APP_FILE_PLACEHOLDER|$APP_FILE|g" /root/startup-nvm-pm2.sh

chmod +x /root/startup-nvm-pm2.sh
echo "✓ 启动脚本已创建: /root/startup-nvm-pm2.sh"

echo ""
echo "步骤 5: 创建 systemd 服务..."
cat > /etc/systemd/system/pm2-nvm.service << 'EOF'
[Unit]
Description=PM2 Process Manager with Node.js 14.21.3
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/root
ExecStart=/root/startup-nvm-pm2.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "✓ systemd 服务已创建"

echo ""
echo "步骤 6: 启用并启动服务..."
systemctl enable pm2-nvm.service
systemctl start pm2-nvm.service
echo "✓ 服务已启用并启动"

echo ""
echo "步骤 7: 验证配置..."
sleep 3

# 检查服务状态
if systemctl is-active --quiet pm2-nvm.service; then
    echo "✓ pm2-nvm 服务运行正常"
else
    echo "✗ pm2-nvm 服务启动失败"
    echo "查看日志: journalctl -u pm2-nvm.service -n 50 --no-pager"
fi

# 检查 Node.js 版本
NODE_VERSION=$(node -v 2>/dev/null || echo "未安装")
echo "当前 Node.js 版本: $NODE_VERSION"

# 检查 pm2 进程
if command -v pm2 &> /dev/null; then
    echo ""
    echo "PM2 进程列表:"
    pm2 list
fi

echo ""
echo "=========================================="
echo "配置完成！"
echo "=========================================="
echo ""
echo "生成的文件:"
echo "  - /root/startup-nvm-pm2.sh (启动脚本)"
echo "  - /etc/systemd/system/pm2-nvm.service (systemd 服务)"
echo ""
echo "常用命令:"
echo "  查看服务状态: systemctl status pm2-nvm.service"
echo "  查看服务日志: journalctl -u pm2-nvm.service -f"
echo "  重启服务: systemctl restart pm2-nvm.service"
echo "  停止服务: systemctl stop pm2-nvm.service"
echo "  查看 pm2 进程: pm2 list"
echo "  查看 pm2 日志: pm2 logs"
echo ""
echo "测试重启: reboot"
echo ""