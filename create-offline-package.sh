#!/bin/bash
# 创建离线npm包的脚本 - 在可以访问npm的机器上运行

set -e

echo "📦 创建离线npm安装包"
echo "===================="

# 创建临时目录
TEMP_DIR="/tmp/cloud-shop-offline"
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

# 服务列表
SERVICES=("user-service" "product-service" "order-service" "dashboard-service")

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "1️⃣  准备服务代码..."

for service in "${SERVICES[@]}"; do
    echo -e "${YELLOW}处理 $service...${NC}"
    
    # 创建服务目录
    mkdir -p $TEMP_DIR/$service
    
    # 复制package.json
    if [ -f "services/$service/package.json" ]; then
        cp services/$service/package.json $TEMP_DIR/$service/
    else
        # 创建基础package.json
        cat > $TEMP_DIR/$service/package.json <<EOF
{
  "name": "$service",
  "version": "1.0.0",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "redis": "^4.6.5",
    "cors": "^2.8.5",
    "axios": "^1.4.0",
    "jsonwebtoken": "^9.0.0",
    "bcryptjs": "^2.4.3"
  }
}
EOF
    fi
    
    # 进入服务目录安装依赖
    cd $TEMP_DIR/$service
    
    echo "安装依赖..."
    # 使用国内镜像源
    npm config set registry https://registry.npmmirror.com/
    npm install --production --no-audit --no-fund
    
    # 创建安装包
    echo "打包 node_modules..."
    tar czf ../${service}-node_modules.tar.gz node_modules
    
    echo -e "${GREEN}✅ $service 离线包创建成功${NC}"
    cd - > /dev/null
done

# 创建总包
echo ""
echo "2️⃣  创建总安装包..."
cd $TEMP_DIR
tar czf cloud-shop-offline-npm.tar.gz *.tar.gz
mv cloud-shop-offline-npm.tar.gz /tmp/

echo ""
echo -e "${GREEN}✅ 离线安装包创建成功！${NC}"
echo "文件位置: /tmp/cloud-shop-offline-npm.tar.gz"
echo ""
echo "📋 使用方法："
echo "1. 将 /tmp/cloud-shop-offline-npm.tar.gz 复制到K8s节点"
echo "2. 在K8s节点解压: tar xzf cloud-shop-offline-npm.tar.gz"
echo "3. 在每个服务目录解压对应的node_modules包"
echo ""
echo "或者使用自动安装脚本（见 install-offline-npm.sh）"

# 清理临时目录
rm -rf $TEMP_DIR