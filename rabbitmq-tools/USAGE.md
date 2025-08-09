# rabbitmq-tool

Unified RabbitMQ load & benchmarking helper for local monitoring demos.

## Features
- Produce messages with configurable concurrency, payload size, batch logging
- Consume messages with manual or auto acknowledgements and optional prefetch
- Single binary for both roles (`--mode=produce|consume`)
- Deterministic randomness support via `RANDOM_SEED`
- External configuration of connection via `RABBITMQ_URL` or `--url`

## Installation / Build
```bash
make -C rabbitmq-tools build
# or
cd rabbitmq-tools && go build -o rabbitmq-tool .
```

## Quick Start
Produce 10k messages using 5 publishers and 512‑byte payloads:
```bash
./rabbitmq-tool --mode=produce --queue=loadq --count=10000 --concurrency=5 --size=512
```
Consume them with manual acks and prefetch 50:
```bash
./rabbitmq-tool --mode=consume --queue=loadq --count=10000 --prefetch=50 --ack=true
```
Consume indefinitely (stream):
```bash
./rabbitmq-tool --mode=consume --queue=loadq --count=0 --ack=false
```

## Flags
| Flag | Mode | Description | Default |
|------|------|-------------|---------|
| `--mode` | both | `produce` or `consume` (aliases: pub,publisher,sub,consumer) | produce |
| `--queue` | both | Queue name (created if producing) | test_load_queue |
| `--count` | both | Produce: msgs to publish. Consume: msgs to read (0=infinite) | 10000 |
| `--url` | both | AMQP URL (overridden by env `RABBITMQ_URL`) | amqp://admin:admin@localhost:5672/ |
| `--exchange` | produce | Exchange name (blank=default) | (blank) |
| `--routing` | produce | Routing key (default=queue if blank) | (queue) |
| `--batch` | produce | Progress log interval | 1000 |
| `--size` | produce | Payload size padding (bytes) | 0 (dynamic small) |
| `--concurrency` | produce | Parallel publisher goroutines | 1 |
| `--ack` | consume | Manual acks (set `--ack=false` for auto-ack) | true |
| `--prefetch` | consume | Prefetch (QoS) count (0 = unlimited) | 0 |
| `--help` | both | Show embedded help and exit | n/a |

## Environment Variables
| Variable | Purpose |
|----------|---------|
| `RABBITMQ_URL` | Overrides `--url` |
| `RANDOM_SEED` | Fixed seed for reproducible payload sequence |

## Exit Codes
- 0 success / normal completion
- 1 fatal setup or publish/consume error

## Performance Notes
- For higher throughput, increase `--concurrency` (publishers) and optionally raise RabbitMQ connection limits.
- For consumers, tune `--prefetch` based on message size and processing latency.
- Payload padding (`--size`) affects network & memory—match realistic workloads.

## Examples
| Scenario | Command |
|----------|---------|
| High throughput small msgs | `./rabbitmq-tool --mode=produce --queue=bench --count=50000 --concurrency=8 --batch=500` |
| Large payload test (2KB) | `./rabbitmq-tool --mode=produce --queue=large --count=2000 --size=2048` |
| Infinite consumer w/ prefetch | `./rabbitmq-tool --mode=consume --queue=stream --count=0 --prefetch=100 --ack=false` |

## Make Targets
From repo root:
```bash
make -C rabbitmq-tools build        # build binary
make -C rabbitmq-tools run-producer # sample 1k produce
make -C rabbitmq-tools run-consumer # sample 1k consume
make -C rabbitmq-tools clean        # remove binary
```

## Future Ideas
- Optional rate limiting (msgs/sec)
- JSON summary output for automation
- Prometheus exporter mode
- TLS / SASL options

---
Generated for internal observability lab usage.
