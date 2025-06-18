# 🚀 云原生商城 - 使用指南（简化版）

## 一键部署

```bash
./deploy-all-in-one.sh
```

**就这一个命令！** 它会自动：
- ✅ 部署K8s服务（修复了启动问题）
- ✅ 部署Jenkins（admin/admin123，无需初始密码）
- ✅ 创建Pipeline项目（无XML错误）

## 部署完成后

### 访问服务
- Jenkins: http://localhost:8080 (admin/admin123)
- 用户服务: http://localhost:30081
- 商品服务: http://localhost:30082
- 订单服务: http://localhost:30083
- 监控面板: http://localhost:30084

### 运行Jenkins Pipeline
1. 访问 http://localhost:8080
2. 使用 admin/admin123 登录
3. 点击 `cloud-native-shop-pipeline`
4. 点击 `立即构建`

## 其他脚本说明

- `setup-directories.sh` - 初始化项目目录结构
- `deploy-k8s-optimized.sh` - 仅部署K8s服务（用于特殊场景）
- `upload-to-github.sh` - 上传项目到GitHub

## 故障排查

```bash
# 查看Pod状态
kubectl get pods -n cloud-shop

# 查看Jenkins日志
docker logs jenkins-cloud-shop

# 完全重新部署
./deploy-all-in-one.sh
```

---

**就是这么简单！一个脚本搞定所有！** 🎉