// Mobile App Instrumentation - React Native / Expo
// Métricas específicas para mobile: crashes, ANR, battery, network

import { AppState, Dimensions, Platform } from 'react-native';
import NetInfo from '@react-native-async-storage/async-storage';

class MobileInstrumentation {
  constructor() {
    this.metricsEndpoint = 'http://backend-service/api/metrics/mobile';
    this.sessionId = this.generateSessionId();
    this.appStartTime = Date.now();
    this.screenViews = 0;
    this.userInteractions = 0;
    this.apiCalls = 0;
    this.crashes = 0;
    this.errors = 0;
    
    this.deviceInfo = this.getDeviceInfo();
    this.init();
  }
  
  generateSessionId() {
    return 'mobile_session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
  
  getDeviceInfo() {
    const { width, height } = Dimensions.get('screen');
    return {
      platform: Platform.OS,
      platform_version: Platform.Version,
      screen_width: width,
      screen_height: height,
      device_model: Platform.select({
        ios: 'iPhone', // Pode usar react-native-device-info para detalhes
        android: 'Android Device'
      })
    };
  }
  
  init() {
    console.log('📱 Mobile instrumentation initialized');
    this.setupAppStateTracking();
    this.setupErrorTracking();
    this.setupNetworkMonitoring();
    this.setupPerformanceTracking();
    this.setupBusinessMetrics();
    this.startMetricsCollection();
  }
  
  // =====================================================
  // APP LIFECYCLE & PERFORMANCE (GOLDEN SIGNALS)
  // =====================================================
  setupAppStateTracking() {
    // App state changes
    AppState.addEventListener('change', (nextAppState) => {
      this.sendMetric('mobile_app_state_change', {
        previous_state: this.currentAppState || 'unknown',
        current_state: nextAppState,
        session_duration: Date.now() - this.appStartTime
      });
      this.currentAppState = nextAppState;
    });
    
    // Screen navigation tracking
    this.navigationStartTime = Date.now();
  }
  
  // Track screen navigation (use with React Navigation)
  onNavigationStateChange = (prevState, currentState) => {
    const currentScreen = this.getActiveRouteName(currentState);
    const prevScreen = prevState ? this.getActiveRouteName(prevState) : null;
    
    if (currentScreen !== prevScreen) {
      const navigationTime = Date.now() - this.navigationStartTime;
      this.screenViews++;
      
      this.sendMetric('mobile_screen_navigation', {
        from_screen: prevScreen,
        to_screen: currentScreen,
        navigation_time_ms: navigationTime,
        screen_views_count: this.screenViews
      });
      
      this.navigationStartTime = Date.now();
    }
  }
  
  getActiveRouteName(navigationState) {
    if (!navigationState) return null;
    const route = navigationState.routes[navigationState.index];
    if (route.state) {
      return this.getActiveRouteName(route.state);
    }
    return route.name;
  }
  
  // =====================================================
  // ERROR TRACKING & CRASH REPORTING (GOLDEN SIGNALS - ERRORS)
  // =====================================================
  setupErrorTracking() {
    // JavaScript errors
    if (ErrorUtils) {
      const defaultHandler = ErrorUtils.getGlobalHandler();
      ErrorUtils.setGlobalHandler((error, isFatal) => {
        this.crashes++;
        this.sendMetric('mobile_js_error', {
          error_message: error.message,
          stack_trace: error.stack,
          is_fatal: isFatal,
          device_info: this.deviceInfo,
          app_state: this.currentAppState
        });
        
        // Call original handler
        defaultHandler(error, isFatal);
      });
    }
    
    // Promise rejections
    const tracking = require('promise/setimmediate/rejection-tracking');
    tracking.enable({
      allRejections: true,
      onUnhandled: (id, error) => {
        this.errors++;
        this.sendMetric('mobile_promise_rejection', {
          error_message: error?.message || 'Unhandled promise rejection',
          stack_trace: error?.stack,
          promise_id: id,
          device_info: this.deviceInfo
        });
      }
    });
  }
  
  // =====================================================
  // NETWORK MONITORING (GOLDEN SIGNALS - TRAFFIC/LATENCY)
  // =====================================================
  setupNetworkMonitoring() {
    // Network state monitoring
    NetInfo.addEventListener(state => {
      this.sendMetric('mobile_network_state', {
        is_connected: state.isConnected,
        connection_type: state.type,
        is_internet_reachable: state.isInternetReachable,
        details: state.details
      });
    });
    
    // HTTP request interceptor (para fetch)
    const originalFetch = global.fetch;
    global.fetch = async (...args) => {
      const startTime = Date.now();
      this.apiCalls++;
      
      try {
        const response = await originalFetch(...args);
        const duration = Date.now() - startTime;
        
        this.sendMetric('mobile_api_call', {
          url: args[0],
          method: args[1]?.method || 'GET',
          status: response.status,
          duration_ms: duration,
          success: response.ok,
          network_type: await this.getCurrentNetworkType()
        });
        
        return response;
      } catch (error) {
        const duration = Date.now() - startTime;
        this.sendMetric('mobile_api_error', {
          url: args[0],
          method: args[1]?.method || 'GET',
          duration_ms: duration,
          error_message: error.message,
          network_type: await this.getCurrentNetworkType()
        });
        throw error;
      }
    };
  }
  
  async getCurrentNetworkType() {
    try {
      const state = await NetInfo.fetch();
      return state.type;
    } catch {
      return 'unknown';
    }
  }
  
  // =====================================================
  // PERFORMANCE TRACKING (GOLDEN SIGNALS - SATURATION)
  // =====================================================
  setupPerformanceTracking() {
    // Memory warnings (iOS)
    if (Platform.OS === 'ios') {
      // Note: Precisa de biblioteca nativa para memory warnings
      // DeviceEventEmitter.addListener('MemoryWarning', () => {
      //   this.sendMetric('mobile_memory_warning', {
      //     timestamp: Date.now(),
      //     device_info: this.deviceInfo
      //   });
      // });
    }
    
    // App launch time simulation
    setTimeout(() => {
      const launchTime = Date.now() - this.appStartTime;
      this.sendMetric('mobile_app_launch', {
        launch_time_ms: launchTime,
        is_cold_start: true, // Pode ser determinado dinamicamente
        device_info: this.deviceInfo
      });
    }, 100);
  }
  
  // =====================================================
  // BUSINESS METRICS & USER BEHAVIOR
  // =====================================================
  setupBusinessMetrics() {
    this.businessEvents = {
      screen_views: 0,
      button_taps: 0,
      swipe_actions: 0,
      form_submissions: 0,
      product_views: 0,
      purchases: 0,
      app_opens: 1, // Início da sessão
      session_duration: 0
    };
    
    // Simular eventos de negócio baseados em uso real
    this.simulateUserBehavior();
  }
  
  simulateUserBehavior() {
    // Simular interações do usuário a cada 30 segundos
    setInterval(() => {
      if (this.currentAppState === 'active') {
        // Simular visualização de produto
        if (Math.random() < 0.4) {
          this.businessEvents.product_views++;
          this.sendMetric('mobile_product_view', {
            product_id: `mobile_product_${Math.floor(Math.random() * 500)}`,
            category: ['electronics', 'fashion', 'home', 'sports'][Math.floor(Math.random() * 4)],
            price: Math.floor(Math.random() * 300) + 20,
            view_duration: Math.floor(Math.random() * 60) + 10
          });
        }
        
        // Simular tap em botão
        if (Math.random() < 0.6) {
          this.businessEvents.button_taps++;
          this.userInteractions++;
          this.sendMetric('mobile_button_tap', {
            button_type: ['primary', 'secondary', 'cta', 'navigation'][Math.floor(Math.random() * 4)],
            screen: this.currentScreen || 'unknown'
          });
        }
        
        // Simular swipe/gesture
        if (Math.random() < 0.3) {
          this.businessEvents.swipe_actions++;
          this.sendMetric('mobile_swipe_action', {
            swipe_direction: ['left', 'right', 'up', 'down'][Math.floor(Math.random() * 4)],
            screen: this.currentScreen || 'unknown'
          });
        }
        
        // Simular compra
        if (Math.random() < 0.05) {
          this.businessEvents.purchases++;
          this.sendMetric('mobile_purchase', {
            order_value: Math.floor(Math.random() * 500) + 50,
            payment_method: ['apple_pay', 'google_pay', 'credit_card'][Math.floor(Math.random() * 3)],
            items_count: Math.floor(Math.random() * 3) + 1,
            checkout_duration: Math.floor(Math.random() * 180) + 30
          });
        }
      }
    }, 30000);
  }
  
  // =====================================================
  // METRICS COLLECTION & REPORTING
  // =====================================================
  startMetricsCollection() {
    setInterval(() => {
      const sessionDuration = Date.now() - this.appStartTime;
      this.businessEvents.session_duration = sessionDuration;
      
      // Error rate calculation
      const totalInteractions = this.userInteractions + this.apiCalls;
      const errorRate = totalInteractions > 0 ? ((this.errors + this.crashes) / totalInteractions) * 100 : 0;
      
      // Performance summary
      this.sendMetric('mobile_performance_summary', {
        session_duration_ms: sessionDuration,
        screen_views: this.screenViews,
        user_interactions: this.userInteractions,
        api_calls: this.apiCalls,
        error_rate_percent: errorRate,
        crashes_count: this.crashes,
        errors_count: this.errors,
        app_state: this.currentAppState
      });
      
      // Business summary
      this.sendMetric('mobile_business_summary', {
        ...this.businessEvents,
        conversion_rate: this.businessEvents.product_views > 0 ? 
          (this.businessEvents.purchases / this.businessEvents.product_views) * 100 : 0,
        engagement_score: this.calculateEngagementScore()
      });
      
    }, 60000); // A cada minuto
  }
  
  calculateEngagementScore() {
    const sessionMinutes = (Date.now() - this.appStartTime) / 60000;
    const interactionsPerMinute = sessionMinutes > 0 ? this.userInteractions / sessionMinutes : 0;
    return Math.min(100, interactionsPerMinute * 10); // Score 0-100
  }
  
  // =====================================================
  // METRIC SENDING
  // =====================================================
  sendMetric(metricName, data = {}) {
    const metric = {
      name: metricName,
      timestamp: Date.now(),
      session_id: this.sessionId,
      service: 'mobile',
      platform: Platform.OS,
      device_info: this.deviceInfo,
      ...data
    };
    
    // Enviar para backend (com retry e queue offline)
    this.queueMetric(metric);
  }
  
  queueMetric(metric) {
    // Em produção, usar uma queue persistente (AsyncStorage)
    fetch(this.metricsEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(metric)
    }).catch(() => {
      // Falha silenciosa - em produção, salvar em AsyncStorage para retry
      console.debug('Mobile metric send failed:', metric.name);
    });
    
    // Log para debug
    console.debug('📱 Mobile metric:', metric.name, metric);
  }
  
  // =====================================================
  // PUBLIC METHODS
  // =====================================================
  trackScreen(screenName) {
    this.currentScreen = screenName;
    this.screenViews++;
    this.sendMetric('mobile_screen_view', {
      screen_name: screenName,
      previous_screen: this.previousScreen,
      screen_views_count: this.screenViews
    });
    this.previousScreen = screenName;
  }
  
  trackUserAction(action, properties = {}) {
    this.userInteractions++;
    this.sendMetric('mobile_user_action', {
      action_type: action,
      screen: this.currentScreen,
      ...properties
    });
  }
  
  trackBusinessEvent(eventType, properties = {}) {
    this.sendMetric(`mobile_business_${eventType}`, {
      event_type: eventType,
      screen: this.currentScreen,
      ...properties
    });
  }
  
  trackError(error, context = {}) {
    this.errors++;
    this.sendMetric('mobile_manual_error', {
      error_message: error.message,
      stack_trace: error.stack,
      context,
      screen: this.currentScreen,
      device_info: this.deviceInfo
    });
  }
  
  // ANR Detection (Android Network Request timeout)
  trackANR(duration) {
    this.sendMetric('mobile_anr', {
      anr_duration_ms: duration,
      screen: this.currentScreen,
      device_info: this.deviceInfo,
      app_state: this.currentAppState
    });
  }
  
  // Battery level tracking (se disponível)
  trackBatteryLevel(level, isLowBattery = false) {
    this.sendMetric('mobile_battery_status', {
      battery_level: level,
      is_low_battery: isLowBattery,
      device_info: this.deviceInfo
    });
  }
}

// =====================================================
// REACT NAVIGATION INTEGRATION
// =====================================================
export const createNavigationTracker = (instrumentation) => {
  return {
    onStateChange: (prevState, currentState) => {
      instrumentation.onNavigationStateChange(prevState, currentState);
    }
  };
};

// =====================================================
// REACT COMPONENT HOC FOR SCREEN TRACKING
// =====================================================
export const withScreenTracking = (WrappedComponent, screenName) => {
  return class extends React.Component {
    componentDidMount() {
      if (global.mobileInstrumentation) {
        global.mobileInstrumentation.trackScreen(screenName);
      }
    }
    
    render() {
      return <WrappedComponent {...this.props} />;
    }
  };
};

// =====================================================
// INITIALIZATION
// =====================================================
const mobileInstrumentation = new MobileInstrumentation();

// Make globally available
global.mobileInstrumentation = mobileInstrumentation;
global.trackMobileEvent = (action, props) => mobileInstrumentation.trackUserAction(action, props);
global.trackMobileError = (error, context) => mobileInstrumentation.trackError(error, context);
global.trackMobileBusiness = (type, props) => mobileInstrumentation.trackBusinessEvent(type, props);

console.log('📱 Mobile instrumentation ready!');
console.log('📊 Use trackMobileEvent(action, props) for user actions');
console.log('❌ Use trackMobileError(error, context) for error tracking');
console.log('💼 Use trackMobileBusiness(type, props) for business events');

export default mobileInstrumentation;