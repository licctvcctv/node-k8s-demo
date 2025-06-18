#!/bin/bash
# 彻底清理所有残留资源

echo "🧹 开始彻底清理..."

echo "1. 强制删除Kubernetes命名空间"
kubectl delete namespace cloud-shop --force --grace-period=0 2>/dev/null || true
sleep 5

echo "2. 清理可能残留的资源"
kubectl get namespace | grep cloud-shop && kubectl patch namespace cloud-shop -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || echo "命名空间已清理"

echo "3. 停止并删除Jenkins容器"
docker stop jenkins-cloud-shop 2>/dev/null || true
docker rm jenkins-cloud-shop 2>/dev/null || true

echo "4. 清理Jenkins数据目录"
rm -rf jenkins-data

echo "5. 清理Docker镜像缓存（可选）"
docker system prune -f 2>/dev/null || true

echo "6. 检查端口占用"
netstat -tlnp | grep ":8080 " || echo "端口8080已释放"
netstat -tlnp | grep ":3008[1-4] " || echo "NodePort端口已释放"

echo "7. 等待清理完成"
sleep 10

echo "✅ 清理完成！现在可以重新部署"
echo ""
echo "🚀 执行以下命令重新部署："
echo "./deploy-all-in-one.sh"