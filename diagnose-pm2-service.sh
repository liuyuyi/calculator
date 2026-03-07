#!/bin/bash

# PM2 NVM 服务启动失败诊断和修复脚本

echo "=========================================="
echo "PM2 NVM 服务诊断工具"
echo "=========================================="

# 1. 检查脚本文件是否存在
echo ""
echo "1. 检查脚本文件..."
if [ ! -f "/root/startup-nvm-pm2-fixed.sh" ]; then
    echo "❌ 错误: 脚本文件不存在: /root/startup-nvm-pm2-fixed.sh"
    echo "请确保文件已上传到服务器"
    exit 1
else
    echo "✓ 脚本文件存在"
fi

# 2. 检查脚本权限
echo ""
echo "2. 检查脚本权限..."
PERMISSIONS=$(stat -c "%a" /root/startup-nvm-pm2-fixed.sh)
if [ "$PERMISSIONS" != "755" ] && [ "$PERMISSIONS" != "744" ] && [ "$PERMISSIONS" != "700" ]; then
    echo "⚠️  警告: 脚本权限为 $PERMISSIONS，应该为 755 或 744"
    echo "正在修复权限..."
    chmod +x /root/startup-nvm-pm2-fixed.sh
    echo "✓ 权限已修复"
else
    echo "✓ 脚本权限正确: $PERMISSIONS"
fi

# 3. 检查脚本格式（换行符）
echo ""
echo "3. 检查脚本格式..."
if file /root/startup-nvm-pm2-fixed.sh | grep -q "CRLF"; then
    echo "❌ 错误: 脚本使用 Windows 换行符 (CRLF)"
    echo "正在转换为 Unix 换行符 (LF)..."
    dos2unix /root/startup-nvm-pm2-fixed.sh 2>/dev/null || sed -i 's/\r$//' /root/startup-nvm-pm2-fixed.sh
    echo "✓ 格式已修复"
else
    echo "✓ 脚本格式正确 (LF)"
fi

# 4. 检查 shebang 行
echo ""
echo "4. 检查 shebang 行..."
SHEBANG=$(head -1 /root/startup-nvm-pm2-fixed.sh)
if [[ ! "$SHEBANG" =~ ^#!/bin/bash ]]; then
    echo "❌ 错误: shebang 行不正确: $SHEBANG"
    echo "正在修复 shebang 行..."
    sed -i '1s/^.*$/#!\/bin\/bash/' /root/startup-nvm-pm2-fixed.sh
    echo "✓ shebang 行已修复"
else
    echo "✓ shebang 行正确: $SHEBANG"
fi

# 5. 检查 bash 路径
echo ""
echo "5. 检查 bash 路径..."
if [ ! -x "/bin/bash" ]; then
    echo "❌ 错误: /bin/bash 不存在或不可执行"
    echo "正在查找 bash 路径..."
    BASH_PATH=$(which bash)
    if [ -n "$BASH_PATH" ]; then
        echo "找到 bash: $BASH_PATH"
        echo "正在更新 shebang 行..."
        sed -i "1s|#!/bin/bash|#!$BASH_PATH|" /root/startup-nvm-pm2-fixed.sh
        echo "✓ shebang 行已更新"
    else
        echo "❌ 错误: 无法找到 bash"
        exit 1
    fi
else
    echo "✓ bash 路径正确: /bin/bash"
fi

# 6. 手动测试脚本
echo ""
echo "6. 手动测试脚本..."
echo "正在执行脚本测试..."
/root/startup-nvm-pm2-fixed.sh
TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo "✓ 脚本执行成功"
else
    echo "❌ 脚本执行失败，返回码: $TEST_RESULT"
    echo "请查看日志: /var/log/pm2-nvm-startup.log"
fi

# 7. 检查日志文件
echo ""
echo "7. 检查日志文件..."
if [ -f "/var/log/pm2-nvm-startup.log" ]; then
    echo "✓ 日志文件存在"
    echo ""
    echo "最近的日志内容:"
    echo "----------------------------------------"
    tail -20 /var/log/pm2-nvm-startup.log
    echo "----------------------------------------"
else
    echo "⚠️  日志文件不存在，将在脚本执行时创建"
fi

# 8. 检查 systemd 服务文件
echo ""
echo "8. 检查 systemd 服务文件..."
if [ ! -f "/etc/systemd/system/pm2-nvm.service" ]; then
    echo "❌ 错误: systemd 服务文件不存在"
    echo "请上传 pm2-nvm-fixed.service 到 /etc/systemd/system/pm2-nvm.service"
    exit 1
else
    echo "✓ systemd 服务文件存在"
fi

# 9. 重新加载 systemd
echo ""
echo "9. 重新加载 systemd..."
systemctl daemon-reload
echo "✓ systemd 已重新加载"

# 10. 重启服务
echo ""
echo "10. 重启 pm2-nvm 服务..."
systemctl restart pm2-nvm.service
sleep 2

# 11. 检查服务状态
echo ""
echo "11. 检查服务状态..."
if systemctl is-active --quiet pm2-nvm.service; then
    echo "✓ 服务运行正常"
    echo ""
    echo "服务状态详情:"
    systemctl status pm2-nvm.service --no-pager
else
    echo "❌ 服务启动失败"
    echo ""
    echo "服务状态详情:"
    systemctl status pm2-nvm.service --no-pager
    echo ""
    echo "查看详细日志:"
    echo "  systemctl status pm2-nvm.service"
    echo "  journalctl -u pm2-nvm.service -n 50 --no-pager"
fi

echo ""
echo "=========================================="
echo "诊断完成"
echo "=========================================="