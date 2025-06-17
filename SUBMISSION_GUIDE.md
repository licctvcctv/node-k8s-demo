# 作业提交指南

## 项目完成度确认

### ✅ 核心要求（必须满足）
- [x] **云原生技术**：使用Docker、K8s、微服务架构
- [x] **用户管理微服务**：完整的登录鉴权功能（JWT）
- [x] **2个业务微服务**：商品管理、订单管理
- [x] **3台虚拟机部署**：Master + 2个Worker节点

### ✅ 技术栈要求
- [x] **容器平台**：Docker + containerd + K3s
- [x] **自动化部署**：Jenkins Pipeline配置
- [x] **监控系统**：Prometheus + Grafana配置
- [x] **脚本语言**：Bash脚本（所有自动化脚本）
- [x] **编程语言**：Node.js（微服务开发）
- [x] **编排语言**：YAML（K8s配置）

## 提交前检查清单

### 1. 运行预检查脚本
```bash
cd cloud-native-shop
./scripts/pre-deploy-check.sh
```

### 2. 本地测试
```bash
# 启动服务
docker-compose up -d

# 运行测试
make test

# API测试
./scripts/test-apis.sh

# 初始化演示数据
./scripts/init-demo-data.sh

# 验证部署
./scripts/validate-deployment.sh
```

### 3. 清理测试环境
```bash
docker-compose down -v
```

## Git提交步骤

### 1. 初始化Git仓库
```bash
cd cloud-native-shop
git init
git add .
git commit -m "Initial commit: Cloud Native Shop microservices project"
```

### 2. 创建GitHub/GitLab仓库
在GitHub或GitLab创建新仓库，不要初始化README

### 3. 推送代码
```bash
git remote add origin <你的仓库地址>
git branch -M main
git push -u origin main
```

## 虚拟机部署步骤

### 1. 准备虚拟机
- 3台CentOS 7虚拟机
- 确保网络互通
- 记录IP地址

### 2. 在Master节点执行
```bash
# 克隆项目
git clone <你的仓库地址>
cd cloud-native-shop

# 安装并部署
./scripts/install-tools.sh
./scripts/install-k3s.sh <master-ip> <worker1-ip> <worker2-ip>
# 按照提示在Worker节点安装K3s

# 部署应用
./scripts/deploy-all.sh

# 验证部署
./scripts/validate-deployment.sh --k8s
```

## 演示准备

### 1. 初始化演示数据
```bash
./scripts/init-demo-data.sh --k8s
```

### 2. 准备演示脚本
```bash
# 显示集群状态
kubectl get nodes
kubectl get pods -n cloud-shop

# 显示服务
kubectl get svc -n cloud-shop

# 访问服务
curl http://<node-ip>:30081/health
curl http://<node-ip>:30082/health
curl http://<node-ip>:30083/health
```

### 3. 演示场景
1. **用户注册和登录**
   - 注册新用户
   - 登录获取JWT Token

2. **商品管理**
   - 查看商品列表
   - 创建新商品（需要JWT）

3. **订单流程**
   - 创建订单（需要JWT）
   - 查看订单列表

4. **监控展示**
   - 访问Prometheus
   - 访问Grafana

## 文档准备

确保以下文档齐全：
- [x] README.md - 项目介绍
- [x] QUICK_START.md - 快速开始
- [x] ARCHITECTURE.md - 架构说明
- [x] VM_DEPLOYMENT_GUIDE.md - 虚拟机部署指南
- [x] PROJECT_REQUIREMENTS.md - 需求文档
- [x] API文档（在README中）

## 录制演示视频建议

### 视频内容建议（10-15分钟）

1. **项目介绍**（2分钟）
   - 展示项目结构
   - 说明技术栈

2. **本地开发演示**（3分钟）
   - Docker Compose启动
   - 运行测试
   - API测试

3. **K8s部署演示**（5分钟）
   - 展示集群状态
   - 部署过程
   - 服务访问

4. **功能演示**（3分钟）
   - 用户注册/登录
   - 商品管理
   - 订单创建

5. **监控演示**（2分钟）
   - Prometheus界面
   - Grafana仪表盘

## 提交材料清单

1. **源代码**
   - Git仓库地址
   - 确保.gitignore正确配置

2. **部署截图**
   - K8s集群状态
   - Pod运行状态
   - 服务访问结果
   - 监控界面

3. **演示视频**
   - 完整的部署和运行过程
   - 功能演示

4. **项目报告**
   - 项目架构说明
   - 部署步骤说明
   - 遇到的问题和解决方案

## 常见问题

1. **Pod一直Pending**
   - 检查节点资源
   - 查看Pod描述信息

2. **镜像构建失败**
   - 确保Docker服务运行
   - 检查Dockerfile语法

3. **服务无法访问**
   - 检查防火墙设置
   - 验证NodePort配置

## 最后确认

- [ ] 所有服务可以正常访问
- [ ] 测试脚本全部通过
- [ ] 文档完整清晰
- [ ] 代码注释适当
- [ ] 敏感信息已移除（密码、密钥等）

祝提交顺利！🎉