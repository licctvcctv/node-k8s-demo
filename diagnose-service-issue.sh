#!/bin/bash
# 诊断服务访问问题

echo "🔍 诊断云原生商城服务问题"
echo "========================="

NAMESPACE="cloud-shop"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "1️⃣  检查Pod状态..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "2️⃣  检查最近的事件..."
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10

echo ""
echo "3️⃣  检查服务端点..."
kubectl get endpoints -n $NAMESPACE

echo ""
echo "4️⃣  检查某个Pod的详细信息（以user-service为例）..."
USER_POD=$(kubectl get pods -n $NAMESPACE -l app=user-service -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$USER_POD" ]; then
    echo "Pod名称: $USER_POD"
    
    echo ""
    echo "检查Init容器日志..."
    kubectl logs $USER_POD -c setup -n $NAMESPACE --tail=20
    
    echo ""
    echo "检查主容器日志..."
    kubectl logs $USER_POD -n $NAMESPACE --tail=20
    
    echo ""
    echo "检查Pod内的文件结构..."
    kubectl exec $USER_POD -n $NAMESPACE -- ls -la /app/ 2>/dev/null || echo "无法访问/app目录"
    
    echo ""
    echo "检查public目录..."
    kubectl exec $USER_POD -n $NAMESPACE -- ls -la /app/public/ 2>/dev/null || echo "public目录不存在"
    
    echo ""
    echo "检查index.js内容（前20行）..."
    kubectl exec $USER_POD -n $NAMESPACE -- head -20 /app/index.js 2>/dev/null || echo "index.js不存在"
else
    echo -e "${RED}找不到user-service的Pod${NC}"
fi

echo ""
echo "5️⃣  测试服务访问..."
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

for port in 30081 30082 30083 30084; do
    echo ""
    echo "测试端口 $port..."
    echo "URL: http://$NODE_IP:$port/"
    
    # 获取HTTP响应
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://$NODE_IP:$port/ 2>/dev/null || echo "CURL_ERROR")
    
    if [[ "$response" == "CURL_ERROR" ]]; then
        echo -e "${RED}无法连接到服务${NC}"
    else
        # 分离内容和状态码
        content=$(echo "$response" | sed '$d')
        http_code=$(echo "$response" | tail -1 | cut -d: -f2)
        
        echo "HTTP状态码: $http_code"
        echo "响应内容（前100字符）:"
        echo "$content" | head -c 100
        echo ""
        
        # 检查是否是HTML
        if [[ "$content" == *"<html"* ]] || [[ "$content" == *"<!DOCTYPE"* ]]; then
            echo -e "${GREEN}✓ 返回HTML页面${NC}"
        else
            echo -e "${YELLOW}⚠ 返回非HTML内容${NC}"
        fi
    fi
done

echo ""
echo "6️⃣  网络连通性测试..."

# 检查NodePort服务
echo "NodePort服务列表:"
kubectl get svc -n $NAMESPACE -o wide

# 检查iptables规则（如果有权限）
echo ""
echo "检查节点上的端口监听（需要在K8s节点上执行）:"
echo "ss -tlnp | grep -E '30081|30082|30083|30084'"

echo ""
echo "💡 常见问题及解决方案："
echo ""
echo "1. 如果只返回文本而非HTML页面："
echo "   - 检查public目录是否存在: kubectl exec <pod> -n $NAMESPACE -- ls /app/public/"
echo "   - 检查hostPath挂载: 确保/tmp/node-k8s-demo/services/有实际代码"
echo ""
echo "2. 如果无法访问服务："
echo "   - 检查防火墙: firewall-cmd --list-ports"
echo "   - 检查iptables: iptables -L -n | grep 3008"
echo "   - 使用正确的节点IP: 使用worker节点IP而非master节点IP"
echo ""
echo "3. 如果Pod一直在Init状态："
echo "   - 查看Init容器日志: kubectl logs <pod> -c setup -n $NAMESPACE"
echo "   - 可能是npm安装失败，检查网络连接"
echo ""
echo "4. 快速修复方案："
echo "   ./fix-code-deployment.sh  # 确保代码正确部署"
echo "   ./deploy-with-full-code.sh # 使用完整代码重新部署"