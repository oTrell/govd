FROM golang:1.26-alpine AS builder

ENV GOCACHE=/root/.cache/go-build

RUN apk add --no-cache \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/main" \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/community" \
        "build-base=0.5-r4" \
        "libheif-dev=1.21.2-r2"

WORKDIR /app

RUN go install github.com/sqlc-dev/sqlc/cmd/sqlc@v1.30.0

COPY go.mod go.sum ./

RUN go mod download

COPY . .

RUN sqlc generate

RUN CGO_ENABLED=1 go build \
        -ldflags="-s -w" \
        -o govd ./cmd/main.go

FROM alpine:3.22 AS runtime

WORKDIR /app

RUN apk add --no-cache \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/main" \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/community" \
        "ffmpeg=8.0.1-r3" \
        "libheif=1.21.2-r2"

COPY --from=builder /app/govd ./govd

ENTRYPOINT ["./govd"]