FROM golang:1.26-alpine AS builder

ENV GOCACHE=/root/.cache/go-build

# Build dependencies + dependencies required by libheif
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    pkgconf \
    libde265-dev \
    x265-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    aom-dev

WORKDIR /tmp

# Build the exact libheif version required by go.mod
RUN git clone --depth 1 --branch v1.21.2 \
    https://github.com/strukturag/libheif.git libheif

RUN cmake -S /tmp/libheif -B /tmp/libheif/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_LIBDE265=ON \
    -DWITH_X265=ON \
    -DWITH_AOM_DECODER=ON \
    -DWITH_AOM_ENCODER=ON \
    -DWITH_JPEG=ON \
    -DWITH_PNG=ON \
    -DENABLE_PLUGIN_LOADING=OFF \
    -DBUILD_TESTING=OFF

RUN cmake --build /tmp/libheif/build -j$(nproc) \
    && cmake --install /tmp/libheif/build

ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib

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
    ffmpeg \
    libde265 \
    x265 \
    libjpeg-turbo \
    libpng \
    aom

# Copy the exact libheif built in the builder
COPY --from=builder /usr/local/lib/libheif.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/pkgconfig/libheif.pc /usr/local/lib/pkgconfig/

COPY --from=builder /app/govd ./govd

RUN ldconfig /usr/local/lib 2>/dev/null || true

ENV LD_LIBRARY_PATH=/usr/local/lib

ENTRYPOINT ["./govd"]