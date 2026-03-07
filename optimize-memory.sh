#!/bin/bash

# 内存优化脚本
# 用于创建 swap 文件和优化内存使用

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "内存优化脚本"
echo "=========================================="
echo ""

# 检查当前内存状态
echo "当前内存状态:"
free -h
echo ""

# 检查可用内存
AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')

echo "可用内存: ${AVAILABLE_MEM}MB"
echo "当前 Swap: ${TOTAL_SWAP}MB"
echo ""

# 检查是否需要创建 swap
if [ $AVAILABLE_MEM -lt 512 ] && [ $TOTAL_SWAP -eq 0 ]; then
    echo -e "${YELLOW}内存不足，正在创建 2GB swap 文件...${NC}"
    echo ""
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    echo "可用磁盘空间: ${DISK_SPACE}GB"
    
    if [ $DISK_SPACE -lt 2 ]; then
        echo -e "${RED}错误: 磁盘空间不足，至少需要 2GB${NC}"
        exit 1
    fi
    
    # 创建 swap 文件
    echo "创建 2GB swap 文件..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
    
    # 设置权限
    echo "设置权限..."
    chmod 600 /swapfile
    
    # 创建 swap
    echo "创建 swap..."
    mkswap /swapfile
    
    # 启用 swap
    echo "启用 swap..."
    swapon /swapfile
    
    # 添加到 fstab（开机自动挂载）
    echo "配置开机自动挂载..."
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # 优化 swap 使用
    echo "优化 swap 使用策略..."
    sysctl vm.swappiness=10
    if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
    fi
    
    echo ""
    echo -e "${GREEN}✓ Swap 文件创建完成${NC}"
    
    # 显示新的内存状态
    echo ""
    echo "新的内存状态:"
    free -h
    echo ""
    
    # 验证 swap
    if swapon --show | grep -q '/swapfile'; then
        echo -e "${GREEN}✓ Swap 已成功启用${NC}"
    else
        echo -e "${RED}✗ Swap 启用失败${NC}"
        exit 1
    fi
    
else
    echo -e "${GREEN}内存充足或已有 swap，无需创建 swap${NC}"
fi

echo ""
echo "=========================================="
echo "优化完成"
echo "=========================================="
echo ""
echo "内存优化建议:"
echo "  1. 定期检查内存使用: free -h"
echo "  2. 监控 swap 使用: swapon --show"
echo "  3. 如果 swap 使用率高，考虑升级服务器"
echo "  4. 清理 yum 缓存: yum clean all"
echo "  5. 停止不必要的服务: systemctl stop <service>"
echo ""
echo "常用命令:"
echo "  free -h              # 查看内存状态"
echo "  swapon --show        # 查看 swap 状态"
echo "  swapoff /swapfile    # 禁用 swap"
echo "  swapon /swapfile     # 启用 swap"
echo "  rm /swapfile        # 删除 swap 文件"
echo ""
echo "=========================================="