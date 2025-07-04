const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8081;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

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
  res.json({ status: 'ok', service: 'user-service' });
});

// User registration
app.post('/api/register', async (req, res) => {
  try {
    const { username, password, email } = req.body;
    
    if (!username || !password || !email) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if user exists
    const existingUser = await redisClient.get(`user:${username}`);
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Store user
    const user = {
      username,
      password: hashedPassword,
      email,
      createdAt: new Date().toISOString()
    };
    
    await redisClient.set(`user:${username}`, JSON.stringify(user));
    
    res.status(201).json({ 
      message: 'User created successfully',
      username: user.username 
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// User login
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Missing credentials' });
    }

    // Get user
    const userData = await redisClient.get(`user:${username}`);
    if (!userData) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = JSON.parse(userData);
    
    // Verify password
    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT
    const token = jwt.sign(
      { username: user.username, email: user.email },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({ 
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify JWT middleware
function verifyToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    req.user = decoded;
    next();
  });
}

// Verify token endpoint
app.get('/api/verify', verifyToken, (req, res) => {
  res.json({ 
    valid: true, 
    user: req.user 
  });
});

// Get user profile
app.get('/api/profile', verifyToken, async (req, res) => {
  try {
    const userData = await redisClient.get(`user:${req.user.username}`);
    if (!userData) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = JSON.parse(userData);
    const { password, ...profile } = user; // Remove password
    
    res.json(profile);
  } catch (error) {
    console.error('Profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Initialize default data
async function initDefaultData() {
  try {
    console.log('Initializing default users...');
    
    // Check if admin exists
    const adminExists = await redisClient.exists('user:admin');
    if (!adminExists) {
      const hashedPassword = await bcrypt.hash('admin123', 10);
      const adminUser = {
        id: 'admin',
        username: 'admin',
        email: 'admin@cloudshop.com',
        password: hashedPassword,
        role: 'admin',
        createdAt: new Date().toISOString()
      };
      await redisClient.set(`user:admin`, JSON.stringify(adminUser));
      console.log('Created default admin user (username: admin, password: admin123)');
    }
    
    // Check if demo user exists
    const demoExists = await redisClient.exists('user:demo');
    if (!demoExists) {
      const hashedPassword = await bcrypt.hash('demo123', 10);
      const demoUser = {
        id: 'demo',
        username: 'demo',
        email: 'demo@cloudshop.com',
        password: hashedPassword,
        role: 'user',
        createdAt: new Date().toISOString()
      };
      await redisClient.set(`user:demo`, JSON.stringify(demoUser));
      console.log('Created default demo user (username: demo, password: demo123)');
    }
    
    // Check if test user exists
    const testExists = await redisClient.exists('user:test');
    if (!testExists) {
      const hashedPassword = await bcrypt.hash('test123', 10);
      const testUser = {
        id: 'test',
        username: 'test',
        email: 'test@cloudshop.com',
        password: hashedPassword,
        role: 'user',
        createdAt: new Date().toISOString()
      };
      await redisClient.set(`user:test`, JSON.stringify(testUser));
      console.log('Created default test user (username: test, password: test123)');
    }
    
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
      console.log(`User service running on port ${PORT}`);
      console.log('Default users:');
      console.log('  - Admin: username=admin, password=admin123');
      console.log('  - Demo: username=demo, password=demo123');
      console.log('  - Test: username=test, password=test123');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

start();

// Export for testing
module.exports = { app, verifyToken };