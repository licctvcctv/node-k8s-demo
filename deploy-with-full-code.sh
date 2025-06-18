#!/bin/bash
# 使用完整应用代码重新部署（不依赖hostPath）

set -e

echo "🚀 部署完整的云原生商城应用"
echo "============================"

NAMESPACE="cloud-shop"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_progress() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 创建包含完整代码的ConfigMap
create_full_service_configmap() {
    local service_name=$1
    local port=$2
    
    echo "创建 $service_name 的完整ConfigMap..."
    
    # 读取实际的服务代码
    local index_js_content=""
    if [ -f "services/$service_name/index.js" ]; then
        index_js_content=$(cat services/$service_name/index.js | sed 's/\$/\\$/g' | sed 's/`/\\`/g')
    else
        # 使用默认代码
        index_js_content=$(cat <<'EOF'
const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());
app.use(express.static('public'));

// 健康检查
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'SERVICE_NAME' });
});

// API路由
app.get('/api/info', (req, res) => {
    res.json({
        service: 'SERVICE_NAME',
        version: '1.0.0',
        status: 'running'
    });
});

// 主页路由
app.get('/', (req, res) => {
    const indexPath = path.join(__dirname, 'public', 'index.html');
    if (require('fs').existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.send('<h1>SERVICE_NAME Service</h1><p>Public files not found</p>');
    }
});

app.listen(port, () => {
    console.log(`SERVICE_NAME listening on port ${port}`);
});
EOF
)
        index_js_content=$(echo "$index_js_content" | sed "s/SERVICE_NAME/$service_name/g")
    fi
    
    # 创建ConfigMap，包含所有文件
    kubectl delete configmap $service_name-full -n $NAMESPACE 2>/dev/null || true
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    # 复制服务文件
    if [ -d "services/$service_name" ]; then
        cp -r services/$service_name/* $temp_dir/
    fi
    
    # 创建ConfigMap从目录
    kubectl create configmap $service_name-full \
        --from-file=$temp_dir \
        -n $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # 清理临时目录
    rm -rf $temp_dir
    
    show_progress "$service_name ConfigMap创建完成"
}

# 部署服务的函数
deploy_service() {
    local service_name=$1
    local port=$2
    local nodePort=$3
    
    echo -e "${YELLOW}部署 $service_name...${NC}"
    
    # 创建包含完整代码的ConfigMap
    create_full_service_configmap $service_name $port
    
    # 创建Deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service_name
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $service_name
  template:
    metadata:
      labels:
        app: $service_name
    spec:
      initContainers:
      - name: setup
        image: node:18-alpine
        command: ['sh', '-c']
        args:
          - |
            echo "Setting up $service_name..."
            
            # 复制所有文件从ConfigMap
            cp -r /config/* /app/
            cd /app
            
            # 设置权限
            chmod -R 755 /app
            
            # 如果有public目录，确保它存在
            if [ ! -d public ]; then
                mkdir -p public
            fi
            
            # 创建package.json如果不存在
            if [ ! -f package.json ]; then
                cat > package.json <<'PKG_EOF'
            {
              "name": "$service_name",
              "version": "1.0.0",
              "main": "index.js",
              "scripts": {
                "start": "node index.js"
              },
              "dependencies": {
                "express": "^4.18.2",
                "path": "^0.12.7",
                "redis": "^4.6.5",
                "cors": "^2.8.5",
                "axios": "^1.4.0",
                "jsonwebtoken": "^9.0.0",
                "bcryptjs": "^2.4.3"
              }
            }
            PKG_EOF
            fi
            
            # 安装依赖（使用国内镜像）
            npm config set registry https://registry.npmmirror.com/
            npm install --production --no-audit --no-fund
            
            echo "Setup completed for $service_name"
            ls -la /app/
        volumeMounts:
        - name: config
          mountPath: /config
        - name: app
          mountPath: /app
      containers:
      - name: $service_name
        image: node:18-alpine
        workingDir: /app
        command: ["npm", "start"]
        ports:
        - containerPort: $port
        env:
        - name: PORT
          value: "$port"
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: JWT_SECRET
          value: "cloud-shop-secret-key-2024"
        volumeMounts:
        - name: app
          mountPath: /app
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
            port: $port
          initialDelaySeconds: 90
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: $port
          initialDelaySeconds: 60
          periodSeconds: 10
      volumes:
      - name: config
        configMap:
          name: $service_name-full
      - name: app
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: $service_name
  namespace: $NAMESPACE
spec:
  selector:
    app: $service_name
  ports:
  - port: $port
    targetPort: $port
    nodePort: $nodePort
  type: NodePort
EOF
    
    show_progress "$service_name 部署完成"
}

echo "1️⃣  清理旧部署..."
kubectl delete deployments --all -n $NAMESPACE --grace-period=0 --force 2>/dev/null || true
kubectl delete pods --all -n $NAMESPACE --grace-period=0 --force 2>/dev/null || true

echo ""
echo "2️⃣  部署服务..."

# 确保在正确的目录
cd /mnt/c/Users/18362/Documents/augment-projects/2313212/cloud-native-shop || cd /tmp/node-k8s-demo || {
    echo "错误：找不到项目目录"
    exit 1
}

# 部署各服务
deploy_service "user-service" "8081" "30081"
deploy_service "product-service" "8082" "30082"
deploy_service "order-service" "8083" "30083"
deploy_service "dashboard-service" "8084" "30084"

echo ""
echo "3️⃣  等待部署完成..."
sleep 30

kubectl get pods -n $NAMESPACE

echo ""
echo "等待Pod就绪..."
kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s || echo "部分Pod可能需要更多时间"

echo ""
echo "4️⃣  验证服务..."

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "🌐 服务地址："
echo "用户服务: http://$NODE_IP:30081"
echo "商品服务: http://$NODE_IP:30082"
echo "订单服务: http://$NODE_IP:30083"
echo "监控面板: http://$NODE_IP:30084"

echo ""
echo "💡 调试命令："
echo "查看Pod: kubectl get pods -n $NAMESPACE"
echo "查看日志: kubectl logs <pod-name> -n $NAMESPACE"
echo "查看Init日志: kubectl logs <pod-name> -c setup -n $NAMESPACE"
echo "进入Pod: kubectl exec -it <pod-name> -n $NAMESPACE -- sh"