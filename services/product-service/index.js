const express = require('express');
const axios = require('axios');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8082;
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:8081';

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
  res.json({ status: 'ok', service: 'product-service' });
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

// Get all products
app.get('/api/products', async (req, res) => {
  try {
    const keys = await redisClient.keys('product:*');
    const products = [];

    for (const key of keys) {
      const product = await redisClient.get(key);
      if (product) {
        products.push(JSON.parse(product));
      }
    }

    // Sort by createdAt descending
    products.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json(products);
  } catch (error) {
    console.error('Get products error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get product by ID
app.get('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const product = await redisClient.get(`product:${id}`);

    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.json(JSON.parse(product));
  } catch (error) {
    console.error('Get product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create product (requires authentication)
app.post('/api/products', verifyToken, async (req, res) => {
  try {
    const { name, description, price, stock } = req.body;

    if (!name || !price || stock === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const product = {
      id: uuidv4(),
      name,
      description: description || '',
      price: parseFloat(price),
      stock: parseInt(stock),
      createdBy: req.user.username,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    await redisClient.set(`product:${product.id}`, JSON.stringify(product));

    res.status(201).json(product);
  } catch (error) {
    console.error('Create product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update product (requires authentication)
app.put('/api/products/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description, price, stock } = req.body;

    const existingProduct = await redisClient.get(`product:${id}`);
    if (!existingProduct) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const product = JSON.parse(existingProduct);

    // Update fields
    if (name !== undefined) product.name = name;
    if (description !== undefined) product.description = description;
    if (price !== undefined) product.price = parseFloat(price);
    if (stock !== undefined) product.stock = parseInt(stock);
    
    product.updatedAt = new Date().toISOString();
    product.updatedBy = req.user.username;

    await redisClient.set(`product:${id}`, JSON.stringify(product));

    res.json(product);
  } catch (error) {
    console.error('Update product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete product (requires authentication)
app.delete('/api/products/:id', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;

    const exists = await redisClient.exists(`product:${id}`);
    if (!exists) {
      return res.status(404).json({ error: 'Product not found' });
    }

    await redisClient.del(`product:${id}`);

    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Initialize default data
async function initDefaultData() {
  try {
    console.log('Initializing default products...');
    
    const defaultProducts = [
      {
        id: 'prod-1',
        name: 'iPhone 15 Pro',
        description: '最新款苹果手机，搭载A17 Pro芯片，钛金属设计',
        price: 9999,
        stock: 50,
        category: 'electronics',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-2',
        name: 'MacBook Pro 14"',
        description: 'M3 Pro芯片，14英寸Liquid视网膜XDR显示屏',
        price: 16999,
        stock: 30,
        category: 'electronics',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-3',
        name: 'AirPods Pro 2',
        description: '主动降噪，自适应通透模式，个性化空间音频',
        price: 1899,
        stock: 100,
        category: 'electronics',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-4',
        name: '云原生架构设计',
        description: '深入理解云原生架构设计与实践',
        price: 89,
        stock: 200,
        category: 'books',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-5',
        name: 'Kubernetes实战',
        description: '从入门到精通的K8s实战指南',
        price: 79,
        stock: 150,
        category: 'books',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-6',
        name: '程序员T恤',
        description: 'Hello World主题T恤，纯棉材质',
        price: 99,
        stock: 80,
        category: 'clothing',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-7',
        name: '机械键盘',
        description: 'Cherry轴机械键盘，RGB背光',
        price: 599,
        stock: 40,
        category: 'electronics',
        createdAt: new Date().toISOString()
      },
      {
        id: 'prod-8',
        name: '人体工学椅',
        description: '专业人体工学设计，久坐不累',
        price: 2999,
        stock: 20,
        category: 'home',
        createdAt: new Date().toISOString()
      }
    ];
    
    // 添加默认商品
    for (const product of defaultProducts) {
      const exists = await redisClient.exists(`product:${product.id}`);
      if (!exists) {
        await redisClient.set(`product:${product.id}`, JSON.stringify(product));
        console.log(`Created product: ${product.name}`);
      }
    }
    
    console.log('Default products initialized');
    
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
      console.log(`Product service running on port ${PORT}`);
      console.log('Default products initialized - 8 products available');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

start();

// Export for testing
module.exports = { app, verifyToken };