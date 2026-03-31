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
    exit 1
fi

COLLECTOR_NAME="${COLLECTOR_NAME:-otelcol-custom}"
CORE_VERSION="${OTEL_CORE_VERSION:-0.148.0}"
CONTRIB_VERSION="${OTEL_CONTRIB_VERSION:-0.148.0}"
CONFMAP_VERSION="${OTEL_CONFMAP_VERSION:-1.48.0}"

# Determine the version for a gomod path
resolve_version() {
    local mod="$1"
    if [[ "$mod" == *"confmap/provider"* ]]; then
        echo "$CONFMAP_VERSION"
    elif [[ "$mod" == *"opentelemetry-collector-contrib"* ]]; then
        echo "$CONTRIB_VERSION"
    else
        echo "$CORE_VERSION"
    fi
}

# Generate a YAML list of gomod entries from a comma-separated env var
generate_components() {
    local csv="$1"
    if [ -z "$csv" ]; then
        return
    fi
    IFS=',' read -ra MODS <<< "$csv"
    for mod in "${MODS[@]}"; do
        mod="$(echo "$mod" | xargs)"  # trim whitespace
        [ -z "$mod" ] && continue
        local ver
        ver=$(resolve_version "$mod")
        echo "  - gomod: ${mod} v${ver}"
    done
}

OUTPUT="$SCRIPT_DIR/builder-config.yaml"

cat > "$OUTPUT" <<EOF
dist:
  name: ${COLLECTOR_NAME}
  description: Custom OpenTelemetry Collector distribution
  output_path: /build/${COLLECTOR_NAME}
EOF

# Receivers
if [ -n "${OTEL_RECEIVERS:-}" ]; then
    echo "" >> "$OUTPUT"
    echo "receivers:" >> "$OUTPUT"
    generate_components "$OTEL_RECEIVERS" >> "$OUTPUT"
fi

# Processors
if [ -n "${OTEL_PROCESSORS:-}" ]; then
    echo "" >> "$OUTPUT"
    echo "processors:" >> "$OUTPUT"
    generate_components "$OTEL_PROCESSORS" >> "$OUTPUT"
fi

# Exporters
if [ -n "${OTEL_EXPORTERS:-}" ]; then
    echo "" >> "$OUTPUT"
    echo "exporters:" >> "$OUTPUT"
    generate_components "$OTEL_EXPORTERS" >> "$OUTPUT"
fi

# Extensions
if [ -n "${OTEL_EXTENSIONS:-}" ]; then
    echo "" >> "$OUTPUT"
    echo "extensions:" >> "$OUTPUT"
    generate_components "$OTEL_EXTENSIONS" >> "$OUTPUT"
fi

# Providers (always included)
cat >> "$OUTPUT" <<EOF

providers:
  - gomod: go.opentelemetry.io/collector/confmap/provider/envprovider v${CONFMAP_VERSION}
  - gomod: go.opentelemetry.io/collector/confmap/provider/fileprovider v${CONFMAP_VERSION}
  - gomod: go.opentelemetry.io/collector/confmap/provider/httpprovider v${CONFMAP_VERSION}
  - gomod: go.opentelemetry.io/collector/confmap/provider/httpsprovider v${CONFMAP_VERSION}
  - gomod: go.opentelemetry.io/collector/confmap/provider/yamlprovider v${CONFMAP_VERSION}
EOF

echo "Generated $OUTPUT"
