#!/bin/bash
# 调试npm安装问题的脚本

set -e

echo "🔍 npm安装问题调试脚本"
echo "========================"

# 检查必要的工具
check_tools() {
    echo "📋 检查必要工具..."
    
    if command -v docker &> /dev/null; then
        echo "✅ Docker: 可用"
        DOCKER_AVAILABLE=true
    else
        echo "❌ Docker: 不可用"
        DOCKER_AVAILABLE=false
    fi
    
    if command -v kubectl &> /dev/null; then
        echo "✅ kubectl: 可用"
        KUBECTL_AVAILABLE=true
    else
        echo "❌ kubectl: 不可用"
        KUBECTL_AVAILABLE=false
    fi
}

# 测试Docker环境下的npm安装
test_docker_npm() {
    if [ "$DOCKER_AVAILABLE" = false ]; then
        echo "⚠️  Docker不可用，跳过Docker测试"
        return
    fi
    
    echo ""
    echo "🐳 测试Docker环境下的npm安装..."
    
    # 创建临时目录
    TEMP_DIR="/tmp/npm-docker-test"
    mkdir -p "$TEMP_DIR"
    
    # 复制package.json到临时目录
    cp services/user-service/package.json "$TEMP_DIR/"
    
    # 测试npm安装
    docker run --rm -v "$TEMP_DIR:/test" node:18-alpine sh -c "
        cd /test
        echo '🔧 开始npm安装测试...'
        
        echo 'Node版本:' \$(node --version)
        echo 'npm版本:' \$(npm --version)
        
        # 清理和配置
        npm cache clean --force
        rm -f package-lock.json
        
        # 配置npm
        npm config set registry https://registry.npmjs.org/
        npm config set strict-ssl false
        npm config set fetch-retry-mintimeout 20000
        npm config set fetch-retry-maxtimeout 120000
        npm config set fetch-retries 3
        
        # 升级npm
        npm install -g npm@latest
        echo '升级后npm版本:' \$(npm --version)
        
        # 安装依赖
        echo '📦 安装依赖...'
        npm install --production --no-audit --no-fund --verbose
        
        # 验证结果
        if [ -d node_modules ]; then
            echo '✅ node_modules创建成功'
            echo '安装的包数量:' \$(ls node_modules | wc -l)
            
            # 检查关键模块
            for module in express redis cors jsonwebtoken bcryptjs; do
                if [ -d \"node_modules/\$module\" ]; then
                    echo \"✅ \$module 已安装\"
                else
                    echo \"❌ \$module 缺失\"
                fi
            done
        else
            echo '❌ node_modules未创建'
            exit 1
        fi
    "
    
    echo "✅ Docker npm测试完成"
    rm -rf "$TEMP_DIR"
}

# 检查当前Kubernetes Pod状态
check_k8s_pods() {
    if [ "$KUBECTL_AVAILABLE" = false ]; then
        echo "⚠️  kubectl不可用，跳过Kubernetes检查"
        return
    fi
    
    echo ""
    echo "☸️  检查Kubernetes Pod状态..."
    
    if kubectl get namespace cloud-shop &> /dev/null; then
        echo "📋 云商城命名空间存在，检查Pod状态:"
        kubectl get pods -n cloud-shop -o wide
        
        echo ""
        echo "📋 检查有问题的Pod日志:"
        # 获取CrashLoopBackOff的Pod
        PROBLEM_PODS=$(kubectl get pods -n cloud-shop --no-headers | grep -E "(CrashLoopBackOff|Error|ImagePullBackOff)" | awk '{print $1}' || echo "")
        
        if [ ! -z "$PROBLEM_PODS" ]; then
            for pod in $PROBLEM_PODS; do
                echo "🔍 Pod $pod 的日志:"
                kubectl logs "$pod" -n cloud-shop --tail=30 || true
                echo "---"
            done
        else
            echo "✅ 没有发现问题的Pod"
        fi
    else
        echo "ℹ️  云商城命名空间不存在"
    fi
}

# 测试网络连接
test_network() {
    echo ""
    echo "🌐 测试网络连接..."
    
    # 测试npm registry连接
    if curl -s --connect-timeout 10 https://registry.npmjs.org/express > /dev/null; then
        echo "✅ npm registry (HTTPS): 可访问"
    else
        echo "❌ npm registry (HTTPS): 不可访问"
        
        # 尝试HTTP
        if curl -s --connect-timeout 10 http://registry.npmjs.org/express > /dev/null; then
            echo "✅ npm registry (HTTP): 可访问"
        else
            echo "❌ npm registry (HTTP): 不可访问"
        fi
    fi
    
    # 测试镜像仓库
    if curl -s --connect-timeout 10 https://registry.npmmirror.com/express > /dev/null; then
        echo "✅ 淘宝镜像: 可访问"
    else
        echo "❌ 淘宝镜像: 不可访问"
    fi
}

# 生成调试报告
generate_debug_report() {
    echo ""
    echo "📊 生成调试报告..."
    
    REPORT_FILE="npm-debug-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "npm安装问题调试报告"
        echo "生成时间: $(date)"
        echo "========================"
        echo ""
        
        echo "环境信息:"
        echo "- 系统: $(uname -a)"
        echo "- Docker可用: $DOCKER_AVAILABLE"
        echo "- kubectl可用: $KUBECTL_AVAILABLE"
        echo ""
        
        echo "服务package.json检查:"
        for service in user-service product-service order-service dashboard-service; do
            if [ -f "services/$service/package.json" ]; then
                echo "✅ $service: package.json存在"
            else
                echo "❌ $service: package.json缺失"
            fi
        done
        
    } > "$REPORT_FILE"
    
    echo "📋 调试报告已保存到: $REPORT_FILE"
}

# 主函数
main() {
    check_tools
    test_network
    test_docker_npm
    check_k8s_pods
    generate_debug_report
    
    echo ""
    echo "🎯 调试完成！"
    echo ""
    echo "📋 总结:"
    echo "- 如果Docker npm测试通过，说明修复方案有效"
    echo "- 如果Kubernetes Pod仍有问题，请检查Pod日志"
    echo "- 如果网络连接有问题，可能需要配置代理"
    echo ""
    echo "🔧 下一步:"
    echo "1. 在有Docker/kubectl环境下运行此脚本"
    echo "2. 根据测试结果调整配置"
    echo "3. 运行 ./deploy-all-in-one.sh 重新部署"
}

# 执行主函数
main "$@"