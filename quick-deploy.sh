#!/bin/bash
# 快速部署脚本 - 使用正确的K8s文件路径

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 配置变量
NAMESPACE="cloud-shop"
WORKER_NODES=("k8s-worker1" "k8s-worker2")
IMAGES=(
  "cloud-shop/user-service:latest"
  "cloud-shop/product-service:latest"
  "cloud-shop/order-service:latest"
)

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

echo "🚀 云原生商城 - 快速部署脚本"
echo "==============================="

# 1. 环境检查
echo "1️⃣  检查环境..."
check_command docker
check_command kubectl
check_command ctr

# 检查kubectl连接
if ! kubectl cluster-info &> /dev/null; then
    show_error "无法连接到Kubernetes集群"
    exit 1
fi

show_progress "环境检查完成"

# 2. 构建镜像
echo ""
echo "2️⃣  构建Docker镜像..."
cd services

for service in user-service product-service order-service; do
    echo -e "${YELLOW}构建 $service...${NC}"
    cd $service
    if docker build -t cloud-shop/$service:latest .; then
        show_progress "$service 构建成功"
    else
        show_error "$service 构建失败"
        exit 1
    fi
    cd ..
done
cd ..

# 3. 导入镜像到本地containerd
echo ""
echo "3️⃣  导入镜像到containerd..."
for img in "${IMAGES[@]}"; do
    echo -e "${YELLOW}导入 $img...${NC}"
    if docker save $img | ctr -n k8s.io images import -; then
        show_progress "$img 导入成功"
    else
        show_error "$img 导入失败"
        exit 1
    fi
done

# 4. 同步到Worker节点
echo ""
echo "4️⃣  同步镜像到Worker节点..."
for worker in "${WORKER_NODES[@]}"; do
    echo -e "${YELLOW}处理节点 $worker...${NC}"
    
    # 检查节点连接（简化检查）
    if ! ssh -o ConnectTimeout=5 root@$worker "echo 'Connected'" &> /dev/null; then
        show_warning "跳过 $worker (SSH连接失败)"
        continue
    fi
    
    # 传输镜像
    for img in "${IMAGES[@]}"; do
        echo "  传输 $img 到 $worker..."
        if docker save $img | ssh root@$worker "ctr -n k8s.io images import -" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $img"
        else
            show_warning "  $img 传输失败"
        fi
    done
done

# 5. 部署Kubernetes资源
echo ""
echo "5️⃣  部署Kubernetes资源..."

# 创建命名空间
echo "创建命名空间..."
kubectl apply -f k8s/namespace.yaml
show_progress "命名空间创建完成"

# 部署Redis
echo "部署Redis..."
kubectl apply -f k8s/redis/redis-deployment.yaml
show_progress "Redis部署完成"

# 部署微服务
echo "部署微服务..."
kubectl apply -f k8s/user-service/deployment.yaml
kubectl apply -f k8s/product-service/deployment.yaml
kubectl apply -f k8s/order-service/deployment.yaml
show_progress "微服务部署完成"

# 6. 等待Pod就绪
echo ""
echo "6️⃣  等待服务就绪..."
echo "等待Pod启动..."
sleep 15

echo "检查Pod状态..."
kubectl get pods -n $NAMESPACE

echo "等待所有Pod就绪（最多等待5分钟）..."
if kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s; then
    show_progress "所有Pod已就绪"
else
    show_warning "部分Pod可能未就绪，请检查状态"
fi

# 7. 显示部署结果
echo ""
echo "🔍 部署状态检查..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "📋 服务信息:"
kubectl get svc -n $NAMESPACE

# 获取访问地址
echo ""
echo "🌐 服务访问地址:"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "用户服务: http://$NODE_IP:30081"
echo "商品服务: http://$NODE_IP:30082"
echo "订单服务: http://$NODE_IP:30083"

echo ""
echo "🎉 部署完成！"
echo ""
echo "💡 如果有问题，请检查："
echo "1. kubectl get pods -n $NAMESPACE"
echo "2. kubectl logs <pod-name> -n $NAMESPACE"
echo "3. kubectl describe pod <pod-name> -n $NAMESPACE"