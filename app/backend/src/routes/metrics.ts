import { Router } from 'express';
import { logger } from '../logger.js';
import { Counter, Gauge, register } from 'prom-client';

const router = Router();

// Prometheus metrics for Web Vitals
const webVitalsFCP = new Gauge({
  name: 'frontend_web_vitals_fcp',
  help: 'First Contentful Paint in milliseconds',
});

const webVitalsLCP = new Gauge({
  name: 'frontend_web_vitals_lcp',
  help: 'Largest Contentful Paint in milliseconds',
});

const webVitalsFID = new Gauge({
  name: 'frontend_web_vitals_fid',
  help: 'First Input Delay in milliseconds',
});

const webVitalsCLS = new Gauge({
  name: 'frontend_web_vitals_cls',
  help: 'Cumulative Layout Shift score',
});

const webVitalsTTFB = new Gauge({
  name: 'frontend_web_vitals_ttfb',
  help: 'Time to First Byte in milliseconds',
});

const webVitalsTotal = new Counter({
  name: 'frontend_web_vitals_total',
  help: 'Total number of Web Vitals metrics received',
  labelNames: ['metric_name', 'rating'],
});

// Frontend metrics
const frontendRequestsTotal = new Counter({
  name: 'frontend_requests_total',
  help: 'Total frontend requests',
  labelNames: ['route'],
});

const frontendErrorsTotal = new Counter({
  name: 'frontend_errors_total',
  help: 'Total frontend errors',
  labelNames: ['route'],
});

// Mobile metrics
const mobileRequestsTotal = new Counter({
  name: 'mobile_requests_total',
  help: 'Total mobile requests',
  labelNames: ['route'],
});

const mobileErrorsTotal = new Counter({
  name: 'mobile_errors_total',
  help: 'Total mobile errors',
  labelNames: ['route'],
});

// POST /api/metrics/web-vitals - Receive Web Vitals from frontend
router.post('/web-vitals', (req, res) => {
  try {
    const { name, value, rating, delta, id, timestamp } = req.body;

    if (!name || value === undefined) {
      return res.status(400).json({ error: 'Missing required fields: name, value' });
    }

    // Update Prometheus metrics
    switch (name) {
      case 'FCP':
        webVitalsFCP.set(value);
        break;
      case 'LCP':
        webVitalsLCP.set(value);
        break;
      case 'FID':
        webVitalsFID.set(value);
        break;
      case 'CLS':
        webVitalsCLS.set(value);
        break;
      case 'TTFB':
        webVitalsTTFB.set(value);
        break;
      default:
        logger.warn({ name, value }, 'Unknown Web Vital metric');
    }

    // Increment total counter
    webVitalsTotal.inc({ metric_name: name, rating: rating || 'unknown' });

    logger.info({
      name,
      value,
      rating,
      delta,
      id,
      timestamp,
    }, 'Web Vital metric received');

    res.status(200).json({ status: 'ok' });
  } catch (error) {
    logger.error({ error }, 'Error processing Web Vitals metric');
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/metrics/frontend - Receive frontend metrics (requests, errors, latency)
router.post('/frontend', (req, res) => {
  try {
    const { route, duration, error } = req.body;

    if (!route) {
      return res.status(400).json({ error: 'Missing required field: route' });
    }

    // Track request
    (frontendRequestsTotal as Counter<string>).inc({ route });

    // Track error if occurred
    if (error) {
      (frontendErrorsTotal as Counter<string>).inc({ route });
    }

    logger.info({ route, duration, error }, 'Frontend metric received');

    res.status(200).json({ status: 'ok' });
  } catch (error) {
    logger.error({ error }, 'Error processing frontend metric');
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/metrics/mobile - Receive mobile metrics
router.post('/mobile', (req, res) => {
  try {
    const { route, duration, error } = req.body;

    if (!route) {
      return res.status(400).json({ error: 'Missing required field: route' });
    }

    // Track request
    (mobileRequestsTotal as Counter<string>).inc({ route });

    // Track error if occurred
    if (error) {
      (mobileErrorsTotal as Counter<string>).inc({ route });
    }

    logger.info({ route, duration, error }, 'Mobile metric received');

    res.status(200).json({ status: 'ok' });
  } catch (error) {
    logger.error({ error }, 'Error processing mobile metric');
    res.status(500).json({ error: 'Internal server error' });
  }
});

export { router as metricsRouter };
