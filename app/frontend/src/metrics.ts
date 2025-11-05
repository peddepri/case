// Basic metrics collection for Frontend
import { onCLS, onFCP, onFID, onLCP, onTTFB } from 'web-vitals';

class MetricsCollector {
  private metrics: Map<string, number> = new Map();
  private counters: Map<string, number> = new Map();

  constructor() {
    this.initWebVitals();
    this.initPageMetrics();
  }

  private initWebVitals() {
    onCLS((metric: any) => this.metrics.set('frontend_web_vitals_cls', metric.value));
    onFCP((metric: any) => this.metrics.set('frontend_web_vitals_fcp', metric.value));
    onFID((metric: any) => this.metrics.set('frontend_web_vitals_fid', metric.value));
    onLCP((metric: any) => this.metrics.set('frontend_web_vitals_lcp', metric.value));
    onTTFB((metric: any) => this.metrics.set('frontend_web_vitals_ttfb', metric.value));
  }

  private initPageMetrics() {
    // Track page loads
    this.incrementCounter('frontend_page_loads_total');
    
    // Track navigation timing
    if (performance && performance.timing) {
      const timing = performance.timing;
      const loadTime = timing.loadEventEnd - timing.navigationStart;
      this.metrics.set('frontend_page_load_duration_ms', loadTime);
    }
  }

  incrementCounter(name: string, labels?: Record<string, string>) {
    const key = labels ? `${name}|${JSON.stringify(labels)}` : name;
    this.counters.set(key, (this.counters.get(key) || 0) + 1);
  }

  setMetric(name: string, value: number, labels?: Record<string, string>) {
    const key = labels ? `${name}|${JSON.stringify(labels)}` : name;
    this.metrics.set(key, value);
  }

  // Track HTTP requests
  trackRequest(url: string, method: string, status: number, duration: number) {
    const labels = { method, status: status.toString(), route: this.extractRoute(url) };
    this.incrementCounter('frontend_requests_total', labels);
    this.setMetric('frontend_request_duration_ms', duration, labels);
    
    if (status >= 400) {
      this.incrementCounter('frontend_errors_total', labels);
    }
  }

  private extractRoute(url: string): string {
    try {
      const urlObj = new URL(url);
      return urlObj.pathname;
    } catch {
      return '/unknown';
    }
  }

  // Export metrics in Prometheus format
  exportMetrics(): string {
    const lines: string[] = [];
    
    // Counters
    for (const [key, value] of this.counters.entries()) {
      const [name, labelsStr] = key.split('|');
      const labels = labelsStr ? JSON.parse(labelsStr) : {};
      const labelStr = Object.entries(labels).map(([k, v]) => `${k}="${v}"`).join(',');
      lines.push(`${name}${labelStr ? `{${labelStr}}` : ''} ${value}`);
    }
    
    // Metrics
    for (const [key, value] of this.metrics.entries()) {
      const [name, labelsStr] = key.split('|');
      const labels = labelsStr ? JSON.parse(labelsStr) : {};
      const labelStr = Object.entries(labels).map(([k, v]) => `${k}="${v}"`).join(',');
      lines.push(`${name}${labelStr ? `{${labelStr}}` : ''} ${value}`);
    }
    
    return lines.join('\n') + '\n';
  }
}

export const metricsCollector = new MetricsCollector();

// Monkey patch fetch to track HTTP requests
const originalFetch = window.fetch;
window.fetch = async (...args) => {
  const start = performance.now();
  const [url, options] = args;
  const method = options?.method || 'GET';
  
  try {
    const response = await originalFetch(...args);
    const duration = performance.now() - start;
    metricsCollector.trackRequest(url.toString(), method, response.status, duration);
    return response;
  } catch (error) {
    const duration = performance.now() - start;
    metricsCollector.trackRequest(url.toString(), method, 0, duration);
    throw error;
  }
};