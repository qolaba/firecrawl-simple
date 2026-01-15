#!/bin/bash
set -e

echo "Starting Firecrawl Unified Service..."

# Set default ports if not provided
PUPPETEER_SERVICE_PORT=${PUPPETEER_SERVICE_PORT:-3000}
API_PORT=${PORT:-3002}

# Function to handle shutdown
shutdown() {
    echo "Shutting down all services..."
    kill $(jobs -p) 2>/dev/null || true
    exit 0
}

trap shutdown SIGINT SIGTERM

# Start Puppeteer Service in background
echo "Starting Puppeteer Service on port $PUPPETEER_SERVICE_PORT..."
cd /app/puppeteer-service
PORT=$PUPPETEER_SERVICE_PORT node dist/api.js &
PUPPETEER_PID=$!

# Wait for puppeteer service to be ready
echo "Waiting for Puppeteer Service to be ready..."
sleep 5

# Start Worker in background (only if REDIS_URL is set)
if [ -n "$REDIS_URL" ]; then
  echo "Starting Worker..."
  cd /app/api
  node dist/src/services/queue-worker.js &
  WORKER_PID=$!
else
  echo "Skipping Worker (no REDIS_URL configured)"
  WORKER_PID=""
fi

# Start API server in foreground
echo "Starting API Server on port $API_PORT..."
cd /app/api
PORT=$API_PORT node dist/src/index.js &
API_PID=$!

echo "All services started!"
echo "  - Puppeteer Service: PID $PUPPETEER_PID (port $PUPPETEER_SERVICE_PORT)"
if [ -n "$WORKER_PID" ]; then
  echo "  - Worker: PID $WORKER_PID"
fi
echo "  - API: PID $API_PID (port $API_PORT)"

# Wait for any process to exit
wait -n

# If any process exits, shut down all
echo "A process exited, shutting down..."
shutdown
