# 云原生商城项目展示

## 1. 项目结构 📁

```
cloud-native-shop/
├── services/                    # 微服务目录
│   ├── user-service/           # 用户服务
│   │   ├── index.js           # 服务入口
│   │   ├── package.json       # 依赖配置
│   │   ├── Dockerfile         # 容器化配置
│   │   └── public/            # 前端页面
│   │       ├── index.html     # 首页
│   │       ├── login.html     # 登录页
│   │       ├── register.html  # 注册页
│   │       └── profile.html   # 个人中心
│   ├── product-service/        # 商品服务
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   └── public/
│   │       ├── index.html     # 商品首页
│   │       ├── list.html      # 商品列表
│   │       ├── detail.html    # 商品详情
│   │       └── admin.html     # 商品管理
│   ├── order-service/          # 订单服务
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   └── public/
│   │       └── index.html     # 订单管理
│   ├── dashboard-service/      # 监控服务
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   └── public/
│   │       └── index.html     # 监控面板
│   └── shared/                 # 共享模块
│       └── auth.js            # 认证模块
├── k8s/                        # Kubernetes配置
│   ├── namespace.yaml         # 命名空间
│   ├── redis/                 # Redis配置
│   ├── user-service/          # 用户服务K8s配置
│   ├── product-service/       # 商品服务K8s配置
│   ├── order-service/         # 订单服务K8s配置
│   └── dashboard-service/     # 监控服务K8s配置
├── Jenkinsfile                # CI/CD流水线
├── deploy-k8s-optimized.sh    # 优化部署脚本
└── quick-deploy.sh            # 快速部署脚本
```

## 2. 云原生环境展示 ☸️

### 查看Kubernetes节点
```bash
kubectl get nodes
```
输出示例：
```
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   7d    v1.28.0
k8s-worker1   Ready    <none>          7d    v1.28.0
k8s-worker2   Ready    <none>          7d    v1.28.0
```

### 查看Pod状态
```bash
kubectl get pods -n cloud-shop -o wide
```
输出示例：
```
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE
redis-5b4d6c4d8-xyz12              1/1     Running   0          1h    10.244.1.5   k8s-worker1
user-service-7f8d9c6b5-abc34       1/1     Running   0          1h    10.244.2.3   k8s-worker2
product-service-6a7e8f9c4-def56    1/1     Running   0          1h    10.244.1.6   k8s-worker1
order-service-8c9a7b6e5-ghi78      1/1     Running   0          1h    10.244.2.4   k8s-worker2
dashboard-service-9d8c7a6b5-jkl90  1/1     Running   0          1h    10.244.1.7   k8s-worker1
```

### 查看服务
```bash
kubectl get svc -n cloud-shop
```
输出示例：
```
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
redis               ClusterIP   10.96.10.123    <none>        6379/TCP         1h
user-service        NodePort    10.96.20.234    <none>        8081:30081/TCP   1h
product-service     NodePort    10.96.30.345    <none>        8082:30082/TCP   1h
order-service       NodePort    10.96.40.456    <none>        8083:30083/TCP   1h
dashboard-service   NodePort    10.96.50.567    <none>        8084:30084/TCP   1h
```

## 3. 微服务请求及返回结果 🔄

### 用户服务API测试

#### 注册用户
```bash
curl -X POST http://192.168.1.100:30081/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "test123",
    "email": "test@example.com"
  }'
```
返回结果：
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "testuser",
    "username": "testuser",
    "email": "test@example.com"
  }
}
```

#### 用户登录
```bash
curl -X POST http://192.168.1.100:30081/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "demo",
    "password": "demo123"
  }'
```
返回结果：
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "demo",
    "username": "demo",
    "email": "demo@cloudshop.com",
    "role": "user"
  }
}
```

### 商品服务API测试

#### 获取商品列表
```bash
curl http://192.168.1.100:30082/api/products
```
返回结果：
```json
[
  {
    "id": "prod-1",
    "name": "iPhone 15 Pro",
    "description": "最新款苹果手机，搭载A17 Pro芯片，钛金属设计",
    "price": 9999,
    "stock": 50,
    "category": "electronics",
    "createdAt": "2024-01-10T08:00:00.000Z"
  },
  {
    "id": "prod-2",
    "name": "MacBook Pro 14\"",
    "description": "M3 Pro芯片，14英寸Liquid视网膜XDR显示屏",
    "price": 16999,
    "stock": 30,
    "category": "electronics",
    "createdAt": "2024-01-10T08:00:00.000Z"
  }
  // ... 更多商品
]
```

### 订单服务API测试

#### 创建订单
```bash
curl -X POST http://192.168.1.100:30083/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -d '{
    "items": [
      {
        "productId": "prod-1",
        "productName": "iPhone 15 Pro",
        "quantity": 1,
        "price": 9999
      }
    ],
    "shippingAddress": "北京市朝阳区XX街道",
    "notes": "请尽快发货"
  }'
```
返回结果：
```json
{
  "id": "order-xxxx-xxxx",
  "userId": "demo",
  "items": [...],
  "totalAmount": 9999,
  "status": "pending",
  "createdAt": "2024-01-10T10:30:00.000Z"
}
```

## 4. Dashboard展示 📊

访问监控面板：`http://192.168.1.100:30084`

### 系统概览
- **注册用户**: 3
- **商品总数**: 8
- **订单总数**: 4
- **总销售额**: ¥16,352

### 服务健康状态
- ✅ 用户服务 - 正常运行
- ✅ 商品服务 - 正常运行
- ✅ 订单服务 - 正常运行
- ✅ 监控服务 - 正常运行

### K8s集群信息
显示节点状态、Pod运行情况、服务列表等实时信息。

## 5. Jenkins Pipeline运行 🔧

### Pipeline执行流程
1. **代码检出** - 从Git仓库拉取最新代码
2. **并行构建** - 同时构建4个微服务镜像
3. **测试执行** - 运行单元测试和集成测试
4. **镜像推送** - 推送到Docker Registry
5. **K8s部署** - 自动部署到集群
6. **健康检查** - 验证服务状态

### 构建结果展示
```
========================================
🎉 构建成功！
========================================
构建编号: #42
构建时间: 2024-01-10 15:30:45
持续时间: 5分23秒

阶段执行时间：
- 代码检出: 8秒
- 镜像构建: 2分30秒
- 测试运行: 45秒
- 部署K8s: 1分20秒
- 健康检查: 40秒

服务访问地址:
- 用户服务: http://192.168.1.100:30081
- 商品服务: http://192.168.1.100:30082
- 订单服务: http://192.168.1.100:30083
- 监控面板: http://192.168.1.100:30084
========================================
```

## 6. 演示流程 🎬

1. **展示项目结构**
   - 使用 `tree` 命令展示目录结构
   - 说明微服务架构设计

2. **展示K8s环境**
   - 执行kubectl命令展示集群状态
   - 展示Pod在不同节点的分布

3. **功能演示**
   - 登录系统（使用demo账号）
   - 浏览商品列表
   - 创建订单
   - 查看订单状态

4. **API测试**
   - 使用curl或Postman测试各个API
   - 展示JWT认证流程

5. **监控面板**
   - 展示实时系统状态
   - 查看K8s资源信息

6. **CI/CD流程**
   - 触发Jenkins构建
   - 展示Pipeline各阶段执行
   - 验证自动部署结果

## 7. 技术亮点 ✨

- **微服务架构**: 服务解耦，独立部署
- **容器化部署**: Docker打包，K8s编排
- **认证授权**: JWT跨服务认证
- **持续集成**: Jenkins自动化流水线
- **监控运维**: 实时健康检查和监控
- **高可用设计**: 多副本部署，负载均衡