/// <reference types="jest" />
process.env.NODE_ENV = 'test';
// Desabilitar tracing do Datadog nos testes para evitar open handles
process.env.DD_TRACE_ENABLED = 'false';
// Garantir DogStatsD em modo mock
process.env.DD_ENABLE_DOGSTATSD = 'false';

// Encerrar coleta de métricas default do prom-client ao final para não deixar timers abertos
import { stopDefaultMetrics } from '../src/metrics.js';

afterAll(async () => {
  try { stopDefaultMetrics(); } catch { /* no-op */ }
});
