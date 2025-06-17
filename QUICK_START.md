# 快速部署指南

## 30分钟完成部署

### 步骤1：本地测试（5分钟）

```bash
# 在Windows上使用Docker Desktop
cd cloud-native-shop
docker-compose up -d

# 测试API
./scripts/test-apis.sh
```

### 步骤2：准备虚拟机（10分钟）

在3台CentOS 7虚拟机上执行：

```bash
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 设置SELinux为宽松模式
setenforce 0
```

### 步骤3：安装K3s集群（10分钟）

在Master节点(VM1)执行：

```bash
# 拷贝项目到Master节点
scp -r cloud-native-shop root@192.168.1.10:/opt/

# SSH到Master节点
ssh root@192.168.1.10

# 安装K3s和工具
cd /opt/cloud-native-shop
./scripts/install-tools.sh
./scripts/install-k3s.sh 192.168.1.10 192.168.1.11 192.168.1.12

# 在Worker节点安装K3s agent
# 将生成的脚本拷贝到Worker节点并执行
```

### 步骤4：部署应用（5分钟）

```bash
# 在Master节点执行
cd /opt/cloud-native-shop
./scripts/deploy-all.sh

# 测试部署
./scripts/test-apis.sh --k8s
```

## 访问地址

假设Master节点IP为192.168.1.10：

- 用户服务: http://192.168.1.10:30081
- 商品服务: http://192.168.1.10:30082
- 订单服务: http://192.168.1.10:30083
- Jenkins: http://192.168.1.10:8080
- Prometheus: http://192.168.1.10:30090
- Grafana: http://192.168.1.10:30030

## 验证部署

```bash
# 查看所有Pod状态
kubectl get pods -n cloud-shop

# 查看服务
kubectl get svc -n cloud-shop

# 查看节点
kubectl get nodes
```

## 常见问题

1. **Pod一直处于Pending状态**
   - 检查节点资源是否充足
   - 使用 `kubectl describe pod <pod-name> -n cloud-shop` 查看详情

2. **无法访问服务**
   - 确保防火墙已关闭
   - 检查NodePort是否正确

3. **Redis连接失败**
   - 确保Redis Pod正在运行
   - 检查服务名称是否正确

## 清理环境

```bash
# 删除所有资源
./scripts/deploy-all.sh cleanup

# 卸载K3s
/usr/local/bin/k3s-uninstall.sh
```