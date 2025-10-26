const express = require('express');
const promClient = require('prom-client');
const StatsD = require('hot-shots');
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/semantic-conventions');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');

// =====================================================
// CONFIGURAÇÃO PROMETHEUS METRICS
// =====================================================
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// 4 Golden Signals Metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds (Latency)',
  labelNames: ['method', 'route', 'status_code', 'service'],
  buckets: [0.1, 0.5, 1, 2, 5, 10],
  registers: [register]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests (Traffic)',
  labelNames: ['method', 'route', 'status_code', 'service'],
  registers: [register]
});

const httpRequestsErrorRate = new promClient.Gauge({
  name: 'http_requests_error_rate',
  help: 'HTTP error rate percentage (Errors)',
  labelNames: ['service'],
  registers: [register]
});

const systemResourceUsage = new promClient.Gauge({
  name: 'system_resource_usage_percent',
  help: 'System resource usage percentage (Saturation)',
  labelNames: ['resource', 'service'],
  registers: [register]
});

// Business Metrics
const ordersTotal = new promClient.Counter({
  name: 'orders_total',
  help: 'Total number of orders processed',
  labelNames: ['status', 'product_type', 'service'],
  registers: [register]
});

const revenueTotal = new promClient.Counter({
  name: 'revenue_total',
  help: 'Total revenue generated',
  labelNames: ['currency', 'product_type', 'service'],
  registers: [register]
});

const activeUsers = new promClient.Gauge({
  name: 'active_users_current',
  help: 'Current number of active users',
  labelNames: ['service'],
  registers: [register]
});

const signupsTotal = new promClient.Counter({
  name: 'user_signups_total',
  help: 'Total number of user signups',
  labelNames: ['signup_method', 'service'],
  registers: [register]
});

const cartConversions = new promClient.Counter({
  name: 'cart_conversions_total',
  help: 'Shopping cart conversions to orders',
  labelNames: ['conversion_type', 'service'],
  registers: [register]
});

// =====================================================
// CONFIGURAÇÃO DATADOG (Opcional)
// =====================================================
let dogstatsd;
if (process.env.DATADOG_API_KEY) {
  dogstatsd = new StatsD({
    host: process.env.DD_AGENT_HOST || 'localhost',
    port: process.env.DD_DOGSTATSD_PORT || 8125,
    globalTags: ['service:backend', 'environment:local']
  });
}

// =====================================================
// EXPRESS APP SETUP
// =====================================================
const app = express();
app.use(express.json());

// Middleware para capturar métricas
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode.toString(),
      service: 'backend'
    };
    
    // Golden Signals
    httpRequestDuration.observe(labels, duration);
    httpRequestsTotal.inc(labels);
    
    // Datadog (se disponível)
    if (dogstatsd) {
      dogstatsd.histogram('http.request.duration', duration * 1000, labels);
      dogstatsd.increment('http.requests.total', 1, labels);
    }
  });
  
  next();
});

// =====================================================
// SIMULAÇÃO DE DADOS REALISTAS
// =====================================================
let currentUsers = 0;
let totalOrders = 0;
let totalRevenue = 0;
let totalSignups = 0;

// Simular flutuações realistas de usuários
setInterval(() => {
  const hour = new Date().getHours();
  const baseUsers = hour >= 9 && hour <= 18 ? 150 : 50; // Horário comercial
  const variation = Math.random() * 50 - 25; // ±25 users
  currentUsers = Math.max(0, Math.floor(baseUsers + variation));
  
  activeUsers.set({ service: 'backend' }, currentUsers);
  
  if (dogstatsd) {
    dogstatsd.gauge('users.active', currentUsers, ['service:backend']);
  }
}, 30000); // A cada 30 segundos

// Simular recursos do sistema
setInterval(() => {
  const cpuUsage = 20 + Math.random() * 60; // 20-80%
  const memoryUsage = 30 + Math.random() * 50; // 30-80%
  const diskUsage = 40 + Math.random() * 30; // 40-70%
  
  systemResourceUsage.set({ resource: 'cpu', service: 'backend' }, cpuUsage);
  systemResourceUsage.set({ resource: 'memory', service: 'backend' }, memoryUsage);
  systemResourceUsage.set({ resource: 'disk', service: 'backend' }, diskUsage);
  
  if (dogstatsd) {
    dogstatsd.gauge('system.cpu.usage', cpuUsage, ['service:backend']);
    dogstatsd.gauge('system.memory.usage', memoryUsage, ['service:backend']);
    dogstatsd.gauge('system.disk.usage', diskUsage, ['service:backend']);
  }
}, 15000); // A cada 15 segundos

// Calcular error rate
setInterval(() => {
  const totalRequests = httpRequestsTotal._hashMap;
  let successCount = 0;
  let errorCount = 0;
  
  Object.values(totalRequests).forEach(metric => {
    const statusCode = parseInt(metric.labels.status_code);
    if (statusCode >= 200 && statusCode < 400) {
      successCount += metric.value;
    } else {
      errorCount += metric.value;
    }
  });
  
  const errorRate = totalRequests.size > 0 ? (errorCount / (successCount + errorCount)) * 100 : 0;
  httpRequestsErrorRate.set({ service: 'backend' }, errorRate);
}, 60000); // A cada minuto

// =====================================================
// ENDPOINTS DA API
// =====================================================

// Health Check
app.get('/healthz', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    service: 'backend'
  });
});

// Métricas Prometheus
app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});

// Listar pedidos (com simulação de dados)
app.get('/api/orders', (req, res) => {
  // Simular latência variável
  const latency = Math.random() * 1000 + 100; // 100-1100ms
  
  setTimeout(() => {
    const orders = [];
    const orderCount = Math.floor(Math.random() * 10) + 1;
    
    for (let i = 0; i < orderCount; i++) {
      const order = {
        id: `order_${Date.now()}_${i}`,
        user_id: `user_${Math.floor(Math.random() * 1000)}`,
        product_type: Math.random() > 0.5 ? 'premium' : 'basic',
        amount: Math.floor(Math.random() * 500) + 50,
        currency: 'USD',
        status: Math.random() > 0.1 ? 'completed' : 'failed',
        created_at: new Date().toISOString()
      };
      
      orders.push(order);
      
      // Registrar métricas de negócio
      ordersTotal.inc({
        status: order.status,
        product_type: order.product_type,
        service: 'backend'
      });
      
      if (order.status === 'completed') {
        revenueTotal.inc({
          currency: order.currency,
          product_type: order.product_type,
          service: 'backend'
        }, order.amount);
        
        totalRevenue += order.amount;
      }
      
      totalOrders++;
      
      // Datadog business metrics
      if (dogstatsd) {
        dogstatsd.increment('orders.total', 1, [
          `status:${order.status}`,
          `product_type:${order.product_type}`,
          'service:backend'
        ]);
        
        if (order.status === 'completed') {
          dogstatsd.increment('revenue.total', order.amount, [
            `currency:${order.currency}`,
            `product_type:${order.product_type}`,
            'service:backend'
          ]);
        }
      }
    }
    
    res.json({
      orders,
      pagination: {
        total: totalOrders,
        count: orders.length,
        revenue_total: totalRevenue
      }
    });
  }, latency);
});

// Criar novo pedido
app.post('/api/orders', (req, res) => {
  const latency = Math.random() * 800 + 200; // 200-1000ms
  
  setTimeout(() => {
    // Simular falhas ocasionais (10%)
    if (Math.random() < 0.1) {
      return res.status(500).json({ error: 'Internal server error' });
    }
    
    const order = {
      id: `order_${Date.now()}`,
      user_id: req.body.user_id || `user_${Math.floor(Math.random() * 1000)}`,
      product_type: req.body.product_type || 'basic',
      amount: req.body.amount || Math.floor(Math.random() * 200) + 50,
      currency: 'USD',
      status: 'completed',
      created_at: new Date().toISOString()
    };
    
    // Conversão do carrinho
    cartConversions.inc({
      conversion_type: 'checkout_completed',
      service: 'backend'
    });
    
    ordersTotal.inc({
      status: order.status,
      product_type: order.product_type,
      service: 'backend'
    });
    
    revenueTotal.inc({
      currency: order.currency,
      product_type: order.product_type,
      service: 'backend'
    }, order.amount);
    
    if (dogstatsd) {
      dogstatsd.increment('cart.conversions', 1, ['type:checkout_completed', 'service:backend']);
      dogstatsd.increment('orders.created', 1, [`product_type:${order.product_type}`]);
    }
    
    res.status(201).json(order);
  }, latency);
});

// Cadastro de usuários
app.post('/api/users/signup', (req, res) => {
  const latency = Math.random() * 600 + 100; // 100-700ms
  
  setTimeout(() => {
    // Simular falhas de validação (5%)
    if (Math.random() < 0.05) {
      return res.status(400).json({ error: 'Invalid email format' });
    }
    
    const signupMethod = req.body.signup_method || 'email';
    
    signupsTotal.inc({
      signup_method: signupMethod,
      service: 'backend'
    });
    
    totalSignups++;
    
    if (dogstatsd) {
      dogstatsd.increment('users.signups', 1, [`method:${signupMethod}`, 'service:backend']);
    }
    
    res.status(201).json({
      id: `user_${Date.now()}`,
      email: req.body.email || `user${totalSignups}@example.com`,
      signup_method: signupMethod,
      created_at: new Date().toISOString()
    });
  }, latency);
});

// Endpoint que simula erro (para testar alertas)
app.get('/api/error-test', (req, res) => {
  // 50% de chance de erro
  if (Math.random() < 0.5) {
    return res.status(500).json({ error: 'Simulated error for testing' });
  }
  
  res.json({ message: 'Success response' });
});

// Endpoint com latência alta (para testar alertas)
app.get('/api/slow-endpoint', (req, res) => {
  const latency = Math.random() * 5000 + 2000; // 2-7 segundos
  
  setTimeout(() => {
    res.json({ 
      message: 'Slow response',
      latency_ms: latency,
      timestamp: new Date().toISOString()
    });
  }, latency);
});

// Stats endpoint para dashboard
app.get('/api/stats', (req, res) => {
  res.json({
    active_users: currentUsers,
    total_orders: totalOrders,
    total_revenue: totalRevenue,
    total_signups: totalSignups,
    timestamp: new Date().toISOString(),
    service: 'backend'
  });
});

// =====================================================
// ENDPOINTS PARA COLETA DE MÉTRICAS FRONTEND/MOBILE
// =====================================================

// Armazenar métricas frontend/mobile em memória (em produção usar Redis/DB)
let frontendMetrics = [];
let mobileMetrics = [];

// Endpoint para receber métricas do frontend
app.post('/api/metrics/frontend', (req, res) => {
  const metric = {
    ...req.body,
    received_at: new Date().toISOString(),
    service: 'frontend'
  };
  
  frontendMetrics.push(metric);
  
  // Manter apenas últimos 1000 registros em memória
  if (frontendMetrics.length > 1000) {
    frontendMetrics = frontendMetrics.slice(-1000);
  }
  
  // Converter para métricas Prometheus
  convertFrontendMetricToPrometheus(metric);
  
  // Enviar para Datadog se disponível
  if (dogstatsd) {
    sendFrontendMetricToDatadog(metric);
  }
  
  res.status(200).json({ status: 'received' });
});

// Endpoint para receber métricas do mobile
app.post('/api/metrics/mobile', (req, res) => {
  const metric = {
    ...req.body,
    received_at: new Date().toISOString(),
    service: 'mobile'
  };
  
  mobileMetrics.push(metric);
  
  // Manter apenas últimos 1000 registros em memória
  if (mobileMetrics.length > 1000) {
    mobileMetrics = mobileMetrics.slice(-1000);
  }
  
  // Converter para métricas Prometheus
  convertMobileMetricToPrometheus(metric);
  
  // Enviar para Datadog se disponível
  if (dogstatsd) {
    sendMobileMetricToDatadog(metric);
  }
  
  res.status(200).json({ status: 'received' });
});

// Endpoint para recuperar métricas frontend
app.get('/api/metrics/frontend/recent', (req, res) => {
  const limit = parseInt(req.query.limit) || 100;
  const recentMetrics = frontendMetrics.slice(-limit);
  
  res.json({
    metrics: recentMetrics,
    total_count: frontendMetrics.length,
    service: 'frontend'
  });
});

// Endpoint para recuperar métricas mobile
app.get('/api/metrics/mobile/recent', (req, res) => {
  const limit = parseInt(req.query.limit) || 100;
  const recentMetrics = mobileMetrics.slice(-limit);
  
  res.json({
    metrics: recentMetrics,
    total_count: mobileMetrics.length,
    service: 'mobile'
  });
});

// =====================================================
// CONVERSÃO PARA PROMETHEUS
// =====================================================

// Métricas Prometheus para Frontend
const frontendPageLoadTime = new promClient.Histogram({
  name: 'frontend_page_load_duration_seconds',
  help: 'Frontend page load time in seconds',
  labelNames: ['page_url', 'service'],
  buckets: [0.1, 0.5, 1, 2, 5, 10],
  registers: [register]
});

const frontendWebVitals = new promClient.Gauge({
  name: 'frontend_web_vitals',
  help: 'Core Web Vitals metrics',
  labelNames: ['metric_type', 'service'],
  registers: [register]
});

const frontendErrorsTotal = new promClient.Counter({
  name: 'frontend_errors_total',
  help: 'Total frontend errors',
  labelNames: ['error_type', 'service'],
  registers: [register]
});

const frontendBusinessEvents = new promClient.Counter({
  name: 'frontend_business_events_total',
  help: 'Frontend business events',
  labelNames: ['event_type', 'service'],
  registers: [register]
});

// Métricas Prometheus para Mobile
const mobileScreenLoadTime = new promClient.Histogram({
  name: 'mobile_screen_load_duration_seconds',
  help: 'Mobile screen load time in seconds',
  labelNames: ['screen_name', 'platform', 'service'],
  buckets: [0.1, 0.5, 1, 2, 5, 10],
  registers: [register]
});

const mobileAppLaunchTime = new promClient.Histogram({
  name: 'mobile_app_launch_duration_seconds',
  help: 'Mobile app launch time in seconds',
  labelNames: ['platform', 'is_cold_start', 'service'],
  buckets: [0.5, 1, 2, 5, 10, 20],
  registers: [register]
});

const mobileCrashesTotal = new promClient.Counter({
  name: 'mobile_crashes_total',
  help: 'Total mobile app crashes',
  labelNames: ['platform', 'error_type', 'service'],
  registers: [register]
});

const mobileBusinessEvents = new promClient.Counter({
  name: 'mobile_business_events_total',
  help: 'Mobile business events',
  labelNames: ['event_type', 'platform', 'service'],
  registers: [register]
});

function convertFrontendMetricToPrometheus(metric) {
  const labels = { service: 'frontend' };
  
  switch (metric.name) {
    case 'frontend_page_load_time':
      if (metric.value) {
        frontendPageLoadTime.observe(
          { ...labels, page_url: metric.page_url || 'unknown' },
          metric.value / 1000 // Convert ms to seconds
        );
      }
      break;
      
    case 'frontend_cls':
    case 'frontend_fid':
    case 'frontend_fcp':
    case 'frontend_lcp':
    case 'frontend_ttfb':
      if (metric.value !== undefined) {
        frontendWebVitals.set(
          { ...labels, metric_type: metric.name.replace('frontend_', '') },
          metric.value
        );
      }
      break;
      
    case 'frontend_js_error':
    case 'frontend_promise_rejection':
    case 'frontend_resource_error':
      frontendErrorsTotal.inc({
        ...labels,
        error_type: metric.name.replace('frontend_', '')
      });
      break;
      
    case 'frontend_product_view':
    case 'frontend_cart_addition':
    case 'frontend_purchase_completion':
    case 'frontend_checkout_start':
      frontendBusinessEvents.inc({
        ...labels,
        event_type: metric.name.replace('frontend_', '')
      });
      break;
  }
}

function convertMobileMetricToPrometheus(metric) {
  const labels = { 
    service: 'mobile',
    platform: metric.platform || 'unknown'
  };
  
  switch (metric.name) {
    case 'mobile_screen_navigation':
      if (metric.navigation_time_ms) {
        mobileScreenLoadTime.observe(
          { ...labels, screen_name: metric.to_screen || 'unknown' },
          metric.navigation_time_ms / 1000
        );
      }
      break;
      
    case 'mobile_app_launch':
      if (metric.launch_time_ms) {
        mobileAppLaunchTime.observe(
          { 
            ...labels, 
            is_cold_start: metric.is_cold_start ? 'true' : 'false'
          },
          metric.launch_time_ms / 1000
        );
      }
      break;
      
    case 'mobile_js_error':
    case 'mobile_promise_rejection':
      mobileCrashesTotal.inc({
        ...labels,
        error_type: metric.is_fatal ? 'crash' : 'error'
      });
      break;
      
    case 'mobile_product_view':
    case 'mobile_purchase':
    case 'mobile_button_tap':
      mobileBusinessEvents.inc({
        ...labels,
        event_type: metric.name.replace('mobile_', '')
      });
      break;
  }
}

// =====================================================
// ENVIO PARA DATADOG
// =====================================================

function sendFrontendMetricToDatadog(metric) {
  if (!dogstatsd) return;
  
  const tags = [
    'service:frontend',
    `page:${metric.page_url || 'unknown'}`,
    `session:${metric.session_id || 'unknown'}`
  ];
  
  switch (metric.name) {
    case 'frontend_page_load_time':
      if (metric.value) {
        dogstatsd.histogram('frontend.page.load_time', metric.value, tags);
      }
      break;
      
    case 'frontend_cls':
    case 'frontend_fid':
    case 'frontend_fcp':
    case 'frontend_lcp':
    case 'frontend_ttfb':
      if (metric.value !== undefined) {
        dogstatsd.gauge(`frontend.web_vitals.${metric.name.replace('frontend_', '')}`, metric.value, tags);
      }
      break;
      
    case 'frontend_js_error':
    case 'frontend_promise_rejection':
      dogstatsd.increment('frontend.errors', 1, [...tags, `error_type:${metric.name.replace('frontend_', '')}`]);
      break;
      
    case 'frontend_product_view':
    case 'frontend_purchase_completion':
      dogstatsd.increment(`frontend.business.${metric.name.replace('frontend_', '')}`, 1, tags);
      if (metric.price || metric.order_value) {
        dogstatsd.histogram('frontend.business.value', metric.price || metric.order_value, tags);
      }
      break;
  }
}

function sendMobileMetricToDatadog(metric) {
  if (!dogstatsd) return;
  
  const tags = [
    'service:mobile',
    `platform:${metric.platform || 'unknown'}`,
    `session:${metric.session_id || 'unknown'}`
  ];
  
  switch (metric.name) {
    case 'mobile_app_launch':
      if (metric.launch_time_ms) {
        dogstatsd.histogram('mobile.app.launch_time', metric.launch_time_ms, [
          ...tags,
          `cold_start:${metric.is_cold_start || false}`
        ]);
      }
      break;
      
    case 'mobile_screen_navigation':
      if (metric.navigation_time_ms) {
        dogstatsd.histogram('mobile.screen.navigation_time', metric.navigation_time_ms, [
          ...tags,
          `screen:${metric.to_screen || 'unknown'}`
        ]);
      }
      break;
      
    case 'mobile_js_error':
      dogstatsd.increment('mobile.crashes', 1, [
        ...tags,
        `fatal:${metric.is_fatal || false}`,
        `error_type:js_error`
      ]);
      break;
      
    case 'mobile_purchase':
      dogstatsd.increment('mobile.business.purchase', 1, tags);
      if (metric.order_value) {
        dogstatsd.histogram('mobile.business.revenue', metric.order_value, tags);
      }
      break;
      
    case 'mobile_performance_summary':
      if (metric.error_rate_percent !== undefined) {
        dogstatsd.gauge('mobile.performance.error_rate', metric.error_rate_percent, tags);
      }
      if (metric.session_duration_ms) {
        dogstatsd.gauge('mobile.performance.session_duration', metric.session_duration_ms, tags);
      }
      break;
  }
}

// =====================================================
// START SERVER
// =====================================================
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Backend server running on port ${PORT}`);
  console.log(`📊 Metrics available at http://localhost:${PORT}/metrics`);
  console.log(`❤️  Health check at http://localhost:${PORT}/healthz`);
  console.log(`📈 Stats endpoint at http://localhost:${PORT}/api/stats`);
  
  // Simular alguns dados iniciais
  currentUsers = 75;
  activeUsers.set({ service: 'backend' }, currentUsers);
  
  console.log('🎯 Generating initial test data...');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

module.exports = app;