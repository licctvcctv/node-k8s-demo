#!/bin/bash
# 检查Worker节点上的文件

echo "🔍 检查Worker节点上的项目文件"
echo "=============================="

# 获取Worker节点列表
WORKERS=$(kubectl get nodes --no-headers | grep -v master | awk '{print $1}')

echo "Worker节点列表："
echo "$WORKERS"
echo ""

# 检查每个Worker节点
for worker in $WORKERS; do
    echo "========== 检查 $worker =========="
    
    echo "检查 /tmp/node-k8s-demo 目录是否存在："
    ssh root@$worker "ls -la /tmp/node-k8s-demo" 2>&1 || echo "目录不存在或无法访问"
    
    echo ""
    echo "检查 /tmp/node-k8s-demo/services 目录："
    ssh root@$worker "ls -la /tmp/node-k8s-demo/services" 2>&1 || echo "services目录不存在"
    
    echo ""
    echo "检查具体服务目录："
    ssh root@$worker "ls -la /tmp/node-k8s-demo/services/user-service" 2>&1 || echo "user-service目录不存在"
    
    echo ""
    echo "=================================="
done

echo ""
echo "💡 如果Worker节点上没有代码，需要："
echo "1. 在每个Worker节点上同步代码"
echo "2. 或者使用其他方式部署（如ConfigMap包含完整代码）"