import { Router, Request, Response } from 'express';
import { logger } from '../logger.js';
import { incOrdersCreated, incOrdersFailed } from '../metrics.js';
import { listOrders, createOrder } from '../repositories/ordersRepo.js';
import axios from 'axios';
interface Order { id: string; item: string; price: number; }

export const ordersRouter = Router();

ordersRouter.get('/', async (_req: Request, res: Response) => {
  const orders = await listOrders();
  res.json({ orders });
});

ordersRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { item, price } = req.body || {};
    if (!item || typeof price !== 'number') {
      return res.status(400).json({ error: 'item and numeric price are required' });
    }
    // Simulate occasional business failure (10%)
    if (Math.random() < 0.1) {
      incOrdersFailed();
      logger.warn({ item, price }, 'Order failed (simulated)');
      return res.status(500).json({ error: 'Order processing failed' });
    }

    const order: Order = { id: `${Date.now()}`, item, price };
    await createOrder(order as any);
    incOrdersCreated();
    logger.info({ order }, 'Order created');
    res.status(201).json(order);
  } catch (err) {
    incOrdersFailed();
    logger.error({ err }, 'Order error');
    res.status(500).json({ error: 'Unexpected error' });
  }
});

// Example of external dependency for WireMock demo
ordersRouter.get('/price/:item', async (req: Request, res: Response) => {
  const item = req.params.item;
  const baseUrl = process.env.PRICE_SERVICE_URL || 'http://localhost:8080';
  try {
    const r = await axios.get(`${baseUrl}/price/${encodeURIComponent(item)}`);
    res.json({ item, price: r.data.price });
  } catch (err) {
    res.status(502).json({ error: 'upstream_error' });
  }
});
