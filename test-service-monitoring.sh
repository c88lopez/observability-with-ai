#!/bin/bash

echo "🚀 Starting Service Monitoring Setup..."
echo "======================================"

# Start all services
echo "1️⃣ Starting all services with Docker Compose..."
docker compose up -d

echo ""
echo "2️⃣ Waiting for services to initialize (readiness checks)..."

# Configurable timeout / interval
MAX_ATTEMPTS=${MAX_ATTEMPTS:-60}
SLEEP_INTERVAL=${SLEEP_INTERVAL:-1}

wait_for() {
    local name="$1"; shift
    local cmd="$*"
    local attempt=1
    while true; do
        if eval "$cmd" >/dev/null 2>&1; then
            echo "   ✅ $name ready (attempt $attempt)"
            return 0
        fi
        if [ $attempt -ge $MAX_ATTEMPTS ]; then
            echo "   ❌ Timeout waiting for $name after $MAX_ATTEMPTS attempts" >&2
            return 1
        fi
        if [ $attempt -eq 1 ]; then
            echo "   ⏳ Waiting for $name..."
        fi
        attempt=$((attempt+1))
        sleep "$SLEEP_INTERVAL"
    done
}

# Core service readiness
wait_for "PostgreSQL" "docker compose exec -T postgres pg_isready -U postgres"
wait_for "PostgreSQL Exporter" "curl -fsS http://localhost:9187/metrics"
wait_for "Redis" "docker compose exec -T redis redis-cli ping | grep -q PONG"
wait_for "Redis Exporter" "curl -fsS http://localhost:9121/metrics"
wait_for "RabbitMQ Management" "curl -fsS -u admin:admin http://localhost:15672/api/overview"
wait_for "RabbitMQ Exporter" "curl -fsS http://localhost:9419/metrics"
wait_for "Prometheus" "curl -fsS http://localhost:9090/-/ready"

echo ""
echo "3️⃣ Testing service endpoints..."

# Test PostgreSQL
echo "🐘 Testing PostgreSQL..."
if docker compose exec -T postgres psql -U postgres -d monitoring_demo -c "SELECT COUNT(*) FROM app_monitoring.users;" >/dev/null 2>&1; then
    echo "✅ PostgreSQL is responding"
    USER_COUNT=$(docker compose exec -T postgres psql -U postgres -d monitoring_demo -t -c "SELECT COUNT(*) FROM app_monitoring.users;" | xargs)
    echo "   Users in database: $USER_COUNT"
else
    echo "❌ PostgreSQL connection failed"
fi

# Test PostgreSQL Exporter
echo "📊 Testing PostgreSQL Exporter..."
if curl -s http://localhost:9187/metrics | head -5 >/dev/null 2>&1; then
    echo "✅ PostgreSQL Exporter is responding"
    METRIC_COUNT=$(curl -s http://localhost:9187/metrics | grep -c "^pg_")
    echo "   PostgreSQL metrics available: $METRIC_COUNT"
else
    echo "❌ PostgreSQL Exporter not responding"
fi

echo ""

# Test Redis
echo "🔴 Testing Redis..."
if docker compose exec -T redis redis-cli ping >/dev/null 2>&1; then
    echo "✅ Redis is responding"
    # Set some test data
    docker compose exec -T redis redis-cli set test_key "monitoring_demo" >/dev/null 2>&1
    docker compose exec -T redis redis-cli expire test_key 300 >/dev/null 2>&1
    echo "   Test key set with 5-minute expiration"
else
    echo "❌ Redis connection failed"
fi

# Test Redis Exporter
echo "📊 Testing Redis Exporter..."
if curl -s http://localhost:9121/metrics | head -5 >/dev/null 2>&1; then
    echo "✅ Redis Exporter is responding"
    METRIC_COUNT=$(curl -s http://localhost:9121/metrics | grep -c "^redis_")
    echo "   Redis metrics available: $METRIC_COUNT"
else
    echo "❌ Redis Exporter not responding"
fi

echo ""

# Test RabbitMQ
echo "🐰 Testing RabbitMQ..."
if curl -s -u admin:admin http://localhost:15672/api/overview >/dev/null 2>&1; then
    echo "✅ RabbitMQ Management is responding"
    # Create a test queue
    curl -s -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/monitoring_test \
         -H "content-type:application/json" \
         -d '{"durable":false}' >/dev/null 2>&1
    echo "   Test queue 'monitoring_test' created"
else
    echo "❌ RabbitMQ Management not responding"
fi

# Test RabbitMQ Exporter
echo "📊 Testing RabbitMQ Exporter..."
if curl -s http://localhost:9419/metrics | head -5 >/dev/null 2>&1; then
    echo "✅ RabbitMQ Exporter is responding"
    METRIC_COUNT=$(curl -s http://localhost:9419/metrics | grep -c "^rabbitmq_")
    echo "   RabbitMQ metrics available: $METRIC_COUNT"
else
    echo "❌ RabbitMQ Exporter not responding"
fi

echo ""

# Test Prometheus targets
echo "4️⃣ Checking Prometheus targets (waiting for first successful scrape)..."

# Wait until Prometheus has scraped postgres-exporter at least once (metric present)
SCRAPE_WAIT_ATTEMPTS=${SCRAPE_WAIT_ATTEMPTS:-30}
for i in $(seq 1 $SCRAPE_WAIT_ATTEMPTS); do
    if curl -s 'http://localhost:9090/api/v1/query?query=pg_up' | jq -e '.data.result[0].value[1]' >/dev/null 2>&1; then
        break
    fi
    [ $i -eq 1 ] && echo "   ⏳ Waiting for initial postgres metrics (pg_up)..."
    sleep 1
done

POSTGRES_STATUS=$(curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job=="postgres-exporter") | .health' 2>/dev/null)
REDIS_STATUS=$(curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job=="redis-exporter") | .health' 2>/dev/null)
RABBITMQ_STATUS=$(curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job=="rabbitmq-exporter") | .health' 2>/dev/null)

echo "📊 Prometheus Target Status:"
echo "   PostgreSQL Exporter: ${POSTGRES_STATUS:-unknown}"
echo "   Redis Exporter: ${REDIS_STATUS:-unknown}" 
echo "   RabbitMQ Exporter: ${RABBITMQ_STATUS:-unknown}"

echo ""

# Generate some test activity
echo "5️⃣ Generating test activity..."

# PostgreSQL activity
echo "🐘 Generating PostgreSQL activity..."
for i in {1..5}; do
    docker compose exec -T postgres psql -U postgres -d monitoring_demo -c "SELECT app_monitoring.simulate_activity();" >/dev/null 2>&1
    sleep 1
done
echo "   Generated 5 simulated database transactions"

# Redis activity
echo "🔴 Generating Redis activity..."
for i in {1..10}; do
    docker compose exec -T redis redis-cli set "test_key_$i" "value_$i" >/dev/null 2>&1
    docker compose exec -T redis redis-cli get "test_key_$i" >/dev/null 2>&1
    docker compose exec -T redis redis-cli expire "test_key_$i" 600 >/dev/null 2>&1
done
echo "   Generated 10 Redis operations (set/get/expire)"

# RabbitMQ activity
echo "🐰 Generating RabbitMQ activity..."
for i in {1..5}; do
    curl -s -u admin:admin -X POST http://localhost:15672/api/exchanges/%2F/amq.default/publish \
         -H "content-type:application/json" \
         -d "{\"properties\":{},\"routing_key\":\"monitoring_test\",\"payload\":\"Test message $i\",\"payload_encoding\":\"string\"}" >/dev/null 2>&1
done
echo "   Published 5 test messages to queue"

echo ""

# Show service URLs
echo "6️⃣ Service Access URLs:"
echo "📊 Monitoring Dashboards:"
echo "   - Grafana: http://localhost:3000 (admin/admin)"
echo "   - Prometheus: http://localhost:9090"
echo "   - Alertmanager: http://localhost:9093"
echo ""
echo "🗄️ Service Management:"
echo "   - RabbitMQ Management: http://localhost:15672 (admin/admin)"
echo "   - PostgreSQL: localhost:5432 (postgres/postgres)"
echo "   - Redis: localhost:6379"
echo ""
echo "📈 Exporter Metrics:"
echo "   - PostgreSQL Exporter: http://localhost:9187/metrics"
echo "   - Redis Exporter: http://localhost:9121/metrics"
echo "   - RabbitMQ Exporter: http://localhost:9419/metrics"

echo ""
echo "🎯 New Dashboard Available:"
echo "   Service Monitoring: http://localhost:3000/d/service-monitoring/service-monitoring-postgresql-redis-rabbitmq"
echo "   PostgreSQL Overview: http://localhost:3000/d/postgres-overview/postgresql-overview"

echo ""
echo "✅ Service monitoring setup complete!"
echo "   Monitor service health, performance, and activity across all three platforms."
