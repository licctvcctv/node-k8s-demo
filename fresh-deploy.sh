#!/bin/bash
# 完整的清理和重新部署脚本

echo "🚀 完整的清理和重新部署流程"
echo "=========================================="

echo "📋 步骤1: 彻底清理环境"
echo "----------------------------------------"

# 清理Kubernetes资源
echo "清理Kubernetes命名空间..."
kubectl delete namespace cloud-shop --force --grace-period=0 2>/dev/null || true

# 清理Jenkins容器
echo "清理Jenkins容器..."
docker stop jenkins-cloud-shop 2>/dev/null || true
docker rm jenkins-cloud-shop 2>/dev/null || true
rm -rf jenkins-data

# 清理下载的项目目录
echo "清理项目目录..."
rm -rf /tmp/node-k8s-demo
rm -rf ./node-k8s-demo

echo "等待清理完成..."
sleep 10

echo "📋 步骤2: 重新下载最新代码"
echo "----------------------------------------"

# 进入临时目录
cd /tmp

# 重新克隆项目
echo "从GitHub下载最新代码..."
git clone https://github.com/licctvcctv/node-k8s-demo.git

# 进入项目目录
cd node-k8s-demo

# 设置执行权限
echo "设置脚本执行权限..."
chmod +x *.sh

echo "📋 步骤3: 开始部署"
echo "----------------------------------------"

# 运行部署脚本
echo "开始一键部署..."
./deploy-all-in-one.sh

echo "🎉 完整重新部署流程完成！"
