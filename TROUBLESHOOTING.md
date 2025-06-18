# Kubernetes ImagePullBackOff 故障排查指南

## 问题描述

在部署微服务到Kubernetes集群时，遇到了`ImagePullBackOff`和`ErrImageNeverPull`错误，即使镜像已经在节点上存在。

## 根本原因

**关键问题：Kubernetes使用containerd作为容器运行时，而Docker镜像存储在不同的命名空间中。**

- Docker镜像存储在Docker的存储中
- Kubernetes (containerd) 需要镜像在 `k8s.io` 命名空间中
- 即使用 `docker load` 加载的镜像，Kubernetes也无法直接使用

## 环境信息

- Kubernetes版本：v1.28.2
- 容器运行时：containerd 1.6.33
- 节点配置：1个Master + 2个Worker
- 同时安装了Docker和containerd

## 错误现象

```bash
NAME                               READY   STATUS              RESTARTS   AGE
order-service-7ffb5cfd67-f8plh     0/1     ImagePullBackOff    0          22m
product-service-756db9674c-68j8d   0/1     ImagePullBackOff    0          22m
user-service-5c7b7bf495-46wxv      0/1     ErrImageNeverPull   0          22m
```

## 错误的解决尝试（不要这样做）

### ❌ 错误1：只用docker load
```bash
# 这样做是错误的，镜像只在Docker中，不在containerd中
docker load < images.tar
```

### ❌ 错误2：修改Dockerfile中的npm命令
```bash
# 这不是根本问题，虽然npm ci需要package-lock.json
sed -i 's/npm ci/npm install/g' Dockerfile
```

### ❌ 错误3：只设置imagePullPolicy为Never
```bash
# 如果镜像不在containerd中，这样会导致ErrImageNeverPull
kubectl patch deployment xxx -p '{"spec":{"template":{"spec":{"containers":[{"imagePullPolicy":"Never"}]}}}}'
```

## 正确的解决方案

### 步骤1：配置crictl（如果需要）

```bash
# 创建crictl配置文件
cat > /etc/crictl.yaml << EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
EOF
```

### 步骤2：将Docker镜像导入到containerd的k8s.io命名空间

```bash
# 在Master节点
docker save cloud-shop/user-service:latest | ctr -n k8s.io images import -
docker save cloud-shop/product-service:latest | ctr -n k8s.io images import -
docker save cloud-shop/order-service:latest | ctr -n k8s.io images import -

# 验证镜像
ctr -n k8s.io images ls | grep cloud-shop
```

### 步骤3：在所有Worker节点上执行相同操作

```bash
# 方法1：SSH到每个节点执行
ssh root@k8s-worker1
docker save cloud-shop/user-service:latest | ctr -n k8s.io images import -
docker save cloud-shop/product-service:latest | ctr -n k8s.io images import -
docker save cloud-shop/order-service:latest | ctr -n k8s.io images import -
exit

# 方法2：远程执行
ssh root@k8s-worker1 'docker save cloud-shop/user-service:latest | ctr -n k8s.io images import -'
```

### 步骤4：重启Pod

```bash
# 删除所有Pod让它们重新创建
kubectl delete pods --all -n cloud-shop --force

# 查看状态
kubectl get pods -n cloud-shop -w
```

## 快速修复脚本

```bash
#!/bin/bash
# fix-images.sh - 修复containerd镜像问题

IMAGES=(
  "cloud-shop/user-service:latest"
  "cloud-shop/product-service:latest"
  "cloud-shop/order-service:latest"
)

WORKERS=("k8s-worker1" "k8s-worker2")

# 导入到本地containerd
for img in "${IMAGES[@]}"; do
  echo "导入 $img 到本地containerd..."
  docker save $img | ctr -n k8s.io images import -
done

# 导入到Worker节点
for worker in "${WORKERS[@]}"; do
  echo "处理 $worker..."
  for img in "${IMAGES[@]}"; do
    ssh root@$worker "docker save $img | ctr -n k8s.io images import -"
  done
done

# 重启Pod
kubectl delete pods --all -n cloud-shop --force
```

## 验证命令

```bash
# 检查Docker镜像
docker images | grep cloud-shop

# 检查containerd镜像（这个才是关键）
ctr -n k8s.io images ls | grep cloud-shop

# 使用crictl检查
crictl images | grep cloud-shop
```

## 预防措施

1. **理解容器运行时**：明确你的集群使用的是Docker还是containerd
2. **使用正确的镜像导入方法**：
   - 对于containerd：使用 `ctr -n k8s.io images import`
   - 对于Docker作为运行时：使用 `docker load`
3. **构建时就推送到registry**：最好使用镜像仓库，避免手动传输
4. **使用本地registry**：部署一个本地registry服务

## 常见错误信息解释

- `ImagePullBackOff`：Kubernetes尝试拉取镜像失败
- `ErrImageNeverPull`：设置了Never但本地没有镜像
- `ContainerStatusUnknown`：通常是节点资源问题
- `pull access denied`：尝试从公共registry拉取不存在的镜像

## 总结

核心要点：
1. **Docker和containerd使用不同的镜像存储**
2. **必须将镜像导入到k8s.io命名空间**
3. **每个运行Pod的节点都需要有镜像**
4. **使用ctr命令而不是docker load来导入镜像**

记住：`docker images`看到的镜像不等于Kubernetes能使用的镜像！