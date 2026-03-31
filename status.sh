#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

CONTAINER_NAME="${COLLECTOR_CONTAINER_NAME:-otelcol-custom}"
HEALTH_PORT="${OTEL_HEALTH_PORT:-13133}"

echo "=== Container Status ==="
if docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | grep -q .; then
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""

    echo "=== Health Check ==="
    if command -v curl &> /dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HEALTH_PORT}/" 2>/dev/null || true)
        if [ "$HTTP_CODE" = "200" ]; then
            echo "Collector is HEALTHY (HTTP 200 on port ${HEALTH_PORT})"
        else
            echo "Collector health check returned HTTP ${HTTP_CODE:-unreachable} (port ${HEALTH_PORT})"
        fi
    else
        echo "WARNING: curl not found, skipping HTTP health check."
    fi

    echo ""
    echo "=== Recent Logs (last 20 lines) ==="
    docker logs --tail 20 "${CONTAINER_NAME}"
else
    echo "Container '${CONTAINER_NAME}' is NOT running."
    echo ""

    if docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | grep -q .; then
        echo "Container exists but is stopped:"
        docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
        echo ""
        echo "=== Last Logs (last 20 lines) ==="
        docker logs --tail 20 "${CONTAINER_NAME}"
    else
        echo "No container found. Run ./install.sh to start."
    fi
fi
