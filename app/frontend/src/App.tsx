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
    try {
      const list = await fetchOrders();
      setOrders(list);
      setLatencyMs(performance.now() - t0);
    } catch (e) {
      setErrorCount((x) => x + 1);
    }
  }

  async function onCreate() {
    const t0 = performance.now();
    try {
      await createOrder(item, price);
      await load();
      setLatencyMs(performance.now() - t0);
    } catch (e) {
      setErrorCount((x) => x + 1);
    }
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
