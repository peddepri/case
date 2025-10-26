FROM python:3.11-slim

# Instalar Locust e dependências
RUN pip install locust requests

# Criar diretório de trabalho
WORKDIR /locust

# Criar arquivo de teste Locust
COPY locustfile.py .

# Expor porta do Locust
EXPOSE 8089

# Comando para iniciar Locust
CMD ["locust", "--host=http://backend.case.svc.cluster.local:3000"]