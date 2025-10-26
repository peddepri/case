from locust import HttpUser, task, between
import json
import random
import time

class PerformanceUser(HttpUser):
    wait_time = between(0.5, 2.0)
    
    def on_start(self):
        """Executado quando o usuário inicia"""
        # Aguardar um pouco antes de começar
        time.sleep(random.uniform(0.1, 1.0))
        
        # Testar conectividade inicial
        response = self.client.get("/healthz", catch_response=True, name="startup_health_check")
        if response.status_code != 200:
            response.failure("Initial health check failed")
    
    @task(5)  # 50% dos requests
    def health_check(self):
        """Health check básico"""
        with self.client.get("/healthz", catch_response=True, name="health_check") as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if data.get("status") == "ok":
                        response.success()
                    else:
                        response.failure("Health check returned unexpected status")
                except json.JSONDecodeError:
                    response.failure("Invalid JSON in health check")
            else:
                response.failure(f"Health check failed with status {response.status_code}")
    
    @task(3)  # 30% dos requests
    def get_orders(self):
        """Buscar lista de orders"""
        with self.client.get("/api/orders", catch_response=True, name="get_orders") as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    response.success()
                except json.JSONDecodeError:
                    # Pode retornar HTML ou texto, que é aceitável
                    response.success()
            else:
                response.failure(f"Get orders failed with status {response.status_code}")
    
    @task(2)  # 20% dos requests  
    def create_order(self):
        """Criar nova order"""
        order_data = {
            "item": f"product-{random.randint(1, 1000)}",
            "price": round(random.uniform(10.99, 999.99), 2),
            "customer": f"user-{random.randint(1, 500)}",
            "timestamp": int(time.time())
        }
        
        with self.client.post("/api/orders", 
                             json=order_data, 
                             catch_response=True,
                             name="create_order") as response:
            if response.status_code in [200, 201]:
                try:
                    data = response.json()
                    response.success()
                except json.JSONDecodeError:
                    # Aceitar resposta mesmo sem JSON válido
                    response.success()
            else:
                response.failure(f"Create order failed with status {response.status_code}")

class StressUser(HttpUser):
    """Usuário para testes de stress mais intensos"""
    wait_time = between(0.1, 0.5)  # Requests mais rápidos
    
    @task(3)
    def rapid_health_checks(self):
        """Health checks rápidos"""
        with self.client.get("/healthz", catch_response=True, name="rapid_health") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Rapid health check failed: {response.status_code}")
    
    @task(1)
    def rapid_api_calls(self):
        """Chamadas rápidas para API"""
        with self.client.get("/api/orders", catch_response=True, name="rapid_api") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Rapid API call failed: {response.status_code}")

class SpikeUser(HttpUser):
    """Usuário para testes de pico de carga"""
    wait_time = between(0.05, 0.2)  # Muito rápido
    
    @task
    def spike_requests(self):
        """Requests de pico"""
        endpoints = ["/healthz", "/api/orders"]
        endpoint = random.choice(endpoints)
        
        with self.client.get(endpoint, catch_response=True, name=f"spike_{endpoint.replace('/', '_')}") as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Spike request failed: {response.status_code}")