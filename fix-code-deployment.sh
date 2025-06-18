#!/bin/bash
# 修复代码部署问题 - 确保完整的应用代码被部署到K8s

set -e

echo "🔧 修复云原生商城代码部署问题"
echo "================================="

NAMESPACE="cloud-shop"
SOURCE_DIR="/mnt/c/Users/18362/Documents/augment-projects/2313212/cloud-native-shop"
TARGET_DIR="/tmp/node-k8s-demo"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_progress() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo "1️⃣  确保目标目录有完整的项目代码..."

# 创建目标目录
mkdir -p $TARGET_DIR

# 复制完整项目到目标目录
if [ -d "$SOURCE_DIR" ]; then
    echo "从源目录复制项目文件..."
    cp -r $SOURCE_DIR/* $TARGET_DIR/ 2>/dev/null || true
    show_progress "项目文件复制完成"
else
    show_error "源目录不存在: $SOURCE_DIR"
    echo "使用当前目录作为源..."
    cp -r ./* $TARGET_DIR/ 2>/dev/null || true
fi

# 验证服务代码是否存在
echo ""
echo "2️⃣  验证服务代码..."

for service in user-service product-service order-service dashboard-service; do
    if [ -d "$TARGET_DIR/services/$service" ]; then
        echo -e "${GREEN}✓${NC} $service 代码存在"
        
        # 检查关键文件
        if [ -f "$TARGET_DIR/services/$service/index.js" ]; then
            echo "  - index.js ✓"
        else
            show_warning "  - index.js 缺失"
        fi
        
        if [ -d "$TARGET_DIR/services/$service/public" ]; then
            echo "  - public/ ✓ ($(ls -1 $TARGET_DIR/services/$service/public | wc -l) 个文件)"
        else
            show_warning "  - public/ 目录缺失"
        fi
    else
        show_error "$service 目录不存在"
    fi
done

echo ""
echo "3️⃣  重启Pod以加载新代码..."

# 删除现有Pod强制重新创建
kubectl delete pods --all -n $NAMESPACE --grace-period=0 --force

echo "等待Pod重新启动..."
sleep 30

# 检查Pod状态
echo ""
echo "4️⃣  验证部署状态..."

kubectl get pods -n $NAMESPACE

echo ""
echo "等待所有Pod就绪..."
kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s || show_warning "部分Pod可能未就绪"

# 验证服务响应
echo ""
echo "5️⃣  验证服务响应..."

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

for port in 30081 30082 30083 30084; do
    service=""
    case $port in
        30081) service="用户服务" ;;
        30082) service="商品服务" ;;
        30083) service="订单服务" ;;
        30084) service="监控面板" ;;
    esac
    
    echo -n "检查 $service (端口 $port)... "
    
    # 使用curl检查响应
    response=$(curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP:$port/ 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ]; then
        # 检查是否返回HTML
        content=$(curl -s http://$NODE_IP:$port/ | head -n 1)
        if [[ "$content" == *"<"* ]]; then
            echo -e "${GREEN}✅ HTML页面正常${NC}"
        else
            echo -e "${YELLOW}⚠️  返回文本响应（非HTML）${NC}"
        fi
    else
        echo -e "${RED}❌ 无响应 (HTTP $response)${NC}"
    fi
done

echo ""
echo "💡 如果服务仍然只返回文本，可能需要："
echo ""
echo "1. 检查Pod内部的文件："
echo "   kubectl exec -it <pod-name> -n $NAMESPACE -- ls -la /app/"
echo "   kubectl exec -it <pod-name> -n $NAMESPACE -- ls -la /app/public/"
echo ""
echo "2. 查看Init容器日志："
echo "   kubectl logs <pod-name> -c setup -n $NAMESPACE"
echo ""
echo "3. 进入Pod检查代码："
echo "   kubectl exec -it <pod-name> -n $NAMESPACE -- sh"
echo "   cat /app/index.js"
echo ""
echo "🌐 服务访问地址："
echo "用户服务: http://$NODE_IP:30081"
echo "商品服务: http://$NODE_IP:30082"  
echo "订单服务: http://$NODE_IP:30083"
echo "监控面板: http://$NODE_IP:30084"