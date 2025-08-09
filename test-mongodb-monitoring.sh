#!/bin/bash
set -euo pipefail

echo "🔧 Generating MongoDB workload..."
ITERATIONS=${ITERATIONS:-50}
for i in $(seq 1 $ITERATIONS); do
  docker compose exec -T mongodb mongosh --quiet --eval 'db.workload.insertOne({ts: new Date(), n: Math.random()})' >/dev/null 2>&1 || true
  docker compose exec -T mongodb mongosh --quiet --eval 'db.workload.findOne()' >/dev/null 2>&1 || true
  if (( i % 10 == 0 )); then
    echo "  Insert/find cycle: $i"
  fi
  sleep 0.2
done

# Some updates & deletes
for i in $(seq 1 10); do
  docker compose exec -T mongodb mongosh --quiet --eval 'db.workload.updateMany({}, {$set:{u:Math.random()}})' >/dev/null 2>&1 || true
  docker compose exec -T mongodb mongosh --quiet --eval 'db.workload.deleteOne({})' >/dev/null 2>&1 || true
  sleep 0.5
 done

echo "✅ MongoDB workload generation complete. Check dashboard for updated metrics."
