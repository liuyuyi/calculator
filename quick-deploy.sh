#!/bin/bash

# 快速部署脚本（简化版）
# 用于快速部署 Node.js 应用、PM2、Nginx、MongoDB

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "快速部署脚本"
echo "=========================================="
echo ""

# 1. 安装 NVM
echo "[1/7] 安装 NVM..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    echo "✓ NVM 安装完成"
else
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    echo "✓ NVM 已安装"
fi

# 2. 安装 Node.js 14.21.3
echo "[2/7] 安装 Node.js 14.21.3..."
nvm install 14.21.3
nvm use 14.21.3
nvm alias default 14.21.3
echo "✓ Node.js $(node -v) 安装完成"

# 3. 安装 PM2
echo "[3/7] 安装 PM2..."
npm install -g pm2
echo "✓ PM2 $(pm2 -v) 安装完成"

# 4. 部署应用
echo "[4/7] 部署应用..."
if [ -d "/root/calculator" ]; then
    cd /root/calculator
    [ -f "app.js" ] && pm2 start app.js --name calculator-app
    [ -f "simpleHttpServer.js" ] && pm2 start simpleHttpServer.js --name http-server
    pm2 save
    pm2 startup systemd -u root --hp /root | bash
    echo "✓ 应用部署完成"
else
    echo "⚠️  应用目录不存在，跳过应用部署"
fi

# 5. 安装 Nginx
echo "[5/7] 安装 Nginx..."
yum install -y epel-release
yum install -y nginx

# 配置 Nginx
cat > /etc/nginx/conf.d/nodejs.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

systemctl start nginx
systemctl enable nginx
echo "✓ Nginx 安装完成"

# 6. 安装 MongoDB
echo "[6/7] 安装 MongoDB..."
cat > /etc/yum.repos.d/mongodb-org-4.4.repo << 'EOF'
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF

yum install -y mongodb-org

# 配置 MongoDB
mkdir -p /data/db
chown -R mongod:mongod /data/db
mkdir -p /var/log/mongodb
chown -R mongod:mongod /var/log/mongodb

cat > /etc/mongod.conf << 'EOF'
net:
  port: 27017
  bindIp: 127.0.0.1

storage:
  dbPath: /data/db
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

security:
  authorization: enabled
EOF

systemctl start mongod
systemctl enable mongod

# 创建 MongoDB 用户
sleep 3
mongo admin --eval 'db.createUser({user: "admin", pwd: "admin123", roles: ["userAdminAnyDatabase", "dbAdminAnyDatabase", "readWriteAnyDatabase"]})' 2>/dev/null || true
mongo price --eval 'db.createUser({user: "price", pwd: "Liuyuyi1989", roles: ["readWrite"]})' 2>/dev/null || true

echo "✓ MongoDB 安装完成"

# 7. 配置防火墙
echo "[7/7] 配置防火墙..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --zone=public --add-port=80/tcp --permanent
    firewall-cmd --zone=public --add-port=3000/tcp --permanent
    firewall-cmd --reload
    echo "✓ 防火墙配置完成"
elif command -v iptables &> /dev/null; then
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
    service iptables save
    echo "✓ 防火墙配置完成"
else
    echo "⚠️  未找到防火墙命令"
fi

echo ""
echo "=========================================="
echo "部署完成"
echo "=========================================="
echo ""
echo "服务状态:"
systemctl status mongod --no-pager | head -3
systemctl status nginx --no-pager | head -3
pm2 list
echo ""
echo "访问地址:"
echo "  Nginx: http://$(hostname -I | awk '{print $1}')"
echo "  应用: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "常用命令:"
echo "  pm2 list              # 查看进程"
echo "  pm2 logs              # 查看日志"
echo "  pm2 restart all       # 重启应用"
echo "  systemctl status nginx   # Nginx 状态"
echo "  systemctl status mongod # MongoDB 状态"
echo ""