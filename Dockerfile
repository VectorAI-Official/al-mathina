# Dockerfile for AL-Madhina Go Backend
# Multi-stage build for smaller production image

# Stage 1: Build
FROM golang:1.24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /app

# Copy go mod files first (for better Docker layer caching)
COPY go-backend/go.mod go-backend/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code (this will overwrite go.mod/go.sum but that's fine)
COPY go-backend/ .

# Build binary with optimizations
# CGO_ENABLED=0 for static binary (no external dependencies)
# -ldflags="-s -w" strips debug info for smaller binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o main .

# Stage 2: Production
FROM alpine:latest

# Install ca-certificates for HTTPS calls (MongoDB Atlas, Supabase)
RUN apk --no-cache add ca-certificates tzdata wget

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/main .

# Copy static files for admin dashboard
COPY --from=builder /app/static ./static

# Expose port 9000
EXPOSE 9000

# Run as non-root user for security
RUN adduser -D -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9000/health || exit 1

# Run the binary
CMD ["./main"]
