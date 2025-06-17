# 虚拟机部署完整指南

## 前置准备

### 1. 虚拟机要求
- 3台CentOS 7虚拟机
- 每台至少2GB内存，20GB硬盘
- 网络互通，建议使用桥接模式
- 记录好每台机器的IP地址

### 2. 配置虚拟机网络
假设你的虚拟机IP如下（根据实际修改）：
- VM1 (Master): 192.168.1.100
- VM2 (Worker1): 192.168.1.101
- VM3 (Worker2): 192.168.1.102

## 第一步：基础环境准备（在所有虚拟机上执行）

```bash
# 1. 更新系统
sudo yum update -y

# 2. 安装Git
sudo yum install -y git

# 3. 关闭防火墙（生产环境需要配置具体规则）
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 4. 关闭SELinux
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# 5. 配置主机名（分别在不同机器上执行）
# VM1上执行
sudo hostnamectl set-hostname k3s-master

# VM2上执行
sudo hostnamectl set-hostname k3s-worker1

# VM3上执行
sudo hostnamectl set-hostname k3s-worker2

# 6. 配置hosts文件（所有机器上执行，根据实际IP修改）
sudo cat >> /etc/hosts << EOF
192.168.1.100 k3s-master
192.168.1.101 k3s-worker1
192.168.1.102 k3s-worker2
EOF
```

## 第二步：在Master节点部署

### 1. 克隆项目
```bash
# SSH登录到Master节点
ssh root@192.168.1.100

# 克隆项目
cd /opt
git clone <你的git仓库地址> cloud-native-shop
cd cloud-native-shop

# 给脚本添加执行权限
chmod +x scripts/*.sh
```

### 2. 安装必要工具
```bash
# 安装Docker、kubectl、Node.js等工具
sudo ./scripts/install-tools.sh
```

### 3. 安装K3s集群
```bash
# 修改脚本中的IP地址（如果需要）
vim scripts/install-k3s.sh
# 修改MASTER_IP、WORKER1_IP、WORKER2_IP为你的实际IP

# 执行安装（使用实际的IP地址）
sudo ./scripts/install-k3s.sh 192.168.1.100 192.168.1.101 192.168.1.102

# 脚本会生成worker节点的安装脚本
ls /tmp/install-worker*.sh
```

### 4. 在Worker节点安装K3s Agent

```bash
# 将安装脚本复制到Worker节点
scp /tmp/install-worker1.sh root@192.168.1.101:/tmp/
scp /tmp/install-worker2.sh root@192.168.1.102:/tmp/

# SSH到Worker1节点
ssh root@192.168.1.101
sudo bash /tmp/install-worker1.sh

# SSH到Worker2节点
ssh root@192.168.1.102
sudo bash /tmp/install-worker2.sh
```

### 5. 验证集群状态
```bash
# 回到Master节点
ssh root@192.168.1.100
cd /opt/cloud-native-shop

# 检查节点状态（等待所有节点Ready）
kubectl get nodes

# 应该看到类似输出：
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-master    Ready    control-plane,master   5m    v1.27.x
# k3s-worker1   Ready    <none>                 3m    v1.27.x
# k3s-worker2   Ready    <none>                 3m    v1.27.x
```

## 第三步：部署应用

### 1. 构建和部署
```bash
# 确保在Master节点的项目目录
cd /opt/cloud-native-shop

# 执行部署脚本
./scripts/deploy-all.sh

# 脚本会：
# - 构建Docker镜像
# - 创建K8s资源
# - 部署所有服务
```

### 2. 检查部署状态
```bash
# 查看所有Pod状态
kubectl get pods -n cloud-shop

# 等待所有Pod变为Running状态
kubectl wait --for=condition=ready pod --all -n cloud-shop --timeout=300s

# 查看服务
kubectl get svc -n cloud-shop
```

### 3. 获取访问地址
```bash
# 脚本会自动显示访问地址，也可以手动获取
./scripts/deploy-all.sh status

# 或手动查看
NODE_IP=$(kubectl get nodes k3s-master -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "User Service: http://${NODE_IP}:30081"
echo "Product Service: http://${NODE_IP}:30082"
echo "Order Service: http://${NODE_IP}:30083"
```

## 第四步：验证部署

### 1. 测试API
```bash
# 运行测试脚本
./scripts/test-apis.sh --k8s

# 初始化演示数据
./scripts/init-demo-data.sh --k8s
```

### 2. 访问服务
在浏览器或使用curl测试：
```bash
# 健康检查
curl http://192.168.1.100:30081/health
curl http://192.168.1.100:30082/health
curl http://192.168.1.100:30083/health
```

## 第五步：配置Jenkins（可选）

```bash
# 启动Jenkins
./scripts/setup-jenkins.sh

# 访问Jenkins
# http://192.168.1.100:8080
```

## 第六步：配置监控（可选）

```bash
# 部署Prometheus和Grafana
./scripts/setup-monitoring.sh

# 访问监控
# Prometheus: http://192.168.1.100:30090
# Grafana: http://192.168.1.100:30030 (admin/admin)
```

## 故障排查

### Pod无法启动
```bash
# 查看Pod详情
kubectl describe pod <pod-name> -n cloud-shop

# 查看Pod日志
kubectl logs <pod-name> -n cloud-shop
```

### 镜像拉取失败
```bash
# 检查Docker镜像
docker images | grep cloud-shop

# 手动构建镜像
cd services/user-service
docker build -t cloud-shop/user-service:latest .
```

### 服务无法访问
```bash
# 检查Service和Endpoint
kubectl get svc -n cloud-shop
kubectl get endpoints -n cloud-shop

# 检查NodePort是否被占用
netstat -tlnp | grep 300
```

### 清理和重新部署
```bash
# 清理所有资源
./scripts/deploy-all.sh cleanup

# 重新部署
./scripts/deploy-all.sh
```

## 快速命令参考

```bash
# 查看所有资源
kubectl get all -n cloud-shop

# 查看日志
kubectl logs -f deployment/user-service -n cloud-shop

# 进入容器调试
kubectl exec -it deployment/user-service -n cloud-shop -- sh

# 查看集群事件
kubectl get events -n cloud-shop --sort-by='.lastTimestamp'

# 扩容服务
kubectl scale deployment/user-service --replicas=3 -n cloud-shop
```

## 注意事项

1. **IP地址**：务必根据实际情况修改所有脚本中的IP地址
2. **资源限制**：如果虚拟机资源有限，可以修改K8s部署文件中的资源限制
3. **镜像仓库**：生产环境建议使用私有镜像仓库
4. **数据持久化**：生产环境需要配置PVC for Redis
5. **安全**：生产环境需要配置TLS、网络策略等

## 视频演示建议

录制演示视频时，建议展示：
1. 集群节点状态
2. Pod运行状态
3. 访问各个服务的健康检查
4. 使用Postman或curl演示完整的业务流程
5. 展示Jenkins和监控界面