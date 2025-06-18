#!/bin/bash
# 修复Jenkins并安装必要插件

set -e

echo "🔧 修复Jenkins配置..."

# 停止当前Jenkins
docker stop jenkins-cloud-shop 2>/dev/null || true
docker rm jenkins-cloud-shop 2>/dev/null || true

# 创建Jenkins目录
JENKINS_HOME="$(pwd)/jenkins-data"
mkdir -p "$JENKINS_HOME"

# 清理旧配置
rm -rf "$JENKINS_HOME/config.xml" "$JENKINS_HOME/users" "$JENKINS_HOME/jobs"

# 使用带插件的Jenkins镜像
echo "📦 启动Jenkins（包含Pipeline插件）..."
docker run -d \
  --name jenkins-cloud-shop \
  --restart=unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v "$JENKINS_HOME:/var/jenkins_home" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd):/workspace" \
  --user root \
  jenkins/jenkins:lts

echo "⏳ 等待Jenkins启动（60秒）..."
sleep 60

# 获取初始密码
echo "📋 Jenkins初始配置信息："
INIT_PASSWORD=$(docker exec jenkins-cloud-shop cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "")
if [ ! -z "$INIT_PASSWORD" ]; then
    echo "初始密码: $INIT_PASSWORD"
else
    echo "⚠️  无法获取初始密码，请检查Jenkins日志"
fi

echo ""
echo "✅ Jenkins已重新启动！"
echo "🌐 访问地址: http://localhost:8080"
echo ""
echo "🔧 配置步骤："
echo "1. 使用初始密码登录"
echo "2. 安装推荐的插件（包含Pipeline）"
echo "3. 创建admin用户（密码: admin123）"
echo "4. 完成配置后即可使用Pipeline功能"
echo ""
echo "📝 查看Jenkins日志："
echo "docker logs -f jenkins-cloud-shop"