const express = require('express');
const axios = require('axios');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);
const app = express();
const PORT = process.env.PORT || 8084;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

// Service URLs
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:8081';
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://product-service:8082';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://order-service:8083';

// Redis client
let redisClient;

async function connectRedis() {
  try {
    redisClient = redis.createClient({ url: REDIS_URL });
    redisClient.on('error', err => console.error('Redis Client Error', err));
    await redisClient.connect();
    console.log('Connected to Redis');
  } catch (error) {
    console.error('Failed to connect to Redis:', error);
  }
}

// Middleware
app.use(helmet({
  contentSecurityPolicy: false,
}));
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Serve shared auth.js
app.get('/auth.js', (req, res) => {
  res.sendFile(path.join(__dirname, '../shared/auth.js'));
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'dashboard-service' });
});

// Get service health status - 真实健康检查
app.get('/api/health-check', async (req, res) => {
  const services = [
    { name: '用户服务', url: USER_SERVICE_URL + '/health', port: '30081' },
    { name: '商品服务', url: PRODUCT_SERVICE_URL + '/health', port: '30082' },
    { name: '订单服务', url: ORDER_SERVICE_URL + '/health', port: '30083' }
  ];
  
  const results = [];
  
  // 并行检查所有服务
  const checks = services.map(async (service) => {
    try {
      const startTime = Date.now();
      const response = await axios.get(service.url, { 
        timeout: 5000,
        validateStatus: (status) => status < 500 // 允许4xx状态码
      });
      const responseTime = Date.now() - startTime;
      
      return {
        name: service.name,
        status: response.status === 200 ? 'healthy' : 'unhealthy',
        port: service.port,
        responseTime: responseTime + 'ms',
        lastCheck: new Date().toISOString(),
        details: response.data
      };
    } catch (error) {
      return {
        name: service.name,
        status: 'unhealthy',
        port: service.port,
        responseTime: 'timeout',
        lastCheck: new Date().toISOString(),
        error: error.code === 'ECONNREFUSED' ? '服务不可达' : 
               error.code === 'ECONNABORTED' ? '请求超时' : 
               error.message
      };
    }
  });
  
  try {
    const results = await Promise.all(checks);
    res.json(results);
  } catch (error) {
    res.status(500).json({ error: 'Health check failed', message: error.message });
  }
});

// Get Kubernetes cluster info
app.get('/api/k8s-info', async (req, res) => {
  try {
    // Get nodes
    const { stdout: nodesOutput } = await execAsync('kubectl get nodes -o json');
    const nodes = JSON.parse(nodesOutput);
    
    // Get pods in cloud-shop namespace
    const { stdout: podsOutput } = await execAsync('kubectl get pods -n cloud-shop -o json');
    const pods = JSON.parse(podsOutput);
    
    // Get services
    const { stdout: servicesOutput } = await execAsync('kubectl get svc -n cloud-shop -o json');
    const services = JSON.parse(servicesOutput);
    
    res.json({
      nodes: nodes.items.map(node => ({
        name: node.metadata.name,
        status: node.status.conditions.find(c => c.type === 'Ready')?.status,
        version: node.status.nodeInfo.kubeletVersion,
        os: node.status.nodeInfo.osImage,
        containerRuntime: node.status.nodeInfo.containerRuntimeVersion
      })),
      pods: pods.items.map(pod => ({
        name: pod.metadata.name,
        namespace: pod.metadata.namespace,
        status: pod.status.phase,
        ready: pod.status.conditions?.find(c => c.type === 'Ready')?.status === 'True',
        restarts: pod.status.containerStatuses?.[0]?.restartCount || 0,
        node: pod.spec.nodeName,
        createdAt: pod.metadata.creationTimestamp
      })),
      services: services.items.map(svc => ({
        name: svc.metadata.name,
        type: svc.spec.type,
        clusterIP: svc.spec.clusterIP,
        ports: svc.spec.ports,
        selector: svc.spec.selector
      }))
    });
  } catch (error) {
    res.status(500).json({ 
      error: 'Failed to get K8s info',
      message: error.message,
      note: 'Make sure kubectl is configured and you have access to the cluster'
    });
  }
});

// Get service statistics - 真实数据
app.get('/api/statistics', async (req, res) => {
  try {
    const stats = {
      users: 0,
      products: 0,
      orders: 0,
      revenue: 0
    };
    
    if (!redisClient) {
      return res.status(500).json({ error: 'Redis not connected' });
    }
    
    // 真实获取用户数 - 扫描 user:* keys
    try {
      const userKeys = await redisClient.keys('user:*');
      stats.users = userKeys.length;
    } catch (err) {
      console.error('Error getting users count:', err);
    }
    
    // 真实获取商品数 - 扫描 product:* keys
    try {
      const productKeys = await redisClient.keys('product:*');
      stats.products = productKeys.length;
    } catch (err) {
      console.error('Error getting products count:', err);
    }
    
    // 真实获取订单数和总销售额 - 扫描 order:* keys
    try {
      const orderKeys = await redisClient.keys('order:*');
      stats.orders = orderKeys.length;
      
      let totalRevenue = 0;
      for (const key of orderKeys) {
        try {
          const orderData = await redisClient.get(key);
          if (orderData) {
            const order = JSON.parse(orderData);
            if (order.totalAmount && order.status !== 'cancelled') {
              totalRevenue += parseFloat(order.totalAmount);
            }
          }
        } catch (orderErr) {
          console.error('Error parsing order:', orderErr);
        }
      }
      stats.revenue = Math.round(totalRevenue * 100) / 100; // 保留2位小数
    } catch (err) {
      console.error('Error getting orders count:', err);
    }
    
    res.json(stats);
  } catch (error) {
    console.error('Statistics error:', error);
    res.status(500).json({ error: 'Failed to get statistics' });
  }
});

// Get API request metrics (mock data)
app.get('/api/metrics', async (req, res) => {
  // In a real scenario, this would collect actual metrics
  const now = Date.now();
  const metrics = [];
  
  // Generate mock metrics for the last hour
  for (let i = 59; i >= 0; i--) {
    metrics.push({
      timestamp: new Date(now - i * 60 * 1000).toISOString(),
      requests: {
        user: Math.floor(Math.random() * 50) + 10,
        product: Math.floor(Math.random() * 100) + 20,
        order: Math.floor(Math.random() * 30) + 5
      }
    });
  }
  
  res.json(metrics);
});

// Start server
async function start() {
  try {
    await connectRedis();
    app.listen(PORT, () => {
      console.log(`Dashboard service running on port ${PORT}`);
      console.log('Connected to Redis for real statistics');
    });
  } catch (error) {
    console.error('Failed to start dashboard service:', error);
    process.exit(1);
  }
}

start();