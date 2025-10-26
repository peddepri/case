from locust import HttpUser, task, between
import json

class BackendUser(HttpUser):
    wait_time = between(1, 3)
    
    @task(2)
    def health_check(self):
        """Testar endpoint de health check"""
        self.client.get("/healthz")
    
    @task(1)
    def get_orders(self):
        """Testar endpoint de orders"""
        self.client.get("/api/orders")