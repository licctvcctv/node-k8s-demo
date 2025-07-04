#!/bin/bash

echo "=== Git 上传脚本 ==="
echo "请按照以下步骤操作："
echo ""
echo "1. 首先，确保你已经登录 GitHub"
echo "2. 在 Windows 上打开 Git Bash 或命令提示符"
echo "3. 进入项目目录："
echo "   cd /mnt/c/Users/18362/Documents/augment-projects/2313212/cloud-native-shop"
echo ""
echo "4. 运行以下命令上传代码："
echo ""
echo "git push origin master"
echo ""
echo "5. 如果提示输入用户名和密码："
echo "   - Username: 你的 GitHub 用户名"
echo "   - Password: 你的 GitHub Personal Access Token（不是密码）"
echo ""
echo "如果没有 Personal Access Token，请访问："
echo "https://github.com/settings/tokens/new"
echo "创建一个新的 token，勾选 'repo' 权限"
echo ""
echo "=== 当前 Git 状态 ==="
git status
echo ""
echo "=== 最近的提交 ==="
git log --oneline -5