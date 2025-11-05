// Simple metrics collection for Mobile app
class MobileMetrics {
  private metrics: Map<string, number> = new Map();
  private counters: Map<string, number> = new Map();

  constructor() {
    this.initializeMetrics();
    this.startMetricsServer();
  }

  private initializeMetrics() {
    // Initialize basic counters
    this.counters.set('mobile_app_starts_total', 1);
    this.counters.set('mobile_requests_total', 0);
    this.counters.set('mobile_errors_total', 0);
    
    // Initialize gauges
    this.metrics.set('mobile_load_time_ms', Date.now() % 10000); // Simulated
  }

  incrementCounter(name: string, labels?: Record<string, string>) {
    const key = labels ? `${name}|${JSON.stringify(labels)}` : name;
    this.counters.set(key, (this.counters.get(key) || 0) + 1);
  }

  setMetric(name: string, value: number, labels?: Record<string, string>) {
    const key = labels ? `${name}|${JSON.stringify(labels)}` : name;
    this.metrics.set(key, value);
  }

  trackRequest(url: string, method: string, status: number, duration: number) {
    const labels = { method, status: status.toString() };
    this.incrementCounter('mobile_requests_total', labels);
    this.setMetric('mobile_request_duration_ms', duration, labels);
    
    if (status >= 400 || status === 0) {
      this.incrementCounter('mobile_errors_total', labels);
    }
  }

  private startMetricsServer() {
    if (typeof window !== 'undefined') {
      // For web version, we can add a simple metrics endpoint
      (window as any).getMobileMetrics = () => this.exportMetrics();
    }
  }

  exportMetrics(): string {
    const lines: string[] = [
      '# HELP mobile_app_starts_total Total number of app starts',
      '# TYPE mobile_app_starts_total counter'
    ];
    
    // Add counters
    for (const [key, value] of this.counters.entries()) {
      const [name, labelsStr] = key.split('|');
      const labels = labelsStr ? JSON.parse(labelsStr) : {};
      const labelStr = Object.entries(labels).map(([k, v]) => `${k}="${v}"`).join(',');
      lines.push(`${name}${labelStr ? `{${labelStr}}` : ''} ${value}`);
    }
    
    // Add metrics
    for (const [key, value] of this.metrics.entries()) {
      const [name, labelsStr] = key.split('|');
      const labels = labelsStr ? JSON.parse(labelsStr) : {};
      const labelStr = Object.entries(labels).map(([k, v]) => `${k}="${v}"`).join(',');
      lines.push(`${name}${labelStr ? `{${labelStr}}` : ''} ${value}`);
    }
    
    return lines.join('\n') + '\n';
  }
}

export const mobileMetrics = new MobileMetrics();