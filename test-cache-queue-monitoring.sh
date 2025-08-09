#!/bin/bash
set -euo pipefail

echo "🔍 Verifying Cache & Message Queue Monitoring (Phase 2.2)"

REQUIRED_CONTAINERS=(redis redis-exporter rabbitmq rabbitmq-exporter prometheus)
MISSING=0
for c in "${REQUIRED_CONTAINERS[@]}"; do
  if ! docker compose ps --format '{{.Name}}' | grep -q "^${c}$"; then
    echo "❌ Container $c not running"
    MISSING=1
  else
    echo "✅ Container $c running"
  fi
done
if [ $MISSING -eq 1 ]; then
  echo "Attempting to start missing containers..."
  docker compose up -d redis redis-exporter rabbitmq rabbitmq-exporter >/dev/null
  sleep 3
fi

fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; }

prom_query() {
  local q="$1"
  curl -s --fail "http://localhost:9090/api/v1/query?query=${q}" | jq -e '.data.result | length > 0' >/dev/null
}

# Metric presence
prom_query 'redis_up==1' && pass 'redis_up metric present' || fail 'redis_up metric missing'
prom_query 'rabbitmq_up==1' && pass 'rabbitmq_up metric present' || fail 'rabbitmq_up metric missing'
prom_query 'redis_connected_clients' && pass 'redis_connected_clients present' || fail 'redis_connected_clients missing'
prom_query 'rabbitmq_connections' && pass 'rabbitmq_connections present' || fail 'rabbitmq_connections missing'
prom_query 'rate(redis_commands_processed_total[5m])' && pass 'redis command rate available' || fail 'redis command rate missing'
prom_query 'rate(rabbitmq_queue_messages_published_total[5m])' && pass 'rabbitmq publish rate available' || fail 'rabbitmq publish rate missing'

# Alert rules loaded
RULES_JSON=$(curl -s http://localhost:9090/api/v1/rules)
echo "$RULES_JSON" | jq -e '.data.groups[] | select(.name=="redis-alerts")' >/dev/null && pass 'redis alert group loaded' || fail 'redis alert group missing'
echo "$RULES_JSON" | jq -e '.data.groups[] | select(.name=="rabbitmq-alerts")' >/dev/null && pass 'rabbitmq alert group loaded' || fail 'rabbitmq alert group missing'

# Basic threshold evaluation sanity (ensure expressions evaluate)
prom_query '(redis_memory_used_bytes) > 0' && pass 'redis memory metric sane' || fail 'redis memory metric not >0'
prom_query '(rabbitmq_node_mem_used) > 0' && pass 'rabbitmq memory metric sane' || fail 'rabbitmq memory metric not >0'

cat <<EOF

Summary:
  All critical Phase 2.2 metrics and alert rule groups are present.
  Dashboards rely on these metrics; verify visually at:
    Redis:     http://localhost:3000/d/redis-overview/redis-overview
    RabbitMQ:  http://localhost:3000/d/rabbitmq-overview/rabbitmq-overview

EOF
