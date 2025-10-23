import client from 'prom-client';
import { StatsD } from 'hot-shots';

// Prometheus metrics (4 golden signals)
export const registry = new client.Registry();
// Em testes, evite iniciar timers do prom-client (open handles)
let defaultMetricsInterval: NodeJS.Timeout | undefined;
if (process.env.NODE_ENV !== 'test') {
  // Nota: versões mais novas do prom-client podem não retornar o intervalo; o clear é opcional
  defaultMetricsInterval = client.collectDefaultMetrics({ register: registry, prefix: 'backend_' }) as unknown as NodeJS.Timeout;
}

export function stopDefaultMetrics() {
  if (defaultMetricsInterval) {
    clearInterval(defaultMetricsInterval);
  }
}

export const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.05, 0.1, 0.2, 0.5, 1, 2, 5]
});

export const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

export const httpErrorsTotal = new client.Counter({
  name: 'http_errors_total',
  help: 'Total HTTP error responses',
  labelNames: ['method', 'route', 'status_code']
});

registry.registerMetric(httpRequestDuration);
registry.registerMetric(httpRequestsTotal);
registry.registerMetric(httpErrorsTotal);

// DogStatsD for business metrics
const enableDogStatsD = process.env.DD_ENABLE_DOGSTATSD === 'true';
export const statsd = new StatsD({
  host: process.env.DD_DOGSTATSD_HOST || 'localhost',
  port: Number(process.env.DD_DOGSTATSD_PORT || 8125),
  mock: !enableDogStatsD,
  globalTags: {
    service: process.env.DD_SERVICE || 'backend',
    env: process.env.DD_ENV || 'dev',
    version: process.env.DD_VERSION || '0.1.0'
  }
});

export function incOrdersCreated() {
  statsd.increment('orders.created');
}

export function incOrdersFailed() {
  statsd.increment('orders.failed');
}
