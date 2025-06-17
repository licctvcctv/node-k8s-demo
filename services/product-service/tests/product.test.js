const request = require('supertest');
const redis = require('redis-mock');
const axios = require('axios');

// Mock Redis and axios
jest.mock('redis', () => redis);
jest.mock('axios');

// Import app after mocking
const { app } = require('../index');

describe('Product Service', () => {
  let redisClient;
  const mockToken = 'Bearer valid-token';
  const mockUser = { username: 'testuser', email: 'test@example.com' };

  beforeAll(() => {
    // Setup mock Redis client
    redisClient = redis.createClient();
    
    // Mock axios for token verification
    axios.get.mockImplementation((url) => {
      if (url.includes('/api/verify')) {
        return Promise.resolve({ data: { valid: true, user: mockUser } });
      }
      return Promise.reject(new Error('Not found'));
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
        service: 'product-service'
      });
    });
  });

  describe('GET /api/products', () => {
    it('should return empty array when no products', async () => {
      const res = await request(app).get('/api/products');
      expect(res.status).toBe(200);
      expect(res.body).toEqual([]);
    });

    it('should return all products', async () => {
      // Create test products
      const products = [
        {
          id: '1',
          name: 'Product 1',
          price: 100,
          stock: 10,
          createdAt: new Date().toISOString()
        },
        {
          id: '2',
          name: 'Product 2',
          price: 200,
          stock: 20,
          createdAt: new Date().toISOString()
        }
      ];

      // Add products to Redis
      for (const product of products) {
        await redisClient.set(`product:${product.id}`, JSON.stringify(product));
      }

      const res = await request(app).get('/api/products');
      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(2);
    });
  });

  describe('GET /api/products/:id', () => {
    it('should return product by id', async () => {
      const product = {
        id: '123',
        name: 'Test Product',
        price: 99.99,
        stock: 5
      };

      await redisClient.set(`product:${product.id}`, JSON.stringify(product));

      const res = await request(app).get('/api/products/123');
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject(product);
    });

    it('should return 404 for non-existent product', async () => {
      const res = await request(app).get('/api/products/nonexistent');
      expect(res.status).toBe(404);
      expect(res.body).toHaveProperty('error', 'Product not found');
    });
  });

  describe('POST /api/products', () => {
    it('should create a new product with authentication', async () => {
      const newProduct = {
        name: 'New Product',
        description: 'Test description',
        price: 99.99,
        stock: 10
      };

      const res = await request(app)
        .post('/api/products')
        .set('Authorization', mockToken)
        .send(newProduct);

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        name: newProduct.name,
        description: newProduct.description,
        price: newProduct.price,
        stock: newProduct.stock,
        createdBy: mockUser.username
      });
      expect(res.body).toHaveProperty('id');
      expect(res.body).toHaveProperty('createdAt');
    });

    it('should return 401 without authentication', async () => {
      const res = await request(app)
        .post('/api/products')
        .send({
          name: 'Product',
          price: 100,
          stock: 10
        });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'No token provided');
    });

    it('should return 400 for missing required fields', async () => {
      const res = await request(app)
        .post('/api/products')
        .set('Authorization', mockToken)
        .send({
          name: 'Product'
        });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Missing required fields');
    });
  });

  describe('PUT /api/products/:id', () => {
    it('should update an existing product', async () => {
      const product = {
        id: '123',
        name: 'Original Product',
        price: 100,
        stock: 10,
        createdAt: new Date().toISOString()
      };

      await redisClient.set(`product:${product.id}`, JSON.stringify(product));

      const updates = {
        name: 'Updated Product',
        price: 150
      };

      const res = await request(app)
        .put('/api/products/123')
        .set('Authorization', mockToken)
        .send(updates);

      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        id: '123',
        name: 'Updated Product',
        price: 150,
        stock: 10,
        updatedBy: mockUser.username
      });
      expect(res.body).toHaveProperty('updatedAt');
    });

    it('should return 404 for non-existent product', async () => {
      const res = await request(app)
        .put('/api/products/nonexistent')
        .set('Authorization', mockToken)
        .send({ name: 'Updated' });

      expect(res.status).toBe(404);
      expect(res.body).toHaveProperty('error', 'Product not found');
    });

    it('should return 401 without authentication', async () => {
      const res = await request(app)
        .put('/api/products/123')
        .send({ name: 'Updated' });

      expect(res.status).toBe(401);
    });
  });

  describe('DELETE /api/products/:id', () => {
    it('should delete an existing product', async () => {
      const product = {
        id: '123',
        name: 'Product to Delete',
        price: 100,
        stock: 10
      };

      await redisClient.set(`product:${product.id}`, JSON.stringify(product));

      const res = await request(app)
        .delete('/api/products/123')
        .set('Authorization', mockToken);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('message', 'Product deleted successfully');

      // Verify product is deleted
      const getRes = await request(app).get('/api/products/123');
      expect(getRes.status).toBe(404);
    });

    it('should return 404 for non-existent product', async () => {
      const res = await request(app)
        .delete('/api/products/nonexistent')
        .set('Authorization', mockToken);

      expect(res.status).toBe(404);
      expect(res.body).toHaveProperty('error', 'Product not found');
    });

    it('should return 401 without authentication', async () => {
      const res = await request(app).delete('/api/products/123');
      expect(res.status).toBe(401);
    });
  });
});