import { useEffect, useMemo, useState } from 'react';
import { createOrder, fetchOrders } from './api';

export default function App() {
  const [orders, setOrders] = useState<Array<{ id: string; item: string; price: number }>>([]);
  const [item, setItem] = useState('Coffee');
  const [price, setPrice] = useState(3.5);
  const [latencyMs, setLatencyMs] = useState<number | null>(null);
  const [errorCount, setErrorCount] = useState(0);

  async function load() {
    const t0 = performance.now();
    const route = '/api/orders';
    try {
      const list = await fetchOrders();
      setOrders(list);
      const duration = performance.now() - t0;
      setLatencyMs(duration);
      
      // Send metrics to backend
      sendMetric(route, duration, false);
    } catch (e) {
      setErrorCount((x) => x + 1);
      const duration = performance.now() - t0;
      sendMetric(route, duration, true);
    }
  }

  async function onCreate() {
    const t0 = performance.now();
    const route = '/api/orders';
    try {
      await createOrder(item, price);
      await load();
      const duration = performance.now() - t0;
      setLatencyMs(duration);
      
      // Send metrics to backend
      sendMetric(route, duration, false);
    } catch (e) {
      setErrorCount((x) => x + 1);
      const duration = performance.now() - t0;
      sendMetric(route, duration, true);
    }
  }

  function sendMetric(route: string, duration: number, error: boolean) {
    const backendUrl = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000';
    fetch(`${backendUrl}/api/metrics/frontend`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ route, duration, error }),
      keepalive: true,
    }).catch((err) => {
      console.warn('[Metrics] Failed to send metric:', err);
    });
  }

  useEffect(() => {
    load();
  }, []);

  const traffic = useMemo(() => orders.length, [orders]);

  return (
    <div style={{ fontFamily: 'Inter, system-ui, Arial', padding: 20 }}>
      <h1>Case Frontend</h1>

      <section>
        <h3>Golden Signals</h3>
        <ul>
          <li>Latency (ms): {latencyMs ? latencyMs.toFixed(1) : '—'}</li>
          <li>Traffic (orders count): {traffic}</li>
          <li>Errors: {errorCount}</li>
          <li>Saturation: see backend /metrics and Datadog infra metrics</li>
        </ul>
      </section>

      <section>
        <h3>Create order</h3>
        <label>
          Item
          <input value={item} onChange={(e) => setItem(e.target.value)} />
        </label>
        <label style={{ marginLeft: 12 }}>
          Price
          <input
            type="number"
            value={price}
            onChange={(e) => setPrice(Number(e.target.value))}
            step="0.1"
            min="0"
          />
        </label>
        <button style={{ marginLeft: 12 }} onClick={onCreate}>
          Create
        </button>
      </section>

      <section>
        <h3>Orders</h3>
        <ul>
          {orders.map((o) => (
            <li key={o.id}>
              #{o.id} – {o.item} (${o.price})
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
