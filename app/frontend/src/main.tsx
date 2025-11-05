import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { initTracing } from './tracing';
import { initWebVitals } from './webVitals';
import { metricsCollector } from './metrics';
import './observability.js';

// Initialize OpenTelemetry tracing BEFORE rendering
initTracing();

// Initialize Web Vitals monitoring
initWebVitals();

// Initialize metrics collection
console.log('📊 Frontend metrics initialized');

// Initialize Frontend Observability
console.log('🚀 Frontend starting with complete observability...');

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
