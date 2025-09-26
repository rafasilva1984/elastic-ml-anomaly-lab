#!/usr/bin/env bash

INDEX="app-logs-2025-09"
ES_URL="http://localhost:9200"
USER="elastic"
PASS="changeme"

echo "🔄 Gerando 100.000 documentos no índice $INDEX ..."

# Cria o índice
curl -s -k -u $USER:$PASS -X PUT "$ES_URL/$INDEX" -H 'Content-Type: application/json' -d '{
  "mappings": {
    "properties": {
      "@timestamp": {"type": "date"},
      "service": {"type": "keyword"},
      "status_code": {"type": "integer"},
      "response_time": {"type": "integer"}
    }
  }
}'

# Inserindo documentos
for i in $(seq 1 100000); do
  # Data aleatória no mês 09/2025
  day=$(( (RANDOM % 30) + 1 ))
  hour=$((RANDOM % 24))
  minute=$((RANDOM % 60))
  second=$((RANDOM % 60))
  timestamp=$(printf "2025-09-%02dT%02d:%02d:%02dZ" $day $hour $minute $second)

  # Serviço aleatório
  services=("api-gateway" "auth-service" "payment-service")
  service=${services[$RANDOM % ${#services[@]}]}

  # Status code aleatório (mais chance de 200)
  if (( RANDOM % 100 < 80 )); then
    status=200
  else
    if (( RANDOM % 2 == 0 )); then
      status=400
    else
      status=500
    fi
  fi

  # Response time (com picos ocasionais)
  if (( RANDOM % 1000 == 0 )); then
    response=$((1000 + RANDOM % 1500))  # pico
  else
    response=$((50 + RANDOM % 250))     # normal
  fi

  doc="{ \"@timestamp\": \"$timestamp\", \"service\": \"$service\", \"status_code\": $status, \"response_time\": $response }"

  echo "$doc" | curl -s -k -u $USER:$PASS -X POST "$ES_URL/$INDEX/_doc" -H 'Content-Type: application/json' -d @-
done

echo "✅ Dados enviados para o índice $INDEX"
