#!/usr/bin/env bash
set -euo pipefail

INDEX="app-logs-2025-09"
ES_URL="http://localhost:9200"
USER="elastic"
PASS="changeme"
DOCS=100000
BATCH_SIZE=10000  # Tamanho do bulk
TMP_BULK="$(mktemp)"
RESP_FILE="$(mktemp)"

echo "🔧 Configurando índice: $INDEX"
curl -s -u "$USER:$PASS" -X PUT "$ES_URL/$INDEX" -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "refresh_interval": "60s"
  },
  "mappings": {
    "properties": {
      "@timestamp":   {"type": "date"},
      "service":      {"type": "keyword"},
      "status_code":  {"type": "integer"},
      "response_time":{"type": "integer"}
    }
  }
}' >/dev/null

echo "🚀 Iniciando ingestão BULK de $DOCS documentos em lotes de $BATCH_SIZE..."

# Função para gerar timestamp aleatório em 09/2025
rand_ts() {
  local day hour min sec
  day=$(( (RANDOM % 30) + 1 ))
  hour=$(( RANDOM % 24 ))
  min=$(( RANDOM % 60 ))
  sec=$(( RANDOM % 60 ))
  printf "2025-09-%02dT%02d:%02d:%02dZ" "$day" "$hour" "$min" "$sec"
}

# Faixas com picos simulados (spikes)
is_spike_range() {
  local i="$1"
  { [ "$i" -ge 20001 ] && [ "$i" -le 22000 ]; } || \
  { [ "$i" -ge 50001 ] && [ "$i" -le 52000 ]; } || \
  { [ "$i" -ge 80001 ] && [ "$i" -le 81500 ]; }
}

spike_ts() {
  case $((RANDOM % 3)) in
    0) day=10; hour=14 ;;
    1) day=18; hour=21 ;;
    2) day=27; hour=9  ;;
  esac
  min=$(( RANDOM % 10 ))
  sec=$(( RANDOM % 60 ))
  printf "2025-09-%02dT%02d:%02d:%02dZ" "$day" "$hour" "$min" "$sec"
}

# Serviços
services=("api-gateway" "auth-service" "payment-service")

total_batches=$(( (DOCS + BATCH_SIZE - 1) / BATCH_SIZE ))
batch_no=0
sent=0

for ((i=1; i<=DOCS; i++)); do
  service=${services[$RANDOM % ${#services[@]}]}

  # Status code (80% de chance de 200)
  if (( RANDOM % 100 < 82 )); then
    status=200
  else
    status=$(( (RANDOM % 2 == 0) ? 400 : 500 ))
  fi

  # Tempo e resposta com spikes
  if is_spike_range "$i"; then
    ts="$(spike_ts)"
    if (( RANDOM % 100 < 40 )); then status=500; fi
    response=$(( 900 + RANDOM % 1800 ))   # 900–2699 ms
  else
    ts="$(rand_ts)"
    if (( RANDOM % 1000 == 0 )); then
      response=$(( 1000 + RANDOM % 1500 ))  # pico raro
    else
      response=$(( 50 + RANDOM % 250 ))     # 50–299 ms
    fi
  fi

  printf '{"index":{"_index":"%s"}}\n' "$INDEX" >> "$TMP_BULK"
  printf '{"@timestamp":"%s","service":"%s","status_code":%d,"response_time":%d}\n' "$ts" "$service" "$status" "$response" >> "$TMP_BULK"

  # Envia lote
  if (( i % BATCH_SIZE == 0 )); then
    batch_no=$((batch_no+1))
    http_code=$(curl -s -o "$RESP_FILE" -w "%{http_code}" -u "$USER:$PASS" \
      -H 'Content-Type: application/x-ndjson' --data-binary "@$TMP_BULK" \
      "$ES_URL/_bulk?refresh=false")

    errors="no"
    if grep -q '"errors":true' "$RESP_FILE"; then errors="YES"; fi

    sent=$i
    printf "📦 Lote %d/%d enviado (%,d/%,d docs) — HTTP %s — errors: %s\n" \
      "$batch_no" "$total_batches" "$sent" "$DOCS" "$http_code" "$errors"
    : > "$TMP_BULK"
  fi
done

# Últimos docs
if [ -s "$TMP_BULK" ]; then
  batch_no=$((batch_no+1))
  http_code=$(curl -s -o "$RESP_FILE" -w "%{http_code}" -u "$USER:$PASS" \
    -H 'Content-Type: application/x-ndjson' --data-binary "@$TMP_BULK" \
    "$ES_URL/_bulk?refresh=false")
  errors="no"
  if grep -q '"errors":true' "$RESP_FILE"; then errors="YES"; fi
  sent=$DOCS
  printf "📦 Lote %d/%d enviado (%,d/%,d docs) — HTTP %s — errors: %s\n" \
    "$batch_no" "$total_batches" "$sent" "$DOCS" "$http_code" "$errors"
fi

# Ajusta refresh
curl -s -u "$USER:$PASS" -X PUT "$ES_URL/$INDEX/_settings" \
  -H 'Content-Type: application/json' -d '{"refresh_interval":"1s"}' >/dev/null

rm -f "$TMP_BULK" "$RESP_FILE"
echo "✅ Concluído! Verifique no Kibana ou use: GET app-logs-2025-09/_count"
