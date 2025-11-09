import axios from 'axios';

const backendUrl = (import.meta as any).env.VITE_BACKEND_URL || 'http://localhost:3000';

export async function fetchOrders() {
  const res = await axios.get(`${backendUrl}/api/orders`);
  return res.data.orders as Array<{ id: string; item: string; price: number }>;
}

export async function createOrder(item: string, price: number) {
  const res = await axios.post(`${backendUrl}/api/orders`, { item, price });
  return res.data;
}
