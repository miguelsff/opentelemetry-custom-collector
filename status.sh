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
GRPC_PORT="${OTEL_GRPC_PORT:-4317}"
HTTP_PORT="${OTEL_HTTP_PORT:-4318}"

LINE="────────────────────────────────────────────────────"

print_header() {
    echo ""
    echo "$LINE"
    echo "  $1"
    echo "$LINE"
}

print_kv() {
    printf "  %-18s %s\n" "$1" "$2"
}

if docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | grep -q .; then
    # Container is running
    CONTAINER_ID=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}")
    CONTAINER_STATUS=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")
    CONTAINER_IMAGE=$(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Image}}")

    print_header "CONTAINER"
    print_kv "Name:" "$CONTAINER_NAME"
    print_kv "ID:" "$CONTAINER_ID"
    print_kv "Image:" "$CONTAINER_IMAGE"
    print_kv "Status:" "$CONTAINER_STATUS"

    # Health check
    HEALTH_STATUS="UNREACHABLE"
    HEALTH_ICON="[!]"
    if command -v curl &> /dev/null; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HEALTH_PORT}/" 2>/dev/null || true)
        if [ "$HTTP_CODE" = "200" ]; then
            HEALTH_STATUS="HEALTHY"
            HEALTH_ICON="[OK]"
        else
            HEALTH_STATUS="UNHEALTHY (HTTP ${HTTP_CODE})"
            HEALTH_ICON="[!!]"
        fi
    else
        HEALTH_STATUS="UNKNOWN (curl not found)"
    fi

    print_header "HEALTH"
    print_kv "Status:" "$HEALTH_ICON $HEALTH_STATUS"

    # Endpoints
    print_header "ENDPOINTS"
    print_kv "gRPC:" "localhost:${GRPC_PORT}"
    print_kv "HTTP:" "localhost:${HTTP_PORT}"
    print_kv "Health check:" "localhost:${HEALTH_PORT}"

    # Resource usage
    STATS=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" "${CONTAINER_NAME}" 2>/dev/null || true)
    if [ -n "$STATS" ]; then
        CPU=$(echo "$STATS" | cut -d'|' -f1)
        MEM=$(echo "$STATS" | cut -d'|' -f2)
        MEM_PCT=$(echo "$STATS" | cut -d'|' -f3)

        print_header "RESOURCES"
        print_kv "CPU:" "$CPU"
        print_kv "Memory:" "$MEM ($MEM_PCT)"
    fi

    # Recent logs
    print_header "RECENT LOGS (last 10 lines)"
    echo ""
    docker logs --tail 10 "${CONTAINER_NAME}" 2>&1 | sed 's/^/  /'

    echo ""
    echo "$LINE"

else
    # Container not running
    print_header "CONTAINER"
    print_kv "Name:" "$CONTAINER_NAME"

    if docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.ID}}" | grep -q .; then
        CONTAINER_STATUS=$(docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")
        print_kv "Status:" "[!!] STOPPED - $CONTAINER_STATUS"
        echo ""

        print_header "LAST LOGS (last 10 lines)"
        echo ""
        docker logs --tail 10 "${CONTAINER_NAME}" 2>&1 | sed 's/^/  /'
        echo ""
        echo "$LINE"
    else
        print_kv "Status:" "[!!] NOT FOUND"
        echo ""
        echo "  Run ./install.sh to start the collector."
        echo ""
        echo "$LINE"
    fi
fi
