#!/bin/bash
# 同步代码到所有Worker节点

echo "🔄 同步代码到Worker节点"
echo "======================="

SOURCE_DIR="/tmp/node-k8s-demo"
NAMESPACE="cloud-shop"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 获取Worker节点
WORKERS=$(kubectl get nodes --no-headers | grep -v master | awk '{print $1}')

echo "Worker节点列表："
echo "$WORKERS"
echo ""

# 同步到每个Worker节点
for worker in $WORKERS; do
    echo -e "${YELLOW}同步到 $worker...${NC}"
    
    # 创建目标目录
    ssh root@$worker "mkdir -p /tmp/node-k8s-demo" 2>/dev/null || {
        echo -e "${RED}无法连接到 $worker${NC}"
        echo "请确保SSH已配置: ssh-copy-id root@$worker"
        continue
    }
    
    # 同步整个项目目录
    echo "复制项目文件..."
    scp -r $SOURCE_DIR/* root@$worker:/tmp/node-k8s-demo/ 2>/dev/null || {
        echo -e "${RED}复制失败${NC}"
        continue
    }
    
    # 验证
    echo "验证文件..."
    ssh root@$worker "ls -la /tmp/node-k8s-demo/services/" 2>/dev/null && \
        echo -e "${GREEN}✅ $worker 同步成功${NC}" || \
        echo -e "${RED}❌ $worker 验证失败${NC}"
    
    echo ""
done

echo "同步完成！"
echo ""
echo "重启Pod以加载新代码..."
kubectl delete pods --all -n $NAMESPACE --grace-period=10

echo ""
echo "等待Pod重新启动..."
sleep 30

kubectl get pods -n $NAMESPACE

echo ""
echo "💡 现在Pod应该能够从本地hostPath加载完整代码了"