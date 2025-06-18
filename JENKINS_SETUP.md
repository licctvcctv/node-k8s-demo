# Jenkins CI/CD 配置指南

## 🚀 概述
本项目包含完整的Jenkins CI/CD流水线配置，支持自动构建、测试和部署微服务到Kubernetes集群。

## 📋 前置要求

### Jenkins服务器需要安装：
- Docker
- kubectl
- Git
- Node.js (用于运行测试)

### Jenkins插件：
- Docker Pipeline
- Kubernetes CLI
- Git
- Pipeline

## 🔧 Jenkins配置步骤

### 1. 创建凭据
在Jenkins中创建以下凭据：

#### kubeconfig凭据
- 类型：Secret file
- ID：kubeconfig
- 描述：Kubernetes集群配置文件
- 文件：上传你的kubeconfig文件

### 2. 创建Pipeline项目
1. 点击"新建任务"
2. 输入项目名称：`cloud-native-shop`
3. 选择"流水线"
4. 点击"确定"

### 3. 配置Pipeline
在"流水线"部分：

#### 方式一：从SCM获取
```
定义：Pipeline script from SCM
SCM：Git
仓库URL：https://github.com/licctvcctv/node-k8s-demo
凭据：选择你的Git凭据
分支：*/main
脚本路径：Jenkinsfile
```

#### 方式二：直接输入脚本
复制`Jenkinsfile.simple`的内容到脚本框中

### 4. 构建触发器（可选）
- ✅ GitHub hook trigger for GITScm polling
- ✅ 定时构建：`H/15 * * * *`（每15分钟检查一次）

## 📊 流水线阶段说明

### 生产环境流水线（Jenkinsfile）
1. **Checkout** - 拉取代码
2. **Build Services** - 并行构建所有服务镜像
3. **Test** - 并行运行测试
4. **Push Images** - 推送镜像到Registry
5. **Deploy to K8s** - 部署到Kubernetes
6. **Health Check** - 健康检查

### 教学演示流水线（Jenkinsfile.simple）
1. **检出代码** - 从Git拉取
2. **代码质量检查** - 检查代码规范
3. **构建镜像** - 构建Docker镜像
4. **运行测试** - 执行测试
5. **部署准备** - 验证配置文件
6. **模拟部署** - 模拟部署过程
7. **部署验证** - 验证部署状态

## 🛠️ 本地测试Jenkins Pipeline

### 使用Docker运行Jenkins
```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

### 获取初始密码
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## 📝 Pipeline语法示例

### 并行构建
```groovy
stage('Build') {
    parallel {
        stage('Service 1') {
            steps {
                sh 'docker build -t service1 .'
            }
        }
        stage('Service 2') {
            steps {
                sh 'docker build -t service2 .'
            }
        }
    }
}
```

### 条件执行
```groovy
stage('Deploy') {
    when {
        branch 'main'
    }
    steps {
        sh 'kubectl apply -f k8s/'
    }
}
```

### 错误处理
```groovy
stage('Test') {
    steps {
        script {
            try {
                sh 'npm test'
            } catch (err) {
                echo "测试失败: ${err}"
            }
        }
    }
}
```

## 🔍 常见问题

### 1. Docker权限问题
将Jenkins用户添加到docker组：
```bash
sudo usermod -aG docker jenkins
sudo service jenkins restart
```

### 2. kubectl权限问题
确保kubeconfig文件具有正确的权限和集群访问权限。

### 3. 镜像推送失败
检查Docker Registry是否可访问，凭据是否正确。

## 📚 参考资源
- [Jenkins Pipeline文档](https://www.jenkins.io/doc/book/pipeline/)
- [Kubernetes插件文档](https://plugins.jenkins.io/kubernetes-cli/)
- [Docker Pipeline插件](https://plugins.jenkins.io/docker-workflow/)

## 🎯 最佳实践
1. 使用多分支Pipeline支持功能分支
2. 实施蓝绿部署或金丝雀发布
3. 添加自动回滚机制
4. 集成代码质量检查工具
5. 实施安全扫描