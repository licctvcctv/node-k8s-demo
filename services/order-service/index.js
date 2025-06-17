const express = require('express');
const axios = require('axios');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');

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
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'order-service' });
});

// JWT verification middleware
async function verifyToken(req, res, next) {
  try {
    const token = req.headers['authorization'];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // Verify token with user service
    const response = await axios.get(`${USER_SERVICE_URL}/api/verify`, {
      headers: { 'Authorization': token }
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
    const { items } = req.body;

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
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    // Update product stock
    for (const item of items) {
      try {
        await axios.put(
          `${PRODUCT_SERVICE_URL}/api/products/${item.productId}`,
          { stock: item.quantity * -1 }, // Decrease stock
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

// Get user orders
app.get('/api/orders', verifyToken, async (req, res) => {
  try {
    const orderIds = await redisClient.sMembers(`user:${req.user.username}:orders`);
    const orders = [];

    for (const orderId of orderIds) {
      const orderData = await redisClient.get(`order:${orderId}`);
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

    const validStatuses = ['pending', 'processing', 'completed', 'cancelled'];
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

// Start server
async function start() {
  try {
    await connectRedis();
    app.listen(PORT, () => {
      console.log(`Order service running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

start();

// Export for testing
module.exports = { app, verifyToken };