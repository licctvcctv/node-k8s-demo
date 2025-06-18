#!/bin/bash
# 专门排查Init容器卡住问题的脚本

echo "🔍 深度排查Init容器问题..."

# 获取所有卡住的Pod
STUCK_PODS=$(kubectl get pods -n cloud-shop --no-headers | grep "Init:0/1" | awk '{print $1}')

if [ -z "$STUCK_PODS" ]; then
    echo "❌ 没有发现卡在Init:0/1状态的Pod"
    exit 1
fi

for POD in $STUCK_PODS; do
    echo "=========================================="
    echo "🔍 排查Pod: $POD"
    echo "=========================================="
    
    echo ""
    echo "1. Pod详细信息:"
    kubectl describe pod $POD -n cloud-shop | grep -A 10 -B 10 -E "(Events|State|Ready|Status)"
    
    echo ""
    echo "2. Init容器状态:"
    kubectl get pod $POD -n cloud-shop --template '{{.status.initContainerStatuses}}' | jq '.' 2>/dev/null || echo "无法解析JSON状态"
    
    echo ""
    echo "3. Init容器日志 (最新50行):"
    kubectl logs $POD -c setup -n cloud-shop --tail=50
    
    echo ""
    echo "4. 检查Init容器是否还在运行:"
    kubectl exec $POD -c setup -n cloud-shop -- ps aux 2>/dev/null || echo "无法连接到Init容器"
    
    echo ""
    echo "5. 测试网络连接 (从Init容器内部):"
    kubectl exec $POD -c setup -n cloud-shop -- ping -c 3 registry.npmjs.org 2>/dev/null || echo "网络测试失败"
    
    echo ""
    echo "6. 检查DNS解析:"
    kubectl exec $POD -c setup -n cloud-shop -- nslookup registry.npmjs.org 2>/dev/null || echo "DNS解析失败"
    
    echo ""
    echo "=========================================="
done

echo ""
echo "🛠️ 建议的修复方案:"
echo "1. 如果看到npm install卡住，可能是网络问题"
echo "2. 如果Init容器进程还在运行但没有日志输出，可能是timeout问题"
echo "3. 如果网络测试失败，需要检查集群网络配置"
echo "4. 可以尝试删除卡住的Pod让其重新创建:"
echo ""
for POD in $STUCK_PODS; do
    echo "   kubectl delete pod $POD -n cloud-shop"
done