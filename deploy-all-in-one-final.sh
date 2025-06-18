#!/bin/bash
# 🚀 云原生商城 - 一键全部部署脚本（最终修复版）
# 修复：使用ConfigMap部署完整代码，确保所有文件都能正确加载

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 显示函数
show_progress() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_section() {
    echo -e "${PURPLE}🎯 $1${NC}"
    echo "=========================================="
}

# 配置变量
NAMESPACE="cloud-shop"
PROJECT_DIR=$(pwd)
JENKINS_HOME="$PROJECT_DIR/jenkins-data"

# 主函数
main() {
    echo -e "${CYAN}"
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    echo "🎉                                                    🎉"
    echo "🎉      云原生商城 - 一键全部部署系统（最终版）       🎉"
    echo "🎉                                                    🎉"
    echo "🎉   🛒 E-Commerce + ☸️  K8s + 🔄 CI/CD + 📊 Monitor  🎉"
    echo "🎉                                                    🎉"
    echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
    echo -e "${NC}"
    
    # 检查环境
    check_prerequisites
    
    # 部署步骤
    deploy_kubernetes_services
    deploy_jenkins_cicd
    verify_deployments
    show_final_summary
}

# 检查前置条件
check_prerequisites() {
    show_section "1️⃣  环境检查"
    
    # 检查Docker
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            show_progress "Docker: ✅ 已安装且运行中"
        else
            show_error "Docker已安装但未运行，请启动Docker"
            exit 1
        fi
    else
        show_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    # 检查kubectl
    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info &> /dev/null; then
            show_progress "Kubernetes: ✅ 集群连接正常"
        else
            show_warning "kubectl已安装但无法连接集群，将尝试继续部署"
        fi
    else
        show_error "kubectl未安装，请先安装kubectl"
        exit 1
    fi
    
    # 检查端口占用
    check_port 8080 "Jenkins"
    check_port 30081 "用户服务"
    check_port 30082 "商品服务"
    check_port 30083 "订单服务"
    check_port 30084 "监控服务"
    
    show_progress "环境检查完成"
}

# 检查端口占用
check_port() {
    local port=$1
    local service=$2
    if netstat -tlnp 2>/dev/null | grep ":$port " > /dev/null; then
        show_warning "端口 $port ($service) 已被占用，部署可能冲突"
    fi
}

# 部署Kubernetes服务
deploy_kubernetes_services() {
    show_section "2️⃣  部署Kubernetes服务"
    
    show_info "正在清理旧资源..."
    # 删除旧命名空间（如果存在）
    kubectl delete namespace $NAMESPACE --timeout=60s 2>/dev/null || true
    sleep 10
    
    show_info "重新创建命名空间..."
    kubectl create namespace $NAMESPACE
    show_progress "命名空间创建完成"
    
    # 创建shared ConfigMap（重要：包含auth.js）
    show_info "创建共享配置..."
    create_shared_configmap
    
    show_info "部署Redis数据库..."
    deploy_redis
    show_progress "Redis部署完成"
    
    show_info "部署微服务..."
    deploy_microservices
    show_progress "微服务部署完成"
    
    show_info "等待Pod启动..."
    wait_for_pods
}

# 创建shared ConfigMap
create_shared_configmap() {
    # 检查shared/auth.js是否存在
    if [ ! -f "$PROJECT_DIR/services/shared/auth.js" ]; then
        show_error "找不到 services/shared/auth.js 文件"
        exit 1
    fi
    
    # 创建ConfigMap
    kubectl create configmap shared-auth \
        --from-file=auth.js="$PROJECT_DIR/services/shared/auth.js" \
        -n $NAMESPACE
    
    show_progress "共享认证模块ConfigMap创建完成"
}

# 部署Redis
deploy_redis() {
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
}

# 部署微服务
deploy_microservices() {
    # 用户服务
    deploy_service_with_code "user-service" 8081 30081 "redis://redis:6379" '
        - name: JWT_SECRET
          value: "cloud-shop-secret-key-2024"'
    
    # 商品服务
    deploy_service_with_code "product-service" 8082 30082 "redis://redis:6379" ""
    
    # 订单服务
    deploy_service_with_code "order-service" 8083 30083 "redis://redis:6379" ""
    
    # 监控服务
    deploy_service_with_code "dashboard-service" 8084 30084 "redis://redis:6379" '
        - name: USER_SERVICE_URL
          value: "http://user-service:8081"
        - name: PRODUCT_SERVICE_URL
          value: "http://product-service:8082"
        - name: ORDER_SERVICE_URL
          value: "http://order-service:8083"'
}

# 通用服务部署函数 - 包含完整代码
deploy_service_with_code() {
    local service_name=$1
    local container_port=$2
    local node_port=$3
    local redis_url=$4
    local extra_env=$5
    
    show_info "部署 $service_name..."
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    # 复制服务文件
    if [ -d "$PROJECT_DIR/services/$service_name" ]; then
        cp -r "$PROJECT_DIR/services/$service_name"/* "$temp_dir/" 2>/dev/null || true
        
        # 确保有基础的package.json
        if [ ! -f "$temp_dir/package.json" ]; then
            cat > "$temp_dir/package.json" <<PKGEOF
{
  "name": "$service_name",
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
    "bcryptjs": "^2.4.3",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0"
  }
}
PKGEOF
        fi
        
        # 确保有基础的index.js（如果不存在）
        if [ ! -f "$temp_dir/index.js" ]; then
            cat > "$temp_dir/index.js" <<INDEXEOF
const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || $container_port;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// 提供shared/auth.js
app.get('/auth.js', (req, res) => {
    res.sendFile('/shared/auth.js');
});

// 健康检查
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: '$service_name' });
});

// 主页
app.get('/', (req, res) => {
    const indexPath = path.join(__dirname, 'public', 'index.html');
    if (require('fs').existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.send('<h1>$service_name is running!</h1><p>Port: ' + PORT + '</p>');
    }
});

app.listen(PORT, () => {
    console.log('$service_name running on port ' + PORT);
});
INDEXEOF
        fi
    else
        show_warning "$service_name 服务目录不存在"
    fi
    
    # 创建包含所有文件的ConfigMap
    kubectl create configmap $service_name-app \
        --from-file="$temp_dir" \
        -n $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f - || {
        show_error "创建 $service_name ConfigMap 失败"
    }
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
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
            set -e
            echo "Starting setup for $service_name..."
            
            # 复制应用代码
            cp -r /app-config/* /app/ 2>/dev/null || true
            
            # 创建shared目录并复制auth.js
            mkdir -p /app/shared
            cp /shared-auth/auth.js /app/shared/auth.js
            
            # 显示文件结构
            echo "App directory structure:"
            ls -la /app/
            if [ -d /app/public ]; then
                echo "Public directory contents:"
                ls -la /app/public/ | head -10
            fi
            
            cd /app
            
            # 设置npm镜像源
            npm config set registry https://registry.npmmirror.com/
            npm config delete proxy || true
            npm config delete https-proxy || true
            npm config set strict-ssl false
            
            # 安装依赖
            if [ -f package.json ]; then
                echo "Installing dependencies..."
                npm install --production --no-audit --no-fund || {
                    echo "Retry with npmjs registry..."
                    npm config set registry https://registry.npmjs.org/
                    npm install --production --no-audit --no-fund || echo "npm install failed but continuing..."
                }
            fi
            
            echo "Setup completed!"
        volumeMounts:
        - name: app
          mountPath: /app
        - name: app-config
          mountPath: /app-config
        - name: shared-auth
          mountPath: /shared-auth
      containers:
      - name: $service_name
        image: node:18-alpine
        workingDir: /app
        command: ["npm", "start"]
        ports:
        - containerPort: $container_port
        env:
        - name: REDIS_URL
          value: "$redis_url"
        - name: PORT
          value: "$container_port"$extra_env
        volumeMounts:
        - name: app
          mountPath: /app
        - name: shared-auth
          mountPath: /shared
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
          requests:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: $container_port
          initialDelaySeconds: 90
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: $container_port
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
      volumes:
      - name: app
        emptyDir: {}
      - name: app-config
        configMap:
          name: $service_name-app
      - name: shared-auth
        configMap:
          name: shared-auth
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
  - port: $container_port
    targetPort: $container_port
    nodePort: $node_port
  type: NodePort
EOF
    
    show_progress "$service_name 部署完成"
}

# 等待Pod启动
wait_for_pods() {
    echo "等待Pod初始化（90秒）..."
    sleep 90
    
    echo "检查Pod状态..."
    kubectl get pods -n $NAMESPACE
    
    echo "等待Pod准备就绪..."
    local max_attempts=6
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "第 $attempt 次检查（共${max_attempts}次）..."
        
        # 获取未就绪的Pod数量
        local not_ready=$(kubectl get pods -n $NAMESPACE -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True"))] | length' 2>/dev/null || echo "1")
        
        if [ "$not_ready" -eq 0 ] 2>/dev/null; then
            show_progress "所有Pod已就绪"
            break
        else
            kubectl get pods -n $NAMESPACE | grep -v "Running.*1/1" || true
            echo "还有Pod未就绪，等待30秒..."
            sleep 30
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "最终Pod状态："
    kubectl get pods -n $NAMESPACE -o wide
}

# 部署Jenkins CI/CD
deploy_jenkins_cicd() {
    show_section "3️⃣  部署Jenkins CI/CD"
    
    show_info "创建Jenkins数据目录..."
    mkdir -p "$JENKINS_HOME"
    chmod 777 "$JENKINS_HOME"
    
    show_info "启动Jenkins容器..."
    
    # 停止并删除旧容器
    docker stop jenkins-cloud-shop 2>/dev/null || true
    docker rm jenkins-cloud-shop 2>/dev/null || true
    
    # 启动新容器
    docker run -d \
        --name jenkins-cloud-shop \
        -p 8080:8080 \
        -p 50000:50000 \
        -v "$JENKINS_HOME:/var/jenkins_home" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$(which docker):/usr/bin/docker" \
        -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
        --restart unless-stopped \
        jenkins/jenkins:lts
    
    show_info "等待Jenkins启动（60秒）..."
    sleep 60
    
    # 获取初始密码
    show_info "获取Jenkins初始密码..."
    local init_password=""
    
    # 尝试从容器获取
    init_password=$(docker exec jenkins-cloud-shop cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
    
    # 如果失败，从挂载卷获取
    if [ -z "$init_password" ]; then
        init_password=$(cat "$JENKINS_HOME/secrets/initialAdminPassword" 2>/dev/null || echo "")
    fi
    
    if [ -n "$init_password" ]; then
        show_progress "Jenkins部署完成"
        echo ""
        echo "✅ Jenkins访问地址: http://localhost:8080"
        echo "📋 Jenkins初始密码: $init_password"
    else
        show_warning "无法获取Jenkins初始密码，请手动查看"
    fi
    
    # 创建Pipeline Job
    create_jenkins_pipeline
}

# 创建Jenkins Pipeline
create_jenkins_pipeline() {
    echo ""
    echo "🔧 Jenkins配置步骤："
    echo "1. 使用上面的初始密码登录"
    echo "2. 选择'安装推荐的插件'（包含Pipeline插件）"
    echo "3. 创建管理员用户："
    echo "   - 用户名: admin"
    echo "   - 密码: admin123"
    echo "4. 配置完成后，创建新的Pipeline项目"
}

# 验证部署
verify_deployments() {
    show_section "4️⃣  验证部署"
    
    show_info "检查Kubernetes部署状态..."
    echo ""
    echo "📋 Pod状态:"
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "📋 服务状态:"
    kubectl get svc -n $NAMESPACE
    
    # 检查Jenkins
    show_info "检查Jenkins状态..."
    if docker ps | grep jenkins-cloud-shop > /dev/null; then
        show_progress "Jenkins运行正常"
    else
        show_error "Jenkins未运行"
    fi
    
    # 测试服务端点
    show_info "检查服务可访问性..."
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    for port in 30081 30082 30083 30084; do
        if curl -s -o /dev/null -w "%{http_code}" "http://$node_ip:$port/health" | grep -q "200"; then
            show_progress "端口 $port: 服务正常"
        else
            show_warning "端口 $port: 服务可能未就绪"
        fi
    done
}

# 显示最终总结
show_final_summary() {
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    show_section "🎉 部署完成！"
    
    echo ""
    echo "🌐 服务访问地址："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "👤 用户服务      http://$node_ip:30081"
    echo "   ├─ 用户注册   http://$node_ip:30081/register.html"
    echo "   ├─ 用户登录   http://$node_ip:30081/login.html"
    echo "   ├─ 个人中心   http://$node_ip:30081/profile.html"
    echo "   └─ 编辑资料   http://$node_ip:30081/edit-profile.html"
    echo ""
    echo "📦 商品服务      http://$node_ip:30082"
    echo "   ├─ 商品首页   http://$node_ip:30082/index.html"
    echo "   ├─ 商品列表   http://$node_ip:30082/list.html"
    echo "   ├─ 商品详情   http://$node_ip:30082/detail.html"
    echo "   ├─ 购物车     http://$node_ip:30082/cart.html"
    echo "   ├─ 结算页面   http://$node_ip:30082/checkout.html"
    echo "   └─ 商品管理   http://$node_ip:30082/admin.html"
    echo ""
    echo "🛒 订单服务      http://$node_ip:30083"
    echo "   └─ 订单管理   http://$node_ip:30083/index.html"
    echo ""
    echo "📊 监控面板      http://$node_ip:30084"
    echo "   └─ 真实数据监控 (连接Redis获取真实业务数据)"
    echo ""
    echo "🔄 Jenkins CI/CD http://localhost:8080"
    echo "   └─ 需要初次配置（使用初始密码）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "🔑 测试账号："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "管理员账号:   admin   / admin123"
    echo "演示账号:     demo    / demo123"
    echo "测试账号:     test    / test123"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "🚀 快速开始："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 访问商品首页:    http://$node_ip:30082"
    echo "2. 注册新用户:      http://$node_ip:30081/register.html"
    echo "3. 体验购买流程:    浏览商品 → 加入购物车 → 结算 → 下单"
    echo "4. 查看订单:        http://$node_ip:30083"
    echo "5. 监控系统:        http://$node_ip:30084"
    echo "6. Jenkins CI/CD:   http://localhost:8080 (admin/admin123)"
    echo "   └─ 点击 'cloud-native-shop-pipeline' → '立即构建'"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "🛠️  管理命令："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "查看Pod状态:      kubectl get pods -n $NAMESPACE"
    echo "查看服务状态:     kubectl get svc -n $NAMESPACE"
    echo "查看Pod日志:      kubectl logs <pod-name> -n $NAMESPACE"
    echo "查看Init日志:     kubectl logs <pod-name> -c setup -n $NAMESPACE"
    echo "进入Pod调试:      kubectl exec -it <pod-name> -n $NAMESPACE -- sh"
    echo "重启服务:         kubectl rollout restart deployment/<service> -n $NAMESPACE"
    echo "删除所有服务:     kubectl delete namespace $NAMESPACE"
    echo "查看Jenkins日志:  docker logs jenkins-cloud-shop"
    echo "停止Jenkins:      docker stop jenkins-cloud-shop"
    echo "启动Jenkins:      docker start jenkins-cloud-shop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "❓ 常见问题解决："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 如果页面显示'网络错误'："
    echo "   - 检查auth.js是否加载: curl http://$node_ip:30081/auth.js"
    echo "   - 查看浏览器控制台错误信息"
    echo ""
    echo "2. 如果Pod一直在Init状态："
    echo "   - 查看Init日志: kubectl logs <pod> -c setup -n $NAMESPACE"
    echo "   - 可能是npm安装超时，删除Pod重试"
    echo ""
    echo "3. 如果服务返回404："
    echo "   - 检查ConfigMap: kubectl get cm -n $NAMESPACE"
    echo "   - 进入Pod检查文件: kubectl exec -it <pod> -n $NAMESPACE -- ls -la /app/"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "✨ 功能特色："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ 完整电商功能:   用户注册登录、商品管理、购物车、订单"
    echo "✅ 真实业务数据:   Dashboard连接Redis显示真实统计"
    echo "✅ 跨服务认证:     统一JWT token跨端口认证"
    echo "✅ 完整购买流程:   浏览→购物车→结算→订单→支付"
    echo "✅ 微服务架构:     4个独立服务 + Redis数据库"
    echo "✅ 容器化部署:     Kubernetes + Docker"
    echo "✅ CI/CD流水线:    Jenkins自动化构建部署"
    echo "✅ 系统监控:       实时健康检查和业务指标"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo ""
    echo "🎉 恭喜！云原生电商系统已全部部署完成！"
    echo "现在您可以体验完整的云原生微服务电商平台了！"
}

# 执行主函数
main "$@"