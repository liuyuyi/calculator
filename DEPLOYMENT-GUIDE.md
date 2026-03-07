# 自动化部署脚本使用说明

## 概述

本项目提供了两个自动化部署脚本，用于在 CentOS 服务器上快速部署 Node.js 应用、PM2、Nginx 和 MongoDB。

### 脚本文件

1. **auto-deploy.sh** - 完整版部署脚本（推荐）
   - 包含详细的错误处理和状态验证
   - 生成详细的部署报告
   - 适合生产环境使用

2. **quick-deploy.sh** - 快速版部署脚本
   - 简化版，快速部署
   - 适合测试和开发环境

## 系统要求

- 操作系统：CentOS 7/8/Stream 8/Stream 9
- 权限：root 用户或具有 sudo 权限
- 内存：至少 2GB（推荐 4GB+）
- 磁盘：至少 20GB 可用空间
- 网络：能够访问外网（下载软件包）

## 部署内容

### 1. NVM (Node Version Manager)
- 安装 NVM v0.39.0
- 配置环境变量

### 2. Node.js 14.21.3
- 通过 NVM 安装 Node.js 14.21.3
- 设置为默认版本
- 兼容 CentOS 7

### 3. PM2 进程管理器
- 全局安装 PM2
- 部署应用：
  - app.js（calculator-app）
  - simpleHttpServer.js（http-server）
- 配置开机自启动

### 4. Nginx 反向代理
- 安装 Nginx
- 配置反向代理到 3000 端口
- 配置开机自启动

### 5. MongoDB 数据库
- 安装 MongoDB 4.4
- 配置数据目录和日志
- 创建数据库用户：
  - admin（管理员）
  - price（应用用户）
- 配置开机自启动

### 6. 防火墙配置
- 开放 80 端口（HTTP）
- 开放 3000 端口（应用）
- 支持 firewalld 和 iptables

## 使用方法

### 方法一：使用完整版脚本（推荐）

```bash
# 1. 上传脚本到服务器
scp auto-deploy.sh root@your-server:/root/

# 2. 连接到服务器
ssh root@your-server

# 3. 赋予执行权限
chmod +x /root/auto-deploy.sh

# 4. 执行部署脚本
/root/auto-deploy.sh

# 5. 查看部署报告
cat /root/deployment-report.txt
```

### 方法二：使用快速版脚本

```bash
# 1. 上传脚本到服务器
scp quick-deploy.sh root@your-server:/root/

# 2. 连接到服务器
ssh root@your-server

# 3. 赋予执行权限
chmod +x /root/quick-deploy.sh

# 4. 执行部署脚本
/root/quick-deploy.sh
```

### 方法三：直接下载执行

```bash
# 下载并执行完整版脚本
curl -fsSL https://your-server/auto-deploy.sh -o /root/auto-deploy.sh
chmod +x /root/auto-deploy.sh
/root/auto-deploy.sh

# 下载并执行快速版脚本
curl -fsSL https://your-server/quick-deploy.sh -o /root/quick-deploy.sh
chmod +x /root/quick-deploy.sh
/root/quick-deploy.sh
```

## 部署前准备

### 1. 准备应用文件

确保应用文件已上传到服务器的 `/root/calculator` 目录：

```bash
# 创建应用目录
mkdir -p /root/calculator

# 上传应用文件
scp app.js root@your-server:/root/calculator/
scp simpleHttpServer.js root@your-server:/root/calculator/
scp package.json root@your-server:/root/calculator/
# 上传其他必要的文件...
```

### 2. 安装依赖（如果需要）

```bash
cd /root/calculator
npm install
```

### 3. 配置数据库连接

确保数据库配置正确：

```javascript
// db/mongooseDb.js
var DB_URL = 'mongodb://price:Liuyuyi1989@localhost:27017/price';
```

## 部署流程

### 完整版脚本流程

1. **系统环境检查**
   - 操作系统版本
   - 系统架构
   - 内存和磁盘空间
   - root 权限验证

2. **安装 NVM**
   - 下载并安装 NVM
   - 配置环境变量
   - 验证安装

3. **安装 Node.js 14.21.3**
   - 通过 NVM 安装
   - 设置为默认版本
   - 验证版本

4. **安装 PM2**
   - 全局安装 PM2
   - 验证安装

5. **部署应用**
   - 启动 app.js
   - 启动 simpleHttpServer.js
   - 保存 PM2 进程列表
   - 配置开机自启动

6. **安装 Nginx**
   - 安装 EPEL 仓库
   - 安装 Nginx
   - 配置反向代理
   - 启动并设置开机自启动

7. **配置防火墙**
   - 开放 HTTP 端口（80）
   - 开放应用端口（3000）
   - 重载防火墙规则

8. **安装 MongoDB**
   - 配置 MongoDB 仓库
   - 安装 MongoDB
   - 配置数据目录和日志
   - 启动并设置开机自启动

9. **配置 MongoDB**
   - 创建配置文件
   - 启动服务
   - 创建数据库用户

10. **验证部署**
    - 验证所有组件安装
    - 验证服务状态
    - 验证端口监听
    - 测试访问

11. **生成部署报告**
    - 记录部署结果
    - 生成访问地址
    - 提供常用命令

## 部署后验证

### 1. 检查服务状态

```bash
# 检查 MongoDB
systemctl status mongod

# 检查 Nginx
systemctl status nginx

# 检查 PM2 进程
pm2 list
```

### 2. 检查端口监听

```bash
# 检查所有端口
ss -tlnp

# 检查特定端口
ss -tlnp | grep 27017  # MongoDB
ss -tlnp | grep 3000   # 应用
ss -tlnp | grep 80     # Nginx
```

### 3. 测试访问

```bash
# 测试 Nginx
curl http://localhost

# 测试应用
curl http://localhost:3000

# 测试 MongoDB
mongo --eval 'db.version()'
```

### 4. 查看日志

```bash
# PM2 日志
pm2 logs

# Nginx 日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# MongoDB 日志
tail -f /var/log/mongodb/mongod.log
```

## 常用命令

### PM2 管理

```bash
pm2 list              # 查看进程列表
pm2 logs              # 查看日志
pm2 monit             # 实时监控
pm2 restart all       # 重启所有应用
pm2 restart calculator-app  # 重启指定应用
pm2 stop all          # 停止所有应用
pm2 delete all         # 删除所有应用
pm2 save              # 保存进程列表
pm2 startup           # 配置开机自启
```

### Nginx 管理

```bash
systemctl status nginx    # 查看状态
systemctl start nginx     # 启动服务
systemctl stop nginx      # 停止服务
systemctl restart nginx   # 重启服务
systemctl reload nginx    # 重载配置
nginx -t                  # 测试配置
```

### MongoDB 管理

```bash
systemctl status mongod   # 查看状态
systemctl start mongod    # 启动服务
systemctl stop mongod     # 停止服务
systemctl restart mongod  # 重启服务
mongo                     # 连接数据库
mongo price               # 连接到 price 数据库
```

### 防火墙管理

```bash
# firewalld
firewall-cmd --list-all                    # 查看规则
firewall-cmd --zone=public --add-port=80/tcp --permanent  # 添加端口
firewall-cmd --reload                      # 重载规则

# iptables
iptables -L -n                             # 查看规则
iptables -I INPUT -p tcp --dport 80 -j ACCEPT  # 添加规则
service iptables save                      # 保存规则
```

## 故障排查

### 问题 1：NVM 安装失败

```bash
# 检查网络连接
ping raw.githubusercontent.com

# 手动下载安装脚本
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh > /tmp/nvm-install.sh
bash /tmp/nvm-install.sh
```

### 问题 2：Node.js 安装失败

```bash
# 检查 NVM 是否正确加载
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 手动安装
nvm install 14.21.3
```

### 问题 3：PM2 应用启动失败

```bash
# 查看详细日志
pm2 logs calculator-app --lines 100

# 检查应用文件
ls -la /root/calculator/

# 手动测试
cd /root/calculator
node app.js
```

### 问题 4：Nginx 启动失败

```bash
# 检查配置文件
nginx -t

# 查看错误日志
tail -f /var/log/nginx/error.log

# 检查端口占用
ss -tlnp | grep 80
```

### 问题 5：MongoDB 启动失败

```bash
# 检查数据目录权限
ls -la /data/db
chown -R mongod:mongod /data/db

# 检查日志目录权限
ls -la /var/log/mongodb
chown -R mongod:mongod /var/log/mongodb

# 查看错误日志
tail -f /var/log/mongodb/mongod.log

# 手动启动测试
mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log
```

### 问题 6：端口无法访问

```bash
# 检查防火墙规则
firewall-cmd --list-all
iptables -L -n

# 检查云服务商安全组
# 需要在云服务商控制台开放相应端口

# 检查 SELinux
getenforce
# 如果是 Enforcing，临时设置为 Permissive
setenforce 0
```

## 安全建议

### 1. 修改默认密码

```bash
# 修改 MongoDB 管理员密码
mongo admin
> db.changeUserPassword("admin", "your_new_password")

# 修改应用数据库密码
mongo price
> db.changeUserPassword("price", "your_new_password")
```

### 2. 配置 SSL/TLS

```bash
# 为 Nginx 配置 SSL
# 1. 获取 SSL 证书（Let's Encrypt）
yum install -y certbot python2-certbot-nginx
certbot --nginx

# 2. 修改 Nginx 配置
cat > /etc/nginx/conf.d/nodejs.conf << 'EOF'
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

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

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
EOF

systemctl reload nginx
```

### 3. 限制 MongoDB 远程访问

```bash
# 修改 MongoDB 配置，只允许本地访问
cat > /etc/mongod.conf << 'EOF'
net:
  port: 27017
  bindIp: 127.0.0.1  # 只允许本地访问
EOF

systemctl restart mongod
```

### 4. 配置 fail2ban

```bash
# 安装 fail2ban
yum install -y epel-release
yum install -y fail2ban

# 创建配置
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF

systemctl start fail2ban
systemctl enable fail2ban
```

## 备份策略

### 1. MongoDB 数据备份

```bash
# 创建备份脚本
cat > /root/backup-mongodb.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/mongodb"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

mongodump --db price --out $BACKUP_DIR/backup_$DATE
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz $BACKUP_DIR/backup_$DATE
rm -rf $BACKUP_DIR/backup_$DATE

# 保留最近 7 天的备份
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete
EOF

chmod +x /root/backup-mongodb.sh

# 添加定时任务
crontab -e
# 添加以下行（每天凌晨 2 点备份）
0 2 * * * /root/backup-mongodb.sh
```

### 2. 应用文件备份

```bash
# 创建备份脚本
cat > /root/backup-app.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/app"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

tar -czf $BACKUP_DIR/calculator_$DATE.tar.gz /root/calculator

# 保留最近 7 天的备份
find $BACKUP_DIR -name "calculator_*.tar.gz" -mtime +7 -delete
EOF

chmod +x /root/backup-app.sh

# 添加定时任务
crontab -e
# 添加以下行（每天凌晨 3 点备份）
0 3 * * * /root/backup-app.sh
```

## 监控建议

### 1. 系统监控

```bash
# 安装监控工具
yum install -y htop iotop

# 查看系统资源
htop
iotop
```

### 2. PM2 监控

```bash
# 安装 PM2 监控模块
pm2 install pm2-logrotate

# 配置日志轮转
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
```

### 3. Nginx 监控

```bash
# 安装 Nginx 状态模块
cat > /etc/nginx/conf.d/status.conf << 'EOF'
server {
    listen 127.0.0.1:8080;
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

systemctl reload nginx

# 查看状态
curl http://127.0.0.1:8080/nginx_status
```

## 更新升级

### 1. 更新 Node.js 版本

```bash
# 加载 NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 安装新版本
nvm install 16.20.0

# 切换到新版本
nvm use 16.20.0

# 设置为默认
nvm alias default 16.20.0

# 重启应用
pm2 restart all
```

### 2. 更新应用代码

```bash
# 拉取最新代码
cd /root/calculator
git pull

# 安装依赖
npm install

# 重启应用
pm2 restart all
```

### 3. 更新 MongoDB

```bash
# 备份数据
mongodump --db price --out /backup/mongodb/backup_$(date +%Y%m%d)

# 停止服务
systemctl stop mongod

# 更新软件
yum update mongodb-org

# 启动服务
systemctl start mongod

# 验证数据
mongo price --eval 'db.version()'
```

## 联系支持

如果遇到问题，请查看：
1. 部署报告：`/root/deployment-report.txt`
2. 服务日志：`/var/log/` 目录
3. PM2 日志：`pm2 logs`

## 许可证

本脚本仅供学习和个人使用。

## 更新日志

### v1.0.0 (2026-03-07)
- 初始版本发布
- 支持 CentOS 7/8/Stream 8/Stream 9
- 自动化部署 NVM、Node.js、PM2、Nginx、MongoDB
- 完整的错误处理和状态验证
- 生成详细的部署报告