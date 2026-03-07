# CentOS 7.9.2111-x64 自动启动配置指南

## 配置目标
- 系统重启时自动使用 nvm 选中 Node.js 14.21.3 版本
- 自动启动 pm2 管理指定的 JavaScript 文件

## 前提条件
1. 已安装 nvm (Node Version Manager)
2. 已安装 Node.js 14.21.3
3. 已安装 pm2
4. 已有需要启动的 JavaScript 文件

## 步骤 1: 创建启动脚本

将 `startup-nvm-pm2.sh` 文件上传到 CentOS 服务器的 `/root/` 目录：

```bash
# 上传文件到服务器后，赋予执行权限
chmod +x /root/startup-nvm-pm2.sh
```

**重要**: 修改 `startup-nvm-pm2.sh` 中的 JavaScript 文件名：
```bash
# 将 'your-app.js' 替换为实际的 JavaScript 文件名
pm2 start your-app.js
```

## 步骤 2: 创建 systemd 服务文件

将 `pm2-nvm.service` 文件上传到 `/etc/systemd/system/` 目录：

```bash
# 上传文件到服务器后，重新加载 systemd
systemctl daemon-reload
```

## 步骤 3: 启用并启动服务

```bash
# 启用服务（开机自启）
systemctl enable pm2-nvm.service

# 启动服务（立即启动）
systemctl start pm2-nvm.service

# 查看服务状态
systemctl status pm2-nvm.service
```

## 步骤 4: 验证配置

```bash
# 检查 Node.js 版本
node -v
# 应该显示: v14.21.3

# 检查 pm2 进程
pm2 list
# 应该显示你的应用程序正在运行

# 查看服务日志
journalctl -u pm2-nvm.service -f
```

## 步骤 5: 测试重启

```bash
# 重启系统
reboot

# 重启后验证
systemctl status pm2-nvm.service
pm2 list
node -v
```

## 故障排查

### 1. 服务启动失败
```bash
# 查看详细日志
journalctl -u pm2-nvm.service -n 50 --no-pager

# 检查脚本权限
ls -la /root/startup-nvm-pm2.sh
```

### 2. Node.js 版本不正确
```bash
# 手动执行启动脚本测试
/root/startup-nvm-pm2.sh

# 检查 nvm 安装路径
ls -la ~/.nvm/
```

### 3. pm2 无法启动应用
```bash
# 手动测试 pm2 启动
nvm use 14.21.3
pm2 start your-app.js
pm2 logs
```

### 4. 权限问题
```bash
# 确保服务用户有正确的权限
chown root:root /root/startup-nvm-pm2.sh
chmod +x /root/startup-nvm-pm2.sh
```

## 替代方案：使用 crontab

如果 systemd 服务有问题，可以使用 crontab：

```bash
# 编辑 root 用户的 crontab
crontab -e

# 添加以下行（在 @reboot 时执行）
@reboot /root/startup-nvm-pm2.sh

# 保存并退出
```

## 注意事项

1. **路径问题**: 确保 nvm 安装路径正确，默认是 `~/.nvm`
2. **用户权限**: 如果使用非 root 用户，需要修改服务文件中的 `User=` 字段
3. **工作目录**: 根据实际应用位置修改 `WorkingDirectory=`
4. **环境变量**: 如果应用需要特定的环境变量，在服务文件中添加 `Environment=` 行

## 自定义配置

### 修改服务文件中的用户
如果使用非 root 用户：
```ini
[Service]
Type=forking
User=your-username  # 修改为你的用户名
WorkingDirectory=/home/your-username
ExecStart=/home/your-username/startup-nvm-pm2.sh
```

### 添加环境变量
```ini
[Service]
Type=forking
User=root
WorkingDirectory=/root
Environment="NODE_ENV=production"
Environment="PORT=3000"
ExecStart=/root/startup-nvm-pm2.sh
```

### 修改启动脚本中的应用路径
```bash
# 如果应用不在 root 目录，修改为完整路径
pm2 start /path/to/your/app.js
```

## 验证清单

- [ ] nvm 已安装并可以使用
- [ ] Node.js 14.21.3 已安装
- [ ] pm2 已全局安装
- [ ] 启动脚本已上传并赋予执行权限
- [ ] systemd 服务文件已上传到正确位置
- [ ] 服务已启用并启动成功
- [ ] 手动测试重启后应用正常运行
- [ ] Node.js 版本正确为 14.21.3