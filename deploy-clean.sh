#!/bin/bash
# 优化部署脚本 - 清理旧资源并重新部署
# 适用于没有Docker环境的本地测试

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
NAMESPACE="cloud-shop"

# 显示函数
show_progress() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🧹 云原生商城 - 清理并重新部署"
echo "======================================"

# 1. 清理旧资源
echo ""
echo "1️⃣  清理旧资源..."

# 检查命名空间是否存在
if kubectl get namespace $NAMESPACE &> /dev/null; then
    show_info "正在删除命名空间 $NAMESPACE 中的所有资源..."
    
    # 删除所有部署
    kubectl delete deployments --all -n $NAMESPACE --timeout=60s 2>/dev/null || true
    
    # 删除所有服务
    kubectl delete services --all -n $NAMESPACE --timeout=60s 2>/dev/null || true
    
    # 删除所有配置
    kubectl delete configmaps --all -n $NAMESPACE --timeout=60s 2>/dev/null || true
    
    # 删除所有密钥
    kubectl delete secrets --all -n $NAMESPACE --timeout=60s 2>/dev/null || true
    
    # 删除命名空间
    kubectl delete namespace $NAMESPACE --timeout=120s 2>/dev/null || true
    
    show_progress "旧资源清理完成"
else
    show_info "命名空间不存在，跳过清理"
fi

# 等待资源完全删除
echo "等待资源完全删除..."
sleep 10

# 2. 重新创建命名空间
echo ""
echo "2️⃣  重新创建命名空间..."
kubectl create namespace $NAMESPACE 2>/dev/null || show_warning "命名空间已存在"
show_progress "命名空间创建完成"

# 3. 部署Redis
echo ""
echo "3️⃣  部署Redis..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF

show_progress "Redis部署完成"

# 4. 部署用户服务
echo ""
echo "4️⃣  部署用户服务..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: node:16-alpine
        workingDir: /app
        command: ["sh", "-c"]
        args:
          - "npm install && npm start"
        ports:
        - containerPort: 8081
        env:
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: JWT_SECRET
          value: "cloud-shop-secret-key-2024"
        - name: PORT
          value: "8081"
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: app-code
        hostPath:
          path: $(pwd)/services/user-service
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: $NAMESPACE
spec:
  selector:
    app: user-service
  ports:
  - port: 8081
    targetPort: 8081
    nodePort: 30081
  type: NodePort
EOF

show_progress "用户服务部署完成"

# 5. 部署商品服务
echo ""
echo "5️⃣  部署商品服务..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: node:16-alpine
        workingDir: /app
        command: ["sh", "-c"]
        args:
          - "npm install && npm start"
        ports:
        - containerPort: 8082
        env:
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: PORT
          value: "8082"
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: app-code
        hostPath:
          path: $(pwd)/services/product-service
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: $NAMESPACE
spec:
  selector:
    app: product-service
  ports:
  - port: 8082
    targetPort: 8082
    nodePort: 30082
  type: NodePort
EOF

show_progress "商品服务部署完成"

# 6. 部署订单服务
echo ""
echo "6️⃣  部署订单服务..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: node:16-alpine
        workingDir: /app
        command: ["sh", "-c"]
        args:
          - "npm install && npm start"
        ports:
        - containerPort: 8083
        env:
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: PORT
          value: "8083"
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: app-code
        hostPath:
          path: $(pwd)/services/order-service
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: $NAMESPACE
spec:
  selector:
    app: order-service
  ports:
  - port: 8083
    targetPort: 8083
    nodePort: 30083
  type: NodePort
EOF

show_progress "订单服务部署完成"

# 7. 部署监控面板
echo ""
echo "7️⃣  部署监控面板..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard-service
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dashboard-service
  template:
    metadata:
      labels:
        app: dashboard-service
    spec:
      containers:
      - name: dashboard-service
        image: node:16-alpine
        workingDir: /app
        command: ["sh", "-c"]
        args:
          - "npm install && npm start"
        ports:
        - containerPort: 8084
        env:
        - name: PORT
          value: "8084"
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: USER_SERVICE_URL
          value: "http://user-service:8081"
        - name: PRODUCT_SERVICE_URL
          value: "http://product-service:8082"
        - name: ORDER_SERVICE_URL
          value: "http://order-service:8083"
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
      volumes:
      - name: app-code
        hostPath:
          path: $(pwd)/services/dashboard-service
---
apiVersion: v1
kind: Service
metadata:
  name: dashboard-service
  namespace: $NAMESPACE
spec:
  selector:
    app: dashboard-service
  ports:
  - port: 8084
    targetPort: 8084
    nodePort: 30084
  type: NodePort
EOF

show_progress "监控面板部署完成"

# 8. 等待Pod启动
echo ""
echo "8️⃣  等待Pod启动..."
echo "等待30秒让Pod初始化..."
sleep 30

echo "检查Pod状态..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "等待所有Pod就绪（最多等待5分钟）..."
if kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s; then
    show_progress "所有Pod已就绪"
else
    show_warning "部分Pod可能未就绪，请检查状态"
fi

# 9. 显示部署结果
echo ""
echo "🔍 最终部署状态"
echo "=================="

echo ""
echo "📋 Pod状态:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "📋 服务状态:"
kubectl get svc -n $NAMESPACE

# 获取访问地址
echo ""
echo "🌐 服务访问地址:"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")

echo "用户服务:   http://$NODE_IP:30081"
echo "商品服务:   http://$NODE_IP:30082"
echo "订单服务:   http://$NODE_IP:30083"
echo "监控面板:   http://$NODE_IP:30084"

echo ""
echo "🔑 测试账号:"
echo "管理员:     admin / admin123"
echo "演示用户:   demo / demo123"
echo "测试用户:   test / test123"

echo ""
echo "🎉 部署完成！"
echo ""
echo "💡 故障排除命令:"
echo "查看Pod详情:    kubectl describe pod <pod-name> -n $NAMESPACE"
echo "查看Pod日志:    kubectl logs <pod-name> -n $NAMESPACE"
echo "查看所有资源:   kubectl get all -n $NAMESPACE"
echo "重新启动服务:   kubectl rollout restart deployment/<service-name> -n $NAMESPACE"

echo ""
echo "🚀 开始测试完整购买流程:"
echo "1. 访问商品服务首页: http://$NODE_IP:30082"
echo "2. 使用测试账号登录: demo / demo123"
echo "3. 浏览商品 → 加入购物车 → 结算订单"
echo "4. 查看订单状态: http://$NODE_IP:30083"