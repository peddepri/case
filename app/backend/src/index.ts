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

app.get('/healthz', (_req, res) => res.status(200).json({ status: 'ok' }));
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', registry.contentType);
  res.end(await registry.metrics());
});

app.use('/api/orders', ordersRouter);

app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  logger.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'internal' });
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => logger.info(`Backend listening on :${port}`));
}

export default app;
