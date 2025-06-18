# 云原生电商微服务系统

这是一个基于云原生技术的极简电商微服务系统，包含用户管理、商品管理和订单管理三个核心微服务。

## 系统架构

- **用户服务** (8081端口/30081): 用户注册、登录、JWT认证
- **商品服务** (8082端口/30082): 商品CRUD操作、商品管理
- **订单服务** (8083端口/30083): 订单创建和管理
- **监控服务** (8084端口/30084): 系统监控、K8s集群状态
- **数据存储**: Redis（用作数据库和缓存）
- **容器编排**: Kubernetes (K3s)
- **CI/CD**: Jenkins Pipeline
- **监控**: Dashboard + Prometheus + Grafana
- **认证**: 跨服务JWT认证与自动传递

## 快速开始

### 本地开发（使用Docker Compose）

```bash
# 1. 克隆项目
git clone <repository-url>
cd cloud-native-shop

# 2. 安装依赖
make install-deps

# 3. 启动所有服务
make up

# 4. 查看日志
make logs

# 5. 运行测试
make test
```

### 生产部署（使用Kubernetes）

#### 环境准备

需要3台CentOS 7虚拟机：
- VM1 (Master): 192.168.1.10
- VM2 (Worker1): 192.168.1.11  
- VM3 (Worker2): 192.168.1.12

#### 一键部署

```bash
# 1. 在Master节点安装K3s集群
sudo ./scripts/install-k3s.sh 192.168.1.10 192.168.1.11 192.168.1.12

# 2. 安装必要工具
sudo ./scripts/install-tools.sh

# 3. 部署应用
./scripts/deploy-all.sh
# 或使用优化脚本
./deploy-k8s-optimized.sh

# 4. 设置Jenkins CI/CD
./scripts/setup-jenkins.sh

# 5. 设置监控
./scripts/setup-monitoring.sh
```

### 默认账号

系统启动后会自动创建以下默认账号：

| 用户名 | 密码 | 角色 | 说明 |
|--------|------|------|------|
| admin | admin123 | 管理员 | 可以管理商品，查看所有订单 |
| demo | demo123 | 普通用户 | 演示用户，已有历史订单 |
| test | test123 | 普通用户 | 测试用户 |

## API 接口

### 用户服务 (8081)

- `POST /api/register` - 用户注册
  ```json
  {
    "username": "user1",
    "password": "password123",
    "email": "user@example.com"
  }
  ```

- `POST /api/login` - 用户登录
  ```json
  {
    "username": "user1",
    "password": "password123"
  }
  ```

- `GET /api/verify` - 验证JWT Token (需要Authorization header)
- `GET /api/profile` - 获取用户信息 (需要JWT)

### 商品服务 (8082)

- `GET /api/products` - 获取商品列表
- `GET /api/products/:id` - 获取商品详情
- `POST /api/products` - 创建商品 (需要JWT)
  ```json
  {
    "name": "iPhone 13",
    "description": "Latest iPhone",
    "price": 999.99,
    "stock": 100
  }
  ```
- `PUT /api/products/:id` - 更新商品 (需要JWT)
- `DELETE /api/products/:id` - 删除商品 (需要JWT)

### 订单服务 (8083)

- `POST /api/orders` - 创建订单 (需要JWT)
  ```json
  {
    "items": [
      {
        "productId": "xxx",
        "quantity": 2
      }
    ]
  }
  ```
- `GET /api/orders` - 获取用户订单列表 (需要JWT)
- `GET /api/orders/:id` - 获取订单详情 (需要JWT)
- `PUT /api/orders/:id/status` - 更新订单状态 (需要JWT)

## 测试

### 本地测试

```bash
# 用户注册
curl -X POST http://localhost:8081/api/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123","email":"test@example.com"}'

# 用户登录
curl -X POST http://localhost:8081/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}'

# 使用返回的token访问其他API
export TOKEN="<your-jwt-token>"

# 创建商品
curl -X POST http://localhost:8082/api/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Test Product","price":99.99,"stock":10}'
```

### K8s环境测试

```bash
# 获取服务地址
export NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# 测试服务健康
curl http://$NODE_IP:30081/health
curl http://$NODE_IP:30082/health
curl http://$NODE_IP:30083/health
```

## 监控与管理

- 系统监控面板: http://<NODE_IP>:30084
- Prometheus: http://<NODE_IP>:30090
- Grafana: http://<NODE_IP>:30030 (admin/admin)
- Jenkins: http://<NODE_IP>:8080

### 访问地址
- 用户服务: http://<NODE_IP>:30081
- 商品服务: http://<NODE_IP>:30082
- 订单服务: http://<NODE_IP>:30083
- 监控面板: http://<NODE_IP>:30084

## 常用命令

```bash
# 查看部署状态
./scripts/deploy-all.sh status

# 清理所有资源
./scripts/deploy-all.sh cleanup

# 查看K8s集群状态
kubectl get nodes
kubectl get pods -n cloud-shop
kubectl get svc -n cloud-shop

# 查看日志
kubectl logs -f deployment/user-service -n cloud-shop
kubectl logs -f deployment/product-service -n cloud-shop
kubectl logs -f deployment/order-service -n cloud-shop
```

## 项目结构

```
cloud-native-shop/
├── services/              # 微服务源代码
│   ├── user-service/     # 用户服务
│   ├── product-service/  # 商品服务
│   └── order-service/    # 订单服务
├── k8s/                  # Kubernetes配置文件
├── scripts/              # 自动化脚本
├── jenkins/              # Jenkins CI/CD配置
├── docker-compose.yml    # 本地开发环境
└── Makefile             # 快捷命令
```

## 注意事项

1. 生产环境请修改JWT密钥
2. Redis数据持久化需要配置PVC
3. 建议使用真实的镜像仓库
4. 监控指标需要服务端添加metrics端点

## 相关文档

- [使用指南](USAGE_GUIDE.md) - 详细的使用说明和操作流程
- [项目展示](PROJECT_SHOWCASE.md) - 项目功能展示和演示指南
- [Jenkins配置](JENKINS_SETUP.md) - CI/CD流水线配置指南
- [故障排查](TROUBLESHOOTING.md) - 常见问题解决方案

## License

MIT

---

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>