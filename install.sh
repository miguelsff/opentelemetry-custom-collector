#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
else
    echo "ERROR: .env file not found."
    echo "Copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    exit 1
fi

GRPC_PORT="${OTEL_GRPC_PORT:-4317}"
HTTP_PORT="${OTEL_HTTP_PORT:-4318}"
HEALTH_PORT="${OTEL_HEALTH_PORT:-13133}"

# Check if a port is in use
check_port() {
    local port=$1
    local name=$2
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":${port} "; then
            echo "ERROR: Port ${port} (${name}) is already in use."
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || netstat -an 2>/dev/null | grep -q ":${port} "; then
            echo "ERROR: Port ${port} (${name}) is already in use."
            return 1
        fi
    elif command -v lsof &> /dev/null; then
        if lsof -i :"${port}" &> /dev/null; then
            echo "ERROR: Port ${port} (${name}) is already in use."
            return 1
        fi
    else
        echo "WARNING: Cannot check port availability (no ss, netstat, or lsof found). Proceeding anyway."
        return 0
    fi
    echo "OK: Port ${port} (${name}) is available."
    return 0
}

echo "=== Checking port availability ==="
PORTS_OK=true
check_port "$GRPC_PORT" "gRPC"   || PORTS_OK=false
check_port "$HTTP_PORT" "HTTP"   || PORTS_OK=false
check_port "$HEALTH_PORT" "Health Check" || PORTS_OK=false

if [ "$PORTS_OK" = false ]; then
    echo ""
    echo "One or more ports are in use. Free them or change the ports in .env"
    exit 1
fi

echo ""
echo "=== Generating builder-config.yaml from .env ==="
bash "$SCRIPT_DIR/generate-builder-config.sh"

echo ""
echo "=== Building and starting the collector ==="
cd "$SCRIPT_DIR"
docker compose build
docker compose up -d

echo ""
echo "=== Collector started ==="
echo "  gRPC endpoint:  localhost:${GRPC_PORT}"
echo "  HTTP endpoint:  localhost:${HTTP_PORT}"
echo "  Health check:   localhost:${HEALTH_PORT}"
echo ""
echo "Run ./status.sh to check health, ./stop.sh to stop."
