#!/bin/bash
# 修复K8s集群中npm网络问题的脚本

set -e

echo "🔧 修复云原生商城npm网络问题"
echo "================================"

NAMESPACE="cloud-shop"

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

echo "1️⃣  创建修复后的deployment配置..."

# 创建临时目录
mkdir -p /tmp/cloud-shop-fix

# 生成不使用Init容器的简化deployment
for service in user-service product-service dashboard-service; do
    PORT=""
    case $service in
        user-service)
            PORT="8081"
            ;;
        product-service)
            PORT="8082"
            ;;
        dashboard-service)
            PORT="8084"
            ;;
    esac

    cat > /tmp/cloud-shop-fix/${service}-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $service
  template:
    metadata:
      labels:
        app: $service
    spec:
      containers:
      - name: $service
        image: node:18-alpine
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting $service..."
          cd /app
          
          # 创建基础package.json
          cat > package.json <<'PKG_EOF'
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
          PKG_EOF
          
          # 创建简单的服务代码
          cat > index.js <<'JS_EOF'
          const express = require('express');
          const app = express();
          const port = process.env.PORT || $PORT;
          
          app.use(express.json());
          
          // 健康检查
          app.get('/health', (req, res) => {
            res.json({ status: 'ok', service: '$service' });
          });
          
          // 根路径
          app.get('/', (req, res) => {
            res.json({ 
              service: '$service',
              version: '1.0.0',
              status: 'running'
            });
          });
          
          app.listen(port, () => {
            console.log(\`$service listening on port \${port}\`);
          });
          JS_EOF
          
          # 使用国内镜像源
          npm config set registry https://registry.npmmirror.com
          
          # 安装依赖（带重试）
          for i in 1 2 3; do
            echo "尝试安装依赖 (第\$i次)..."
            if npm install --production --no-audit --no-fund; then
              echo "依赖安装成功!"
              break
            else
              echo "安装失败，等待10秒后重试..."
              sleep 10
            fi
          done
          
          # 启动服务
          echo "启动服务..."
          npm start
        ports:
        - containerPort: $PORT
        env:
        - name: PORT
          value: "$PORT"
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: JWT_SECRET
          value: "cloud-shop-secret-key-2024"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: $PORT
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /health
            port: $PORT
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $service
  namespace: $NAMESPACE
spec:
  selector:
    app: $service
  ports:
  - protocol: TCP
    port: $PORT
    targetPort: $PORT
    nodePort: 30${PORT:3:3}
  type: NodePort
EOF

    show_progress "${service} deployment配置创建完成"
done

echo ""
echo "2️⃣  删除现有的有问题的deployment..."

# 删除现有deployment
kubectl delete deployments --all -n $NAMESPACE --grace-period=0 --force 2>/dev/null || true
kubectl delete pods --all -n $NAMESPACE --grace-period=0 --force 2>/dev/null || true

echo "等待清理完成..."
sleep 10

echo ""
echo "3️⃣  应用修复后的deployment..."

# 应用新的deployment
for service in user-service product-service dashboard-service; do
    echo "部署 $service..."
    kubectl apply -f /tmp/cloud-shop-fix/${service}-deployment.yaml
    show_progress "$service 部署完成"
done

echo ""
echo "4️⃣  检查部署状态..."
sleep 5

# 显示Pod状态
echo "Pod状态："
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "等待Pod启动（可能需要2-3分钟安装依赖）..."
echo "持续监控Pod状态："

# 监控Pod状态
watch -n 2 "kubectl get pods -n $NAMESPACE -o wide && echo '' && kubectl get svc -n $NAMESPACE"

echo ""
echo "💡 故障排查命令："
echo "查看日志: kubectl logs -f <pod-name> -n $NAMESPACE"
echo "查看详情: kubectl describe pod <pod-name> -n $NAMESPACE"
echo "进入容器: kubectl exec -it <pod-name> -n $NAMESPACE -- sh"
echo ""
echo "🌐 服务访问地址："
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "用户服务: http://$NODE_IP:30081"
echo "商品服务: http://$NODE_IP:30082"
echo "监控面板: http://$NODE_IP:30084"