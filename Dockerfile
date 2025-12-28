# ---------- FRONTEND BUILD ----------
FROM oven/bun:latest AS builder

WORKDIR /build

# Copy only dependency files first (cache-friendly)
COPY web/package.json web/bun.lock* ./
RUN bun install

# Copy rest of frontend
COPY web ./web
COPY VERSION .

# Build frontend
RUN DISABLE_ESLINT_PLUGIN=true \
    VITE_REACT_APP_VERSION=$(cat VERSION) \
    bun run build


# ---------- BACKEND BUILD ----------
FROM golang:alpine AS builder2

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOEXPERIMENT=greenteagc

ARG TARGETOS
ARG TARGETARCH
ENV GOOS=${TARGETOS:-linux} \
    GOARCH=${TARGETARCH:-amd64}

WORKDIR /build

# Go deps
COPY go.mod go.sum ./
RUN go mod download

# Copy backend source
COPY . .

# Copy frontend build output
COPY --from=builder /build/dist ./web/dist

# Build Go binary
RUN go build -ldflags "-s -w -X 'github.com/QuantumNous/new-api/common.Version=$(cat VERSION)'" \
    -o new-api


# ---------- RUNTIME IMAGE ----------
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates tzdata libasan8 wget \
 && rm -rf /var/lib/apt/lists/* \
 && update-ca-certificates

COPY --from=builder2 /build/new-api /new-api

EXPOSE 3000
WORKDIR /data
ENTRYPOINT ["/new-api"]
