# 云原生电商微服务系统

基于云原生技术栈的极简电商微服务系统，包含用户管理、商品管理和订单管理三个核心微服务。

## 项目特点

- 🚀 **快速部署**：一键脚本完成所有部署
- 🔧 **技术完整**：覆盖容器化、编排、CI/CD、监控全流程
- 📝 **代码简洁**：每个服务核心代码仅100行左右
- ✅ **测试完善**：单元测试、API测试、负载测试齐全
- 📚 **文档详细**：包含架构说明、部署指南、API文档

## 技术栈

- **编程语言**：Node.js + Express
- **数据存储**：Redis
- **容器技术**：Docker
- **容器编排**：Kubernetes (K3s)
- **CI/CD**：Jenkins
- **监控**：Prometheus + Grafana
- **认证**：JWT

## 快速开始

### 本地开发（5分钟）

```bash
# 克隆项目
git clone <repository-url>
cd cloud-native-shop

# 启动所有服务
docker-compose up -d

# 运行测试
./scripts/test-apis.sh

# 查看日志
docker-compose logs -f
```

### 生产部署（30分钟）

需要3台CentOS 7虚拟机，详见 [VM_DEPLOYMENT_GUIDE.md](VM_DEPLOYMENT_GUIDE.md)

```bash
# Master节点执行
./scripts/install-k3s.sh
./scripts/deploy-all.sh
```

## 项目结构

```
cloud-native-shop/
├── services/              # 微服务源代码
│   ├── user-service/     # 用户服务
│   ├── product-service/  # 商品服务
│   └── order-service/    # 订单服务
├── k8s/                  # Kubernetes配置
├── scripts/              # 自动化脚本
├── jenkins/              # CI/CD配置
└── docker-compose.yml    # 本地开发环境
```

## 核心功能

### 用户服务 (端口 8081)
- 用户注册 `POST /api/register`
- 用户登录 `POST /api/login`
- Token验证 `GET /api/verify`
- 用户信息 `GET /api/profile`

### 商品服务 (端口 8082)
- 商品列表 `GET /api/products`
- 商品详情 `GET /api/products/:id`
- 创建商品 `POST /api/products` (需认证)
- 更新商品 `PUT /api/products/:id` (需认证)
- 删除商品 `DELETE /api/products/:id` (需认证)

### 订单服务 (端口 8083)
- 创建订单 `POST /api/orders` (需认证)
- 订单列表 `GET /api/orders` (需认证)
- 订单详情 `GET /api/orders/:id` (需认证)
- 更新状态 `PUT /api/orders/:id/status` (需认证)

## 测试示例

```bash
# 1. 用户注册
curl -X POST http://localhost:8081/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"123456","email":"test@example.com"}'

# 2. 用户登录（获取JWT）
TOKEN=$(curl -X POST http://localhost:8081/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"123456"}' | jq -r '.token')

# 3. 创建商品
curl -X POST http://localhost:8082/api/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"iPhone 14","price":999,"stock":100}'

# 4. 创建订单
curl -X POST http://localhost:8083/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"items":[{"productId":"xxx","quantity":1}]}'
```

## 监控访问

部署后可访问：
- Prometheus: http://<node-ip>:30090
- Grafana: http://<node-ip>:30030 (admin/admin)
- Jenkins: http://<node-ip>:8080

## 常用命令

```bash
# 查看集群状态
kubectl get nodes
kubectl get pods -n cloud-shop

# 查看日志
kubectl logs -f deployment/user-service -n cloud-shop

# 扩容服务
kubectl scale deployment/user-service --replicas=3 -n cloud-shop

# 清理环境
./scripts/deploy-all.sh cleanup
```

## 作业要求对照

| 要求 | 实现情况 |
|------|---------|
| 云原生技术 | ✅ Docker + K8s + 微服务 |
| 用户管理微服务 | ✅ 完整的JWT认证系统 |
| 2个业务微服务 | ✅ 商品服务 + 订单服务 |
| 容器平台 | ✅ Docker + containerd + K3s |
| 自动化部署 | ✅ Jenkins CI/CD |
| 监控系统 | ✅ Prometheus + Grafana |
| 脚本语言 | ✅ Bash自动化脚本 |
| 编程语言 | ✅ Node.js |
| 编排语言 | ✅ YAML + Helm准备 |

## 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

MIT License

## 联系方式

如有问题，请提交 Issue 或联系项目维护者。