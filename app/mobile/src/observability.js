// ==========================================
// MOBILE OBSERVABILITY INSTRUMENTATION
// ==========================================

import { Platform } from 'react-native';

class MobileMetrics {
    constructor() {
        this.backendUrl = process.env.EXPO_PUBLIC_BACKEND_URL || 'http://localhost:3000';
        this.serviceName = 'mobile';
        this.sessionId = this.generateSessionId();
        this.metricsBuffer = [];
        this.initialized = false;
        this.appState = 'active';
        
        this.init();
    }
    
    init() {
        if (this.initialized) return;
        
        console.log('📱 Mobile Observability initialized');
        
        // Start collecting metrics
        this.setupPerformanceTracking();
        this.setupErrorTracking();
        this.setupUserInteractionTracking();
        this.setupAppStateTracking();
        this.setupNetworkTracking();
        
        // Send metrics every 60 seconds (mobile-friendly)
        setInterval(() => this.flushMetrics(), 60000);
        
        this.initialized = true;
    }
    
    generateSessionId() {
        return 'mobile_session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    }
    
    // ==========================================
    // GOLDEN SIGNALS - MOBILE
    // ==========================================
    
    // 1. LATENCY - App launch time, screen transitions, API calls
    setupPerformanceTracking() {
        // App launch time (React Native doesn't have navigation timing, so we simulate)
        const launchStart = Date.now();
        
        setTimeout(() => {
            const launchTime = Date.now() - launchStart;
            this.recordMetric('app_launch_time', launchTime, {
                service: this.serviceName,
                platform: Platform.OS,
                version: Platform.Version
            });
        }, 1000);
        
        // Screen transition tracking
        this.setupNavigationTracking();
        
        // API performance tracking
        this.setupApiTracking();
    }
    
    setupNavigationTracking() {
        // This would integrate with your navigation library (React Navigation, etc.)
        // For now, we'll provide a manual tracking method
        this.navigationStart = null;
    }
    
    trackScreenTransition(fromScreen, toScreen) {
        if (this.navigationStart) {
            const transitionTime = Date.now() - this.navigationStart;
            this.recordMetric('screen_transition_time', transitionTime, {
                from_screen: fromScreen,
                to_screen: toScreen,
                service: this.serviceName,
                platform: Platform.OS
            });
        }
        this.navigationStart = Date.now();
        
        // Record screen view
        this.recordMetric('screen_view', 1, {
            screen: toScreen,
            service: this.serviceName,
            platform: Platform.OS
        });
    }
    
    setupApiTracking() {
        // Monkey patch fetch for mobile
        const originalFetch = global.fetch;
        global.fetch = async (...args) => {
            const start = Date.now();
            const url = typeof args[0] === 'string' ? args[0] : args[0].url;
            
            try {
                const response = await originalFetch(...args);
                const duration = Date.now() - start;
                
                // Record API latency
                this.recordMetric('api_response_time', duration, {
                    url: this.sanitizeUrl(url),
                    status: response.status,
                    service: this.serviceName,
                    platform: Platform.OS
                });
                
                // Count API requests
                this.recordMetric('api_request', 1, {
                    url: this.sanitizeUrl(url),
                    method: args[1]?.method || 'GET',
                    status: response.status,
                    service: this.serviceName,
                    platform: Platform.OS
                });
                
                // Track API errors
                if (!response.ok) {
                    this.recordMetric('api_error', 1, {
                        url: this.sanitizeUrl(url),
                        status: response.status,
                        service: this.serviceName,
                        platform: Platform.OS,
                        error_type: 'http_error'
                    });
                }
                
                return response;
            } catch (error) {
                this.recordMetric('api_error', 1, {
                    url: this.sanitizeUrl(url),
                    service: this.serviceName,
                    platform: Platform.OS,
                    error_type: 'network_error',
                    message: error.message
                });
                
                throw error;
            }
        };
    }
    
    // 2. TRAFFIC - User interactions, screen views, app usage
    setupUserInteractionTracking() {
        // App sessions
        this.recordMetric('app_session_start', 1, {
            service: this.serviceName,
            platform: Platform.OS,
            session: this.sessionId
        });
        
        // Track gestures and taps (would integrate with gesture handlers)
        this.setupGestureTracking();
    }
    
    setupGestureTracking() {
        // This would integrate with react-native-gesture-handler or similar
        // For now, provide manual tracking methods
    }
    
    trackUserAction(action, target, metadata = {}) {
        this.recordMetric('user_action', 1, {
            action,
            target,
            service: this.serviceName,
            platform: Platform.OS,
            session: this.sessionId,
            ...metadata
        });
    }
    
    // 3. ERRORS - App crashes, JavaScript errors, network failures
    setupErrorTracking() {
        // Global error handler
        const originalHandler = global.ErrorUtils.getGlobalHandler();
        
        global.ErrorUtils.setGlobalHandler((error, isFatal) => {
            this.recordMetric('mobile_crash', 1, {
                message: error.message,
                stack: error.stack,
                is_fatal: isFatal,
                service: this.serviceName,
                platform: Platform.OS,
                error_type: isFatal ? 'crash' : 'javascript_error'
            });
            
            // Call original handler
            if (originalHandler) {
                originalHandler(error, isFatal);
            }
        });
        
        // Promise rejection tracking
        require('react-native').LogBox.ignoreAllLogs(false);
        
        const originalConsoleError = console.error;
        console.error = (...args) => {
            const message = args.join(' ');
            if (message.includes('Possible Unhandled Promise Rejection')) {
                this.recordMetric('promise_rejection', 1, {
                    message,
                    service: this.serviceName,
                    platform: Platform.OS,
                    error_type: 'promise_rejection'
                });
            }
            originalConsoleError(...args);
        };
    }
    
    // 4. SATURATION - Memory usage, battery, performance
    setupAppStateTracking() {
        const { AppState } = require('react-native');
        
        AppState.addEventListener('change', (nextAppState) => {
            if (this.appState.match(/inactive|background/) && nextAppState === 'active') {
                // App came to foreground
                this.recordMetric('app_foreground', 1, {
                    service: this.serviceName,
                    platform: Platform.OS,
                    session: this.sessionId
                });
            } else if (this.appState === 'active' && nextAppState.match(/inactive|background/)) {
                // App went to background
                this.recordMetric('app_background', 1, {
                    service: this.serviceName,
                    platform: Platform.OS,
                    session: this.sessionId
                });
            }
            
            this.appState = nextAppState;
        });
        
        // Memory pressure tracking (iOS)
        if (Platform.OS === 'ios') {
            // Would integrate with react-native-device-info or similar
            this.trackMemoryPressure();
        }
    }
    
    trackMemoryPressure() {
        setInterval(() => {
            // Simulate memory usage tracking
            const memoryUsage = Math.random() * 100 + 50; // MB
            this.recordMetric('memory_usage', memoryUsage, {
                service: this.serviceName,
                platform: Platform.OS,
                type: 'heap_mb'
            });
        }, 30000);
    }
    
    setupNetworkTracking() {
        const { NetInfo } = require('@react-native-async-storage/async-storage');
        
        // Network state changes
        if (NetInfo) {
            NetInfo.addEventListener(state => {
                this.recordMetric('network_change', 1, {
                    type: state.type,
                    is_connected: state.isConnected,
                    service: this.serviceName,
                    platform: Platform.OS
                });
            });
        }
    }
    
    // ==========================================
    // MOBILE-SPECIFIC METRICS
    // ==========================================
    
    // Track ANR (Application Not Responding)
    trackANR(duration, screen) {
        this.recordMetric('anr_event', duration, {
            screen,
            service: this.serviceName,
            platform: Platform.OS,
            severity: duration > 5000 ? 'critical' : 'warning'
        });
    }
    
    // Track app performance
    trackPerformanceMetric(metric, value, context = {}) {
        this.recordMetric(`performance_${metric}`, value, {
            service: this.serviceName,
            platform: Platform.OS,
            ...context
        });
    }
    
    // Track feature usage
    trackFeatureUsage(feature, action = 'used') {
        this.recordMetric('feature_usage', 1, {
            feature,
            action,
            service: this.serviceName,
            platform: Platform.OS
        });
    }
    
    // ==========================================
    // BUSINESS METRICS - MOBILE
    // ==========================================
    
    // User journey tracking
    trackUserJourney(step, metadata = {}) {
        this.recordMetric('user_journey_step', 1, {
            step,
            service: this.serviceName,
            platform: Platform.OS,
            session: this.sessionId,
            ...metadata
        });
    }
    
    // Conversion events
    trackConversion(event, value = 1) {
        this.recordMetric('conversion_event', value, {
            event,
            service: this.serviceName,
            platform: Platform.OS,
            session: this.sessionId
        });
    }
    
    // In-app purchases
    trackPurchase(productId, price, currency = 'USD') {
        this.recordMetric('purchase_event', price, {
            product_id: productId,
            currency,
            service: this.serviceName,
            platform: Platform.OS,
            session: this.sessionId
        });
    }
    
    // Push notification interactions
    trackNotification(action, notificationId, metadata = {}) {
        this.recordMetric('notification_event', 1, {
            action, // 'received', 'opened', 'dismissed'
            notification_id: notificationId,
            service: this.serviceName,
            platform: Platform.OS,
            ...metadata
        });
    }
    
    // ==========================================
    // UTILITY METHODS
    // ==========================================
    
    sanitizeUrl(url) {
        // Remove query parameters and sensitive data
        try {
            const urlObj = new URL(url);
            return `${urlObj.protocol}//${urlObj.host}${urlObj.pathname}`;
        } catch {
            return url.split('?')[0];
        }
    }
    
    recordMetric(name, value, labels = {}) {
        this.metricsBuffer.push({
            name,
            value,
            labels: {
                ...labels,
                timestamp: Date.now(),
                session: this.sessionId,
                platform_version: Platform.Version,
                os: Platform.OS
            }
        });
        
        // Auto-flush if buffer gets too large
        if (this.metricsBuffer.length > 50) { // Smaller buffer for mobile
            this.flushMetrics();
        }
    }
    
    async flushMetrics() {
        if (this.metricsBuffer.length === 0) return;
        
        const metrics = [...this.metricsBuffer];
        this.metricsBuffer = [];
        
        try {
            const response = await fetch(`${this.backendUrl}/api/metrics`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ metrics }),
                timeout: 10000 // 10 second timeout for mobile
            });
            
            if (response.ok) {
                console.log(`📱 Sent ${metrics.length} mobile metrics`);
            } else {
                throw new Error(`HTTP ${response.status}`);
            }
        } catch (error) {
            console.error('Failed to send mobile metrics:', error);
            // Put metrics back in buffer for retry (keep only last 100)
            this.metricsBuffer = [...metrics.slice(-100), ...this.metricsBuffer];
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
            platform: Platform.OS,
            ...data
        });
    }
    
    // Performance timing
    startTimer(label) {
        const startTime = Date.now();
        return () => {
            const duration = Date.now() - startTime;
            this.recordMetric('custom_timing', duration, {
                label,
                service: this.serviceName,
                platform: Platform.OS
            });
            return duration;
        };
    }
    
    // Manual crash reporting
    reportCrash(error, context = {}) {
        this.recordMetric('manual_crash_report', 1, {
            message: error.message,
            stack: error.stack,
            service: this.serviceName,
            platform: Platform.OS,
            ...context
        });
    }
}

// Export singleton instance
const mobileMetrics = new MobileMetrics();

export default mobileMetrics;

// Also make available globally for easy access
global.mobileMetrics = mobileMetrics;