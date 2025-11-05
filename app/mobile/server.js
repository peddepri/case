const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 19006;

// Counter for requests
let requestCount = 0;
let errorCount = 0;
let responseTimeSum = 0;

// Middleware to track requests
app.use((req, res, next) => {
  const start = Date.now();
  requestCount++;
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    responseTimeSum += duration;
    
    if (res.statusCode >= 400) {
      errorCount++;
    }
  });
  
  next();
});

// Serve static files
app.use(express.static(path.join(__dirname, 'web-build')));

// Metrics endpoint
app.get('/metrics', (req, res) => {
  const avgResponseTime = requestCount > 0 ? responseTimeSum / requestCount : 0;
  const errorRate = requestCount > 0 ? errorCount / requestCount : 0;
  
  const metrics = `# HELP mobile_requests_total Total HTTP requests to mobile app
# TYPE mobile_requests_total counter
mobile_requests_total{method="GET",status="200"} ${requestCount - errorCount}
mobile_requests_total{method="GET",status="404"} ${errorCount}

# HELP mobile_errors_total Total HTTP errors
# TYPE mobile_errors_total counter  
mobile_errors_total ${errorCount}

# HELP mobile_response_time_seconds Average response time
# TYPE mobile_response_time_seconds gauge
mobile_response_time_seconds ${avgResponseTime.toFixed(3)}

# HELP mobile_error_rate Error rate percentage
# TYPE mobile_error_rate gauge
mobile_error_rate ${(errorRate * 100).toFixed(2)}

# HELP mobile_app_starts_total Total app starts
# TYPE mobile_app_starts_total counter
mobile_app_starts_total 1

# HELP mobile_load_time_ms App load time simulation
# TYPE mobile_load_time_ms gauge
mobile_load_time_ms ${Math.floor(Math.random() * 3000 + 1000)}

# HELP mobile_user_interactions_total User interactions simulation  
# TYPE mobile_user_interactions_total counter
mobile_user_interactions_total ${Math.floor(requestCount * 0.8)}
`;

  res.set('Content-Type', 'text/plain');
  res.send(metrics);
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'mobile',
    uptime: process.uptime(),
    requests: requestCount,
    errors: errorCount
  });
});

// Default route for mobile app
app.get('/', (req, res) => {
  res.json({
    message: '📱 Mobile App API',
    version: '1.0.0',
    endpoints: {
      metrics: '/metrics',
      health: '/health',
      status: '/status'
    }
  });
});

// Catch all other routes
app.get('*', (req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    message: 'Mobile API - Route not available'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`📱 Mobile app with metrics running on port ${PORT}`);
  console.log(`Metrics available at: http://localhost:${PORT}/metrics`);
});

module.exports = app;