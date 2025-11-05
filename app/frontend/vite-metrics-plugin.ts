// Vite plugin to add metrics endpoint during development
import { Plugin } from 'vite';

export function metricsPlugin(): Plugin {
  return {
    name: 'metrics-plugin',
    configureServer(server) {
      server.middlewares.use('/metrics', (req, res) => {
        res.setHeader('Content-Type', 'text/plain');
        
        // Basic frontend metrics in Prometheus format
        const metrics = [
          '# HELP frontend_requests_total Total number of HTTP requests',
          '# TYPE frontend_requests_total counter',
          'frontend_requests_total{method="GET",route="/",status="200"} 1',
          '',
          '# HELP frontend_page_loads_total Total number of page loads',
          '# TYPE frontend_page_loads_total counter',
          'frontend_page_loads_total 1',
          '',
          '# HELP frontend_web_vitals_fcp First Contentful Paint',
          '# TYPE frontend_web_vitals_fcp gauge',
          'frontend_web_vitals_fcp 1200',
          '',
          '# HELP frontend_web_vitals_lcp Largest Contentful Paint',
          '# TYPE frontend_web_vitals_lcp gauge',
          'frontend_web_vitals_lcp 2500',
          '',
          '# HELP frontend_web_vitals_cls Cumulative Layout Shift',
          '# TYPE frontend_web_vitals_cls gauge',
          'frontend_web_vitals_cls 0.1',
          ''
        ].join('\n');
        
        res.end(metrics);
      });
    }
  };
}