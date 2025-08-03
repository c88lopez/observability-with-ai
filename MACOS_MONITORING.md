# macOS Monitoring Setup

## The Problem
Node Exporter in Docker on macOS monitors the Docker Desktop Linux VM, not the actual macOS host system. This is why you see low resource usage - it's monitoring the VM, not your MacBook.

## Solutions

### Option 1: Native Node Exporter (Recommended for macOS)
Install Node Exporter directly on macOS using Homebrew:

```bash
# Install Node Exporter natively
brew install node_exporter

# Run Node Exporter as a service
brew services start node_exporter
# OR run manually:
# node_exporter --web.listen-address=":9100"
```

### Option 2: Docker with Host Network (Limited)
Keep the Docker setup but understand limitations:

```yaml
# This monitors Docker Desktop VM, not macOS host
node-exporter:
  image: prom/node-exporter:latest
  # ... existing config
```

### Option 3: Alternative Exporters for macOS
Use macOS-specific monitoring tools:

```bash
# Install macOS system monitor
brew install --cask stats
# Or use native macOS tools with custom exporters
```

## Recommended Setup for Development

For the best monitoring experience on macOS:

1. **Keep Docker Node Exporter** for learning/development
2. **Add native Node Exporter** for actual host monitoring
3. **Configure both in Prometheus** as different jobs

## Configuration Changes Needed

Update Prometheus to scrape both:
- Docker Node Exporter: `node-exporter:9100` (VM metrics)
- Native Node Exporter: `localhost:9100` (macOS metrics)

## Next Steps

1. Decide which approach you prefer
2. Install native Node Exporter if desired
3. Update Prometheus configuration accordingly
4. Create separate dashboards or panels for each

The current setup is working correctly - it's just monitoring the Docker VM instead of macOS!
