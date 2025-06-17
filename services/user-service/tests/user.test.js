const request = require('supertest');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const redis = require('redis-mock');

// Mock Redis
jest.mock('redis', () => redis);

// Import app after mocking
const { app } = require('../index');

describe('User Service', () => {
  let redisClient;
  
  beforeAll(() => {
    // Setup mock Redis client
    redisClient = redis.createClient();
  });

  afterEach(async () => {
    // Clear Redis data between tests
    await redisClient.flushall();
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        status: 'ok',
        service: 'user-service'
      });
    });
  });

  describe('POST /api/register', () => {
    it('should register a new user', async () => {
      const userData = {
        username: 'testuser',
        password: 'password123',
        email: 'test@example.com'
      };

      const res = await request(app)
        .post('/api/register')
        .send(userData);

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('message', 'User created successfully');
      expect(res.body).toHaveProperty('username', 'testuser');
    });

    it('should return 400 for missing fields', async () => {
      const res = await request(app)
        .post('/api/register')
        .send({ username: 'testuser' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Missing required fields');
    });

    it('should return 409 for existing user', async () => {
      const userData = {
        username: 'testuser',
        password: 'password123',
        email: 'test@example.com'
      };

      // Register first time
      await request(app).post('/api/register').send(userData);
      
      // Try to register again
      const res = await request(app)
        .post('/api/register')
        .send(userData);

      expect(res.status).toBe(409);
      expect(res.body).toHaveProperty('error', 'User already exists');
    });
  });

  describe('POST /api/login', () => {
    beforeEach(async () => {
      // Register a test user
      await request(app)
        .post('/api/register')
        .send({
          username: 'testuser',
          password: 'password123',
          email: 'test@example.com'
        });
    });

    it('should login with valid credentials', async () => {
      const res = await request(app)
        .post('/api/login')
        .send({
          username: 'testuser',
          password: 'password123'
        });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('message', 'Login successful');
      expect(res.body).toHaveProperty('token');
      expect(res.body).toHaveProperty('username', 'testuser');
    });

    it('should return 401 for invalid password', async () => {
      const res = await request(app)
        .post('/api/login')
        .send({
          username: 'testuser',
          password: 'wrongpassword'
        });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'Invalid credentials');
    });

    it('should return 401 for non-existent user', async () => {
      const res = await request(app)
        .post('/api/login')
        .send({
          username: 'nonexistent',
          password: 'password123'
        });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'Invalid credentials');
    });

    it('should return 400 for missing credentials', async () => {
      const res = await request(app)
        .post('/api/login')
        .send({ username: 'testuser' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Missing credentials');
    });
  });

  describe('GET /api/verify', () => {
    let token;

    beforeEach(async () => {
      // Register and login to get token
      await request(app)
        .post('/api/register')
        .send({
          username: 'testuser',
          password: 'password123',
          email: 'test@example.com'
        });

      const loginRes = await request(app)
        .post('/api/login')
        .send({
          username: 'testuser',
          password: 'password123'
        });

      token = loginRes.body.token;
    });

    it('should verify valid token', async () => {
      const res = await request(app)
        .get('/api/verify')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('valid', true);
      expect(res.body).toHaveProperty('user');
      expect(res.body.user).toHaveProperty('username', 'testuser');
    });

    it('should return 401 for missing token', async () => {
      const res = await request(app).get('/api/verify');

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'No token provided');
    });

    it('should return 401 for invalid token', async () => {
      const res = await request(app)
        .get('/api/verify')
        .set('Authorization', 'Bearer invalid-token');

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'Invalid token');
    });
  });

  describe('GET /api/profile', () => {
    let token;

    beforeEach(async () => {
      // Register and login to get token
      await request(app)
        .post('/api/register')
        .send({
          username: 'testuser',
          password: 'password123',
          email: 'test@example.com'
        });

      const loginRes = await request(app)
        .post('/api/login')
        .send({
          username: 'testuser',
          password: 'password123'
        });

      token = loginRes.body.token;
    });

    it('should get user profile', async () => {
      const res = await request(app)
        .get('/api/profile')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('username', 'testuser');
      expect(res.body).toHaveProperty('email', 'test@example.com');
      expect(res.body).not.toHaveProperty('password');
    });

    it('should return 401 without token', async () => {
      const res = await request(app).get('/api/profile');

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error', 'No token provided');
    });
  });
});