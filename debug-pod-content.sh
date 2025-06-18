#!/bin/bash
# 调试Pod内容，检查代码是否正确部署

echo "🔍 调试Pod内容和代码部署情况"
echo "=============================="

NAMESPACE="cloud-shop"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1️⃣  获取所有Pod信息...${NC}"
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${BLUE}2️⃣  检查每个服务的Pod内容...${NC}"

for service in user-service product-service order-service dashboard-service; do
    echo ""
    echo -e "${YELLOW}========== 检查 $service ==========${NC}"
    
    # 获取Pod名称
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD_NAME" ]; then
        echo -e "${RED}找不到 $service 的Pod${NC}"
        continue
    fi
    
    echo "Pod名称: $POD_NAME"
    
    # 检查Init容器日志的最后几行
    echo ""
    echo -e "${BLUE}Init容器日志（最后20行）:${NC}"
    kubectl logs $POD_NAME -c setup -n $NAMESPACE --tail=20 2>/dev/null || echo "无法获取Init容器日志"
    
    # 检查主容器日志
    echo ""
    echo -e "${BLUE}主容器日志（最后10行）:${NC}"
    kubectl logs $POD_NAME -n $NAMESPACE --tail=10 2>/dev/null || echo "无法获取主容器日志"
    
    # 检查/app目录内容
    echo ""
    echo -e "${BLUE}/app目录内容:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- ls -la /app/ 2>/dev/null || echo "无法访问/app目录"
    
    # 检查是否有public目录
    echo ""
    echo -e "${BLUE}/app/public目录内容:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- ls -la /app/public/ 2>/dev/null || echo "没有public目录"
    
    # 查看index.js的前30行
    echo ""
    echo -e "${BLUE}index.js内容（前30行）:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- head -30 /app/index.js 2>/dev/null || echo "无法读取index.js"
    
    # 检查package.json
    echo ""
    echo -e "${BLUE}package.json内容:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- cat /app/package.json 2>/dev/null || echo "无法读取package.json"
    
    # 检查node_modules是否存在
    echo ""
    echo -e "${BLUE}检查node_modules:${NC}"
    kubectl exec $POD_NAME -n $NAMESPACE -- sh -c "if [ -d /app/node_modules ]; then echo '✅ node_modules存在'; ls /app/node_modules | wc -l | xargs echo '包数量:'; else echo '❌ node_modules不存在'; fi" 2>/dev/null
    
    echo ""
    echo "=================================="
done

echo ""
echo -e "${BLUE}3️⃣  测试服务HTTP响应...${NC}"

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

for service_port in "user-service:30081" "product-service:30082" "order-service:30083" "dashboard-service:30084"; do
    service=$(echo $service_port | cut -d: -f1)
    port=$(echo $service_port | cut -d: -f2)
    
    echo ""
    echo -e "${YELLOW}测试 $service (端口 $port)...${NC}"
    
    # 获取根路径响应
    echo "GET http://$NODE_IP:$port/"
    response=$(curl -s http://$NODE_IP:$port/ 2>/dev/null | head -200)
    
    # 检查响应类型
    if [[ "$response" == *"<html"* ]] || [[ "$response" == *"<!DOCTYPE"* ]]; then
        echo -e "${GREEN}✅ 返回HTML页面${NC}"
        echo "前100字符: $(echo "$response" | head -c 100)..."
    else
        echo -e "${YELLOW}⚠️  返回非HTML内容${NC}"
        echo "响应内容: $response"
    fi
    
    # 检查静态文件路径
    echo ""
    echo "GET http://$NODE_IP:$port/index.html"
    html_response=$(curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP:$port/index.html 2>/dev/null)
    echo "HTTP状态码: $html_response"
done

echo ""
echo -e "${BLUE}4️⃣  检查ConfigMap内容...${NC}"

for service in user-service product-service order-service dashboard-service; do
    echo ""
    echo -e "${YELLOW}ConfigMap: ${service}-base${NC}"
    kubectl get configmap ${service}-base -n $NAMESPACE -o yaml | grep -A 20 "index.js:" | head -30
done

echo ""
echo -e "${BLUE}5️⃣  检查挂载的hostPath...${NC}"

# 检查一个Pod的Volume挂载情况
SAMPLE_POD=$(kubectl get pods -n $NAMESPACE -l app=user-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SAMPLE_POD" ]; then
    echo "检查Pod: $SAMPLE_POD 的Volume挂载"
    kubectl describe pod $SAMPLE_POD -n $NAMESPACE | grep -A 20 "Volumes:" | head -30
fi

echo ""
echo -e "${BLUE}💡 调试完成！${NC}"
echo ""
echo "可能的问题："
echo "1. 如果index.js只包含简单的文本响应，说明Init容器没有复制到实际代码"
echo "2. 如果没有public目录，说明静态文件没有被正确部署"
echo "3. 如果ConfigMap中的代码就是简单响应，说明问题在deployment配置"