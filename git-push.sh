#\!/bin/bash
echo '🚀 开始提交并推送到 Git...'

# 添加所有修改的文件
git add .

# 提交
git commit -m "feat: 完善 Jenkins Pipeline 演示功能和 dashboard-service kubectl 权限

- 修改 deploy-all-in-one.sh 添加 dashboard-service 的 ServiceAccount 和 RBAC
- 为 dashboard-service 安装 kubectl 并配置权限
- 创建实用的 Jenkins 演示 Pipeline，可以真实检测服务状态
- 添加 Jenkins job 自动配置功能
- 创建 jenkins-demo-pipeline.groovy 文件

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

# 推送到远程仓库
git push origin master

echo '✅ 代码已成功推送到 GitHub！'
echo '📍 仓库地址: https://github.com/licctvcctv/node-k8s-demo'
