# Caddy + Coraza WAF (OWASP CRS) — Docker Installation Guide

This repository is designed to run the Caddy web server integrated with OWASP Coraza WAF (Core Rule Set) 
on Docker. The guide covers installation, configuration, rate-limiting, 
HTTP/2 upstream, security logging, and performance improvements.

## Installation

### Architecture and Directory Structure
<details>.

.
├─ etc/
│  └─ Caddyfile
├─ Dockerfile
├─ docker-compose.yml
└─ README.md
</details> 

## Create the necessary directories
```
mkdir -p ./etc/caddy ./var/log/caddy ./assets ./certs
```

Optional (if you want to generate a self-signed TLS certificate for the test environment)::

```
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
  -keyout ./certs/key.pem -out ./certs/crt.pem \
  -subj "/CN=localhost"
```

Build / Run
```
docker compose build
docker compose up -d
```
Usage Examples
Container Status Check
```
docker compose ps
docker exec -it caddy-coraza caddy version
```
HTTPS Test
```
curl -kI https://localhost/
curl -kI https://localhost/index.html
```
WAF Test (SQLi Attempt)
```
curl -k “https://localhost/?q=' OR 1=1--”
```

Rate-Limit (Example)
(Testing sending excessive requests to the server in a short period)

```
#403 expected for over 1123 /api/* requests in 20 seconds
ab -n 1500 -c 200 https://localhost/api/ping
```
Monitoring Logs
```
tail -f var/log/caddy/access.log
tail -f var/log/caddy/coraza-audit.log
```
## Security and Performance Notes

WAF modes:

DetectOnly: Reports only. Recommended for initial deployment.

On: Blocking begins. Enable after threshold/false-positive tuning.

Paranoia Level: tx.paranoia_level=1 is conservative. Levels 2-3-4 increase rule sensitivity; application compatibility should be tested.

Header/Query Regexes: Sample constraints (metacharacters and length) should be narrowed/broadened based on false positive risk.

HTTP/2 Upstream: transport http { versions 2 } works on most modern reverse targets. If the target service does not support HTTP/2, drop to 1.x.

Cache (cache-handler): For static content, default_ttl 1h and Cache-Control reduce bandwidth and TTFB.

Log Format: JSON; enables easy integration with SIEM (Wazuh/Splunk/ELK).

Error Masking: handle_errors simplifies 500 → 403; prevents detail leakage.

Certificate Management: Use file certificates for testing; in production, choose ACME or an internal CA and automatic renewal.

Isolation: Open only the necessary ports; consider additional restrictions based on container users/capabilities (read-only fs, no-new-privileges).

## Troubleshooting
CRS rules are not triggering at all: order coraza_waf first or move it to the top. Don't wait for 403 in DetectOnly, check the audit log.

Static content 404: Is there an index.html in your assets/ host folder? Is root * /app/assets correct?

Upstream 502/504: Is the target service address/port correct? If it doesn't support HTTP/2, try versions 1.1.

Certificate Error: Use curl -k for testing; add the self-signed certificate to the trusted root for the browser or use a valid certificate.

## FAQ

“When should I enable blocking?”
After reviewing the DetectOnly logs for at least 1-2 weeks and cleaning up false positives (whitelist/rule settings).

“Can rate-limiting be user-based instead of IP-based?”
Identity-based keys such as “{header.X-User-Id}” can be used instead of “{remote_host}” in the key field (depending on the application architecture).

“Where do the WAF logs go?”
Inside the container, they go to /var/log/caddy/coraza-audit.log (on the host, ./var/log/caddy/…). Collect them with a SIEM agent.

## Official Documentation

Caddy Docs: https://caddyserver.com/docs/
This guide gets Caddy up and running on Docker with OWASP Coraza WAF (CRS); it is accessible via 80/443, WAF audit and access logs are written to the host, /api/* requests are proxied with rate limiting and HTTP/2 upstream, and static assets are served from cache.
