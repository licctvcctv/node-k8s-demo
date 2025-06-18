#!/bin/bash
# 测试npm安装是否正常工作

set -e

echo "🧪 测试npm安装..."

# 创建临时测试目录
TEST_DIR="/tmp/npm-test-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "📍 测试目录: $TEST_DIR"

# 创建基础package.json
cat > package.json << 'EOF'
{
  "name": "npm-test",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "redis": "^4.6.5"
  }
}
EOF

echo "📦 package.json created:"
cat package.json

# 使用Docker测试npm安装（模拟K8s环境）
echo ""
echo "🐳 Testing npm install in Docker container..."

docker run --rm -v "$TEST_DIR:/app" node:18-alpine sh -c "
  cd /app
  echo 'Node.js version:' \$(node --version)
  echo 'npm version:' \$(npm --version)
  
  echo 'Cleaning npm cache...'
  npm cache clean --force
  
  echo 'Upgrading npm...'
  npm install -g npm@latest
  echo 'Updated npm version:' \$(npm --version)
  
  echo 'Configuring npm...'
  npm config set registry https://registry.npmjs.org/
  npm config set strict-ssl false
  npm config set fetch-retry-mintimeout 20000
  npm config set fetch-retry-maxtimeout 120000
  npm config set fetch-retries 3
  
  echo 'Installing dependencies...'
  npm install --production --no-audit --no-fund --verbose
  
  echo 'Verifying installation...'
  if [ -d node_modules ]; then
    echo '✅ node_modules created'
    echo 'Installed packages:'
    ls -la node_modules/ | head -10
    
    # 检查关键模块
    for module in express redis; do
      if [ -d \"node_modules/\$module\" ]; then
        echo \"✅ \$module installed\"
      else
        echo \"❌ \$module missing\"
      fi
    done
  else
    echo '❌ node_modules NOT created'
    exit 1
  fi
"

echo ""
echo "🎯 Testing completed!"
echo "If you see '✅ express installed' and '✅ redis installed' above, npm install should work in K8s"

# 清理测试目录
rm -rf "$TEST_DIR"
echo "🧹 Test directory cleaned up"