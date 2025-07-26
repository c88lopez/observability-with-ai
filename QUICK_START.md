# Quick Start Guide

## Prerequisites
- Docker and Docker Compose installed
- Basic understanding of Prometheus and Grafana
- Access to systems you want to monitor

## Getting Started (15 minutes)

### Step 1: Clone and Setup
```bash
# Navigate to your project directory
cd /Users/cristianlopez/Projects/vandelay-labs/monitoring-and-observability

# Create the basic directory structure
mkdir -p {prometheus/{rules,targets},grafana/{provisioning/{datasources,dashboards},dashboards},alertmanager,exporters}
```

### Step 2: Create Basic Docker Compose Stack
Create `docker-compose.yml` with core monitoring services

### Step 3: Launch the Stack
```bash
# Start all services
docker-compose up -d

# Check services are running
docker-compose ps

# View logs if needed
docker-compose logs -f prometheus
```

### Step 4: Access the Interfaces
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

### Step 5: Add Your First Monitor Target
Edit `prometheus/targets/hosts.yml` to add your first monitoring target

## Next Steps After Quick Start

### Immediate Actions (Day 1)
1. [ ] Verify all services are accessible
2. [ ] Change default Grafana password
3. [ ] Add your local machine as monitoring target
4. [ ] Import a basic host monitoring dashboard
5. [ ] Test basic alerting functionality

### Week 1 Goals
1. [ ] Monitor 2-3 host machines
2. [ ] Set up basic database monitoring (if available)
3. [ ] Create your first custom dashboard
4. [ ] Configure alert notifications (email/Slack)
5. [ ] Document your specific environment setup

### Customization Points
- **Retention Period**: Adjust based on your storage and needs
- **Scrape Intervals**: Balance between data granularity and resource usage
- **Alert Thresholds**: Tune based on your environment's normal behavior
- **Dashboard Layouts**: Modify based on your team's preferences
- **Service Discovery**: Add your specific services and applications

## Common First Tasks

### Add a New Service Type
1. Find or create appropriate exporter
2. Add scrape config to `prometheus/prometheus.yml`
3. Create alert rules in `prometheus/rules/`
4. Build dashboard in Grafana
5. Test alerting and notification flow

### Modify Alert Thresholds
1. Edit relevant file in `prometheus/rules/`
2. Reload Prometheus configuration
3. Test alert firing and resolution
4. Update documentation

### Create Custom Dashboard
1. Use Grafana UI to build dashboard
2. Export dashboard JSON
3. Save to `grafana/dashboards/`
4. Add to provisioning configuration
5. Test auto-deployment

## Troubleshooting Quick Reference

### Service Won't Start
- Check Docker logs: `docker-compose logs [service-name]`
- Verify port conflicts: `netstat -tulpn | grep [port]`
- Check configuration syntax
- Ensure proper file permissions

### Metrics Not Appearing
- Verify exporter is running and accessible
- Check Prometheus targets page (Status → Targets)
- Validate scrape configuration syntax
- Test exporter endpoint manually: `curl http://target:port/metrics`

### Alerts Not Firing
- Check alert rule syntax in Prometheus UI (Alerts page)
- Verify Alertmanager configuration
- Test notification channels
- Check alert rule evaluation frequency

## Configuration Examples

### Basic Host Monitoring Target
```yaml
# prometheus/targets/hosts.yml
- targets:
    - 'localhost:9100'    # Node exporter on local machine
  labels:
    environment: 'development'
    team: 'platform'
```

### Simple Alert Rule
```yaml
# prometheus/rules/hosts.yml
groups:
  - name: host-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% on {{ $labels.instance }}"
```

## Development Workflow

### Making Changes
1. **Configuration Changes**: Edit files, restart affected services
2. **Dashboard Changes**: Edit in Grafana UI, export JSON, commit to repo
3. **Alert Changes**: Edit rule files, reload Prometheus config
4. **New Services**: Add exporter, update configs, create dashboards

### Testing Changes
1. **Local Testing**: Use Docker Compose for rapid iteration
2. **Configuration Validation**: Use Prometheus config check tools
3. **Dashboard Testing**: Verify with sample data and different time ranges
4. **Alert Testing**: Trigger conditions to verify alert flow

### Version Control
- Commit all configuration files
- Tag releases for stable configurations
- Use branching for experimental features
- Document changes in commit messages

This guide gets you up and running quickly while maintaining flexibility for your specific monitoring needs!
