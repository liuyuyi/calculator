#!/bin/bash

# Nginx 独立部署脚本
# 用于在内存受限的环境中单独部署 Nginx

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "=========================================="
echo "Nginx 独立部署脚本"
echo "=========================================="
echo ""

# ============================================
# 步骤 1: 检查内存
# ============================================
log_info "步骤 1: 检查内存状态"
echo "----------------------------------------"

AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')

log_info "可用内存: ${AVAILABLE_MEM}MB"
log_info "当前 Swap: ${TOTAL_SWAP}MB"

# 显示当前内存状态
free -h

echo ""

# ============================================
# 步骤 2: 创建 Swap（如果需要）
# ============================================
log_info "步骤 2: 创建 Swap（如果需要）"
echo "----------------------------------------"

if [ $AVAILABLE_MEM -lt 512 ] && [ $TOTAL_SWAP -eq 0 ]; then
    log_warning "内存不足，正在创建 2GB swap 文件..."
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    log_info "可用磁盘空间: ${DISK_SPACE}GB"
    
    if [ $DISK_SPACE -lt 2 ]; then
        log_error "错误: 磁盘空间不足，至少需要 2GB"
        exit 1
    fi
    
    # 创建 swap 文件
    log_info "创建 2GB swap 文件..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
    
    # 设置权限
    log_info "设置权限..."
    chmod 600 /swapfile
    
    # 创建 swap
    log_info "创建 swap..."
    mkswap /swapfile
    
    # 启用 swap
    log_info "启用 swap..."
    swapon /swapfile
    
    # 添加到 fstab（开机自动挂载）
    log_info "配置开机自动挂载..."
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # 优化 swap 使用
    log_info "优化 swap 使用策略..."
    sysctl vm.swappiness=10
    if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
    fi
    
    log_success "Swap 文件创建完成"
    
    # 显示新的内存状态
    echo ""
    log_info "新的内存状态:"
    free -h
    echo ""
    
    # 验证 swap
    if swapon --show | grep -q '/swapfile'; then
        log_success "Swap 已成功启用"
    else
        log_error "Swap 启用失败"
        exit 1
    fi
else
    log_info "内存充足或已有 swap，跳过 swap 创建"
fi

echo ""

# ============================================
# 步骤 3: 停止不必要的服务
# ============================================
log_info "步骤 3: 停止不必要的服务"
echo "----------------------------------------"

# 记录需要停止的服务
STOPPED_SERVICES=()

# 停止并记录服务
stop_and_record_service() {
    local service_name=$1
    if systemctl is-active --quiet $service_name 2>/dev/null; then
        log_info "停止服务: $service_name"
        systemctl stop $service_name
        STOPPED_SERVICES+=("$service_name")
        log_success "已停止: $service_name"
    else
        log_info "服务未运行: $service_name"
    fi
}

# 停止可能占用内存的服务
stop_and_record_service "yum-updatesd"
stop_and_record_service "packagekit"
stop_and_record_service "abrt-ccpp"
stop_and_record_service "abrt-oops"
stop_and_record_service "abrt-xorg"
stop_and_record_service "auditd"
stop_and_record_service "chronyd"
stop_and_record_service "crond"
stop_and_record_service "dbus"
stop_and_record_service "rsyslog"

# 显示已停止的服务
if [ ${#STOPPED_SERVICES[@]} -gt 0 ]; then
    log_info "已停止 ${#STOPPED_SERVICES[@]} 个服务"
    echo "  停止的服务列表:"
    for service in "${STOPPED_SERVICES[@]}"; do
        echo "    - $service"
    done
else
    log_info "没有需要停止的服务"
fi

echo ""

# ============================================
# 步骤 4: 清理和优化
# ============================================
log_info "步骤 4: 清理和优化系统"
echo "----------------------------------------"

# 清理 yum 缓存
log_info "清理 yum 缓存..."
yum clean all

# 清理系统缓存
log_info "清理系统缓存..."
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
echo 2 > /proc/sys/vm/drop_caches 2>/dev/null || true
echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true

# 清理临时文件
log_info "清理临时文件..."
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/tmp/* 2>/dev/null || true

# 清理日志文件（保留最近 100 行）
log_info "清理日志文件..."
find /var/log -type f -name "*.log" -exec sh -c 'tail -n 100 "$1" > "$1.tmp" && mv "$1.tmp" "$1"' _ {} \; 2>/dev/null || true

log_success "系统清理完成"

# 显示内存状态
echo ""
log_info "清理后的内存状态:"
free -h

echo ""

# ============================================
# 步骤 4: 安装 EPEL 仓库
# ============================================
log_info "步骤 4: 安装 EPEL 仓库"
echo "----------------------------------------"

if rpm -q epel-release &> /dev/null; then
    log_info "EPEL 仓库已安装"
else
    log_info "正在安装 EPEL 仓库..."
    yum install -y epel-release --setopt=install_weak_deps=False --setopt=tsflags=nodocs
    
    if [ $? -eq 0 ]; then
        log_success "EPEL 仓库安装成功"
    else
        log_error "EPEL 仓库安装失败"
        exit 1
    fi
fi

echo ""

# ============================================
# 步骤 5: 安装 Nginx
# ============================================
log_info "步骤 5: 安装 Nginx"
echo "----------------------------------------"

# 检查 Nginx 是否已安装
if command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1 | grep -oP 'nginx/[0-9.]*')
    log_warning "Nginx 已安装，版本: $NGINX_VERSION"
else
    log_info "正在安装 Nginx..."
    
    # 方法 1: 标准安装
    log_info "尝试方法 1: 标准安装..."
    yum install -y nginx --setopt=install_weak_deps=False --setopt=tsflags=nodocs
    
    if [ $? -ne 0 ]; then
        log_warning "标准安装失败，尝试方法 2..."
        
        # 方法 2: 跳过 GPG 检查
        log_info "尝试方法 2: 跳过 GPG 检查..."
        yum install -y --nogpgcheck nginx --setopt=install_weak_deps=False --setopt=tsflags=nodocs
        
        if [ $? -ne 0 ]; then
            log_warning "方法 2 失败，尝试方法 3..."
            
            # 方法 3: 手动下载安装
            log_info "尝试方法 3: 手动下载安装..."
            cd /tmp
            wget http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
            rpm -ivh nginx-release-centos-7-0.el7.ngx.noarch.rpm
            yum install -y nginx --setopt=install_weak_deps=False --setopt=tsflags=nodocs
            cd -
            
            if [ $? -ne 0 ]; then
                log_error "所有安装方法都失败了"
                log_error "请检查以下内容:"
                log_error "  1. 内存是否充足"
                log_error "  2. 磁盘空间是否充足"
                log_error "  3. 网络连接是否正常"
                log_error "  4. yum 仓库是否可用"
                exit 1
            fi
        fi
    fi
    
    NGINX_VERSION=$(nginx -v 2>&1 | grep -oP 'nginx/[0-9.]*')
    log_success "Nginx 安装成功，版本: $NGINX_VERSION"
fi

echo ""

# ============================================
# 步骤 6: 配置 Nginx
# ============================================
log_info "步骤 6: 配置 Nginx"
echo "----------------------------------------"

# 备份原配置
if [ -f /etc/nginx/nginx.conf ]; then
    log_info "备份原配置文件..."
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d_%H%M%S)
fi

# 创建应用反向代理配置
log_info "创建应用反向代理配置..."
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

# 测试 Nginx 配置
log_info "测试 Nginx 配置..."
if nginx -t; then
    log_success "Nginx 配置测试通过"
else
    log_error "Nginx 配置测试失败"
    log_info "正在恢复备份配置..."
    if [ -f /etc/nginx/nginx.conf.bak.* ]; then
        LATEST_BACKUP=$(ls -t /etc/nginx/nginx.conf.bak.* | head -1)
        cp $LATEST_BACKUP /etc/nginx/nginx.conf
        log_info "已恢复配置: $LATEST_BACKUP"
    fi
    exit 1
fi

echo ""

# ============================================
# 步骤 7: 启动 Nginx
# ============================================
log_info "步骤 7: 启动 Nginx"
echo "----------------------------------------"

# 停止旧服务（如果运行）
if systemctl is-active --quiet nginx; then
    log_info "停止旧 Nginx 服务..."
    systemctl stop nginx
fi

# 启动 Nginx
log_info "启动 Nginx 服务..."
systemctl start nginx

if systemctl is-active --quiet nginx; then
    log_success "Nginx 服务启动成功"
else
    log_error "Nginx 服务启动失败"
    log_info "查看错误日志:"
    tail -n 20 /var/log/nginx/error.log
    exit 1
fi

# 设置开机自启
log_info "设置开机自启..."
systemctl enable nginx

log_success "Nginx 开机自启已配置"

echo ""

# ============================================
# 步骤 7.5: 重新启动之前停止的服务
# ============================================
log_info "步骤 7.5: 重新启动之前停止的服务"
echo "----------------------------------------"

# 重新启动服务
restart_stopped_services() {
    local service_name=$1
    if systemctl is-enabled $service_name 2>/dev/null | grep -q "enabled"; then
        log_info "重新启动服务: $service_name"
        systemctl start $service_name
        if systemctl is-active --quiet $service_name 2>/dev/null; then
            log_success "已重新启动: $service_name"
        else
            log_warning "重新启动失败: $service_name"
        fi
    fi
}

# 重新启动之前停止的服务
if [ ${#STOPPED_SERVICES[@]} -gt 0 ]; then
    log_info "重新启动 ${#STOPPED_SERVICES[@]} 个服务..."
    echo "  重新启动的服务列表:"
    for service in "${STOPPED_SERVICES[@]}"; do
        restart_stopped_services "$service"
    done
    log_success "服务重新启动完成"
else
    log_info "没有需要重新启动的服务"
fi

# 显示内存状态
echo ""
log_info "服务重新启动后的内存状态:"
free -h

echo ""

# ============================================
# 步骤 9: 配置防火墙
# ============================================
log_info "步骤 9: 配置防火墙"
echo "----------------------------------------"

# 检查防火墙类型
if command -v firewall-cmd &> /dev/null; then
    log_info "使用 firewalld 配置防火墙"
    
    # 开放 HTTP 端口
    firewall-cmd --zone=public --add-port=80/tcp --permanent
    firewall-cmd --zone=public --add-port=443/tcp --permanent
    
    # 重载防火墙
    firewall-cmd --reload
    
    log_success "防火墙规则已添加"
    log_info "已开放端口: 80, 443"
    
elif command -v iptables &> /dev/null; then
    log_info "使用 iptables 配置防火墙"
    
    # 开放 HTTP 端口
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    
    # 保存规则
    service iptables save
    
    log_success "防火墙规则已添加"
    log_info "已开放端口: 80, 443"
    
    # 显示规则
    log_info "当前 iptables 规则:"
    iptables -L -n | grep -E '80|443'
else
    log_warning "未找到防火墙命令，跳过防火墙配置"
    log_info "请手动配置防火墙开放端口: 80, 443"
fi

echo ""

# ============================================
# 步骤 10: 验证安装
# ============================================
log_info "步骤 10: 验证安装"
echo "----------------------------------------"

# 验证 Nginx 版本
log_info "Nginx 版本:"
nginx -v

# 验证服务状态
log_info "Nginx 服务状态:"
systemctl status nginx --no-pager | head -10

# 验证端口监听
log_info "端口监听状态:"
ss -tlnp | grep nginx || netstat -tlnp | grep nginx

# 测试本地访问
log_info "测试本地访问..."
if curl -I http://localhost &> /dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost)
    log_success "Nginx 本地访问成功 (HTTP $HTTP_CODE)"
else
    log_error "Nginx 本地访问失败"
    log_info "查看错误日志:"
    tail -n 20 /var/log/nginx/error.log
fi

echo ""

# ============================================
# 步骤 11: 生成报告
# ============================================
log_info "步骤 11: 生成部署报告"
echo "----------------------------------------"

# 获取服务器信息
SERVER_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

# 生成报告
cat > /root/nginx-deployment-report.txt << EOF
==========================================
Nginx 部署报告
==========================================

部署时间: $(date)
服务器信息:
  主机名: $HOSTNAME
  IP地址: $SERVER_IP

==========================================
安装信息
==========================================

Nginx 版本: $(nginx -v 2>&1)
服务状态: $(systemctl is-active nginx)
开机自启: $(systemctl is-enabled nginx)

==========================================
配置信息
==========================================

配置文件: /etc/nginx/nginx.conf
应用配置: /etc/nginx/conf.d/nodejs.conf
日志目录: /var/log/nginx/
网站根目录: /usr/share/nginx/html

==========================================
端口状态
==========================================

HTTP 端口 (80): $(ss -tlnp | grep -q ':80' && echo '监听中' || echo '未监听')
HTTPS 端口 (443): $(ss -tlnp | grep -q ':443' && echo '监听中' || echo '未监听')

==========================================
访问地址
==========================================

Nginx 反向代理: http://$SERVER_IP
Nginx 直接访问: http://$SERVER_IP:80

==========================================
常用命令
==========================================

Nginx 管理:
  systemctl status nginx    # 查看状态
  systemctl start nginx     # 启动服务
  systemctl stop nginx      # 停止服务
  systemctl restart nginx   # 重启服务
  systemctl reload nginx    # 重载配置
  nginx -t                # 测试配置

日志查看:
  tail -f /var/log/nginx/access.log  # 访问日志
  tail -f /var/log/nginx/error.log   # 错误日志

配置管理:
  vi /etc/nginx/nginx.conf           # 主配置
  vi /etc/nginx/conf.d/nodejs.conf   # 应用配置
  nginx -t                            # 测试配置
  systemctl reload nginx                # 重载配置

==========================================
注意事项
==========================================

1. 确保防火墙和云服务商安全组已开放端口 80 和 443
2. 定期检查 Nginx 日志
3. 监控服务器资源使用情况
4. 配置 SSL/TLS 证书以提高安全性
5. 定期备份 Nginx 配置文件

==========================================
部署完成
==========================================
EOF

# 显示报告
cat /root/nginx-deployment-report.txt

echo ""
log_success "部署报告已生成: /root/nginx-deployment-report.txt"
echo ""

# ============================================
# 最终总结
# ============================================
echo "=========================================="
echo "部署摘要"
echo "=========================================="
echo ""
echo "✓ Nginx 安装成功"
echo "✓ Nginx 配置完成"
echo "✓ Nginx 服务已启动"
echo "✓ 防火墙规则已配置"
echo "✓ 部署报告已生成"
echo ""
echo "访问地址:"
echo "  http://$SERVER_IP"
echo ""
echo "=========================================="
echo "部署完成！"
echo "=========================================="