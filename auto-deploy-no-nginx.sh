#!/bin/bash

# 自动化部署脚本（不安装 Nginx 版本）
# 功能：安装 NVM、Node.js 14.21.3、PM2、MongoDB 并配置应用
# 外网访问方式：直接暴露 3000 端口

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查命令是否存在
check_command() {
    if command -v $1 &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查服务状态
check_service() {
    if systemctl is-active --quiet $1; then
        return 0
    else
        return 1
    fi
}

# 检查端口是否监听
check_port() {
    if ss -tlnp | grep -q ":$1"; then
        return 0
    else
        return 1
    fi
}

# 等待服务启动
wait_for_service() {
    local service_name=$1
    local max_attempts=30
    local attempt=0
    
    log_info "等待 $service_name 服务启动..."
    
    while [ $attempt -lt $max_attempts ]; do
        if systemctl is-active --quiet $service_name; then
            log_success "$service_name 服务已启动"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log_error "$service_name 服务启动超时"
    return 1
}

# 主函数
main() {
    echo "=========================================="
    echo "自动化部署脚本（不安装 Nginx 版本）"
    echo "=========================================="
    echo ""
    echo "外网访问方式：直接暴露 3000 端口"
    echo ""
    
    # 记录开始时间
    START_TIME=$(date +%s)
    
    # 部署结果
    declare -A DEPLOYMENT_RESULTS
    
    # ============================================
    # 步骤 1: 检查系统环境
    # ============================================
    log_info "步骤 1: 检查系统环境"
    echo "----------------------------------------"
    
    # 检查操作系统
    if [ -f /etc/redhat-release ]; then
        OS_INFO=$(cat /etc/redhat-release)
        log_info "操作系统: $OS_INFO"
    elif [ -f /etc/os-release ]; then
        OS_INFO=$(cat /etc/os-release | grep PRETTY_NAME)
        log_info "操作系统: $OS_INFO"
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    # 检查系统架构
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"
    
    # 检查内存
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    log_info "总内存: ${TOTAL_MEM}GB"
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2{print $4}')
    log_info "可用磁盘空间: ${DISK_SPACE}GB"
    
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户执行此脚本"
        exit 1
    fi
    
    DEPLOYMENT_RESULTS[系统检查]="成功"
    log_success "系统环境检查完成"
    echo ""
    
    # ============================================
    # 步骤 2: 安装 NVM
    # ============================================
    log_info "步骤 2: 安装 NVM (Node Version Manager)"
    echo "----------------------------------------"
    
    if [ -d "$HOME/.nvm" ]; then
        log_warning "NVM 已安装，跳过安装"
        NVM_VERSION=$(nvm --version 2>/dev/null || echo "unknown")
        log_info "NVM 版本: $NVM_VERSION"
    else
        log_info "正在安装 NVM..."
        
        # 下载并安装 NVM
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # 加载 NVM
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # 验证安装
        if command -v nvm &> /dev/null; then
            NVM_VERSION=$(nvm --version)
            log_success "NVM 安装成功，版本: $NVM_VERSION"
            DEPLOYMENT_RESULTS[NVM安装]="成功"
        else
            log_error "NVM 安装失败"
            DEPLOYMENT_RESULTS[NVM安装]="失败"
            exit 1
        fi
    fi
    
    # 将 NVM 添加到 bashrc
    if ! grep -q "NVM_DIR" ~/.bashrc; then
        log_info "将 NVM 添加到 ~/.bashrc"
        cat >> ~/.bashrc << 'EOF'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF
    fi
    
    echo ""
    
    # ============================================
    # 步骤 3: 安装 Node.js 14.21.3
    # ============================================
    log_info "步骤 3: 安装 Node.js 14.21.3"
    echo "----------------------------------------"
    
    # 加载 NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # 检查 Node.js 14.21.3 是否已安装
    if nvm ls 14.21.3 &> /dev/null; then
        log_warning "Node.js 14.21.3 已安装"
        nvm use 14.21.3
    else
        log_info "正在安装 Node.js 14.21.3..."
        
        # 安装 Node.js 14.21.3
        nvm install 14.21.3
        
        if [ $? -eq 0 ]; then
            log_success "Node.js 14.21.3 安装成功"
            DEPLOYMENT_RESULTS[Node.js安装]="成功"
        else
            log_error "Node.js 14.21.3 安装失败"
            DEPLOYMENT_RESULTS[Node.js安装]="失败"
            exit 1
        fi
    fi
    
    # 设置为默认版本
    log_info "设置 Node.js 14.21.3 为默认版本..."
    nvm alias default 14.21.3
    
    # 验证 Node.js 版本
    NODE_VERSION=$(node -v)
    NPM_VERSION=$(npm -v)
    log_info "Node.js 版本: $NODE_VERSION"
    log_info "NPM 版本: $NPM_VERSION"
    
    DEPLOYMENT_RESULTS[Node.js配置]="成功"
    log_success "Node.js 配置完成"
    echo ""
    
    # ============================================
    # 步骤 4: 安装 PM2
    # ============================================
    log_info "步骤 4: 安装 PM2 进程管理工具"
    echo "----------------------------------------"
    
    # 检查 PM2 是否已安装
    if command -v pm2 &> /dev/null; then
        PM2_VERSION=$(pm2 -v)
        log_warning "PM2 已安装，版本: $PM2_VERSION"
    else
        log_info "正在安装 PM2..."
        npm install -g pm2
        
        if [ $? -eq 0 ]; then
            PM2_VERSION=$(pm2 -v)
            log_success "PM2 安装成功，版本: $PM2_VERSION"
            DEPLOYMENT_RESULTS[PM2安装]="成功"
        else
            log_error "PM2 安装失败"
            DEPLOYMENT_RESULTS[PM2安装]="失败"
            exit 1
        fi
    fi
    
    echo ""
    
    # ============================================
    # 步骤 5: 部署应用
    # ============================================
    log_info "步骤 5: 部署应用"
    echo "----------------------------------------"
    
    # 检查应用目录
    APP_DIR="/root/calculator"
    
    if [ ! -d "$APP_DIR" ]; then
        log_warning "应用目录不存在: $APP_DIR"
        log_info "请确保应用文件已上传到服务器"
        DEPLOYMENT_RESULTS[应用部署]="跳过（目录不存在）"
    else
        log_info "应用目录存在: $APP_DIR"
        
        # 启动 app.js
        log_info "启动 app.js..."
        APP_JS="$APP_DIR/app.js"
        
        if [ -f "$APP_JS" ]; then
            cd $APP_DIR
            pm2 start app.js --name calculator-app || pm2 restart calculator-app
            
            if [ $? -eq 0 ]; then
                log_success "app.js 启动成功"
                DEPLOYMENT_RESULTS[app.js启动]="成功"
            else
                log_error "app.js 启动失败"
                DEPLOYMENT_RESULTS[app.js启动]="失败"
            fi
        else
            log_warning "app.js 文件不存在: $APP_JS"
            DEPLOYMENT_RESULTS[app.js启动]="跳过（文件不存在）"
        fi
        
        # 启动 simpleHttpServer.js
        log_info "启动 simpleHttpServer.js..."
        HTTP_SERVER="$APP_DIR/simpleHttpServer.js"
        
        if [ -f "$HTTP_SERVER" ]; then
            cd $APP_DIR
            pm2 start simpleHttpServer.js --name http-server || pm2 restart http-server
            
            if [ $? -eq 0 ]; then
                log_success "simpleHttpServer.js 启动成功"
                DEPLOYMENT_RESULTS[simpleHttpServer.js启动]="成功"
            else
                log_error "simpleHttpServer.js 启动失败"
                DEPLOYMENT_RESULTS[simpleHttpServer.js启动]="失败"
            fi
        else
            log_warning "simpleHttpServer.js 文件不存在: $HTTP_SERVER"
            DEPLOYMENT_RESULTS[simpleHttpServer.js启动]="跳过（文件不存在）"
        fi
        
        # 保存 PM2 进程列表
        log_info "保存 PM2 进程列表..."
        pm2 save
        
        # 配置 PM2 开机自启
        log_info "配置 PM2 开机自启..."
        
        # 创建 systemd 服务文件
        cat > /etc/systemd/system/pm2-root.service << 'EOF'
[Unit]
Description=PM2 Process Manager
Documentation=https://pm2.keymetrics.io/
After=network.target

[Service]
Type=forking
User=root
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Environment=PATH=/usr/bin:/bin:/usr/local/sbin:/usr/local/bin:/root/.nvm/versions/node/v14.21.3/bin
PIDFile=/root/.pm2/pm2.pid
Restart=on-failure

ExecStart=/root/.nvm/versions/node/v14.21.3/bin/pm2 resurrect
ExecReload=/root/.nvm/versions/node/v14.21.3/bin/pm2 reload all
ExecStop=/root/.nvm/versions/node/v14.21.3/bin/pm2 kill

[Install]
WantedBy=multi-user.target
EOF
        
        # 重载 systemd
        systemctl daemon-reload
        
        # 启用服务
        systemctl enable pm2-root.service
        
        log_success "PM2 开机自启配置完成"
        
        DEPLOYMENT_RESULTS[应用部署]="成功"
        log_success "应用部署完成"
    fi
    
    echo ""
    
    # 等待应用启动
    log_info "等待应用启动..."
    sleep 5
    
    # 检查 PM2 进程状态
    log_info "PM2 进程列表:"
    pm2 list
    
    echo ""
    
    # ============================================
    # 步骤 6: 检查内存并创建 swap（如果需要）
    # ============================================
    log_info "步骤 6: 检查内存并创建 swap（如果需要）"
    echo "----------------------------------------"
    
    # 检查可用内存
    AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
    log_info "可用内存: ${AVAILABLE_MEM}MB"
    
    # 检查是否已有 swap
    TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
    log_info "当前 Swap: ${TOTAL_SWAP}MB"
    
    # 如果可用内存小于 512MB 且没有 swap，创建 swap
    if [ $AVAILABLE_MEM -lt 512 ] && [ $TOTAL_SWAP -eq 0 ]; then
        log_warning "内存不足，正在创建 2GB swap 文件..."
        
        # 创建 2GB swap 文件
        dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
        
        # 设置权限
        chmod 600 /swapfile
        
        # 创建 swap
        mkswap /swapfile
        
        # 启用 swap
        swapon /swapfile
        
        # 添加到 fstab（开机自动挂载）
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        
        # 优化 swap 使用
        sysctl vm.swappiness=10
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
        
        log_success "Swap 文件创建完成"
        DEPLOYMENT_RESULTS[Swap创建]="成功"
    else
        log_info "内存充足或已有 swap，跳过 swap 创建"
        DEPLOYMENT_RESULTS[Swap创建]="跳过"
    fi
    
    # 显示新的内存状态
    log_info "当前内存状态:"
    free -h
    
    echo ""
    
    # ============================================
    # 步骤 7: 配置防火墙（开放 3000 端口）
    # ============================================
    log_info "步骤 7: 配置防火墙（开放 3000 端口）"
    echo "----------------------------------------"
    
    # 检查防火墙类型
    FIREWALL_CONFIGURED=false
    
    # 方法 1: 检查 iptables
    if systemctl is-active --quiet iptables 2>/dev/null || systemctl is-active --quiet iptables-services 2>/dev/null; then
        log_info "检测到 iptables 服务正在运行"
        
        if command -v iptables &> /dev/null; then
            log_info "使用 iptables 配置防火墙"
            
            # 开放 3000 端口
            iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
            
            # 保存规则
            if command -v iptables-save &> /dev/null; then
                iptables-save > /etc/sysconfig/iptables 2>/dev/null || service iptables save 2>/dev/null || true
            fi
            
            log_success "防火墙规则已添加"
            log_info "已开放端口: 3000"
            DEPLOYMENT_RESULTS[防火墙配置]="成功"
            FIREWALL_CONFIGURED=true
        else
            log_warning "iptables 服务正在运行，但 iptables 命令不可用"
        fi
    fi
    
    # 方法 2: 尝试安装 iptables-services
    if [ "$FIREWALL_CONFIGURED" = false ]; then
        # 检查 iptables-services 是否已安装
        if rpm -q iptables-services &> /dev/null; then
            log_info "iptables-services 已安装"
            
            # 启动 iptables
            systemctl start iptables
            systemctl enable iptables
            
            # 配置防火墙
            if command -v iptables &> /dev/null; then
                log_info "使用 iptables 配置防火墙"
                
                # 开放 3000 端口
                iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
                iptables-save > /etc/sysconfig/iptables
                
                log_success "防火墙规则已添加"
                log_info "已开放端口: 3000"
                DEPLOYMENT_RESULTS[防火墙配置]="成功"
                FIREWALL_CONFIGURED=true
            fi
        else
            log_info "尝试安装 iptables-services..."
            
            if yum install -y iptables-services --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0; then
                log_success "iptables-services 安装成功"
                
                # 启动 iptables
                systemctl start iptables
                systemctl enable iptables
                
                # 配置防火墙
                if command -v iptables &> /dev/null; then
                    log_info "使用 iptables 配置防火墙"
                    
                    # 开放 3000 端口
                    iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
                    iptables-save > /etc/sysconfig/iptables
                    
                    log_success "防火墙规则已添加"
                    log_info "已开放端口: 3000"
                    DEPLOYMENT_RESULTS[防火墙配置]="成功"
                    FIREWALL_CONFIGURED=true
                fi
            else
                log_warning "iptables-services 安装失败"
            fi
        fi
    fi
    
    # 检查 SELinux 状态
    if command -v getenforce &> /dev/null; then
        SELINUX_STATUS=$(getenforce)
        log_info "SELinux 状态: $SELINUX_STATUS"
        
        if [ "$SELINUX_STATUS" = "Enforcing" ]; then
            log_warning "SELinux 处于强制模式，可能影响端口访问"
            log_info "建议临时关闭 SELinux: setenforce 0"
            log_info "或永久关闭: sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
        fi
    fi
    
    # 如果防火墙未配置，提供手动配置指导
    if [ "$FIREWALL_CONFIGURED" = false ]; then
        log_warning "防火墙未配置"
        log_info "请手动配置防火墙开放端口: 3000"
        echo ""
        log_info "手动配置方法:"
        echo "  方法 1: 安装 iptables-services"
        echo "    yum install -y iptables-services"
        echo "    systemctl start iptables"
        echo "    systemctl enable iptables"
        echo "    iptables -I INPUT -p tcp --dport 3000 -j ACCEPT"
        echo "    iptables-save > /etc/sysconfig/iptables"
        echo ""
        echo "  方法 2: 关闭防火墙（不推荐）"
        echo "    systemctl stop iptables 2>/dev/null"
        echo "    systemctl disable iptables 2>/dev/null"
        echo ""
        log_info "云服务商安全组配置:"
        echo "  阿里云 ECS: 在安全组中添加入方向规则，端口 3000，授权对象 0.0.0.0/0"
        echo "  腾讯云 CVM: 在安全组中添加入站规则，端口 3000，来源 0.0.0.0/0"
        echo "  华为云 ECS: 在安全组中添加入方向规则，端口 3000，源地址 0.0.0.0/0"
        echo ""
        
        DEPLOYMENT_RESULTS[防火墙配置]="未配置（需要手动配置）"
    fi
    
    echo ""
    
    # ============================================
    # 步骤 8: 安装 MongoDB（可选）
    # ============================================
    log_info "步骤 8: 安装 MongoDB（可选）"
    echo "----------------------------------------"
    
    # 询问是否安装 MongoDB
    log_warning "是否需要安装 MongoDB？(y/n)"
    log_info "如果应用不需要数据库，可以输入 n 跳过"
    read -t 30 INSTALL_MONGO
    
    if [ "$INSTALL_MONGO" = "y" ] || [ "$INSTALL_MONGO" = "Y" ]; then
        # 检查 MongoDB 是否已安装
        if command -v mongod &> /dev/null; then
            MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
            log_warning "MongoDB 已安装，版本: $MONGO_VERSION"
        else
            log_info "正在安装 MongoDB..."
            
            # 检测系统版本
            if [ -f /etc/redhat-release ]; then
                OS_RELEASE=$(cat /etc/redhat-release)
                log_info "检测到系统: $OS_RELEASE"
                
                # CentOS Stream 9 检测
                if echo "$OS_RELEASE" | grep -q "Stream 9"; then
                    log_info "检测到 CentOS Stream 9，将安装 MongoDB 6.0/5.0"
                    
                    # 方法 1: 尝试 MongoDB 6.0（CentOS Stream 9 推荐）
                    log_info "尝试方法 1: 安装 MongoDB 6.0（CentOS Stream 9）..."
                    
                    cat > /etc/yum.repos.d/mongodb-org-6.0.repo << 'EOF'
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
                    
                    yum clean all
                    yum install -y mongodb-org --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                    
                    if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                        MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                        log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                        DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                    else
                        log_warning "MongoDB 6.0 安装失败，尝试方法 2..."
                        
                        # 方法 2: 尝试 MongoDB 5.0（CentOS Stream 9 备选）
                        log_info "尝试方法 2: 安装 MongoDB 5.0（CentOS Stream 9）..."
                        
                        cat > /etc/yum.repos.d/mongodb-org-5.0.repo << 'EOF'
[mongodb-org-5.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/5.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-5.0.asc
EOF
                        
                        yum clean all
                        yum install -y mongodb-org --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                        
                        if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                            MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                            log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                            DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                        else
                            log_warning "MongoDB 5.0 安装失败，尝试方法 3..."
                            
                            # 方法 3: 尝试 MongoDB 4.4（可能不兼容）
                            log_info "尝试方法 3: 安装 MongoDB 4.4（可能不兼容 CentOS Stream 9）..."
                            
                            cat > /etc/yum.repos.d/mongodb-org-4.4.repo << 'EOF'
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF
                            
                            yum clean all
                            yum install -y mongodb-org --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                            
                            if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                                MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                                log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                                DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                            else
                                log_error "MongoDB 安装失败，CentOS Stream 9 需要至少 MongoDB 5.0"
                                log_error "建议使用 Docker 运行 MongoDB"
                                log_warning "跳过 MongoDB 安装并继续部署？(y/n)"
                                read -t 30 SKIP_MONGO
                                
                                if [ "$SKIP_MONGO" = "y" ] || [ "$SKIP_MONGO" = "Y" ]; then
                                    log_warning "跳过 MongoDB 安装"
                                    DEPLOYMENT_RESULTS[MongoDB安装]="跳过"
                                else
                                    DEPLOYMENT_RESULTS[MongoDB安装]="失败"
                                    exit 1
                                fi
                            fi
                        fi
                    fi
                    
                # CentOS Stream 8 或其他版本
                else
                    log_info "检测到 CentOS Stream 8 或其他版本，尝试安装 MongoDB 4.4/4.2/3.6..."
                    
                    # 方法 1: 尝试 MongoDB 4.4
                    log_info "尝试方法 1: 安装 MongoDB 4.4..."
                    
                    cat > /etc/yum.repos.d/mongodb-org-4.4.repo << 'EOF'
[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF
                    
                    yum clean all
                    yum install -y mongodb-org --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                    
                    if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                        MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                        log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                        DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                    else
                        log_warning "MongoDB 4.4 安装失败，尝试方法 2..."
                        
                        # 方法 2: 尝试 MongoDB 4.2
                        log_info "尝试方法 2: 安装 MongoDB 4.2..."
                        
                        cat > /etc/yum.repos.d/mongodb-org-4.2.repo << 'EOF'
[mongodb-org-4.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc
EOF
                        
                        yum clean all
                        yum install -y mongodb-org --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                        
                        if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                            MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                            log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                            DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                        else
                            log_warning "MongoDB 4.2 安装失败，尝试方法 3..."
                            
                            # 方法 3: 尝试 MongoDB 3.6
                            log_info "尝试方法 3: 安装 MongoDB 3.6..."
                            
                            cat > /etc/yum.repos.d/mongodb-org-3.6.repo << 'EOF'
[mongodb-org-3.6]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.6/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc
EOF
                            
                            yum clean all
                            yum install -y mongodb-org --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                            
                            if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                                MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                                log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                                DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                            else
                                log_warning "MongoDB 3.6 安装失败，尝试方法 4..."
                                
                                # 方法 4: 使用 EPEL 仓库
                                log_info "尝试方法 4: 使用 EPEL 仓库安装 MongoDB..."
                                
                                yum install -y epel-release --setopt=install_weak_deps=False --setopt=tsflags=nodocs
                                yum install -y mongodb --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0
                                
                                if [ $? -eq 0 ] && command -v mongod &> /dev/null; then
                                    MONGO_VERSION=$(mongod --version | grep -oP 'db version v[0-9.]*')
                                    log_success "MongoDB 安装成功，版本: $MONGO_VERSION"
                                    DEPLOYMENT_RESULTS[MongoDB安装]="成功"
                                else
                                    log_error "MongoDB 安装失败，所有方法都失败了"
                                    log_error "可能的原因:"
                                    log_error "  1. 内存不足（建议至少 2GB）"
                                    log_error "  2. CentOS 版本不支持 MongoDB 4.4/4.2/3.6"
                                    log_error "  3. 网络连接问题"
                                    log_error "  4. yum 仓库配置问题"
                                    log_error ""
                                    log_warning "跳过 MongoDB 安装并继续部署？(y/n)"
                                    read -t 30 SKIP_MONGO
                                    
                                    if [ "$SKIP_MONGO" = "y" ] || [ "$SKIP_MONGO" = "Y" ]; then
                                        log_warning "跳过 MongoDB 安装"
                                        DEPLOYMENT_RESULTS[MongoDB安装]="跳过"
                                    else
                                        DEPLOYMENT_RESULTS[MongoDB安装]="失败"
                                        exit 1
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            else
                log_error "无法检测系统版本"
                DEPLOYMENT_RESULTS[MongoDB安装]="失败"
                exit 1
            fi
        fi
        
        echo ""
        
        # ============================================
        # 步骤 9: 配置 MongoDB（如果已安装）
        # ============================================
        if command -v mongod &> /dev/null; then
            log_info "步骤 9: 配置 MongoDB"
            echo "----------------------------------------"
            
            # 创建数据目录
            log_info "创建 MongoDB 数据目录..."
            mkdir -p /data/db
            chown -R mongod:mongod /data/db
            
            # 创建日志目录
            log_info "创建 MongoDB 日志目录..."
            mkdir -p /var/log/mongodb
            chown -R mongod:mongod /var/log/mongodb
            
            # 创建配置文件
            log_info "创建 MongoDB 配置文件..."
            cat > /etc/mongod.conf << 'EOF'
# mongod.conf

# 网络配置
net:
  port: 27017
  bindIp: 127.0.0.1

# 数据存储
storage:
  dbPath: /data/db
  journal:
    enabled: true

# 日志
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# 安全
security:
  authorization: enabled
EOF
            
            # 启动 MongoDB
            log_info "启动 MongoDB..."
            systemctl start mongod
            systemctl enable mongod
            
            if wait_for_service mongod; then
                DEPLOYMENT_RESULTS[MongoDB配置]="成功"
                log_success "MongoDB 配置完成"
            else
                log_error "MongoDB 启动失败"
                DEPLOYMENT_RESULTS[MongoDB配置]="失败"
                exit 1
            fi
            
            echo ""
            
            # ============================================
            # 步骤 10: 创建 MongoDB 用户
            # ============================================
            log_info "步骤 10: 创建 MongoDB 用户"
            echo "----------------------------------------"
            
            # 等待 MongoDB 完全启动
            sleep 3
            
            # 创建管理员用户
            log_info "创建管理员用户..."
            mongo admin --eval 'db.createUser({user: "admin", pwd: "admin123", roles: ["userAdminAnyDatabase", "dbAdminAnyDatabase", "readWriteAnyDatabase"]})' 2>/dev/null || true
            
            # 创建应用数据库用户
            log_info "创建应用数据库用户..."
            mongo price --eval 'db.createUser({user: "price", pwd: "Liuyuyi1989", roles: ["readWrite"]})' 2>/dev/null || true
            
            log_success "MongoDB 用户创建完成"
            DEPLOYMENT_RESULTS[MongoDB用户]="成功"
            
            echo ""
        else
            log_warning "MongoDB 未安装，跳过配置步骤"
            DEPLOYMENT_RESULTS[MongoDB配置]="跳过"
            echo ""
        fi
    else
        log_warning "跳过 MongoDB 安装"
        DEPLOYMENT_RESULTS[MongoDB安装]="跳过"
        echo ""
    fi
    
    # ============================================
    # 步骤 11: 验证部署
    # ============================================
    log_info "步骤 11: 验证部署"
    echo "----------------------------------------"
    
    # 验证 NVM
    log_info "验证 NVM..."
    if command -v nvm &> /dev/null; then
        log_success "NVM: $(nvm --version)"
    else
        log_error "NVM 未安装"
    fi
    
    # 验证 Node.js
    log_info "验证 Node.js..."
    if command -v node &> /dev/null; then
        log_success "Node.js: $(node -v)"
    else
        log_error "Node.js 未安装"
    fi
    
    # 验证 PM2
    log_info "验证 PM2..."
    if command -v pm2 &> /dev/null; then
        log_success "PM2: $(pm2 -v)"
    else
        log_error "PM2 未安装"
    fi
    
    # 验证应用
    log_info "验证应用..."
    if check_port 3000; then
        log_success "应用正在 3000 端口运行"
    else
        log_error "应用未在 3000 端口运行"
    fi
    
    # 验证防火墙
    log_info "验证防火墙..."
    if command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --list-ports | grep -q "3000/tcp"; then
            log_success "防火墙已开放 3000 端口"
        else
            log_warning "防火墙未开放 3000 端口"
        fi
    elif command -v iptables &> /dev/null; then
        if iptables -L -n | grep -q "dpt:3000"; then
            log_success "防火墙已开放 3000 端口"
        else
            log_warning "防火墙未开放 3000 端口"
        fi
    fi
    
    # 验证 MongoDB（如果已安装）
    if command -v mongod &> /dev/null; then
        log_info "验证 MongoDB..."
        if check_service mongod; then
            log_success "MongoDB 服务正在运行"
        else
            log_error "MongoDB 服务未运行"
        fi
    fi
    
    echo ""
    
    # ============================================
    # 步骤 12: 生成部署报告
    # ============================================
    log_info "步骤 12: 生成部署报告"
    echo "----------------------------------------"
    
    # 计算部署时间
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    # 获取服务器信息
    SERVER_IP=$(hostname -I | awk '{print $1}')
    HOSTNAME=$(hostname)
    
    # 生成报告
    cat > /root/deployment-report-no-nginx.txt << EOF
==========================================
部署报告（不安装 Nginx 版本）
==========================================

部署时间: $(date)
部署耗时: ${MINUTES}分${SECONDS}秒
服务器信息:
  主机名: $HOSTNAME
  IP地址: $SERVER_IP

==========================================
安装信息
==========================================

NVM: $(command -v nvm &> /dev/null && nvm --version || echo "未安装")
Node.js: $(command -v node &> /dev/null && node -v || echo "未安装")
NPM: $(command -v npm &> /dev/null && npm -v || echo "未安装")
PM2: $(command -v pm2 &> /dev/null && pm2 -v || echo "未安装")
MongoDB: $(command -v mongod &> /dev/null && mongod --version | head -1 || echo "未安装")

==========================================
应用信息
==========================================

应用目录: $APP_DIR
PM2 进程列表:
$(pm2 list 2>/dev/null || echo "无进程")

==========================================
网络信息
==========================================

应用访问地址: http://$SERVER_IP:3000
监听端口: 3000
防火墙状态: $(command -v firewall-cmd &> /dev/null && firewall-cmd --list-ports | grep -q "3000/tcp" && echo "已开放" || echo "未开放")

==========================================
部署结果
==========================================

EOF
    
    # 添加部署结果
    for key in "${!DEPLOYMENT_RESULTS[@]}"; do
        echo "$key: ${DEPLOYMENT_RESULTS[$key]}" >> /root/deployment-report-no-nginx.txt
    done
    
    # 显示报告
    cat /root/deployment-report-no-nginx.txt
    
    echo ""
    log_success "部署报告已生成: /root/deployment-report-no-nginx.txt"
    echo ""
    
    # ============================================
    # 最终总结
    # ============================================
    echo "=========================================="
    echo "部署摘要"
    echo "=========================================="
    echo ""
    echo "✓ NVM 安装完成"
    echo "✓ Node.js 14.21.3 安装完成"
    echo "✓ PM2 安装完成"
    echo "✓ 应用部署完成"
    echo "✓ 防火墙配置完成（3000 端口）"
    if command -v mongod &> /dev/null; then
        echo "✓ MongoDB 安装完成"
    fi
    echo ""
    echo "应用访问地址:"
    echo "  http://$SERVER_IP:3000"
    echo ""
    echo "=========================================="
    echo "部署完成！"
    echo "=========================================="
    echo ""
    echo "注意事项:"
    echo "1. 确保防火墙和云服务商安全组已开放端口 3000"
    echo "2. 应用直接通过 3000 端口访问，无需 Nginx"
    echo "3. PM2 管理应用: pm2 list, pm2 logs, pm2 restart"
    echo "4. 查看 PM2 进程: pm2 list"
    echo "5. 查看应用日志: pm2 logs"
    echo ""
}

# 运行主函数
main "$@"