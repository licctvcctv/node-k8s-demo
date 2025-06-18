#!/bin/bash
# 自动创建项目所需的目录结构

set -e

echo "🚀 云原生商城 - 目录结构初始化"
echo "================================"

# 创建所有需要的目录
echo "📁 创建目录结构..."

mkdir -p services/user-service/public
mkdir -p services/product-service/public
mkdir -p services/order-service/public
mkdir -p services/shared
mkdir -p k8s
mkdir -p scripts
mkdir -p docs

echo "✅ 目录结构创建完成"

# 检查是否存在关键文件
echo ""
echo "📋 检查关键文件..."

# 检查Dockerfile
for service in user-service product-service order-service; do
    if [ ! -f "services/$service/Dockerfile" ]; then
        echo "⚠️  缺少: services/$service/Dockerfile"
    else
        echo "✅ services/$service/Dockerfile"
    fi
done

# 检查index.js
for service in user-service product-service order-service; do
    if [ ! -f "services/$service/index.js" ]; then
        echo "⚠️  缺少: services/$service/index.js"
    else
        echo "✅ services/$service/index.js"
    fi
done

# 检查package.json
for service in user-service product-service order-service; do
    if [ ! -f "services/$service/package.json" ]; then
        echo "⚠️  缺少: services/$service/package.json"
    else
        echo "✅ services/$service/package.json"
    fi
done

# 检查K8s配置文件
echo "📁 检查K8s配置文件..."
if [ ! -f "k8s/namespace.yaml" ]; then
    echo "⚠️  缺少: k8s/namespace.yaml"
else
    echo "✅ k8s/namespace.yaml"
fi

if [ ! -f "k8s/redis/redis-deployment.yaml" ]; then
    echo "⚠️  缺少: k8s/redis/redis-deployment.yaml"
else
    echo "✅ k8s/redis/redis-deployment.yaml"
fi

if [ ! -f "k8s/user-service/deployment.yaml" ]; then
    echo "⚠️  缺少: k8s/user-service/deployment.yaml"
else
    echo "✅ k8s/user-service/deployment.yaml"
fi

if [ ! -f "k8s/product-service/deployment.yaml" ]; then
    echo "⚠️  缺少: k8s/product-service/deployment.yaml"
else
    echo "✅ k8s/product-service/deployment.yaml"
fi

if [ ! -f "k8s/order-service/deployment.yaml" ]; then
    echo "⚠️  缺少: k8s/order-service/deployment.yaml"
else
    echo "✅ k8s/order-service/deployment.yaml"
fi

# 检查前端页面
echo ""
echo "🌐 检查前端页面..."

# 用户服务页面
for page in index.html login.html register.html profile.html; do
    if [ ! -f "services/user-service/public/$page" ]; then
        echo "⚠️  缺少: services/user-service/public/$page"
    else
        echo "✅ services/user-service/public/$page"
    fi
done

# 商品服务页面
for page in index.html list.html detail.html admin.html; do
    if [ ! -f "services/product-service/public/$page" ]; then
        echo "⚠️  缺少: services/product-service/public/$page"
    else
        echo "✅ services/product-service/public/$page"
    fi
done

# 订单服务页面
if [ ! -f "services/order-service/public/index.html" ]; then
    echo "⚠️  缺少: services/order-service/public/index.html"
else
    echo "✅ services/order-service/public/index.html"
fi

echo ""
echo "🔍 目录结构检查完成"
echo ""
echo "📂 当前项目结构："
tree -L 3 2>/dev/null || find . -type d -name ".*" -prune -o -type d -print | head -20

echo ""
echo "🎯 下一步操作："
echo "1. 如果有缺失文件，请先创建对应的文件"
echo "2. 运行 ./deploy-k8s-optimized.sh 进行部署"
echo "3. 访问服务："
echo "   - 用户服务: http://<节点IP>:30081"
echo "   - 商品服务: http://<节点IP>:30082"
echo "   - 订单服务: http://<节点IP>:30083"