# PM2 NVM 服务启动失败修复指南

## 错误信息

```
ExecStart=/root/startup-nvm-pm2-fixed.sh (code=exited, status=203/EXEC)
```

**错误码 203/EXEC** 表示 systemd 无法执行启动脚本。

## 快速修复步骤

### 方法一：使用诊断脚本（推荐）

```bash
# 1. 上传 diagnose-pm2-service.sh 到服务器
chmod +x diagnose-pm2-service.sh

# 2. 运行诊断脚本
./diagnose-pm2-service.sh

# 3. 查看诊断结果并按照提示操作
```

### 方法二：手动修复

#### 步骤 1: 检查脚本权限

```bash
# 查看当前权限
ls -la /root/startup-nvm-pm2-fixed.sh

# 如果没有执行权限，添加执行权限
chmod +x /root/startup-nvm-pm2-fixed.sh

# 验证权限
ls -la /root/startup-nvm-pm2-fixed.sh
# 应该显示 -rwxr-xr-x 或类似的执行权限
```

#### 步骤 2: 检查并修复换行符

```bash
# 检查文件格式
file /root/startup-nvm-pm2-fixed.sh

# 如果显示 "with CRLF line terminators"，需要转换为 LF
# 方法 1: 使用 dos2unix（如果已安装）
dos2unix /root/startup-nvm-pm2-fixed.sh

# 方法 2: 使用 sed 转换
sed -i 's/\r$//' /root/startup-nvm-pm2-fixed.sh

# 验证转换
file /root/startup-nvm-pm2-fixed.sh
# 应该显示 "with LF line terminators"
```

#### 步骤 3: 检查 shebang 行

```bash
# 查看第一行
head -1 /root/startup-nvm-pm2-fixed.sh

# 应该显示: #!/bin/bash
# 如果不是，修复它
sed -i '1s/^.*$/#!\/bin\/bash/' /root/startup-nvm-pm2-fixed.sh

# 验证
head -1 /root/startup-nvm-pm2-fixed.sh
```

#### 步骤 4: 验证 bash 路径

```bash
# 检查 bash 是否存在
which bash

# 应该显示: /bin/bash
# 如果显示其他路径（如 /usr/bin/bash），需要更新 shebang 行
BASH_PATH=$(which bash)
sed -i "1s|#!/bin/bash|#!$BASH_PATH|" /root/startup-nvm-pm2-fixed.sh
```

#### 步骤 5: 手动测试脚本

```bash
# 直接执行脚本测试
/root/startup-nvm-pm2-fixed.sh

# 检查执行结果
echo "返回码: $?"

# 查看日志
cat /var/log/pm2-nvm-startup.log
```

#### 步骤 6: 重新加载 systemd 并重启服务

```bash
# 重新加载 systemd 配置
systemctl daemon-reload

# 重启服务
systemctl restart pm2-nvm.service

# 等待 2-3 秒
sleep 3

# 检查服务状态
systemctl status pm2-nvm.service
```

## 常见问题和解决方案

### 问题 1: 权限被拒绝

**错误信息**: `Permission denied`

**解决方案**:
```bash
chmod +x /root/startup-nvm-pm2-fixed.sh
chmod 755 /root/startup-nvm-pm2-fixed.sh
```

### 问题 2: 换行符问题

**错误信息**: 文件显示为 `with CRLF line terminators`

**解决方案**:
```bash
# 安装 dos2unix
yum install -y dos2unix

# 转换文件
dos2unix /root/startup-nvm-pm2-fixed.sh
```

### 问题 3: bash 路径错误

**错误信息**: `/bin/bash: bad interpreter`

**解决方案**:
```bash
# 查找正确的 bash 路径
which bash

# 更新 shebang 行
sed -i "1s|#!/bin/bash|#!$(which bash)|" /root/startup-nvm-pm2-fixed.sh
```

### 问题 4: 脚本内容错误

**错误信息**: 脚本执行后返回非零状态码

**解决方案**:
```bash
# 查看详细日志
cat /var/log/pm2-nvm-startup.log

# 手动执行脚本查看错误
bash -x /root/startup-nvm-pm2-fixed.sh
```

## 验证修复

### 检查服务状态

```bash
# 查看服务状态
systemctl status pm2-nvm.service

# 应该显示:
# Active: active (running)
```

### 查看 systemd 日志

```bash
# 查看最近的日志
journalctl -u pm2-nvm.service -n 50 --no-pager

# 实时查看日志
journalctl -u pm2-nvm.service -f
```

### 检查 PM2 进程

```bash
# 查看 PM2 进程列表
pm2 list

# 应该显示你的应用正在运行
```

### 检查 Node.js 版本

```bash
# 检查 Node.js 版本
node -v

# 应该显示: v14.21.3
```

## 完整修复脚本

如果上述步骤都试过了还是不行，使用这个完整修复脚本：

```bash
#!/bin/bash

# 完整修复脚本

echo "开始修复 PM2 NVM 服务..."

# 1. 修复权限
chmod +x /root/startup-nvm-pm2-fixed.sh
chmod 755 /root/startup-nvm-pm2-fixed.sh
echo "✓ 权限已修复"

# 2. 修复换行符
sed -i 's/\r$//' /root/startup-nvm-pm2-fixed.sh
echo "✓ 换行符已修复"

# 3. 修复 shebang 行
sed -i '1s/^.*$/#!\/bin\/bash/' /root/startup-nvm-pm2-fixed.sh
echo "✓ shebang 行已修复"

# 4. 重新加载 systemd
systemctl daemon-reload
echo "✓ systemd 已重新加载"

# 5. 重启服务
systemctl restart pm2-nvm.service
echo "✓ 服务已重启"

# 6. 等待服务启动
sleep 3

# 7. 检查状态
systemctl status pm2-nvm.service --no-pager

echo ""
echo "修复完成！"
```

## 如果还是失败

如果以上方法都尝试了还是失败，请检查：

1. **文件是否完整上传**
   ```bash
   wc -l /root/startup-nvm-pm2-fixed.sh
   # 应该有 80+ 行
   ```

2. **文件内容是否正确**
   ```bash
   head -20 /root/startup-nvm-pm2-fixed.sh
   # 查看前 20 行内容
   ```

3. **查看完整的错误日志**
   ```bash
   journalctl -u pm2-nvm.service -n 100 --no-pager
   ```

4. **尝试直接运行脚本**
   ```bash
   bash /root/startup-nvm-pm2-fixed.sh
   ```

5. **检查系统日志**
   ```bash
   dmesg | tail -50
   ```

## 预防措施

为了避免将来出现同样的问题：

1. **在 Windows 上编辑文件时，使用支持 Unix 换行符的编辑器**
   - VS Code: 设置 `files.eol` 为 `\n`
   - Notepad++: 编辑 → EOL 转换 → Unix (LF)

2. **上传文件后立即检查格式**
   ```bash
   file your-file.sh
   ```

3. **始终设置正确的权限**
   ```bash
   chmod +x your-script.sh
   ```

4. **测试脚本后再配置为服务**
   ```bash
   ./your-script.sh
   # 确保脚本能正常执行
   ```