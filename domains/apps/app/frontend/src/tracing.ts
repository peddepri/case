import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } from '@opentelemetry/semantic-conventions';
import { ZoneContextManager } from '@opentelemetry/context-zone';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { DocumentLoadInstrumentation } from '@opentelemetry/instrumentation-document-load';
import { UserInteractionInstrumentation } from '@opentelemetry/instrumentation-user-interaction';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request';

// Configure the OpenTelemetry tracer for the frontend
export function initTracing() {
  // Determine OTLP endpoint - in production this should be the Tempo collector endpoint
  const otlpEndpoint = import.meta.env.VITE_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces';

  // Create resource with service information
  const resource = Resource.default().merge(
    new Resource({
      [SEMRESATTRS_SERVICE_NAME]: 'case-frontend',
      [SEMRESATTRS_SERVICE_VERSION]: '0.1.0',
      'deployment.environment': import.meta.env.MODE || 'development',
    })
  );

  // Create tracer provider
  const provider = new WebTracerProvider({
    resource,
  });

  // Configure OTLP exporter
  const exporter = new OTLPTraceExporter({
    url: otlpEndpoint,
    headers: {},
  });

  // Use BatchSpanProcessor to batch spans before sending
  provider.addSpanProcessor(new BatchSpanProcessor(exporter, {
    maxQueueSize: 100,
    maxExportBatchSize: 10,
    scheduledDelayMillis: 5000,
  }));

  // Register the provider
  provider.register({
    contextManager: new ZoneContextManager(),
  });

  // Register instrumentations
  registerInstrumentations({
    instrumentations: [
      // Captures page load and navigation timings
      new DocumentLoadInstrumentation(),
      
      // Captures user interactions (clicks, etc.)
      new UserInteractionInstrumentation({
        eventNames: ['click', 'submit', 'keypress'],
      }),
      
      // Captures fetch API calls and propagates trace context
      new FetchInstrumentation({
        propagateTraceHeaderCorsUrls: [
          /localhost:3000/,
          /localhost:3002/,
          new RegExp(import.meta.env.VITE_BACKEND_URL || ''),
        ],
        clearTimingResources: true,
      }),
      
      // Captures XMLHttpRequest calls
      new XMLHttpRequestInstrumentation({
        propagateTraceHeaderCorsUrls: [
          /localhost:3000/,
          /localhost:3002/,
          new RegExp(import.meta.env.VITE_BACKEND_URL || ''),
        ],
      }),
    ],
  });

  console.log('[OpenTelemetry] Frontend tracing initialized', {
    otlpEndpoint,
    serviceName: 'case-frontend',
  });
}
