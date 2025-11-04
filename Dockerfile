
# 1) Builder: Caddy + Modüller derlenir
FROM golang:1.25-alpine
WORKDIR /app
RUN apk update && apk add  --no-cache bash nano curl git caddy xcaddy
RUN xcaddy build --with github.com/corazawaf/coraza-caddy/v2 \
  --with github.com/mholt/caddy-ratelimit \
  --with github.com/caddyserver/cache-handler \
  --with github.com/darkweak/storages/otter/caddy

#Modüller ile derlenen caddy sistem path'ine taşınır
RUN mv /app/caddy /usr/sbin/caddy

#Owaps core rule set yüklenir
RUN git clone https://github.com/coreruleset/coreruleset.git
RUN cp ./coreruleset/crs-setup.conf.example ./coreruleset/crs-setup.conf

#Log klasörü hazırlanır
RUN mkdir -p /var/log/caddy

ENV SHELL=/bin/bash







