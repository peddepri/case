import request from 'supertest';
import app from '../src/index.js';

describe('Orders API', () => {
  it('GET /api/orders returns 200', async () => {
    const res = await request(app).get('/api/orders');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.orders)).toBe(true);
  });

  it('POST /api/orders validates body', async () => {
    const res = await request(app).post('/api/orders').send({});
    expect(res.status).toBe(400);
  });
});
