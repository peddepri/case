import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { initTracing } from './tracing';
import { initWebVitals } from './webVitals';

// Initialize OpenTelemetry tracing BEFORE rendering
initTracing();

// Initialize Web Vitals monitoring
initWebVitals();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
