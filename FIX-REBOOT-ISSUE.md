# CentOS 7.9.2111-x64 修复 Node.js 版本选择问题

## 问题描述
系统重启后，systemd 服务无法正确使用 nvm 选择 Node.js 14.21.3 版本。

## 解决方案

### 步骤 1: 设置 Node.js 14.21.3 为默认版本（关键步骤）

```bash
# 上传 set-default-nodejs.sh 到服务器
chmod +x set-default-nodejs.sh

# 运行脚本设置默认版本
./set-default-nodejs.sh
```

或者手动执行：

```bash
# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 设置 Node.js 14.21.3 为默认版本
nvm alias default 14.21.3

# 验证默认版本
nvm alias default
```

### 步骤 2: 上传修复后的文件

```bash
# 上传以下文件到服务器：
# - startup-nvm-pm2-fixed.sh (修复后的启动脚本)
# - pm2-nvm-fixed.service (修复后的 systemd 服务文件)
```

### 步骤 3: 修改启动脚本中的应用文件名

```bash
# 编辑启动脚本
vim /root/startup-nvm-pm2-fixed.sh

# 找到这一行并修改为你的实际文件名：
APP_FILE="/root/your-app.js"

# 例如，如果你的文件是 app.js，修改为：
APP_FILE="/root/app.js"

# 保存并退出
```

### 步骤 4: 赋予执行权限

```bash
chmod +x /root/startup-nvm-pm2-fixed.sh
```

### 步骤 5: 创建日志文件

```bash
# 创建日志文件并设置权限
touch /var/log/pm2-nvm-startup.log
chmod 644 /var/log/pm2-nvm-startup.log
```

### 步骤 6: 更新 systemd 服务

```bash
# 停止旧服务（如果存在）
systemctl stop pm2-nvm.service
systemctl disable pm2-nvm.service

# 上传新的服务文件
cp pm2-nvm-fixed.service /etc/systemd/system/pm2-nvm.service

# 重新加载 systemd
systemctl daemon-reload

# 启用新服务
systemctl enable pm2-nvm.service

# 启动服务
systemctl start pm2-nvm.service
```

### 步骤 7: 验证配置

```bash
# 查看服务状态
systemctl status pm2-nvm.service

# 查看启动日志
cat /var/log/pm2-nvm-startup.log

# 查看 systemd 日志
journalctl -u pm2-nvm.service -n 50 --no-pager

# 检查 Node.js 版本
node -v

# 检查 pm2 进程
pm2 list
```

### 步骤 8: 测试重启

```bash
# 重启系统
reboot

# 重启后验证
systemctl status pm2-nvm.service
cat /var/log/pm2-nvm-startup.log
node -v
pm2 list
```

---

## 修复说明

### 1. 修复了启动脚本 (startup-nvm-pm2-fixed.sh)

**改进点：**
- 添加了详细的日志记录
- 添加了错误检查和处理
- 添加了版本验证
- 添加了 pm2 进程状态记录

**关键改进：**
```bash
# 记录所有操作到日志文件
LOG_FILE="/var/log/pm2-nvm-startup.log"

# 检查 nvm 是否正确加载
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
    echo "NVM loaded successfully" >> $LOG_FILE
fi

# 验证 Node.js 版本
NODE_VERSION=$(node -v)
echo "Current Node.js version: $NODE_VERSION" >> $LOG_FILE
```

### 2. 修复了 systemd 服务 (pm2-nvm-fixed.service)

**改进点：**
- 添加了环境变量 HOME 和 NVM_DIR
- 添加了标准输出和错误输出配置
- 改进了重启策略

**关键改进：**
```ini
[Service]
Type=forking
User=root
Environment=HOME=/root          # 添加 HOME 环境变量
Environment=NVM_DIR=/root/.nvm   # 添加 NVM_DIR 环境变量
WorkingDirectory=/root
ExecStart=/root/startup-nvm-pm2-fixed.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal           # 标准输出到 journal
StandardError=journal            # 标准错误到 journal
```

### 3. 设置默认版本 (set-default-nodejs.sh)

**关键步骤：**
```bash
# 设置 Node.js 14.21.3 为默认版本
nvm alias default 14.21.3
```

这是解决重启后版本问题的关键步骤。设置默认版本后，每次打开新的 shell 会话时，nvm 都会自动使用 Node.js 14.21.3。

---

## 故障排查

### 1. 服务启动失败

```bash
# 查看详细日志
journalctl -u pm2-nvm-service -n 100 --no-pager

# 查看启动脚本日志
cat /var/log/pm2-nvm-startup.log

# 手动测试启动脚本
/root/startup-nvm-pm2-fixed.sh
```

### 2. Node.js 版本不正确

```bash
# 检查默认版本设置
nvm alias default

# 重新设置默认版本
nvm alias default 14.21.3

# 验证设置
source ~/.bashrc
node -v
```

### 3. pm2 无法启动应用

```bash
# 检查应用文件是否存在
ls -la /root/your-app.js

# 手动测试 pm2 启动
nvm use 14.21.3
pm2 start /root/your-app.js
pm2 logs
```

### 4. 日志文件权限问题

```bash
# 检查日志文件权限
ls -la /var/log/pm2-nvm-startup.log

# 修复权限
chmod 644 /var/log/pm2-nvm-startup.log
chown root:root /var/log/pm2-nvm-startup.log
```

### 5. nvm 路径问题

```bash
# 检查 nvm 安装路径
ls -la ~/.nvm/

# 如果 nvm 安装在其他位置，修改启动脚本中的 NVM_DIR
export NVM_DIR="/path/to/nvm"
```

---

## 验证清单

- [ ] Node.js 14.21.3 已设置为默认版本
- [ ] 启动脚本已上传并赋予执行权限
- [ ] 日志文件已创建并设置正确权限
- [ ] systemd 服务文件已更新并重新加载
- [ ] 服务状态为 active (running)
- [ ] 启动日志显示 Node.js 版本为 v14.21.3
- [ ] pm2 进程列表显示应用正在运行
- [ ] 重启后应用自动启动
- [ ] 重启后 Node.js 版本正确为 v14.21.3

---

## 关键要点

1. **必须设置默认版本**: 使用 `nvm alias default 14.21.3` 设置默认版本
2. **环境变量**: systemd 服务需要 HOME 和 NVM_DIR 环境变量
3. **日志记录**: 详细的日志有助于排查问题
4. **权限检查**: 确保所有文件都有正确的权限
5. **验证步骤**: 每一步都要验证，确保配置正确

---

## 常用命令

```bash
# 查看服务状态
systemctl status pm2-nvm.service

# 重启服务
systemctl restart pm2-nvm.service

# 停止服务
systemctl stop pm2-nvm.service

# 查看服务日志
journalctl -u pm2-nvm-service -f

# 查看启动脚本日志
tail -f /var/log/pm2-nvm-startup.log

# 查看 pm2 进程
pm2 list

# 查看 pm2 日志
pm2 logs

# 检查 Node.js 版本
node -v

# 检查默认版本
nvm alias default
```