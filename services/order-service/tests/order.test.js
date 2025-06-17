const request = require('supertest');
const redis = require('redis-mock');
const axios = require('axios');

// Mock Redis and axios
jest.mock('redis', () => redis);
jest.mock('axios');

// Import app after mocking
const { app } = require('../index');

describe('Order Service', () => {
  let redisClient;
  const mockToken = 'Bearer valid-token';
  const mockUser = { username: 'testuser', email: 'test@example.com' };
  
  const mockProduct = {
    id: 'prod-123',
    name: 'Test Product',
    price: 100,
    stock: 10
  };

  beforeAll(() => {
    // Setup mock Redis client
    redisClient = redis.createClient();
    
    // Mock axios for token verification and product service
    axios.get.mockImplementation((url) => {
      if (url.includes('/api/verify')) {
        return Promise.resolve({ data: { valid: true, user: mockUser } });
      }
      if (url.includes('/api/products/prod-123')) {
        return Promise.resolve({ data: mockProduct });
      }
      return Promise.reject(new Error('Not found'));
    });

    axios.put.mockImplementation(() => {
      return Promise.resolve({ data: { success: true } });
    });
  });

  afterEach(async () => {
    // Clear Redis data between tests
    await redisClient.flushall();
    jest.clearAllMocks();
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        status: 'ok',
        service: 'order-service'
      });
    });
  });

  describe('POST /api/orders', () => {
    it('should create a new order', async () => {
      const orderData = {
        items: [
          { productId: 'prod-123', quantity: 2 }
        ]
      };

      const res = await request(app)
        .post('/api/orders')
        .set('Authorization', mockToken)
        .send(orderData);

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        userId: mockUser.username,
        items: [{
          productId: 'prod-123',
          productName: 'Test Product',
          price: 100,
          quantity: 2,
          subtotal: 200
        }],
        totalAmount: 200,
        status: 'pending'
      });
      expect(res.body).toHaveProperty('id');
      expect(res.body).toHaveProperty('createdAt');
    });

    it('should return 401 without authentication', async () => {
      const res = await request(app)
        .post('/api/orders')
        .send({
          items: [{ productId: 'prod-123', quantity: 1 }]
        });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'No token provided');
    });

    it('should return 400 for missing items', async () => {
      const res = await request(app)
        .post('/api/orders')
        .set('Authorization', mockToken)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Items required');
    });

    it('should return 400 for invalid item format', async () => {
      const res = await request(app)
        .post('/api/orders')
        .set('Authorization', mockToken)
        .send({
          items: [{ productId: 'prod-123' }] // Missing quantity
        });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Invalid item format');
    });

    it('should return 400 for insufficient stock', async () => {
      axios.get.mockImplementationOnce((url) => {
        if (url.includes('/api/verify')) {
          return Promise.resolve({ data: { valid: true, user: mockUser } });
        }
        if (url.includes('/api/products/')) {
          return Promise.resolve({ 
            data: { ...mockProduct, stock: 1 } // Low stock
          });
        }
      });

      const res = await request(app)
        .post('/api/orders')
        .set('Authorization', mockToken)
        .send({
          items: [{ productId: 'prod-123', quantity: 5 }]
        });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain('Insufficient stock');
    });
  });

  describe('GET /api/orders', () => {
    it('should return user orders', async () => {
      // Create test orders
      const orders = [
        {
          id: 'order-1',
          userId: mockUser.username,
          items: [],
          totalAmount: 100,
          status: 'pending',
          createdAt: new Date().toISOString()
        },
        {
          id: 'order-2',
          userId: mockUser.username,
          items: [],
          totalAmount: 200,
          status: 'completed',
          createdAt: new Date().toISOString()
        }
      ];

      // Add orders to Redis
      for (const order of orders) {
        await redisClient.set(`order:${order.id}`, JSON.stringify(order));
        await redisClient.sadd(`user:${mockUser.username}:orders`, order.id);
      }

      const res = await request(app)
        .get('/api/orders')
        .set('Authorization', mockToken);

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(2);
    });

    it('should return empty array for user with no orders', async () => {
      const res = await request(app)
        .get('/api/orders')
        .set('Authorization', mockToken);

      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('should return 401 without authentication', async () => {
      const res = await request(app).get('/api/orders');
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/orders/:id', () => {
    it('should return order by id', async () => {
      const order = {
        id: 'order-123',
        userId: mockUser.username,
        items: [],
        totalAmount: 100,
        status: 'pending',
        createdAt: new Date().toISOString()
      };

      await redisClient.set(`order:${order.id}`, JSON.stringify(order));

      const res = await request(app)
        .get('/api/orders/order-123')
        .set('Authorization', mockToken);

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject(order);
    });

    it('should return 404 for non-existent order', async () => {
      const res = await request(app)
        .get('/api/orders/nonexistent')
        .set('Authorization', mockToken);

      expect(res.status).toBe(404);
      expect(res.body).toHaveProperty('error', 'Order not found');
    });

    it('should return 403 for order belonging to another user', async () => {
      const order = {
        id: 'order-123',
        userId: 'anotheruser',
        items: [],
        totalAmount: 100,
        status: 'pending'
      };

      await redisClient.set(`order:${order.id}`, JSON.stringify(order));

      const res = await request(app)
        .get('/api/orders/order-123')
        .set('Authorization', mockToken);

      expect(res.status).toBe(403);
      expect(res.body).toHaveProperty('error', 'Access denied');
    });
  });

  describe('PUT /api/orders/:id/status', () => {
    it('should update order status', async () => {
      const order = {
        id: 'order-123',
        userId: mockUser.username,
        items: [],
        totalAmount: 100,
        status: 'pending',
        createdAt: new Date().toISOString()
      };

      await redisClient.set(`order:${order.id}`, JSON.stringify(order));

      const res = await request(app)
        .put('/api/orders/order-123/status')
        .set('Authorization', mockToken)
        .send({ status: 'completed' });

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        id: 'order-123',
        status: 'completed'
      });
      expect(res.body).toHaveProperty('updatedAt');
    });

    it('should return 400 for invalid status', async () => {
      const order = {
        id: 'order-123',
        userId: mockUser.username,
        status: 'pending'
      };

      await redisClient.set(`order:${order.id}`, JSON.stringify(order));

      const res = await request(app)
        .put('/api/orders/order-123/status')
        .set('Authorization', mockToken)
        .send({ status: 'invalid' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Invalid status');
    });

    it('should return 404 for non-existent order', async () => {
      const res = await request(app)
        .put('/api/orders/nonexistent/status')
        .set('Authorization', mockToken)
        .send({ status: 'completed' });

      expect(res.status).toBe(404);
    });

    it('should return 403 for order belonging to another user', async () => {
      const order = {
        id: 'order-123',
        userId: 'anotheruser',
        status: 'pending'
      };

      await redisClient.set(`order:${order.id}`, JSON.stringify(order));

      const res = await request(app)
        .put('/api/orders/order-123/status')
        .set('Authorization', mockToken)
        .send({ status: 'completed' });

      expect(res.status).toBe(403);
    });
  });
});