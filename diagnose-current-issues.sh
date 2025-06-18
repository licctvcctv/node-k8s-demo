#!/bin/bash
# 诊断当前问题的脚本

echo "🔍 诊断当前问题..."

echo "=========================================="
echo "0. 清理和重新下载项目（可选）"
echo "=========================================="
echo "如果需要重新下载最新代码，请运行："
echo "cd /tmp && rm -rf node-k8s-demo && git clone https://github.com/licctvcctv/node-k8s-demo.git"
echo ""

echo "=========================================="
echo "1. 检查Pod详细状态"
echo "=========================================="
kubectl get pods -n cloud-shop -o wide

echo ""
echo "=========================================="
echo "2. 检查Init容器日志"
echo "=========================================="

# 获取当前的Pod名称
USER_POD=$(kubectl get pods -n cloud-shop -l app=user-service --no-headers | awk '{print $1}')
PRODUCT_POD=$(kubectl get pods -n cloud-shop -l app=product-service --no-headers | awk '{print $1}')
DASHBOARD_POD=$(kubectl get pods -n cloud-shop -l app=dashboard-service --no-headers | awk '{print $1}')

echo "User Service Init日志:"
if [ ! -z "$USER_POD" ]; then
    kubectl logs $USER_POD -c setup -n cloud-shop --tail=30
else
    echo "User Pod未找到"
fi

echo ""
echo "Product Service Init日志:"
if [ ! -z "$PRODUCT_POD" ]; then
    kubectl logs $PRODUCT_POD -c setup -n cloud-shop --tail=30
else
    echo "Product Pod未找到"
fi

echo ""
echo "Dashboard Service Init日志:"
if [ ! -z "$DASHBOARD_POD" ]; then
    kubectl logs $DASHBOARD_POD -c setup -n cloud-shop --tail=30
else
    echo "Dashboard Pod未找到"
fi

echo ""
echo "=========================================="
echo "3. 检查Order Service为什么能运行"
echo "=========================================="
ORDER_POD=$(kubectl get pods -n cloud-shop -l app=order-service --no-headers | awk '{print $1}')
if [ ! -z "$ORDER_POD" ]; then
    echo "Order Service主容器日志:"
    kubectl logs $ORDER_POD -n cloud-shop --tail=20

    echo ""
    echo "检查Order Service内部:"
    kubectl exec $ORDER_POD -n cloud-shop -- ls -la /app/
    echo ""
    kubectl exec $ORDER_POD -n cloud-shop -- ls -la /app/node_modules/ 2>/dev/null | head -10 || echo "node_modules不存在"
else
    echo "Order Pod未找到"
fi

echo ""
echo "=========================================="
echo "4. 检查服务端点"
echo "=========================================="
kubectl get endpoints -n cloud-shop

echo ""
echo "=========================================="
echo "5. 测试网络连接"
echo "=========================================="
echo "测试从master节点访问服务:"
for port in 30081 30082 30083 30084; do
    echo -n "端口 $port: "
    curl -s --connect-timeout 3 http://192.168.200.150:$port/health 2>/dev/null || echo "无法连接"
done

echo ""
echo "=========================================="
echo "6. 检查Node状态"
echo "=========================================="
kubectl get nodes -o wide

echo ""
echo "=========================================="
echo "7. 检查Service配置"
echo "=========================================="
kubectl get svc -n cloud-shop -o wide