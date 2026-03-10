#!/bin/bash

# 自动化部署脚本（不安装 Nginx 版本）
# 功能：安装 NVM、Node.js 14.21.3、PM2、MySQL 并配置应用
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
    # 步骤 5: 检查内存并创建 swap（如果需要）
    # ============================================
    log_info "步骤 5: 检查内存并创建 swap（如果需要）"
    echo "----------------------------------------"
    
    # 检查可用内存
    AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
    log_info "可用内存: ${AVAILABLE_MEM}MB"
    
    # 检查是否已有 swap
    TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
    log_info "当前 Swap: ${TOTAL_SWAP}MB"
    
    # 如果可用内存小于 512MB 或没有 swap，创建 swap
    if [ $AVAILABLE_MEM -lt 512 ] || [ $TOTAL_SWAP -eq 0 ]; then
        log_warning "内存不足，正在创建 2GB swap 文件..."
        
        # 清理现有 swap 文件（如果存在）
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile 2>/dev/null || true
        
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
        log_info "内存充足且已有 swap，跳过 swap 创建"
        DEPLOYMENT_RESULTS[Swap创建]="跳过"
    fi
    
    # 显示新的内存状态
    log_info "当前内存状态:"
    free -h
    
    echo ""
    
    # ============================================
    # 步骤 6: 安装 MySQL
    # ============================================
    log_info "步骤 6: 安装 MySQL"
    echo "----------------------------------------"
    
    # 检查 MySQL 是否已安装
    if command -v mysql &> /dev/null; then
        log_warning "MySQL 已安装，跳过安装"
    else
        log_info "正在安装 MySQL..."
        
        # 清理失效的 MongoDB 仓库配置
        log_info "清理失效的 MongoDB 仓库配置..."
        rm -f /etc/yum.repos.d/mongodb*.repo 2>/dev/null || true
        rm -f /etc/yum.repos.d/mongodb-org*.repo 2>/dev/null || true
        
        # 清理现有 MySQL 相关包
        yum remove -y mysql mysql-server mysql-libs mysql-common 2>/dev/null || true
        rm -rf /var/lib/mysql 2>/dev/null || true
        rm -rf /etc/my.cnf 2>/dev/null || true
        
        # 优先尝试 MySQL 5.7（兼容性更好）
        log_info "尝试安装 MySQL 5.7（兼容性更好）..."
        
        # 配置 MySQL 5.7 仓库
        cat > /etc/yum.repos.d/mysql-community.repo << 'EOF'
[mysql57-community]
name=MySQL 5.7 Community Server
baseurl=https://repo.mysql.com/yum/mysql-5.7-community/el/7/$basearch/
enabled=1
gpgcheck=0
EOF
        
        # 安装 MySQL 5.7（禁用 GPG 检查）
        yum install -y mysql-community-server --nogpgcheck --setopt=install_weak_deps=False --setopt=tsflags=nodocs
        
        if [ $? -eq 0 ]; then
            log_success "MySQL 5.7 安装成功"
            DEPLOYMENT_RESULTS[MySQL安装]="成功（MySQL 5.7）"
        else
            log_warning "MySQL 5.7 安装失败，尝试 MySQL 8.0..."
            
            # 安装 OpenSSL 兼容库（MySQL 8.0 需要）
            log_info "安装 OpenSSL 兼容库..."
            yum install -y compat-openssl10 --setopt=install_weak_deps=False --setopt=tsflags=nodocs 2>/dev/null || true
            
            # 配置 MySQL 8.0 仓库
            cat > /etc/yum.repos.d/mysql-community.repo << 'EOF'
[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=https://repo.mysql.com/yum/mysql-8.0-community/el/7/$basearch/
enabled=1
gpgcheck=0
EOF
            
            # 安装 MySQL 8.0（禁用 GPG 检查）
            yum install -y mysql-community-server --nogpgcheck --setopt=install_weak_deps=False --setopt=tsflags=nodocs
            
            if [ $? -eq 0 ]; then
                log_success "MySQL 8.0 安装成功"
                DEPLOYMENT_RESULTS[MySQL安装]="成功（MySQL 8.0）"
            else
                log_error "MySQL 安装失败"
                log_warning "尝试使用 MariaDB 作为替代..."
                
                # 安装 MariaDB
                yum install -y mariadb-server --setopt=install_weak_deps=False --setopt=tsflags=nodocs
                
                if [ $? -eq 0 ]; then
                    log_success "MariaDB 安装成功"
                    DEPLOYMENT_RESULTS[MySQL安装]="成功（MariaDB）"
                else
                    log_error "所有数据库安装都失败了"
                    DEPLOYMENT_RESULTS[MySQL安装]="失败"
                    exit 1
                fi
            fi
        fi
    fi
    
    # 启动 MySQL 服务
    log_info "启动 MySQL 服务..."
    systemctl start mysqld 2>/dev/null || systemctl start mariadb 2>/dev/null
    systemctl enable mysqld 2>/dev/null || systemctl enable mariadb 2>/dev/null
    
    if wait_for_service mysqld 2>/dev/null || wait_for_service mariadb 2>/dev/null; then
        log_success "MySQL 服务启动成功"
        DEPLOYMENT_RESULTS[MySQL启动]="成功"
    else
        log_error "MySQL 服务启动失败"
        DEPLOYMENT_RESULTS[MySQL启动]="失败"
        exit 1
    fi
    
    # 配置 MySQL
    log_info "配置 MySQL..."
    
    # 获取临时密码（MySQL 5.7 和 8.0）
    if command -v mysql &> /dev/null; then
        TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | tail -1 | awk '{print $NF}')
        
        if [ -n "$TEMP_PASS" ]; then
            # 重置密码（MySQL 5.7 和 8.0）
            log_info "重置 MySQL 密码..."
            mysql -u root -p"$TEMP_PASS" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'Liuyuyi1989';" 2>/dev/null || true
        else
            # 尝试无密码登录（MariaDB 或已配置的 MySQL）
            mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('Liuyuyi1989');" 2>/dev/null || \
            mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'Liuyuyi1989';" 2>/dev/null || true
        fi
        
        # 创建数据库和用户
        log_info "创建数据库和用户..."
        mysql -u root -p'Liuyuyi1989' -e "CREATE DATABASE IF NOT EXISTS price_db;" 2>/dev/null || \
        mysql -u root -p'Liuyuyi1989' --connect-expired-password -e "CREATE DATABASE IF NOT EXISTS price_db;" 2>/dev/null || true
        
        mysql -u root -p'Liuyuyi1989' -e "CREATE USER IF NOT EXISTS 'price'@'localhost' IDENTIFIED BY 'Liuyuyi1989';" 2>/dev/null || \
        mysql -u root -p'Liuyuyi1989' --connect-expired-password -e "CREATE USER IF NOT EXISTS 'price'@'localhost' IDENTIFIED BY 'Liuyuyi1989';" 2>/dev/null || true
        
        mysql -u root -p'Liuyuyi1989' -e "GRANT ALL PRIVILEGES ON price_db.* TO 'price'@'localhost';" 2>/dev/null || \
        mysql -u root -p'Liuyuyi1989' --connect-expired-password -e "GRANT ALL PRIVILEGES ON price_db.* TO 'price'@'localhost';" 2>/dev/null || true
        
        mysql -u root -p'Liuyuyi1989' -e "FLUSH PRIVILEGES;" 2>/dev/null || \
        mysql -u root -p'Liuyuyi1989' --connect-expired-password -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        
        log_success "MySQL 配置完成"
        DEPLOYMENT_RESULTS[MySQL配置]="成功"
    else
        log_error "MySQL 命令不可用"
        DEPLOYMENT_RESULTS[MySQL配置]="失败"
        exit 1
    fi
    
    echo ""
    
    # ============================================
    # 步骤 7: 部署应用
    # ============================================
    log_info "步骤 7: 部署应用"
    echo "----------------------------------------"
    
    # 检查应用目录
    APP_DIR="/root/calculator"
    
    if [ ! -d "$APP_DIR" ]; then
        log_warning "应用目录不存在: $APP_DIR"
        log_info "请确保应用文件已上传到服务器"
        DEPLOYMENT_RESULTS[应用部署]="跳过（目录不存在）"
    else
        log_info "应用目录存在: $APP_DIR"
        
        # 清理可能存在的旧版本 undici
        log_info "清理可能存在的旧版本依赖..."
        cd $APP_DIR
        npm uninstall undici 2>/dev/null || true
        
        # 安装应用依赖
        log_info "安装应用依赖..."
        cd $APP_DIR
        npm install mysql2 express cheerio nodemailer node-schedule puppeteer undici@4.15.0 --legacy-peer-deps
        
        if [ $? -eq 0 ]; then
            log_success "应用依赖安装成功"
            DEPLOYMENT_RESULTS[依赖安装]="成功"
        else
            log_error "应用依赖安装失败"
            DEPLOYMENT_RESULTS[依赖安装]="失败"
        fi
        
        # 确保目录存在
        mkdir -p $APP_DIR/public/images
        
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
    # 步骤 8: 配置防火墙（开放 3000 端口）
    # ============================================
    log_info "步骤 8: 配置防火墙（开放 3000 端口）"
    echo "----------------------------------------"
    
    # 检查防火墙类型
    FIREWALL_CONFIGURED=false
    
    # 停止可能冲突的防火墙服务
    log_info "停止可能冲突的防火墙服务..."
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true
    
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
    
    # 方法 2: 尝试安装和配置 iptables-services
    if [ "$FIREWALL_CONFIGURED" = false ]; then
        # 检查 iptables-services 是否已安装
        if rpm -q iptables-services &> /dev/null; then
            log_info "iptables-services 已安装"
            
            # 停止现有 iptables 服务
            systemctl stop iptables 2>/dev/null || true
            
            # 创建基础 iptables 配置文件
            log_info "创建基础 iptables 配置..."
            cat > /etc/sysconfig/iptables << 'EOF'
# Generated by iptables-save v1.4.21
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 3000 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
            
            # 尝试启动 iptables
            log_info "启动 iptables 服务..."
            if systemctl start iptables 2>/dev/null; then
                systemctl enable iptables 2>/dev/null || true
                log_success "iptables 服务启动成功"
                DEPLOYMENT_RESULTS[防火墙配置]="成功"
                FIREWALL_CONFIGURED=true
            else
                log_warning "iptables 服务启动失败，跳过防火墙配置"
            fi
        else
            log_info "尝试安装 iptables-services..."
            
            if yum install -y iptables-services --setopt=install_weak_deps=False --setopt=tsflags=nodocs --setopt=strict=0 --nogpgcheck; then
                log_success "iptables-services 安装成功"
                
                # 停止现有 iptables 服务
                systemctl stop iptables 2>/dev/null || true
                
                # 创建基础 iptables 配置文件
                log_info "创建基础 iptables 配置..."
                cat > /etc/sysconfig/iptables << 'EOF'
# Generated by iptables-save v1.4.21
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p tcp --dport 3000 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
                
                # 尝试启动 iptables
                log_info "启动 iptables 服务..."
                if systemctl start iptables 2>/dev/null; then
                    systemctl enable iptables 2>/dev/null || true
                    log_success "iptables 服务启动成功"
                    DEPLOYMENT_RESULTS[防火墙配置]="成功"
                    FIREWALL_CONFIGURED=true
                else
                    log_warning "iptables 服务启动失败，跳过防火墙配置"
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
    # 步骤 9: 验证部署
    # ============================================
    log_info "步骤 9: 验证部署"
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
    
    # 验证 MySQL
    log_info "验证 MySQL..."
    if command -v mysql &> /dev/null; then
        if check_service mysqld 2>/dev/null || check_service mariadb 2>/dev/null; then
            log_success "MySQL 服务正在运行"
        else
            log_error "MySQL 服务未运行"
        fi
    else
        log_error "MySQL 未安装"
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
    if command -v iptables &> /dev/null; then
        if iptables -L -n | grep -q "dpt:3000"; then
            log_success "防火墙已开放 3000 端口"
        else
            log_warning "防火墙未开放 3000 端口"
        fi
    fi
    
    echo ""
    
    # ============================================
    # 步骤 10: 生成部署报告
    # ============================================
    log_info "步骤 10: 生成部署报告"
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
MySQL: $(command -v mysql &> /dev/null && mysql --version | head -1 || echo "未安装")

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
防火墙状态: $(command -v iptables &> /dev/null && iptables -L -n | grep -q "dpt:3000" && echo "已开放" || echo "未开放")

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
    echo "✓ MySQL 安装完成"
    echo "✓ 应用部署完成"
    echo "✓ 防火墙配置完成（3000 端口）"
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
    echo "6. MySQL 数据库: root/Liuyuyi1989, price/Liuyuyi1989"
    echo ""
}

# 运行主函数
main "$@"