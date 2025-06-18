const express = require('express');
const axios = require('axios');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);
const app = express();
const PORT = process.env.PORT || 8084;

// Service URLs
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:8081';
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://product-service:8082';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://order-service:8083';

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

// Get service health status
app.get('/api/health-check', async (req, res) => {
  const services = [
    { name: 'User Service', url: USER_SERVICE_URL + '/health', port: '30081' },
    { name: 'Product Service', url: PRODUCT_SERVICE_URL + '/health', port: '30082' },
    { name: 'Order Service', url: ORDER_SERVICE_URL + '/health', port: '30083' }
  ];
  
  const results = [];
  
  for (const service of services) {
    try {
      const response = await axios.get(service.url, { timeout: 3000 });
      results.push({
        name: service.name,
        status: 'healthy',
        port: service.port,
        response: response.data
      });
    } catch (error) {
      results.push({
        name: service.name,
        status: 'unhealthy',
        port: service.port,
        error: error.message
      });
    }
  }
  
  res.json(results);
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

// Get service statistics
app.get('/api/statistics', async (req, res) => {
  try {
    const stats = {
      users: 0,
      products: 0,
      orders: 0,
      revenue: 0
    };
    
    // Mock statistics (in real scenario, these would query the actual services)
    stats.users = 3; // Default users
    stats.products = 8; // Default products
    stats.orders = 4; // Default orders
    stats.revenue = 16352; // Sum of default orders
    
    res.json(stats);
  } catch (error) {
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
app.listen(PORT, () => {
  console.log(`Dashboard service running on port ${PORT}`);
});