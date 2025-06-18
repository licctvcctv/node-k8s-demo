#!/bin/bash
# 优化的K8s部署脚本 - 解决containerd镜像问题
# 适用于使用containerd作为容器运行时的K8s集群

set -e

echo "🚀 云原生商城 - 优化K8s部署脚本"
echo "================================"

# 配置变量
NAMESPACE="cloud-shop"
WORKER_NODES=("k8s-worker1" "k8s-worker2")
IMAGES=(
  "cloud-shop/user-service:latest"
  "cloud-shop/product-service:latest"
  "cloud-shop/order-service:latest"
  "cloud-shop/dashboard-service:latest"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查函数
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 未安装${NC}"
        exit 1
    fi
}

# 显示进度
show_progress() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 显示警告
show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 显示错误
show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查必要命令
echo "1️⃣  检查环境..."
check_command docker
check_command kubectl
check_command ctr
check_command ssh

# 检查kubectl连接
if ! kubectl cluster-info &> /dev/null; then
    show_error "无法连接到Kubernetes集群"
    exit 1
fi

# 检查Docker服务
if ! docker info &> /dev/null; then
    show_error "Docker服务未运行"
    exit 1
fi

# 检查containerd服务
if ! ctr version &> /dev/null; then
    show_error "containerd服务未运行"
    exit 1
fi

show_progress "环境检查完成"

# 创建crictl配置（如果需要）
echo ""
echo "2️⃣  配置containerd客户端..."
if [ ! -f /etc/crictl.yaml ]; then
    cat > /etc/crictl.yaml << EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
EOF
    show_progress "crictl配置创建成功"
else
    show_progress "crictl配置已存在"
fi

# 构建镜像
echo ""
echo "3️⃣  构建Docker镜像..."
cd services

for service in user-service product-service order-service dashboard-service; do
    echo -e "${YELLOW}构建 $service...${NC}"
    cd $service
    docker build -t cloud-shop/$service:latest .
    if [ $? -eq 0 ]; then
        show_progress "$service 构建成功"
    else
        show_error "$service 构建失败"
        exit 1
    fi
    cd ..
done
cd ..

# 导入镜像到本地containerd
echo ""
echo "4️⃣  导入镜像到本地containerd..."
for img in "${IMAGES[@]}"; do
    echo -e "${YELLOW}导入 $img...${NC}"
    docker save $img | ctr -n k8s.io images import -
    if [ $? -eq 0 ]; then
        show_progress "$img 导入成功"
    else
        show_error "$img 导入失败"
        exit 1
    fi
done

# 验证本地镜像
echo ""
echo "验证本地containerd镜像..."
ctr -n k8s.io images ls | grep cloud-shop

# 导入镜像到Worker节点
echo ""
echo "5️⃣  同步镜像到Worker节点..."
for worker in "${WORKER_NODES[@]}"; do
    echo -e "${YELLOW}处理节点 $worker...${NC}"
    
    # 检查节点连接
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes root@$worker "echo 'Connected'" &> /dev/null; then
        show_error "无法连接到 $worker，请检查SSH配置"
        echo "解决方案："
        echo "1. 确保SSH密钥已配置：ssh-copy-id root@$worker"
        echo "2. 或手动在 $worker 节点执行以下命令："
        for img in "${IMAGES[@]}"; do
            echo "   docker save $img | ctr -n k8s.io images import -"
        done
        continue
    fi
    
    # 确保Worker节点有最新镜像
    for img in "${IMAGES[@]}"; do
        echo "  检查 $img 在 $worker..."
        
        # 检查Worker节点是否已有镜像
        if ssh root@$worker "ctr -n k8s.io images ls | grep -q $(echo $img | cut -d':' -f1)" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $img 已存在"
            continue
        fi
        
        # 检查Docker中是否有镜像
        if ssh root@$worker "docker images | grep -q $(echo $img | cut -d':' -f1)" 2>/dev/null; then
            echo "  从本地Docker导入 $img..."
            if ssh root@$worker "docker save $img | ctr -n k8s.io images import -" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $img 导入成功"
            else
                show_warning "  $img 本地导入失败，尝试远程传输"
            fi
        else
            echo "  从Master传输 $img..."
            if docker save $img | ssh root@$worker "ctr -n k8s.io images import -" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $img 传输成功"
            else
                show_error "  $img 传输失败"
                echo "  手动解决：在 $worker 节点执行 'docker save $img | ctr -n k8s.io images import -'"
            fi
        fi
    done
    
    # 验证Worker节点镜像
    echo "  验证 $worker 节点镜像..."
    if ssh root@$worker "ctr -n k8s.io images ls | grep cloud-shop" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $worker 镜像验证成功"
    else
        show_warning "  $worker 镜像验证失败，可能影响Pod启动"
    fi
done

# 创建命名空间
echo ""
echo "6️⃣  创建Kubernetes资源..."
echo "创建命名空间..."
kubectl apply -f k8s/namespace.yaml
show_progress "命名空间创建完成"

# 部署Redis
echo "部署Redis..."
kubectl apply -f k8s/redis/redis-deployment.yaml
show_progress "Redis部署完成"

# 等待Redis就绪
echo "等待Redis就绪..."
kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=60s || show_warning "Redis启动超时"

# 部署服务
echo ""
echo "7️⃣  部署微服务..."
for service in user-service product-service order-service dashboard-service; do
    echo "部署 $service..."
    kubectl apply -f k8s/$service/deployment.yaml
    show_progress "$service 部署完成"
done

# 重启所有Pod（确保使用最新镜像）
echo ""
echo "8️⃣  重启所有Pod..."
kubectl delete pods --all -n $NAMESPACE --grace-period=30
show_progress "Pod重启命令已发出"

# 等待Pod就绪
echo ""
echo "9️⃣  等待服务就绪..."
echo "等待Pod启动..."
sleep 15

# 检查Pod状态
echo "检查Pod状态..."
kubectl get pods -n $NAMESPACE

# 等待所有Pod就绪
echo "等待所有Pod就绪（最多等待5分钟）..."
kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s

if [ $? -eq 0 ]; then
    show_progress "所有Pod已就绪"
else
    show_warning "部分Pod可能未就绪，请检查状态"
    kubectl get pods -n $NAMESPACE
fi

# 检查部署状态
echo ""
echo "🔍 检查部署状态..."
kubectl get pods -n $NAMESPACE -o wide

# 检查服务
echo ""
echo "📋 服务信息:"
kubectl get svc -n $NAMESPACE

# 获取服务访问地址
echo ""
echo "🌐 服务访问地址:"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "用户服务: http://$NODE_IP:30081"
echo "商品服务: http://$NODE_IP:30082"
echo "订单服务: http://$NODE_IP:30083"
echo "监控面板: http://$NODE_IP:30084"

# 监控Pod状态
echo ""
echo "📊 监控Pod状态 (按Ctrl+C退出):"
echo "================================"
kubectl get pods -n $NAMESPACE -w

# 清理函数（可选）
cleanup() {
    echo ""
    echo "清理部署？(y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        kubectl delete namespace $NAMESPACE
        show_progress "清理完成"
    fi
}

# 故障排查提示
echo ""
echo "💡 故障排查提示:"
echo "1. 查看Pod日志: kubectl logs <pod-name> -n $NAMESPACE"
echo "2. 查看Pod详情: kubectl describe pod <pod-name> -n $NAMESPACE"
echo "3. 进入Pod调试: kubectl exec -it <pod-name> -n $NAMESPACE -- /bin/sh"
echo "4. 查看containerd镜像: ctr -n k8s.io images ls | grep cloud-shop"
echo "5. 检查ImagePullBackOff: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo "6. 手动导入镜像到节点: docker save <image> | ctr -n k8s.io images import -"
echo "7. 清理部署: kubectl delete namespace $NAMESPACE"
echo "8. 查看节点状态: kubectl get nodes -o wide"
echo "9. 重建镜像: cd services/<service> && docker build -t <image> ."
echo ""
echo "📋 常见问题解决:"
echo "- ImagePullBackOff: 确保所有节点都有镜像在k8s.io命名空间中"
echo "- ErrImageNeverPull: 检查imagePullPolicy设置和本地镜像"
echo "- SSH连接失败: 配置SSH密钥 ssh-copy-id root@<node>"
echo "- 构建失败: 检查Dockerfile和依赖文件是否存在"