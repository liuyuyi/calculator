#!/bin/bash

# 设置 Node.js 14.21.3 为 nvm 默认版本的脚本

echo "=========================================="
echo "设置 Node.js 14.21.3 为默认版本"
echo "=========================================="

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 检查 Node.js 14.21.3 是否安装
if ! nvm ls 14.21.3 &> /dev/null; then
    echo "错误: Node.js 14.21.3 未安装"
    echo "正在安装 Node.js 14.21.3..."
    nvm install 14.21.3
fi

# 设置为默认版本
echo "设置 Node.js 14.21.3 为默认版本..."
nvm alias default 14.21.3

# 验证默认版本
echo ""
echo "当前默认版本:"
nvm alias default

echo ""
echo "验证设置..."
source ~/.bashrc
echo "当前 Node.js 版本: $(node -v)"

echo ""
echo "=========================================="
echo "设置完成！"
echo "=========================================="