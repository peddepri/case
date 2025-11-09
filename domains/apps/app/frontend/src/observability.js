// ==========================================
// FRONTEND OBSERVABILITY INSTRUMENTATION
// ==========================================

class FrontendMetrics {
    constructor() {
        this.backendUrl = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000';
        this.serviceName = 'frontend';
        this.sessionId = this.generateSessionId();
        this.metricsBuffer = [];
        this.initialized = false;
        
        this.init();
    }
    
    init() {
        if (this.initialized) return;
        
        console.log('🔍 Frontend Observability initialized');
        
        // Start collecting metrics
        this.setupPerformanceObserver();
        this.setupErrorTracking();
        this.setupUserInteractionTracking();
        this.setupResourceTracking();
        this.setupCoreWebVitals();
        
        // Send metrics every 30 seconds
        setInterval(() => this.flushMetrics(), 30000);
        
        // Send metrics on page unload
        window.addEventListener('beforeunload', () => this.flushMetrics());
        
        this.initialized = true;
    }
    
    generateSessionId() {
        return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    // ==========================================
    // GOLDEN SIGNALS - FRONTEND
    // ==========================================
    
    // 1. LATENCY - Page load times, API response times
    setupPerformanceObserver() {
        if (!('PerformanceObserver' in window)) return;
        
        // Navigation timing (page loads)
        const navObserver = new PerformanceObserver((list) => {
            list.getEntries().forEach((entry) => {
                if (entry.entryType === 'navigation') {
                    this.recordMetric('page_load_time', entry.loadEventEnd - entry.fetchStart, {
                        page: window.location.pathname,
                        service: this.serviceName
                    });
                    
                    this.recordMetric('time_to_interactive', entry.domInteractive - entry.fetchStart, {
                        page: window.location.pathname,
                        service: this.serviceName
                    });
                }
            });
        });
        
        navObserver.observe({ entryTypes: ['navigation'] });
        
        // Resource timing (API calls, assets)
        const resourceObserver = new PerformanceObserver((list) => {
            list.getEntries().forEach((entry) => {
                if (entry.initiatorType === 'xmlhttprequest' || entry.initiatorType === 'fetch') {
                    this.recordMetric('api_response_time', entry.responseEnd - entry.requestStart, {
                        url: entry.name,
                        service: this.serviceName
                    });
                }
            });
        });
        
        resourceObserver.observe({ entryTypes: ['resource'] });
    }
    
    // 2. TRAFFIC - User interactions, page views
    setupUserInteractionTracking() {
        // Page views
        this.recordMetric('page_view', 1, {
            page: window.location.pathname,
            service: this.serviceName,
            referrer: document.referrer
        });
        
        // Button clicks
        document.addEventListener('click', (event) => {
            if (event.target.tagName === 'BUTTON' || event.target.role === 'button') {
                this.recordMetric('user_action', 1, {
                    action: 'button_click',
                    element: event.target.textContent || event.target.id || 'unknown',
                    service: this.serviceName
                });
            }
        });
        
        // Form submissions
        document.addEventListener('submit', (event) => {
            this.recordMetric('user_action', 1, {
                action: 'form_submit',
                form: event.target.id || event.target.className || 'unknown',
                service: this.serviceName
            });
        });
        
        // Route changes (SPA)
        let currentPath = window.location.pathname;
        const originalPushState = history.pushState;
        const originalReplaceState = history.replaceState;
        
        history.pushState = function(...args) {
            originalPushState.apply(history, args);
            if (window.location.pathname !== currentPath) {
                currentPath = window.location.pathname;
                window.frontendMetrics?.recordMetric('page_view', 1, {
                    page: currentPath,
                    service: 'frontend',
                    type: 'spa_navigation'
                });
            }
        };
        
        history.replaceState = function(...args) {
            originalReplaceState.apply(history, args);
            if (window.location.pathname !== currentPath) {
                currentPath = window.location.pathname;
                window.frontendMetrics?.recordMetric('page_view', 1, {
                    page: currentPath,
                    service: 'frontend',
                    type: 'spa_navigation'
                });
            }
        };
    }
    
    // 3. ERRORS - JavaScript errors, failed API calls
    setupErrorTracking() {
        // JavaScript errors
        window.addEventListener('error', (event) => {
            this.recordMetric('javascript_error', 1, {
                message: event.message,
                filename: event.filename,
                lineno: event.lineno,
                service: this.serviceName,
                error_type: 'javascript'
            });
        });
        
        // Unhandled promise rejections
        window.addEventListener('unhandledrejection', (event) => {
            this.recordMetric('javascript_error', 1, {
                message: event.reason?.message || 'Unhandled promise rejection',
                service: this.serviceName,
                error_type: 'promise_rejection'
            });
        });
        
        // API error tracking (monkey patch fetch)
        const originalFetch = window.fetch;
        window.fetch = async (...args) => {
            const start = performance.now();
            try {
                const response = await originalFetch(...args);
                const duration = performance.now() - start;
                
                // Record API latency
                this.recordMetric('api_response_time', duration, {
                    url: args[0],
                    status: response.status,
                    service: this.serviceName
                });
                
                // Count API calls
                this.recordMetric('api_request', 1, {
                    url: args[0],
                    method: args[1]?.method || 'GET',
                    status: response.status,
                    service: this.serviceName
                });
                
                // Track errors
                if (!response.ok) {
                    this.recordMetric('api_error', 1, {
                        url: args[0],
                        status: response.status,
                        service: this.serviceName,
                        error_type: 'http_error'
                    });
                }
                
                return response;
            } catch (error) {
                const duration = performance.now() - start;
                
                this.recordMetric('api_error', 1, {
                    url: args[0],
                    service: this.serviceName,
                    error_type: 'network_error',
                    message: error.message
                });
                
                throw error;
            }
        };
    }
    
    // 4. SATURATION - Browser performance metrics
    setupResourceTracking() {
        setInterval(() => {
            // Memory usage (if available)
            if ('memory' in performance) {
                this.recordMetric('memory_usage', performance.memory.usedJSHeapSize, {
                    service: this.serviceName,
                    type: 'used_heap'
                });
                
                this.recordMetric('memory_usage', performance.memory.totalJSHeapSize, {
                    service: this.serviceName,
                    type: 'total_heap'
                });
            }
            
            // Connection info
            if ('connection' in navigator) {
                this.recordMetric('connection_speed', navigator.connection.downlink, {
                    service: this.serviceName,
                    type: 'downlink_mbps'
                });
                
                this.recordMetric('connection_rtt', navigator.connection.rtt, {
                    service: this.serviceName,
                    type: 'round_trip_time'
                });
            }
        }, 30000);
    }
    
    // ==========================================
    // CORE WEB VITALS
    // ==========================================
    setupCoreWebVitals() {
        // Largest Contentful Paint (LCP)
        if ('PerformanceObserver' in window) {
            const lcpObserver = new PerformanceObserver((list) => {
                const entries = list.getEntries();
                const lastEntry = entries[entries.length - 1];
                
                this.recordMetric('largest_contentful_paint', lastEntry.startTime, {
                    service: this.serviceName,
                    page: window.location.pathname
                });
            });
            
            lcpObserver.observe({ entryTypes: ['largest-contentful-paint'] });
        }
        
        // First Input Delay (FID)
        if ('PerformanceObserver' in window) {
            const fidObserver = new PerformanceObserver((list) => {
                list.getEntries().forEach((entry) => {
                    this.recordMetric('first_input_delay', entry.processingStart - entry.startTime, {
                        service: this.serviceName,
                        page: window.location.pathname
                    });
                });
            });
            
            fidObserver.observe({ entryTypes: ['first-input'] });
        }
        
        // Cumulative Layout Shift (CLS)
        if ('PerformanceObserver' in window) {
            let clsScore = 0;
            
            const clsObserver = new PerformanceObserver((list) => {
                list.getEntries().forEach((entry) => {
                    if (!entry.hadRecentInput) {
                        clsScore += entry.value;
                    }
                });
                
                this.recordMetric('cumulative_layout_shift', clsScore, {
                    service: this.serviceName,
                    page: window.location.pathname
                });
            });
            
            clsObserver.observe({ entryTypes: ['layout-shift'] });
        }
    }
    
    // ==========================================
    // BUSINESS METRICS - FRONTEND
    // ==========================================
    
    // Track user journey
    trackUserJourney(step, metadata = {}) {
        this.recordMetric('user_journey_step', 1, {
            step,
            service: this.serviceName,
            session: this.sessionId,
            ...metadata
        });
    }
    
    // Track conversion events
    trackConversion(event, value = 1) {
        this.recordMetric('conversion_event', value, {
            event,
            service: this.serviceName,
            session: this.sessionId
        });
    }
    
    // Track feature usage
    trackFeatureUsage(feature, action = 'used') {
        this.recordMetric('feature_usage', 1, {
            feature,
            action,
            service: this.serviceName
        });
    }
    
    // ==========================================
    // METRICS COLLECTION
    // ==========================================
    
    recordMetric(name, value, labels = {}) {
        this.metricsBuffer.push({
            name,
            value,
            labels: {
                ...labels,
                timestamp: Date.now(),
                session: this.sessionId,
                user_agent: navigator.userAgent,
                url: window.location.href
            }
        });
        
        // Auto-flush if buffer gets too large
        if (this.metricsBuffer.length > 100) {
            this.flushMetrics();
        }
    }
    
    async flushMetrics() {
        if (this.metricsBuffer.length === 0) return;
        
        const metrics = [...this.metricsBuffer];
        this.metricsBuffer = [];
        
        try {
            await fetch(`${this.backendUrl}/api/metrics`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ metrics })
            });
            
            console.log(`📊 Sent ${metrics.length} frontend metrics`);
        } catch (error) {
            console.error('Failed to send frontend metrics:', error);
            // Put metrics back in buffer for retry
            this.metricsBuffer.unshift(...metrics);
        }
    }
    
    // ==========================================
    // PUBLIC API
    // ==========================================
    
    // Custom event tracking
    track(eventName, data = {}) {
        this.recordMetric('custom_event', 1, {
            event: eventName,
            service: this.serviceName,
            ...data
        });
    }
    
    // Performance timing
    time(label) {
        console.time(`metrics_${label}`);
        return () => {
            console.timeEnd(`metrics_${label}`);
            const duration = performance.now();
            this.recordMetric('custom_timing', duration, {
                label,
                service: this.serviceName
            });
        };
    }
}

// ==========================================
// INITIALIZATION
// ==========================================

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.frontendMetrics = new FrontendMetrics();
    });
} else {
    window.frontendMetrics = new FrontendMetrics();
}

// Export for manual usage
export default FrontendMetrics;