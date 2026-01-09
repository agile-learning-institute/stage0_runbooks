#!/bin/bash
# Health check script for Stage0 Runbook API
#
# Usage:
#   ./healthcheck.sh
#   API_URL=http://api.example.com:8083 ./healthcheck.sh
#
# Exit codes:
#   0 - Service is healthy
#   1 - Service is unhealthy

API_URL="${API_URL:-http://localhost:8083}"

# Check metrics endpoint
if curl -f -s "${API_URL}/metrics" > /dev/null 2>&1; then
    echo "OK: Metrics endpoint healthy"
    exit 0
else
    echo "FAIL: Metrics endpoint unhealthy"
    exit 1
fi
