# Elastic ML Anomaly Detection Lab

Este lab demonstra como usar o **Machine Learning do Elastic** para detectar anomalias em métricas simuladas de uma aplicação.

## 🚀 Passos para rodar

### 1. Subir o ambiente
```bash
docker-compose up -d
```

Aguarde alguns segundos até o Elasticsearch e Kibana estarem disponíveis:
- Elasticsearch: http://localhost:9200 (user: elastic / senha: changeme)
- Kibana: http://localhost:5601

### 2. Gerar os dados simulados
```bash
chmod +x data-generator.sh
./data-generator.sh
```

Isso vai criar o índice `app-logs-2025-09` com **100.000 documentos**, contendo:
- Datas no mês **09/2025**
- Serviços: `api-gateway`, `auth-service`, `payment-service`
- Status codes: `200`, `400`, `500`
- Response time: 50–300ms (normais) + picos de até 2000ms (anomalias)

### 3. Conferir os dados
No Kibana Dev Tools:
```json
GET app-logs-2025-09/_count
```

Deve retornar `100000`.

### 4. Criar o Job de ML
No Kibana:
1. Vá em **Machine Learning > Anomaly Detection**
2. Clique em **Create Job**
3. Selecione o índice `app-logs-2025-09`
4. Configure:
   - Campo de análise: `response_time`
   - Bucket span: `1m`
   - Influencers: `service`, `status_code`
5. Salve e inicie o job

### 5. Visualizar Anomalias
- No gráfico do ML, pontos **vermelhos** indicam anomalias críticas.
- Clique no ponto para explorar os documentos relacionados.

### 6. Criar um Alerta
- Vá em **Rules and Connectors**
- Crie uma regra de alerta para quando o `anomaly_score > 75`

---

## ⚠️ Aviso
Este lab é apenas para **uso educacional**. O `-k` (insecure) está ativado para bypass de certificados SSL, **não recomendado em produção**.

---

👨‍💻 Autor: Rafa Silva – Observabilidade na Prática
