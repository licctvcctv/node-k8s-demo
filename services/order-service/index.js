const express = require('express');
const axios = require('axios');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8083;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:8081';
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://localhost:8082';

// Redis client
let redisClient;

async function connectRedis() {
  redisClient = redis.createClient({ url: REDIS_URL });
  redisClient.on('error', err => console.error('Redis Client Error', err));
  await redisClient.connect();
  console.log('Connected to Redis');
}

// Middleware
app.use(helmet({
  contentSecurityPolicy: false, // 允许加载外部资源
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
  res.json({ status: 'ok', service: 'order-service' });
});

// JWT verification middleware
async function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers['authorization'];
    
    if (!authHeader) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // Verify token with user service
    const response = await axios.get(`${USER_SERVICE_URL}/api/verify`, {
      headers: { 'Authorization': authHeader }  // 直接传递完整的 "Bearer token" 格式
    });

    req.user = response.data.user;
    next();
  } catch (error) {
    console.error('Token verification error:', error.message);
    res.status(401).json({ error: 'Invalid token' });
  }
}

// Create order
app.post('/api/orders', verifyToken, async (req, res) => {
  try {
    const { items, shippingAddress, notes } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Items required' });
    }

    // Validate and calculate order
    let totalAmount = 0;
    const orderItems = [];

    for (const item of items) {
      if (!item.productId || !item.quantity) {
        return res.status(400).json({ error: 'Invalid item format' });
      }

      // Get product details
      try {
        const productRes = await axios.get(`${PRODUCT_SERVICE_URL}/api/products/${item.productId}`);
        const product = productRes.data;

        if (product.stock < item.quantity) {
          return res.status(400).json({ 
            error: `Insufficient stock for product ${product.name}` 
          });
        }

        const itemTotal = product.price * item.quantity;
        totalAmount += itemTotal;

        orderItems.push({
          productId: product.id,
          productName: product.name,
          price: product.price,
          quantity: item.quantity,
          subtotal: itemTotal
        });
      } catch (error) {
        return res.status(400).json({ 
          error: `Product ${item.productId} not found` 
        });
      }
    }

    // Create order
    const order = {
      id: uuidv4(),
      userId: req.user.username,
      items: orderItems,
      totalAmount,
      shippingAddress: shippingAddress || '',
      notes: notes || '',
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    // Update product stock
    for (const item of orderItems) {
      try {
        // Get current product to calculate new stock
        const productRes = await axios.get(`${PRODUCT_SERVICE_URL}/api/products/${item.productId}`);
        const currentStock = productRes.data.stock;
        const newStock = currentStock - item.quantity;
        
        // Update stock with new value
        await axios.put(
          `${PRODUCT_SERVICE_URL}/api/products/${item.productId}`,
          { stock: newStock },
          { headers: { 'Authorization': req.headers['authorization'] } }
        );
      } catch (error) {
        console.error('Failed to update stock:', error.message);
      }
    }

    // Save order
    await redisClient.set(`order:${order.id}`, JSON.stringify(order));
    
    // Add to user's orders
    await redisClient.sAdd(`user:${req.user.username}:orders`, order.id);

    res.status(201).json(order);
  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get orders (all orders if no token, user orders if authenticated)
app.get('/api/orders', async (req, res) => {
  try {
    const token = req.headers['authorization'];
    
    if (token) {
      // If authenticated, get user-specific orders
      try {
        const userResponse = await axios.get(`${USER_SERVICE_URL}/api/verify`, {
          headers: { 'Authorization': token }
        });
        const user = userResponse.data.user;
        
        const orderIds = await redisClient.sMembers(`user:${user.username}:orders`);
        const orders = [];

        for (const orderId of orderIds) {
          const orderData = await redisClient.get(`order:${orderId}`);
          if (orderData) {
            orders.push(JSON.parse(orderData));
          }
        }

        // Sort by createdAt descending
        orders.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        return res.json(orders);
      } catch (authError) {
        // If token verification fails, fall through to get all orders
      }
    }
    
    // Get all orders (for public viewing or if not authenticated)
    const keys = await redisClient.keys('order:*');
    const orders = [];

    for (const key of keys) {
      const orderData = await redisClient.get(key);
      if (orderData) {
        orders.push(JSON.parse(orderData));
      }
    }

    // Sort by createdAt descending
    orders.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json(orders);
  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get order by ID
app.get('/api/orders/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const orderData = await redisClient.get(`order:${id}`);

    if (!orderData) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const order = JSON.parse(orderData);

    // Check if order belongs to user
    if (order.userId !== req.user.username) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json(order);
  } catch (error) {
    console.error('Get order error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update order status
app.put('/api/orders/:id/status', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = ['pending', 'paid', 'shipped', 'delivered', 'cancelled'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const orderData = await redisClient.get(`order:${id}`);
    if (!orderData) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const order = JSON.parse(orderData);

    // Check if order belongs to user
    if (order.userId !== req.user.username) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Update status
    order.status = status;
    order.updatedAt = new Date().toISOString();

    await redisClient.set(`order:${id}`, JSON.stringify(order));

    res.json(order);
  } catch (error) {
    console.error('Update order error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Initialize default data
async function initDefaultData() {
  try {
    console.log('Initializing default orders...');
    
    const defaultOrders = [
      {
        id: 'order-demo-1',
        userId: 'demo',
        items: [
          {
            productId: 'prod-1',
            productName: 'iPhone 15 Pro',
            quantity: 1,
            price: 9999
          }
        ],
        totalAmount: 9999,
        status: 'delivered',
        shippingAddress: '北京市朝阳区云原生大道1号',
        notes: '演示订单 - 已完成',
        createdAt: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
        updatedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString()
      },
      {
        id: 'order-demo-2',
        userId: 'demo',
        items: [
          {
            productId: 'prod-4',
            productName: '云原生架构设计',
            quantity: 2,
            price: 89
          },
          {
            productId: 'prod-5',
            productName: 'Kubernetes实战',
            quantity: 1,
            price: 79
          }
        ],
        totalAmount: 257,
        status: 'shipped',
        shippingAddress: '上海市浦东新区容器路88号',
        notes: '技术书籍订单',
        createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
        updatedAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString()
      },
      {
        id: 'order-test-1',
        userId: 'test',
        items: [
          {
            productId: 'prod-3',
            productName: 'AirPods Pro 2',
            quantity: 1,
            price: 1899
          }
        ],
        totalAmount: 1899,
        status: 'paid',
        shippingAddress: '广州市天河区微服务街520号',
        notes: '生日礼物',
        createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000).toISOString()
      },
      {
        id: 'order-admin-1',
        userId: 'admin',
        items: [
          {
            productId: 'prod-7',
            productName: '机械键盘',
            quantity: 2,
            price: 599
          },
          {
            productId: 'prod-8',
            productName: '人体工学椅',
            quantity: 1,
            price: 2999
          }
        ],
        totalAmount: 4197,
        status: 'pending',
        shippingAddress: '深圳市南山区DevOps大厦',
        notes: '办公设备采购',
        createdAt: new Date().toISOString()
      }
    ];
    
    // 添加默认订单
    for (const order of defaultOrders) {
      const exists = await redisClient.exists(`order:${order.id}`);
      if (!exists) {
        await redisClient.set(`order:${order.id}`, JSON.stringify(order));
        console.log(`Created order: ${order.id} for user ${order.userId}`);
      }
    }
    
    console.log('Default orders initialized');
    
  } catch (error) {
    console.error('Error initializing default data:', error);
  }
}

// Start server
async function start() {
  try {
    await connectRedis();
    await initDefaultData();
    app.listen(PORT, () => {
      console.log(`Order service running on port ${PORT}`);
      console.log('Default orders initialized - 4 sample orders created');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

start();

// Export for testing
module.exports = { app, verifyToken };