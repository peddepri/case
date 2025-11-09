// ==========================================
// OBSERVABILITY INSTRUMENTATION
// ==========================================
const express = require('express');
const cors = require('cors');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');

// Prometheus metrics
const client = require('prom-client');
const collectDefaultMetrics = client.collectDefaultMetrics;

// Create a Registry to register metrics
const register = new client.Registry();

// Add default metrics (process, nodejs)
collectDefaultMetrics({
    app: 'case-backend',
    prefix: 'case_backend_',
    timeout: 10000,
    gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
    register
});

// ==========================================
// GOLDEN SIGNALS METRICS
// ==========================================

// 1. LATENCY - Request duration histogram
const httpRequestDuration = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code', 'service'],
    buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
    registers: [register]
});

// 2. TRAFFIC - Request rate counter
const httpRequestsTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code', 'service'],
    registers: [register]
});

// 3. ERRORS - Error rate counter
const httpErrorsTotal = new client.Counter({
    name: 'http_errors_total',
    help: 'Total number of HTTP errors',
    labelNames: ['method', 'route', 'status_code', 'service', 'error_type'],
    registers: [register]
});

// 4. SATURATION - Resource usage gauges
const memoryUsage = new client.Gauge({
    name: 'memory_usage_bytes',
    help: 'Memory usage in bytes',
    labelNames: ['service', 'type'],
    registers: [register]
});

const cpuUsage = new client.Gauge({
    name: 'cpu_usage_percent',
    help: 'CPU usage percentage',
    labelNames: ['service'],
    registers: [register]
});

// ==========================================
// BUSINESS METRICS
// ==========================================

// Orders metrics
const ordersTotal = new client.Counter({
    name: 'orders_total',
    help: 'Total number of orders',
    labelNames: ['service', 'status'],
    registers: [register]
});

const orderValue = new client.Histogram({
    name: 'order_value_dollars',
    help: 'Order value in dollars',
    labelNames: ['service'],
    buckets: [10, 25, 50, 100, 250, 500, 1000, 2500],
    registers: [register]
});

// Revenue metrics
const revenueTotal = new client.Counter({
    name: 'revenue_total_dollars',
    help: 'Total revenue in dollars',
    labelNames: ['service'],
    registers: [register]
});

// User activity metrics
const userSignups = new client.Counter({
    name: 'user_signups_total',
    help: 'Total number of user signups',
    labelNames: ['service', 'source'],
    registers: [register]
});

const userSessions = new client.Gauge({
    name: 'active_sessions',
    help: 'Number of active user sessions',
    labelNames: ['service'],
    registers: [register]
});

// Performance metrics
const databaseLatency = new client.Histogram({
    name: 'database_query_duration_seconds',
    help: 'Database query duration in seconds',
    labelNames: ['service', 'operation', 'table'],
    buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1],
    registers: [register]
});

// ==========================================
// EXPRESS APP SETUP
// ==========================================
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// ==========================================
// INSTRUMENTATION MIDDLEWARE
// ==========================================
app.use((req, res, next) => {
    const start = Date.now();
    const route = req.route?.path || req.path || 'unknown';
    
    // Increment request counter
    httpRequestsTotal.inc({
        method: req.method,
        route: route,
        service: 'backend'
    });
    
    // Override res.end to capture metrics
    const originalEnd = res.end;
    res.end = function(...args) {
        const duration = (Date.now() - start) / 1000;
        
        // Record latency
        httpRequestDuration.observe({
            method: req.method,
            route: route,
            status_code: res.statusCode,
            service: 'backend'
        }, duration);
        
        // Count total requests with status
        httpRequestsTotal.inc({
            method: req.method,
            route: route,
            status_code: res.statusCode,
            service: 'backend'
        });
        
        // Count errors (4xx and 5xx)
        if (res.statusCode >= 400) {
            httpErrorsTotal.inc({
                method: req.method,
                route: route,
                status_code: res.statusCode,
                service: 'backend',
                error_type: res.statusCode >= 500 ? 'server_error' : 'client_error'
            });
        }
        
        return originalEnd.apply(this, args);
    };
    
    next();
});

// ==========================================
// DYNAMODB SETUP
// ==========================================
const dynamoClient = new DynamoDBClient({
    region: process.env.AWS_REGION || 'us-east-1',
    endpoint: process.env.DYNAMODB_ENDPOINT,
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
});

const docClient = DynamoDBDocumentClient.from(dynamoClient);

// ==========================================
// BUSINESS LOGIC WITH METRICS
// ==========================================

// Simulate active sessions (updates every 30 seconds)
setInterval(() => {
    const activeSessions = Math.floor(Math.random() * 500) + 100;
    userSessions.set({ service: 'backend' }, activeSessions);
}, 30000);

// Update resource metrics every 10 seconds
setInterval(() => {
    const memUsage = process.memoryUsage();
    memoryUsage.set({ service: 'backend', type: 'rss' }, memUsage.rss);
    memoryUsage.set({ service: 'backend', type: 'heapUsed' }, memUsage.heapUsed);
    memoryUsage.set({ service: 'backend', type: 'heapTotal' }, memUsage.heapTotal);
    
    // Simulate CPU usage
    const cpuPercent = Math.random() * 50 + 10; // 10-60%
    cpuUsage.set({ service: 'backend' }, cpuPercent);
}, 10000);

// ==========================================
// API ROUTES
// ==========================================

// Health check
app.get('/healthz', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'backend',
        version: process.env.DD_VERSION || '0.1.0'
    });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

// Get orders
app.get('/api/orders', async (req, res) => {
    const dbStart = Date.now();
    
    try {
        const command = new ScanCommand({
            TableName: process.env.DDB_TABLE || 'orders'
        });
        
        const response = await docClient.send(command);
        
        // Record database latency
        const dbDuration = (Date.now() - dbStart) / 1000;
        databaseLatency.observe({
            service: 'backend',
            operation: 'scan',
            table: 'orders'
        }, dbDuration);
        
        res.json({
            orders: response.Items || [],
            count: response.Count || 0
        });
        
    } catch (error) {
        console.error('Error fetching orders:', error);
        res.status(500).json({ error: 'Failed to fetch orders' });
    }
});

// Create order
app.post('/api/orders', async (req, res) => {
    const dbStart = Date.now();
    
    try {
        const { customerName, items, total } = req.body;
        
        if (!customerName || !items || !total) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        
        const order = {
            id: `order_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            customerName,
            items,
            total: parseFloat(total),
            status: 'pending',
            createdAt: new Date().toISOString()
        };
        
        const command = new PutCommand({
            TableName: process.env.DDB_TABLE || 'orders',
            Item: order
        });
        
        await docClient.send(command);
        
        // Record database latency
        const dbDuration = (Date.now() - dbStart) / 1000;
        databaseLatency.observe({
            service: 'backend',
            operation: 'put',
            table: 'orders'
        }, dbDuration);
        
        // Business metrics
        ordersTotal.inc({ service: 'backend', status: 'created' });
        orderValue.observe({ service: 'backend' }, order.total);
        revenueTotal.inc({ service: 'backend' }, order.total);
        
        res.status(201).json(order);
        
    } catch (error) {
        console.error('Error creating order:', error);
        ordersTotal.inc({ service: 'backend', status: 'failed' });
        res.status(500).json({ error: 'Failed to create order' });
    }
});

// User signup endpoint
app.post('/api/signup', async (req, res) => {
    try {
        const { email, source = 'direct' } = req.body;
        
        if (!email) {
            return res.status(400).json({ error: 'Email is required' });
        }
        
        // Simulate signup logic
        const user = {
            id: `user_${Date.now()}`,
            email,
            createdAt: new Date().toISOString()
        };
        
        // Business metrics
        userSignups.inc({ service: 'backend', source });
        
        res.status(201).json(user);
        
    } catch (error) {
        console.error('Error creating user:', error);
        res.status(500).json({ error: 'Failed to create user' });
    }
});

// Frontend/Mobile metrics collection endpoint
app.post('/api/metrics', (req, res) => {
    try {
        const { metrics } = req.body;
        
        if (!metrics || !Array.isArray(metrics)) {
            return res.status(400).json({ error: 'Invalid metrics format' });
        }
        
        // Process frontend/mobile metrics
        metrics.forEach(metric => {
            const { name, value, labels = {} } = metric;
            
            switch (name) {
                case 'page_load_time':
                    // Record frontend page load times
                    httpRequestDuration.observe({
                        method: 'GET',
                        route: labels.page || 'unknown',
                        status_code: '200',
                        service: labels.service || 'frontend'
                    }, value);
                    break;
                    
                case 'mobile_crash':
                    // Record mobile crashes as errors
                    httpErrorsTotal.inc({
                        method: 'CLIENT',
                        route: 'app',
                        status_code: '500',
                        service: 'mobile',
                        error_type: 'crash'
                    });
                    break;
                    
                case 'user_action':
                    // Record user interactions
                    httpRequestsTotal.inc({
                        method: 'USER',
                        route: labels.action || 'unknown',
                        status_code: '200',
                        service: labels.service || 'frontend'
                    });
                    break;
                    
                default:
                    console.log('Unknown metric:', name);
            }
        });
        
        res.json({ status: 'metrics received', count: metrics.length });
        
    } catch (error) {
        console.error('Error processing metrics:', error);
        res.status(500).json({ error: 'Failed to process metrics' });
    }
});

// Simulate some business activity
const simulateActivity = () => {
    // Random order creation
    if (Math.random() > 0.8) {
        const orderValue = Math.random() * 200 + 20;
        ordersTotal.inc({ service: 'backend', status: 'simulated' });
        revenueTotal.inc({ service: 'backend' }, orderValue);
    }
    
    // Random signups
    if (Math.random() > 0.9) {
        const sources = ['organic', 'paid', 'social', 'referral'];
        const source = sources[Math.floor(Math.random() * sources.length)];
        userSignups.inc({ service: 'backend', source });
    }
    
    // Random errors (simulate occasional failures)
    if (Math.random() > 0.95) {
        httpErrorsTotal.inc({
            method: 'POST',
            route: '/api/orders',
            status_code: '500',
            service: 'backend',
            error_type: 'server_error'
        });
    }
};

// Run simulation every 5 seconds
setInterval(simulateActivity, 5000);

// ==========================================
// ERROR HANDLING
// ==========================================
app.use((err, req, res, next) => {
    console.error(err.stack);
    
    httpErrorsTotal.inc({
        method: req.method,
        route: req.route?.path || req.path || 'unknown',
        status_code: '500',
        service: 'backend',
        error_type: 'server_error'
    });
    
    res.status(500).json({ error: 'Something went wrong!' });
});

// ==========================================
// SERVER START
// ==========================================
app.listen(port, '0.0.0.0', () => {
    console.log(`Backend server running on http://0.0.0.0:${port}`);
    console.log(`📊 Metrics available at http://0.0.0.0:${port}/metrics`);
    console.log(`🏥 Health check at http://0.0.0.0:${port}/healthz`);
    
    // Set initial active sessions
    userSessions.set({ service: 'backend' }, Math.floor(Math.random() * 300) + 50);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('👋 SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('👋 SIGINT received, shutting down gracefully');
    process.exit(0);
});