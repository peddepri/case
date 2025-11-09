import React, { useEffect, useState } from 'react';
import { SafeAreaView, Text, View, Button, FlatList } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { mobileMetrics } from './metrics';

const BACKEND_URL = process.env.EXPO_PUBLIC_BACKEND_URL || 'http://localhost:3000';

// Simple logger for observability
const logger = {
  info: (msg: string, data?: any) => console.log(`[INFO] ${msg}`, data || ''),
  error: (msg: string, error?: any) => console.error(`[ERROR] ${msg}`, error || ''),
  warn: (msg: string, data?: any) => console.warn(`[WARN] ${msg}`, data || ''),
};

export default function App() {
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = async () => {
    try {
      setLoading(true);
      setError(null);
      logger.info('Fetching orders from backend', { url: BACKEND_URL });
      
      const startTime = Date.now();
      const r = await fetch(`${BACKEND_URL}/api/orders`);
      const duration = Date.now() - startTime;
      
      if (!r.ok) {
        throw new Error(`HTTP ${r.status}: ${r.statusText}`);
      }
      
      const j = await r.json();
      setOrders(j.orders || []);
      
      logger.info('Orders fetched successfully', { 
        count: j.orders?.length || 0, 
        duration: `${duration}ms` 
      });
    } catch (err: any) {
      const errorMsg = err.message || 'Failed to fetch orders';
      setError(errorMsg);
      logger.error('Failed to fetch orders', err);
    } finally {
      setLoading(false);
    }
  };

  const create = async () => {
    try {
      setLoading(true);
      setError(null);
      const orderData = { 
        item: 'mobile', 
        price: Math.round(Math.random() * 100) 
      };
      
      logger.info('Creating order', orderData);
      
      const startTime = Date.now();
      const r = await fetch(`${BACKEND_URL}/api/orders`, {
        method: 'POST', 
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(orderData)
      });
      const duration = Date.now() - startTime;
      
      if (!r.ok) {
        throw new Error(`HTTP ${r.status}: ${r.statusText}`);
      }
      
      logger.info('Order created successfully', { duration: `${duration}ms` });
      await load();
    } catch (err: any) {
      const errorMsg = err.message || 'Failed to create order';
      setError(errorMsg);
      logger.error('Failed to create order', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { 
    logger.info('App mounted', { backendUrl: BACKEND_URL });
    load(); 
  }, []);

  return (
    <SafeAreaView>
      <View style={{ padding: 16 }}>
        <Text style={{ fontSize: 18, fontWeight: 'bold', marginBottom: 8 }}>
          Mobile Orders
        </Text>
        
        {error && (
          <Text style={{ color: 'red', marginBottom: 8 }}>
            Error: {error}
          </Text>
        )}
        
        <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16 }}>
          <Button 
            title={loading ? "Loading..." : "Refresh"} 
            onPress={load} 
            disabled={loading}
          />
          <Button 
            title="Create Order" 
            onPress={create} 
            disabled={loading}
          />
        </View>
        
        <Text style={{ fontSize: 14, marginBottom: 8 }}>
          Total Orders: {orders.length}
        </Text>
        
        <FlatList 
          data={orders} 
          keyExtractor={(o) => o.id}
          renderItem={({ item }) => (
            <Text style={{ paddingVertical: 4 }}>
              • {item.item} - ${item.price}
            </Text>
          )}
          ListEmptyComponent={
            <Text style={{ fontStyle: 'italic', color: '#666' }}>
              No orders yet
            </Text>
          }
        />
        
        <StatusBar style="auto" />
      </View>
    </SafeAreaView>
  );
}
