# CentOS 7.9.2111-x64 NVM + PM2 自动启动配置

## 方案一：使用 systemd 服务（推荐）

### 1. 上传文件到 CentOS 服务器

```bash
# 上传以下文件到服务器：
# - setup-centos-pm2.sh (自动配置脚本)
# - startup-nvm-pm2.sh (启动脚本)
# - pm2-nvm.service (systemd 服务文件)
```

### 2. 运行自动配置脚本

```bash
# 赋予执行权限
chmod +x setup-centos-pm2.sh

# 运行配置脚本
./setup-centos-pm2.sh

# 按照提示输入你的 JavaScript 文件名
```

### 3. 验证配置

```bash
# 检查服务状态
systemctl status pm2-nvm.service

# 查看服务日志
journalctl -u pm2-nvm.service -f

# 检查 pm2 进程
pm2 list

# 检查 Node.js 版本
node -v
```

### 4. 测试重启

```bash
reboot

# 重启后验证
systemctl status pm2-nvm.service
pm2 list
```

---

## 方案二：使用 crontab（备选方案）

### 1. 创建启动脚本

```bash
# 创建启动脚本
cat > /root/startup-nvm-pm2.sh << 'EOF'
#!/bin/bash

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 使用 Node.js 14.21.3
nvm use 14.21.3

# 启动 pm2 应用（替换为你的文件名）
pm2 start your-app.js

# 保存 pm2 进程列表
pm2 save
EOF

# 赋予执行权限
chmod +x /root/startup-nvm-pm2.sh
```

### 2. 添加到 crontab

```bash
# 编辑 root 用户的 crontab
crontab -e

# 添加以下行（在 @reboot 时执行）
@reboot /root/startup-nvm-pm2.sh

# 保存并退出
```

### 3. 验证配置

```bash
# 查看当前用户的 crontab
crontab -l

# 手动测试启动脚本
/root/startup-nvm-pm2.sh

# 检查 pm2 进程
pm2 list
```

---

## 方案三：修改 bash 配置文件

### 1. 修改 ~/.bashrc

```bash
# 编辑 ~/.bashrc
vim ~/.bashrc

# 在文件末尾添加以下内容：
# NVM 配置
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 自动使用 Node.js 14.21.3
nvm use 14.21.3

# 启动 pm2 应用（如果未运行）
if ! pm2 list | grep -q "online"; then
    pm2 start your-app.js
    pm2 save
fi

# 保存并退出
```

### 2. 使配置生效

```bash
source ~/.bashrc
```

### 3. 验证配置

```bash
# 检查 Node.js 版本
node -v

# 检查 pm2 进程
pm2 list
```

---

## 手动配置步骤（如果自动脚本失败）

### 1. 检查 nvm 安装

```bash
# 检查 nvm 是否安装
ls -la ~/.nvm/

# 如果未安装，安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# 重新加载 bash 配置
source ~/.bashrc
```

### 2. 安装 Node.js 14.21.3

```bash
# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 安装 Node.js 14.21.3
nvm install 14.21.3

# 设置为默认版本
nvm alias default 14.21.3

# 验证安装
node -v
```

### 3. 安装 pm2

```bash
# 使用 Node.js 14.21.3
nvm use 14.21.3

# 全局安装 pm2
npm install -g pm2

# 验证安装
pm2 -v
```

### 4. 创建启动脚本

```bash
# 创建启动脚本
cat > /root/startup-nvm-pm2.sh << 'EOF'
#!/bin/bash

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 使用 Node.js 14.21.3
nvm use 14.21.3

# 启动 pm2 应用（替换为你的文件名）
pm2 start your-app.js

# 保存 pm2 进程列表
pm2 save
EOF

# 赋予执行权限
chmod +x /root/startup-nvm-pm2.sh
```

### 5. 创建 systemd 服务

```bash
# 创建 systemd 服务文件
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

# 重新加载 systemd
systemctl daemon-reload

# 启用服务
systemctl enable pm2-nvm.service

# 启动服务
systemctl start pm2-nvm.service

# 查看服务状态
systemctl status pm2-nvm.service
```

---

## 常见问题解决

### 1. nvm 命令找不到

```bash
# 确保加载了 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 或者重新安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
```

### 2. Node.js 版本不正确

```bash
# 手动设置默认版本
nvm alias default 14.21.3

# 验证默认版本
nvm alias default
```

### 3. pm2 无法启动应用

```bash
# 手动测试启动
nvm use 14.21.3
pm2 start your-app.js
pm2 logs

# 检查应用文件路径和权限
ls -la your-app.js
```

### 4. systemd 服务启动失败

```bash
# 查看详细日志
journalctl -u pm2-nvm.service -n 50 --no-pager

# 检查脚本权限
ls -la /root/startup-nvm-pm2.sh

# 手动测试启动脚本
/root/startup-nvm-pm2.sh
```

### 5. 权限问题

```bash
# 确保文件有正确的权限
chmod +x /root/startup-nvm-pm2.sh
chown root:root /root/startup-nvm-pm2.sh

# 确保服务文件有正确的权限
chmod 644 /etc/systemd/system/pm2-nvm.service
```

---

## 验证清单

- [ ] nvm 已安装并可以使用
- [ ] Node.js 14.21.3 已安装
- [ ] pm2 已全局安装
- [ ] 启动脚本已创建并赋予执行权限
- [ ] systemd 服务已创建并启用
- [ ] 服务状态为 active (running)
- [ ] pm2 进程列表显示应用正在运行
- [ ] Node.js 版本正确为 v14.21.3
- [ ] 重启后应用自动启动

---

## 快速命令参考

```bash
# 查看服务状态
systemctl status pm2-nvm.service

# 重启服务
systemctl restart pm2-nvm.service

# 停止服务
systemctl stop pm2-nvm.service

# 查看服务日志
journalctl -u pm2-nvm.service -f

# 查看 pm2 进程
pm2 list

# 查看 pm2 日志
pm2 logs

# 重启 pm2 应用
pm2 restart all

# 停止 pm2 应用
pm2 stop all

# 删除 pm2 应用
pm2 delete all
```