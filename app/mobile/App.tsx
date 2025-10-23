import React, { useEffect, useState } from 'react';
import { SafeAreaView, Text, View, Button, FlatList } from 'react-native';
import { StatusBar } from 'expo-status-bar';

const BACKEND_URL = process.env.EXPO_PUBLIC_BACKEND_URL || 'http://localhost:3000';

export default function App() {
  const [orders, setOrders] = useState<any[]>([]);

  const load = async () => {
    const r = await fetch(`${BACKEND_URL}/api/orders`);
    const j = await r.json();
    setOrders(j.orders || []);
  };

  const create = async () => {
    const r = await fetch(`${BACKEND_URL}/api/orders`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ item: 'mobile', price: Math.round(Math.random()*100) })
    });
    await load();
  };

  useEffect(() => { load(); }, []);

  return (
    <SafeAreaView>
      <View style={{ padding: 16 }}>
        <Text style={{ fontSize: 18, fontWeight: 'bold' }}>Mobile Orders</Text>
        <Button title="Refresh" onPress={load} />
        <Button title="Create Order" onPress={create} />
        <FlatList data={orders} keyExtractor={(o) => o.id}
          renderItem={({ item }) => <Text>- {item.item} $ {item.price}</Text>} />
        <StatusBar style="auto" />
      </View>
    </SafeAreaView>
  );
}
