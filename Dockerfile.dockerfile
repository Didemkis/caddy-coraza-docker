#Dockerfile

# 1) Builder: Caddy + eklentiler derlenir
FROM caddy:2.8-builder AS builder
RUN xcaddy build \
  --with github.com/corazawaf/coraza-caddy/v2 \
  --with github.com/mholt/caddy-ratelimit \
  --with github.com/caddyserver/cache-handler

# 2) Final imaj
FROM caddy:2.8-alpine

# Derlenen Caddy'yi kopyala
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Yardımcı paketler (opsiyonel)
RUN apk add --no-cache bash nano curl git

# Çalışma dizini
WORKDIR /app

# OWASP Core Rule Set'i imaja dahil et (volume ile gölgelenmeyecek)
RUN git clone --depth 1 https://github.com/coreruleset/coreruleset.git && \
    cp coreruleset/crs-setup.conf.example coreruleset/crs-setup.conf && \
    mkdir -p /var/log/caddy

ENV SHELL=/bin/bash
