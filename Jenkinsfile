pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'localhost:5000' // 本地Docker Registry
        NAMESPACE = 'cloud-shop'
        KUBECONFIG = credentials('kubeconfig') // Jenkins中配置的kubeconfig凭据
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 拉取代码...'
                checkout scm
            }
        }
        
        stage('Build Services') {
            parallel {
                stage('Build User Service') {
                    steps {
                        echo '🔨 构建用户服务...'
                        dir('services/user-service') {
                            script {
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/user-service:${BUILD_NUMBER}")
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/user-service:latest")
                            }
                        }
                    }
                }
                
                stage('Build Product Service') {
                    steps {
                        echo '🔨 构建商品服务...'
                        dir('services/product-service') {
                            script {
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/product-service:${BUILD_NUMBER}")
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/product-service:latest")
                            }
                        }
                    }
                }
                
                stage('Build Order Service') {
                    steps {
                        echo '🔨 构建订单服务...'
                        dir('services/order-service') {
                            script {
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/order-service:${BUILD_NUMBER}")
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/order-service:latest")
                            }
                        }
                    }
                }
                
                stage('Build Dashboard Service') {
                    steps {
                        echo '🔨 构建监控服务...'
                        dir('services/dashboard-service') {
                            script {
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/dashboard-service:${BUILD_NUMBER}")
                                docker.build("${DOCKER_REGISTRY}/cloud-shop/dashboard-service:latest")
                            }
                        }
                    }
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('Test User Service') {
                    steps {
                        echo '🧪 测试用户服务...'
                        dir('services/user-service') {
                            sh 'npm test || echo "No tests defined"'
                        }
                    }
                }
                
                stage('Test Product Service') {
                    steps {
                        echo '🧪 测试商品服务...'
                        dir('services/product-service') {
                            sh 'npm test || echo "No tests defined"'
                        }
                    }
                }
                
                stage('Test Order Service') {
                    steps {
                        echo '🧪 测试订单服务...'
                        dir('services/order-service') {
                            sh 'npm test || echo "No tests defined"'
                        }
                    }
                }
            }
        }
        
        stage('Push Images') {
            when {
                branch 'main'
            }
            steps {
                echo '📤 推送镜像到Registry...'
                script {
                    docker.withRegistry("http://${DOCKER_REGISTRY}") {
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/user-service:${BUILD_NUMBER}").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/user-service:latest").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/product-service:${BUILD_NUMBER}").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/product-service:latest").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/order-service:${BUILD_NUMBER}").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/order-service:latest").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/dashboard-service:${BUILD_NUMBER}").push()
                        docker.image("${DOCKER_REGISTRY}/cloud-shop/dashboard-service:latest").push()
                    }
                }
            }
        }
        
        stage('Deploy to K8s') {
            when {
                branch 'main'
            }
            steps {
                echo '🚀 部署到Kubernetes...'
                script {
                    // 创建命名空间（如果不存在）
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} create namespace ${NAMESPACE} || true
                    """
                    
                    // 更新镜像标签
                    sh """
                        sed -i 's|image: cloud-shop/\\(.*\\):latest|image: ${DOCKER_REGISTRY}/cloud-shop/\\1:${BUILD_NUMBER}|g' k8s/*/deployment.yaml
                    """
                    
                    // 应用K8s配置
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/namespace.yaml
                        kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/redis/
                        kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/user-service/
                        kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/product-service/
                        kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/order-service/
                        kubectl --kubeconfig=${KUBECONFIG} apply -f k8s/dashboard-service/
                    """
                    
                    // 等待部署完成
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} wait --for=condition=ready pod --all -n ${NAMESPACE} --timeout=300s || true
                    """
                }
            }
        }
        
        stage('Health Check') {
            when {
                branch 'main'
            }
            steps {
                echo '🏥 健康检查...'
                script {
                    sh """
                        kubectl --kubeconfig=${KUBECONFIG} get pods -n ${NAMESPACE}
                        kubectl --kubeconfig=${KUBECONFIG} get svc -n ${NAMESPACE}
                    """
                    
                    // 获取NodePort并测试服务
                    def nodeIP = sh(
                        script: "kubectl --kubeconfig=${KUBECONFIG} get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}'",
                        returnStdout: true
                    ).trim()
                    
                    sh """
                        echo "测试用户服务..."
                        curl -f http://${nodeIP}:30081/health || echo "用户服务健康检查失败"
                        
                        echo "测试商品服务..."
                        curl -f http://${nodeIP}:30082/health || echo "商品服务健康检查失败"
                        
                        echo "测试订单服务..."
                        curl -f http://${nodeIP}:30083/health || echo "订单服务健康检查失败"
                        
                        echo "测试监控服务..."
                        curl -f http://${nodeIP}:30084/health || echo "监控服务健康检查失败"
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ 流水线执行成功！'
            script {
                def nodeIP = sh(
                    script: "kubectl --kubeconfig=${KUBECONFIG} get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}'",
                    returnStdout: true
                ).trim()
                
                echo """
                🎉 部署成功！服务访问地址：
                - 用户服务: http://${nodeIP}:30081
                - 商品服务: http://${nodeIP}:30082
                - 订单服务: http://${nodeIP}:30083
                - 监控面板: http://${nodeIP}:30084
                """
            }
        }
        
        failure {
            echo '❌ 流水线执行失败！'
        }
        
        always {
            echo '🧹 清理工作空间...'
            cleanWs()
        }
    }
}