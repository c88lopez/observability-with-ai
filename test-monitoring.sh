#!/bin/bash

# Phase 1.2 Monitoring Stack Test Script
echo "🧪 Testing Monitoring Stack - Phase 1.2"
echo "=========================================="

# Test 1: Check if all services are running
echo "1️⃣ Checking Docker services..."
docker compose ps
echo ""

# Test 2: Check Prometheus targets
echo "2️⃣ Checking Prometheus targets..."
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' 2>/dev/null || echo "jq not available, using basic curl..."
echo ""

# Test 3: Test Node Exporter metrics
echo "3️⃣ Testing Node Exporter metrics..."
METRICS_COUNT=$(curl -s http://localhost:9100/metrics | wc -l)
echo "Node Exporter is exposing $METRICS_COUNT metrics"
echo "📝 NOTE: On macOS, this monitors Docker Desktop VM, not macOS host"
echo "📝 For actual macOS monitoring, install: brew install node_exporter"
echo ""

# Test 4: Test Prometheus query for CPU usage
echo "4️⃣ Testing Prometheus query (CPU usage)..."
CPU_QUERY="100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
curl -s "http://localhost:9090/api/v1/query?query=$CPU_QUERY" | jq -r '.data.result[] | "CPU Usage on \(.metric.instance): \(.value[1])%"' 2>/dev/null || echo "Query sent successfully (jq not available for parsing)"
echo ""

# Test 5: Check alert rules status
echo "5️⃣ Checking alert rules..."
ALERT_COUNT=$(curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[0].rules | length' 2>/dev/null || echo "unknown")
echo "Loaded $ALERT_COUNT alert rules"
echo ""

# Test 6: Test Grafana accessibility
echo "6️⃣ Testing Grafana accessibility..."
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)
if [ "$GRAFANA_STATUS" = "200" ]; then
    echo "✅ Grafana is accessible (HTTP $GRAFANA_STATUS)"
else
    echo "❌ Grafana is not accessible (HTTP $GRAFANA_STATUS)"
fi
echo ""

# Test 7: Test Alertmanager
echo "7️⃣ Testing Alertmanager..."
ALERTMANAGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy)
if [ "$ALERTMANAGER_STATUS" = "200" ]; then
    echo "✅ Alertmanager is healthy (HTTP $ALERTMANAGER_STATUS)"
else
    echo "❌ Alertmanager is not healthy (HTTP $ALERTMANAGER_STATUS)"
fi
echo ""

echo "🎯 Phase 1.2 Test Summary:"
echo "- All core services should be running"
echo "- Node Exporter should be collecting metrics"
echo "- Prometheus should be scraping targets successfully"
echo "- Alert rules should be loaded and evaluating"
echo "- Grafana should be accessible at http://localhost:3000"
echo "- Alertmanager should be healthy"
echo ""
echo "Next: Check the Host Overview Dashboard in Grafana!"
echo "URL: http://localhost:3000/d/host-overview/host-overview-dashboard"
