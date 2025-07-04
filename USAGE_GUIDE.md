# 云原生商城使用指南

## 🚀 快速开始

### 默认账号
系统启动后会自动创建以下默认账号：

| 用户名 | 密码 | 角色 | 说明 |
|--------|------|------|------|
| admin | admin123 | 管理员 | 可以管理商品，查看所有订单 |
| demo | demo123 | 普通用户 | 演示用户，已有历史订单 |
| test | test123 | 普通用户 | 测试用户，可用于测试 |

### 默认数据
- **商品**: 8个示例商品（iPhone、MacBook、书籍等）
- **订单**: 4个示例订单（不同状态的订单）

## 📋 完整使用流程

### 1. 用户登录
1. 访问用户服务：`http://<节点IP>:30081`
2. 点击"登录"按钮
3. 使用默认账号登录（如：demo/demo123）

### 2. 浏览商品
1. 登录成功后，点击导航栏的"商品中心"
2. 自动跳转到商品服务：`http://<节点IP>:30082`
3. 浏览商品列表，查看商品详情

### 3. 商品管理（管理员）
1. 使用admin账号登录
2. 访问商品管理页面：`http://<节点IP>:30082/admin.html`
3. 可以添加、编辑、删除商品

### 4. 创建订单
1. 在商品页面选择商品
2. 点击"立即购买"或"加入购物车"
3. 填写收货地址
4. 提交订单

### 5. 查看订单
1. 点击导航栏的"订单中心"
2. 自动跳转到订单服务：`http://<节点IP>:30083`
3. 查看个人订单列表
4. 可以对订单进行操作（支付、取消等）

## 🔐 认证机制
- 系统使用JWT进行身份认证
- Token在不同服务间自动传递
- 登录状态24小时有效

## 🌐 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| 用户服务 | 30081 | 登录、注册、个人中心 |
| 商品服务 | 30082 | 商品展示、商品管理 |
| 订单服务 | 30083 | 订单管理 |
| 监控面板 | 30084 | 系统监控（开发中） |

## 🛠️ 常见操作

### 查看系统状态
```bash
kubectl get pods -n cloud-shop
kubectl get svc -n cloud-shop
```

### 查看服务日志
```bash
kubectl logs <pod-name> -n cloud-shop
```

### 重启服务
```bash
kubectl delete pod <pod-name> -n cloud-shop
```

## ⚠️ 注意事项
1. 首次访问时会自动创建默认数据
2. 跨服务跳转时会自动传递认证信息
3. 商品管理需要admin权限
4. 订单只能查看和操作自己的

## 🐛 问题排查

### 登录后跳转失败
- 确保所有服务正常运行
- 检查浏览器是否禁用了localStorage

### 商品列表为空
- 等待服务完全启动（约30秒）
- 刷新页面重试

### 无法创建订单
- 确保已登录
- 检查商品库存是否充足

## 📞 技术支持
如遇到问题，请查看服务日志或联系管理员。