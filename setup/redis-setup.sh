#!/bin/bash
# redis-setup.sh
# Wait for Redis to be reachable (best-effort).
set -euo pipefail

echo "Waiting for Redis..."
REDIS_TIMEOUT=30
REDIS_COUNTER=0
while ! nc -z "${REDIS_HOST}" "${REDIS_PORT}" 2>/dev/null; do
  echo "Waiting for Redis... (${REDIS_COUNTER}/${REDIS_TIMEOUT})"
  sleep 2
  REDIS_COUNTER=$((REDIS_COUNTER + 1))
  if [ "${REDIS_COUNTER}" -ge "${REDIS_TIMEOUT}" ]; then
    echo "Redis not available after ${REDIS_TIMEOUT} attempts, continuing without Redis cache..."
    break
  fi
done

if nc -z "${REDIS_HOST}" "${REDIS_PORT}" 2>/dev/null; then
  echo "Redis is ready!"
else
  echo "Starting without Redis cache..."
fi