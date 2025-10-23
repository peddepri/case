// Initialize Datadog tracer as early as possible
import ddTrace from 'dd-trace';

export function initTracing() {
  const enabled = process.env.DD_TRACE_ENABLED !== 'false';
  if (!enabled) return;

  ddTrace.init({
    service: process.env.DD_SERVICE || process.env.SERVICE_NAME || 'backend',
    env: process.env.DD_ENV || 'dev',
    version: process.env.DD_VERSION || '0.1.0',
    logInjection: process.env.DD_LOGS_INJECTION !== 'false',
    runtimeMetrics: true,
    // APM agent host/port picked up via DD_AGENT_HOST/DD_TRACE_AGENT_PORT
  });
}
