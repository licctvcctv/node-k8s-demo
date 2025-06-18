#!/bin/bash
# Git上传脚本

echo "🚀 开始上传项目到GitHub..."

# 配置git（如果需要）
git config --global user.name "licctvcctv" 2>/dev/null || true
git config --global user.email "your-email@example.com" 2>/dev/null || true

# 检查是否已经是git仓库
if [ ! -d .git ]; then
    echo "初始化Git仓库..."
    git init
fi

# 添加所有文件
echo "添加所有文件..."
git add .

# 创建提交
echo "创建提交..."
git commit -m "Fix: 修复跨端口认证问题和部署脚本

- 解决了Git合并冲突
- 修复了auth.js跨端口sessionStorage隔离问题
- 使用URL参数传递认证信息替代sessionStorage
- 优化了ConfigMap创建流程，使用tar打包确保包含所有子目录
- 修复了public目录文件无法访问的问题"

# 检查远程仓库
if ! git remote | grep -q "origin"; then
    echo "添加远程仓库..."
    git remote add origin https://github.com/licctvcctv/node-k8s-demo.git
fi

# 设置主分支
git branch -M main

# 推送到GitHub
echo "推送到GitHub..."
echo "如果提示输入密码，请使用GitHub Personal Access Token"
echo "创建Token: https://github.com/settings/tokens"
git push -u origin main

echo ""
echo "✅ 上传完成！"
echo "访问: https://github.com/licctvcctv/node-k8s-demo"