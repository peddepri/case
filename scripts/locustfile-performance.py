from locust import HttpUser, task, between
import json
import random

class OrderUser(HttpUser):
    wait_time = between(0.5, 2.0)  # Pausa entre requests
    
    def on_start(self):
        """Executado quando user inicia"""
        # Testar conectividade
        response = self.client.get("/healthz", catch_response=True)
        if response.status_code != 200:
            response.failure("Health check failed")
    
    @task(3)  # 60% dos requests
    def get_orders(self):
        """Buscar lista de orders"""
        with self.client.get("/api/orders", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    response.success()
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            else:
                response.failure(f"Got status {response.status_code}")
    
    @task(2)  # 40% dos requests  
    def create_order(self):
        """Criar nova order"""
        order_data = {
            "item": f"product-{random.randint(1, 1000)}",
            "price": round(random.uniform(10, 500), 2),
            "customer": f"user-{random.randint(1, 100)}"
        }
        
        with self.client.post("/api/orders", 
                             json=order_data, 
                             catch_response=True) as response:
            if response.status_code == 201:
                try:
                    data = response.json()
                    if "id" in data:
                        response.success()
                    else:
                        response.failure("No ID in response")
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            else:
                response.failure(f"Got status {response.status_code}")
    
    @task(1)  # 20% dos requests
    def health_check(self):
        """Health check"""
        with self.client.get("/healthz", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")

class StressUser(HttpUser):
    """User para testes de stress mais intensos"""
    wait_time = between(0.1, 0.5)  # Requests mais rápidos
    
    @task
    def rapid_requests(self):
        endpoints = ["/api/orders", "/healthz"]
        endpoint = random.choice(endpoints)
        
        with self.client.get(endpoint, catch_response=True) as response:
            if response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"Got {response.status_code}")
