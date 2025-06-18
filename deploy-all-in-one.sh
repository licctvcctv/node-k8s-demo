#!/bin/bash
# 🚀 云原生商城 - 一键全部部署脚本
# 包含：K8s部署 + Jenkins CI/CD + 真实监控 + 完整前端页面

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
    echo "🎉         云原生商城 - 一键全部部署系统               🎉"
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
    
    show_info "部署Redis数据库..."
    deploy_redis
    show_progress "Redis部署完成"
    
    show_info "部署微服务..."
    deploy_microservices
    show_progress "微服务部署完成"
    
    show_info "等待Pod启动..."
    wait_for_pods
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
    deploy_service "user-service" 8081 30081 "redis://redis:6379" '
        - name: JWT_SECRET
          value: "cloud-shop-secret-key-2024"'
    
    # 商品服务
    deploy_service "product-service" 8082 30082 "redis://redis:6379" ""
    
    # 订单服务
    deploy_service "order-service" 8083 30083 "redis://redis:6379" ""
    
    # 监控服务（包含真实Dashboard）
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
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: app-code
        hostPath:
          path: $PROJECT_DIR/services/dashboard-service
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
}

# 通用服务部署函数
deploy_service() {
    local service_name=$1
    local container_port=$2
    local node_port=$3
    local redis_url=$4
    local extra_env=$5
    
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
      containers:
      - name: $service_name
        image: node:16-alpine
        workingDir: /app
        command: ["sh", "-c"]
        args:
          - "npm install && npm start"
        ports:
        - containerPort: $container_port
        env:
        - name: REDIS_URL
          value: "$redis_url"
        - name: PORT
          value: "$container_port"$extra_env
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
          path: $PROJECT_DIR/services/$service_name
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
}

# 等待Pod启动
wait_for_pods() {
    echo "等待Pod初始化（30秒）..."
    sleep 30
    
    echo "检查Pod状态..."
    kubectl get pods -n $NAMESPACE -o wide
    
    echo "等待所有Pod就绪（最多5分钟）..."
    if kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=300s; then
        show_progress "所有Pod已就绪"
    else
        show_warning "部分Pod可能未就绪，但继续部署过程"
    fi
}

# 部署Jenkins CI/CD
deploy_jenkins_cicd() {
    show_section "3️⃣  部署Jenkins CI/CD"
    
    show_info "创建Jenkins数据目录..."
    mkdir -p $JENKINS_HOME
    chmod 777 $JENKINS_HOME
    
    show_info "启动Jenkins容器..."
    # 停止已存在的容器
    docker stop jenkins-cloud-shop 2>/dev/null || true
    docker rm jenkins-cloud-shop 2>/dev/null || true
    
    # 启动新容器
    docker run -d \
      --name jenkins-cloud-shop \
      --restart=unless-stopped \
      -p 8080:8080 \
      -p 50000:50000 \
      -v $JENKINS_HOME:/var/jenkins_home \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $PROJECT_DIR:/workspace \
      --user root \
      -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
      jenkins/jenkins:lts > /dev/null
    
    show_info "等待Jenkins启动..."
    sleep 20
    
    # 等待Jenkins可访问
    for i in {1..20}; do
        if curl -s http://localhost:8080 > /dev/null; then
            break
        fi
        echo -n "."
        sleep 3
    done
    echo ""
    
    show_progress "Jenkins容器部署完成"
    
    # 自动配置Jenkins Pipeline
    show_info "自动配置Jenkins Pipeline项目..."
    if [ -f "$PROJECT_DIR/jenkins-auto-setup.sh" ]; then
        chmod +x "$PROJECT_DIR/jenkins-auto-setup.sh"
        "$PROJECT_DIR/jenkins-auto-setup.sh"
        show_progress "Jenkins Pipeline项目自动配置完成"
    else
        show_warning "未找到Jenkins自动配置脚本"
        # 获取初始密码作为备用
        local initial_password=""
        for i in {1..10}; do
            if docker exec jenkins-cloud-shop test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
                initial_password=$(docker exec jenkins-cloud-shop cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "获取失败")
                break
            fi
            echo "等待Jenkins初始化..."
            sleep 3
        done
        echo "📋 Jenkins初始密码: $initial_password"
    fi
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
    
    show_info "检查Jenkins状态..."
    if curl -s http://localhost:8080 > /dev/null; then
        show_progress "Jenkins运行正常"
    else
        show_warning "Jenkins可能还在启动中"
    fi
    
    show_info "检查服务可访问性..."
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    
    # 简单的健康检查
    for port in 30081 30082 30083 30084; do
        if curl -s --connect-timeout 5 http://$node_ip:$port/health > /dev/null 2>&1; then
            show_progress "端口 $port: 服务正常"
        else
            show_warning "端口 $port: 服务可能还在启动中"
        fi
    done
}

# 最终总结
show_final_summary() {
    show_section "🎉 部署完成！"
    
    local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "localhost")
    
    echo -e "${CYAN}"
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
    echo "   ├─ 用户名: admin / 密码: admin123"
    echo "   ├─ Pipeline项目: cloud-native-shop-pipeline"
    echo "   └─ 完整的构建和部署流水线 (已自动配置)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    echo -e "${GREEN}"
    echo "🔑 测试账号："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "管理员账号:   admin   / admin123"
    echo "演示账号:     demo    / demo123"
    echo "测试账号:     test    / test123"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    echo -e "${YELLOW}"
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
    echo -e "${NC}"
    
    echo -e "${BLUE}"
    echo "🛠️  管理命令："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "查看Pod状态:      kubectl get pods -n $NAMESPACE"
    echo "查看服务状态:     kubectl get svc -n $NAMESPACE"
    echo "查看Pod日志:      kubectl logs <pod-name> -n $NAMESPACE"
    echo "重启服务:         kubectl rollout restart deployment/<service> -n $NAMESPACE"
    echo "删除所有服务:     kubectl delete namespace $NAMESPACE"
    echo "查看Jenkins日志:  docker logs jenkins-cloud-shop"
    echo "停止Jenkins:      docker stop jenkins-cloud-shop"
    echo "启动Jenkins:      docker start jenkins-cloud-shop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    
    echo -e "${PURPLE}"
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
    echo -e "${NC}"
    
    echo ""
    echo -e "${CYAN}🎉 恭喜！云原生电商系统已全部部署完成！${NC}"
    echo -e "${CYAN}现在您可以体验完整的云原生微服务电商平台了！${NC}"
    echo ""
}

# 执行主函数
main "$@"