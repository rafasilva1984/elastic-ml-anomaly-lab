# Elastic ML Anomaly Detection Lab

Este lab demonstra como usar o **Machine Learning do Elastic** para detectar anomalias em métricas simuladas de uma aplicação.

---

## 🚀 Passos para rodar

### 1. Subir Elasticsearch
Comando:
docker compose up -d elasticsearch

Acesse: http://localhost:9200  
Usuário inicial: elastic / changeme

---

### 2. Configurar senha do usuário Kibana
O Kibana precisa do usuário kibana_system.  
Gere uma senha para ele dentro do container do Elasticsearch:

docker exec -it es-ml-lab bin/elasticsearch-reset-password -u kibana_system -i

Digite a nova senha (exemplo: kibana123) e guarde.

---

### 3. Atualizar docker-compose.yml
No serviço kibana, configure assim:

environment:
  - ELASTICSEARCH_HOSTS=["http://elasticsearch:9200"]
  - ELASTICSEARCH_USERNAME=kibana_system
  - ELASTICSEARCH_PASSWORD=kibana123

Agora suba o Kibana:

docker compose up -d kibana

Acesse: http://localhost:5601

---

### 4. Gerar os dados simulados (100.000 docs em 09/2025)
Este lab já vem com um seeder em Python para rodar via Docker.  
Ele insere documentos em bulk (lotes de 1000) com spikes de latência e status 500 em horários específicos.

Comando:
docker compose run --rm seeder

Exemplo de saída:
📦 Lote 1/100 enviado (1,000/100,000 docs) — HTTP 200 — errors: no  
...  
✅ Concluído! Conferir no Kibana (Dev Tools): GET app-logs-2025-09/_count

---

### 5. Criar o Job de ML no Kibana

O Kibana traz um wizard (assistente passo a passo) para criação dos jobs de Machine Learning.  
Vamos criar nosso primeiro job de Detecção de Anomalias com base no campo response_time.

**Passo 1 – Acessar a tela de Machine Learning**  
No menu lateral do Kibana, clique em:  
Analytics > Machine Learning > Anomaly Detection

**Passo 2 – Criar um novo Job**  
Na tela de Anomaly Detection, clique em:  
Create job > Select index or search  
Escolha o índice: app-logs-2025-09

**Passo 3 – Escolher o tipo de Job**  
Aqui aparecem várias opções:  
- Single metric job → Monitora uma única métrica, ex: tempo de resposta.  
- Multi-metric job → Monitora várias métricas juntas.  
- Population job → Detecta desvios em grupos.  
- Advanced job → Total flexibilidade.  

👉 Para este laboratório, use: Single metric job.

**Passo 4 – Configurar o detector**  
- Field to analyze → response_time  
- Function → mean  
- Bucket span → 1m  

Clique em Next.

**Passo 5 – Configurar influenciadores**  
Selecione:  
- service  
- status_code  

Clique em Next.

**Passo 6 – Configurações adicionais**  
- Nome → ml_response_time_job  
- Descrição → Job para detectar anomalias de tempo de resposta em setembro/2025  

Clique em Next.

**Passo 7 – Resumo e criação**  
Revise:  
- Tipo: Single metric  
- Campo: mean(response_time)  
- Bucket span: 1m  
- Influencers: service, status_code  

Clique em Create job.

**Passo 8 – Rodar o Job**  
O job começa a processar os dados.  
Você verá uma barra de progresso.

**Passo 9 – Visualizar resultados**  
Após o processamento:  
- Gráfico mostra o comportamento do response_time  
- Pontos coloridos:  
  - Verde = normal  
  - Amarelo = leve anomalia  
  - Laranja = significativa  
  - Vermelho = crítica  

Clique em pontos vermelhos para detalhes:  
- Score (0 a 100)  
- Documentos relacionados  
- Serviços influenciadores

Resumo: Criamos um Single Metric Job monitorando mean(response_time).  
Variações:  
- Multi-metric job → response_time + status_code  
- Population job → comparar serviços entre si  
- Advanced job → configurações manuais

---

### 6. Visualizar Anomalias
O gráfico do ML mostra anomalias em vermelho.  
Clique no ponto para ver os documentos.

---

### 7. Criar um Alerta
No Kibana:  
- Vá em Stack Management > Rules and Connectors  
- Crie regra para anomaly_score > 75  
- Configure ação: e-mail, Slack ou log no console

---

## ⚠️ Aviso
Este lab é apenas para uso educacional.  
O bypass de certificados (http sem TLS) está ativado para simplificar — não use em produção.

---

👨‍💻 Autor: Rafa Silva – Observabilidade na Prática
