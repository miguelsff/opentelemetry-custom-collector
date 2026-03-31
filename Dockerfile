# Global build args (must be before any FROM to be used in FROM lines)
ARG GO_VERSION=1.25.8

# Stage 1: Obtain CA certificates
FROM alpine:3.19 AS certs
RUN apk --update add ca-certificates

# Stage 2: Build the custom collector binary with OCB
FROM golang:${GO_VERSION} AS build-stage

ARG OCB_VERSION=0.148.0
WORKDIR /build
COPY ./builder-config.yaml builder-config.yaml

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    GO111MODULE=on go install go.opentelemetry.io/collector/cmd/builder@v${OCB_VERSION}

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    builder --config builder-config.yaml

# Stage 3: Minimal runtime image
FROM gcr.io/distroless/base:latest

ARG USER_UID=10001
USER ${USER_UID}

COPY ./collector-config.yaml /otelcol/collector-config.yaml
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --chmod=755 --from=build-stage /build/otelcol-custom/otelcol-custom /otelcol/otelcol-custom

ENTRYPOINT ["/otelcol/otelcol-custom"]
CMD ["--config", "/otelcol/collector-config.yaml"]

EXPOSE 4317 4318 13133
