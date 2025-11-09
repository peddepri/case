import 'dotenv/config';
// Optional AppDynamics (must run before tracing)
import './appdynamics.js';
import { initTracing } from './tracing.js';
initTracing();

import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import pinoHttp from 'pino-http';
import { logger } from './logger.js';
import { registry, httpRequestsTotal, httpRequestDuration, httpErrorsTotal } from './metrics.js';
import { ordersRouter } from './routes/orders.js';
import { metricsRouter } from './routes/metrics.js';

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json());
app.use(pinoHttp({ logger }));

// Metrics middleware for latency/traffic/errors
app.use((req: Request, res: Response, next: NextFunction) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationSec = Number((process.hrtime.bigint() - start)) / 1e9;
    const route = req.route?.path || req.path || 'unknown';
    const labels = { method: req.method, route, status_code: String(res.statusCode) } as const;
    httpRequestDuration.observe(labels as any, durationSec);
    httpRequestsTotal.inc(labels as any);
    if (res.statusCode >= 400) {
      httpErrorsTotal.inc(labels as any);
    }
  });
  next();
});

app.get('/', (_req, res) => {
  res.status(200).json({
    name: 'Case Backend API',
    version: '0.1.0',
    environment: process.env.NODE_ENV || 'development',
    endpoints: {
      health: '/healthz',
      metrics: '/metrics',
      orders: {
        list: 'GET /api/orders',
        create: 'POST /api/orders',
        getById: 'GET /api/orders/:id'
      }
    },
    aws: {
      region: process.env.AWS_REGION,
      dynamodbEndpoint: process.env.DYNAMODB_ENDPOINT,
      table: process.env.DDB_TABLE
    }
  });
});

app.get('/healthz', (_req, res) => res.status(200).json({ status: 'ok' }));
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', registry.contentType);
  res.end(await registry.metrics());
});

app.use('/api/orders', ordersRouter);
app.use('/api/metrics', metricsRouter);

app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  logger.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'internal' });
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => logger.info(`Backend listening on :${port}`));
}

export default app;
