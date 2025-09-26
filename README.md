# Elastic ML Anomaly Detection Lab

Este lab demonstra como usar o **Machine Learning do Elastic** para detectar anomalias em métricas simuladas de uma aplicação.

---

## 🚀 Passos para rodar

### 1. Subir Elasticsearch
docker compose up -d elasticsearch

Acesse: [http://localhost:9200](http://localhost:9200)  
Usuário inicial: **elastic / changeme**

---

### 2. Configurar senha do usuário Kibana
O Kibana precisa do usuário `kibana_system`.  
Gere uma senha para ele dentro do container do Elasticsearch:

docker exec -it es-ml-lab bin/elasticsearch-reset-password -u kibana_system -i

Digite a nova senha (exemplo: `kibana123`) e guarde.

---

### 3. Atualizar `docker-compose.yml`
No serviço `kibana`, configure assim:

environment:
  - ELASTICSEARCH_HOSTS=["http://elasticsearch:9200"]
  - ELASTICSEARCH_USERNAME=kibana_system
  - ELASTICSEARCH_PASSWORD=kibana123

Agora suba o Kibana:

docker compose up -d kibana

Acesse: [http://localhost:5601](http://localhost:5601)

---

### 4. Gerar os dados simulados (100.000 docs em 09/2025)
Este lab já vem com um seeder em Python para rodar via Docker.  
Ele insere documentos em bulk (lotes de 1000) com **spikes de latência** e **status 500** em horários específicos.

docker compose run --rm seeder

Exemplo de saída:

📦 Lote 1/100 enviado (1,000/100,000 docs) — HTTP 200 — errors: no  
...  
✅ Concluído! Conferir no Kibana (Dev Tools): GET app-logs-2025-09/_count

---

### 5. Criar o Job de ML no Kibana
1. Vá em **Machine Learning > Anomaly Detection**  
2. Clique em **Create job**  
3. Selecione o índice `app-logs-2025-09`  
4. Configure:  
   - Campo de análise: `response_time`  
   - Bucket span: `1m`  
   - Influencers: `service`, `status_code`  
5. Salve e inicie o job

---

### 6. Visualizar Anomalias
- Gráfico do ML marca anomalias em **vermelho**  
- Clique no ponto para explorar os documentos relacionados  

---

### 7. Criar um Alerta
- Vá em **Stack Management > Rules and Connectors**  
- Crie regra para quando `anomaly_score > 75`  
- Integre com e-mail, Slack ou log no console  

---

## ⚠️ Aviso
Este lab é apenas para **uso educacional**.  
O bypass de certificados (`http` sem TLS) está ativado para simplificar — **não use em produção**.

---

👨‍💻 Autor: Rafa Silva – Observabilidade na Prática
