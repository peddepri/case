import random
from locust import FastHttpUser, task, between

BACKEND_BASE = "/api/orders"

class OrdersUser(FastHttpUser):
    wait_time = between(0.1, 1.5)

    @task(3)
    def list_orders(self):
        self.client.get(BACKEND_BASE)

    @task(1)
    def create_order(self):
        item = random.choice(["book","pen","notebook","bag"])    
        price = round(random.uniform(1, 100), 2)
        with self.client.post(BACKEND_BASE, json={"item": item, "price": price}, catch_response=True) as resp:
            if resp.status_code not in (201, 500, 400):
                resp.failure(f"Unexpected status {resp.status_code}")
