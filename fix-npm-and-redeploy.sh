#!/bin/bash
# 修复npm镜像源并重新部署的脚本

set -e

echo "🔧 修复npm镜像源并重新部署云原生商城"
echo "======================================="

NAMESPACE="cloud-shop"
PROJECT_DIR="/tmp/node-k8s-demo"

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

echo "1️⃣  清理现有部署..."

# 删除现有的deployment和pods
kubectl delete deployments --all -n $NAMESPACE --grace-period=0 --force 2>/dev/null || true
kubectl delete pods --all -n $NAMESPACE --grace-period=0 --force 2>/dev/null || true
kubectl delete configmaps --all -n $NAMESPACE 2>/dev/null || true

echo "等待清理完成..."
sleep 10

echo ""
echo "2️⃣  检查项目目录..."

if [ ! -d "$PROJECT_DIR" ]; then
    show_error "项目目录 $PROJECT_DIR 不存在"
    echo "请确保项目已经克隆到该目录"
    exit 1
fi

cd $PROJECT_DIR

# 确保deploy-all-in-one.sh使用国内镜像源
if [ -f "deploy-all-in-one.sh" ]; then
    echo "修改部署脚本使用国内npm镜像源..."
    sed -i 's|https://registry.npmjs.org/|https://registry.npmmirror.com/|g' deploy-all-in-one.sh
    show_progress "部署脚本已更新"
fi

echo ""
echo "3️⃣  重新执行部署..."

# 执行修改后的部署脚本
./deploy-all-in-one.sh

echo ""
echo "💡 如果还有问题，可以尝试以下方案："
echo ""
echo "方案1: 使用离线安装包"
echo "在可以访问npm的机器上："
echo "1. cd services/user-service && npm install"
echo "2. tar czf node_modules.tar.gz node_modules"
echo "3. 将 node_modules.tar.gz 复制到K8s节点"
echo ""
echo "方案2: 使用预构建的Docker镜像"
echo "修改deployment使用已经包含依赖的镜像，而不是在Init容器中安装"
echo ""
echo "方案3: 配置HTTP代理"
echo "如果有可用的代理服务器："
echo "npm config set proxy http://proxy-server:port"
echo "npm config set https-proxy http://proxy-server:port"