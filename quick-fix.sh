#!/bin/bash
# 快速修复当前问题

echo "🔧 快速修复当前问题..."

echo "1. 获取Jenkins初始密码"
docker exec jenkins-cloud-shop cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "无法获取密码"

echo ""
echo "2. 检查init容器错误日志"
echo "order-service init日志:"
kubectl logs order-service-7f4877f674-dg657 -c setup -n cloud-shop --tail=20

echo ""
echo "user-service init日志:"
kubectl logs user-service-bd7c55867-sjvm6 -c setup -n cloud-shop --tail=20

echo ""
echo "3. 重启失败的服务"
kubectl delete pod order-service-7f4877f674-dg657 -n cloud-shop
kubectl delete pod user-service-bd7c55867-sjvm6 -n cloud-shop
kubectl delete pod product-service-756d5f9cf8-cv8kh -n cloud-shop
kubectl delete pod dashboard-service-bcbf9d779-b98xx -n cloud-shop

echo ""
echo "4. 等待新Pod启动..."
sleep 30
kubectl get pods -n cloud-shop

echo ""
echo "🎯 修复完成！请检查Pod状态"