import sys, math, random, time, http.client, json
from datetime import datetime

INDEX = "app-logs-2025-09"
ES_HOST = "elasticsearch"
ES_PORT = 9200
USER = "elastic"
PASS = "changeme"
DOCS = 100_000
BATCH_SIZE = 1_000  # ajuste se quiser acelerar
TIMEOUT = 120

# --- helpers ---------------------------------------------------------------

def rand_ts_09_2025():
    day = random.randint(1, 30)
    hour = random.randint(0, 23)
    minute = random.randint(0, 59)
    second = random.randint(0, 59)
    return f"2025-09-{day:02d}T{hour:02d}:{minute:02d}:{second:02d}Z"

SPIKE_WINDOWS = [(20001,22000),(50001,52000),(80001,81500)]
SPIKE_SLOTS = [(10,14),(18,21),(27,9)]  # (dia, hora)

def in_spike_range(i):
    return any(lo <= i <= hi for (lo,hi) in SPIKE_WINDOWS)

def spike_ts():
    day, hour = random.choice(SPIKE_SLOTS)
    minute = random.randint(0, 9)
    second = random.randint(0, 59)
    return f"2025-09-{day:02d}T{hour:02d}:{minute:02d}:{second:02d}Z"

SERVICES = ["api-gateway","auth-service","payment-service"]

def basic_auth_header(user, pwd):
    import base64
    token = base64.b64encode(f"{user}:{pwd}".encode()).decode()
    return {"Authorization": f"Basic {token}"}

# --- index setup -----------------------------------------------------------

def ensure_index(conn):
    mapping = {
        "settings": {"number_of_shards": 1, "number_of_replicas": 0, "refresh_interval": "60s"},
        "mappings": {
            "properties": {
                "@timestamp":   {"type": "date"},
                "service":      {"type": "keyword"},
                "status_code":  {"type": "integer"},
                "response_time":{"type": "integer"},
            }
        },
    }
    body = json.dumps(mapping)
    headers = {"Content-Type":"application/json"}
    headers.update(basic_auth_header(USER, PASS))
    conn.request("PUT", f"/{INDEX}", body=body, headers=headers)
    resp = conn.getresponse()
    resp.read()  # discard
    # 200/201/400 (already exists) são aceitáveis

def set_refresh_interval(conn, value):
    body = json.dumps({"refresh_interval": value})
    headers = {"Content-Type":"application/json"}
    headers.update(basic_auth_header(USER, PASS))
    conn.request("PUT", f"/{INDEX}/_settings", body=body, headers=headers)
    r = conn.getresponse(); r.read()

# --- bulk send -------------------------------------------------------------

def send_bulk(conn, ndjson_bytes):
    headers = {"Content-Type":"application/x-ndjson"}
    headers.update(basic_auth_header(USER, PASS))
    conn.request("POST", "/_bulk?refresh=false", body=ndjson_bytes, headers=headers)
    resp = conn.getresponse()
    data = resp.read()
    status = resp.status
    has_errors = b'"errors":true' in data
    return status, has_errors

# --- main -----------------------------------------------------------------

def main():
    print(f"🔧 Configurando índice: {INDEX}", flush=True)
    conn = http.client.HTTPConnection(ES_HOST, ES_PORT, timeout=TIMEOUT)
    ensure_index(conn)
    set_refresh_interval(conn, "60s")

    total_batches = math.ceil(DOCS / BATCH_SIZE)
    sb = []
    sent = 0
    batch_no = 0

    print(f"🚀 Iniciando ingestão BULK de {DOCS:,} documentos em lotes de {BATCH_SIZE}...", flush=True)

    for i in range(1, DOCS + 1):
        service = random.choice(SERVICES)
        status = 200 if random.random() < 0.82 else (400 if random.random() < 0.5 else 500)

        if in_spike_range(i):
            ts = spike_ts()
            if random.random() < 0.40:
                status = 500
            response = random.randint(900, 2699)
        else:
            ts = rand_ts_09_2025()
            if random.randint(0, 999) == 0:
                response = random.randint(1000, 2499)
            else:
                response = random.randint(50, 299)

        # NDJSON: action/meta + source
        sb.append(json.dumps({"index":{"_index": INDEX}}, separators=(",",":")))
        sb.append(json.dumps({
            "@timestamp": ts,
            "service": service,
            "status_code": status,
            "response_time": response
        }, separators=(",",":")))

        if i % BATCH_SIZE == 0:
            batch_no += 1
            payload = ("\n".join(sb) + "\n").encode()
            sb.clear()
            status_code, has_errors = send_bulk(conn, payload)
            sent = i
            print(f"📦 Lote {batch_no}/{total_batches} enviado ({sent:,}/{DOCS:,} docs) — HTTP {status_code} — errors: {'YES' if has_errors else 'no'}", flush=True)

    if sb:
        batch_no += 1
        payload = ("\n".join(sb) + "\n").encode()
        sb.clear()
        status_code, has_errors = send_bulk(conn, payload)
        sent = DOCS
        print(f"📦 Lote {batch_no}/{total_batches} enviado ({sent:,}/{DOCS:,} docs) — HTTP {status_code} — errors: {'YES' if has_errors else 'no'}", flush=True)

    set_refresh_interval(conn, "1s")
    print("✅ Concluído! Conferir no Kibana (Dev Tools): GET app-logs-2025-09/_count", flush=True)

if __name__ == "__main__":
    sys.exit(main())
