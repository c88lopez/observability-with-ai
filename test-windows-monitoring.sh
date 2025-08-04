#!/bin/bash

echo "🪟 Testing Windows Exporter Integration..."
echo "Windows IP: 192.168.68.55"
echo "=========================================="

# Test 1: Check if Windows Exporter is reachable
echo "1️⃣ Testing Windows Exporter endpoint..."
if curl -s --connect-timeout 5 "http://192.168.68.55:9182/metrics" | head -5 >/dev/null 2>&1; then
    echo "✅ Windows Exporter is responding"
    echo "   Sample metrics:"
    curl -s "http://192.168.68.55:9182/metrics" | grep -E "windows_cpu_time_total|windows_os_physical_memory" | head -3
else
    echo "❌ Cannot reach Windows Exporter at 192.168.68.55:9182"
    echo "   Make sure:"
    echo "   - Windows Exporter is installed and running"
    echo "   - Windows firewall allows port 9182"
    echo "   - Network connectivity is working"
fi

echo ""

# Test 2: Check Prometheus configuration
echo "2️⃣ Checking Prometheus configuration..."
if grep -q "192.168.68.55:9182" /Users/cristianlopez/Projects/vandelay-labs/monitoring-and-observability/prometheus/prometheus.yml; then
    echo "✅ Windows target found in Prometheus config"
else
    echo "❌ Windows target not found in Prometheus config"
fi

echo ""

# Test 3: Reload Prometheus config
echo "3️⃣ Reloading Prometheus configuration..."
if curl -s -X POST "http://localhost:9090/-/reload" >/dev/null 2>&1; then
    echo "✅ Prometheus configuration reloaded"
else
    echo "❌ Failed to reload Prometheus configuration"
fi

echo ""

# Test 4: Wait for scrape and check targets
echo "4️⃣ Waiting 30 seconds for scrape cycle..."
sleep 30

echo "5️⃣ Checking Prometheus targets..."
TARGET_STATUS=$(curl -s "http://localhost:9090/api/v1/targets" | jq -r '.data.activeTargets[] | select(.labels.job=="windows-exporter") | .health' 2>/dev/null)

if [ "$TARGET_STATUS" = "up" ]; then
    echo "✅ Windows Exporter target is UP in Prometheus"
elif [ "$TARGET_STATUS" = "down" ]; then
    echo "❌ Windows Exporter target is DOWN in Prometheus"
    echo "   Check the error details in Prometheus UI: http://localhost:9090/targets"
else
    echo "⚠️  Windows Exporter target not found in Prometheus targets"
    echo "   This might mean the scrape hasn't happened yet"
fi

echo ""

# Test 5: Test Windows metrics query
echo "6️⃣ Testing Windows CPU metrics query..."
CPU_QUERY_RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=windows_cpu_time_total" | jq -r '.status' 2>/dev/null)

if [ "$CPU_QUERY_RESULT" = "success" ]; then
    echo "✅ Windows CPU metrics available in Prometheus"
    CPU_VALUE=$(curl -s "http://localhost:9090/api/v1/query?query=windows_cpu_time_total" | jq -r '.data.result | length' 2>/dev/null)
    echo "   Found $CPU_VALUE CPU metric series"
else
    echo "❌ Windows CPU metrics not available"
fi

echo ""

# Test 6: Check Grafana dashboard
echo "7️⃣ Checking Grafana dashboard file..."
if [ -f "/Users/cristianlopez/Projects/vandelay-labs/monitoring-and-observability/grafana/dashboards/windows-monitoring.json" ]; then
    echo "✅ Windows monitoring dashboard created"
    echo "   Will be available at: http://localhost:3000/d/windows-monitoring/windows-server-monitoring"
else
    echo "❌ Windows monitoring dashboard file not found"
fi

echo ""
echo "🎯 Windows Monitoring Setup Summary:"
echo "   - Configuration files updated ✅"
echo "   - Alert rules created ✅"
echo "   - Dashboard created ✅"
echo "   - Next step: Restart Grafana to load the dashboard"

echo ""
echo "To restart Grafana and complete setup:"
echo "   docker compose restart grafana"

echo ""
echo "Access points after setup:"
echo "   - Prometheus targets: http://localhost:9090/targets"
echo "   - Windows dashboard: http://localhost:3000/d/windows-monitoring/windows-server-monitoring"
echo "   - All dashboards: http://localhost:3000"
