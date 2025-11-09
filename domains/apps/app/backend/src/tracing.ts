// Initialize OpenTelemetry and Datadog tracing
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import ddTrace from 'dd-trace';

let sdk: NodeSDK | null = null;

export function initTracing() {
  // Initialize Datadog tracer if enabled
  const ddEnabled = process.env.DD_TRACE_ENABLED !== 'false';
  if (ddEnabled) {
    ddTrace.init({
      service: process.env.DD_SERVICE || process.env.SERVICE_NAME || 'backend',
      env: process.env.DD_ENV || 'dev',
      version: process.env.DD_VERSION || '0.1.0',
      logInjection: process.env.DD_LOGS_INJECTION !== 'false',
      runtimeMetrics: true,
    });
    console.log('[Datadog] Tracer initialized');
  }

  // Initialize OpenTelemetry tracer
  const otelEnabled = process.env.OTEL_TRACE_ENABLED !== 'false';
  if (!otelEnabled) {
    console.log('[OpenTelemetry] Tracing disabled');
    return;
  }

  const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://tempo:4318/v1/traces';
  
  const resource = Resource.default().merge(
    new Resource({
      [SEMRESATTRS_SERVICE_NAME]: process.env.SERVICE_NAME || 'case-backend',
      [SEMRESATTRS_SERVICE_VERSION]: process.env.SERVICE_VERSION || '0.1.0',
      'deployment.environment': process.env.NODE_ENV || 'development',
    })
  );

  const traceExporter = new OTLPTraceExporter({
    url: otlpEndpoint,
    headers: {},
  });

  sdk = new NodeSDK({
    resource,
    traceExporter,
    instrumentations: [
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': {
          enabled: false, // Disable fs instrumentation to reduce noise
        },
        '@opentelemetry/instrumentation-http': {
          enabled: true,
          ignoreIncomingRequestHook: (req) => {
            // Don't trace health checks and metrics endpoints
            const url = req.url || '';
            return url.includes('/healthz') || url.includes('/metrics');
          },
        },
        '@opentelemetry/instrumentation-express': {
          enabled: true,
        },
        '@opentelemetry/instrumentation-aws-sdk': {
          enabled: true,
        },
      }),
    ],
  });

  sdk.start();
  console.log('[OpenTelemetry] Backend tracing initialized', {
    otlpEndpoint,
    serviceName: process.env.SERVICE_NAME || 'case-backend',
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    sdk?.shutdown()
      .then(() => console.log('[OpenTelemetry] SDK shut down successfully'))
      .catch((error) => console.error('[OpenTelemetry] Error shutting down SDK', error))
      .finally(() => process.exit(0));
  });
}
