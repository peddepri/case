// Frontend Instrumentation - Core Web Vitals + Business Metrics
// Para usar em aplicações React/Vue/Angular

import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

class FrontendInstrumentation {
  constructor() {
    this.metricsEndpoint = '/api/metrics/frontend';
    this.sessionId = this.generateSessionId();
    this.pageLoadTime = Date.now();
    this.userInteractions = 0;
    this.apiCallsCount = 0;
    this.errorsCount = 0;
    
    this.init();
  }
  
  generateSessionId() {
    return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
  
  init() {
    console.log('🎯 Frontend instrumentation initialized');
    this.setupWebVitals();
    this.setupErrorTracking();
    this.setupUserInteractionTracking();
    this.setupAPIMonitoring();
    this.setupBusinessMetrics();
    this.startMetricsCollection();
  }
  
  // =====================================================
  // CORE WEB VITALS (GOLDEN SIGNALS)
  // =====================================================
  setupWebVitals() {
    // Latência: Core Web Vitals
    getCLS(this.sendMetric.bind(this, 'frontend_cls'));
    getFID(this.sendMetric.bind(this, 'frontend_fid'));
    getFCP(this.sendMetric.bind(this, 'frontend_fcp'));
    getLCP(this.sendMetric.bind(this, 'frontend_lcp'));
    getTTFB(this.sendMetric.bind(this, 'frontend_ttfb'));
    
    // Page Load Time
    window.addEventListener('load', () => {
      const loadTime = Date.now() - this.pageLoadTime;
      this.sendMetric('frontend_page_load_time', { value: loadTime });
    });
    
    // Navigation Timing API
    if (performance.getEntriesByType) {
      window.addEventListener('load', () => {
        setTimeout(() => {
          const navigation = performance.getEntriesByType('navigation')[0];
          if (navigation) {
            this.sendMetric('frontend_navigation_timing', {
              dns_lookup: navigation.domainLookupEnd - navigation.domainLookupStart,
              tcp_connect: navigation.connectEnd - navigation.connectStart,
              request_response: navigation.responseEnd - navigation.requestStart,
              dom_processing: navigation.domContentLoadedEventEnd - navigation.responseEnd,
              load_complete: navigation.loadEventEnd - navigation.loadEventStart
            });
          }
        }, 0);
      });
    }
  }
  
  // =====================================================
  // ERROR TRACKING (GOLDEN SIGNALS - ERRORS)
  // =====================================================
  setupErrorTracking() {
    // JavaScript Errors
    window.addEventListener('error', (event) => {
      this.errorsCount++;
      this.sendMetric('frontend_js_error', {
        error_message: event.message,
        filename: event.filename,
        line_number: event.lineno,
        column_number: event.colno,
        stack_trace: event.error?.stack,
        user_agent: navigator.userAgent,
        url: window.location.href
      });
    });
    
    // Promise Rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.errorsCount++;
      this.sendMetric('frontend_promise_rejection', {
        reason: event.reason?.toString(),
        stack_trace: event.reason?.stack,
        url: window.location.href
      });
    });
    
    // Resource Loading Errors
    window.addEventListener('error', (event) => {
      if (event.target !== window) {
        this.sendMetric('frontend_resource_error', {
          resource_type: event.target.tagName,
          resource_url: event.target.src || event.target.href,
          url: window.location.href
        });
      }
    }, true);
  }
  
  // =====================================================
  // USER INTERACTION TRACKING (GOLDEN SIGNALS - TRAFFIC)
  // =====================================================
  setupUserInteractionTracking() {
    // Click tracking
    document.addEventListener('click', (event) => {
      this.userInteractions++;
      this.sendMetric('frontend_user_click', {
        element_tag: event.target.tagName,
        element_class: event.target.className,
        element_id: event.target.id,
        page_url: window.location.href
      });
    });
    
    // Page visibility
    document.addEventListener('visibilitychange', () => {
      this.sendMetric('frontend_page_visibility', {
        visibility_state: document.visibilityState,
        page_url: window.location.href
      });
    });
    
    // Session duration tracking
    this.sessionStartTime = Date.now();
    setInterval(() => {
      if (document.visibilityState === 'visible') {
        const sessionDuration = Date.now() - this.sessionStartTime;
        this.sendMetric('frontend_session_duration', { 
          duration_ms: sessionDuration,
          interactions_count: this.userInteractions
        });
      }
    }, 60000); // A cada minuto
  }
  
  // =====================================================
  // API MONITORING (GOLDEN SIGNALS - TRAFFIC/LATENCY/ERRORS)
  // =====================================================
  setupAPIMonitoring() {
    // Interceptar fetch calls
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      const startTime = Date.now();
      this.apiCallsCount++;
      
      try {
        const response = await originalFetch(...args);
        const duration = Date.now() - startTime;
        
        this.sendMetric('frontend_api_call', {
          url: args[0],
          method: args[1]?.method || 'GET',
          status: response.status,
          duration_ms: duration,
          success: response.ok
        });
        
        return response;
      } catch (error) {
        const duration = Date.now() - startTime;
        this.sendMetric('frontend_api_error', {
          url: args[0],
          method: args[1]?.method || 'GET',
          duration_ms: duration,
          error_message: error.message
        });
        throw error;
      }
    };
    
    // Interceptar XMLHttpRequest
    const originalXMLHttpRequest = window.XMLHttpRequest;
    window.XMLHttpRequest = function() {
      const xhr = new originalXMLHttpRequest();
      const startTime = Date.now();
      
      xhr.addEventListener('loadend', function() {
        const duration = Date.now() - startTime;
        window.frontendInstrumentation?.sendMetric('frontend_xhr_call', {
          url: this.responseURL,
          method: this.method || 'GET',
          status: this.status,
          duration_ms: duration,
          success: this.status >= 200 && this.status < 400
        });
      });
      
      return xhr;
    };
  }
  
  // =====================================================
  // BUSINESS METRICS
  // =====================================================
  setupBusinessMetrics() {
    // Simular eventos de negócio baseados em interações do usuário
    this.businessEvents = {
      page_views: 0,
      button_clicks: 0,
      form_submissions: 0,
      product_views: 0,
      cart_additions: 0,
      checkout_starts: 0,
      purchase_completions: 0
    };
    
    // Page view tracking
    this.trackPageView();
    
    // Form submission tracking
    document.addEventListener('submit', (event) => {
      this.businessEvents.form_submissions++;
      this.sendMetric('frontend_form_submission', {
        form_action: event.target.action,
        form_method: event.target.method,
        page_url: window.location.href
      });
    });
    
    // Product interaction simulation
    this.simulateBusinessEvents();
  }
  
  trackPageView() {
    this.businessEvents.page_views++;
    this.sendMetric('frontend_page_view', {
      page_url: window.location.href,
      page_title: document.title,
      referrer: document.referrer,
      user_agent: navigator.userAgent,
      screen_resolution: `${screen.width}x${screen.height}`,
      viewport_size: `${window.innerWidth}x${window.innerHeight}`
    });
  }
  
  simulateBusinessEvents() {
    // Simular eventos de e-commerce baseados em comportamento do usuário
    setInterval(() => {
      if (document.visibilityState === 'visible' && this.userInteractions > 0) {
        // Simular visualização de produto
        if (Math.random() < 0.3) {
          this.businessEvents.product_views++;
          this.sendMetric('frontend_product_view', {
            product_id: `product_${Math.floor(Math.random() * 1000)}`,
            product_category: ['electronics', 'clothing', 'books', 'home'][Math.floor(Math.random() * 4)],
            price: Math.floor(Math.random() * 500) + 10
          });
        }
        
        // Simular adição ao carrinho
        if (Math.random() < 0.1) {
          this.businessEvents.cart_additions++;
          this.sendMetric('frontend_cart_addition', {
            product_id: `product_${Math.floor(Math.random() * 1000)}`,
            quantity: Math.floor(Math.random() * 3) + 1,
            price: Math.floor(Math.random() * 200) + 20
          });
        }
        
        // Simular início de checkout
        if (Math.random() < 0.05) {
          this.businessEvents.checkout_starts++;
          this.sendMetric('frontend_checkout_start', {
            cart_value: Math.floor(Math.random() * 1000) + 50,
            items_count: Math.floor(Math.random() * 5) + 1
          });
        }
        
        // Simular compra completa
        if (Math.random() < 0.02) {
          this.businessEvents.purchase_completions++;
          this.sendMetric('frontend_purchase_completion', {
            order_value: Math.floor(Math.random() * 800) + 100,
            payment_method: ['credit_card', 'paypal', 'bank_transfer'][Math.floor(Math.random() * 3)],
            items_count: Math.floor(Math.random() * 4) + 1
          });
        }
      }
    }, 30000); // A cada 30 segundos
  }
  
  // =====================================================
  // RESOURCE MONITORING (GOLDEN SIGNALS - SATURATION)
  // =====================================================
  startMetricsCollection() {
    setInterval(() => {
      // Memory usage (se disponível)
      if (performance.memory) {
        this.sendMetric('frontend_memory_usage', {
          used_heap: performance.memory.usedJSHeapSize,
          total_heap: performance.memory.totalJSHeapSize,
          heap_limit: performance.memory.jsHeapSizeLimit,
          usage_percent: (performance.memory.usedJSHeapSize / performance.memory.totalJSHeapSize) * 100
        });
      }
      
      // Connection information
      if (navigator.connection) {
        this.sendMetric('frontend_connection_info', {
          effective_type: navigator.connection.effectiveType,
          downlink: navigator.connection.downlink,
          rtt: navigator.connection.rtt,
          save_data: navigator.connection.saveData
        });
      }
      
      // Performance entries
      const resources = performance.getEntriesByType('resource');
      if (resources.length > 0) {
        const slowResources = resources.filter(r => r.duration > 1000);
        if (slowResources.length > 0) {
          this.sendMetric('frontend_slow_resources', {
            slow_resources_count: slowResources.length,
            total_resources: resources.length,
            slowest_resource: slowResources[0].name,
            slowest_duration: slowResources[0].duration
          });
        }
      }
      
      // Error rate calculation
      const totalInteractions = this.userInteractions + this.apiCallsCount;
      const errorRate = totalInteractions > 0 ? (this.errorsCount / totalInteractions) * 100 : 0;
      
      this.sendMetric('frontend_error_rate', {
        error_rate_percent: errorRate,
        total_errors: this.errorsCount,
        total_interactions: totalInteractions
      });
      
      // Aggregate business metrics
      this.sendMetric('frontend_business_summary', {
        ...this.businessEvents,
        session_duration: Date.now() - this.sessionStartTime,
        conversion_rate: this.businessEvents.page_views > 0 ? 
          (this.businessEvents.purchase_completions / this.businessEvents.page_views) * 100 : 0
      });
      
    }, 60000); // A cada minuto
  }
  
  // =====================================================
  // METRIC SENDING
  // =====================================================
  sendMetric(metricName, data = {}) {
    const metric = {
      name: metricName,
      timestamp: Date.now(),
      session_id: this.sessionId,
      page_url: window.location.href,
      user_agent: navigator.userAgent,
      service: 'frontend',
      ...data
    };
    
    // Enviar para backend (com fallback silencioso)
    fetch(this.metricsEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metric)
    }).catch(() => {
      // Falha silenciosa para não impactar UX
      console.debug('Metric send failed:', metricName);
    });
    
    // Log para debug (remover em produção)
    console.debug('📊 Frontend metric:', metricName, data);
  }
  
  // =====================================================
  // PUBLIC METHODS
  // =====================================================
  trackCustomEvent(eventName, properties = {}) {
    this.sendMetric(`frontend_custom_${eventName}`, properties);
  }
  
  trackError(error, context = {}) {
    this.errorsCount++;
    this.sendMetric('frontend_manual_error', {
      error_message: error.message,
      stack_trace: error.stack,
      context,
      ...context
    });
  }
  
  trackBusinessEvent(eventType, properties = {}) {
    this.sendMetric(`frontend_business_${eventType}`, {
      event_type: eventType,
      ...properties
    });
  }
}

// =====================================================
// INITIALIZATION
// =====================================================
if (typeof window !== 'undefined') {
  window.frontendInstrumentation = new FrontendInstrumentation();
  
  // Expose global functions for easy tracking
  window.trackEvent = (name, props) => window.frontendInstrumentation.trackCustomEvent(name, props);
  window.trackError = (error, context) => window.frontendInstrumentation.trackError(error, context);
  window.trackBusiness = (type, props) => window.frontendInstrumentation.trackBusinessEvent(type, props);
  
  console.log('🎯 Frontend instrumentation ready!');
  console.log('📊 Use window.trackEvent(name, props) for custom events');
  console.log('❌ Use window.trackError(error, context) for manual error tracking');
  console.log('💼 Use window.trackBusiness(type, props) for business events');
}

export default FrontendInstrumentation;