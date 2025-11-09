/**
 * Instrumentação Completa de Observabilidade
 * Backend Node.js - Métricas, Logs e Traces
 */

const express = require('express');
const pino = require('pino');
const pinoHttp = require('pino-http');
const client = require('prom-client');
const StatsD = require('hot-shots');
const opentelemetry = require('@opentelemetry/api');
const { NodeSDK } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

// =====================================================
// 1. CONFIGURAÇÃO DE LOGS (Structured Logging)
// =====================================================
const logger = pino({
  name: 'case-backend',
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
    log: (object) => ({
      ...object,
      service: 'backend',
      environment: process.env.NODE_ENV || 'development',
      version: process.env.APP_VERSION || '1.0.0'
    })
  }
});

// =====================================================
// 2. CONFIGURAÇÃO DE MÉTRICAS PROMETHEUS
// =====================================================

// Registry para métricas Prometheus
const register = new client.Registry();

// Métricas padrão do Node.js
client.collectDefaultMetrics({ 
  register,
  prefix: 'backend_',
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5]
});

// ===== GOLDEN SIGNALS METRICS =====

// 1. LATENCY - Histogram de duração de requests
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 1, 2, 5, 10]
});

// 2. TRAFFIC - Counter de requests totais
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// 3. ERRORS - Counter de erros
const httpErrorsTotal = new client.Counter({
  name: 'http_errors_total',
  help: 'Total number of HTTP errors (4xx and 5xx)',
  labelNames: ['method', 'route', 'status_code']
});

// 4. SATURATION - Gauges de recursos
const activeConnections = new client.Gauge({
  name: 'http_active_connections',
  help: 'Number of active HTTP connections'
});

const heapUsed = new client.Gauge({
  name: 'backend_nodejs_heap_used_bytes', 
  help: 'Node.js heap used in bytes'
});

// ===== BUSINESS METRICS =====
const ordersCreatedTotal = new client.Counter({
  name: 'orders_created_total',
  help: 'Total number of orders successfully created',
  labelNames: ['payment_method', 'customer_type']
});

const ordersFailedTotal = new client.Counter({
  name: 'orders_failed_total',
  help: 'Total number of failed order attempts',
  labelNames: ['failure_reason', 'payment_method']
});

const orderValueHistogram = new client.Histogram({
  name: 'order_value_dollars',
  help: 'Distribution of order values in USD',
  labelNames: ['customer_type'],
  buckets: [10, 25, 50, 100, 250, 500, 1000, 2500]
});

const userSignupsTotal = new client.Counter({
  name: 'user_signups_total', 
  help: 'Total number of user sign-ups',
  labelNames: ['signup_method', 'user_type']
});

// Registrar métricas
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(httpErrorsTotal);
register.registerMetric(activeConnections);
register.registerMetric(heapUsed);
register.registerMetric(ordersCreatedTotal);
register.registerMetric(ordersFailedTotal);
register.registerMetric(orderValueHistogram);
register.registerMetric(userSignupsTotal);

// =====================================================
// 3. CONFIGURAÇÃO DATADOG STATSD
// =====================================================
const dogstatsd = new StatsD({
  host: process.env.DATADOG_HOST || 'localhost',
  port: process.env.DATADOG_PORT || 8125,
  prefix: 'case.backend.',
  tags: {
    service: 'backend',
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0'
  }
});

// =====================================================
// 4. CONFIGURAÇÃO OPENTELEMETRY (TRACES)
// =====================================================
const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'case-backend',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.APP_VERSION || '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development'
  }),
  traceExporter: {
    url: process.env.TEMPO_ENDPOINT || 'http://tempo:4318/v1/traces'
  }
});

// Inicializar OpenTelemetry
sdk.start();

// =====================================================
// 5. EXPRESS APP COM INSTRUMENTAÇÃO COMPLETA
// =====================================================
const app = express();

// Middleware de logs estruturados
app.use(pinoHttp({ logger }));

// Middleware de métricas customizado
app.use((req, res, next) => {
  const start = Date.now();
  
  // Incrementar conexões ativas
  activeConnections.inc();
  
  // Capturar fim da resposta
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path || 'unknown';
    
    // Métricas Prometheus
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString())
      .observe(duration);
      
    httpRequestsTotal
      .labels(req.method, route, res.statusCode.toString())
      .inc();
    
    // Contar erros (4xx e 5xx)
    if (res.statusCode >= 400) {
      httpErrorsTotal
        .labels(req.method, route, res.statusCode.toString())
        .inc();
    }
    
    // Métricas Datadog
    dogstatsd.timing('http.request.duration', duration * 1000, {
      method: req.method,
      route: route,
      status_code: res.statusCode.toString()
    });
    
    dogstatsd.increment('http.requests', 1, {
      method: req.method,
      route: route, 
      status_code: res.statusCode.toString()
    });
    
    // Logs estruturados
    req.log.info({
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: duration,
      userAgent: req.get('User-Agent')
    }, 'HTTP Request completed');
    
    // Decrementar conexões ativas
    activeConnections.dec();
  });
  
  next();
});

// =====================================================
// 6. ENDPOINTS DA API COM BUSINESS METRICS
// =====================================================

app.use(express.json());

// Health Check
app.get('/healthz', (req, res) => {
  const memUsage = process.memoryUsage();
  heapUsed.set(memUsage.heapUsed);
  
  res.json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: memUsage
  });
});

// Orders API com métricas de negócio
app.get('/api/orders', (req, res) => {
  // Simular busca de orders
  const orders = Array.from({ length: 5 }, (_, i) => ({
    id: i + 1,
    item: `Product ${i + 1}`,
    price: Math.random() * 100,
    status: 'completed'
  }));
  
  req.log.info({ orderCount: orders.length }, 'Orders retrieved');
  res.json(orders);
});

app.post('/api/orders', (req, res) => {
  const { item, price, customer, paymentMethod = 'credit_card' } = req.body;
  
  try {
    // Simular validação e processamento
    if (!item || !price || price < 0) {
      // Métrica de falha
      ordersFailedTotal
        .labels('validation_error', paymentMethod)
        .inc();
        
      dogstatsd.increment('orders.failed', 1, {
        failure_reason: 'validation_error',
        payment_method: paymentMethod
      });
      
      req.log.warn({ item, price }, 'Order validation failed');
      return res.status(400).json({ error: 'Invalid order data' });
    }
    
    // Simular falha ocasional (10%)
    if (Math.random() < 0.1) {
      ordersFailedTotal
        .labels('payment_error', paymentMethod)
        .inc();
        
      dogstatsd.increment('orders.failed', 1, {
        failure_reason: 'payment_error',
        payment_method: paymentMethod
      });
      
      req.log.error({ item, price, paymentMethod }, 'Payment processing failed');
      return res.status(500).json({ error: 'Payment processing failed' });
    }
    
    // Sucesso
    const customerType = customer?.includes('premium') ? 'premium' : 'standard';
    
    ordersCreatedTotal
      .labels(paymentMethod, customerType)
      .inc();
      
    orderValueHistogram
      .labels(customerType)
      .observe(parseFloat(price));
    
    // Datadog business metrics
    dogstatsd.increment('orders.created', 1, {
      payment_method: paymentMethod,
      customer_type: customerType
    });
    
    dogstatsd.histogram('orders.value', parseFloat(price), {
      customer_type: customerType
    });
    
    const order = {
      id: Date.now(),
      item,
      price: parseFloat(price),
      customer,
      paymentMethod,
      status: 'created',
      timestamp: new Date().toISOString()
    };
    
    req.log.info({ 
      orderId: order.id, 
      value: price, 
      customerType,
      paymentMethod 
    }, 'Order created successfully');
    
    res.status(201).json(order);
    
  } catch (error) {
    ordersFailedTotal
      .labels('system_error', paymentMethod)
      .inc();
      
    req.log.error({ error: error.message }, 'System error processing order');
    res.status(500).json({ error: 'Internal server error' });
  }
});

// User signup endpoint
app.post('/api/users/signup', (req, res) => {
  const { email, signupMethod = 'direct' } = req.body;
  
  if (!email) {
    return res.status(400).json({ error: 'Email required' });
  }
  
  const userType = email.includes('@company.com') ? 'enterprise' : 'consumer';
  
  userSignupsTotal
    .labels(signupMethod, userType)
    .inc();
    
  dogstatsd.increment('users.signup', 1, {
    signup_method: signupMethod,
    user_type: userType
  });
  
  req.log.info({ email, signupMethod, userType }, 'User signed up');
  
  res.status(201).json({
    message: 'User created',
    userType,
    signupMethod
  });
});

// Endpoint de métricas Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// =====================================================
// 7. MONITORAMENTO DE RECURSOS CONTÍNUO
// =====================================================
setInterval(() => {
  const memUsage = process.memoryUsage();
  
  // Prometheus
  heapUsed.set(memUsage.heapUsed);
  
  // Datadog
  dogstatsd.gauge('system.memory.heap_used', memUsage.heapUsed);
  dogstatsd.gauge('system.memory.heap_total', memUsage.heapTotal);
  dogstatsd.gauge('system.memory.external', memUsage.external);
  
}, 10000); // A cada 10 segundos

// =====================================================
// 8. GRACEFUL SHUTDOWN
// =====================================================
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  
  dogstatsd.close(() => {
    logger.info('StatsD client closed');
  });
  
  sdk.shutdown();
  process.exit(0);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info({ port: PORT }, 'Server started with full observability');
});

module.exports = app;