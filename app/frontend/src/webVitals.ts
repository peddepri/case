import { onCLS, onFCP, onFID, onLCP, onTTFB, Metric } from 'web-vitals';

// Custom metrics collector for Web Vitals
// These will be exposed as custom metrics that can be scraped by Prometheus
// or sent to a metrics endpoint

interface WebVitalsMetrics {
  FCP?: number;
  LCP?: number;
  FID?: number;
  CLS?: number;
  TTFB?: number;
}

const metrics: WebVitalsMetrics = {};

function sendMetric(metric: Metric) {
  // Store metric value
  metrics[metric.name as keyof WebVitalsMetrics] = metric.value;

  // Log to console for debugging
  console.log(`[Web Vitals] ${metric.name}:`, {
    value: metric.value,
    rating: metric.rating,
    delta: metric.delta,
  });

  // In a production environment, you would send this to your metrics backend
  // For now, we'll expose these via a global object that can be scraped
  if (typeof window !== 'undefined') {
    (window as any).__WEB_VITALS__ = metrics;
  }

  // Optionally send to backend metrics endpoint
  sendToBackend(metric);
}

function sendToBackend(metric: Metric) {
  const backendUrl = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000';
  
  // Send metric to backend (non-blocking, fire-and-forget)
  if (navigator.sendBeacon) {
    const body = JSON.stringify({
      name: metric.name,
      value: metric.value,
      rating: metric.rating,
      delta: metric.delta,
      id: metric.id,
      timestamp: Date.now(),
    });
    
    navigator.sendBeacon(`${backendUrl}/api/metrics/web-vitals`, body);
  } else {
    // Fallback for browsers that don't support sendBeacon
    fetch(`${backendUrl}/api/metrics/web-vitals`, {
      method: 'POST',
      body: JSON.stringify({
        name: metric.name,
        value: metric.value,
        rating: metric.rating,
        delta: metric.delta,
        id: metric.id,
        timestamp: Date.now(),
      }),
      headers: {
        'Content-Type': 'application/json',
      },
      keepalive: true,
    }).catch((err) => {
      console.warn('[Web Vitals] Failed to send metric to backend:', err);
    });
  }
}

export function initWebVitals() {
  // Register all Web Vitals metrics
  onCLS(sendMetric);
  onFCP(sendMetric);
  onFID(sendMetric);
  onLCP(sendMetric);
  onTTFB(sendMetric);

  console.log('[Web Vitals] Monitoring initialized');
}

// Export metrics for external access
export function getWebVitals(): WebVitalsMetrics {
  return { ...metrics };
}
